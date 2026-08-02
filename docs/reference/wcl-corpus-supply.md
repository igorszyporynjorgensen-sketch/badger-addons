# What corpus Warcraft Logs can actually supply (measured 2026-08-02)

The harvester's ceiling, in facts rather than assumptions. Measured with ~350 read-only V1 rankings calls
while scoping the MC spectrum pass (WO-077). Everything here is checked, not inferred — the repo has been
bitten before by reasoning about WCL data instead of measuring it (the CSV-vs-API Lucifron split, D-012).

## Only the Fresh/Anniversary era is readable

| era | encounter ids | dates | readable? |
|---|---|---|---|
| original Classic | 663–672 | 2019–2021 | **no — archived**, events return HTTP 400 |
| Anniversary / "Fresh" | 150663–150672 | 2025-01 → | **yes**, 12/12 sampled kills readable |

So any request phrased in original-Classic terms ("Phase 1 to Phase 5 pre-TBC", 2019–2021) can only be
served from the **Anniversary** timeline. The archive boundary is not a rate limit or a permissions issue —
those reports are gone for the free API, and no amount of retrying recovers them.

**Archived rate in the Fresh era is zero.** This matters for planning: the WO-070-era harvester carries
skip-archived logic and a `cap = max(5*n, 50)` attempt bound sized for heavy archiving. Within Fresh, that
defensiveness is unnecessary and the attempt bound is the thing that will actually limit a large harvest.

## `partition` is the phase

`rankings/encounter/<id>?metric=speed&page=N&partition=P` — the `partition` parameter selects the content
phase, which is exactly the axis a phase-spanning corpus needs:

| partition | dates |
|---|---|
| 1 | 2025-01-17 → 2025-03-16 |
| 2 | 2025-03-19 → 2025-07-08 |
| 3 | 2025-07-09 → 2025-09-30 |
| 4 | 2025-10-01 → 2026-01-11 |
| 5 | 2026-01-16 → 2026-02-04 |

Without `partition` the endpoint returns partition 1 only — which is why the existing corpus is implicitly
P1-era data. That was never a deliberate curation choice; it is the API's default.

## Supply ceiling: 50 rows/page, and depth varies by phase

Pagination stops hard (HTTP 400 past the last page). Measured last usable page per MC boss × phase:

| phase | last page | kills |
|---|---|---|
| P1 | 20 | 1000 |
| P2 | 20 | 1000 |
| P3 | 20 | 1000 |
| P4 | 14–17 | 700–850 |
| P5 | 6 | 300 |

**~4000–4150 kills available per boss.** Depth is near-identical across the ten MC bosses, because any raid
that kills Lucifron kills the rest — per-boss supply tracks the phase's total logged raids, not the boss.
P5 is thin simply because it is recent (≈3 weeks of data at time of measurement), so a phase-balanced plan
must either accept a smaller P5 quota or rebalance onto earlier phases.

## Page depth is the performance axis — but the last page is not "slow raids"

On `metric=speed`, deeper pages are slower kills. Measured on Ragnaros:

| phase | page 1 | mid | last page |
|---|---|---|---|
| P1 | 18.4–39.4s | p10 57.5–58.9s | p20 80.0–82.2s |
| P2 | 24.2–32.3s | p10 49.4–50.7s | p20 63.9–65.8s |
| P3 | 21.7–35.5s | p10 55.0–56.5s | p20 74.0–76.5s |
| P4 | 22.5–53.8s | p7 79.6–83.5s | p14 **131.6–260.7s** |
| P5 | 33.6–60.8s | p3 71.4–79.3s | p6 **112.4–264.8s** |

**Read the spread, not just the median.** Mid pages are tight (57.5–58.9s across a whole page); the *final*
page alone spans 131–261s. That final-page variance is the pathological tail — wipe-recovery kills,
disconnects, half-AFK raids — not a slower guild. Sampling "the bottom" as "the last page" would train the
estimator on noise.

**Rule:** define performance tiers by **duration quantile within a phase, with the extreme tail trimmed** —
never by raw page position.

## The population this can and cannot represent

`metric=speed` rankings contain only raids that **logged**. Guilds that log skew organised, addon-using and
performance-interested. So the "bottom tier" here is a slow *logging* raid, which is not the same population
as an unlogged pug — the very audience whose fights the addon most needs to read well. A spectrum corpus
widens the distribution honestly, but it cannot claim to sample the true bottom of the player base, and no
sampling strategy against this API can fix that. The human's own raids remain the real
out-of-distribution test.

## Practical notes

- 99 calls for a 10-boss × 5-phase availability sweep; ~260 for a binary-searched depth map. Both fast
  (under 2 minutes each) and safe to re-run.
- Rankings rows carry `duration` and `startTime`, so the whole duration distribution can be enumerated
  **before** deciding which fights to pull — quantile tiering and tail-trimming therefore cost no extra
  fight pulls.
- The zone-name lookup for Molten Core did not resolve via the `zones` endpoint during this sweep; the
  encounter-id map below was taken from the repo's own profiles instead.

## MC encounter map (authoritative)

`150663` Lucifron · `150664` Magmadar · `150665` Gehennas · `150666` Garr · `150667` **Shazzrah** ·
`150668` **Baron Geddon** · `150669` Sulfuron Harbinger · `150670` Golemagg · `150671` Majordomo ·
`150672` Ragnaros

Note 667/668: Shazzrah before Baron Geddon — the **inverse** of the display order in
[`src/raids/table.lua`](../../projects/badger-ttk/src/raids/table.lua). Keying a profile off the display
order would silently attach it to the wrong boss, the same class of mistake the Thekal/Gahz'ranka id note
in `assemble-regimes.py` already warns about.
