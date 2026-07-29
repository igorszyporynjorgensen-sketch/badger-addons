# Kill-history schema (D-012)

One record shape that fits both **local recording** and a **Warcraft Logs** import, so the two blend into
one prior and the prior can be scaled by the current group. Warcraft Logs models a report as a list of
**fights**; we model kill history as a list of **kill records** — one row per kill. The four open
questions are now **resolved** (reliability-first, TBC/Retail forward-compat baked in) — see the bottom.

## The store — split by identity space

```lua
db.global.history = {
    encounter = { [encounterID] = { <record>, ... } },  -- instanced bosses: the Warcraft-Logs-native key
    creature  = { [creatureID]  = { <record>, ... } },  -- solo / world / trash: the id from the GUID
}
```

**Why two spaces (Q1 — the reliable answer).** The one identity a local kill *always* has is the
**creature id** (from `UnitGUID`). The one Warcraft Logs is keyed on is the **encounter id**. To make
local instanced-boss kills and WCL imports share a key (so they blend), instanced bosses key on
**`encounterID`** — the addon gets it reliably from `ENCOUNTER_START`, and it's exactly WCL's key. Solo /
world / trash (no encounter) key on the **creature id**. Every record lands in exactly one space, both
sources agree on it, and there's no fragile encounter↔creature mapping table to maintain.

## The per-kill record

```lua
{
    name  = "Kel'Thuzad",   -- display only; never keyed on
    level = 60,             -- your level at the kill (solo/leveling; ~cap in raids). cap 60 Era · 70 TBC
    dur   = 312.4,          -- fight duration (s). rate = 1 / dur for a full kill (health 1 → 0)
    size  = 40,             -- group size: 1 solo · 5 dungeon · 10 / 25 / 40 raid
    comp  = { WARRIOR = 8, MAGE = 6, PRIEST = 5, DRUID = 4, ... },  -- per-CLASS counts (see Q2)
    diff  = "normal",       -- Era: "normal" · TBC: normal / heroic (dungeons) · Retail: tiers (see Q4)
    src   = "local",        -- provenance: "local" | "wcl"
    when  = 1730200000,     -- unix timestamp — recency weighting + dedup
}
```

`rate` isn't stored — it's derived (`1 / dur`), so the record stays a faithful WCL-shaped fact. (Local
recording already measures the real damaging-window rate; store its implied `dur = 1 / rate`, so both
sources are byte-identical in shape.)

## Prior selection (sketch)

Given the current target (its `encounterID` or creature id) and the live group `{ size, comp }`:

1. Pull the record list for that identity; prefer rows with a matching `size` (and `diff`), else use all.
2. Blend their `1/dur` rates (recency-weighted via `when`), optionally scaled by a DPS proxy derived from
   `comp` (non-healer class counts) when the record's group differs from the current one.
3. Feed that as `priorRate` — the estimator blends it as pseudo-observation seconds (WO-056).

## WCL → record (a thin mapping, not a translation)

| Our field | Warcraft Logs (GraphQL `reportData … fights`) |
|---|---|
| store space + key | `fight.encounterID` → `encounter[encounterID]` |
| `name` | `fight.name` |
| `dur` | `(fight.endTime − fight.startTime) / 1000` |
| `size` | `fight.size` / friendlies count |
| `comp` | count `report.masterData.actors[].subType` (**class**) |
| `diff` | `fight.difficulty` |
| `when` | `report.startTime + fight.startTime` |

Local recording fills the same fields from live APIs (`UnitGUID` → creature id, `ENCOUNTER_START` →
encounter id + size + difficulty, a group scan → per-class `comp`, the damaging-window duration it already
tracks → `dur`).

## Transport (the import blob)

`LibSerialize` the records → `LibDeflate` compress → base64 (the "WeakAuras string" convention). The
**external converter** (a companion site/tool) produces that string from a WCL export (its GraphQL API) or
a raw `WoWCombatLog.txt`; the addon just decodes + appends (dedup on `when` + identity). The addon never
touches the web itself (sandbox).

## Resolved questions

1. **Raid key → `encounterID` (from `ENCOUNTER_START`), creature id otherwise.** Most reliable + safe: it's
   the key WCL already uses *and* one the client hands us for instanced bosses, so imports and local kills
   share it with no mapping table; non-instanced kills fall back to the always-present creature id.
2. **`comp` → per-**class** counts** (`{ WARRIOR = n, ... }`). Class is the *atom* both sources reliably
   provide — `UnitClass` locally (spec/role are unreliable to read in Classic; the game assigns no roles),
   and the actor class from WCL. Per-class rolls up to roles or a DPS proxy whenever we want; roles can
   never be split back into classes. So class counts are both the most reliable **and** the most flexible.
3. **Cap → 50 per identity.** *The penalty of 50 vs 20 is only storage* (SavedVariables size → login/logout
   parse time): a record is ~200 bytes, so 50 ≈ 10 KB per identity vs ~4 KB. For raids (dozens of bosses)
   it's trivial (~½ MB); the only place it grows is a long leveling career touching many creature ids —
   low-single-digit MB worst case, which WoW handles fine. Safety valve: prune oldest beyond 50 **and**
   drop records older than ~180 days, so it stays bounded regardless. 50 it is.
4. **Keep `diff` + `level` now, for TBC/Retail forward-compat.** Era sets `diff = "normal"` and `level`
   ≤ 60; the fields already exist so a **TBC** flavor (heroic dungeons, level 70 — see D-004) and Retail
   imports slot in with **zero schema change or migration**. Baked in from day one.
