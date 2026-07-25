local _, ns = ...

-- Ability model logic. The `available` / `deriveState` / `shouldShow` rules are PURE (plain inputs, no
-- WoW API) so they unit-test off-client; only `scanCharacter` touches the client to gather the character
-- state those rules consume. The live driver (WO-015) samples auras/cooldowns and calls these to build
-- the tracked entries the render-model draws.

local Abilities = {}

local AbilityTable = ns.AbilityTable

-- Is `entry` usable IF OWNED, given the character state? Spells → known; trinkets → equipped;
-- consumables / engineering → in bags. `character` = { knownSpells, equippedTrinkets, bagCounts }.
function Abilities.available(entry, character)
    if entry.idType == "spell" then
        return character.knownSpells[entry.id] == true
    elseif entry.kind == "trinket" then
        return character.equippedTrinkets[entry.id] == true
    end
    return (character.bagCounts[entry.id] or 0) > 0
end

-- Derive an entry's live state from plain game inputs. `game` = { auraRemaining, usable }.
-- A live buff → active (with its remaining); otherwise planned + whether it can be fired now.
-- (`_entry` is reserved for the live driver, WO-015 — kind-specific handling — and unused here.)
function Abilities.deriveState(_entry, game)
    local remaining = game.auraRemaining
    if remaining and remaining > 0 then
        return { active = true, remaining = remaining, usable = false }
    end
    return { active = false, usable = game.usable == true }
end

-- Visibility rule: a bar shows only when the entry is enabled AND (usable-now OR its buff is active).
function Abilities.shouldShow(enabled, state)
    return enabled and (state.usable or state.active) or false
end

-- The client edge (untestable off-client): gather the character state the rules consume.
function Abilities.scanCharacter()
    local knownSpells, equippedTrinkets, bagCounts = {}, {}, {}
    local t1 = GetInventoryItemID("player", 13)
    local t2 = GetInventoryItemID("player", 14)
    if t1 then
        equippedTrinkets[t1] = true
    end
    if t2 then
        equippedTrinkets[t2] = true
    end
    for i = 1, #AbilityTable do
        local e = AbilityTable[i]
        if e.idType == "spell" then
            knownSpells[e.id] = IsPlayerSpell(e.id) and true or false
        elseif e.kind ~= "trinket" then
            bagCounts[e.id] = GetItemCount(e.id)
        end
    end
    return { knownSpells = knownSpells, equippedTrinkets = equippedTrinkets, bagCounts = bagCounts }
end

ns.Abilities = Abilities
