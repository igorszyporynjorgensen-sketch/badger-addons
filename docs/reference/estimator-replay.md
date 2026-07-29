# Replay & grade the estimator against real fights (WO-067)

The "dev mode": feed a real fight's **health curve** through the pure estimator off-client and grade its
predicted TTK against ground truth (the fight already happened, so we know the true remaining time at every
tick). It's the same **Warcraft Logs** pipeline as the history import (D-012): one data source, two uses —
the *summary* feeds the prior; the *full curve* feeds this grader.

```
luajit tools/estimator-replay.lua <fight.lua> [estimator.lua]
luajit tools/estimator-replay.lua tools/fights/sample-boss.lua      # the built-in sample
```

## The fight-file format (what the converter emits)

A fight file returns the boss's health **fraction** over time, polled at 0.15s — the same shape the future
WCL→fight converter (piece 2) will produce. Death is the last sample's `t`.

```lua
return {
    name      = "Kel'Thuzad — 2026-07-29",
    priorRate = nil,          -- optional; the grader also sweeps its own scenarios
    samples   = { { t = 0, h = 1.0 }, { t = 0.15, h = 0.997 }, ... },
}
```

## Grade the rhythm, not the clock

A speedguild's kill and a pug's kill are both valid curves — the estimator's job is to predict **its own**
fight's remaining time. So the headline is **relative** error (% of remaining, length-independent), never
absolute seconds (which just scale with fight length). The grader reports:

- **RHYTHM** — MAPE (mean |error|/remaining), % within 15%, the health at which it locks within 15%.
- **WHERE IT DRIFTED** — the worst moments, each with a **cause** (damage lull · lagging a speed-up ·
  lagging a slow-down · execute · warm-up) and direction (reads too long/short). *This is the lesson:*
  where + why we were off, so we know what to tune.
- **PRIOR SENSITIVITY** — the same fight graded cold / correct / 2×-fast / 2×-slow prior, proving a
  mismatched import (speedguild vs pug) doesn't break live tracking.
- **RHYTHM BY HEALTH** — predicted ÷ actual across the fight's *shape* (~1.0 = tracking).

## First lessons (from the sample — a deliberately dynamic fight)

The sample accelerates (P1 → Bloodlust @45% → execute <20%) with a 5s lull, and the grader immediately
surfaced three real things:

1. **The ceiling.** It reads ~1.3–1.7× **too long** throughout (bias +36s) — a health-only estimator can't
   *anticipate* future acceleration (Bloodlust/execute) it hasn't seen. This is the numeric case for
   **boss-phase profiles** (WO-066 roadmap): knowing execute is coming is the only way to close it.
2. **Lull staleness.** The worst single moment (`t=65s, pred 421s vs actual 106s`) is the 5s no-damage
   window — exactly where feeding `damageable=false` (a boss profile) would hold the estimate steady.
3. **Prior robustness.** Cold / correct / 2×-slow priors all land ~43% MAPE — the prior barely moves it;
   live tracking dominates. A mismatched import (a speedguild's times on your slower kill) does **not**
   break it. Confirms the D-012 group-scaling is a refinement, not a load-bearing dependency.

## The loop

Real fight → replay → grade → read *where + why* it drifted → tune the estimator (or add the boss
knowledge the ceiling demands) → re-score. Piece 2 (the WCL → fight-file converter) turns any logged pull
into a fight file; until then, the sample validates the grader.
