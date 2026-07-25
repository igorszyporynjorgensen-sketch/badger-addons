local mock = require("tools.wow-mock.init")

describe("Abilities", function()
    local ns

    before_each(function()
        ns = {}
        mock.load("projects/badger-ttk/src/abilities/table.lua", ns)
        mock.load("projects/badger-ttk/src/abilities/abilities.lua", ns)
    end)

    local spell = { id = 12328, idType = "spell", kind = "ability" }
    local trinket = { id = 21180, idType = "item", kind = "trinket" }
    local potion = { id = 13442, idType = "item", kind = "consumable" }
    local function char(t)
        return {
            knownSpells = t.knownSpells or {},
            equippedTrinkets = t.equippedTrinkets or {},
            bagCounts = t.bagCounts or {},
        }
    end

    it("a spell is available when known", function()
        assert.is_true(ns.Abilities.available(spell, char({ knownSpells = { [12328] = true } })))
        assert.is_false(ns.Abilities.available(spell, char({})))
    end)

    it("a trinket is available when equipped", function()
        assert.is_true(
            ns.Abilities.available(trinket, char({ equippedTrinkets = { [21180] = true } }))
        )
        assert.is_false(ns.Abilities.available(trinket, char({})))
    end)

    it("a consumable is available when in bags", function()
        assert.is_true(ns.Abilities.available(potion, char({ bagCounts = { [13442] = 3 } })))
        assert.is_false(ns.Abilities.available(potion, char({ bagCounts = { [13442] = 0 } })))
    end)

    it("derives active state from a live aura", function()
        local s = ns.Abilities.deriveState(trinket, { auraRemaining = 12 })
        assert.is_true(s.active)
        assert.equals(12, s.remaining)
    end)

    it("derives a usable planned state when no aura is up", function()
        local s = ns.Abilities.deriveState(trinket, { usable = true })
        assert.is_false(s.active)
        assert.is_true(s.usable)
    end)

    it("shows only when enabled and (usable or buff-active)", function()
        assert.is_true(ns.Abilities.shouldShow(true, { usable = true, active = false }))
        assert.is_true(ns.Abilities.shouldShow(true, { usable = false, active = true }))
        assert.is_false(ns.Abilities.shouldShow(false, { usable = true, active = true }))
        assert.is_false(ns.Abilities.shouldShow(true, { usable = false, active = false }))
    end)
end)
