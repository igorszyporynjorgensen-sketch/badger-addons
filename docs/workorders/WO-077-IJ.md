---
wo: WO-077-IJ
status: Accepted
assigned: IJ
mr:
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-076-IJ.md
related:
  - docs/reference/wcl-corpus-supply.md
  - docs/reference/wo076-lab-vs-client.md
  - docs/reference/estimator-replay.md
  - tools/estimator-perbin.lua
  - tools/estimator-grade.lua
  - tools/learn-rhythm.py
  - tools/learn-regime.py
  - tools/wcl-corpus.py
  - projects/badger-ttk/src/raids/rhythms.lua
---

# WO-077-IJ — The Molten Core spectrum pass: re-learn MC from a phase × tier corpus

- **Created:** 2026-08-02
- **Anchor:** [D-013-IJ] (per-encounter learning) · builds directly on **WO-076** (the honest sticky gate)
- **Accepted:** human directive — *"make a massive learning pass and do Molten Core bosses again … from top
  end, middle and bottom of logged raids … Phase 1 to Phase 5"*, then *"the amount or manner from which you
  learn best"* and *"I approve of your plan"*.

## Why this is not an optimization pass

**Nine of the ten MC bosses have zero fixtures on disk** (only Sulfuron `150669` survives, 60). The MC corpus
was harvested, learned from, and discarded — it is gitignored and disposable by design. So there is **no
honest post-WO-076 baseline for Molten Core at all**, and the profiles the addon ships were learned from
**25 train kills each**, under the per-tick gate WO-076 proved was flattering results by ~15 MAPE points,
from a corpus drawn entirely from **one phase** (the harvester never sends `partition`) at the **fast end**
of the speed leaderboard.

### The floor, measured first (2026-08-02, shipped engine, honest gate, 27 stratified fights/boss)

| boss | n | mean | median | p90 | bias | old record |
|---|---|---|---|---|---|---|
| Shazzrah | 26 | 29.7% | 27.1% | 45.5% | +1.8s | 22.8% |
| Golemagg | 26 | 29.9% | 29.9% | 44.1% | +3.9s | — |
| Magmadar | 24 | 30.6% | 28.5% | 50.6% | +4.5s | 20.5% |
| Ragnaros | 27 | 34.4% | 33.5% | 52.8% | +3.9s | — |
| Garr | 27 | 34.9% | 34.1% | 49.7% | +3.3s | 29.1% |
| Gehennas | 25 | 54.1% | 48.2% | 81.8% | +5.9s | 26.8% |
| Lucifron | 26 | 57.2% | 44.6% | 99.2% | +7.8s | 25.6% |
| Baron Geddon | 27 | 70.2% | 72.8% | 93.2% | +7.9s | — |
| **Sulfuron** | 27 | **105.3%** | 85.6% | 176.7% | **+26.0s** | — |
| Majordomo | 27 | *bar never shows* (`hideBar`) | | | | — |

**Median boss MAPE 34.9%.** Where old records exist the honest number is **1.2–2.2× worse** — the gate
correction and spectrum sampling compounding. **Sulfuron reads roughly double the remaining time** and is
the single largest available win.

## Scope

Branch `feature/WO-077-IJ-mc-spectrum-pass`. Human merges. **No profile ships in the same PR as an
instrument change** — Part A lands and is verified before Part C's numbers mean anything.

### Part A — instrument fixes that MUST precede learning

Three of these would actively corrupt a duration-spanning corpus, which is exactly what Part B builds.

1. **Per-kill weighting in `estimator-perbin.lua`** (`:107-108`, `:136`). Every in-window sample from every
   kill is pushed into one flat pool and a plain median taken, so a 320s kill carries ~20× the weight of a
   15s kill. Harmless when fights are uniform; **damaging on a spectrum corpus** — the slow tier would
   silently dominate the learned caps. Aggregate **per kill first, then across kills**, matching
   `learn-rhythm.py:75`'s per-kill median.
2. **Unify the train/test file ordering.** The Python learners use `sorted(glob.glob(...))` (byte order)
   while `estimator-perbin.lua:53` shells out to `ls`. The "train half" is therefore not guaranteed to be
   the same set in both tools. Make one ordering authoritative.
3. **`learn-regime.py`'s evidence guard counts samples, not kills** (`if n < 20`). At 60+ fixtures it is
   already nearly vacuous and at 450 it is entirely so. Count **kills**.
4. **Short-fight gradeability — measure and disclose, do not silently retune.** `WARMUP 3.0` + `TAIL 6.0`
   means a kill under **9.0s yields zero graded samples**, and those constants were calibrated on 60–240s
   fights while MC's fast tier is 7–16s. Note carefully: `MINTTK = 10` is **correct client behaviour** (a
   fight never predicting past 10s genuinely shows no bar) and must NOT be "fixed". Report per boss what
   fraction of kills and of fight-time is gradeable at all; only then decide whether a duration-aware
   window is justified. **[NEEDS CLARIFICATION]** resolved at execution: default is to disclose, not retune.
5. **`partition` plumbing** — `wcl-corpus.py:100` and `ttk-lab.py:235` never send it, so both are
   structurally single-phase. Fixed by Part B's sampler; the old paths get the parameter or a pointer.

