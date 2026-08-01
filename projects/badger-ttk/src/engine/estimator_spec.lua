local mock = require("tools.wow-mock.init")

-- The estimator is pure Lua (no WoW API), so we just load the file and drive it with samples.
describe("Estimator", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
    end)

    it("is unknown before it has a rate", function()
        local e = ns.Estimator.new({})
        local ttk, conf = e:ttk()
        assert.is_nil(ttk)
        assert.equals(0, conf)
        e:sample(0, 1.0)
        assert.is_nil((e:ttk())) -- one sample: still no dt, no rate
    end)

    it("estimates TTK from a steady health-loss rate", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 1.00)
        e:sample(1, 0.90)
        e:sample(2, 0.80)
        e:sample(3, 0.70)
        -- rate ~ 0.10/s, h = 0.70 → ttk ~ 7s
        local ttk = e:ttk()
        assert.is_true(ttk > 5 and ttk < 9)
    end)

    it("clamps heals so TTK never goes negative", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 0.50)
        e:sample(1, 0.40) -- losing health
        e:sample(2, 0.60) -- healed up: the rate is clamped to 0, not negative
        local ttk = e:ttk()
        if ttk ~= nil then
            assert.is_true(ttk > 0)
        end
    end)

    it("shortens TTK in execute range", function()
        local base = ns.Estimator.new({ reactivity = 1, executeThreshold = 0, executeModifier = 1 })
        base:sample(0, 0.30)
        base:sample(1, 0.20)

        local exec =
            ns.Estimator.new({ reactivity = 1, executeThreshold = 0.25, executeModifier = 2 })
        exec:sample(0, 0.30)
        exec:sample(1, 0.20)

        assert.is_true(exec:ttk() < base:ttk()) -- below 25% HP the estimate is halved
    end)

    it("resets on target change", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 1.0)
        e:sample(1, 0.9)
        assert.is_not_nil(e:ttk())
        e:reset()
        assert.is_nil((e:ttk()))
    end)

    it("pauses through an immune phase without corrupting the estimate", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 1.00)
        e:sample(1, 0.90)
        e:sample(2, 0.80) -- steady 0.10/s
        assert.is_not_nil(e:ttk())
        -- immune / hardened for 6s (health frozen at 0.80); the driver marks samples non-damageable
        e:sample(3, 0.80, false)
        e:sample(8, 0.80, false)
        -- damage resumes: the first sample re-establishes the reference, then measures the real rate
        e:sample(9, 0.80)
        e:sample(10, 0.70) -- 0.10/s again
        -- ~ 0.70 / 0.10 = 7s — NOT blown up by the 6s zero-damage gap
        assert.is_true(e:ttk() > 5 and e:ttk() < 9)
    end)

    it("uses the history prior immediately, before any live rate", function()
        local e = ns.Estimator.new({ priorRate = 0.05 })
        e:sample(0, 0.50) -- one sample: no live rate yet, so lean on the prior
        local ttk = e:ttk()
        assert.is_not_nil(ttk)
        assert.is_true(ttk > 8 and ttk < 12) -- 0.50 / 0.05 = 10
    end)

    it("floors the effective rate at a fraction of the prior (caps TTK spikes)", function()
        local e = ns.Estimator.new({ reactivity = 1, priorRate = 0.10 })
        e:sample(0, 1.00)
        e:sample(1, 0.90)
        e:sample(2, 0.80)
        for i = 3, 12 do
            e:sample(i, 0.80) -- flat: the live rate decays toward 0
        end
        -- Without the floor TTK would balloon; floor = 0.5·0.10 = 0.05 → ttk ≤ 0.80 / 0.05 = 16
        local ttk = e:ttk()
        assert.is_true(ttk ~= nil and ttk <= 16)
    end)

    it("ramps confidence with more samples", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 1.0)
        e:sample(1, 0.9)
        local _, early = e:ttk()
        for i = 2, 10 do
            e:sample(i, 1.0 - i * 0.05)
        end
        local _, late = e:ttk()
        assert.is_true(late > early)
        assert.is_true(late <= 1)
    end)

    -- ── WO-056: the chunk-clock rewrite's own guarantees ────────────────────────────────────────

    -- Drive a discrete-hit fight at the live driver's 0.15s cadence: `hits` = { {t, chunk}, ... }.
    -- Returns the per-tick (t, ttk) readout so cases can assert on the exact sequence the user sees.
    local function chunkyReadout(e, hits, until_t)
        local reads, h, hi = {}, 1, 1
        local t = 0
        while t <= until_t + 1e-9 do
            while hi <= #hits and hits[hi][1] <= t + 1e-9 do
                h = h - hits[hi][2]
                hi = hi + 1
            end
            e:sample(t, h, true)
            reads[#reads + 1] = { t = t, ttk = (e:ttk()) }
            t = t + 0.15
        end
        return reads
    end

    it("WO-056: the between-hit readout reads as a countdown — no sawtooth balloons", function()
        -- 30% chunks every 2.5s with a matching prior: the old estimator's readout ballooned ~2.5x
        -- (+5s) across every swing gap and cliff-dived 8+s at every hit (the reported sawtooth). The
        -- rewrite counts down between hits; only the gentle past-grace stall may nudge it up. Guard:
        -- the readout never RISES by more than 0.5s within any sliding 1-second window.
        local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.12 })
        local reads = chunkyReadout(e, { { 0.3, 0.30 }, { 2.8, 0.30 }, { 5.3, 0.30 } }, 7.0)
        for i = 1, #reads do
            for j = i + 1, #reads do
                if reads[j].t - reads[i].t > 1.0 then
                    break
                end
                if reads[i].ttk and reads[j].ttk then
                    assert.is_true(
                        reads[j].ttk - reads[i].ttk <= 0.5,
                        "rose >0.5s within 1s at t=" .. reads[j].t
                    )
                end
            end
        end
    end)

    it("WO-056: a steady chunk train re-syncs at hits with barely any jump", function()
        -- On a perfectly steady train the countdown already sits where the re-sync lands.
        local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.12 })
        local hits = { { 0.3, 0.30 }, { 2.8, 0.30 }, { 5.3, 0.30 } }
        local reads = chunkyReadout(e, hits, 7.0)
        for i = 2, #reads do
            local prev, cur = reads[i - 1].ttk, reads[i].ttk
            if prev and cur and reads[i].t > 3.0 then -- past warm-up
                assert.is_true(math.abs(cur - prev) < 1.0, "jump at t=" .. reads[i].t)
            end
        end
    end)

    it("WO-056: continuous steady decay is EXACT (no first-hit floor on sub-2% drops)", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        local h
        for i = 0, 40 do
            h = 1.0 - i * 0.0015 -- 1%/s at 0.15s ticks: each drop is 0.15%, well under 2%
            e:sample(i * 0.15, h, true)
        end
        local ttk = e:ttk()
        assert.is_true(math.abs(ttk - h / 0.01) < 1e-6)
    end)

    it(
        "WO-056: an idle target with a prior holds EXACTLY h/prior (no drift to the floor)",
        function()
            -- The old estimator's readout walked from h/prior to the 2x floor on an untouched target.
            local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.05 })
            for i = 0, 20 do
                e:sample(i * 0.15, 0.50, true)
                local ttk, conf = e:ttk()
                assert.is_true(math.abs(ttk - 10) < 1e-9) -- 0.50 / 0.05, every single tick
                -- A full-strength history prior IS confidence (WO-061): conf = its evidence share,
                -- so a history-backed pull qualifies instantly instead of sitting gated for ~3s.
                assert.equals(1, conf)
            end
        end
    )

    it("WO-056: a first hit with no prior never reads absurdly short", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        e:sample(0, 1.0, true)
        e:sample(0.3, 0.60, true) -- a 40% opener 0.3s in read as 0.4/0.15 = 2.7/s by the old code
        local ttk = e:ttk()
        assert.is_true(ttk >= 1.5) -- the first-event span floor keeps it sane
    end)

    it("WO-056: a genuine burst flushes on the SECOND out-of-band event, not the first", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        -- Establish 5% every 2.5s (rate 0.02)...
        local hits = { { 2.5, 0.05 }, { 5, 0.05 }, { 7.5, 0.05 }, { 10, 0.05 } }
        local reads = chunkyReadout(e, hits, 10.1)
        assert.is_truthy(reads[#reads].ttk)
        -- ...then the party arrives: 15% every 1.25s (x6 the rate; obs/belief = 6 > 2.5).
        e:sample(11.25, 0.65, true)
        local afterFirst = e:ttk() -- armed, NOT flushed: still near the old pace
        e:sample(12.5, 0.50, true)
        local afterSecond = e:ttk() -- flushed: the run's own rate (0.30/2.5s = 0.12)
        assert.is_true(afterFirst > 8, "flushed too early: " .. tostring(afterFirst))
        assert.is_true(
            afterSecond > 3 and afterSecond < 5.5, -- 0.50 / 0.12 = 4.2
            "did not adopt the burst: " .. tostring(afterSecond)
        )
    end)

    it("WO-056: a lone crit never flushes the evidence", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        local hits = { { 2.5, 0.05 }, { 5, 0.05 }, { 7.5, 0.05 }, { 10, 0.05 } }
        chunkyReadout(e, hits, 10.1)
        local before = e:ttk()
        e:sample(12.5, 0.68, true) -- one 12% crit (2.4x — inside the band)
        e:sample(15.0, 0.63, true) -- back to normal 5%
        local after = e:ttk()
        -- The crit folds in as one observation; the estimate moves, but nowhere near a 2.4x snap.
        assert.is_true(after > before * 0.5, "crit collapsed the estimate: " .. tostring(after))
    end)

    it("WO-056: when hits stop, the readout stalls gently, then goes honestly unknown", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        local hits = { { 1, 0.10 }, { 3.5, 0.10 }, { 6, 0.10 } }
        local reads = chunkyReadout(e, hits, 40.0) -- hits stop at t=6; 34s of silence follow
        for i = 2, #reads do
            local prev, cur = reads[i - 1].ttk, reads[i].ttk
            if prev and cur and reads[i].t > 6.2 and reads[i].t <= 11 then
                -- Early silence: a gentle ~linear stall (the old code compounded exponentially,
                -- ~x1.06 per tick). Later the fade steepens on purpose — and then...
                assert.is_true(cur - prev < 1.5, "ballooned at t=" .. reads[i].t)
            end
        end
        -- ...the rate crosses the not-dying floor and the estimate goes honestly unknown.
        assert.is_nil(reads[#reads].ttk)
    end)

    it("WO-056: an immune hold keeps ttk() BIT-IDENTICAL until damage resumes", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        e:sample(0, 1.0, true)
        e:sample(2, 0.8, true)
        e:sample(4, 0.6, true)
        local held = e:ttk()
        for i = 1, 200 do
            e:sample(4 + i * 0.15, 0.6, false) -- 30s immune phase
        end
        assert.equals(held, (e:ttk()))
    end)

    it("WO-056: higher reactivity adopts a sub-flush-band change faster", function()
        local function ride(reactivity)
            -- 5% every 2.5s, then a sustained x2 (10% every 2.5s — below the 2.5x flush band).
            local hits = {}
            for i = 1, 4 do
                hits[#hits + 1] = { i * 2.5, 0.05 }
            end
            for i = 5, 8 do
                hits[#hits + 1] = { i * 2.5, 0.10 }
            end
            local e2 = ns.Estimator.new({ reactivity = reactivity })
            chunkyReadout(e2, hits, 20.1)
            local ttk = e2:ttk()
            local h = 1 - 4 * 0.05 - 4 * 0.10 -- 0.40
            return math.abs(ttk - h / 0.04) -- distance from the NEW truth (0.10/2.5s)
        end
        assert.is_true(ride(1) < ride(0)) -- snappy tracks the change closer than smooth
    end)

    -- ── WO-061: verify-panel follow-ups ─────────────────────────────────────────────────────────

    it(
        "WO-061: a fight genuinely SLOWER than history converges to live truth (floor released)",
        function()
            -- Recorded with a group (0.10/s), now soloed at 0.01/s: the slowdown flush fires and the
            -- prior floor must stop binding — the old clamp held the readout at ~2x history forever.
            local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.10 })
            local h
            for i = 1, 40 do
                local t = i * 1.0
                h = 1.0 - i * 0.01 -- 1% per second, sampled once a second for simplicity
                e:sample(t, h, true)
            end
            local ttk = e:ttk()
            -- Truth: 0.60 / 0.01 = 60s. The un-released floor capped this at 0.60 / 0.05 = 12s.
            assert.is_true(ttk > 20, "still floor-capped: " .. tostring(ttk))
            assert.is_true(ttk > 45 and ttk < 70, "did not converge: " .. tostring(ttk))
        end
    )

    it("WO-061: an overdue countdown floors at 0.05s — never blanks a live target", function()
        local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.10 })
        e:sample(0, 0.10, true)
        e:sample(1, 0.06, true) -- one hard hit: ttk small
        for i = 1, 40 do
            e:sample(1 + i * 0.15, 0.06, true) -- silence: the countdown runs past the estimate
        end
        local ttk = e:ttk()
        assert.is_not_nil(ttk)
        assert.is_true(ttk >= 0.05) -- 0 would read as "no data" and blank the display
    end)
end)

-- Mutation-tested gap cases contributed by the WO-056 adversarial verify panel (WO-061): each one
-- kills a mutant that passed the entire suite above.
describe("Estimator (verify-panel gap cases)", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
    end)

    it("registers a post-heal hit as one clean chunk off the healed level", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        e:sample(0, 1.00, true)
        e:sample(2, 0.90, true)
        e:sample(4, 0.80, true)
        e:sample(5, 0.90, true) -- heal +10% inside the gap
        local events = e.events
        e:sample(6, 0.80, true) -- 10% off the HEALED level
        assert.equals(events + 1, e.events)
        local ttk = e:ttk()
        assert.is_true(math.abs(ttk - 16) < 2.5)
    end)

    it("caps a late hit's span at SPAN_CAP after a long quiet stretch", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 1.00, true)
        e:sample(2, 0.90, true)
        for i = 1, 199 do
            e:sample(2 + i * 0.15, 0.90, true)
        end
        e:sample(32, 0.80, true)
        local ttk = e:ttk()
        assert.is_true(ttk ~= nil and ttk <= 130)
    end)

    it("flushes DOWN on the second out-of-band slow event (jumpLo path)", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        e:sample(0, 1.00, true)
        e:sample(1.25, 0.85, true)
        e:sample(2.5, 0.70, true)
        e:sample(3.75, 0.55, true)
        e:sample(5.0, 0.40, true)
        e:sample(7.5, 0.38, true)
        e:sample(10.0, 0.36, true)
        local ttk = e:ttk()
        assert.is_true(ttk ~= nil and ttk > 30 and ttk < 60)
    end)

    it(
        "a direction flip re-arms: spike then two slow events still flushes on the slow pair",
        function()
            local e = ns.Estimator.new({ reactivity = 0.5 })
            e:sample(0, 1.00, true)
            e:sample(1.25, 0.85, true)
            e:sample(2.5, 0.70, true)
            e:sample(3.75, 0.55, true)
            e:sample(4.0, 0.40, true)
            e:sample(6.5, 0.38, true)
            e:sample(9.0, 0.36, true)
            local ttk = e:ttk()
            assert.is_true(ttk ~= nil and ttk > 25)
        end
    )

    it("an in-band event disarms the flush run (non-consecutive crits never accumulate)", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        local h = 1.0
        local function hit(t, d)
            h = h - d
            e:sample(t, h, true)
        end
        hit(2.5, 0.02)
        hit(5, 0.02)
        hit(7.5, 0.02)
        hit(10, 0.02)
        hit(12.5, 0.20)
        hit(15, 0.02)
        hit(17.5, 0.20)
        local ttk = e:ttk()
        assert.is_true(ttk > 10 and ttk < 15)
    end)

    it("reset() restores the prior's FULL pseudo-weight, not the decayed remnant", function()
        local e = ns.Estimator.new({ reactivity = 1, priorRate = 0.05, priorWeight = 6 })
        e:sample(0, 1.00, true)
        e:sample(4, 0.60, true)
        e:reset()
        e:sample(10, 1.00, true)
        assert.is_true(math.abs((e:ttk()) - 20) < 1e-9)
        e:sample(12, 0.80, true)
        local pT = 6 * math.exp(-1)
        local expected = 0.80 / ((0.20 + 0.05 * pT) / (2 + pT))
        assert.is_true(math.abs((e:ttk()) - expected) < 1e-9)
    end)

    it("priorWeight scales how strongly the prior resists the first live event", function()
        local function firstEventTTK(w)
            local e = ns.Estimator.new({ reactivity = 0.5, priorRate = 0.02, priorWeight = w })
            e:sample(0, 1.00, true)
            e:sample(2, 0.80, true)
            return (e:ttk())
        end
        local light, heavy = firstEventTTK(1), firstEventTTK(20)
        local anchor = 0.80 / 0.02
        assert.is_true(math.abs(heavy - anchor) < math.abs(light - anchor))
        assert.is_true(heavy - light > 5)
    end)

    it("confidence is the MIN of the time ramp and the event ramp", function()
        local e = ns.Estimator.new({ reactivity = 0.5 })
        e:sample(0, 1.00, true)
        e:sample(0.5, 0.95, true)
        e:sample(1.0, 0.90, true)
        e:sample(1.5, 0.85, true)
        local _, conf = e:ttk()
        assert.is_true(math.abs(conf - 1 / 6) < 1e-9)
    end)

    it("after a heal the estimate stays KNOWN and positive (non-vacuous heal clamp)", function()
        local e = ns.Estimator.new({ reactivity = 1 })
        e:sample(0, 0.50, true)
        e:sample(1, 0.40, true)
        e:sample(2, 0.60, true)
        local ttk = e:ttk()
        assert.is_not_nil(ttk)
        assert.is_true(ttk > 0)
    end)

    it("execute correction divides by exactly executeModifier below the threshold", function()
        local function build(thr, mod)
            local e = ns.Estimator.new({
                reactivity = 1,
                executeThreshold = thr,
                executeModifier = mod,
            })
            e:sample(0, 0.30, true)
            e:sample(2, 0.20, true)
            return (e:ttk())
        end
        assert.is_true(math.abs(build(0, 1) / build(0.25, 2) - 2) < 1e-9)
    end)
