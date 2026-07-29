---
wo: WO-066-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/70
decision: ~
depends_on:
  - docs/workorders/WO-056-IJ.md
related:
  - tools/estimator-sim.lua
  - docs/reference/estimator-party-raid.md
---

# WO-066-IJ — validate the estimator for party/raid + composition; document the analysis

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** in-game testing has only been solo (an overleveled warrior vs single
  mobs; a level-4 hunter vs even mobs). Validate — off-client — how the estimator behaves in a
  party/raid, including how raid **composition** (healer-heavy · warrior/melee-heavy · caster-DPS-heavy ·
  many-melee) affects the estimate. Document the analysis + a roadmap.
- **Approach:** extend `tools/estimator-sim.lua` with party/raid traces that model each regime, run
  old-vs-new, and record the numbers. Write `docs/reference/estimator-party-raid.md` with the analysis,
  the composition breakdown, the numbers, and the concrete follow-ups (boss-phase detection; optional
  prior-by-comp). Pure tooling + docs — the shipped addon is untouched (no `.toc` change).
- **Traces to add:** caster/DoT-smooth · many-melee-averaged · healer-heavy-slow · mid-fight heroism
  surge · a boss **immune-phase** window (fed both as the driver does today = `damageable=true`, and as a
  boss-profile would = `damageable=false`) to quantify the one real gap.
- **Acceptance:** the harness runs the new traces green; the reference doc records the numbers + roadmap;
  `pnpm validate` unaffected.
- **Behavior delta:** none (in-game) — a dev harness + design doc.
- **Constitution check:** Principles OK — tooling + docs; no shipped-code/`_G` change; no version bump (D-011).

**Phase 1** 1. [x] sim harness party/raid + composition + immune traces.
**Phase 2** 1. [x] doc the analysis + numbers + roadmap. PR.