### Part B — the corpus (`tools/wcl-spectrum.py`, one new tool)

Supply is measured and ample (~4,000 kills/boss; see
[wcl-corpus-supply.md](../reference/wcl-corpus-supply.md)). Pull cost is **~1.8s/fight regardless of fight
length** (latency-bound), so ~4,500 fights ≈ 2¼h serial and well under an hour at modest concurrency.

- **9 cells** — 3 phase groups (**prog** P1+P2 · **mid** P3 · **farm** P4+P5) × 3 performance tiers.
- **~450 kills/boss → 50/cell**, variance-weighted: topped up toward ~600 on the high-variance bosses
  (Sulfuron, Baron Geddon, Lucifron, Gehennas per the floor above), nearer ~300 on the clean ones.
- **Tiers are trimmed duration quantiles within each phase group — never raw page position.** Human
  directive, and the data agrees: mid pages are tight (Ragnaros P1 p10 = 57.5–58.9s) while the final page
  alone spans 131.6–260.7s. That tail is wipe-recovery / disconnects / half-AFK raids — it describes the
  *logging*, not the encounter.
- **The curation rule.** A kill may be excluded only for a reason statable **without looking at how the
  estimator scored it** — a duration outlier beyond the trim, a curve that resets, an implausible stall.
  *"It graded badly"* is never a reason. Excluding hard-but-real kills is how a lab flatters itself, which
  is the exact failure WO-076 corrected.
- **Balanced sampling, reweighted afterward.** Equal n per cell maximises power to *detect* tier/phase
  differences; if the shipped profile should lean slower, that is a weighting decision made later on data
  we already hold. Sampling is the expensive, irreversible half.
- **Metadata manifest, free.** Ranking rows already carry `duration`, `startTime`, `melee`, `ranged`,
  `healers`, `itemLevel`. Record them per fight — it costs no extra calls and turns the corpus from curves
  into something that can answer *why* the curves look as they do (see the two hypotheses below).
- **Split as directories** — `train/` (60%) · `val/` (20%) · `test/` (20%), stratified within every cell.
  All four consumers already accept a corpus dir, so this needs **no learner changes**. It replaces the
  single even/odd split, whose fairness today is an accident: after the `<enc>-` prefix the sort key is a
  random report code, so `sorted()` happens to yield a random permutation. **`test/` is touched once, at
  the end.**

### Part C — learn, grade, and answer two hypotheses

Re-learn the nine MC rhythms on `train/`, tune on `val/`, score once on `test/`, against the floor above.
Then test what the old corpus could not:

- **H1 — the "universal slow open" is largely a fixed warm-up artifact.** Learned gate depth correlates with
  fight length at **r = +0.732** (Shazzrah 10.5s → 0.294; Ragnaros 37.5s → 0.548), implying a roughly fixed
  ~3s ramp that occupies a larger fraction of a short fight. If true, nine bosses' "slow open" is
  substantially one effect wearing nine costumes. A duration-spanning corpus separates them.
- **H2 — execute acceleration may belong to the players, not the bosses.** All nine profiles peak at exactly
  `bins[4]` (health 15–20%), precisely Warrior Execute's ≤20% threshold, and MC raids are melee-heavy.
  The manifest's `melee`/`ranged` counts test this at zero extra cost.

**Sulfuron is the priority target** (105.3% / +26.0s) and the only MC boss where a confidence cap can even
fire — everywhere else the bar has already latched before the fight goes wrong.

## Out of scope

- **Any client/addon behaviour change**, including the latch policy (`minConfidenceToShow`, `minTTK`).
  Recon shows caps are viable on **Sulfuron alone**, which makes re-shaping the latch the most promising
  *future* lever — but it is a client change with UX cost and byte-identity risk, and it needs its own
  decision. Record the evidence; do not act.
- **CLEU-tier work.** Majordomo, Sulfuron, Ragnaros, Garr and Shazzrah need combat-log data the addon does
  not consume. Out of reach here.
- **Shipping a profile on re-derived numbers alone** — [D-021-IJ]. Part C produces evidence and a proposal.
- **Any version bump** (D-011).

## Constitution check

- Parts A and B are instrument/lab only; the addon is untouched until Part C proposes a profile, which is
  data under `src/raids/` and gated on held-out `test/` evidence plus human sign-off.
- Learning stays client-side, never CI. The corpus stays gitignored.
- Existing non-regression guards apply: sim byte-identity, and non-MC boss rows unchanged.

## Acceptance criteria

1. Part A landed and verified; per-kill weighting demonstrably changes a known-skewed encounter.
2. Corpus built to plan with a manifest; every exclusion attributable to a stated, grade-blind rule.
3. `train`/`val`/`test` stratified across all nine cells; `test/` provably scored once.
4. Per-boss re-learned profiles graded on `test/` against the floor table above, with the honest gate.
5. H1 and H2 answered with numbers — **including a null result**, which is a legitimate outcome and must be
   reported, not buried.
6. `pnpm validate --skip-nx-cache` green.

## Open question carried forward

In-game **step B5** (`UnitLevel("target") == -1` on an instanced Era boss) is still unverified. If a boss
reports a number, `regimeFor` never fires and the regime layer has been inert since release — which would
moot Sulfuron's cap work, though **not** the rhythm work (rhythms are injected on a separate path).
