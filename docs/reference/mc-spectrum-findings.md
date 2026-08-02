# The Molten Core spectrum pass — what the data said (WO-077)

**Date:** 2026-08-02 · **Branch:** `feature/WO-077-IJ-mc-spectrum-pass` · **WO:** [WO-077-IJ](../workorders/WO-077-IJ.md)

Running record of measured findings. Everything here is a number from this repo's own tools, not an
argument. Where a prediction was wrong it is marked **REFUTED** and left in — the wrong predictions were
the useful part.

## 0. The situation this started from

Nine of the ten MC bosses had **zero fixtures on disk** (the corpus is gitignored and disposable), so there
was no honest post-WO-076 baseline for Molten Core at all. The shipped profiles were learned from **25
train kills each**, under the per-tick gate WO-076 proved was flattering results by ~15 MAPE points, from a
corpus drawn entirely from **one phase** at the **fast end** of the speed leaderboard — because
`wcl-corpus.py:100` never sends `partition` and its page loop stops at page 8.

## 1. The floor, measured before touching anything

Shipped engine, honest sticky gate, 27 stratified fights/boss (3 phase groups × 3 tiers), then re-measured
with a history prior once F1 was fixed:

| boss | n | cold | **history-backed** | old record |
|---|---|---|---|---|
| Magmadar | 24 | 30.6% | **28.9%** | 20.5% |
| Shazzrah | 26 | 29.7% | 30.7% | 22.8% |
| Golemagg | 26 | 29.9% | 30.1% | — |
| Garr | 27 | 34.9% | 34.6% | 29.1% |
| Ragnaros | 27 | 34.4% | 35.2% | — |
| Gehennas | 25 | 54.1% | 53.2% | 26.8% |
| Lucifron | 26 | 57.2% | 57.4% | 25.6% |
| Baron Geddon | 27 | 70.2% | 71.5% | — |
| **Sulfuron** | 27 | **105.3%** | **78.7%** | — |
| Majordomo | 27 | *bar never shows* (`hideBar`) | | — |

**Median boss 34.9% cold / 35.2% history-backed.** Where old records exist the honest number is
**1.2–2.2× worse** — the WO-076 gate correction and spectrum sampling compounding, not an addon regression.

## 2. Five instrument defects, all measured

The lab was wrong in ways that would have corrupted the very corpus this pass builds.

**(a) A kill's weight was its duration.** `estimator-perbin.lua` pooled every in-window sample into one
flat list per bin, so a 320s kill outvoted a 15s kill ~20:1. Harmless when fixtures are uniform, corrupting
the moment a corpus spans durations on purpose. Measured on Rajaxx (24–321s): bin 19 reported **147%**
median relative error where the per-kill median is **71%**; bin 18, **153%** vs **67%**. Rajaxx's shipped
caps were derived from those inflated figures.

**(b) The graders modelled a player who had never killed the boss.** They built `Estimator.new` without
`priorRate`, while `driver.lua:219` always passes one and `core.lua:78-79` default history **on**. This is
WO-076's defect one layer down. The correction is real but **concentrated**: every boss moves within ±1.7
points except **Sulfuron, which drops 105.3% → 78.7%** (bias +26.0s → +16.1s). That is coherent — Sulfuron
is the heal-polluted encounter, so when healing corrupts the curve the *prior* is what carries the estimate.

**(c) The evidence guard counted samples, not kills.** `learn-regime.py`'s `n < 20` test read a sample
count; at 60+ fixtures thousands of samples per bin cleared a threshold of 20 unconditionally.

**(d) The fastest MC kills cannot be graded at all.** `WARMUP 3.0` + `TAIL 6.0` means a kill under **9.0s**
yields zero graded samples. Only **3%** of sampled MC kills are wholly ungradeable, but coverage is
strongly per-boss: we grade **52%** of a Shazzrah fight versus **84%** of a Ragnaros one. Since the window
always removes the opening (worst-read) and the ending (best-read), that is a per-boss bias, not uniform
noise. **Disclosed, not retuned** — retuning would invalidate every historical number for a 3% gain. Note
`MINTTK = 10` is *correct* client behaviour and must not be "fixed".

**(e) The harvester was budget-blind.** See §5.

## 3. H1 — the "universal slow open" is NOT a fixed warm-up. **REFUTED.**

The prediction: learned gate depth correlates with fight length at r = +0.732 across bosses (Shazzrah 10.5s
→ 0.294; Ragnaros 37.5s → 0.548), implying a roughly fixed ~3s ramp that simply occupies more of a short
fight — nine bosses' "slow open" being one effect wearing nine costumes.

The within-boss test says otherwise. On Sulfuron, fast raids spend **~5s** in the top 5% of health and slow
raids **~22s**. The opening slowness **scales with fight length**; it is not a fixed cost. The cross-boss
correlation still stands, but the within-boss test is the cleaner instrument and it disagrees.

## 4. H2 — the endgame rush belongs to the raid, not the boss. **SUPPORTED, and replicated.**

