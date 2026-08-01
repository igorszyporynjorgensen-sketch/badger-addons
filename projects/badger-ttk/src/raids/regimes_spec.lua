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

    it("keys Thekal's resurrect reset on 789 — NOT on 790, which is Gahz'ranka", function()
        -- The load-bearing id correction (design §1.3 graft 6), verified against real WCL fixture names:
        -- 150789 = "High Priest Thekal", 150790 = "Gahz'ranka". `resetOnRise` on the wrong key silently
        -- no-ops, and nothing else in the gate would notice — so assert both id spaces explicitly.
        assert.is_true(
            (ns.Regimes[789].resetOnRise or 0) > 0,
            "Thekal (789) lost his resurrect reset"
        )
        assert.is_true((ns.Regimes[150789].resetOnRise or 0) > 0, "Fresh alias 150789 lost it")
        assert.is_nil(ns.Regimes[790].resetOnRise, "Gahz'ranka (790) must NOT carry Thekal's reset")
        assert.is_nil(ns.Regimes[150790].resetOnRise, "Fresh alias 150790 must NOT carry it")
    end)

    it("never ships an EMPTY profile (a profile must actually say something)", function()
        for key, prof in pairs(ns.Regimes) do
            if type(prof) == "table" and key ~= "default" then
                local says = prof.hideBar
                    or prof.suppressFlush
                    or prof.confCap
                    or prof.resetOnRise
                    or prof.healPolluted
                    or prof.secondPool
                assert.is_true(says and true or false, "empty profile @ " .. tostring(key))
            end
        end
    end)

    it(
        "STRUCTURE: confCap bins in 1..K with values in [0,1]; resetOnRise in (0,1]; no removed fields",
        function()
            for key, prof in pairs(ns.Regimes) do
                if type(prof) == "table" then
                    local at = " @ " .. tostring(key)
                    -- `freeze` was removed in PR3 (D-020) — the estimator no longer reads it, so a profile
                    -- carrying one would be silently dead data. Fail the gate if the assembler regresses.
                    assert.is_nil(prof.freeze, "removed `freeze` field still emitted" .. at)
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
