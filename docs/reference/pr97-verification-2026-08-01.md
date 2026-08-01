---
title: PR #97 adversarial re-verification — findings
type: reference
date: 2026-08-01
related:
  - docs/handover-2026-08-01.md
  - docs/workorders/WO-075-IJ.md
  - docs/decisions.md
---

# PR [#97](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/97) — adversarial re-verification

The first verification run (previous session) hit a **git-lock collision** and may have read a stale tree,
so it was re-run from scratch. This file is the result. **Nothing here has been fixed yet** — it is a
findings record, not a changelog.

## Provenance — why this run is trustworthy where the last one wasn't

- Re-run against **HEAD `71273d7`**. `git diff 40b77ba..HEAD` touches only `BadgerTTK.toc` and
  `CHANGELOG.md` (the release commit), so **every PR97 code file at HEAD is byte-identical to what merged**
  — findings apply directly to what shipped as 0.9.48.
- Every agent ran under a hard **read-only git rule** (no `stash` / `checkout` / `add` / `reset`; read-only
  plumbing only) and mutated **scratchpad copies** for repro. Verified after the fact: `git status` showed
  no repo modifications. That is what prevented a second stale-tree collision.
- Five independent lenses (freeze removal · Thekal dual-id keying · generator drift · learner circularity ·
  spec strength), each finding then handed to an **adversarial refuter** instructed to default to
  "refuted" when it could not positively confirm. Then a **completeness critic** asked what the five lenses
  never opened, and its highest-severity finding got its own **three-lens adversarial round**.
- **18 candidate findings → 6 confirmed + 1 unrefuted.** The 11 refuted were mostly stale comments and
  lab-tool nits with no effect on shipped behaviour — listed at the bottom so nobody re-raises them.
- 32 agents total, 0 errors.

## Read this first if you read nothing else

**Finding 6 is the important one.** The regime layer's caps were both *learned* and *graded* under a show
gate the client does not implement, so three of the fourteen shipped profiles are effectively inert in game
— one of them **bit-identical to shipping no regime at all**. It is confirmed by three independent
reproductions. It changes no player-visible correctness, and the fix is instrument-side.

**Finding 5 is parked by [D-021-IJ]** and must not be fixed blind.

**Gap 3 outranks both if it is true**: the whole regime layer only engages when `UnitLevel("target") == -1`,
and nobody has ever checked that on a live Classic Era instanced boss. One `/run` line settles it — protocol
step **B5**.

## The gate is green, and that is exactly the problem

`pnpm validate --skip-nx-cache` at `71273d7`: **0 warnings / 0 errors, 33 files, all 4 projects.** Real
execution, no cache.

> A first `pnpm validate` returned green on **12/12 Nx cache hits** — nothing ran. Always
> `--skip-nx-cache` when the answer matters. This is the failure mode where a green gate means nothing.

Three of the five findings below are **things the green gate cannot see**.

---

## CONFIRMED — safe to fix off-client

These are provable and disprovable with `busted` alone. No client needed.

### 1. The per-bin `confCap` path has no test that it ever caps — MEDIUM

`projects/badger-ttk/src/engine/estimator.lua:252-261` · spec at `estimator_spec.lua:558-567`

The only per-bin spec is **titled** "a per-bin confCap uses the health bin (K=20)" — but its single
assertion is `assert.equals(cBase, c)`, the **negative** clause ("an absent bin does not cap"), which
`ceil = nil` also satisfies. So nothing anywhere feeds `_capConf` a per-bin table whose bin actually
**matches** the live health bin.

The refuter proved the gap rather than argued it: **two distinct breaking mutations of line 260 both
survive at 151 successes / 0 failures**, while a control mutation of the *scalar* branch does fail — so the
harness demonstrably detects real breaks, and these two survivals are genuine coverage holes, not a mis-run.

This is the regime layer's **primary mechanism** — the thing that makes the bar go quiet, the whole point of
0.9.48 — and the suite would not notice if it stopped working. Cheapest, highest-value item on the list.

