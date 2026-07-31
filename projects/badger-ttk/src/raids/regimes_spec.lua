local mock = require("tools.wow-mock.init")

-- Guards the STRUCTURE of the regime playbook (a regeneration/hand-edit mistake fails the gate), not the
-- learned values. Mirrors rhythms_spec.lua.
describe("Regimes (WO-075 structural playbook)", function()
    local ns
    before_each(function()
        ns = mock.load("projects/badger-ttk/src/raids/regimes.lua")
    end)

    it("exposes ns.Regimes with a `default` fallback carrying a confCap", function()
        assert.is_table(ns.Regimes)
        assert.is_table(ns.Regimes.default)
        assert.is_table(ns.Regimes.default.confCap)
    end)

    it("dual-keys every profile at the classic id AND +150000 (same table by identity)", function()
        for _, id in ipairs({ 1084, 671 }) do
            assert.is_table(ns.Regimes[id], "missing classic id " .. id)
            assert.equals(ns.Regimes[id], ns.Regimes[id + 150000])
        end
    end)

    it(
        "Onyxia (1084) quiets the air-phase bins with a confCap (a slowdown, not a stall — no freeze)",
        function()
            local o = ns.Regimes[1084]
            assert.is_table(o.confCap)
            -- the air-phase bins (h ~0.35-0.60) are capped below the show threshold so the bar goes quiet there
            assert.is_true(o.confCap[10] ~= nil and o.confCap[10] < 0.5)
            assert.is_nil(o.freeze) -- WO-075 finding: Onyxia's air phase is a slowdown; a freeze over-holds
        end
    )

    it("Majordomo (671) hides the bar", function()
        assert.is_true(ns.Regimes[671].hideBar)
    end)

    it(
        "STRUCTURE: freeze bands {lo<hi} in [0,1]; stallSec>0; confCap in [0,1]; resetOnRise in (0,1]",
        function()
            for key, prof in pairs(ns.Regimes) do
                if type(prof) == "table" then
                    local at = " @ " .. tostring(key)
                    if prof.freeze then
                        for _, b in ipairs(prof.freeze) do
                            assert.is_true(b.lo >= 0 and b.lo <= 1, "freeze.lo range" .. at)
                            assert.is_true(b.hi >= 0 and b.hi <= 1, "freeze.hi range" .. at)
                            assert.is_true(b.lo < b.hi, "freeze lo<hi" .. at)
                            assert.is_true(b.stallSec == nil or b.stallSec > 0, "stallSec>0" .. at)
                        end
                    end
                    if prof.confCap then
                        if type(prof.confCap) == "number" then
                            assert.is_true(
                                prof.confCap >= 0 and prof.confCap <= 1,
                                "confCap scalar range" .. at
                            )
                        else
                            for _, v in pairs(prof.confCap) do
                                assert.is_true(v >= 0 and v <= 1, "confCap range" .. at)
                            end
                        end
                    end
                    if prof.resetOnRise ~= nil then
                        assert.is_true(
                            prof.resetOnRise > 0 and prof.resetOnRise <= 1,
                            "resetOnRise range" .. at
                        )
                    end
                end
            end
        end
    )
end)
