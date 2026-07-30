---
title: WO-069 Regime Architecture — Phase 1 Design (synthesis)
type: reference
status: Proposed — awaiting human acceptance (anchors D-014-IJ)
related:
  - docs/workorders/WO-069-IJ.md
  - docs/decisions.md
  - docs/reference/estimator-replay.md
---

> **Provenance.** Produced by a fable-5 + ultracode multi-agent workflow (WO-069 Phase 1):
> 4 deep-readers → 4 independent architectures → 3-judge panel → this synthesis. The winner was
> **unanimous** across all three judge lenses. This document is a **design proposal** — implementation
> is the branch+PR increments in §4, each gated by sim byte-identity + corpus regression, human-merged.
> A real, repo-grounded 1.0.0 gap audit
> now exists at `docs/reference/v1.0.0-gap-audit.md` (it replaced the workflow's stubbed gap-audit input);
> its Tier-1 findings — the deferred in-game /reload and the kill-history schema-vs-code gap — are the true
> 1.0.0 blockers, and §5 below should be read alongside it.

# WO-069 Phase 1 — Regime Architecture (Synthesis)

**Anchor:** WO-069-IJ · Decision D-013-IJ (refined here → recommend logging **D-014-IJ**)
**Target:** badger-ttk 1.0.0 / out of alpha · **Method:** fable-5 + ultracode fan-out → this synthesis
**Baseline to beat** (frozen chunk-clock, scoreboard run 2, 126 kills): mean MAPE **117.1%** · median **41.5%** · bias **+17.7s** · within-15% **26.1%**. Shipped 41-profile rhythm library (v0.9.45): whole-corpus median **25.3%**. This WO attacks the **structural tail** the rhythm profiles provably cannot fix.

---

## 1. The chosen architecture

### 1.1 Winner: **Minimal Seams — a health-anchored regime playbook injected as `opts.regime`** (Design 1)

Unanimous across all three judge lenses (in-game reality 34, engineering principles 34/35, provability 34/35). One new **injected, read-only, per-encounter data table** — `opts.regime` — consumed by a handful of **nil-guarded seams inside `estimator.lua`**, every one a literal no-op when `self.regime == nil`.

**The decisive property — the single injection point.** All regime interpretation is **health-anchored inside the estimator**, driven off the `h` it already receives. This is not an aesthetic choice; it is forced by the lab. `tools/estimator-batch.lua:67` grades every one of the ~2,100 corpus fixtures with `est:sample(s.t, s.h, true)` — `damageable` is hard-wired `true`. The **only** way a freeze / immune / reset mechanism can be proven byte-identically offline *and* fire identically live is for the estimator to freeze **itself** off `h`. Putting the logic anywhere else (the driver, a controller, a strategy object) splits the behavior into a live path and a mirrored grader path that must be kept in lockstep — the exact offline↔live divergence that makes an "improvement" unprovable. Design 1 collapses the grader change to *"inject one table"* and nothing else.

**Byte-identity is structural, not tested-in.** The sim (`estimator-sim.lua`) injects no rhythm and no regime, so `self.regime` is `nil`, so every new branch short-circuits. Constraint 3 (solo chunk-clock must not regress) holds by construction; we additionally wire the sim diff into the gate as a hard fail (graft, §1.3).

**It refuses to fake the un-fixable.** Heal pollution (Sulfuron/Jin'do) and second-health-pool / targeting-artifact bosses (Twins/Skeram) are **physically invisible to health polling** (verified: zero upward ticks on heal-polluted kills — heals only flatten a monotonic slope). Design 1 does not pretend; it **caps confidence** so the bar never shows a confident-wrong number, and declares the true fix a scheduled CLEU follow-up (§5, deferred).

### 1.2 Explicit rejections

| Design | Verdict | Why rejected |
|---|---|---|
| **D2 — Regime strategy-registry (full D-013 split)** | 25 / 29 | **Over-engineered for the actual defect.** Its own thesis concedes the rate integrator never changes (solo already nails smooth curves) — so a strategy registry + `estimator-core` extraction + a *speculative, un-corpus'd* `party` strategy is future-proofing that Principle 1.4 warns against ("promote when a second consumer is real, not speculatively"). The facade over separate strategy files strains single-file `mock.load` in sim/batch/specs (its own named risk), and the restructure widens the byte-identity blast radius for **the same health-only payoff** as the winner. |
| **D3 — Driver-level Encounter Controller** | 26 / 28 / 29 | **Highest ceiling, lowest provability, most in-game risk.** It alone attacks the CLEU-invisible tail (heal add-back, Majordomo add-counter, Twin second pool) — but those headline fixes are **not corpus-provable with today's lab** (they need a new fixture-events extension) and are in-game-only. It adds a new architectural indirection layer and stateful stall/`prevH` detection that must `resume()` correctly across every retarget/disconnect/wipe, and 40-man CLEU with no server-side filter is a genuine frame-hitch risk. Its ambitions are **absorbed as a scheduled future WO** (§5), not the winning ship. |
| **D4 — Enriched Encounter Profiles (learn the regime as data)** | 32 / 30 / 34 | **Not rejected — the primary graft source.** Consistent close second; stronger on calibration (learned vs hand-tuned) and on honoring the pipeline (constraint 6). Its one structural weakness: it puts the freeze decision in `driver.damageableFor` **and** mirrors it in the batch grader — two implementations that must agree, reintroducing the offline↔live divergence the winner avoids by freezing inside the estimator. **We take D4's learning machinery and universal default; we keep D1's single in-estimator injection point.** |

### 1.3 Absorbed grafts (the final architecture = D1 core + these)

Deduplicated across the three verdicts, each graft is folded in decisively:

1. **[D4 — the core graft] Learn the numeric fields; hand-author only the categorical facts.** A new `tools/learn-regime.py` (grown from `learn-rhythm.py`) derives, on the even/odd train/test split the 41 profiles already use: per-health-bin **`confCap`** from the coefficient of variation of held-out remaining-time at bin entry (high dispersion → low cap); **freeze band** boundaries from robust cross-kill quantiles of where health stalls; **`resetOnRise`** thresholds from majority up-jump detection. Categorical flags (`hideBar`, `suppressFlush`, `secondPool`, `healPolluted`) stay hand-authored — those are domain facts, not statistics. This cures D1's only real weakness (hand-tuned magic-number bands) while keeping the single-injection runtime.

2. **[D4] Ship the universal raid-gate knowledge as a global default.** `ns.Regimes.default` carries a `confCap` on the top/opening bins so the corpus-wide observation — *all 41 bosses open at 0.30–0.55× steady rate; a trickle at full HP is never certainty* — applies to **every** raid target, including un-profiled bosses (Naxxramas, Onyxia). This ships the "regime-aware confidence" + "universal raid gate" requirements the per-encounter table leaves on the floor.

3. **[D4] Regenerable data via a deterministic assembler.** `tools/assemble-regimes.py` concatenates `tools/candidates/regime-*.lua` + the hand-authored categorical flags into `src/raids/regimes.lua`, emitting the `+150000` alias loop and merging the universal default into each entry. Removes the "hand-edit outside the alias loop" hazard. **`regimes.lua` stays a separate file from the auto-generated `rhythms.lua`** so the two pipelines never cross-contaminate.

4. **[D3] An optional stall-timer freeze for mid-curve bands.** The stateless health band is rock-solid for the unambiguous `h≈1.0` gates (Rajaxx / C'Thun P1 / Majordomo) but cannot tell a mid-curve *plateau* (Viscidus ~0.93, Ouro submerge) from health *legitimately passing through* the band. A band that carries a `stallSec` key freezes only after health has **stalled** in-band for `stallSec` — a tiny health-anchored timer (`self.regimeStall`), still driven off `dt`/`h`, still provable through the grader. Closes D1's one in-game gap without importing D3's full statefulness.

5. **[D3] Reserved forward-compatible CLEU slots.** Every honest `confCap`-only non-fix carries a declared upgrade path: `healPolluted=true`, `addNpcIds`/`addTotal`, `secondPool=true`. Ignored by the estimator today (extra keys are silently forward-compatible, exactly like `rhythm.kills`). The deferred CLEU WO (§5) pre-commits to its discipline: register `COMBAT_LOG_EVENT_UNFILTERED` **only** between `ENCOUNTER_START`/`END`, filter to the boss GUID set, whitelist subevents, allocate nothing per event, and **subtract overheal from `SPELL_HEAL`** (the gotcha D3 itself missed).

6. **[D3/D4] The load-bearing id correction, spec-locked.** Thekal is `encounterID 150789`; **`150790` is Gahz'ranka**. `resetOnRise` on the wrong key silently no-ops. The regimes spec asserts both the base id and the `+150000` alias resolve for Thekal at 789.

7. **[D3, verdict 2] Nil-identity as a first-class named invariant, wired into CI.** "`regime = nil` reproduces the baseline byte-for-byte" is (a) an explicit `estimator_spec` assertion and (b) a hard-fail `estimator-sim.lua` output diff in the gate — the guarantee that protects constraint 3.

8. **[D2, verdict 2] Regime-aware confidence as one cross-cutting guardrail.** *Never reach certainty while `h` is flat-at-full OR the observed rate is anomalously low for the band* — applied globally via the universal default (graft 2), so a steady trickle during a gate/waves can never reach certainty even on a boss with no bespoke entry. This directly answers D-013's motivating defect (Lucifron confidence hit 1.00 at 99% HP during the adds gate).

9. **[D3, verdict 3] Mine the fixture timeline comments offline.** `learn-regime.py` parses the `-- timeline: add down ~Ns — <Flamewaker Priest>` annotations already in every fixture to anchor the heal-polluted high-HP `confCap` band for Sulfuron/Jin'do — converting a "health-invisible, in-game-only" item into a *partially* corpus-provable one, while still reserving the CLEU slot for the true subtraction fix.

10. **[D2/D3, verdict 3] The non-regime regression guard is a hard asserted gate.** `estimator-batch.lua` proves every non-regime boss row is byte-identical when `regime=nil`, and reports per-boss `shown%` + `n` alongside MAPE so the "confCap improves MAPE by scoring fewer samples" effect is always visible and labeled, never a silent win.

### 1.4 What this architecture deliberately does *not* build

- **No solo/party/raid strategy classes.** D-013's *intent* — stop stretching one solo-tuned path across structurally different regimes; give the raid path per-encounter shape + regime-aware confidence + phase handling — is fully delivered by the shipped rhythm-DI **plus** this regime layer. The evidence (verdicts) showed the rate **integrator** does not need to fork; **confidence and phase behavior** do, and injected regime data provides exactly that. This **refines D-013** and warrants a short decision note (**D-014**, §5 MUST).
- **No group-size regime detection.** Routing is **encounter-keyed** (`encounterID` + boss-level `-1`), which subsumes the solo-vs-raid distinction (no encounter id + no boss level ⇒ no regime ⇒ pure chunk-clock). The **party (5-man)** regime is deferred pending a 5-man corpus — no unvalidated party path ships.
- **No combat-log reads in Phase 1.** Everything here is health-only and corpus-provable today. CLEU is a named, disciplined future WO with reserved schema slots (§5 deferred).

---

## 2. Component spec

### 2.1 Data schema (verbatim) — the regime profile

Shipped in `src/raids/regimes.lua`. Every field is optional; **an absent field is a no-op.** Keyed by `DungeonEncounterID`, dual-aliased `+150000`.

```lua
-- ns.Regimes[encounterID] = a regime profile. All fields optional; nil ⇒ no-op.
[150719] = {                     -- (illustrative — Rajaxx)
    -- ── CATEGORICAL FLAGS (hand-authored domain facts) ───────────────────────
    hideBar      = true,         -- boss health is pure noise; ttk() returns (nil, 0).
    suppressFlush = true,        -- scripted chunk damage: cliffs must not flush the prior.
    resetOnRise  = 0.5,          -- a one-sample rise ≥ this fraction = phase reset → self:reset().

    -- ── FREEZE BANDS (the SET is declared; boundaries LEARNED via quantiles) ──
    freeze = {
        { lo = 0.999, hi = 1.0 },                 -- STATELESS: unambiguous flat-at-full gate.
        { lo = 0.90,  hi = 0.95, stallSec = 3.0 },-- STALL-GATED: freeze only after health
    },                                            --   stalls in-band ≥ stallSec (mid-curve plateau).

    -- ── CONFIDENCE CAP (LEARNED per-bin from held-out remaining-time CV) ──────
    -- Number ⇒ cap all bins. Table ⇒ per-bin ceiling, K=20, index = health bin
    -- (bin 20 = h∈(0.95,1.0], bin 1 = execute end). Absent bin ⇒ no cap.
    -- SHIPPED data is always a normalized per-bin table (assembler folds the
    -- universal default in by element-wise min); scalar form is accepted for
    -- hand/lab authoring.
    confCap = { [20] = 0.0, [19] = 0.10, [18] = 0.25 },

    -- ── RESERVED CLEU SLOTS (forward-compatible; ignored today) ──────────────
    healPolluted = true,                          -- Sulfuron/Jin'do: SPELL_HEAL subtraction (future WO).
    addNpcIds    = { [Flamewaker] = true },        -- Majordomo add-counter (future WO).
    addTotal     = 8,
    secondPool   = true,                          -- Twins: needs boss2 token / CLEU (future WO).

    -- ── PROVENANCE (mirrors rhythm.kills; spec-checked, estimator ignores) ────
    kills = 25,
}

-- Universal raid gate — applies to EVERY boss-level raid target, profiled or not.
ns.Regimes.default = {
    confCap = { [20] = 0.0, [19] = 0.10 },        -- "never certain at/near full; raids open slow".
}
```

### 2.2 Files

Legend: **NEW** / **CHANGE**. "Ships to client" = loaded by the `.toc`; "lab" = `tools/` (never ships).

| File | N/C | Responsibility | Spec / proof |
|---|---|---|---|
| `projects/badger-ttk/src/raids/regimes.lua` | **NEW** (ships) | `ns.Regimes` — the per-encounter regime playbook + `ns.Regimes.default`. Same shape/aliasing as `rhythms.lua`; **kept separate** so the two pipelines never mix. Assembled, never hand-edited-in-place. | `regimes_spec.lua` (below) |
| `projects/badger-ttk/src/raids/regimes_spec.lua` | **NEW** (ships) | Guards STRUCTURE (a regeneration mistake fails the gate), not learned values. Asserts: every profile resolves at base id **and** `+150000`; `freeze` bands are `{lo<hi}` in `[0,1]`; `confCap` in `[0,1]`; `resetOnRise` in `(0,1]`; **Thekal keyed at 150789, absent at 150790**; `ns.Regimes.default` exists; no add-level leak (documents `-1` routing). Mirrors `rhythms_spec.lua`. | self |
| `projects/badger-ttk/src/engine/estimator.lua` | **CHANGE** (ships, ~+45 nil-guarded lines) | Adds the seams (§2.3). Public API `new/reset/sample/ttk` unchanged. | `estimator_spec.lua` |
| `projects/badger-ttk/src/engine/estimator_spec.lua` | **CHANGE** (ships) | New cases: freeze holds `ttk()` bit-identical + stops conf growth; band-exit re-acquires without an event; stall-gated band arms after `stallSec` and releases on resumed drop; `hideBar → (nil,0)`; `confCap` clamps (never raises) at every return site; `resetOnRise` clears+re-anchors (P1 "about to die" does not bleed into P2); an **un-flagged** profile with an up-jump does **not** reset (Twin/Skeram negative test); `suppressFlush` blocks a two-cliff flush; **`regime=nil` reproduces baseline exactly** (named invariant). | self |
| `projects/badger-ttk/src/live/driver.lua` | **CHANGE** (ships, ~+15 lines) | `LiveDriver.regimeFor` (mirror of `rhythmFor`, boss-level `-1` gate, falls back to `ns.Regimes.default` for un-profiled boss-level targets in a live encounter); `buildEst` gains a `regime` param → `opts.regime`; **one-shot upgrade generalized** so a **regime-only** boss (Majordomo, no rhythm) still gets its regime injected at `ENCOUNTER_START` (§2.4). | `driver_spec.lua` |
| `projects/badger-ttk/src/live/driver_spec.lua` | **CHANGE** (ships) | `regimeFor` truth table (nil regimes/encounter, non-boss level rejects, boss level resolves entry + aliased id, un-profiled boss level → `default`); `buildEst` passes `opts.regime`; **stickiness**: a `confCap` may block the FIRST show only, never hide an already-shown bar. | self |
| `projects/badger-ttk/BadgerTTK.toc` | **CHANGE** (ships, +1 line) | Insert `src\raids\regimes.lua` after `src\raids\rhythms.lua` (line 49) and before `src\live\driver.lua` — `ns.Regimes` must exist before the driver references it. | — |
| `tools/estimator-batch.lua` | **CHANGE** (lab, ~+12 lines) | Add `regimeFor(encounterID)` loading `tools/candidates/regime-<enc>.lua` (mirrors the existing `rhythmFor`); pass `regime = regimeFor(fight.encounterID)` into `Estimator.new`. **The `est:sample(s.t, s.h, true)` call is UNCHANGED** — the estimator freezes itself. Add the hard **non-regime regression guard** (rows byte-identical when no candidate) + per-boss `shown%`/`n` columns. | — |
| `tools/learn-regime.py` | **NEW** (lab) | Grown from `learn-rhythm.py`. Even/odd train/test. Emits `tools/candidates/regime-<enc>.lua`. Learns `confCap` (per-bin CV of held-out remaining-time), `freeze` boundaries (cross-kill stall quantiles), `resetOnRise` (majority up-jump). Parses `-- timeline: add down` comments to anchor heal-polluted caps (Sulfuron/Jin'do) and seed reserved CLEU add data. Prints the learned regime as ASCII. Stdlib only. | — |
| `tools/assemble-regimes.py` | **NEW** (lab, ~80 lines) | Deterministic: concatenates `tools/candidates/regime-*.lua` + hand-authored categorical flags → `src/raids/regimes.lua`; emits the `+150000` alias loop; **normalizes scalar `confCap` to per-bin and folds `ns.Regimes.default` in by element-wise min** so the universal floor rides every entry. | — |
| `tools/estimator-sim.lua` | **UNCHANGED** | Injects no regime → `self.regime` nil → byte-identical. This *is* the PR acceptance gate. | — |
| `docs/reference/estimator-replay.md` | **CHANGE** (docs) | Record the regime-campaign learnings + the health-only↔CLEU boundary (post-pass convention). | — |
| `docs/reference/estimator-scoreboard.json` | **CHANGE** (docs) | Baseline-vs-regime held-out MAPE/bias/shown/n per structural boss, per increment. | — |
| `docs/workorders/WO-069-IJ.md` | **CHANGE** (docs, direct-to-main) | Record schema, the confCap-from-dispersion method, the 3-increment plan, the health-only↔CLEU boundary, and the D-014 refinement. | — |

### 2.3 Estimator seams (exact attach points, current `estimator.lua` line refs)

Every seam is guarded by `self.regime`; all are no-ops when `nil`.

1. **`new()` (after line 85, `self.rhythm = opts.rhythm`):** `self.regime = opts.regime`.
2. **`reset()` (line 106 block):** `self.regimeStall = 0` (stall-timer for stall-gated freeze bands). Cleared like all live state. *Note:* `reset()` does **not** touch `self.regime`/`rhythm`/`tau`/`priorRate` (construction-time), so a `resetOnRise` mid-fight re-anchor keeps the regime.
3. **`sample()` freeze (after line 115, i.e. after the existing `if damageable == false` short-circuit — so the swap-back `sample(0,0,false)` at driver:251 is untouched):**
   ```lua
   if self.regime and inFreezeBand(self, t, h) then
       self.prevSampleT = nil   -- reuse the existing hold path: no events, dmgTime frozen
       return                   -- (regime-aware confidence falls out for free)
   end
   ```
   `inFreezeBand` (file-local): stateless band → `lo ≤ h ≤ hi`; stall-gated band → accrue `self.regimeStall` while in-band with |Δh| below a small epsilon, freeze once `regimeStall ≥ stallSec` (reset the timer on band exit / resumed drop).
4. **`sample()` resetOnRise (the heal branch, `drop < 0`, lines 201–205):**
   ```lua
   if self.regime and self.regime.resetOnRise
      and (h - self.lastH) >= self.regime.resetOnRise then
       self:reset(); self.prevSampleT, self.lastH = t, h; return
   end
   ```
5. **`sample()` suppressFlush (wrap the flush arm/fire block, lines 157–185):** `if not (self.regime and self.regime.suppressFlush) then … end`. The **fold** (188–195) still runs — evidence accumulates; only the prior-destabilizing flush is suppressed.
6. **`ttk()` hideBar (top, after the `lastH == nil` guard at line 214):** `if self.regime and self.regime.hideBar then return nil, 0 end`.
7. **`ttk()` confCap (a private `self:_capConf(conf)` applied at every real-conf return site — 245, 266, 308 — after the prior-share raise at 250–255, so a full-strength prior can't re-inflate past the cap):** number form caps all bins; table form uses the same bin math as the rhythm branch (`idx = min(floor(h*K)+1, K)`, `K=20`), absent bin ⇒ no cap. Never raises `conf`. Flows through the driver's **already-sticky** gate (`LiveDriver.gate` applies `minConf` only `if not wasShown`), so a cap blocks only the first appearance.

### 2.4 Driver wiring — the one correctness subtlety

`regimeFor` mirrors `rhythmFor` exactly (boss-level `-1`, live encounter), with a **default fallback**:
```lua
function LiveDriver.regimeFor(regimes, encounterID, targetLevel)
    if regimes and encounterID and targetLevel == -1 then
        return regimes[encounterID] or regimes.default
    end
    return nil
end
```

**Load-bearing:** the existing one-shot upgrade (driver 269–275) fires on `not estHasRhythm and rhythm ~= nil`. A **regime-only** boss (Majordomo — deliberately absent from `rhythms.lua`) has `rhythm == nil`, so the upgrade would **never inject its `hideBar`** on a pre-pull-targeted pull. Fix: track the encounter id the estimator was keyed against (`estEncounterID`, replacing `estHasRhythm` in the local + the `recent[guid]` stash/restore) and fire the one-shot rebuild when `currentEncounterID` transitions from `nil` → a real id, resolving **both** `rhythmFor` and `regimeFor`. This keeps a single construction path (`buildEst`) and guarantees regime injection for rhythm-less regime bosses.

---

## 3. Per-Tier-3-boss: mechanism + acceptance test

Numbers are **held-out mean MAPE, with the shipped rhythm profile** (the current tail) → the regime target. **Every target is measured by `tools/estimator-batch.lua` before/after against a frozen even/odd baseline** — the brief's quoted figures are re-established in-run, never assumed. For the honest non-fixes, the win is **`shown%`↓ with MAPE non-regressed** (confCap drops confident-wrong rows below `MINCONF=0.5`); `n` and `shown%` are always reported so the sample-count effect is visible and labeled.

| Boss | id | Mechanism | Corpus number to beat | Acceptance test |
|---|---|---|---|---|
| **Majordomo Executus** | 150671 | `hideBar` — health is pure noise (median 100% of fight at full; kill = 8 adds). `ttk()→(nil,0)`. | *excluded* (6 fixtures) | Bar **hidden** on every tick; `shown%→0`; no meaningless-number rows in the grade. No MAPE regression possible. |
| **Rajaxx** | 150719 | `freeze {0.999,1.0}` (7-wave gate pins h=1.0, median 126s) + `confCap[20]=0`. | 424% → **348%** | Gate samples leave the graded set; `shown%` during the gate → ~0; **MAPE-of-shown ≤ 150%** (collapses toward the ~24s post-gate burn). |
| **C'Thun** | 150717 | `freeze {0.994,1.0}` (immune P1 body, variable 2.7–94s) → clean ~60s P2 burn scored by the rhythm bins. | 225% → **55%** | **MAPE ≤ 45%**; bias tightens (no 2×-prior balloon during the immune window). |
| **Viscidus** | 150713 | Stall-gated `freeze {0.90,0.95,stallSec}` over the ~0.93 frozen plateau + `confCap` on the plateau bin. Shatter timing stays unknowable. | 608% → **86%** | **MAPE ≤ 86%** (hold/tighten) **and** false-certainty on the plateau eliminated (`conf` capped below 0.5 across the frozen window). |
| **Ouro** | 150716 | Stall-gated `freeze` (submerge band) — a burned-through submerge must not read as "rate collapsed". | 38% → **29%** | **MAPE ≤ 29%** (hold); guards long-submerge kills the single fixture under-represents. |
| **Thekal** | **150789** | `resetOnRise=0.5` — P1 trio → h=0, then the 0→~1.0 tiger resurrect triggers `self:reset()`; P2 tracked fresh. *(150790 is Gahz'ranka — do not key here.)* | 171% → **129%** | **MAPE < 129%** on the P2 window; P1 "about to die" false read cleared; P1 itself still reads "dying" (a second life is unforeseeable from health). |
| **Buru** | 150721 | `suppressFlush` (egg cliffs must not flush the prior) + opening `freeze {0.98,1.0}` (~18s near-immune chase). Bins carry the staircase shape. | 273% → **171%** | **MAPE < 171%**; the wild post-cliff TTK swings (flushed-away prior) removed. Egg timing stays player-driven (irreducible). |
| **Skeram** | 150709 | `confCap` (scalar) — 75/50/25 splits cause targeting-artifact up-jumps; real-vs-image needs unit discrimination (Era-blocked). | 177% → **174%** | **Honesty win, not accuracy:** MAPE non-regressed; bogus `shown%` during the sawtooth drops (rows go never-confident). |
| **Twin Emperors** | 150715 | `confCap` (~0.4) + stall-gated freeze over the swap-heal plateaus — single-target curve is the wrong quantity (two pools; needs boss2/CLEU). `secondPool=true` reserved. | 466% → **418%** | **Honest non-fix:** confident-wrong rows drop below the 0.5 gate; `shown%`↓; MAPE non-regressed. |
| **Chromaggus** | 150616 | `confCap` (scalar) — weekly-random Brood Power vulnerability is a non-stationary slope (needs `UnitAura`). | 71% → **54%** | **Honesty win:** MAPE non-regressed; vulnerability-conditioned profile **deferred** (future UnitAura WO). |
| **Sulfuron** | 150669 | `confCap` on the high-HP suppressed band (learned from the healer-death timeline comment) + `healPolluted=true` reserved. Heal pollution is health-invisible (zero up-ticks). | 92% → **50%** | Bias tightened, confidence honest in the pre-healer-death window; **MAPE ≤ 50%** (no overclaim). True fix (SPELL_HEAL subtraction) deferred. |
| **Jin'do** | 150792 | Same as Sulfuron (totem heals). | 85% → **71%** | Same stance; **MAPE ≤ 71%**. |
| **Universal (all 41 + un-profiled)** | `default` | `confCap` on the opening/full bins — "raids open at 0.3–0.55×; never certain at full." | — | Across the whole corpus: over-confident early-fight shows ↓; **non-structural bosses' MAPE/`shown%` within noise** of the shipped baseline (the regression guard). |

---

## 4. Implementation plan — ordered PR increments

**Universal gate for every PR** (per the working agreement — branch `feature/WO-069-IJ-<slug>` off an `Accepted` WO on `main`, PR, human-merged; AI never merges):
- `PATH=~/.luarocks/bin:$PATH pnpm validate` green (StyLua `--check` · Luacheck · Busted).
- **Sim byte-identity (hard fail):** `luajit tools/estimator-sim.lua` diffed against `main` = empty. Wired into the gate as a diff hard-fail, not just a spec.
- **Corpus regression guard (hard fail):** `luajit tools/estimator-batch.lua` — every **non-regime** boss row byte-identical to the pre-change aggregate (no candidate ⇒ `regime=nil` ⇒ identical MAPE/bias/shown/n).
- Scoreboard run N vs N−1 recorded; `CHANGELOG [Unreleased]` entry; **no version bump** (D-011).

Each PR is independently shippable and corpus-graded. Lab tooling (`learn-regime.py`, `assemble-regimes.py`) lands in PR1 because it generates the data PR1 ships.

### PR1 — Freeze + hideBar + the universal default + the lab (the health-only structural wins)
- **Scope:** the immune/gate/plateau bosses whose fix is corpus-provable today.
- **Files:** `learn-regime.py` (holds/freeze + timeline parse), `assemble-regimes.py`; **NEW** `regimes.lua` (+ `regimes_spec.lua`) with `hideBar` (Majordomo), stateless `freeze` (Rajaxx, C'Thun, Buru-opening), stall-gated `freeze` (Viscidus, Ouro), `ns.Regimes.default`; `estimator.lua` seams 1–4 & 6–7 (+ stall timer) + spec; `driver.lua` `regimeFor` + `estEncounterID` upgrade + `buildEst` param + spec; `BadgerTTK.toc` (+1); `estimator-batch.lua` regime injection + regression guard + `shown%`/`n` columns.
- **Validation:** sim byte-identical; non-regime rows byte-identical; **Rajaxx / C'Thun / Viscidus / Ouro / Buru** MAPE + `shown%` move as in §3; **Majordomo hidden**.

### PR2 — Regime-aware confidence at scale + suppressFlush cliffs
- **Scope:** the confCap honesty tier + Buru's cliff handling; the learned per-bin CV caps.
- **Files:** `regimes.lua` regenerated — per-bin `confCap` (Twins/Skeram/Chromaggus), high-HP `confCap` from the healer-death timeline (Sulfuron/Jin'do), `suppressFlush` (Buru), reserved slots (`healPolluted`/`addNpcIds`/`secondPool`); `estimator.lua` seam 5 (suppressFlush) + spec; `learn-regime.py` CV-based `confCap` + timeline mining.
- **Validation:** sim byte-identical; confCap rows drop below `MINCONF` → per-boss `shown%`/`n` reported and labeled never-confident (not a silent MAPE win); **Buru** MAPE improves; regression guard holds.

### PR3 — Thekal resetOnRise + stall-gated mid-band tuning + honest CLEU-deferred note
- **Scope:** the phase-reset boss and the mid-band calibration; close the schema for the deferred tier.
- **Files:** `regimes.lua` — `resetOnRise` for **Thekal 150789** (spec asserts both id spaces), tuned stall bands (Viscidus/Ouro); `estimator.lua` seam 4 (resetOnRise, if not already in PR1) + stall-band tuning + specs (incl. the **Twin/Skeram un-flagged negative test**); `learn-regime.py` resetRise detection.
- **Validation:** sim byte-identical; **Thekal** P2-window MAPE improves; Viscidus/Ouro hold/improve; Twin/Skeram up-jumps provably do **not** reset; regression guard holds.

### PR4 — DEFERRED (needs in-game `/reload` + CLEU) — the off-target tier → **new WO (recommend WO-072)**
Not in this WO's Phase-1 scope. The reserved schema slots make it forward-compatible. Pre-committed discipline (§1.3 graft 5). Concrete roadmap absorbed from D3: heal add-back `h_eff = h_raw − cumHealFrac` (Sulfuron/Jin'do, **overheal-subtracted**); add-counter progress `h_eff = adds_left/8` (Majordomo — turns "excluded" into "estimable"); wave-fraction (Rajaxx via `UNIT_DIED`); Twin second-pool `min(both)`; Chromaggus vulnerability-conditioned profiles via `UnitAura`. Plus a corpus **events extension** (`wcl-v1-to-fight.py` emits `UNIT_DIED`/`SPELL_HEAL` rows — the timeline comments already carry the data) to make PR4 partially offline-provable.

---

## 5. The 1.0.0 release plan

> **Gap-audit note.** The 1.0.0 gap-audit input to this synthesis was a **placeholder stub** (`{"summary":"test","findings":[{"topic":"test"}]}`) — it returned no substantive findings. The MUST/SHOULD/deferred below is reconstructed from **repo state**: WO-069, D-011 (version-on-release-only), D-012 (lock kill-history schema before 1.0), D-013 (regime-aware overhaul), and the **explicitly deferred in-game `/reload`** from the PR #85 merge note. **A real gap audit should be run and merged before sign-off** (checklist item below); treat this section as the working plan, not a completed audit.

### MUST (blocks 1.0.0 / out of alpha)

1. **Regime increments PR1–PR3 merged**, each gate-green, sim byte-identical, corpus-graded (§4). These deliver the structural-tail fixes and the honest non-fixes.
2. **Regime-aware confidence live** — the universal default `confCap` (§1.3 graft 8). This is D-013's motivating defect (Lucifron 1.00 conf at 99% HP); "out of alpha" requires it fixed, not just per-boss.
3. **The deferred in-game `/reload` verification** (open since PR #85) — the entire rhythm library **and** the new regime layer are unverified live. Confirm on a real Anniversary pull: (a) **which id space `ENCOUNTER_START` actually fires** (663 vs 150663 — the dual-aliasing hedges either way, but this must be resolved and the dead alias eventually trimmed); (b) `UnitHealth` pins at ~1.0 during gates so `freeze` engages at the right fractions; (c) **Majordomo's bar truly hides**; (d) no add ever routes a boss regime.
4. **Kill-history schema locked** (D-012) — record shape frozen so local recording is forward-compatible from day one. Verify `docs/reference/kill-history-schema.md` is final and the driver records to it.
5. **Record D-014-IJ** — "regime behavior via injected data + minimal seams, not a strategy-class split" — the decision that refines D-013 (§1.4). Docs are direct-to-`main`.
6. **Run + merge a real 1.0.0 gap audit** (replacing the stub) and fold any new MUSTs before sign-off.

### SHOULD (target for 1.0.0; not a hard block)

- **Reserved CLEU slots populated as data** (`healPolluted`, `addNpcIds`/`addTotal`, `secondPool`) even though unused — declares the upgrade path and lets PR4 land without a schema change.
- **Scoreboard + `estimator-replay.md` updated** with the regime campaign (before→after per structural boss; the health-only↔CLEU boundary stated plainly).
- **CHANGELOG `[Unreleased]`** carries the regime entries; the 1.0.0 bump renames it per D-011.

### DEFERRED (explicitly out of 1.0.0)

- **The CLEU off-target tier** (WO-072 / §4 PR4): heal add-back, add-counters, Twin second pool, Chromaggus vulnerability profiles. Physically health-invisible; needs combat-log plumbing + the corpus events extension. Honest confCap holds the line until then.
- **Naxxramas + Onyxia rhythm/regime profiles** — no Fresh-window corpus exists (probed). Learnable the moment one does; the universal default already gives them regime-aware confidence.
- **The party (5-man) regime** — no 5-man corpus; no unvalidated party path ships.

### 1.0.0 sign-off checklist

- [ ] PR1 merged · gate green · sim byte-identical · Rajaxx/C'Thun/Viscidus/Ouro/Buru + Majordomo acceptance met (§3).
- [ ] PR2 merged · gate green · confCap honesty tier verified with `shown%`/`n` reported · Buru MAPE improved.
- [ ] PR3 merged · gate green · Thekal P2 improved · Twin/Skeram no-reset negative test passing.
- [ ] Whole-corpus **non-regime regression guard** green across all three increments (no collateral drift).
- [ ] **D-014-IJ recorded**; WO-069 body updated with the campaign + boundary.
- [ ] **Kill-history schema locked** (D-012) and recording verified against it.
- [ ] **Real 1.0.0 gap audit run and merged** (stub replaced); any new MUSTs cleared.
- [ ] CHANGELOG `[Unreleased]` complete; build reproducible via `tools/build.sh badger-ttk`.
- [ ] **IN-GAME `/reload` (the gate cannot prove this — engineering principles):**
  - [ ] Encounter id space confirmed (663 vs 150663); dead alias trim scheduled.
  - [ ] `freeze` boundaries match live health fractions on a real pull (Rajaxx gate, C'Thun P1, Viscidus/Ouro plateau).
  - [ ] Majordomo bar hides; no add inherits a boss regime.
  - [ ] Rhythm library behavior delta confirmed live (the still-open PR #85 item).
- [ ] **Human sign-off** → bump `## Version` to `1.0.0`, rename `[Unreleased]`, build, CurseForge Release (D-011). 1.0.0 is a human decision, not an automated bump.

---

**Bottom line.** One architecture: an injected, per-encounter `opts.regime` playbook consumed by nil-guarded, health-anchored seams **inside** the estimator — the frozen-API extension its own header block anticipated. It fixes the health-visible structural tail (freeze/hide/reset/suppress), is honest (confCap, not fake fixes) about the CLEU-invisible tail, learns its numbers from the same even/odd corpus pipeline that produced the 41 rhythm profiles, ships the universal raid-gate guardrail to *every* boss, and is provable byte-identically offline because the estimator freezes itself. Three PRs, each solo-regression-guarded by sim byte-identity and corpus-graded; the ambitious CLEU tail is a scheduled, schema-reserved follow-up, not a risk taken now.
