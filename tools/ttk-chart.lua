-- ttk-chart — the whole fight on one screen: WHERE the countdown was wrong, and by how much.
--
--     luajit tools/ttk-chart.lua <fight.lua> [--rhythm none|shipped|candidate] [--compare]
--
-- Plots PREDICTED TIME OF DEATH (now + TTK) against the truth. A perfect estimator draws a flat line
-- sitting exactly on the actual death time: at every tick it names the same instant. So the chart reads
-- directly —
--   line ON the rule      the countdown is right
--   line ABOVE the rule   it thinks the boss dies later than it does (reads long)
--   line BELOW the rule   it thinks the boss dies sooner (reads short)
-- and the DISTANCE from the rule is the error in seconds, at a glance, for the whole fight.
--
-- This is the view a draining bar cannot give: a bar shows one instant against an arbitrary scale, so a
-- countdown that is drifting badly and one that is locked on look identical frame to frame.
--
-- `--compare` overlays the shipped profile and the learned candidate on the same axes.

local G = require("tools.estimator-grade")
local mock = require("tools.wow-mock.init")

local path, rhythmMode, compare = nil, "shipped", false
for i = 1, #arg do
    local a = arg[i]
    if a == "--rhythm" then
        rhythmMode = arg[i + 1]
    elseif a == "--compare" then
        compare = true
    elseif not a:match("^%-%-") and not path then
        path = a
    end
end
if not path then
    io.stderr:write("usage: ttk-chart.lua <fight.lua> [--rhythm ...] [--compare]\n")
    os.exit(1)
end

local ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
local fight = assert(loadfile(path))()
local samples, enc = fight.samples, fight.encounterID
local death = samples[#samples].t

local C = {
    r = "\27[0m", dim = "\27[38;5;244m", gold = "\27[38;5;178m", good = "\27[38;5;71m",
    warn = "\27[38;5;214m", bad = "\27[38;5;203m", ink = "\27[38;5;252m", bold = "\27[1m",
    hp = "\27[38;5;131m", a = "\27[38;5;74m", b = "\27[38;5;170m",
}

local function rhythmFor(mode)
    if mode == "shipped" then
        local R = mock.load("projects/badger-ttk/src/raids/rhythms.lua").Rhythms
        return R and (R[enc] or R[enc and enc - 150000])
    elseif mode == "candidate" and enc then
        local f = loadfile(("tools/candidates/rhythm-%d.lua"):format(enc))
        return f and f() or nil
    end
    return nil
end

-- Replay: predicted time of death at each tick, and when the bar latched.
local function run(rhythm)
    local est = ns.Estimator.new({
        reactivity = 0.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
        rhythm = rhythm,
    })
    local gate = G.newGate()
    local series, latch = {}, nil
    for i = 1, #samples do
        local s = samples[i]
        est:sample(s.t, s.h, G.damageable(s.h))
        local pred, conf = est:ttk()
        local shown = gate:update(pred, conf)
        if shown and not latch then
            latch = s.t
        end
        series[i] = { t = s.t, h = s.h, eta = (shown and pred) and (s.t + pred) or nil }
    end
    return series, latch
end

local runs = {}
if compare then
    local s1, l1 = run(rhythmFor("shipped"))
    local s2, l2 = run(rhythmFor("candidate"))
    runs = { { name = "shipped", series = s1, latch = l1, col = C.a, ch = "o" },
             { name = "learned", series = s2, latch = l2, col = C.b, ch = "*" } }
else
    local s1, l1 = run(rhythmFor(rhythmMode))
    runs = { { name = rhythmMode, series = s1, latch = l1, col = C.a, ch = "o" } }
end

local W, H = 72, 18
-- Y range: the truth must always be on screen; clip absurd early reads so one 30-minute tick does not
-- flatten the whole chart into a single row.
local YMAX = death * 2.2
local YMIN = 0
local function row(v)
    local f = (v - YMIN) / (YMAX - YMIN)
    return H - math.floor(f * (H - 1) + 0.5)
end
local function col(t)
    return 1 + math.floor((t / death) * (W - 1) + 0.5)
end

local grid = {}
for y = 1, H do
    grid[y] = {}
    for x = 1, W do
        grid[y][x] = false
    end
end

-- the truth: a horizontal rule at the actual death time
local truthRow = row(death)
for x = 1, W do
    grid[truthRow][x] = { ch = "─", col = C.dim }
end

local clipped = 0
for _, rr in ipairs(runs) do
    for _, p in ipairs(rr.series) do
        if p.eta then
            local v, over = p.eta, false
            if v > YMAX then
                v, over = YMAX, true
                clipped = clipped + 1
            end
            local y, x = row(v), col(p.t)
            if y >= 1 and y <= H and x >= 1 and x <= W then
                grid[y][x] = { ch = over and "^" or rr.ch, col = over and C.bad or rr.col }
            end
        end
    end
end

print(("\n%s%s  %s%s"):format(C.gold, C.bold, fight.name or path, C.r))
local sub = ("%sdies at %.1fs · %s · rule = the truth; distance from it = error in seconds%s")
    :format(C.dim, death, fight.size and (fight.size .. "p") or "?", C.r)
print(sub .. "\n")

for y = 1, H do
    local v = YMIN + (H - y) / (H - 1) * (YMAX - YMIN)
    local label = (y == truthRow) and ("%s%5.0fs%s"):format(C.bold, death, C.r)
        or ("%s%5.0fs%s"):format(C.dim, v, C.r)
    local line = {}
    for x = 1, W do
        local c = grid[y][x]
        line[#line + 1] = c and (c.col .. c.ch .. C.r) or " "
    end
    local mark = (y == truthRow) and (" " .. C.dim .. "<- actual death" .. C.r) or ""
    print(("%s %s%s"):format(label, table.concat(line), mark))
end
io.write(("      %s"):format(C.dim))
for _ = 1, W do
    io.write("─")
end
print(C.r)
print(("      %s0s%s%.0fs%s"):format(C.dim, string.rep(" ", W - 8), death, C.r))

-- Legend + per-run summary.
print("")
for _, rr in ipairs(runs) do
    local sum, n, worstE, worstT = 0, 0, 0, nil
    for _, p in ipairs(rr.series) do
        local actual = death - p.t
        if p.eta and p.t >= G.WARMUP and actual > G.TAIL then
            local e = (p.eta - death)
            sum = sum + math.abs(e) / actual
            n = n + 1
            if math.abs(e) > math.abs(worstE) then
                worstE, worstT = e, p.t
            end
        end
    end
    print(("  %s%s%s  bar at %s%.1fs%s · MAPE %s%.1f%%%s · worst read %s%+.0fs%s at t=%.0fs")
        :format(rr.col, rr.ch, C.r, C.bold, rr.latch or 0, C.r,
            C.bold, n > 0 and 100 * sum / n or 0, C.r,
            (math.abs(worstE) > 15 and C.bad or C.warn), worstE, C.r, worstT or 0))
end
if clipped > 0 then
    print(("  %s%s^%s %d ticks read past %.0fs — off the top of the chart%s")
        :format(C.dim, C.bad, C.dim, clipped, YMAX, C.r))
end
print("")
