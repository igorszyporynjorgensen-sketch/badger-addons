local mock = require("tools.wow-mock.init")

-- Pure generated data — the spec guards the STRUCTURE (a regeneration mistake must fail the gate),
-- not the learned values themselves (those are validated by the lab's held-out grading, WO-069).
describe("Rhythms", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/raids/rhythms.lua")
    end)

    it("ships nine MC profiles, aliased on both id spaces", function()
        local classic = { 663, 664, 665, 666, 667, 668, 669, 670, 672 }
        for _, id in ipairs(classic) do
            assert.is_table(ns.Rhythms[id], "missing classic id " .. id)
            -- The WCL Fresh partition names the same encounter at +150000 — same table, by identity.
            assert.equals(ns.Rhythms[id], ns.Rhythms[id + 150000])
        end
        assert.is_nil(ns.Rhythms[671]) -- Majordomo deliberately absent (his fight is his adds)
    end)

    it("every profile has 20 sane bins and provenance", function()
        local seen = {}
        for id, prof in pairs(ns.Rhythms) do
            if not seen[prof] then
                seen[prof] = true
                assert.is_true(prof.kills > 0, id .. ": no kill provenance")
                assert.equals(20, #prof.bins, id .. ": bin count")
                for i, m in ipairs(prof.bins) do
                    assert.is_true(
                        m >= 0.05 and m <= 8,
                        id .. " bin " .. i .. " out of range: " .. m
                    )
                end
            end
        end
    end)
end)
