local mock = require("tools.wow-mock.init")

describe("SimScenario", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/sim/scenario.lua")
    end)

    it("provides a warrior-burst scenario with samples and pops", function()
        local s = ns.SimScenario.warriorBurst
        assert.is_true(#s.samples > 0)
        assert.is_true(#s.pops >= 2)
        assert.equals(1.0, s.samples[1].h)
    end)

    it("freezes health inside an immune window", function()
        local s = ns.SimScenario.warriorBurst
        local function hAt(t)
            for i = 1, #s.samples do
                if s.samples[i].t == t then
                    return s.samples[i].h
                end
            end
        end
        assert.equals(hAt(18), hAt(22)) -- immune window 18..22 → health frozen
    end)

    it("reports immune windows", function()
        assert.is_true(ns.SimScenario.inImmune({ { from = 18, to = 23 } }, 20))
        assert.is_false(ns.SimScenario.inImmune({ { from = 18, to = 23 } }, 25))
        assert.is_false(ns.SimScenario.inImmune(nil, 5))
    end)
end)
