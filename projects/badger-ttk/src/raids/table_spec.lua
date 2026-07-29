local mock = require("tools.wow-mock.init")

describe("RaidTable", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/raids/table.lua")
    end)

    it("lists the Classic-Era raids in order", function()
        local ids = {}
        for i = 1, #ns.RaidTable do
            ids[i] = ns.RaidTable[i].id
        end
        assert.same({ "mc", "onyxia", "bwl", "zg", "aq20", "aq40", "naxx", "world" }, ids)
    end)

    it("gives every raid a name and at least one encounter", function()
        for i = 1, #ns.RaidTable do
            local raid = ns.RaidTable[i]
            assert.is_true(type(raid.name) == "string" and raid.name ~= "")
            assert.is_true(#raid.encounters >= 1)
        end
    end)

    it("uses globally-unique raid and encounter ids (safe db.profile keys)", function()
        local raidIds, encIds = {}, {}
        for i = 1, #ns.RaidTable do
            local raid = ns.RaidTable[i]
            assert.is_nil(raidIds[raid.id], "duplicate raid id: " .. tostring(raid.id))
            raidIds[raid.id] = true
            for j = 1, #raid.encounters do
                local enc = raid.encounters[j]
                assert.is_true(type(enc.name) == "string" and enc.name ~= "")
                assert.is_nil(encIds[enc.id], "duplicate encounter id: " .. tostring(enc.id))
                encIds[enc.id] = true
            end
        end
    end)
end)
