-- ttk-career — replay ONE guild's raid career the way a player actually lives it (WO-078 follow-up).
--
--     luajit tools/ttk-career.lua [dir] [--throttle 2] [--speed 8] [--no-history]
--
-- Every other tool in this lab grades a fight in isolation, with the history prior faked from the corpus.
-- That is not how the addon works. In game the prior is the PLAYER'S OWN past kills, accumulated one at a
-- time (D-012, `history.lua`), and a guild raiding weekly is the closest proxy available: broadly the same
-- roster, gear and strategy from week to week.
--
-- So this replays the career WALK-FORWARD. Kill N is predicted using ONLY kills 1..N-1 as history —
-- the same information the addon would genuinely have had at that moment. Nothing from the future, and
-- nothing from other guilds. That makes it the only measurement here that answers the question a player
-- actually asks: "does this thing get better at MY raid the longer I use it?"
--
-- History.rate (history.lua:88-131) is mirrored exactly: newest-first, recency-weighted mean of 1/dur,
-- RECENCY = 0.8, filtered to the same group size.

local G = require("tools.estimator-grade")
local mock = require("tools.wow-mock.init")
local ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
local Rh = mock.load("projects/badger-ttk/src/raids/rhythms.lua").Rhythms

local dir, throttle, speed, noHist = "tools/fights/guild", nil, 8.0, false
do
    -- Consume flag VALUES explicitly. Scanning for "the first non-`--` argument" silently swallows a
    -- flag's value as the positional — the same bug that made `--prior loo` load "loo" as an estimator
    -- path and produced two byte-identical runs before it was caught.
    local i = 1
    while i <= #arg do
        local a = tostring(arg[i])
        if a == "--throttle" then
            throttle = tonumber(arg[i + 1]) or 2.0
            i = i + 2
        elseif a == "--speed" then
            speed = tonumber(arg[i + 1]) or 8.0
            i = i + 2
        elseif a == "--no-history" then
            noHist = true -- the control: every kill treated as a first kill, forever
            i = i + 1
        else
            dir = a
            i = i + 1
        end
    end
end

local C = {
    r = "\27[0m", dim = "\27[38;5;244m", gold = "\27[38;5;178m", good = "\27[38;5;71m",
    warn = "\27[38;5;214m", bad = "\27[38;5;203m", ink = "\27[38;5;252m", bold = "\27[1m",
}

local sleep
do
    local ok, ffi = pcall(require, "ffi")
    if ok then
        pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
        sleep = function(s)
            ffi.C.poll(nil, 0, math.max(0, math.floor(s * 1000)))
        end
    else
        sleep = function() end
    end
end

