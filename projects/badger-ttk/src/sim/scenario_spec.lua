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

    it("fires Death Wish on time (30s-left) and Earthstrike 4s late (used at 16s-left)", function()
        local s = ns.SimScenario.warriorBurst
        local byId = {}
        for i = 1, #s.pops do
            byId[s.pops[i].id] = s.pops[i]
        end
        assert.equals("Death Wish", byId[12328].name)
        assert.equals(30, byId[12328].fireTTK) -- optimal (duration 30) == used → on time
        assert.equals(30, byId[12328].duration)
        assert.equals("Earthstrike", byId[21180].name)
        assert.equals(16, byId[21180].fireTTK) -- used at 16s-left...
        assert.equals(20, byId[21180].duration) -- ...but optimal is 20s-left → fired 4s late
    end)
end)