### 2. `resetOnRise`'s magnitude threshold is untested — LOW (but nastier than it sounds)

`projects/badger-ttk/src/engine/estimator.lua:226-230`

Two tests guard the seam (a rise of 0.76 against a 0.5 threshold, and a profile with no `resetOnRise`);
**neither exercises a rise smaller than the threshold.** Deleting the comparison entirely — leaving
`if self.regime and self.regime.resetOnRise then` — keeps the gate at 151/0, identical to baseline.

The refuter then showed the failure is real, not theoretical: drive the mutated estimator with the
**shipped** Thekal profile (`resetOnRise = 0.25`) and sub-threshold heal ticks (rise `0.004`), and every
heal calls `self:reset()` — `ttk()` returns nil on **60/60** readouts versus **1/60** for shipped code. The
threshold is load-bearing and completely unpinned.

### 3. `assemble-regimes.py` emits a profile shape `regimes_spec` rejects — LOW

`tools/assemble-regimes.py:124-132`, `:154-160` vs `regimes_spec.lua:53-59`

**Found independently by three of the five lenses; all three confirmed.** The assembler has a deliberate,
documented branch (reached when `fmt_cap(caps)` is empty and the boss is in `learned`) that emits a profile
whose only field is `kills = N` plus two explanatory comments. `regimes_spec` computes `says` from
`hideBar / suppressFlush / confCap / resetOnRise / healPolluted / secondPool` — **`kills` is not in that
list** — so line 59 aborts with `empty profile @ 999` (and `@ 150999` via the dual-key alias).

**This one is already decided — the spec is wrong, not the generator.** The assembler's emitted comment is
*"The profile exists so the blanket default cap does NOT apply to it"*, which is **[D-019-IJ] clause (b)**
almost verbatim:

> *Measurement beats the blanket default. The universal raid cap is NOT folded into a measured boss […]
> A measured boss therefore always ships a profile, even one with no caps ("measured: nothing to cap"), so
> the default cannot re-impose itself.*