end)

describe("Estimator rhythm profile (WO-069)", function()
    local ns

    before_each(function()
        ns = require("tools.wow-mock.init").load("projects/badger-ttk/src/engine/estimator.lua")
    end)

    local function flat(v, n)
        local t = {}
        for i = 1, n or 20 do
            t[i] = v
        end
        return t
    end
    local function feed(e)
        -- steady 10%/s continuous decay
        e:sample(0, 1.00)
        e:sample(1, 0.90)
        e:sample(2, 0.80)
        e:sample(3, 0.70)
        return e:ttk()
    end

    it("m == 1 everywhere reproduces the naive estimate exactly", function()
        local plain = ns.Estimator.new({ reactivity = 1 })
        local flat1 = ns.Estimator.new({ reactivity = 1, rhythm = { bins = flat(1.0) } })
        assert.near(feed(plain), feed(flat1), 1e-9)
    end)

    it("a back-loaded profile anticipates: reads SHORTER than naive at high health", function()
        -- slow top half (0.5x), fast bottom half (2x): the fight will accelerate — anticipate it.
        local bins = {}
        for i = 1, 10 do
            bins[i] = 2.0 -- h < 50%: execute end
        end
        for i = 11, 20 do
            bins[i] = 0.5 -- h >= 50%: slow opening
        end
        local naive = feed(ns.Estimator.new({ reactivity = 1 }))
        local shaped = feed(ns.Estimator.new({ reactivity = 1, rhythm = { bins = bins } }))
        assert.is_true(shaped < naive, ("shaped %s should be < naive %s"):format(shaped, naive))
    end)

    it("the profile supersedes the execute correction (no double-count)", function()
        local mk = function(mod)
            local e = ns.Estimator.new({
                reactivity = 1,
                executeThreshold = 0.5,
                executeModifier = mod,
                rhythm = { bins = flat(1.0) },
            })
            e:sample(0, 0.40) -- below the execute threshold from the start
            e:sample(1, 0.35)
            e:sample(2, 0.30)
            e:sample(3, 0.25)
            return e:ttk()
        end
        -- with a rhythm present the modifier must not change the estimate
        assert.near(mk(1.0), mk(4.0), 1e-9)
    end)
end)

