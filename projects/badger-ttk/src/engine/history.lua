local _, ns = ...

-- Recorded kill history — a stable PRIOR for the TTK estimate (WO-025). Keyed by player LEVEL then a target
-- key (its NPC id): `store[level][key] = { n, rate }`, where `rate` is a running mean of the observed
-- health-loss rate (fraction of max HP per second) across past kills. DATA logic only (no WoW API): the live
-- driver parses the GUID/level and reads db.global, then calls these. A future WarcraftLogs import can
-- populate the same store (the D-005 seam). Each level is kept separate, as the human asked (a level-52 kill
-- of a wolf must not pollute a level-20 one).

local History = {}

-- Cap the effective weight so the mean keeps ADAPTING to recent kills (an EMA once past the cap), rather
-- than freezing after many samples.
local WEIGHT_CAP = 20

-- Record a kill's average health-loss `rate` for (level, key) into `store`, updating the running mean.
function History.record(store, level, key, rate)
    if not (store and level and key ~= nil and rate and rate > 0) then
        return
    end
    local byLevel = store[level]
    if not byLevel then
        byLevel = {}
        store[level] = byLevel
    end
    local e = byLevel[key]
    if not e then
        e = { n = 0, rate = 0 }
        byLevel[key] = e
    end
    local w = (e.n < WEIGHT_CAP) and e.n or WEIGHT_CAP
    e.rate = (e.rate * w + rate) / (w + 1)
    e.n = e.n + 1
end

-- The recorded mean rate for (level, key), or nil when none is stored.
function History.rate(store, level, key)
    local e = store and level and store[level] and store[level][key]
    return e and e.rate or nil
end

ns.History = History
