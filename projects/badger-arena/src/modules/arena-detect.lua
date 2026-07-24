local _, ns = ...

-- Tracks whether the player is in an arena, driven by zone/login events, and notifies listeners on
-- each transition. Deliberately API-light (no Ace3) so it unit-tests directly against the WoW mock;
-- the Ace3 wiring that consumes it lives in core.lua.
local ArenaDetect = {}

local inArena = false
local listeners = {}
local frame

local function evaluate()
    local active = IsActiveBattlefieldArena() and true or false
    if active == inArena then
        return
    end
    inArena = active
    for _, listener in ipairs(listeners) do
        listener(inArena)
    end
end

function ArenaDetect.isInArena()
    return inArena
end

function ArenaDetect.onStateChange(listener)
    tinsert(listeners, listener)
end

-- Register the game events that can change arena state. Idempotent — call once from OnEnable.
function ArenaDetect.enable()
    if frame then
        return
    end
    frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", evaluate)
    evaluate()
end

ns.ArenaDetect = ArenaDetect
