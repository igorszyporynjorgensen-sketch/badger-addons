local ADDON_NAME, ns = ...

-- Addon bootstrap. Ace3 provides saved-variable profiles (per-character or shared), an event mixin,
-- and a slash-driven options panel. Feature modules will hang off `ns`; this file wires them together.
-- No time-to-kill behavior yet — this is the scaffold (WO-008); functionality lands in later work orders.
local BadgerTTK = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.addon = BadgerTTK

local DEFAULTS = {
    profile = {
        enabled = true,
    },
    -- Account-wide namespace reserved for imported/recorded kill history (see WO-007). History is
    -- observational data, not a per-settings-profile value, so it lives in `global`, never `profile`.
    global = {
        history = {},
    },
}

function BadgerTTK:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BadgerTTKDB", DEFAULTS, true)
    ns.buildOptions(self)
    self:RegisterChatCommand("badgerttk", "OpenOptions")
    self:RegisterChatCommand("bttk", "OpenOptions")
end

function BadgerTTK:OpenOptions()
    LibStub("BadgerConfigUI-1.0"):Toggle(ADDON_NAME)
end