All nine shipped profiles peak at exactly `bins[4]` (health 15–20%) — precisely Warrior Execute's ≤20%
threshold — and MC raids are melee-heavy. If that peak is a property of the *players*, it should vary with
raid speed. It does.

`tools/tier-invariance.py` splits an encounter's kills into duration terciles and compares the scale-free
per-bin profile:

| boss | kills | tercile range | mean \|SLOW−FAST\| | **drift per × of range** | monotone bins | largest divergence |
|---|---|---|---|---|---|---|
| Sulfuron | 590 | 1.7× | 0.232 | **0.340** | **16/20** | **−0.549** @ 20–15% |
| Baron Geddon | 100 | 1.4× | 0.108 | **0.261** | 8/20 | −0.347 @ 5–0% |

Raw divergence is not comparable across encounters — a corpus spanning 14–52s cannot show as much drift as
one spanning 14–116s — so the tool reports **drift per × of sampled range**. Normalised, the two bosses
agree to the same order of magnitude.

Both put their largest divergence in the **endgame**, and in both the slow tercile kicks **weaker**
(Sulfuron 2.57× vs 2.02× at 20–15% health). Sulfuron's 16/20 monotone bins make it a systematic trend
rather than noise.

**So the shape is not tier-invariant, and the corpus's fast-end bias is not harmless.** A profile learned
from ranked kills will tell a slow raid the boss is nearly dead too early — and the error lands in the last
20% of health, where the bar is watched most closely.

## 5. What the corpus can and cannot be

**The budget is the binding constraint, and it is not latency.** Measured: `x-ratelimit-limit: 800`, **1
point per call**, sliding ~1-hour window, on a **shared** key. A fight costs ~2 calls, so the ceiling is
~**400 fights/hour**. The first harvest ran unpaced and took **HTTP 429 after 691 fights**. The original
~4,500-fight plan was a ~12-hour job, not the "well under an hour" it was sized as — an error that came
from measuring per-fight *latency* (1.8s) and never checking the *quota*.

**"The bottom of logged raids" does not exist in this data.** WCL rankings are **guild-deduplicated** — 50
rows = 50 distinct `guildID`. Every row is one guild's **best kill of that phase**, a min-of-N. So the slow
tier is *bad guilds' best nights*, never anyone's bad night, and **no wipe or recovery can enter the
corpus**. Combined with the page-20 ceiling (`metric=speed` exposes at most the fastest 1000 kills of a
phase), four independent selection effects all push the same way. Conclusions must be stated as *"ranked
guild-best kills from logging raids"* — never "the bottom of the ladder".

**Tiers are trimmed duration quantiles, never page position.** The final leaderboard page is not "slow
raids" — it is the pathological tail. Measured: Ragnaros P1 page 10 spans a tight 57.5–58.9s while the
final page alone spans **131.6–260.7s**. Training on that teaches the estimator noise.

**The curation rule.** A kill may be excluded only for a reason statable **without looking at how the
estimator scored it** — a duration outlier past the trim, a curve that resets, an implausible stall. *"It
graded badly"* is never a reason. Excluding hard-but-real kills is how a lab flatters itself, which is
precisely the failure WO-076 corrected.

## 6. H3 — absolute DPS (human proposal)

The estimator sees only the health *fraction*, so it reasons in "% per second" and cannot tell a speedguild
from a pug. `wcl-v1-to-fight.py` always read the exact `maxHitPoints` and then **discarded** it; it is now
preserved as `maxHP` (with `size`) in every fight file. The live client can compute the same quantity from
`UnitHealthMax("target")`, since Classic boss health is fixed and does not scale with raid size.

**The arithmetic caveat, stated plainly:** `maxHP` cancels in the instantaneous calculation — TTK =
remaining HP ÷ DPS is algebraically identical to `h ÷ (dh/dt)`. The value is not in the current sum. It is
in **cross-fight comparison** (matching early HP/s against the corpus) and **forward projection**.

**First measurement — the simplest form tests worse.** Anchoring raid output to elapsed time rather than
boss health, on 590 Sulfuron kills:

| anchor | median spread (IQR/median) |
|---|---|
| **Health-anchored** (what ships) | **0.352** |
| Time-anchored (a DPS-curve model) | 0.452 |

Per-bin, health anchoring is flat at ~0.32 through most of the fight while time anchoring is catastrophic
early (1.88 in the first 6 seconds). So projecting a DPS curve over *time* would be a downgrade exactly
where the bar most needs to be right. Both representations agree the **opening is the high-variance
region** (1.19 top health bin; 1.88 first 6s).

But §4 makes the underlying idea load-bearing anyway: **because shape depends on tier, the client must
infer which tier it is in**, and early absolute HP/s is the only signal available to do it. What was
proposed as "help classify the fight" turns out to be the missing input for choosing a profile at all.

## 6b. The rubber-band — the largest finding of the pass, and it needed no corpus

Found by **watching a fight**, not by reading a number. `ttk-scope` showed the displayed countdown
jumping `27.3s → 137.4s` and `41.1s → 214.7s`, each inside a single 0.15s tick; on the corpus's worst
fight it reached **43 minutes** on a boss with 36 seconds left. Measured: **13.2% of ticks** carry an
upward jump >2s, worst **+2401s**. No aggregate had surfaced this — a fight-average MAPE blends
"reads 2401s long" and "reads 0.3s short" into one number.

