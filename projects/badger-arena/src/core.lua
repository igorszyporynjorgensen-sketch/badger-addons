local ADDON_NAME, ns = ...

-- Addon bootstrap. Ace3 provides saved-variable profiles, an event mixin, and a slash-driven
-- options panel. Feature modules hang off `ns`; this file wires them together.
local BadgerArena = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.addon = BadgerArena

local DEFAULTS = {
    profile = {
        enabled = true,
        showDR = true,
        showTrinket = true,
    },
}

function BadgerArena:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BadgerArenaDB", DEFAULTS, true)
    ns.buildOptions(self)
    self:RegisterChatCommand("badgerarena", "OpenOptions")
    self:RegisterChatCommand("bga", "OpenOptions")
end

function BadgerArena:OnEnable()
    ns.ArenaDetect.onStateChange(function(inArena)
        self:SendMessage("BADGER_ARENA_STATE_CHANGED", inArena)
    end)
    ns.ArenaDetect.enable()
end

function BadgerArena:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
end
