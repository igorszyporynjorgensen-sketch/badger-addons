---
wo: WO-056-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/62
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

- **Baseline (simulation harness `tools/estimator-sim.lua`, current estimator, reactivity 0.5):**
  | trace | cdev | worst 1s jump | rmse | burst adapt |
  |---|---|---|---|---|
  | chunky + prior | 0.61s | **7.53s** | 4.42s | — |
  | chunky no prior | 0.82s | **13.19s** | 4.10s | — |
  | raid smooth | 0.51s | 6.98s | 2.62s | — |
  | burst ×2 @45s | 0.27s | 25.11s | (pre-burst-dominated) | 3.75s |
  `cdev` = mean per-tick deviation from an ideal 1s/s countdown; `jump1s` = worst readout jump the user
  can see in one second. Target: jump1s on chunky traces down by ~an order of magnitude; adapt ≤ ~5s.

**Phase 1 — Diagnose + design (workflow)** 1. [x] 3 analysts + 4 designs + 3 judges (each ported all
designs AND all 9 specs into executable harnesses). **Unanimous winner: Chunk-Clock** (event-interval
fading ratio) with two mandated grafts: frozen jump baseline (the un-grafted detector measurably never
fired on a ×3 burst) + run-evidence re-seed on flush. Rejected: D4's output governor (ttk() feeds the
render-model's fire-timing geometry — the estimate must stay honest).
**Phase 2 — Implement** 1. [x] estimator.lua rewritten + specs extended (9 frozen pass unmodified,
10 new guards, 19 total); gate green.
**Phase 3 — Verify** 1. [x] Harness old→new: chunky+prior worst-1s-jump **7.53→2.39s** (residual = the
hit re-sync; countdown dev 0.61→**0.01s**/tick, rmse 4.42→**0.07s**); no-prior jump 13.19→**1.00s**;
burst ×3 adoption 4.35→**0.45s** (flush); ×2 rides the window 8.4s (designed — crits must never flush).
Bumped 0.9.40; rebuilt `.release`. PR #62; adversarial verify workflow running.
2. [ ] **In-game (human):** stable readout on low-level mobs + normal raid feel.
