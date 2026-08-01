local mock = require("tools.wow-mock.init")

-- Guards the STRUCTURE of the regime playbook — regimes.lua is AUTO-GENERATED (tools/assemble-regimes.py
-- from the lab's learned candidates), so a regeneration mistake must fail the gate while the learned VALUES
-- stay free to move as the corpus grows. Mirrors rhythms_spec.lua.
describe("Regimes (WO-075 structural playbook)", function()
    local ns
    local BINS = 20
    local FRESH = 150000

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/raids/regimes.lua")
    end)

    it("exposes ns.Regimes with a `default` fallback carrying a confCap", function()
        assert.is_table(ns.Regimes)
        assert.is_table(ns.Regimes.default)
        assert.is_table(ns.Regimes.default.confCap)
    end)

    it("dual-keys every profile at the classic id AND +150000 (same table by identity)", function()
        local classic = 0
        for key, prof in pairs(ns.Regimes) do
            if type(key) == "number" and key < FRESH then
                classic = classic + 1
                assert.equals(prof, ns.Regimes[key + FRESH], "missing Fresh alias for " .. key)
            end
        end
        assert.is_true(classic > 0, "no classic-keyed profiles at all")
    end)

    it("keeps the hand-authored categorical facts (they are domain truths, not learned)", function()
        assert.is_true(ns.Regimes[671].hideBar) -- Majordomo: his fight is his adds
        assert.is_true(ns.Regimes[721].suppressFlush) -- Buru: scripted chunk damage must not flush
    end)

    it("never ships an EMPTY profile (a profile must actually say something)", function()
        for key, prof in pairs(ns.Regimes) do
            if type(prof) == "table" and key ~= "default" then
                local says = prof.hideBar
                    or prof.suppressFlush
                    or prof.freeze
                    or prof.confCap
                    or prof.resetOnRise
                    or prof.healPolluted
                    or prof.secondPool
                assert.is_true(says and true or false, "empty profile @ " .. tostring(key))
            end
        end
    end)

    it(
        "STRUCTURE: confCap bins in 1..K with values in [0,1]; freeze {lo<hi}; resetOnRise in (0,1]",
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
                                "confCap scalar" .. at
                            )
                        else
                            for bin, v in pairs(prof.confCap) do
                                assert.is_true(
                                    type(bin) == "number" and bin >= 1 and bin <= BINS,
                                    "confCap bin " .. tostring(bin) .. at
                                )
                                assert.is_true(v >= 0 and v <= 1, "confCap range" .. at)
                            end
                        end
                    end
                    if prof.resetOnRise ~= nil then
                        assert.is_true(
                            prof.resetOnRise > 0 and prof.resetOnRise <= 1,
                            "resetOnRise" .. at
                        )
                    end
                    -- Reserved CLEU slots are inert flags today, but must stay well-formed.
                    for _, slot in ipairs({ "healPolluted", "secondPool" }) do
                        if prof[slot] ~= nil then
                            assert.is_true(
                                prof[slot] == true,
                                slot .. " must be true-or-absent" .. at
                            )
                        end
                    end
                end
            end
        end
    )
end)