-- Regime seams (WO-075). Every seam is a no-op when regime == nil (proven byte-identical by the sim gate);
-- these assert the behavior when a regime IS present.
describe("Estimator — regime seams (WO-075)", function()
    local ns
    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/estimator.lua")
    end)

    -- a steady 1.0→~0.2 drop, one event/second, enough to reach full confidence
    local function steady(regime)
        local e = ns.Estimator.new({ regime = regime })
        for i = 0, 16 do
            e:sample(i * 1.0, 1.0 - i * 0.05)
        end
        return e
    end

    it("an EMPTY regime reproduces the baseline exactly (nil-guard invariant)", function()
        local base, withEmpty = steady(nil), steady({})
        local t1, c1 = base:ttk()
        local t2, c2 = withEmpty:ttk()
        assert.equals(t1, t2)
        assert.equals(c1, c2)
    end)

    it("hideBar → (nil, 0) even with strong evidence", function()
        local e = steady({ hideBar = true })
        local ttk, conf = e:ttk()
        assert.is_nil(ttk)
        assert.equals(0, conf)
    end)

    it("confCap clamps confidence DOWN, never up", function()
        local _, cBase = steady(nil):ttk()
        local _, cCap = steady({ confCap = 0.2 }):ttk()
        assert.is_true(cBase > 0.2, "baseline should be confident here (" .. cBase .. ")")
        assert.is_true(cCap <= 0.2 + 1e-9)
        assert.is_true(cCap <= cBase)
    end)

    it("a per-bin confCap uses the health bin (K=20); absent bin ⇒ no cap", function()
        -- cap only bin 20 (h∈(0.95,1]) to 0; at h≈0.5 (bin 11, uncapped) confidence is untouched
        local capped = ns.Estimator.new({ regime = { confCap = { [20] = 0.0 } } })
        for i = 0, 16 do
            capped:sample(i * 1.0, 1.0 - i * 0.05)
        end -- ends at h≈0.2 (bin 5, no cap)
        local _, c = capped:ttk()
        local _, cBase = steady(nil):ttk()
        assert.equals(cBase, c) -- uncapped bin: identical
    end)

    -- (The `freeze` tier and its three tests were removed in PR3 — D-020. A profile can no longer declare
    -- health bands that hold the countdown; an immune/hardened phase is stated as FACT by the driver via
    -- sample(t, h, damageable = false), which is covered by "pauses through an immune phase" above.)

    it(
        "resetOnRise clears + re-anchors on a phase reset (old pool doesn't bleed into the new)",
        function()
            local e = ns.Estimator.new({ regime = { resetOnRise = 0.5 } })
            for i = 0, 9 do
                e:sample(i * 1.0, 1.0 - i * 0.09)
            end -- drop toward death
            e:sample(10.0, 0.95) -- phase reset: refill (rise ≥ 0.5)
            assert.equals(0, e.events) -- evidence cleared
            e:sample(11.0, 0.90)
            local _, conf = e:ttk()
            assert.is_true(conf < 0.5) -- fresh fight: not carrying the old pool's confidence
        end
    )

    it("suppressFlush blocks the two-cliff regime flush, but evidence still folds", function()
        -- Scripted chunk damage (Buru's cliffs) fires the regime-change flush on a MECHANIC rather than a
        -- genuine kill-speed change, discarding a sound prior. Drive two big out-of-band cliffs: unflagged
        -- the estimator flushes (priorT collapses to JUMP_KEEP); flagged it must not — yet events/evidence
        -- still accumulate exactly as normal.
        local function run(regime)
            local e = ns.Estimator.new({ priorRate = 0.02, regime = regime })
            for i = 0, 5 do
                e:sample(i * 1.0, 1.0 - i * 0.02) -- steady, slow: establishes a belief
            end
            e:sample(6.0, 0.60) -- cliff 1 (way out of band): arms
            e:sample(7.0, 0.20) -- cliff 2: would fire the flush
            return e
        end
        local plain, capped = run(nil), run({ suppressFlush = true })
        assert.is_true(capped.priorT > plain.priorT, "the flush should have been suppressed")
        assert.equals(plain.events, capped.events) -- evidence still folds: same event count
        assert.is_true(capped.sumD > 0 and capped.sumT > 0)
    end)

    it("an UN-flagged profile does NOT reset on an up-jump (Twin/Skeram negative test)", function()
        local e = ns.Estimator.new({ regime = { confCap = 0.9 } }) -- no resetOnRise
        for i = 0, 9 do
            e:sample(i * 1.0, 1.0 - i * 0.09)
        end
        local before = e.events
        e:sample(10.0, 0.95) -- up-jump (heal / second-pool artifact)
        assert.equals(before, e.events) -- NOT reset — evidence preserved
    end)
end)
