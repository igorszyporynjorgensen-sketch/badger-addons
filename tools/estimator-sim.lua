-- Offline TTK-estimator simulation harness (WO-056). Runs one or more estimator implementations over
-- deterministic synthetic combat traces and prints stability/accuracy metrics, so an estimator change is
-- proven NUMERICALLY off-client (the gate proves specs, not feel; this proves feel). Pure Lua 5.1 —
-- run from the repo root:
--
--     luajit tools/estimator-sim.lua [estimator.lua ...]
--
-- With no args it compares the live estimator against itself (one column). Typical use: pass a snapshot
-- of the old estimator plus the live file and read the columns side by side.
--
-- Metrics (per trace, ignoring the first WARMUP seconds):
--   cdev   mean |Δttk + dt| per tick — deviation from the ideal 1s/s countdown (0 = a perfect timer)
--   jump1s max |ttk(t) − (ttk(t−1s) − 1s)| — the worst single-second readout jump the user can see
--   rmse   root-mean-square error vs the trace's realized time-to-death
--   nil%   fraction of ticks reading nil after the first non-nil estimate
--   adapt  (burst trace only) seconds after the rate doubles until the estimate stays within 15% of truth

local DT = 0.15 -- driver sampling cadence (src/live/driver.lua INTERVAL)
local WARMUP = 3.0 -- seconds excluded from metrics (both estimators are allowed a warm-up)

-- Deterministic LCG so every run (and every interpreter) sees the identical traces.
local seed = 42
local function rand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end
local function range(lo, hi)
    return lo + (hi - lo) * rand()
end

-- ── Trace generators ─────────────────────────────────────────────────────────────────────────────
-- A trace is { name, samples = { {t, h}, ... }, death, priorRate (nil = no history), burstAt (optional) }.
-- Health is piecewise per the generator; samples poll it every DT like the live driver polls UnitHealth.

