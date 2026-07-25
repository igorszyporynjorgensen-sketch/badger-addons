local mock = require("tools.wow-mock.init")

-- The sim composes the engine + scenario, so load all four onto one ns.
describe("Sim", function()
    local ns

    before_each(function()
        ns = {}
        mock.load("projects/badger-ttk/src/engine/estimator.lua", ns)
        mock.load("projects/badger-ttk/src/engine/render-model.lua", ns)
        mock.load("projects/badger-ttk/src/sim/scenario.lua", ns)
        mock.load("projects/badger-ttk/src/sim/sim.lua", ns)
    end)

    it("produces a render model with one entry per pop", function()
        local s = ns.SimScenario.warriorBurst
        local model = ns.Sim.run(s, 16)
        assert.is_not_nil(model)
        assert.equals(#s.pops, #model.entries)
    end)

    it("marks a popped cooldown active with its remaining duration", function()
        local s = ns.SimScenario.warriorBurst
        -- Death Wish popped at t=5, D=30 → at t=10 it is active with 25s left
        local model = ns.Sim.run(s, 10)
        local dw
        for i = 1, #model.entries do
            if model.entries[i].id == "deathwish" then
                dw = model.entries[i]
            end
        end
        assert.is_not_nil(dw.active)
        assert.equals(25, dw.active.remaining)
    end)

    it("TTK decreases as the fight progresses", function()
        local s = ns.SimScenario.warriorBurst
        local _, ttk1 = ns.Sim.run(s, 8)
        local _, ttk2 = ns.Sim.run(s, 14)
        assert.is_true(ttk1 > ttk2)
    end)

    it("does not blow up across the immune window", function()
        local s = ns.SimScenario.warriorBurst
        local _, before = ns.Sim.run(s, 17) -- just before the immune phase
        local _, after = ns.Sim.run(s, 24) -- just after it (damage resumed)
        assert.is_not_nil(before)
        assert.is_not_nil(after)
        assert.is_true(after < before + 30) -- the 5s frozen phase never inflates the estimate wildly
    end)

    it("static preview covers planned + fits/over/short", function()
        local m = ns.Sim.staticPreview()
        local byId = {}
        for i = 1, #m.entries do
            byId[m.entries[i].id] = m.entries[i]
        end
        assert.is_not_nil(byId.planned.planned.popLines)
        assert.equals("fits", byId.fits.active.coverage)
        assert.equals("over", byId.over.active.coverage)
        assert.equals("short", byId.short.active.coverage)
    end)
end)
