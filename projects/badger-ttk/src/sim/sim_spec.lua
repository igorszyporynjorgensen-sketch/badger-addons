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

    it("static preview covers planned + fits/over/short, with names", function()
        local m = ns.Sim.staticPreview()
        local byId = {}
        for i = 1, #m.entries do
            byId[m.entries[i].id] = m.entries[i]
        end
        assert.is_not_nil(byId.planned.planned.popLines)
        assert.equals("fits", byId.fits.active.coverage)
        assert.equals("over", byId.over.active.coverage)
        assert.equals("short", byId.short.active.coverage)
        assert.equals("Death Wish", byId.fits.name)
    end)
end)
