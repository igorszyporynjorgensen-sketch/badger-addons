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
-- Output: one TSV row per bin — bin  n  medianRel  medianAbs  preShow
-- (bin 20 = h in (0.95,1.0], bin 1 = execute).
-- `--even` uses only the EVEN-indexed fixtures — the same deterministic train half the learners use.
--
-- `preShow` (WO-076) is the REACHABILITY of the bin: the fraction of its in-scope samples where the bar
-- had not yet latched. The client's show gate is sticky (src/live/driver.lua:55-80), so a confCap can only
-- ever act while the bar is still hidden — a cap in a bin with preShow ≈ 0 is dead data that will never
-- fire in game. `learn-regime.py` drops those rather than emitting them. Measuring it here (rather than
-- assuming it) is the same discipline as measuring the error itself.

local G = require("tools.estimator-grade")
local WARMUP, TAIL = G.WARMUP, G.TAIL
local K = 20 -- health bins (mirrors the estimator's confCap/rhythm bin math)

local mock = require("tools.wow-mock.init")
local enc =
    assert(tonumber(arg[1]), "usage: estimator-perbin.lua <encounterID> [corpusDir] [--even]")
local dir = (arg[2] and not arg[2]:match("^%-%-")) and arg[2] or "tools/fights/corpus"
-- `--regime '<lua table literal>'` measures with the OTHER regime fields that will ship already active
-- (suppressFlush, resetOnRise — never confCap, which is what we are deriving). Caps must be calibrated
-- against the estimator the client actually runs: measured without its own facts, Buru's error is ~3x worse
-- and Thekal's ~1.5x worse, so the caps would silence readouts that are in fact usable.
local evenOnly, contextRegime = false, nil
for i = 2, #arg do
    if arg[i] == "--even" then
        evenOnly = true
    elseif arg[i] == "--regime" then
        local src = arg[i + 1]
        if src and src ~= "" then
            local chunk = assert(loadstring("return " .. src), "bad --regime literal")
            contextRegime = chunk()
        end
    end
end

local ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
local rhythms = mock.load("projects/badger-ttk/src/raids/rhythms.lua").Rhythms
local rhythm = rhythms and rhythms[enc]

local files = {}
-- LC_ALL=C forces BYTE ordering, matching Python's sorted() in learn-rhythm.py / learn-regime.py. The
-- even/odd train-test split is taken over this order in three separate tools, so they must agree on it.
-- Measured identical under the current locale — this pins it so it cannot drift with the environment.
local p = io.popen(('LC_ALL=C ls "%s"/%d-*.lua 2>/dev/null'):format(dir, enc))
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

-- PER-KILL aggregation (WO-077). Each kill contributes exactly ONE value per bin — its own median — and
-- the bin's figure is the median ACROSS KILLS. The previous version pooled every in-window sample into
-- one flat list, so a kill's weight was proportional to its DURATION: on a spectrum corpus a 320s kill
-- outvotes a 15s kill ~20:1 and the slow tier silently dictates the learned caps. Harmless when every
-- fixture is a similar length (the old MC corpus), corrupting the moment the corpus spans durations on
-- purpose — which is exactly what this pass builds. Mirrors learn-rhythm.py:75's per-kill median.
local rel, abs = {}, {} -- per bin: one entry PER KILL (that kill's median error)
local samplesN = {} -- per bin: total in-scope samples (reporting only, no longer a weight)
local preShow = {} -- per bin: one entry per kill — that kill's pre-latch fraction in this bin
for i = 1, K do
    rel[i], abs[i], preShow[i] = {}, {}, {}
    samplesN[i] = 0
end

local function med(t)
    if #t == 0 then
        return nil
    end
    table.sort(t)
    local m = math.floor(#t / 2)
    return (#t % 2 == 1) and t[m + 1] or (t[m] + t[m + 1]) / 2
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
                regime = contextRegime,
            })
            local gate = G.newGate()
            -- This kill's own per-bin samples; collapsed to one value per bin below.
            local kRel, kAbs, kPre, kN = {}, {}, {}, {}
            for i = 1, K do
                kRel[i], kAbs[i], kPre[i], kN[i] = {}, {}, 0, 0
            end
            for i = 1, #samples do
                local s = samples[i]
                est:sample(s.t, s.h, G.damageable(s.h))
                local pred, conf = est:ttk()
                -- Reachability is read BEFORE the gate updates: "was the bar still hidden when the
                -- fight reached this sample?" The gate itself sees every tick, in-scope or not.
                local hiddenHere = not gate:latched()
                gate:update(pred, conf)
                local actual = death - s.t
                if pred and s.t >= WARMUP and actual > TAIL then
                    local b = math.floor(s.h * K) + 1
                    if b > K then
                        b = K
                    end
                    if b < 1 then
                        b = 1
                    end
                    kRel[b][#kRel[b] + 1] = math.abs(pred - actual) / actual
                    kAbs[b][#kAbs[b] + 1] = math.abs(pred - actual)
                    kN[b] = kN[b] + 1
                    if hiddenHere then
                        kPre[b] = kPre[b] + 1
                    end
                end
            end
            -- Collapse: one entry per bin per kill, so every kill weighs the same regardless of length.
            for b = 1, K do
                if kN[b] > 0 then
                    rel[b][#rel[b] + 1] = med(kRel[b])
                    abs[b][#abs[b] + 1] = med(kAbs[b])
                    preShow[b][#preShow[b] + 1] = kPre[b] / kN[b]
                    samplesN[b] = samplesN[b] + kN[b]
                end
            end
        end
    end
end

io.stderr:write(
    ("perbin: encounter %d — %d fixtures%s (per-kill weighted)\n"):format(
        enc,
        used,
        evenOnly and " (train half)" or ""
    )
)
-- TSV: bin · KILLS · medianRel · medianAbs · preShow · samples
-- Column 2 is now the number of KILLS contributing to the bin, not the sample count — that is the
-- honest evidence count for a per-bin decision, and it is what learn-regime.py's guard must test.
-- The raw sample total moves to column 6 for reporting only (WO-077).
for b = K, 1, -1 do
    local mr, ma = med(rel[b]), med(abs[b])
    if mr then
        local reach = med(preShow[b]) or 0
        print(("%d\t%d\t%.4f\t%.2f\t%.4f\t%d"):format(b, #rel[b], mr, ma, reach, samplesN[b]))
    end
end
