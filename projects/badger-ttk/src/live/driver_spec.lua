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

        it(
            "does not START showing below minTTK, but STAYS shown once up (sticky = no flicker)",
            function()
                local ctx = { hasTarget = true, inCombat = true, hostile = true, ttk = 5 }
                assert.is_false(ns.LiveDriver.gate(settings(), ctx, false)) -- initial: ttk 5 < 10 → no
                assert.is_true(ns.LiveDriver.gate(settings(), ctx, true)) -- already shown → stays (endgame)
            end
        )

        it("qualifies the initial show only once ttk reaches minTTK (nil = not yet)", function()
            local c = { hasTarget = true, inCombat = true, hostile = true }
            assert.is_false(ns.LiveDriver.gate(settings(), c, false)) -- ttk nil → not qualified
            c.ttk = 12
            assert.is_true(ns.LiveDriver.gate(settings(), c, false))
        end)

        it("showAnyTarget shows immediately regardless of ttk", function()
            assert.is_true(
                ns.LiveDriver.gate(
                    settings({ showAnyTarget = true }),
                    { hasTarget = true, inCombat = true, hostile = false, ttk = 3 },
                    false
                )
            )
        end)

        it("hides a dead target only when hideOnTargetDead", function()
            local ctx = { hasTarget = true, inCombat = true, hostile = true, ttk = 20, dead = true }
            assert.is_false(ns.LiveDriver.gate(settings({ hideOnTargetDead = true }), ctx, true))
            assert.is_true(ns.LiveDriver.gate(settings({ hideOnTargetDead = false }), ctx, true))
        end)
    end)

    describe("showUtility", function()
        it("shows utilities in a raid encounter regardless of the toggle", function()
            assert.is_true(
                ns.LiveDriver.showUtility(
                    { showUtilityOutsideRaid = false },
                    { inRaidEncounter = true }
                )
            )
        end)

        it("outside a raid encounter, follows the showUtilityOutsideRaid toggle", function()
            local ctx = { inRaidEncounter = false }
            assert.is_true(ns.LiveDriver.showUtility({ showUtilityOutsideRaid = true }, ctx))
            assert.is_false(ns.LiveDriver.showUtility({ showUtilityOutsideRaid = false }, ctx))
        end)
    end)
end)
