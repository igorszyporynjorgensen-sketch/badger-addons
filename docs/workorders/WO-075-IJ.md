---
wo: WO-075-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/95
decision: D-014-IJ
depends_on:
  - docs/workorders/WO-069-IJ.md
  - docs/reference/estimator-regime-design.md
related:
  - projects/badger-ttk/src/raids/regimes.lua
  - projects/badger-ttk/src/engine/estimator.lua
  - projects/badger-ttk/src/live/driver.lua
  - tools/learn-regime.py
---

# WO-075-IJ — Implement the regime structural-tail layer → ship as 0.9.48

- **Created:** 2026-07-30
- **Anchor:** [D-014-IJ] (the Minimal-Seams design) + **[D-018-IJ]** (ship as **0.9.48**, before 1.0.0).
  Human directive on Onyxia's air-phase weakness: "whatever 1.1 does, I want it next but as 0.9.48."
- **Objective:** implement the designed **regime layer** so the estimator handles structural phases a rhythm
  profile provably can't — freeze/immune/reset off health, and **cap confidence so the bar goes QUIET
  instead of showing a confident-wrong countdown**. Full design (schema · seams · per-boss tests):
  [docs/reference/estimator-regime-design.md](../reference/estimator-regime-design.md).

## The architecture (recap — D-014)

One injected, read-only, per-encounter table **`opts.regime`** (mirrors `opts.rhythm`), consumed by ~45
**nil-guarded, health-anchored seams inside `estimator.lua`** — every one a literal no-op when
`self.regime == nil`. The estimator freezes/immunes/resets **itself** off the `h` it already receives, so the
same behavior is provable byte-identically offline (the grader just injects the table) and fires identically
live. Public API `new/reset/sample/ttk` unchanged. Learned numeric fields (`confCap` from held-out
remaining-time dispersion, `freeze` bands from stall quantiles, `resetOnRise`), hand-authored categorical
flags (`hideBar`, `suppressFlush`, `secondPool`, `healPolluted`).

## Onyxia — the motivating case (added to the design's boss set)

The air phase (~50% health, ~40s untargetable, zero damage) is exactly a **stall-gated `freeze` band +
`confCap`**: freeze the countdown while health stalls in-band, and cap confidence so the bar goes quiet
rather than reading long (measured today: ~99% shown, confidently wrong). Onyxia joins the PR1/PR2 boss set;
its regime is *learned* from the corpus harvested in WO-074 (id 151084).

## Scope — the 3 shippable PR increments (design §4), each human-merged, all under 0.9.48

**Universal gate every PR:** `pnpm validate` green · **sim byte-identity** vs `main` (hard fail) · **corpus
regression guard** (every non-regime boss row byte-identical — `regime=nil` ⇒ baseline) · scoreboard run
recorded · `CHANGELOG [Unreleased]`. Branch `feature/WO-075-IJ-<slug>` off this Accepted WO; AI never merges.

- **PR1 — freeze + hideBar + universal default + the lab.** `tools/learn-regime.py` + `assemble-regimes.py`;
  **NEW** `regimes.lua` + `regimes_spec.lua` (`hideBar` Majordomo · stateless `freeze` Rajaxx/C'Thun/Buru-open
  · stall-gated `freeze` Viscidus/Ouro/**Onyxia** · `ns.Regimes.default`); `estimator.lua` seams 1–4,6–7 +
  stall timer + spec; `driver.lua` `regimeFor` + one-shot upgrade + `buildEst` param + spec;
  `estimator-batch.lua` regime injection + regression guard + `shown%`/`n` cols; `.toc`. *Validation:* Rajaxx/
  C'Thun/Viscidus/Ouro/Buru/**Onyxia** MAPE + `shown%` move as designed; Majordomo hidden; sim byte-identical.
- **PR2 — regime-aware confidence at scale + `suppressFlush`.** Per-bin learned `confCap` (Twins/Skeram/
  Chromaggus/**Onyxia air phase**), high-HP `confCap` from healer-death timelines (Sulfuron/Jin'do),
  `suppressFlush` (Buru); `estimator.lua` seam 5 + spec; `learn-regime.py` CV-based caps. *Validation:*
  capped rows drop below `MINCONF` → reported as never-confident (honest quiet, not a silent MAPE win).
- **PR3 — Thekal `resetOnRise` + stall-band tuning + the negative test.** `resetOnRise` for **Thekal 150789**
  (spec asserts both id spaces; `150790` = Gahz'ranka); tuned stall bands; the **Twin/Skeram un-flagged
  up-jump does NOT reset** negative test. *Validation:* Thekal P2 improves; Twin/Skeram provably don't reset.

## Out of scope

- **PR4 / CLEU off-target tier** (heal add-back, add-counter, second-pool) — needs an in-game `/reload` +
  a combat-log-events corpus extension; a **separate future WO** with reserved schema slots (design §5).
- Re-learning the 42 rhythm profiles; the release mechanics (already WO-073).

## Behavior delta

MODIFIED (estimator gains regime seams). By construction **no change where `regime=nil`** — solo/sim/every
un-profiled encounter is byte-identical; only profiled structural bosses change (freeze/quiet/reset). The
0.9.48 release ships the accumulated PRs.

## Constitution check

Principles OK — the design was built around them: single in-estimator injection point (provability),
nil-guarded seams (solo non-regression by construction, wired as a hard gate), learned-not-hand-tuned
numerics (honors the pipeline), specs for every seam + a `regime=nil`-reproduces-baseline invariant. Learning
runs client-side. No `_G` leak. Version bump only at the 0.9.48 release (D-011/D-018).

## Acceptance

- All three PRs merged; `regimes.lua` ships with the structural profiles incl. Onyxia; gate + sim-byte-identity
  + corpus-regression guards green on each.
- Per-boss held-out grades show the designed moves (freeze bosses' MAPE down / honest `shown%`; capped bosses
  quiet not wrong); Onyxia's air phase no longer shows a confident-wrong countdown.
- Cut **0.9.48** via the pipeline (tag `badger-ttk/0.9.48` + GitHub Release). CurseForge + the in-game
  `/reload` remain the human's (D-015). 1.0.0 (now including regime) follows.

**Phases** — PR1 (freeze+hideBar+lab) · PR2 (confCap+suppressFlush) · PR3 (resetOnRise+tuning). Each is a
branch + PR, corpus-graded, human-merged. Detailed per-boss mechanism/acceptance in design §3.

## Outcome — PR1 (PR #95 merged; main green)

The architecture is in and **byte-identical when `regime=nil`** (sim-gated). Shipped: Onyxia's **per-bin
air-phase confCap** + Majordomo `hideBar` + the universal default confCap. **Key finding:** the FREEZE was
the wrong tool for Onyxia — 200 real kills show the air phase is a *slowdown*, not a true stall, so a freeze
over-holds (heavy right tail); the honest fix is the bar going **quiet** there (a confCap): MAPE 57%→44%,
reads-long bias +41s→+20s, shown 99%→55%. The freeze mechanism ships **tested but unused by any PR1 profile**
(its first users are the true-stall bosses in a later PR). An adversarial 6-lens verify + two focused
re-verifies caught & fixed **three real freeze bugs** (cadence-dependent gate, stuck-freeze, delayed in-band
release) + a latent `reset()` bug — each now guarded by a regression test (20 regime tests; gate green).
**PR2** = `learn-regime.py`/`assemble-regimes.py` + confCap-at-scale roster + `suppressFlush`.
