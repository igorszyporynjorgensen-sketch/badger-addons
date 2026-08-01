-- Per-health-bin error profile of the SHIPPED estimator (WO-075 / the regime lab).
--
--     luajit tools/estimator-perbin.lua <encounterID> [corpusDir] [--even]
--
-- Replays every corpus fixture for one encounter through the real estimator — with the SHIPPED rhythm
-- injected (exactly what the client runs) and NO regime — and reports, per health bin, how wrong the
-- readout actually is. `tools/learn-regime.py` turns that into confidence caps: the bar is allowed to be
-- confident where it is measurably right, and is quieted where it is measurably wrong. Measuring the real
-- estimator (rather than a statistical proxy for it) is what keeps the learned caps honest — a proxy such
-- as the dispersion of remaining time explodes near death purely because the denominator vanishes, which
-- would silence the endgame, the very stretch the readout gets RIGHT.
--
-- Output: one TSV row per bin — bin  n  medianRel  medianAbs  (bin 20 = h in (0.95,1.0], bin 1 = execute).
-- `--even` uses only the EVEN-indexed fixtures — the same deterministic train half the learners use.

local WARMUP = 3.0 -- ignore the opening: no evidence yet
local TAIL = 6.0 -- ignore the last seconds: everything is "about to die"
local K = 20 -- health bins (mirrors the estimator's confCap/rhythm bin math)

local mock = require("tools.wow-mock.init")
local enc =
    assert(tonumber(arg[1]), "usage: estimator-perbin.lua <encounterID> [corpusDir] [--even]")
local dir = (arg[2] and not arg[2]:match("^%-%-")) and arg[2] or "tools/fights/corpus"
local evenOnly, suppressFlush = false, false
for i = 2, #arg do
    if arg[i] == "--even" then
        evenOnly = true
    elseif arg[i] == "--suppress-flush" then
        -- Measure with the categorical fact that WILL ship enabled. Caps must be learned under the
        -- configuration the client actually runs: Buru's scripted chunk damage triggers the regime-change
        -- flush, and suppressing it cuts his error ~3x — caps learned without it would be calibrated to an
        -- estimator far worse than the one that ships, and would silence a readout that is in fact fine.
        suppressFlush = true
    end
end

local ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
local rhythms = mock.load("projects/badger-ttk/src/raids/rhythms.lua").Rhythms
local rhythm = rhythms and rhythms[enc]

local files = {}
local p = io.popen(('ls "%s"/%d-*.lua 2>/dev/null'):format(dir, enc))
if p then
    for line in p:lines() do
        files[#files + 1] = line
    end
    p:close()
end
if #files == 0 then
    io.stderr:write(("no fixtures for encounter %d in %s\n"):format(enc, dir))
    os.exit(1)
end

local rel, abs = {}, {} -- per bin: lists of relative / absolute error
for i = 1, K do
    rel[i], abs[i] = {}, {}
end

local used = 0
for idx, path in ipairs(files) do
    if not evenOnly or idx % 2 == 1 then -- 1-based odd == 0-based even (matches the python split)
        local ok, fight = pcall(function()
            return assert(loadfile(path))()
        end)
        if ok and type(fight) == "table" and fight.samples and #fight.samples > 0 then
            used = used + 1
            local samples = fight.samples
            local death = samples[#samples].t
            local est = ns.Estimator.new({
                reactivity = 0.5,
                executeThreshold = 0.20,
                executeModifier = 1.2,
                rhythm = rhythm,
                regime = suppressFlush and { suppressFlush = true } or nil,
            })
            for i = 1, #samples do
                local s = samples[i]
                est:sample(s.t, s.h, true)
                local pred = est:ttk()
                local actual = death - s.t
                if pred and s.t >= WARMUP and actual > TAIL then
                    local b = math.floor(s.h * K) + 1
                    if b > K then
                        b = K
                    end
                    if b < 1 then
                        b = 1
                    end
                    rel[b][#rel[b] + 1] = math.abs(pred - actual) / actual
                    abs[b][#abs[b] + 1] = math.abs(pred - actual)
                end
            end
        end
    end
end

local function median(t)
    if #t == 0 then
        return nil
    end
    table.sort(t)
    local m = math.floor(#t / 2)
    return (#t % 2 == 1) and t[m + 1] or (t[m] + t[m + 1]) / 2
end

io.stderr:write(
    ("perbin: encounter %d — %d fixtures%s\n"):format(
        enc,
        used,
        evenOnly and " (train half)" or ""
    )
)
for b = K, 1, -1 do
    local mr, ma = median(rel[b]), median(abs[b])
    if mr then
        print(("%d\t%d\t%.4f\t%.2f"):format(b, #rel[b], mr, ma))
    end
end
