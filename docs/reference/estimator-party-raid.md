# Estimator behaviour in party & raid (WO-066)

In-game testing so far has been **solo only** — an overleveled warrior vs single mobs, and a level-4
hunter vs even-level mobs. That is close to the estimator's *worst* case (chunky single-source melee).
This note validates the party/raid regimes **off-client** with the sim harness (`tools/estimator-sim.lua`)
and records the design follow-ups.

## TL;DR

- The estimator watches the **target's health fraction**, so it measures **total incoming damage** from
  everyone automatically. It is comp-agnostic and self-correcting: the live rate is whatever the group is
  actually doing, and it converges within a few seconds regardless of composition.
- **Raids are usually the estimator's *better* case.** Many overlapping attackers → smooth, continuous
  health loss, which is the chunk-clock's design sweet spot. The sawtooth the rewrite fixed is a *solo*
  problem.
- **Composition matters through two channels:** how *lumpy* the damage is (chunkiness) and the *prior*
  (a raid kill's rate depends on group size/comp). Caster/DoT-heavy = smoothest; a small melee-stacked
  group = lumpiest and the one wobble risk; more attackers always smooths it.
- **One real gap:** boss **immune/hardened phases** aren't detected — the readout balloons (capped at 2×
  history) during them. A boss-phase profile fixes it cleanly (proven below).

## How composition affects the estimate

The estimator never *needs* to know the comp — it measures the realized rate. Composition only changes
the **texture** of that signal:

| Composition | Effect on the *rate* | Damage texture | Estimate quality |
|---|---|---|---|
| **Caster-DPS / DoT-heavy** | steady | very smooth (ticks + casts) | **Best** — clean countdown |
| **Many melee (large raid)** | steady | swings overlap → smoothed | Good |
| **Few / stacked melee (small group)** | steady | lumpy at the 0.15s poll | **Wobble risk** (see the cliff) |
| **Healer-heavy** | **lower total DPS** → longer TTK | smooth | Stable — just a slower countdown |

So "healer-heavy" mostly means *slower* (the estimator reads the slower rate fine); "caster-heavy" means
*smoother* (ideal); "melee-heavy" means *lumpier* — and lumpiness is the only thing that stresses the
estimator, exactly as in the solo-warrior case, just diluted by the number of attackers.

## Sim numbers (current estimator, reactivity 0.5)

`worst 1s jump` = the biggest readout jump the user can see in one second; `cdev` = mean per-tick
deviation from an ideal 1s/s countdown; `adapt` = seconds to track a mid-fight rate change.

| trace | worst 1s jump | cdev | rmse | adapt |
|---|---|---|---|---|
| raid-caster-heavy (smooth) | **4.2s** | 0.17s | 1.3s | — |
| raid-healer-heavy (slow, smooth) | 10.0s | 0.59s | 4.1s | — |
| raid-heroism +40% mid-fight | 6.8s | 0.19s | — | **5.4s** |
| raid-melee-heavy (very lumpy) | **192s** ⚠ | 2.81s | 12.8s | — |
| raid-immune (driver today) | **113s** ⚠ | 0.51s | — | — |
| raid-immune (with boss profile) | 5.0s | 0.29s | — | — |

### The lumpiness cliff

Sweeping the per-tick jitter (a proxy for *how few* melee swings overlap in one 0.15s poll):

| jitter (lumpier →) | worst 1s jump |
|---|---|
| 0.2 (caster / many overlap) | 2.1s |
| 0.4 | 4.1s |
| 0.5 | 5.2s |
| 0.6 | 6.3s |
| **0.7** | **162s** ⚠ |
| 0.8 | 270s ⚠ |

There's a sharp cliff around **0.6 → 0.7**: below it the readout is a clean countdown; above it the
low-side **regime flush misfires** (two unlucky low-jitter polls in a row read as a genuine slowdown,
re-seed the fit low, and balloon the TTK before recovering). Most real raids sit well below the cliff —
any continuous damage (DoTs, casters, auto-shots) plus a handful of overlapping melee keeps jitter low.
The risk is a *small, melee-stacked* group with no continuous floor.

