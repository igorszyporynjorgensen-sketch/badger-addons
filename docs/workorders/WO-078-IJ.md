---
wo: WO-078-IJ
status: Accepted
assigned: IJ
mr:
decision: D-022-IJ
depends_on:
  - docs/workorders/WO-077-IJ.md
related:
  - docs/reference/mc-spectrum-findings.md
  - projects/badger-ttk/src/engine/estimator.lua
  - projects/badger-ttk/src/live/driver.lua
---

# WO-078-IJ — Investigate the learned opening baseline: benefits AND drawbacks

- **Created:** 2026-08-02
- **Anchor:** [D-022-IJ](../decisions.md) part (b)
- **Accepted:** human directive — *"make a WO investigate benefits and/or drawbacks of my opening idea, and
  then do a small investigation by working that WO"*.
- **Investigation only.** No addon change, no profile change, no branch required for the measurement
  itself. The deliverable is evidence and a recommendation.

## The idea being tested

Human, 2026-08-02: *"as you start building up and indeed ramping up confidence and fight has just started —
you could have a 'reasonable time to kill for this DPS in first seconds' and work off that as an assumed
baseline."*

Formally: over the first `W` seconds measure the early kill rate `r` (fraction of max health per second),
then predict total duration as `k / r`, where `k` is a **per-boss constant learned from real kills**
(`k = duration × early-rate`). Naive linear extrapolation is the special case `k = 1.0`.

## Why it looks promising

The opening is the estimator's worst band **and** the one where it is most confident — measured over the
WO-077 val corpus, throttled, returning player:

| first N sec | mean err | median | **mean confidence** |
|---|---|---|---|
| ≤ 2s | 69.0% | 70.6% | **0.96** |
| ≤ 6s | 62.0% | 65.4% | 0.68 |
| ≤ 20s | 40.6% | 41.0% | 0.87 |

Confidence is *inverted* against accuracy in the opening. And naive linear extrapolation — roughly what a
rate estimator does before it has evidence — over-predicts fight length by **3× to 33%** at 3 seconds
(median error 1699.9%). First pass, fit on `train`, evaluated on `val`:

| window | learned baseline (median) | naive linear (median) | shipped estimator (median) |
|---|---|---|---|
| 3s | **61.1%** | 1699.9% | ~70% |
| 5s | **54.3%** | 692.5% | ~66% |
| 8s | **43.2%** | 331.1% | ~60% |

Measured `k` at 3s: Sulfuron 0.03 · Geddon 0.07 · Garr 0.09 · Golemagg 0.10 · Shazzrah 0.17 ·
Lucifron 0.18 · Magmadar 0.19 · Gehennas 0.22 · Ragnaros 0.35.

## The questions this WO must answer

**Q1 — Does it survive the throttle?** *The decisive one.* WO-077's re-learned profiles were a −14.4
improvement alone and a **significant regression** (+1.42, CI [+0.44, +2.40]) once the rise throttle
existed, because they were compensating for rubber-banding. The opening baseline may be doing the same
thing. **Measure it with and without the throttle, paired.** If it only helps without the throttle, it
does not ship.

**Q2 — Does it survive the history prior?** `driver.lua:219` already passes a prior derived from the
player's own past kills, which is itself an opening estimate and is why the bar latches at 0.4s with a sane
value. The baseline may be redundant for a returning player and only help on a first kill — a much narrower
case that self-heals after one kill.

**Q3 — What are the failure modes?** The first pass showed **ugly means against good medians** (110–300%
mean vs 43–61% median). Characterise the tail: which fights blow up, by how much, and is the failure
bounded? A change that improves the median while occasionally producing an absurd number is worse than one
that does neither, because the absurd number is what the player remembers.

**Q4 — Where does it stop helping?** Find the crossover: at what elapsed time does the estimator's own
evidence beat the baseline? That is the natural hand-off point.

**Q5 — What happens on an unknown boss?** `k` is per-encounter learned data. A boss with no `k` (a
world boss, an un-harvested encounter, or **any boss at all if step B5 shows `UnitLevel ~= -1`**) gets
nothing. Is there a safe universal fallback `k`, and how much worse is it than the per-boss value?

**Q6 — What does it cost?** Bytes of shipped data, an estimator seam, and the risk to the `regime == nil`
byte-identity guarantee the layer rests on.

## Method

- Fit `k` on `train/` only; evaluate on `val/`. **`test/` is SPENT** — WO-077 scored it once, so any
  result tuned against it is no longer honest. If a final verdict is needed later it requires fresh
  fixtures.
- Report by band (opening / middle / last quarter / final 10%), not as a single MAPE — one aggregate
  hides all four regimes, which is how the rubber-band went unnoticed for so long.
- Paired per-fight comparisons with confidence intervals. Point estimates manufacture false positives
  (WO-077 F7).
- Median alongside mean throughout; the repo's own precedent is that median beats mean on chaotic bosses.

## Out of scope

- Any addon change. If the evidence is good this produces a **recommendation** and a follow-up WO.
- Re-harvesting. The existing 1,061-fixture corpus is sufficient and costs ~2.5h to rebuild against the
  measured 800-calls/hour budget.
- The rise throttle itself (D-022(a)) — already measured, ships or not on its own evidence.

## Acceptance criteria

1. Q1–Q6 answered with numbers and confidence intervals.
2. A clear recommendation: ship / do not ship / ship only under stated conditions.
3. A **null or negative result is an acceptable and complete outcome** and must be reported as such, per
   WO-077's precedent.