**The fix is asymmetric and physically motivated.** A real time-to-kill falls at one second per second,
so downward movement is almost always genuine while a large upward jump is almost always noise — a raid
cannot slow by 174 seconds inside 150ms. Capping only the RISE removes the noise without costing any
reactivity to a boss that is genuinely melting.

| rise cap | MAPE | shown% | latch | jumps >2s | worst jump |
|---|---|---|---|---|---|
| none | 95.3% | 93.4% | 5.7s | 13.2% | +2401s |
| 4 s/s | 36.0% | 93.4% | 5.7s | 0.0% | +7s |
| **2 s/s** | **35.1%** | **93.4%** | **5.7s** | **0.0%** | **+4s** |
| 1 s/s | 36.7% | 93.4% | 5.7s | 0.0% | +2s |
| 0.5 s/s | 40.0% | — | — | 0.0% | +1s |

Too tight is worse — at 0.5 s/s the display lags genuine slowdowns. The optimum is ~2 s/s.

**It is not free, and calling it free was wrong.** Two Golemagg kills, same boss, same shipped profile:

| | P4 farm (39.3s) | P1 progression (31.4s) |
|---|---|---|
| jumps unthrottled | 21 | 5 |
| verdict | 20.7% → **12.8%** ✓ | 11.0% → **16.4%** ✗ |

On an already-clean fight the cap blocks legitimate upward corrections and costs points. Across the val
corpus, by unthrottled jump count:

| jumps | fights | off | on | delta | % helped |
|---|---|---|---|---|---|
| 1–3 | 4 | 24.0% | 17.2% | −6.8 | 100% |
| 4–10 | 14 | 41.2% | 23.3% | −17.9 | 93% |
| 11–25 | 54 | 59.0% | 26.1% | −32.8 | 98% |
| 26+ | 101 | 86.6% | 31.8% | −54.8 | 99% |

**No fight in the corpus had zero jumps** — the rubber-banding is universal, only its severity varies.

### Three follow-ups, all REFUTED by measurement

- **Volatility as a show gate.** Buys 8 points, charges 37pp of `shown%` and a latch delay of 5.7s → 16.2s,
  and adds only 2.2 points on top of the throttle. Rejected. Volatility stays a *diagnostic*: its error
  deciles run 44%…153% monotonically, where the shipped confidence signal is flat noise
  (103, 99, 82, 85, 76, 84, 59, 100, 162, 87 over 31,195 ticks) — **the confidence the show gate consults
  does not predict error at all.**
- **A relative (%-of-estimate) cap for the endgame.** Degrades the endgame monotonically (28.3% → 33.8%),
  because late rises are often genuine recoveries from having fallen too short.
- **An adaptive cap** that loosens while the estimate is calm. Every variant is worse than the fixed cap
  (30.8–31.9% vs 30.6%).

### Accuracy by how much of the fight remains (throttled, returning player)

| remaining ≤ | 100% | 75% | 50% | 25% | 10% |
|---|---|---|---|---|---|
| mean / median | 30.8 / 27.3 | 24.5 / 21.3 | **24.4 / 21.1** | **22.4 / 19.9** | 28.0 / 24.4 |

Accuracy improves through the fight and then **degrades again in the final 10%** — the execute lag. The
true kill rate climbs (measured on one Golemagg: 2.34 → 3.99 %/s) and a backward-looking rate cannot
anticipate it. That is the one band the throttle cannot help and the one band a per-encounter profile is
uniquely able to fix, which is where the corpus work properly belongs.

## 7. Out of reach from health alone

- **Majordomo** — `hideBar` makes `estimator.lua:275-277` return `(nil, 0)` before any rate exists, so his
  MAPE is undefined *by construction* and "bar hidden on 100% of ticks" is a lab tautology. Dropped from
  the harvest; nothing measurable is lost.
- **Ragnaros's submerge** fires at ~180s, above every trim cut — so a directive-compliant corpus encodes
  "Ragnaros never submerges": true of the ranked population, false of a pug.
- **Confidence caps are viable on Sulfuron alone.** On every other MC boss the bar has already latched
  before the fight goes wrong, so no cap can fire (WO-076's sticky gate). The MC win must come from rhythm
  profiles, not the regime layer.
- **Raising `minConfidenceToShow` is inert** for the returning player: a history prior's evidence share
  starts at exactly **1.0** (`estimator.lua:314-319`, WO-061 by design), so the threshold changes the latch
  by zero ticks.

## 8. Still unverified, and it gates a lot

In-game **step B5** — `UnitLevel("target") == -1` on an instanced Era boss. `driver.lua:96-101` `rhythmFor`
and `driver.lua:186-193` `historyKey` carry the **same** test as `regimeFor`, so if a boss reports a number
instead of −1, the rhythm profiles *and* the history prior have never fired for anyone. That would not
merely moot the regime layer; it would invalidate the premise of this entire pass. It is a ten-second
`/run` in game.
