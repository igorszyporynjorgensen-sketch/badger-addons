---
wo: WO-067-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/71
decision: ~
depends_on:
  - docs/workorders/WO-066-IJ.md
related:
  - tools/estimator-replay.lua
  - docs/reference/estimator-party-raid.md
---

# WO-067-IJ — replay-and-grade harness: score the estimator vs a real fight's health curve

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** feed real Warcraft Logs fights (a boss's health-over-time) through the
  pure estimator OFF-CLIENT and grade its predicted TTK against ground truth (the known time-to-death), so
  we can validate + tune the estimator against reality. (The "dev mode" idea; piece 1 = the grader.)
- **Approach:** a new `tools/estimator-replay.lua` that loads a **fight file** (`{ name, priorRate,
  samples = { {t, h}, … } }` — the boss HP fraction over time, exactly what a WCL export/converter would
  produce) + an estimator, replays it at the driver's 0.15s cadence, and at each tick records predicted
  TTK vs actual remaining (`death − t`). Prints a grade: MAE, bias, within-20%, convergence, worst
  over/under, warm-up, and a per-decile table (predicted vs actual at 90%…10% health). Ships a synthetic
  "realistic boss" fight as a stand-in to validate the grader until a real WCL trace is pasted in. Pure
  dev tooling — the addon is untouched.
- **Piece 2 (later, not this WO):** the WCL → fight-file converter (the boss HP curve from the WCL API's
  damage-event target HP or resources graph) — same external-converter family as the D-012 import.
- **Acceptance:** `estimator-replay.lua <fight> [estimator]` grades a fight and prints sensible numbers on
  the sample; `pnpm validate` unaffected.
- **Behavior delta:** none (in-game) — a dev harness.
- **Constitution check:** Principles OK — tooling only; no shipped-code/`_G` change; no version bump (D-011).

**Phase 1** 1. [x] estimator-replay.lua + sample fight; validate.
**Phase 2** 1. [x] document the fight-file format + usage. PR.