## The immune-phase gap (and the fix)

A boss with a 20s immune/frozen-health window (C'Thun weakened-gap, a submerge), tick-by-tick TTK:

```
DRIVER  (damageable=true through freeze):  t=41 →129   t=47 →219   t=53 →219   t=59 →219
PROFILE (damageable=false through freeze): t=41 →110   t=47 →110   t=53 →110   t=59 →110
```

Today the driver only ever passes `damageable = not dead` (`driver.lua:243`), so during an immune phase
the estimator sees frozen health, stales, and the readout balloons to the 2×-prior cap (~219 vs ~110) and
holds there until damage resumes. It is **not corrupted** (it recovers), but it lies for the phase. Feed
`damageable=false` for the window — which a boss profile can do — and the estimate **holds steady**
(110 throughout). The estimator already supports this; only the driver-side detection is missing.

## Roadmap (follow-ups, in rough priority)

1. **Boss-phase detection.** A per-encounter profile (or heuristics off `ENCOUNTER_START`/aura state)
   that feeds `damageable=false` during known immune/hardened windows. Proven valuable above (113s → 5s).
   The estimator + the `encounterActive` seam are already in place. *Post-1.0 feature.*
2. **Flush robustness past the lumpiness cliff.** Harden the low-side regime flush against per-tick noise
   (e.g. require the out-of-band run to be *sustained* over more events, gate it on a minimum accumulated
   evidence, or scale `JUMP_COUNT` with observed variance) so a small melee group can't wobble.
   Cheap, spec-able, and it removes the only stability risk the sim found. *Candidate for pre-1.0.*
3. **Unified kill-history schema — local recording ≡ web-log import — built on the community standard.**
   (Raised by the human.) The local store is `store[level][npcId] = { n, rate }` today. Four design pins:
   - **Base our schema on the community standard; don't invent one** (the human's lean — concur). The
     de-facto web-log standard is **Warcraft Logs**, itself built on WoW's own **combat log** (encounter /
     NPC id, fight duration, group size, specs). Model our per-kill record as a *subset/mapping* of those
     fields, so a locally-observed kill and an imported one are the **same shape** and a converter is a
     thin mapping rather than a translation.
   - **Sandbox reality (the load-bearing constraint):** a WoW addon **cannot fetch a URL or read a log
     file**. So "import from logs" is a **copy-paste** (exactly like our skin export/import), and a small
     **external converter** — a companion tool or website — turns a Warcraft Logs export or a raw
     `WoWCombatLog.txt` into that paste string. The only web-touching piece lives *outside* the addon.
   - **Transport = the community addon-string standard:** LibSerialize + LibDeflate → base64 (what
     WeakAuras / Plater / most data-sharing addons use), not a bespoke blob.
   - **Payoff:** local + imported kills blend into one prior; a web import seeds a fresh character's priors
     with zero local kills; and with size/comp stored per record the prior can be **selected or scaled by
     the current group** — the direct answer to the "prior is group-dependent" caveat — instead of averaged
     blindly across every past comp.

   *Decide the record schema before 1.0 so local recording is forward-compatible from day one; build the
   converter + paste-import later. Formalize as a decision once the source (WCL API vs. `WoWCombatLog.txt`)
   and the exact field set are chosen.*
4. **Optional prior-by-comp / by-size** (falls out of #3): weight or pick the history prior by the current
   raid size/composition. Low urgency — the live estimate self-corrects within seconds regardless.
5. **Live raid testing.** The sim de-risks the regimes but can't replace a real raid (phases, enrage,
   real comp variance, target-swapping under pressure). Still the final gate.

---

*Method: `tools/estimator-sim.lua` (deterministic LCG traces; run `luajit tools/estimator-sim.lua
projects/badger-ttk/src/engine/estimator.lua`). Numbers are for the current estimator at reactivity 0.5.*