That is an **Accepted** decision. `regimes_spec`'s `says` list (`hideBar / suppressFlush / confCap /
resetOnRise / healPolluted / secondPool`) simply predates it and omits the case D-019(b) mandates. The fix
is to let the spec recognise that **presence itself is the assertion** for a boss with `kills` recorded —
not to change the generator, which is implementing an accepted decision correctly.

Still the human's call to confirm, but it is a confirmation, not an open design question.

Reachability is closer than it looks: `learn-regime.py:173`'s `if caps:` omits `confCap` entirely when every
bin measures readable, and three real candidates — **Chromaggus (150616), Ouro (150716), C'Thun (150717)** —
already sit at a single cap entry (bin 20). One more readable boss and the generator produces a file that
fails the gate.

### 4. Scalar `confCap` collapse discards measured zeros — LOW

`tools/assemble-regimes.py:148-149`

When every bin measures below the hard-coded `SHOW_THRESHOLD = 0.5`, the assembler replaces the 20-entry
measured table with the single **maximum** value. `_capConf` applies a numeric cap uniformly to every bin,
so the shipped scalar **raises 19 bins that were measured `0.0`**.

`learn-regime.py:158/161` proves `0.0` is a genuine measurement (median error ≥ 70% relative or ≥ 45s
absolute), not a sentinel or missing-data placeholder — so the discarded zeros carry real information. It is
only behaviourally equivalent *at the default threshold*, and `minConfidenceToShow` is a **user-facing
setting** (`config.lua:308-321`, range 0..1 step 0.05, default 0.5). Any player who moves that slider gets
a profile that no longer matches what was measured.

---

## PARKED — cannot be settled without data. **Do not fix blind.**

### 5. `resetOnRise` may never fire in the live client — MEDIUM, UNRESOLVED

`projects/badger-ttk/src/engine/estimator.lua:226`, `tools/estimator-perbin.lua:82`

The claim, with the exact path the refuter reproduced against `71273d7`:

- `estimator.lua:129-132` **nils `prevSampleT`** whenever `damageable == false`;
- `estimator.lua:133-137` re-anchors and **returns early** whenever `prevSampleT` is nil;
- so the `resetOnRise` block at `estimator.lua:222-234` is **structurally unreachable** for any rise whose
  immediately preceding sample was non-damageable;
- and `driver.lua:294` / `:379` pass `not UnitIsDeadOrGhost("target")` unconditionally. The driver is
  *built* to keep sampling dead targets (it records kill history off `dead` at `:385`, and has a
  `hideOnTargetDead` display setting at `:58`), so the hold genuinely persists across the window.

Thekal's resurrect is always preceded by a multi-second stretch at `h == 0`. Asserted as a silent no-op in
**55/60 harvested kills**.

Sharpening it: **the lab measures a configuration the client never runs.** `estimator-perbin.lua` and
`estimator-batch.lua` hard-code `damageable = true`, while the live driver passes `not dead`. The refuter
could not refute it and reproduced the code path against the committed tree.

If true, this is *lesson 3 of this project* ("learn under the configuration that ships") recurring on an
axis nobody had closed — and PR97's headline feature would be inert in-game.

### Why this stays parked — the standing decision (human, 2026-08-01)

It affects **one or very few bosses**, and it **cannot be tested right now** — confirming it needs a real
ZG raid on Thekal, which is not available. The finding therefore stays in limbo.

**The explicit instruction is to work around it, not around the uncertainty.** Do not "fix" this blind.
The reasons are structural, and they are the whole point:

- The suspect code is the **sampling / `damageable` hold**, which is on the path **every boss** takes.
  A speculative change there trades a possible no-op on one boss for a real regression on all fourteen.
- 0.9.48's load-bearing guarantee is that **`regime == nil` ⇒ the estimator is byte-identical**, enforced by
  diffing `tools/estimator-sim.lua` against `main`. A change to the sampling gate is exactly the kind of
  edit that breaks it.
- The evidence is **derived from the lab**, and the finding itself says **the lab's configuration is wrong**.
  Using a mis-calibrated instrument to justify surgery on the thing it mis-measures is circular. Correcting
  the instrument first is safe; acting on its current output is not.

**Allowed now** (instrument-only, no shipped-behaviour change): align `estimator-perbin.lua` /
`estimator-batch.lua` to pass `damageable = not dead` like the driver, then **re-measure**. That is a lab
change; it cannot regress the addon, and it either reproduces the no-op or dissolves the finding. If the
caps move materially, that is itself the finding — and it would mean 0.9.48's caps were calibrated against
a configuration the client never runs.

**Not allowed without data:** touching `estimator.lua`'s sampling gate, the `damageable` hold, or Thekal's
profile.

**How it gets resolved:** add Thekal to the in-game protocol — during a real ZG kill, confirm whether a
sample lands across the resurrect. Until then it is open, and being open is the correct state.

---

---

## The pattern underneath three of these: **the lab does not model the client**

Findings 5, 6 and gap 3 below are the same defect wearing three coats. In each, the estimator's evidence
base was produced by a harness that differs from the shipping driver in a way that **flatters the result**:

| # | the lab does | the client does | consequence |
|---|---|---|---|
| 5 | `estimator-batch.lua:105` / `estimator-perbin.lua:82` hard-code `damageable = true` | `driver.lua:294/379` pass `not UnitIsDeadOrGhost("target")` | `resetOnRise` fires 61× in the lab, **5×** live |
| 6 | `estimator-batch.lua:110` re-checks `conf >= MINCONF` **every sample** | `driver.lua:67` checks confidence **only while `not wasShown`** — the gate is sticky | most learned caps are **inert in game** |
| gap 3 | assumes the regime applies | `driver.lua:105` applies it only when `targetLevel == -1` | unverified for instanced Era bosses |

This is **[D-019-IJ] clause (c)** — *"facts must be live while measuring"* — recurring on three axes nobody
had closed. The lesson the project already paid for ("learn under the configuration that ships") was applied
to the *regime facts* and not to the *harness itself*.

**None of this means 0.9.48 is wrong.** It means the confidence we have in its numbers is lower than the
numbers suggest, and the cheap fix — make the lab model the driver, then re-measure — is instrument-side
and cannot regress the addon.

---

## FOUND BY THE COMPLETENESS CRITIC

### 6. The lab grades caps under a gate the client does not implement — **HIGH, CONFIRMED**

`tools/estimator-batch.lua:110` · `tools/learn-regime.py:207-208` vs `driver.lua:67-79`

**Three independent adversarial lenses — code-path, reproduce-the-numbers, and does-it-matter — all failed
to refute this.** Two wrote their own dual-gate graders from scratch and reproduced the critic's numbers to
three decimals, *including values they had no way to guess* (0.633 inert; 0.013 for Gahz'ranka). One
cross-validated its harness against the repo's own tool — `luajit tools/estimator-batch.lua <fixture>
--shipped` gives `mape=0.3755 shown=0.2983`, and its lab arm returned the same to four decimals — so the
replay is not diverging from the shipped grader. This is the most heavily corroborated finding in the sweep.

**The mechanism.** `driver.lua:67` is `if not wasShown and not settings.showAnyTarget then`. Confidence is
consulted **only before the bar's first appearance**. `shown` is a single module-local written in exactly
five places (`driver.lua:279, 286, 327, 336, 416`) — **every one a fight boundary**, never a mid-fight
event. Nothing resets it on `ENCOUNTER_START`/`ENCOUNTER_END`, nor on the one-shot encounter rebuild at
`:361-370` (which builds a fresh estimator with confidence back to 0 but leaves `shown` alone). The
retarget swap-back at `:327` *deliberately restores* it from the stash — WO-061 exists precisely to stop a
swap-back re-qualifying.

**The stickiness is correct and intended.** `driver_spec.lua:156-164` asserts it (*"a dip never hides the
bars"*), and `estimator.lua:245-246` states it in a comment: *"it flows through the driver's already-sticky
gate, so a cap blocks only the FIRST appearance."*

**The defect is that the lab never modelled it.** `estimator-batch.lua:110` is a bare
`if conf and conf >= MINCONF then`, re-evaluated every sample. And the learner carries the same false
assumption — `learn-regime.py:207-208` computes `quiet = sum(1 for b in caps if caps[b] < 0.5)` and prints
it as *"{quiet}/{BINS} bins would HIDE the bar"*, treating each bin as independently able to hide.

So once the bar latches in **any** bin, every later cap — **including a hard `0.0`** — is unreachable. Caps
were both *derived* and *graded* under a gate the client does not implement.

**Scope — 5 of 14 profiles materially affected, 3 of them effectively nullified:**

| profile | shape | lab (shown/MAPE) | client, sticky | verdict |
|---|---|---|---|---|
| **Viscidus (713)** | `[20]=0.75` latches at h≈0.996 | 0.333 / 0.460 | 0.966 / 1.184 | **fully nullified** — bit-identical to *no regime at all* |
| **Skeram (709)** | `[20]=0.28` blocks, but `[19]=0.9` latches | 0.234 / 0.863 | 0.825 / 1.209 | **~nullified** (baseline 0.860 / 1.213); 59.9% inert |
| **Sulfuron (669)** | `[20]=0.72` latches, `[19]=0.09` inert | — | 0.496 | **nullified** (baseline 0.495) |
| **Onyxia (1084)** | `[20]=0.0` but 19–12 uncapped | 0.836 / 0.487 | 0.922 / 0.538 | degraded, still net-positive (baseline 0.559) |
| **Buru (721)** | `[18]=0.91` latches after `[20]/[19]=0.0` | 0.676 / 0.377 | 0.817 / 0.441 | degraded, **survives** — the win is `suppressFlush`, not caps |
| Gahz'ranka (790) | — | — | ~1% inert | unaffected |

The refuting lens killed the obvious escape: *"most profiles cap bin 20 below 0.5, so the bar never
qualifies early."* False — capping bin 20 low does **not** protect a profile, because the lower bins are
usually uncapped or capped high, so the bar simply latches one bin later. Skeram and Onyxia both do exactly
that.

**What survives.** PR97's own boss (Gahz'ranka) is unaffected, so **PR #97's per-boss claim stands**. Buru's
headline **188.6% → 37.3%** survives in substance — client-model ~44% against a ~192% baseline — because
that win comes from `suppressFlush`, not from the caps. **What does not survive** is the Viscidus, Skeram
and Sulfuron cap results: those lab numbers describe a client that does not exist.

**This does not mean the addon is broken.** No player sees a wrong number because of this; they see a bar
that stays up where the lab thought it would go quiet. It means part of 0.9.48's evidence base is measured
against the wrong gate, and the fix — teach the grader and the learner the sticky gate, then re-learn — is
**instrument-side and cannot regress the addon**.

### The remaining critic findings — **unrefuted**

The adversarial pass on finding 7 and the two fresh sweeps were **stopped early** (deliberately: the
sticky-gate verdict was already decisive and the remainder was the low-value tail). Finding 7 below has had
no adversarial pass; per **[D-021-IJ]** it does not license a code change until it gets one.

### 7. `tools/candidates/*.lua` violate the very lint rule PR97 added a guard for — LOW, unrefuted

PR97 added a hard-fail for >120-char generated comments. But `learn-regime.py`'s own candidate output
violates the same rule: `regime-150789.lua` line 1 is **135** chars and line 9 is **261**. `luacheck
tools/candidates` reports **101 W631 warnings across 56 files**, including both files PR97 added.

They pass unnoticed because **no Nx project covers `tools/candidates`** — `pnpm validate` runs
`nx run-many` over `projects/badger-arena`, `projects/badger-ttk`, `tools/wow-mock` and
`libs/BadgerConfigUI-1.0` only. The repo's lint invariant holds by **scope accident**, not by the guard.
Bring `tools/` under the gate and every learner output fails immediately.

### Gaps the critic closed itself (all clean)

- **`.toc` load order** — `src\raids\regimes.lua` is listed after `rhythms.lua` and before `driver.lua`, so
  `ns.Regimes` exists when the driver reads it. Regimes touch no SavedVariables.
- **Driver regime plumbing** — `buildEst` forwards `regime` at both call sites (`:345`, `:363`), and the
  retarget stash preserves it across a target swap. No drop path.
- **All `ttk()` return sites** — every confidence-carrying return applies `_capConf`. No uncapped leak.
- **Lua 5.1 / sandbox** — PR97's shipped delta is pure deletion; the alias loop writes into a *different*
  table than it traverses, so no `invalid key to 'next'` hazard. No `loadstring` in shipped `src`.
- **Integrity** — the critic verified `HEAD = 71273d7` at start *and* end, with
  `git status --porcelain projects tools` empty throughout.

### Gap 3 — the one nobody can close off-client, and it is the real `/reload` question

`LiveDriver.regimeFor` (`driver.lua:104-109`) engages **only** when `targetLevel == -1`:

```lua
if regimes and encounterID and targetLevel == -1 then
```

**Every regime profile shipped — PR97's included — therefore depends on ZG's High Priest Thekal (789) and
Gahz'ranka (790) reporting boss/skull level −1 on a live Classic Era client.** Nothing in the repo verifies
that, and `docs/decisions.md:222` already records the analogous `UnitClassification == "worldboss"` gate as
explicitly *"unverified for instanced Era bosses"*.

If ZG's high priests report a numeric level, **the entire regime layer for ZG is a silent no-op in game**,
and no off-client gate can see it. This is the actual content of the outstanding `/reload` item — see
protocol step **B5**.

### Cosmetic

`estimator-scoreboard.json` run 20 says Thekal resurrects in "60/60 kills"; `regimes.lua:110` and
`tools/candidates/regime-150789.lua` say "30/30" (full corpus vs train half). Both are true of different
sets; the wording should say which. Fixture accounting is otherwise self-consistent (run 19's 800 + 60 + 60
= run 20's 920). No spec asserts the "14 profiles ship" claim, though it is true (616, 669, 671, 709, 713,
715, 716, 717, 719, 721, 789, 790, 792, 1084).

---

## REFUTED — do not re-raise these

Eleven candidates died under refutation. Recorded so a future sweep doesn't spend tokens rediscovering them:

- **Stale `freeze` documentation** in `estimator.lua:100`, `learn-regime.py:23`, `assemble-regimes.py:6`
  (three separate reports). Textually real, **zero behavioural effect** — D-020 removed the tier and no
  shipped code reads the field. Worth a tidy-up commit someday; not a defect.
- **`--split-even` locale-dependent split** (Python `sorted(glob)` bytewise vs `ls` locale order): refuted —
  zero leakage in the shipped derivation.
- **`--bins N` is a no-op** against the measurement (`estimator-perbin.lua` hardcodes `K = 20`): mechanically
  true, `certain` refuted as a defect — it mislabels a report, nothing more.
- **`estimator-perbin.lua` silently ignores unknown flags** (so a stale `--suppress-flush` does nothing):
  refuted — that invocation never existed as a user-facing path.
- **The >120-char guard only inspects lines starting with `--`**: real, but the exempted case cannot occur in
  the assembler's own output.
- **`regimes.lua` header claims `DEFAULT_CONFCAP` is "folded into every profile"**: the header is imprecise;
  the behaviour is correct and deliberate (D-014 — *a blanket default must not override a measurement*).
- **Re-running the assembler leaves the repo failing `format-check`**: the documented workflow includes the
  StyLua pass; not drift.

## Suggested landing

None of this is on CurseForge — 0.9.46/47/48 are GitHub-only — so every fix lands before a player sees it.
**Nothing here is a 1.0.0 blocker; the `/reload` still is.**

1. **First, the one-line question.** `/reload` protocol step **B5** (`UnitLevel("target") == -1`). If it
   prints a number rather than −1, the regime layer has never engaged for anyone and that reorders
   everything below. Cost: one `/run` on any boss.
2. **WO-076 — make the lab model the client (instrument-only, cannot regress the addon).** This is now the
   highest-value work order, and it subsumes the root cause of findings 5 and 6:
   - teach `estimator-batch.lua` / `estimator-perbin.lua` the **sticky** gate (`wasShown`), and fix
     `learn-regime.py:207-208`'s per-bin independent-hide assumption;
   - pass `damageable = not dead` like the driver instead of hard-coding `true`;
   - **re-learn and re-grade**, then compare against the shipped caps. Expect Viscidus, Skeram and Sulfuron
     to change materially. Whatever the new caps are, they will be the first ones calibrated against the
     estimator the client actually runs.
   - Regenerating `regimes.lua` will trip finding 3 the moment a boss measures clean — fix the spec
     (per D-019(b)) as part of this.
3. **WO-077 — the test holes (findings 1 and 2).** Pure spec additions; cannot change shipped behaviour.
   Worth doing independently and first if WO-076 is deferred, because they pin the mechanism that WO-076 is
   about to re-derive.
4. **Keep finding 5 parked** under [D-021-IJ]. The instrument alignment in WO-076 is the permitted move and
   may well dissolve it.
5. **Finding 7** needs an adversarial pass before anyone acts on it.
6. **Do not bump the version** for any of this until it is deliberately released (D-011). None of it is
   player-visible.
