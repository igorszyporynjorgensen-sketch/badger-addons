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
end)
