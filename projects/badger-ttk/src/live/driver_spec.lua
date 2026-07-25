local mock = require("tools.wow-mock.init")

describe("LiveDriver", function()
    local ns

    before_each(function()
        ns = {}
        mock.load("projects/badger-ttk/src/abilities/abilities.lua", ns)
        mock.load("projects/badger-ttk/src/live/driver.lua", ns)
    end)

    local TBL = {
        { id = 1, idType = "spell", kind = "ability", duration = 30, cooldown = 180 },
        { id = 2, idType = "item", kind = "trinket", duration = 20, cooldown = 120 },
        { id = 3, idType = "item", kind = "consumable", duration = 20, cooldown = 60 },
    }
    local function char(t)
        return {
            knownSpells = t.knownSpells or {},
            equippedTrinkets = t.equippedTrinkets or {},
            bagCounts = t.bagCounts or {},
        }
    end

    describe("assembleEntries", function()
        it("includes only enabled + available (or buff-active) entries", function()
            local config =
                { [1] = { enabled = true }, [2] = { enabled = false }, [3] = { enabled = true } }
            local character = char({
                knownSpells = { [1] = true },
                equippedTrinkets = { [2] = true },
                bagCounts = { [3] = 0 },
            })
            local out = ns.LiveDriver.assembleEntries(TBL, config, character, {})
            -- 1 enabled+known → in; 2 disabled → out; 3 enabled but 0 in bags + no buff → out
            assert.equals(1, #out)
            assert.equals(1, out[1].id)
        end)

        it("shows a consumable with no stock when its buff is active (override)", function()
            local config = { [3] = { enabled = true } }
            local character = char({ bagCounts = { [3] = 0 } })
            local out = ns.LiveDriver.assembleEntries(
                TBL,
                config,
                character,
                { [3] = { auraRemaining = 8 } }
            )
            assert.equals(1, #out)
            assert.is_true(out[1].active)
            assert.equals(8, out[1].remaining)
        end)

        it("carries the per-entry offset through", function()
            local config = { [1] = { enabled = true, offset = 10 } }
            local character = char({ knownSpells = { [1] = true } })
            local out = ns.LiveDriver.assembleEntries(TBL, config, character, {})
            assert.equals(10, out[1].offset)
        end)
    end)

    describe("gate", function()
        local base = {
            enabled = true,
            inCombatOnly = true,
            requireHostile = true,
            showAnyTarget = false,
            minTTK = 10,
        }
        local function settings(over)
            local s = {}
            for k, v in pairs(base) do
                s[k] = v
            end
            for k, v in pairs(over or {}) do
                s[k] = v
            end
            return s
        end

        it("hides with no target or when disabled", function()
            assert.is_false(ns.LiveDriver.gate(settings(), { hasTarget = false }))
            assert.is_false(
                ns.LiveDriver.gate(
                    settings({ enabled = false }),
                    { hasTarget = true, inCombat = true, hostile = true }
                )
            )
        end)

        it("respects in-combat-only", function()
            assert.is_false(
                ns.LiveDriver.gate(
                    settings(),
                    { hasTarget = true, inCombat = false, hostile = true }
                )
            )
            assert.is_true(
                ns.LiveDriver.gate(
                    settings(),
                    { hasTarget = true, inCombat = true, hostile = true, ttk = 20 }
                )
            )
        end)

        it("requires a hostile target unless show-any-target", function()
            assert.is_false(
                ns.LiveDriver.gate(
                    settings(),
                    { hasTarget = true, inCombat = true, hostile = false }
                )
            )
            assert.is_true(
                ns.LiveDriver.gate(
                    settings({ showAnyTarget = true }),
                    { hasTarget = true, inCombat = true, hostile = false, ttk = 20 }
                )
            )
        end)

        it("hides below minTTK", function()
            assert.is_false(
                ns.LiveDriver.gate(
                    settings(),
                    { hasTarget = true, inCombat = true, hostile = true, ttk = 5 }
                )
            )
        end)
    end)
end)
