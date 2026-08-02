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

-- The grading window and the client's STICKY show gate both live in the shared harness (WO-076), so the
-- three graders cannot drift apart again. Grade only what the bar would actually show.
local G = require("tools.estimator-grade")
local WARMUP, TAIL = G.WARMUP, G.TAIL

local mock = require("tools.wow-mock.init")
-- Positional args are the first two NON-flag arguments, so flags may appear anywhere.
local positional = {}
for i = 1, #arg do
    if not tostring(arg[i]):match("^%-%-") then
        positional[#positional + 1] = arg[i]
    end
end
local dir = positional[1] or "tools/fights/corpus"
local estPath = positional[2] or "projects/badger-ttk/src/engine/estimator.lua"
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

-- Rhythm-profile resolution (WO-069 loop 2): the grader plays the DRIVER's role — a fixture carries its
-- `encounterID`, and if a learned profile exists for it (tools/candidates/rhythm-<enc>.lua) it is
-- INJECTED via opts.rhythm, exactly as the live driver will on ENCOUNTER_START. The shipped estimator
-- ignores the field (baseline unchanged); a rhythm-aware candidate consumes it. No profile ⇒ nil.
local function rhythmFor(encounterID)
    if not encounterID then
        return nil
    end
    local ok, prof = pcall(function()
        return assert(loadfile(("tools/candidates/rhythm-%d.lua"):format(encounterID)))()
    end)
    return (ok and type(prof) == "table") and prof or nil
end

-- Regime injection (WO-075): the grader plays the DRIVER's role for regimes too — a candidate
-- tools/candidates/regime-<enc>.lua is injected via opts.regime, EXACTLY as the live driver will on
-- ENCOUNTER_START. The estimator still freezes ITSELF off h; the sample call passes only `damageable`
-- (alive/dead, WO-076) and carries no regime knowledge of its own.
-- No candidate ⇒ nil ⇒ baseline (the non-regime regression guard: those boss rows stay byte-identical).
-- `--shipped` grades the profile that actually SHIPS (src/raids/regimes.lua) instead of the lab candidate.
-- They are not the same artifact: the shipped profile also carries the hand-authored categorical facts
-- (suppressFlush, hideBar) that the learner never emits, so a candidate-only grade can badly misreport a
-- boss whose fix is one of those facts (Buru's flush suppression is worth ~3x on its own).
local useShipped = false
for i = 1, #arg do
    if arg[i] == "--shipped" then
        useShipped = true
    end
end
local shippedRegimes = useShipped and mock.load("projects/badger-ttk/src/raids/regimes.lua").Regimes
    or nil

local function regimeFor(encounterID)
    if not encounterID then
        return nil
    end
    if useShipped then
        return shippedRegimes and (shippedRegimes[encounterID] or shippedRegimes.default) or nil
    end
    local ok, prof = pcall(function()
        return assert(loadfile(("tools/candidates/regime-%d.lua"):format(encounterID)))()
    end)
    return (ok and type(prof) == "table") and prof or nil
end

-- Grade one fixture → { name, dur, mape, bias, within, shown, n } (nil if nothing graded).
local function grade(path, priorRate)
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
        rhythm = rhythmFor(fight.encounterID),
        regime = regimeFor(fight.encounterID),
        priorRate = priorRate, -- nil = cold (never killed it); set = the returning player (WO-077 F1)
    })
    local relSum, biasSum, within, n, scored = 0, 0, 0, 0, 0
    local gate = G.newGate()
    for i = 1, #samples do
        local s = samples[i]
        est:sample(s.t, s.h, G.damageable(s.h))
        local pred, conf = est:ttk()
        -- The gate sees EVERY tick (it can latch during the warm-up); grading stays in-window.
        local onScreen = gate:update(pred, conf)
        local actual = death - s.t
        if pred and s.t >= WARMUP and actual > TAIL then
            scored = scored + 1
            if onScreen then
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

-- Single-file mode (WO-071): pass a fight FILE instead of a directory to grade just that fight and print
-- one tab-separated RESULT line — the ttk-lab terminal dashboard grades incrementally as fights land.
-- Fields: RESULT · name · dur · mape (or NC = never confident) · bias · within15 · shown.
if dir:match("%.lua$") then
    local r = grade(dir)
    if not r then
        print("RESULT\tERROR\t0\tNC\t0\t0\t0")
    elseif r.mape then
        print(
            ("RESULT\t%s\t%.2f\t%.4f\t%.2f\t%.4f\t%.4f"):format(
                r.name,
                r.dur,
                r.mape,
                r.bias,
                r.within,
                r.shown
            )
        )
    else
        print(("RESULT\t%s\t%.2f\tNC\t0\t0\t0"):format(r.name, r.dur))
    end
    return
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

-- HISTORY PRIOR (WO-077 F1). The graders built Estimator.new WITHOUT priorRate, but driver.lua:219
-- ALWAYS passes one and core.lua:78-79 default useHistory/recordHistory to true — so every number the
-- lab produced described a player who had NEVER killed the boss. That is the minority case, and it is
-- WO-076's defect one layer down: the lab modelling a client that does not exist.
--
-- `--prior loo` models the returning player. History.rate averages 1/dur over past kills of the same
-- boss at the same group size (history.lua:88-131), so the lab equivalent is a LEAVE-ONE-OUT mean of
-- 1/dur over the other fixtures of this encounter. Recency weighting (RECENCY=0.8) is deliberately not
-- modelled: fixtures carry no per-player kill order, and a flat mean is that weighting's limit.
-- NOTE the flag takes no value: positional args are "the first two non-`--` arguments" (see line 19), so
-- a `--prior loo` pair would silently donate `loo` to positional[2] and load it as the estimator path.
local looPrior = {} -- path -> priorRate
local wantLoo = false
for i = 1, #arg do
    if tostring(arg[i]) == "--prior-loo" then
        wantLoo = true
    end
end
if wantLoo then
    local byEnc = {} -- encounterID -> { {path=, invDur=}, ... }
    for _, f in ipairs(files) do
        local ok, fight = pcall(function()
            return assert(loadfile(f))()
        end)
        if ok and type(fight) == "table" and fight.samples and #fight.samples > 0 then
            local d = fight.samples[#fight.samples].t
            local e = fight.encounterID or 0
            if d and d > 0 then
                byEnc[e] = byEnc[e] or {}
                table.insert(byEnc[e], { path = f, inv = 1 / d })
            end
        end
    end
    for _, list in pairs(byEnc) do
        local sum = 0
        for _, it in ipairs(list) do
            sum = sum + it.inv
        end
        for _, it in ipairs(list) do
            -- leave-one-out: this kill is not part of its own history
            if #list > 1 then
                looPrior[it.path] = (sum - it.inv) / (#list - 1)
            end
        end
    end
end

local rows = {}
for _, f in ipairs(files) do
    local r = grade(f, looPrior[f])
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
