local mock = require("tools.wow-mock.init")

-- The deterministic sim composes only the render model + scenario (no estimator).
describe("Sim", function()
    local ns

    before_each(function()
        ns = {}
        mock.load("projects/badger-ttk/src/engine/render-model.lua", ns)
        mock.load("projects/badger-ttk/src/sim/scenario.lua", ns)
        mock.load("projects/badger-ttk/src/sim/sim.lua", ns)
    end)

    it("counts TTK down linearly from the scenario total", function()
        local s = ns.SimScenario.warriorBurst
        local _, ttk0 = ns.Sim.run(s, 0)
        local _, ttk10 = ns.Sim.run(s, 10)
        assert.equals(50, ttk0)
        assert.equals(40, ttk10)
    end)

    it("carries the fixed total onto the model (the steady scale)", function()
        assert.equals(50, ns.Sim.run(ns.SimScenario.warriorBurst, 12).total)
    end)

    it("produces one named entry per pop", function()
        local s = ns.SimScenario.warriorBurst
        local m = ns.Sim.run(s, 25)
        assert.equals(#s.pops, #m.entries)
        assert.equals("Death Wish", m.entries[1].name)
        assert.equals("Earthstrike", m.entries[2].name)
    end)

    it("shows Death Wish planned before its fire moment, active after", function()
        local s = ns.SimScenario.warriorBurst
        -- Death Wish fires at 30s-left → t = total - 30 = 20
        local before = ns.Sim.run(s, 15)
        assert.is_nil(before.entries[1].active)
        assert.is_not_nil(before.entries[1].planned)
        local after = ns.Sim.run(s, 20)
        assert.is_not_nil(after.entries[1].active)
        assert.equals(30, after.entries[1].active.remaining) -- just fired → full 30s
    end)

    it("drains a fired buff's remaining as the fight continues", function()
        -- 15s after Death Wish fired at t=20
        local m = ns.Sim.run(ns.SimScenario.warriorBurst, 35)
        assert.equals(15, m.entries[1].active.remaining)
    end)

    it("shows Earthstrike waiting → ready → used (fired 4s late)", function()
        local s = ns.SimScenario.warriorBurst
        -- Earthstrike: optimal 20s-left (t=30), used at 16s-left (t=34)
        assert.is_false(ns.Sim.run(s, 25).entries[2].planned.ready) -- TTK 25 → waiting
        local ready = ns.Sim.run(s, 32) -- TTK 18 → past optimal, not yet used → ready (green)
        assert.is_nil(ready.entries[2].active)
        assert.is_true(ready.entries[2].planned.ready)
        assert.is_not_nil(ns.Sim.run(s, 36).entries[2].active) -- TTK 14 → used
    end)

    it(
        "static preview is the one scenario frozen at 0:25 — the same bars the dynamic sim animates",
        function()
            local m, ttk = ns.Sim.staticPreview()
            assert.equals(25, ttk) -- reads 0:25
            assert.equals(25, m.ttk)
            -- Same single warrior scenario, not a separate stack: one entry per pop, in scenario order.
            assert.equals(#ns.SimScenario.warriorBurst.pops, #m.entries)
            assert.equals("Death Wish", m.entries[1].name)
            assert.is_not_nil(m.entries[1].active) -- Death Wish already fired at t=20
            assert.equals("Earthstrike", m.entries[2].name)
            assert.is_not_nil(m.entries[2].planned) -- Earthstrike not yet fired at t=25
        end
    )

    it("the frozen static preview matches Sim.run at the same moment (single source)", function()
        local s = ns.SimScenario.warriorBurst
        local frozen = ns.Sim.staticPreview()
        local viaRun = ns.Sim.run(s, s.total - 25)
        assert.equals(frozen.ttk, viaRun.ttk)
        assert.equals(#frozen.entries, #viaRun.entries)
    end)
end)
