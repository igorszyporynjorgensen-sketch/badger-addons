-- Estimator REPLAY + GRADE harness (WO-067). Feed a real fight's health curve (a Warcraft Logs export,
-- via the future converter — or the sample) through the pure estimator OFF-CLIENT and grade its predicted
-- TTK against ground truth: the fight already happened, so at every tick we KNOW the true remaining time.
--
--     luajit tools/estimator-replay.lua <fight.lua> [estimator.lua]
--
-- A fight file returns { name, samples = { {t, h}, ... }, priorRate? } — the boss HEALTH FRACTION over
-- time at ~0.15s. Death = the last sample's t.
--
-- PHILOSOPHY (per the human): grade the RHYTHM, not the clock. A speedguild's kill and a pug's kill are
-- both valid curves — the estimator's job is to predict ITS OWN fight's remaining time. So the headline is
-- RELATIVE error (% of remaining, length-independent), plus how fast it recovers from a MISMATCHED prior
-- (a speedguild import on your slower kill). Absolute seconds are context only. And it doesn't just score —
-- it points at the worst moments and says WHY it was off, so we know what to tune.

local DT = 0.15
local W = 27 -- ~4s window for the local-rate "why" heuristic
-- Grade only what the PLAYER sees. The live driver hides the bar until minTTK AND minConfidenceToShow
-- both clear — and then STOPS CHECKING (the gate is sticky). Both the window and that gate live in the
-- shared harness (WO-076) so all three graders model the same client.
local G = require("tools.estimator-grade")
local WARMUP, TAIL = G.WARMUP, G.TAIL

