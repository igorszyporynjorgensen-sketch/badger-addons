---
wo: WO-056-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/engine/estimator.lua
  - projects/badger-ttk/src/engine/estimator_spec.lua
  - projects/badger-ttk/src/live/driver.lua
---

# WO-056-IJ — estimator stability: the TTK readout jumps by large margins between swings

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** the TTK estimate is noisy — it "jumps up and down by a large margin in
  seconds", even against mobs 30 levels lower and with a history sample to draw on. Make the readout
  stable without making it sluggish.
- **Noise anatomy (from the code):** the driver samples every 0.15s while melee hits land every ~2–3s, so
  the per-tick rate is a spike train — `r = chunk/0.15` on a hit tick (a 30%-health hit reads as 2.0/sec
  vs a true ~0.1/sec), `r = 0` on the ~16 ticks between. The rate EWMA (λ 0.5–5s) spikes on hits and
  decays between them (TTK balloons ~2.5× across a swing gap), and `TTK = lastH / rate` adds a sawtooth
  as health steps down. Worse, confidence ramps over 8 *ticks* (~1.2s) — not damage events — so the
  history-prior blend `conf·live + (1−conf)·prior` is gone almost immediately; the prior only survives as
  the PRIOR_FLOOR clamp (which still allows 2× swings).
- **Approach:** ultracode multi-phase — (1) a diagnose+design workflow (parallel analysts quantify the
  noise; independent designers propose full redesigns; judge panel scores on stability, responsiveness,
  simplicity, spec-ability, API compat); (2) implement the winning design in the pure estimator (public
  API `new/reset/sample/ttk` and driver contract unchanged; specs extended); (3) an offline **simulation
  harness** proving the fix numerically (synthetic chunky-combat traces: old vs new TTK volatility) plus
  an adversarial verify workflow over the diff and edge cases (heals, immune phases, execute, target
  swap, prior on/off, reactivity extremes).
- **Acceptance:**
  - On a synthetic chunky-combat trace (2.5s swing gaps, 25–40% chunks), the new estimator's TTK
    volatility (per-second max jump + std-dev) is dramatically lower than the current one, with no
    material lag penalty on smooth raid-boss-like traces.
  - Public API + driver contract unchanged; all existing spec behaviours preserved or knowingly amended;
    `pnpm validate` green.
  - **In-game (human):** the readout no longer visibly jumps between swings on low-level mobs.
- **Behavior delta:** MODIFIED (in-game) — the TTK readout is stable between hits.
- **Constitution check:** Principles OK — pure spec'd engine logic; no API/`_G` change; driver untouched
  or minimally touched.

**Phase 1 — Diagnose + design (workflow)** 1. [ ] Analysts + design panel + judges; winning design synthesized.
**Phase 2 — Implement** 1. [ ] estimator.lua rewrite + extended specs; gate green.
**Phase 3 — Verify** 1. [ ] Simulation harness old-vs-new numbers; adversarial verify workflow; bump 0.9.37; rebuild `.release`. PR.
2. [ ] **In-game (human):** stable readout on low-level mobs + normal raid feel.
