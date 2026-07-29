-- Estimator BATCH-GRADE (WO-070). Replay every fight fixture in a directory through the estimator and
-- print a per-fight table + the AGGREGATE grade across the whole corpus — the "study N runs" view the
-- single-fight replay can't give. Confidence-gated exactly like the live client (see estimator-replay.lua).
--
--     luajit tools/estimator-batch.lua [dir] [estimator.lua]
--     luajit tools/estimator-batch.lua                       # defaults to tools/fights/corpus
--
-- Speed: the estimator module is loaded ONCE and a fresh Estimator.new() is used per fight (no per-fight
-- module reload), so a 200-fight corpus grades in one quick pass. The corpus dir is gitignored (WO-070).
-- (Grading mirrors estimator-replay.lua; a shared tools/estimator-grade.lua is a future refactor.)

local WARMUP = 3.0
local TAIL = 6.0
local MINCONF = 0.5 -- src/core.lua default minConfidenceToShow — grade only what the bar would show

local mock = require("tools.wow-mock.init")
local dir = arg[1] or "tools/fights/corpus"
local estPath = arg[2] or "projects/badger-ttk/src/engine/estimator.lua"
local ns = mock.load(estPath) -- once

-- List *.lua fixtures in the directory (portable via ls; the corpus is flat).
local function fixtures(d)
    local out = {}
    local p = io.popen('ls "' .. d .. '"/*.lua 2>/dev/null')
    if p then
        for line in p:lines() do
            out[#out + 1] = line
        end
        p:close()
    end
    return out
end

-- Grade one fixture → { name, dur, mape, bias, within, shown, n } (nil if nothing graded).
local function grade(path)
    local ok, fight = pcall(function()
        return assert(loadfile(path))()
    end)
    if not ok or type(fight) ~= "table" or not fight.samples or #fight.samples == 0 then
        return nil
    end
    local samples = fight.samples
    local death = samples[#samples].t
    local est = ns.Estimator.new({
        reactivity = 0.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
    })
    local relSum, biasSum, within, n, scored = 0, 0, 0, 0, 0
    for i = 1, #samples do
        local s = samples[i]
        est:sample(s.t, s.h, true)
        local pred, conf = est:ttk()
        local actual = death - s.t
        if pred and s.t >= WARMUP and actual > TAIL then
            scored = scored + 1
            if conf and conf >= MINCONF then
                local rel = math.abs(pred - actual) / actual
                relSum = relSum + rel
                biasSum = biasSum + (pred - actual)
                if rel <= 0.15 then
                    within = within + 1
                end
                n = n + 1
            end
        end
    end
    if n == 0 then
        return { name = fight.name or path, dur = death, mape = nil, n = 0 }
    end
    return {
        name = fight.name or path,
        dur = death,
        mape = relSum / n,
        bias = biasSum / n,
        within = within / n,
        shown = scored > 0 and n / scored or 0,
        n = n,
    }
end

local function median(t)
    if #t == 0 then
        return nil
    end
    local s = {}
    for i = 1, #t do
        s[i] = t[i]
    end
    table.sort(s)
    local m = math.floor(#s / 2)
    return (#s % 2 == 1) and s[m + 1] or (s[m] + s[m + 1]) / 2
end
local function quantile(sorted, q)
    if #sorted == 0 then
        return nil
    end
    return sorted[math.max(1, math.min(#sorted, math.floor(q * #sorted + 0.5)))]
end

local files = fixtures(dir)
if #files == 0 then
    print(
        ("\nno *.lua fixtures in %s — harvest first:  python3 tools/wcl-corpus.py <encounterID>"):format(
            dir
        )
    )
    return
end

local rows = {}
for _, f in ipairs(files) do
    local r = grade(f)
    if r then
        rows[#rows + 1] = r
    end
end
table.sort(rows, function(a, b)
    return (a.mape or math.huge) < (b.mape or math.huge)
end)

print(("\n=== BATCH GRADE  %s  (%d fixtures, estimator %s) ==="):format(dir, #rows, estPath))
print(("%-34s %7s %8s %8s %8s %7s"):format("fight", "dur", "MAPE", "bias", "<15%", "shown"))
local mapes, biases = {}, {}
for _, r in ipairs(rows) do
    if r.mape then
        mapes[#mapes + 1] = r.mape
        biases[#biases + 1] = r.bias
        print(
            ("%-34s %6.1fs %7.1f%% %7.1fs %7.1f%% %6.1f%%"):format(
                (r.name):sub(1, 34),
                r.dur,
                r.mape * 100,
                r.bias,
                r.within * 100,
                r.shown * 100
            )
        )
    else
        print(("%-34s %6.1fs %8s"):format((r.name):sub(1, 34), r.dur, "  (never confident)"))
    end
end

-- Aggregate — the corpus-level verdict.
local sortedM = {}
for i = 1, #mapes do
    sortedM[i] = mapes[i]
end
table.sort(sortedM)
local sumM, sumB = 0, 0
for i = 1, #mapes do
    sumM = sumM + mapes[i]
end
for i = 1, #biases do
    sumB = sumB + biases[i]
end
print(("\nAGGREGATE over %d graded fights:"):format(#mapes))
if #mapes > 0 then
    print(
        ("  MAPE   mean %.1f%%   median %.1f%%   p90 %.1f%%"):format(
            100 * sumM / #mapes,
            100 * median(mapes),
            100 * quantile(sortedM, 0.9)
        )
    )
    print(("  bias   mean %+.1fs  (>0 = reads long)"):format(sumB / #biases))
    print(("  best %.1f%%  ·  worst %.1f%%"):format(100 * sortedM[1], 100 * sortedM[#sortedM]))
end
print("")
