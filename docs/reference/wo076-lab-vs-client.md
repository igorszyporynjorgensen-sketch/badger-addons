# The lab vs the client — what changed when the grader started modelling the show gate (WO-076)

**Date:** 2026-08-01 · **Branch:** `fix/WO-076-IJ-lab-models-client` · **WO:** [WO-076-IJ](../workorders/WO-076-IJ.md)
· **Anchor:** the PR #97 verification ([D-021-IJ])

Instrument-only. The addon is unchanged except one spec correction. What changed is what we *know*.

## The defect, in one line

`driver.lua:68` consults `minTTK` and `minConfidenceToShow` only while `not wasShown`. Once the bar
latches it stays. The three graders re-tested confidence on **every tick independently**, and
`learn-regime.py` derived each bin's cap as if the bar could be hushed there. So caps were learned and
graded under a rule the client does not implement.

## Headline — the estimator was never as good as the lab said

`estimator-batch.lua <corpus> --shipped`, same corpus (921 fixtures), old lab vs new:

| | old lab | **honest lab** |
|---|---|---|
| MAPE mean | 55.6% | **70.2%** |
| MAPE median | 47.5% | **54.6%** |
| p90 | 86.3% | **103.2%** |
| bias | +10.4s | **+15.6s** |
| worst single fight | 350.2% | **1751.1%** |
| fights graded | 788 | 778 |

The 10 lost fights are correct, not a regression: with `minTTK = 10` modelled, a kill whose predicted TTK
never reaches 10s never shows a bar at all. The client wouldn't show one either.

## 16 of 105 learned caps can never fire

Both columns are the **same learner rule on the same corpus** — the only difference is dropping caps the
sticky gate makes unreachable. (Baseline regenerated with `main`'s learner against today's corpus; see
*Method*.)

| boss | caps | kept | dead | dropped (bin=cap) |
|---|---|---|---|---|
| Chromaggus | 1 | 1 | 0 | — |
| Sulfuron | 4 | 2 | **2** | 18=0.86, 17=0.96 |
| Skeram | 17 | 16 | 1 | 17=0.6 |
| Viscidus | 5 | 1 | **4** | 19=0.15, 18=0, 2=0.94, 1=0 |
| Twin Emperors | 20 | 20 | 0 | — |
| Ouro | 1 | 1 | 0 | — |
| C'Thun | 1 | 1 | 0 | — |
| Rajaxx | 6 | 6 | 0 | — |
| Buru | 17 | 17 | 0 | — |
| Thekal | 20 | 20 | 0 | — |
| Gahz'ranka | 5 | 2 | **3** | 9=0.94, 7=0.92, 2=0 |
| Jin'do | 3 | 1 | **2** | 9=0.9, 8=0.84 |
| **Onyxia** | 5 | 1 | **4** | 11=0, 10=0.91, 8=0.89, 7=0.93 |
| **TOTAL** | **105** | **89** | **16** | |

**Why some bosses lose nothing.** A cap can only act pre-show, so a boss whose *top* bins are capped keeps
the bar hidden deep into the fight and its later caps stay reachable. Twin Emperors, Thekal and Buru cap
from bin 20 downward in an unbroken run — the bar barely shows, so nearly every cap survives. The losers
are bosses that read fine early (so the bar latches) and only go wrong later.

## Onyxia — the sharpest case, and where this started

Shipped: `confCap = { [20] = 0.0, [11] = 0.0, [10] = 0.91, [8] = 0.89, [7] = 0.93 }`.

Reachability measured over 200 fixtures (`preShow` = fraction of a bin's in-scope samples where the bar
had not yet latched):

| condition | bin 20 | bin 19 | bins 18↓ |
|---|---|---|---|
| no caps | 8.3% | 0.0% | 0.0% |
| **with the shipped caps** | **99.9%** | 1.8% | **0.0%** |

`[20] = 0.0` is real and load-bearing — it is what holds the bar hidden through the opening. Everything
below it is dead. Bin 11 (50–55% health — **the air phase**) is the fight's worst-tracking bin: median
relative error **45.9%**, median absolute **59.0s**, on 22,036 samples. The learner correctly asked for
silence exactly there, and the client cannot deliver it.

A 20-kill grade of Onyxia the same day: mean MAPE 45.9%, median 43.9%, bias +22.8s, shown 86.9%,
durations 104–207s. Train/holdout was 11/9 and graded 45.1% vs 47.0% — **the profile generalizes; this is
a gate defect, not overfitting.**

## Two things found along the way

**1. The committed candidates are stale.** `tools/candidates/regime-*.lua` were learned from a corpus that
no longer exists on disk — `tools/fights/corpus/` is gitignored and disposable, and has been re-harvested
since WO-075. Re-running `main`'s own learner against today's corpus reproduces Onyxia's committed caps
exactly but *not* Buru's. So a naive "committed vs regenerated" diff conflates corpus drift with this
fix. Every number above uses the corpus-controlled comparison instead. **This is the WO-070 lesson again:
the corpus is ephemeral, so any diff against a committed artifact must re-derive its own baseline.** It is
also why this PR regenerates **no** candidate files.

**2. `damageable` moves the measurement on exactly two bosses.** Passing `damageable = h > 0` instead of a
hard-coded `true` shifts derived caps slightly for **Thekal** and **Skeram** — and only those two, because
they are the fights whose curves touch `h = 0` mid-fight: Thekal **56/60** kills, Skeram **23/60** (vs
Onyxia 22/200, Buru 2/60). The wobbles are small (Thekal `[19] 0.35→0.4`, Skeram `[12] 0.76→0.71`).

This lands on the boss [D-021-IJ] parked (finding 5 — Thekal `resetOnRise` / the damageable hold). It is
**recorded, not acted on**, per that decision and the WO's out-of-scope list. It does not resolve finding
5; it shows the instrument was feeding the estimator a slightly wrong world on the one boss where that
matters most.

## Method

- Baseline = `main`'s `learn-regime.py` + `estimator-perbin.lua` run in a detached worktree against
  **today's** corpus (absolute `--corpus`), so corpus drift is held constant.
- `estimator-perbin.lua` gained a 5th TSV column, `preShow`, measuring reachability directly rather than
  assuming it.
- Caps interact — keeping bin 20's cap is what holds the bar hidden into bin 19 — so `learn-regime.py`
  iterates: derive, re-measure reachability **with the candidate caps active**, drop what stays
  unreachable, repeat. Dropping can only make later bins latch earlier, so it converges (2–3 passes).
- `REACH_MIN = 0.05` — a cap must be able to act on ≥5% of its bin's in-scope samples to be worth
  shipping.
- Verified along the way: the old and new `perbin` produce **byte-identical** error columns, so the
  reachability work does not contaminate the measurement it feeds.

## What this does NOT do

No caps change ships. `src/raids/regimes.lua` is untouched, and so is every other addon file except
`regimes_spec.lua` (which [D-019-IJ](b) had already ruled wrong — a kills-only profile is legitimate).
Whether to re-learn the shipped table is a separate, human-gated call now that honest numbers exist —
D-011, and [D-021-IJ]'s rule that a re-derived number is not by itself licence to edit shared data.

**The open question this hands forward:** the air phase needs a mechanism *other than confidence*. The bar
is already up by 50% health, hiding it mid-fight would need a deliberate un-show, and D-020 removed the
`freeze` tier. That wants its own decision.
