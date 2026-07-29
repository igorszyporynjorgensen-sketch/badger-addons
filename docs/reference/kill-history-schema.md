# Kill-history schema — strawman (D-012)

A **strawman to react to**, not final. The goal (D-012): one record shape that fits both **local
recording** and a **Warcraft Logs** import, so the two blend into one prior and the prior can be scaled by
the current group. Warcraft Logs models a report as a list of **fights**; we model kill history as a list
of **kill records** — the same idea, one row per kill.

## The per-kill record

Mirrors a WCL "fight" (kill), pared to what the prior needs:

```lua
{
    npc   = 15990,          -- creature id from the target GUID (raids: the encounter's boss) — the KEY
    name  = "Kel'Thuzad",   -- display only (readability / debug); never keyed on
    level = 60,             -- your level at the kill — drives solo/leveling priors (~max in raids)
    dur   = 312.4,          -- fight duration (s). rate = 1 / dur for a full kill (health 1 → 0)
    size  = 40,             -- group size: 1 solo · 5 dungeon · 10 / 25 / 40 raid
    comp  = { tank = 2, healer = 8, melee = 12, ranged = 18 },  -- role/bucket counts (sums to size)
    diff  = "normal",       -- difficulty (Classic: normal; Retail: normal/heroic/mythic)
    src   = "local",        -- provenance: "local" | "wcl"
    when  = 1730200000,     -- unix timestamp — recency weighting + dedup
}
```

`rate` isn't stored — it's derived (`1 / dur`), so the record stays a faithful WCL-shaped fact and the
estimator computes the prior. (Local recording already measures the real damaging-window rate; store its
implied `dur = 1 / rate` so both sources are identical in shape.)

## The store — a capped list of records, not a running mean

```lua
db.global.history[npc] = { <record>, <record>, ... }   -- newest last, capped (~20–50 per npc)
```

Per-kill records (vs. today's `store[level][npcId] = { n, rate }` running mean) because:

- **Import = append.** A WCL fight maps 1:1 to a record — the converter just emits rows.
- **Group-aware prior.** With `size`/`comp` per row, the prior for *this* pull can prefer rows from a
  similar group, or scale a solo/other-size row by a DPS proxy — instead of one comp-blind average.
- **Recency + dedup.** `when` lets recent kills weigh more and drops duplicate imports.
- Aggregating on demand is trivial; a per-npc cap bounds storage.

## Prior selection (sketch)

Given the current target `npc` and live group `{ size, comp }`:

1. Prefer records with a matching `size` bucket (and `diff`); else fall back to all rows for that `npc`.
2. Blend their `1/dur` rates (recency-weighted via `when`), optionally scaled by a coarse DPS proxy
   (e.g. ranged+melee count) when the record's group differs from the current one.
3. Feed that as `priorRate` (the estimator already blends it as pseudo-observation seconds, WO-056).

## WCL → record (a thin mapping, not a translation)

| Our field | Warcraft Logs (GraphQL `reportData … fights`) |
|---|---|
| `npc` | `fight.encounterID` (or the boss's `gameID`) |
| `name` | `fight.name` |
| `dur` | `(fight.endTime − fight.startTime) / 1000` |
| `size` | `fight.size` / friendlies count |
| `comp` | roll up `report.masterData.actors[].subType` (class/spec) into role buckets |
| `diff` | `fight.difficulty` |
| `when` | `report.startTime + fight.startTime` |

Local recording fills the same fields from live APIs (`UnitGUID`, `GetRaidRosterInfo`/group scan, the
damaging-window duration it already tracks).

## Transport (the import blob)

`LibSerialize` the records → `LibDeflate` compress → base64 (the "WeakAuras string" convention). The
**external converter** (a companion site/tool) produces that string from a WCL export or a raw
`WoWCombatLog.txt`; the addon just decodes + appends (dedup on `when`+`npc`). The addon never touches the
web itself (sandbox).

## Open questions (for you)

1. **Key for raids** — `encounterID` (stable, one row per boss) vs. the raw creature `gameID`? (Solo uses
   the creature id from the GUID regardless.)
2. **`comp` granularity** — role buckets (tank/healer/melee/ranged, as above) enough, or do you want
   per-class counts for finer scaling?
3. **Per-npc record cap** — 20? 50? (storage vs. history depth)
4. **`diff`/`level` in Classic** — Classic Era has no difficulty tiers; keep the field for Retail/forward
   compat, or drop it for now?
