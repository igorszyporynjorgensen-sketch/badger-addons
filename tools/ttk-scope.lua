-- ttk-scope — WATCH a real fight replay through the estimator, as two bars in the terminal.
--
--     luajit tools/ttk-scope.lua <fight.lua> [--speed 4] [--rhythm none|shipped|candidate]
--     luajit tools/ttk-scope.lua tools/fights/mc/val/150669-pt2-abc-12.lua --speed 6
--
-- Top bar  = the TTK countdown the PLAYER would see (drains toward the kill).
-- Bottom bar = the boss's actual health.
--
-- Why this exists: every other tool in the lab reports aggregates, and an aggregate cannot show you the
-- one thing that matters most about this addon — WHEN the bar appears and whether it lies while it is up.
-- The show gate is sticky (WO-076): once the bar latches it never hides again, so the moment of latching
-- is the single most consequential event in the fight. Here you can see it happen.
--
-- The TTK bar is drawn against the largest estimate seen so far, so a correct estimator produces a bar
-- that drains smoothly to empty exactly as the health bar does. Divergence between the two bars IS the
-- error, visible directly: TTK ahead of health = reading short, behind = reading long.

local G = require("tools.estimator-grade")
local mock = require("tools.wow-mock.init")

local path, speed, rhythmMode, static, throttle, priorDur = nil, 4.0, "candidate", nil, nil, nil
local openK, openTo = nil, 10.0
local OPEN_W = 5.0 -- seconds of early rate the baseline is measured over
for i = 1, #arg do
    local a = arg[i]
    if a == "--speed" then
        speed = tonumber(arg[i + 1]) or 4.0
    elseif a == "--throttle" then
        -- Cap on how fast the DISPLAYED countdown may RISE, in seconds of TTK per second of wall
        -- clock. Asymmetric on purpose: a real time-to-kill falls at 1s per second, so downward
        -- movement is almost always genuine and needs no limit, while a large upward jump is almost
        -- always noise — a raid cannot slow by 174 seconds inside one 0.15s tick.
        throttle = tonumber(arg[i + 1]) or 2.0
    elseif a == "--prior" then
        -- Seconds this player has historically needed to kill this boss. The live driver ALWAYS passes
        -- a prior (driver.lua:219) and history defaults on (core.lua:78-79), so a replay without one
        -- models a FIRST kill, not the normal case. Omitting it here was the same defect WO-076 found in
        -- the show gate and WO-077 F1 found in the graders — reintroduced in a new tool. It matters a
        -- lot: without a prior the opening read can reach 43 MINUTES; with one it is sane from tick one.
        priorDur = tonumber(arg[i + 1])
    elseif a == "--opening" then
        -- WO-078: the human's learned opening baseline. Over the first `openW` seconds measure the early
        -- kill rate r, then show (k / r) * health instead of the estimator, until `openTo` seconds.
        -- k is the per-boss constant learned from real kills (k = duration x early-rate); k = 1 would be
        -- naive linear extrapolation, which over-predicts fight length by 3x-33x at 3 seconds.
        openK = tonumber(arg[i + 1])
        openTo = tonumber(arg[i + 2]) or 10.0
    elseif a == "--rhythm" then
        rhythmMode = arg[i + 1]
    elseif a == "--static" then
        -- N evenly spaced snapshots, printed without cursor control — a filmstrip that survives
        -- being piped, pasted or read back from a log.
        static = tonumber(arg[i + 1]) or 8
    elseif not a:match("^%-%-") and not path then
        path = a
    end
end
if not path then
    io.stderr:write("usage: ttk-scope.lua <fight.lua> [--speed N] [--rhythm none|shipped|candidate]\n")
    os.exit(1)
end

local ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
local fight = assert(loadfile(path))()
local samples = fight.samples
local death = samples[#samples].t
local enc = fight.encounterID

local rhythm
if rhythmMode == "shipped" then
    local R = mock.load("projects/badger-ttk/src/raids/rhythms.lua").Rhythms
    rhythm = R and (R[enc] or R[enc and enc - 150000])
elseif rhythmMode == "candidate" and enc then
    local f = loadfile(("tools/candidates/rhythm-%d.lua"):format(enc))
    if f then
        rhythm = f()
    end
end

-- Sleep without spawning a process per frame (LuaJIT ffi; falls back to a spin).
local sleep
do
    local ok, ffi = pcall(require, "ffi")
    if ok then
        pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
        sleep = function(s)
            ffi.C.poll(nil, 0, math.max(0, math.floor(s * 1000)))
        end
    else
        sleep = function(s)
            local t = os.clock() + s
            while os.clock() < t do
            end
        end
    end
end

local C = {
    r = "\27[0m", dim = "\27[38;5;244m", gold = "\27[38;5;178m", good = "\27[38;5;71m",
    warn = "\27[38;5;214m", bad = "\27[38;5;203m", ink = "\27[38;5;252m", bold = "\27[1m",
    hp = "\27[38;5;131m", ttk = "\27[38;5;74m",
}
local W = 54
local BLOCKS = { "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" }

local function bar(frac, width)
    frac = math.max(0, math.min(1, frac or 0))
    local whole = math.floor(frac * width)
    local rem = frac * width - whole
    local s = string.rep("█", whole)
    if whole < width and rem > 1 / 8 then
        s = s .. BLOCKS[math.max(1, math.floor(rem * 8))]
    end
    return s .. string.rep("·", math.max(0, width - #({ s:gsub("[\128-\191]", "") })[1]))
end

local function fmt(t)
    if not t then
        return "  --  "
    end
    if t >= 60 then
        return ("%d:%02d"):format(math.floor(t / 60), math.floor(t % 60))
    end
    return ("%4.1fs"):format(t)
end

-- Replay first, render second: the estimator must not be paced by the animation.
local est = ns.Estimator.new({
    reactivity = 0.5,
    executeThreshold = 0.20,
    executeModifier = 1.2,
    rhythm = rhythm,
    priorRate = priorDur and priorDur > 0 and (1 / priorDur) or nil,
})
-- The early kill rate this fight actually showed, over the first OPEN_W seconds.
local earlyRate
do
    local h0 = samples[1].h
    for _, s in ipairs(samples) do
        if s.t > OPEN_W then
            break
        end
        if s.t > 0 and h0 - s.h > 0 then
            earlyRate = (h0 - s.h) / s.t
        end
    end
end

local gate = G.newGate()
local frames, peak = {}, 0
local disp, prevT, jumps = nil, nil, 0
for i = 1, #samples do
    local s = samples[i]
    est:sample(s.t, s.h, G.damageable(s.h))
    local pred, conf = est:ttk()
    local shown = gate:update(pred, conf)
    -- The gate still sees the RAW estimate; only what the player reads is throttled.
    local out = pred
    -- WO-078: during the opening, substitute the learned baseline for the estimator's own read.
    if openK and earlyRate and pred and s.t <= openTo then
        out = (openK / earlyRate) * s.h
    end
    if shown and pred then
        if throttle and disp and prevT then
            local lim = disp + throttle * (s.t - prevT)
            if out > lim then
                out = lim
            end
        end
        if disp and out - disp > 2.0 then
            jumps = jumps + 1
        end
        disp, prevT = out, s.t
    end
    if shown and out and out > peak then
        peak = out
    end
    frames[#frames + 1] =
        { t = s.t, h = s.h, pred = out, conf = conf, shown = shown, actual = death - s.t }
end

if not static then
    io.write("\27[2J\27[H")
end
print(("%s%s  %s%s"):format(C.gold, C.bold, fight.name or path, C.r))
-- State the simulated PLAYER, not just the fight. A replay without a prior models someone who has never
-- killed this boss, which is the minority case and behaves very differently — it must never be mistaken
-- for the normal experience.
print(
    ("%smaxHP %s · %s · rhythm: %s · throttle: %s · replay %.0f×%s"):format(
        C.dim,
        fight.maxHP and tostring(fight.maxHP) or "?",
        fight.size and (fight.size .. "-player") or "?",
        rhythm and rhythmMode or "none",
        throttle and (throttle .. "s/s") or "off",
        speed,
        C.r
    )
)
print(
    ("%splayer: %s%s\n"):format(
        C.dim,
        priorDur and ("%sRETURNING — has killed this boss in ~%.0fs%s"):format(C.good, priorDur, C.dim)
            or (C.warn .. "FIRST KILL — no history prior (the minority case)" .. C.dim),
        C.r
    )
)

-- One shared seconds-per-cell scale for both time bars. Anchored on the fight's true length (with
-- headroom) rather than on the estimate, so an over-long read visibly overflows instead of silently
-- rescaling the picture under it.
local SCALE = death * 1.25

local latchedAt
local STEP = 2 -- render every other 0.15s sample ≈ 3.3 fps × speed
if static then
    STEP = math.max(1, math.floor(#frames / static))
end
for i = 1, #frames, STEP do
    local f = frames[i]
    -- latchedAt must be found from EVERY frame, not just rendered ones, or a sparse filmstrip
    -- would report the latch late.
    for j = 1, i do
        if frames[j].shown then
            latchedAt = latchedAt or frames[j].t
            break
        end
    end
    local err = (f.shown and f.pred) and (f.pred - f.actual) or nil
    local ecol = C.good
    if err and math.abs(err) > 0.30 * math.max(1, f.actual) then
        ecol = C.bad
    elseif err and math.abs(err) > 0.15 * math.max(1, f.actual) then
        ecol = C.warn
    end

    if static then
        io.write("\n")
    else
        io.write("\27[6;1H")
    end
    -- BOTH time bars share ONE seconds-per-cell scale, so "the estimator is right" reads as "the two
    -- bars are the same length". Scaling each to its own maximum (the first version of this view) made
    -- a locked-on countdown and a drifting one look identical — the comparison has to be like-for-like.
    if f.shown and f.pred then
        io.write(
            ("  %sSAYS  %s%s%s %s%s%s\27[K\n"):format(
                C.ink, C.ttk, bar(f.pred / SCALE, W), C.r, C.bold, fmt(f.pred), C.r
            )
        )
    else
        io.write(
            ("  %sSAYS  %s%s %s— hidden —%s\27[K\n"):format(
                C.ink, C.dim, string.rep("·", W), C.dim, C.r
            )
        )
    end
    io.write(
        ("  %sTRUTH %s%s%s %s%s%s   %s%s%s\27[K\n"):format(
            C.ink, C.good, bar(f.actual / SCALE, W), C.r, C.bold, fmt(f.actual), C.r,
            ecol, err and ("%+.1fs"):format(err) or "", C.r
        )
    )
    -- Health bar.
    io.write(
        ("  %sHP  %s%s%s  %s%5.1f%%%s\27[K\n"):format(
            C.ink, C.hp, bar(f.h, W), C.r, C.bold, f.h * 100, C.r
        )
    )
    io.write(
        ("\n  %st = %5.1fs / %.1fs   conf %.2f   %s\27[K%s\n"):format(
            C.dim, f.t, death, f.conf or 0,
            latchedAt and ("bar appeared at " .. ("%.1fs"):format(latchedAt)) or "bar not shown yet",
            C.r
        )
    )
    io.flush()
    if not static then sleep((0.15 * STEP) / speed) end
end

-- Final read-out.
local sum, n = 0, 0
for _, f in ipairs(frames) do
    if f.shown and f.pred and f.t >= G.WARMUP and f.actual > G.TAIL then
        sum = sum + math.abs(f.pred - f.actual) / f.actual
        n = n + 1
    end
end
print(
    ("\n  %s%s%s over %d graded ticks%s"):format(
        C.bold,
        n > 0 and ("MAPE %.1f%%"):format(100 * sum / n) or "never confident",
        C.r, n, C.r
    )
)
print(
    ("  %sbar on screen from %s · throttle %s · upward jumps >2s: %s%d%s\n"):format(
        C.dim, latchedAt and ("%.1fs"):format(latchedAt) or "never",
        throttle and (throttle .. "s/s") or "OFF",
        jumps > 0 and C.bad or C.good, jumps, C.r
    )
)
