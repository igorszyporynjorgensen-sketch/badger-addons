local _, ns = ...

-- The live driver — real combat → the display. The `assembleEntries` + `gate` helpers are PURE (plain
-- inputs, no WoW API) so they unit-test off-client; the sampling / event / aura-cooldown reads are the
-- untestable edge. Reuses ns.Estimator / ns.RenderModel / ns.Abilities / ns.AbilityTable — no new math.

local Estimator = ns.Estimator
local RenderModel = ns.RenderModel
local Abilities = ns.Abilities
local AbilityTable = ns.AbilityTable

local LiveDriver = {}

-- Per-entry config: enabled (default true), offset (default 0).
local function entryConfig(config, id)
    local c = config[id]
    return (not c or c.enabled ~= false), (c and c.offset) or 0
end

-- PURE: build the render-model entries. Include an enabled entry when it is available (owned / equipped /
-- in bags) OR its buff is active (the override). Active → draining (remaining); else planned (offset/D/C).
-- `states[id] = { auraRemaining, usable }`.
function LiveDriver.assembleEntries(entries, config, character, states)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        local enabled, offset = entryConfig(config, e.id)
        local available = Abilities.available(e, character)
        local state = Abilities.deriveState(e, states[e.id] or {})
        if enabled and (available or state.active) then
            local entry = {
                id = e.id,
                name = e.name,
                duration = e.duration,
                cooldown = e.cooldown,
                offset = offset,
            }
            if state.active then
                entry.active = true
                entry.remaining = state.remaining
            end
            out[#out + 1] = entry
        end
    end
    return out
end

-- PURE: should the bars show? `settings` = the enable/Behavior profile; `context` = { hasTarget, inCombat,
-- hostile, ttk }. `showAnyTarget` bypasses the hostile gate (testing); combat + minTTK still apply.
function LiveDriver.gate(settings, context)
    if not (settings.enabled and context.hasTarget) then
        return false
    end
    if settings.inCombatOnly and not context.inCombat then
        return false
    end
    if not settings.showAnyTarget and settings.requireHostile and not context.hostile then
        return false
    end
    if context.ttk and context.ttk < settings.minTTK then
        return false
    end
    return true
end

-- ===== the client edge (untestable off-client; delegates all decisions to the pure helpers above) =====

local frame -- event + ticker frame
local est -- per-target estimator
local lastGUID
local character = { knownSpells = {}, equippedTrinkets = {}, bagCounts = {} }
local nameIndex -- buff name → entry (for aura matching)
local accum = 0
local INTERVAL = 0.15
local suspended = false -- pushed true by the display while a sim preview owns the container

-- The display commands this directly the instant a preview is toggled (see Display.showPreview/playSim),
-- so the driver never has to read db.profile on a tick to know a preview is up. Belt-and-suspenders: the
-- update() guard ALSO checks the db flags, so a real target is never blocked even if this desynced.
function LiveDriver.setSuspended(v)
    suspended = v and true or false
end

local function rescan()
    character = Abilities.scanCharacter()
    if not nameIndex then
        nameIndex = {}
        for i = 1, #AbilityTable do
            nameIndex[AbilityTable[i].name] = AbilityTable[i]
        end
    end
end

-- Active-buff remaining per entry: scan the player's buffs by name (heuristic — refine with buff
-- spellIDs, the reference doc's open verification item).
local function readStates()
    local states = {}
    for i = 1, 40 do
        local name, _, _, _, _, expires = UnitAura("player", i, "HELPFUL")
        if not name then
            break
        end
        local e = nameIndex[name]
        if e then
            states[e.id] =
                { auraRemaining = (expires and expires > 0) and (expires - GetTime()) or 0 }
        end
    end
    return states
end

local function update()
    local p = ns.addon.db.profile
    -- A sim preview (static or dynamic playback) owns the display; don't clobber/hide it. `suspended` is
    -- the display's explicit command; the db flags are the backstop (see LiveDriver.setSuspended).
    if suspended or p.simStatic or p.simPlaying then
        return
    end
    if not UnitExists("target") then
        est, lastGUID = nil, nil
        ns.Display.hide()
        return
    end
    local guid = UnitGUID("target")
    if guid ~= lastGUID then
        lastGUID = guid
        est = Estimator.new({
            reactivity = p.reactivity,
            executeThreshold = p.executeThreshold,
            executeModifier = p.executeModifier,
        })
    end
    local maxhp = UnitHealthMax("target")
    local h = (maxhp > 0) and (UnitHealth("target") / maxhp) or 1
    est:sample(GetTime(), h, not UnitIsDeadOrGhost("target"))
    local ttk = est:ttk()

    local context = {
        hasTarget = true,
        inCombat = InCombatLockdown(),
        hostile = UnitCanAttack("player", "target"),
        ttk = ttk,
    }
    if not LiveDriver.gate(p, context) then
        ns.Display.hide()
        return
    end

    local entries = LiveDriver.assembleEntries(AbilityTable, p.abilities, character, readStates())
    ns.Display.render(RenderModel.build(ttk or 0, entries), h)
end

function LiveDriver.start()
    if frame then
        return
    end
    rescan()
    frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum >= INTERVAL then
            accum = 0
            update()
        end
    end)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_TARGET_CHANGED" then
            rescan()
        end
        update()
    end)
end

ns.LiveDriver = LiveDriver