-- Read the chronological index (a small JSON the puller wrote; parsed by pattern, no JSON lib in LuaJIT).
local fh = assert(io.open(dir .. "/progression.json"), "no progression.json in " .. dir)
local raw = fh:read("a")
fh:close()
local guild = raw:match('"guild":%s*"([^"]*)"') or "?"
local prog = {}
for obj in raw:gmatch("{[^{}]*}") do
    local enc = tonumber(obj:match('"enc":%s*(%d+)'))
    local path = obj:match('"path":%s*"([^"]*)"')
    local boss = obj:match('"boss":%s*"([^"]*)"')
    local night = obj:match('"night":%s*"([^"]*)"')
    local size = tonumber(obj:match('"size":%s*(%d+)'))
    if enc and path and boss then
        prog[#prog + 1] = { enc = enc, path = path, boss = boss, night = night, size = size }
    end
end
assert(#prog > 0, "no fights parsed from progression.json")

-- History.rate, mirrored (history.lua:112-131): newest first, weight RECENCY^rank, mean of 1/dur.
local RECENCY = 0.8
local function priorFrom(records, size)
    local pool = {}
    for _, r in ipairs(records) do
        if not size or r.size == size then
            pool[#pool + 1] = r
        end
    end
    if #pool == 0 then
        pool = records
    end
    if #pool == 0 then
        return nil
    end
    local sorted = {}
    for i = 1, #pool do
        sorted[i] = pool[i]
    end
    table.sort(sorted, function(a, b)
        return (a.when or 0) > (b.when or 0)
    end)
    local ws, rs = 0, 0
    for i, rec in ipairs(sorted) do
        if rec.dur and rec.dur > 0 then
            local w = RECENCY ^ (i - 1)
            ws = ws + w
            rs = rs + w * (1 / rec.dur)
        end
    end
    return ws > 0 and (rs / ws) or nil
end

local function gradeOne(path, enc, priorRate)
    local ok, fight = pcall(function()
        return assert(loadfile(path))()
    end)
    if not ok or not fight.samples or #fight.samples < 8 then
        return nil
    end
    local samples = fight.samples
    local death = samples[#samples].t
    local est = ns.Estimator.new({
        reactivity = 0.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
        rhythm = Rh and (Rh[enc] or Rh[enc - 150000]),
        priorRate = priorRate,
    })
    local gate = G.newGate()
    local disp, prevT, rel, n = nil, nil, 0, 0
    for _, s in ipairs(samples) do
        est:sample(s.t, s.h, G.damageable(s.h))
        local pred, conf = est:ttk()
        if gate:update(pred, conf) and pred then
            local d = pred
            if throttle and disp and prevT then
                local lim = disp + throttle * (s.t - prevT)
                if d > lim then
                    d = lim
                end
            end
            disp, prevT = d, s.t
            local a = death - s.t
            if s.t >= G.WARMUP and a > G.TAIL then
                rel = rel + math.abs(d - a) / a
                n = n + 1
            end
        end
    end
    return n > 0 and (100 * rel / n) or nil, death
end

io.write("\27[2J\27[H")
print(("%s%s  🦡 CAREER REPLAY — %s%s"):format(C.gold, C.bold, guild, C.r))
print(
    ("%swalk-forward: kill N uses ONLY kills 1..N-1 as history · throttle %s · %s%s\n"):format(
        C.dim,
        throttle and (throttle .. "s/s") or "off",
        noHist and (C.warn .. "HISTORY DISABLED (control)" .. C.dim) or "history ON",
        C.r
    )
)
print(
    ("  %-4s %-11s %-20s %7s %9s %8s %8s"):format(
        "#", "night", "boss", "dur", "prior", "MAPE", "seen"
    )
)
print("  " .. string.rep("─", 74))

local hist = {} -- [enc] = { {dur=, size=, when=}, ... }  — exactly the addon's per-encounter store
local firstN, laterN, firstS, laterS = 0, 0, 0, 0
local clock = 0
for i, f in ipairs(prog) do
    clock = clock + 1
    local recs = hist[f.enc] or {}
    local prior = (not noHist) and priorFrom(recs, f.size) or nil
    local m, dur = gradeOne(f.path, f.enc, prior)
    if m then
        local seen = #recs
        -- Split the career: has the addon watched THIS boss before, or is this a first kill?
        if seen == 0 then
            firstN = firstN + 1
            firstS = firstS + m
        else
            laterN = laterN + 1
            laterS = laterS + m
        end
        local col = m < 25 and C.good or (m < 50 and C.warn or C.bad)
        print(
            ("  %-4d %-11s %-20s %6.1fs %8s %s%7.1f%%%s %8s"):format(
                i, f.night or "?", f.boss:sub(1, 20), dur,
                prior and ("%.0fs"):format(1 / prior) or "—",
                col, m, C.r,
                seen == 0 and "1st" or ("+" .. seen)
            )
        )
        sleep(0.35 / speed * 8)
    end
    hist[f.enc] = recs
    recs[#recs + 1] = { dur = dur, size = f.size, when = clock }
end

print("  " .. string.rep("─", 74))
if firstN > 0 then
    print(("  %sfirst kill of a boss   %s%5.1f%%%s   over %d kills"):format(
        C.dim, C.bold, firstS / firstN, C.r, firstN))
end
if laterN > 0 then
    print(("  %swith own history       %s%5.1f%%%s   over %d kills   %s%+.1f points%s"):format(
        C.dim, C.bold, laterS / laterN, C.r, laterN,
        (laterS / laterN < firstS / firstN) and C.good or C.bad,
        (laterS / laterN) - (firstS / firstN), C.r))
end
print("")
