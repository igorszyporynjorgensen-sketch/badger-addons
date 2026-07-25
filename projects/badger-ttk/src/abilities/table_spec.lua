local mock = require("tools.wow-mock.init")

describe("AbilityTable", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/abilities/table.lua")
    end)

    it("lists the curated warrior cooldowns", function()
        assert.equals(14, #ns.AbilityTable)
    end)

    it("every entry is well-formed", function()
        for _, e in ipairs(ns.AbilityTable) do
            assert.is_number(e.id)
            assert.is_true(e.idType == "spell" or e.idType == "item")
            assert.is_string(e.name)
            assert.is_number(e.cooldown)
        end
    end)
end)
