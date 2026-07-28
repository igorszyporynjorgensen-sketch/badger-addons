---
wo: WO-061-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/64
decision: ~
depends_on:
  - docs/workorders/WO-056-IJ.md
related:
  - projects/badger-ttk/src/engine/estimator.lua
  - projects/badger-ttk/src/live/driver.lua
---

# WO-061-IJ — estimator verify follow-ups (4-lens adversarial pass on WO-056)

- **Created / Updated:** 2026-07-28
- **Objective:** the post-merge 4-lens verify workflow (30+ probes, 13 mutants, all runnable repros)
  confirmed the WO-056 headline numbers and found 2 functional HIGHs, 2 spec-coverage HIGHs, and a
  display-blanking MEDIUM. Fix them.
- **Fixes:**
  - **HIGH — PRIOR_FLOOR binds forever** (inherited, but it neuters WO-056's slowdown flush): a mob
    genuinely 2×+ slower than its recorded history stays clamped at ~2× history no matter the live
    evidence (probe: 11.3s shown vs 61s truth). Fix: the floor still caps STALENESS (frozen spec #8
    intact) but is DISABLED once a jumpLo (slowdown) flush fires — the design already trusts that
    two-consecutive-events signal. + convergence spec.
  - **HIGH — conf gate re-arms per retarget**: swap to an add and back → ≥3.45s bar blackout; inside
    the last ~13s of a boss, bars never re-show. Two-part fix: (a) confidence now counts the prior's
    evidence share (`conf = max(liveConf, priorT/den)`) — a history-backed pull shows instantly, the
    slider still gates unknown mobs as labeled; (b) the driver keeps a 90s per-GUID continuation cache
    (estimator + shown + history-recording refs) so a swap-back resumes instead of restarting.
  - **MEDIUM — countdown 0 blanks the display**: an overdue countdown reaching exactly 0 while the
    target lives made the TTK text and ALL utility bars vanish (display maps ≤0 to no-data). Live ttk
    now floors at 0.05s; nil stays the only "unknown".
  - **Spec HIGHs**: adopted the verify panel's mutation-tested gap cases (down-flush, direction-flip,
    in-band disarm, heal non-vacuous + post-heal chunk, SPAN_CAP, reset-restores-prior, priorWeight,
    conf-MIN, execute-exact; 3 gate-skip cases in driver_spec).
- **Recorded as known / later:** heal gross-vs-net rate (LOW, v1 design); immune-phase feed unreachable
  from live play (pre-existing driver simplification); sim-harness methodology notes (oracle-prior
  traces, adapt metric definition, countdown-affine cdev) — harness improvements, not product defects.
- **Acceptance:** slow-regime-with-prior converges to live truth; retarget-back keeps bars; countdown
  never blanks a live target; all adopted cases green; `pnpm validate` green.
- **Behavior delta:** FIXED (in-game) — history no longer caps slow fights; retargeting keeps the bars;
  no end-of-fight blanking. History-backed pulls show instantly again.
- **Constitution check:** Principles OK — pure estimator + spec'd; the GUID cache is driver edge.

**Phase 1** 1. [x] estimator floor-release + prior-conf + 0.05 clamp; driver GUID cache; adopt gap specs.
**Phase 2** 1. [ ] gate green; bump 0.9.42; rebuild `.release`. PR. 2. [ ] **In-game (human):** retarget test; slow-solo of a history mob.