local mock = require("tools.wow-mock.init")
local fightPath = arg[1] or error("usage: estimator-replay.lua <fight.lua> [estimator.lua]")
local estPath = arg[2] or "projects/badger-ttk/src/engine/estimator.lua"
local fight = assert(loadfile(fightPath))()
local samples = fight.samples
local death = samples[#samples].t

local function newEst(priorRate)
    local ns = mock.load(estPath)
    return ns.Estimator.new({
        reactivity = 0.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
        priorRate = priorRate,
    })
end

-- Replay the fight; return per-tick { t, h, pred, actual } (pred may be nil while unknown).
local function replay(priorRate)
    local est = newEst(priorRate)
    local gate = G.newGate()
    local reads = {}
    for i = 1, #samples do
        local s = samples[i]
        est:sample(s.t, s.h, G.damageable(s.h))
        local pred, conf = est:ttk()
        -- The gate sees every tick, in order — it can latch during the warm-up.
        local onScreen = gate:update(pred, conf)
        reads[i] =
            { t = s.t, h = s.h, pred = pred, conf = conf, shown = onScreen, actual = death - s.t }
    end
    return reads
end

-- A tick is in scope for grading if it's past warm-up, before the noisy tail, AND the estimate had one.
local function scored(r)
    return r.pred and r.t >= WARMUP and r.actual > TAIL
end

-- ...and it's actually GRADED only if the bar was on screen — which, once latched, it stays.
local function graded(r)
    return scored(r) and r.shown
end

-- Aggregate the length-independent grade.
local function metrics(reads)
    local relSum, n, within, mae, biasSum, seen = 0, 0, 0, 0, 0, false
    local scoredN = 0 -- ticks in scope (warm-up/tail) regardless of confidence
    local decile = {} -- [1..9] = { sumRatio, n } for health 90%..10%
    for i = 1, 9 do
        decile[i] = { 0, 0 }
    end
    -- convergence: the last tick where relErr first exceeded 15% (it "locks in" after that)
    local convergedT
    for _, r in ipairs(reads) do
        if scored(r) then
            scoredN = scoredN + 1
        end
        if graded(r) then
            seen = true
            local rel = math.abs(r.pred - r.actual) / r.actual
            relSum = relSum + rel
            n = n + 1
            if rel <= 0.15 then
                within = within + 1
            else
                convergedT = nil
            end
            if rel <= 0.15 and convergedT == nil then
                convergedT = r.t
            end
            mae = mae + math.abs(r.pred - r.actual)
            biasSum = biasSum + (r.pred - r.actual)
            local b = math.floor(r.h * 10) -- 9..0
            if b >= 1 and b <= 9 then
                local d = decile[b]
                d[1] = d[1] + r.pred / r.actual
                d[2] = d[2] + 1
            end
        end
    end
    local convHP
    if convergedT then
        for _, r in ipairs(reads) do
            if r.t >= convergedT then
                convHP = r.h
                break
            end
        end
    end
    return {
        mape = n > 0 and relSum / n or nil,
        within = n > 0 and within / n or 0,
        convHP = convHP,
        mae = n > 0 and mae / n or nil,
        bias = n > 0 and biasSum / n or nil,
        decile = decile,
        seen = seen,
        shown = scoredN > 0 and n / scoredN or 0, -- fraction of in-scope ticks the client would show
        gradedN = n,
    }
end

-- Why was it off at tick i? Look at the local health rhythm around it.
local function why(reads, i, r)
    local a, b = reads[i - W], reads[i - 2 * W]
    local dropRecent = a and (a.h - r.h) or 0
    local rateRecent = a and (dropRecent / (r.t - a.t)) or 0
    local ratePrev = (a and b) and ((b.h - a.h) / (a.t - b.t)) or rateRecent
    local dir = r.pred > r.actual and "reads too LONG" or "reads too SHORT"
    local cause
    if dropRecent < 0.002 then
        cause = "damage lull — the estimate stalled"
    elseif ratePrev > 0 and rateRecent > 1.8 * ratePrev then
        cause = "lagging a damage speed-up (Bloodlust/execute)"
    elseif ratePrev > 0 and rateRecent < 0.55 * ratePrev then
        cause = "lagging a slow-down"
    elseif r.h < 0.20 then
        cause = "execute phase (fast, chunky)"
    elseif r.t < WARMUP + 4 then
        cause = "still warming up"
    else
        cause = "residual jitter"
    end
    return dir, cause
end

local function pct(x)
    return x and string.format("%5.1f%%", x * 100) or "   —"
end
local function secs(x)
    return x and string.format("%6.1fs", x) or "     —"
end

print(("\n=== REPLAY  %s ==="):format(fight.name or fightPath))
print(("fight: dies at %.0fs · %d samples · estimator %s"):format(death, #samples, estPath))

-- The base grade (cold — no prior; pure live tracking of THIS curve's rhythm).
local base = replay(nil)
local m = metrics(base)
print("\nRHYTHM  (relative — the length-independent grade, over what the bar actually SHOWS):")
print(
    ("  on screen                  %s   of in-scope ticks (sticky gate: ttk ≥ %ds, conf ≥ %.2f)"):format(
        pct(m.shown),
        G.MINTTK,
        G.MINCONF
    )
)
print(("  MAPE (mean |err|/remaining) %s   <- the headline (graded ticks only)"):format(pct(m.mape)))
print(("  within 15%%                  %s   of graded ticks"):format(pct(m.within)))
print(("  locks within 15%% by         %s HP"):format(pct(m.convHP)))
print("timing  (absolute — context only; scales with fight length):")
print(("  MAE %s   bias %s"):format(secs(m.mae), secs(m.bias)))

-- Where it drifted — the top worst-error moments, with a cause. THE LESSONS.
local worst = {}
for i, r in ipairs(base) do
    if graded(r) then
        worst[#worst + 1] = { i = i, rel = math.abs(r.pred - r.actual) / r.actual, r = r }
    end
end
table.sort(worst, function(x, y)
    return x.rel > y.rel
end)
print("\nWHERE IT DRIFTED  (worst moments — where + why we were off):")
print(("  %6s %6s %8s %8s %7s  reason"):format("t", "HP", "pred", "actual", "err"))
local shown, lastT = 0, -99
for _, w in ipairs(worst) do
    if shown >= 6 then
        break
    end
    if math.abs(w.r.t - lastT) > 8 then -- de-cluster: one line per drift region
        local dir, cause = why(base, w.i, w.r)
        print(
            ("  %5.0fs %5.0f%% %7.0fs %7.0fs %6.0f%%  %s (%s)"):format(
                w.r.t,
                w.r.h * 100,
                w.r.pred,
                w.r.actual,
                w.rel * 100,
                cause,
                dir
            )
        )
        shown = shown + 1
        lastT = w.r.t
    end
end

-- Prior sensitivity: does a MISMATCHED import (speedguild vs sweats) break it? Grade the same fight cold,
-- with the correct prior, and with 2x-fast / 2x-slow priors. Live tracking should dominate either way.
print("\nPRIOR SENSITIVITY  (a speedguild's times shouldn't break your slower kill):")
print(("  %-18s %8s %10s"):format("prior", "MAPE", "locks@HP"))
local full = 1 / death -- the fight's own average rate
for _, sc in ipairs({
    { "cold (none)", nil },
    { "correct", full },
    { "2x fast (sweats)", full * 2 },
    { "2x slow (pug)", full * 0.5 },
}) do
    local mm = metrics(replay(sc[2]))
    print(("  %-18s %8s %9s"):format(sc[1], pct(mm.mape), pct(mm.convHP)))
end

-- Per-decile rhythm: predicted ÷ actual across the fight's SHAPE (should hover ~1.0 regardless of length).
print("\nRHYTHM BY HEALTH  (predicted ÷ actual remaining — ~1.0 = tracking the shape):")
local hdr, row = "  ", "  "
for bkt = 9, 1, -1 do
    hdr = hdr .. string.format("%6d%%", bkt * 10)
    local d = m.decile[bkt]
    row = row .. (d[2] > 0 and string.format("%6.2f", d[1] / d[2]) or "     —")
end
print(hdr)
print(row)
print("")
