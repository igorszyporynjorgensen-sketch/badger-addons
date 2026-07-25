local mock = require("tools.wow-mock.init")

describe("SimScenario", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/sim/scenario.lua")
    end)

    it("is a deterministic 50s warrior fight with two named pops", function()
        local s = ns.SimScenario.warriorBurst
        assert.equals(50, s.total)
        assert.equals(2, #s.pops)
    end)

    it("fires Death Wish at 30s-left and Earthstrike at 20s-left", function()
        local s = ns.SimScenario.warriorBurst
        local byId = {}
        for i = 1, #s.pops do
            byId[s.pops[i].id] = s.pops[i]
        end
        assert.equals("Death Wish", byId.deathwish.name)
        assert.equals(30, byId.deathwish.fireTTK)
        assert.equals(30, byId.deathwish.duration)
        assert.equals("Earthstrike", byId.earthstrike.name)
        assert.equals(20, byId.earthstrike.fireTTK)
        assert.equals(20, byId.earthstrike.duration)
    end)
end)
