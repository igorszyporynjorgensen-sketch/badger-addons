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
                assert.equals(0, conf) -- zero-information ticks are not evidence
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
end)
