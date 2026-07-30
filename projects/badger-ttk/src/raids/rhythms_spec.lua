local mock = require("tools.wow-mock.init")

-- Pure generated data — the spec guards the STRUCTURE (a regeneration mistake must fail the gate),
-- not the learned values themselves (those are validated by the lab's held-out grading, WO-069).
describe("Rhythms", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/raids/rhythms.lua")
    end)

    it("ships all learned profiles (five raids), aliased on both id spaces", function()
        local classic = {
            610,
            611,
            612,
            613,
            614,
            615,
            616,
            617,
            663,
            664,
            665,
            666,
            667,
            668,
            669,
            670,
            672,
            709,
            710,
            711,
            712,
            713,
            714,
            715,
            716,
            717,
            718,
            719,
            720,
            721,
            722,
            723,
            784,
            785,
            786,
            787,
            789,
            790,
            791,
            792,
            793,
        }
        for _, id in ipairs(classic) do
            assert.is_table(ns.Rhythms[id], "missing classic id " .. id)
            -- The WCL Fresh partition names the same encounter at +150000 — same table, by identity.
            assert.equals(ns.Rhythms[id], ns.Rhythms[id + 150000])
        end
        assert.equals(
            41 * 2,
            (function()
                local n = 0
                for _ in pairs(ns.Rhythms) do
                    n = n + 1
                end
                return n
            end)()
        )
        assert.is_nil(ns.Rhythms[671]) -- Majordomo deliberately absent (his fight is his adds)
        assert.is_nil(ns.Rhythms[788]) -- Edge of Madness absent (four random bosses share the id)
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
