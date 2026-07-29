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

## First REAL fight: Lucifron (MC 40) — corrected by the exact API pull

Piece 2 turned a real Anniversary MC kill into a fight file — first via a paginated CSV export, then (much
better) via the **V1 API**, whose damage events carry the target's exact `hitPoints`/`maxHitPoints`, so the
boss curve is **read directly, not reconstructed**. The two disagreed, and **the API is the truth:**

| source | duration | shape | graded MAPE |
|---|---|---|---|
| CSV export (reconstructed) | 31.1s | "flat ~99% for 8s, then a burst" | ~1069% |
| **V1 API (exact hitPoints)** | **25.6s** | **fairly steady decline, mild end-accel** | **65.7%** |

The CSV's dramatic "adds gate" was an **artifact** — its clock started ~5.5s before the encounter (pre-pull
shots) and it mixed in cleave. On the exact curve — Lucifron (`encounterID 150663`, maxHP **351,780**,
40-player) — the estimator actually behaves *reasonably*:

- **The bar stays hidden ~5s** while confidence builds (0.07 → 0.40 → shows at 0.72), then tracks down
  cleanly. **No 30-minute read anywhere** — the confidence gate does its job on clean data.
- **It still reads too long** — bias **+8.9s**, MAPE **65.7%**, locks within 15% by ~41% HP. A
  backward-looking rate can't anticipate even the *mild* end-acceleration (cooldowns/execute). The real,
  calm version of the ceiling — not a catastrophe.
- **The add was NOT killed first** (Flamewaker Protector had **73k HP at the kill**). Low-tier groups often
  just **cleave everything at once** rather than kill adds first — so the *same encounter has
  strategy-dependent rhythms*.

**Two meta-lessons, both load-bearing for the overhaul:**

1. **Data quality decides the conclusion.** The CSV nearly sent us chasing a phantom "confident 30-minute
   adds-gate" bug. The exact API pull (hitPoints) is ground truth — use it. *("Learn where you were wrong"
   applied to the analysis itself.)*
2. **One encounter, many rhythms.** Cleave-all vs adds-first, speedguild vs pug — the same `encounterID`
   varies. A per-encounter profile must be **learned from many kills across tiers and strategies**, and the
   live estimator must track the *actual* curve, never assume a fixed shape. This is the data engine the
   API + grader now enable: **pull any encounter at any performance tier on demand and "learn" it.**

The core [D-013] motivation still holds — a solo-tuned chunk-clock stretched onto raid curves reads
systematically long and can't anticipate — just at a *calmer severity* than the CSV first suggested.

## Where this points (per-encounter, learned from logs)

1. **Per-encounter rhythm profiles.** From many logged kills of an encounterID, learn its characteristic
   normalized shape + phase markers (adds-down HP, execute HP, typical end-game multiplier). Stored/keyed
   exactly like the D-012 history.
2. **Rhythm archetypes.** Cluster encounters by curve shape (adds-gate-then-burst · steady · front-loaded ·
   immune-gap · execute-heavy). A live fight is matched to its archetype.
3. **Anticipatory "modulator."** The matched archetype/profile lets the live estimate *lead* the known
   acceleration instead of lagging it — the only way to close the ceiling the sample fight first exposed.

None of this is a generic estimator change: it's a per-encounter prior the live estimator consults **when
it recognises the encounter**, and falls back to today's behaviour when it doesn't.

### Corpus curation (which kills to learn from)

The learning corpus is not "any log ever." A raid's rhythm shifts across its own lifecycle, so kills are
curated:

- **Relevance window.** Only kills from when the raid was *current content* — **release → the next tier**
  (for MC, up to the following raid / BWL; for a season, its `classicSeasonID`). WCL reports carry dates
  and a season id, so the puller can filter. A kill logged after the next tier's gear/nerfs exists no
  longer describes *this* fight.
- **Span the arc as the spectrum.** Within that window, sample **progression → farm** (green-geared, no
  world buffs → fully geared, world-buffed) and **pug → speedguild**. That range *is* the performer
  spectrum the human wants — a profile that knows both the slow and the fast end, not one point.
- **Exact data only.** Reconstruct nothing that the API gives exactly: use per-event `hitPoints`
  (`wcl-v1-to-fight.py`), which the Lucifron CSV-vs-API split proved decisive (1069% → 66% MAPE from the
  same fight, different data quality).

## Fetching real fights — the API (reachable from tooling)

The WCL v2 API is reachable from the dev environment (OAuth/GraphQL respond; only the *web pages* 403).
So `tools/wcl-to-fight.py` (OAuth client-credentials) pulls a whole fight — all targets + timeline — into
one file with no row cap. Needs a free, **read-only** WCL API client (id + secret). The CSV path
(`tools/wcl-csv-to-fight.py`) stays as the no-credentials fallback (boss-target-filtered export).

## The loop

Real fight → replay → grade → read *where + why* it drifted → **learn that encounter's rhythm** (or add
the phase knowledge the ceiling demands) → re-score. Lucifron is the first entry.