-- Chunky melee: a player far above the mob's level — big hits every couple of seconds, nothing between.
local function chunkyTrace(name, withPrior)
    local hits, t, h = {}, 0, 1
    while h > 0 do
        t = t + range(2.2, 2.8)
        local chunk = range(0.25, 0.40)
        if rand() < 0.15 then
            chunk = chunk * 1.8 -- crit
        end
        h = h - chunk
        hits[#hits + 1] = { t = t, h = (h > 0) and h or 0 }
        if h <= 0 then
            break
        end
    end
    local death = hits[#hits].t
    local samples, hi = {}, 1
    local cur = 1
    for st = 0, death, DT do
        while hi <= #hits and hits[hi].t <= st do
            cur = hits[hi].h
            hi = hi + 1
        end
        samples[#samples + 1] = { t = st, h = cur }
    end
    return {
        name = name,
        samples = samples,
        death = death,
        priorRate = withPrior and (1 / death) or nil,
    }
end

-- Smooth raid boss: many attackers chip steadily with mild per-tick jitter.
local function raidTrace()
    local samples, t, h = {}, 0, 1
    local rate = 1 / 180 -- ~3-minute kill
    while h > 0 do
        samples[#samples + 1] = { t = t, h = h }
        h = h - rate * DT * range(0.8, 1.2)
        t = t + DT
    end
    samples[#samples + 1] = { t = t, h = 0 }
    return { name = "raid-smooth", samples = samples, death = t, priorRate = rate }
end

-- Burst: a raid kill whose rate jumps ×mult mid-fight (adds die / burst phase) — adaptation lag. A ×2
-- deliberately sits BELOW the estimator's regime-flush band (crit protection) and rides the τ-window;
-- ≥×2.5 should fire the two-consecutive-events flush and adopt within a couple of events.
local function burstTrace(mult)
    local samples, t, h = {}, 0, 1
    local burstAt = 45
    while h > 0 do
        samples[#samples + 1] = { t = t, h = h }
        local rate = ((t < burstAt) and 1 or mult) / 150
        h = h - rate * DT * range(0.9, 1.1)
        t = t + DT
    end
    samples[#samples + 1] = { t = t, h = 0 }
    return {
        name = ("burst-x%d@45s"):format(mult),
        samples = samples,
        death = t,
        priorRate = 1 / 150,
        burstAt = burstAt,
    }
end

-- Chunky burst: discrete 10% hits every 2.5s, then at t=12 the party arrives — 30% every 1.25s (×6
-- rate). The flush must fire on the second burst swing (~2.5s in), not ride the window.
local function chunkyBurstTrace()
    local samples = {}
    local h, t, hitAt, burstAt = 1, 0, 2.5, 12
    local nextHit = hitAt
    while h > 0 do
        for st = t, nextHit - DT / 2, DT do
            samples[#samples + 1] = { t = st, h = h }
        end
        t = nextHit
        local burst = t >= burstAt
        h = h - (burst and 0.30 or 0.10) * range(0.9, 1.1)
        nextHit = t + (burst and 1.25 or 2.5)
        if h < 0 then
            h = 0
        end
    end
    samples[#samples + 1] = { t = t, h = 0 }
    return {
        name = "chunky-burst-x6",
        samples = samples,
        death = t,
        priorRate = 0.10 / 2.5,
        burstAt = burstAt,
    }
end

-- Chunky fight with a mid-fight heal: TTK must not go negative or explode.
local function healTrace()
    local base = chunkyTrace("heal", true)
    local samples = {}
    for i = 1, #base.samples do
        local s = base.samples[i]
        local h = s.h
        if s.t >= 8 then
            h = h + 0.15 -- the mob healed 15% at t=8
            if h > 1 then
                h = 1
            end
        end
        samples[#samples + 1] = { t = s.t, h = h }
    end
    -- Death shifts later; keep the realized trace but skip rmse (truth is murky) — stability still counts.
    return { name = "chunky+heal", samples = samples, death = nil, priorRate = base.priorRate }
end

-- ── Runner ───────────────────────────────────────────────────────────────────────────────────────

-- ── Party/raid traces (WO-066) ───────────────────────────────────────────────────────────────────
-- Raids kill via MANY overlapping attackers, so the target's health drops smoothly/continuously — the
-- estimator's design sweet spot (many small drops per tau), the opposite of the chunky solo-melee case.
-- Composition shows up as rate (how fast) + jitter (how lumpy): casters/DoTs = low jitter; melee = high;
-- healer-heavy = a low rate. An optional immune window [imStart,imEnd) freezes health; `imDamageable` is
-- what the driver feeds during it — true today (the gap), false if a boss profile marked the phase.
local function contTrace(name, rate, jitter, imStart, imEnd, imDamageable)
    local samples, t, h = {}, 0, 1
    while h > 0 do
        local frozen = imStart and t >= imStart and t < imEnd
        samples[#samples + 1] = { t = t, h = h, damageable = (not frozen) or imDamageable }
        if not frozen then
            h = h - rate * DT * range(1 - jitter, 1 + jitter)
        end
        t = t + DT
    end
    samples[#samples + 1] = { t = t, h = 0 }
    return { name = name, samples = samples, death = t, priorRate = rate }
end

-- A boss fight where DPS jumps mid-fight — Bloodlust/Heroism ~+40% (deliberately BELOW the 2.5x regime
-- flush, so it must ride the tau-window, not flush). Measures adaptation to a realistic raid surge.
local function heroismTrace()
    local samples, t, h = {}, 0, 1
    local base, at = 1 / 180, 60
    while h > 0 do
        samples[#samples + 1] = { t = t, h = h }
        local rate = (t < at) and base or (base * 1.4)
        h = h - rate * DT * range(0.85, 1.15)
        t = t + DT
    end
    samples[#samples + 1] = { t = t, h = 0 }
    return {
        name = "raid-heroism+40%",
        samples = samples,
        death = t,
        priorRate = base,
        burstAt = at,
    }
end

local function runTrace(Estimator, trace)
    local est = Estimator.new({
        reactivity = 0.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
        priorRate = trace.priorRate,
    })
    local reads = {} -- { t, ttk } per tick (ttk may be nil)
    for i = 1, #trace.samples do
        local s = trace.samples[i]
        est:sample(s.t, s.h, s.damageable ~= false)
        local ttk = est:ttk()
        reads[#reads + 1] = { t = s.t, ttk = ttk }
    end

    local cdevSum, cdevN, maxJump, sqSum, sqN, nilN, seen = 0, 0, 0, 0, 0, 0, false
    local byTime = {}
    for i = 1, #reads do
        byTime[i] = reads[i]
    end
    local perSec = math.floor(1 / DT + 0.5)
    local adaptAt
    for i = 1, #reads do
        local r = reads[i]
        if r.ttk then
            seen = true
        elseif seen then
            nilN = nilN + 1
        end
        if r.t >= WARMUP and r.ttk then
            local prev = byTime[i - 1]
            if prev and prev.ttk then
                cdevSum = cdevSum + math.abs((r.ttk - prev.ttk) + DT)
                cdevN = cdevN + 1
            end
            local ago = byTime[i - perSec]
            if ago and ago.ttk then
                local jump = math.abs(r.ttk - (ago.ttk - 1))
                if jump > maxJump then
                    maxJump = jump
                end
            end
            if trace.death then
                local truth = trace.death - r.t
                if truth > 0 then
                    sqSum = sqSum + (r.ttk - truth) ^ 2
                    sqN = sqN + 1
                end
            end
        end
        -- Burst adaptation: first time (after the burst) the estimate stays within 15% of truth.
        if trace.burstAt and not adaptAt and r.t > trace.burstAt and r.ttk and trace.death then
            local truth = trace.death - r.t
            if truth > 1 and math.abs(r.ttk - truth) / truth <= 0.15 then
                adaptAt = r.t - trace.burstAt
            end
        end
    end
    return {
        cdev = (cdevN > 0) and (cdevSum / cdevN) or 0,
        jump1s = maxJump,
        rmse = (sqN > 0) and math.sqrt(sqSum / sqN) or nil,
        nilFrac = (#reads > 0) and (nilN / #reads) or 0,
        adapt = adaptAt,
    }
end

local function fmt(v, unit)
    if v == nil then
        return "    —"
    end
    return string.format("%5.2f%s", v, unit or "")
end

local mock = require("tools.wow-mock.init")
local paths = { ... }
if #paths == 0 then
    paths = { "projects/badger-ttk/src/engine/estimator.lua" }
end

-- Regenerate the trace set identically for every estimator (reset the LCG before each build).
local function buildTraces()
    seed = 42
    return {
        chunkyTrace("chunky+prior", true),
        chunkyTrace("chunky-noprior", false),
        raidTrace(),
        burstTrace(2), -- below the flush band: rides the τ-window
        burstTrace(3), -- inside the flush band: fires within two events
        -- Party/raid regimes (WO-066): composition = rate + jitter; casters smooth, melee lumpy.
        contTrace("raid-caster-heavy", 1 / 120, 0.2), -- casters/DoTs: smooth continuous chip
        contTrace("raid-melee-heavy", 1 / 120, 0.8), -- many overlapping melee swings: lumpier
        contTrace("raid-healer-heavy", 1 / 300, 0.3), -- fewer DPS → slow but smooth (5-min kill)
        heroismTrace(), -- +40% Bloodlust mid-fight (rides the window)
        contTrace("raid-immune-DRIVER", 1 / 150, 0.3, 40, 60, true), -- 20s immune, fed as driver does now
        contTrace("raid-immune-PROFILE", 1 / 150, 0.3, 40, 60, false), -- same, if a boss profile paused it
        chunkyBurstTrace(),
        healTrace(),
    }
end

for _, path in ipairs(paths) do
    local ns = mock.load(path)
    local traces = buildTraces()
    print(("\n== %s =="):format(path))
    print(("%-16s %8s %8s %8s %6s %7s"):format("trace", "cdev", "jump1s", "rmse", "nil%", "adapt"))
    for _, trace in ipairs(traces) do
        local m = runTrace(ns.Estimator, trace)
        print(
            ("%-16s %8s %8s %8s %5.1f%% %7s"):format(
                trace.name,
                fmt(m.cdev, "s"),
                fmt(m.jump1s, "s"),
                fmt(m.rmse, "s"),
                m.nilFrac * 100,
                fmt(m.adapt, "s")
            )
        )
    end
end
