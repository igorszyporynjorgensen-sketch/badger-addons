local _, ns = ...

-- Recorded kill history (D-012) — per-kill RECORDS in the Warcraft-Logs-shaped schema, so a locally
-- observed kill and a future web-log import are the SAME shape and blend into one prior. DATA logic only
-- (no WoW API — timestamps/`now` are passed IN by the caller): the live driver reads db.global, stamps
-- each record with live roster + encounter data, and calls these; a future importer appends records of
-- the same shape (`src = "wcl"`). Replaces the WO-025 running-mean store.
--
--   db.global.history = {
--       encounter = { [encounterID] = { <record>, ... } },  -- instanced bosses (the ENCOUNTER_START key)
--       creature  = { [creatureID]  = { <record>, ... } },  -- solo / world / trash (the id from the GUID)
--   }
--   <record> = { name, level, dur, size, comp = { CLASS = n, ... }, diff, src, when }
--     dur  = seconds to kill from FULL health (rate = 1/dur) · size = group size · comp = per-CLASS counts
--     diff = "normal" (Era) · src = "local" | "wcl" · when = unix seconds (recency weighting + dedup).
--
-- Each identity keeps the MOST RECENT 50 records (evict the oldest by `when`, never the newest) and drops
-- records older than 180 days, so the store stays bounded across a long career (D-012 Q3).

local History = {}

local CAP = 50
local MAX_AGE = 180 * 24 * 60 * 60 -- 180 days, in seconds
local RECENCY = 0.8 -- prior weight per older kill (rank-based): newest 1, then 0.8, 0.64, … — a soft
-- recency bias so recent kill speed leads, without one fluky last kill owning the estimate.

-- Normalize/migrate the store to the D-012 shape. The pre-D-012 shape (`store[level][key] = {n, rate}`) is
-- a collapsed running mean with NONE of the record fields, so it cannot be reconstructed into records — it
-- is wiped (the prior simply regenerates as the player kills things). Returns the store to assign back.
function History.ensureShape(store)
    if type(store) ~= "table" then
        return { encounter = {}, creature = {} }
    end
    -- Strip any pre-D-012 residue (the WO-025 running-mean shape, keyed by player level). AceDB copies the
    -- default `encounter`/`creature` sub-tables INTO an existing saved store via its metatable, so their
    -- presence is NOT proof the store is clean — an upgraded user's store carries the old `[level]` keys
    -- alongside them. Keep only the two identity spaces; the stale prior regenerates as the player plays.
    for k in pairs(store) do
        if k ~= "encounter" and k ~= "creature" then
            store[k] = nil
        end
    end
    if type(store.encounter) ~= "table" then
        store.encounter = {}
    end
    if type(store.creature) ~= "table" then
        store.creature = {}
    end
    return store
end

-- Append one per-kill `record` under (space, id) — space is "encounter" or "creature" — then prune: drop
-- records older than MAX_AGE relative to the newest, and keep only the most-recent CAP by `when`.
function History.record(store, space, id, record)
    local byId = store and space and store[space]
    if type(byId) ~= "table" or id == nil then
        return
    end
    if not (type(record) == "table" and record.when and record.dur and record.dur > 0) then
        return
    end
    local list = byId[id]
    if not list then
        list = {}
        byId[id] = list
    end
    list[#list + 1] = record
    -- Kills append in time order; the sort defends against an importer adding records out of order.
    table.sort(list, function(a, b)
        return (a.when or 0) < (b.when or 0)
    end)
    local newest = list[#list].when
    local kept = {}
    for i = 1, #list do
        if newest - (list[i].when or 0) <= MAX_AGE then
            kept[#kept + 1] = list[i]
        end
    end
    while #kept > CAP do
        table.remove(kept, 1) -- ascending by `when` → drop the oldest, never the newest
    end
    byId[id] = kept
end

-- Derive a blended prior RATE (health fraction per second) for (space, id): a recency-weighted mean of the
-- records' 1/dur, preferring records whose group `size` matches the current one (else all). Same units the
-- estimator's `priorRate` already consumes (it folds it in as pseudo-observation seconds). nil when none.
function History.rate(store, space, id, context)
    local list = store and space and store[space] and store[space][id]
    if not list or #list == 0 then
        return nil
    end
    local size = context and context.size
    local pool = list
    if size then
        local matched = {}
        for i = 1, #list do
            if list[i].size == size then
                matched[#matched + 1] = list[i]
            end
        end
        if #matched > 0 then
            pool = matched
        end
    end
    -- NOTE (D-012 prior step 1 lists `size` AND `diff`): only `size` is discriminated. Every Era record is
    -- `diff = "normal"`, so there is nothing to split today; a `diff` filter (and the comp/DPS-proxy scaling)
    -- wait until a multi-difficulty flavor (TBC heroic vs normal) or a `wcl` import puts differing-diff
    -- records under one identity — which also needs the driver to thread `context.diff`. `diff` is already
    -- recorded, so no store/schema change is deferred, only the blend.
    -- newest first, so rank 0 (weight 1) is the most recent kill
    local sorted = {}
    for i = 1, #pool do
        sorted[i] = pool[i]
    end
    table.sort(sorted, function(a, b)
        return (a.when or 0) > (b.when or 0)
    end)
    local wsum, rsum = 0, 0
    for i = 1, #sorted do
        local rec = sorted[i]
        if rec.dur and rec.dur > 0 then
            local w = RECENCY ^ (i - 1)
            wsum = wsum + w
            rsum = rsum + w * (1 / rec.dur)
        end
    end
    if wsum == 0 then
        return nil
    end
    return rsum / wsum
end

ns.History = History
