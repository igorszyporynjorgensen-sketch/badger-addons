local ADDON_NAME, ns = ...

-- Addon bootstrap. Ace3 provides saved-variable profiles (per-character or shared), an event mixin,
-- and a slash-driven options panel. Feature modules will hang off `ns`; this file wires them together.
-- The config tree (config.lua) binds every option's get/set to `db.profile.*`; the functionality work
-- orders read these values when they land. No time-to-kill behavior yet.
local BadgerTTK = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.addon = BadgerTTK

-- Real-typed defaults — booleans / numbers / colour tables, never string forms. `db.profile` holds every
-- setting; `db.global` is reserved for imported/recorded kill history (the WO-007 seam), not `db.profile`.
local DEFAULTS = {
    profile = {
        enabled = true,

        -- Behavior / show-gating (general rules; the Raids registry + gating logic land in a later WO).
        inCombatOnly = true,
        hideOnTargetDead = true,
        requireHostile = true,
        showAnyTarget = false,
        minTTK = 10,
        minConfidenceToShow = 0.5,

        -- Display: layout.
        anchorPoint = "RIGHT",
        locked = true,
        posX = 0,
        posY = 0,
        scale = 1.0,
        growthDirection = "UP",
        barWidth = 180,
        barHeight = 20,
        barSpacing = 2,
        maxBars = 8,
        opacity = 1.0,
        strata = "MEDIUM",

        -- Display: readout.
        showBarNames = true,
        showTimers = true,
        showIcons = true,
        timeFormat = "mmss",
        showTrendBand = true,
        showConfidence = true,

        -- Skin (LSM-backed font family / texture / border land with the skin engine WO; sizes + the six
        -- state colours are here). Colours are { r, g, b, a }.
        skin = "Badger",
        fontSizeMain = 16,
        fontSizeOther = 12,
        colorTarget = { 0.85, 0.15, 0.15, 1 },
        colorUtility = { 0.25, 0.50, 0.90, 1 },
        colorPlanned = { 0.96, 0.77, 0.26, 1 },
        colorActive = { 0.20, 0.80, 0.30, 1 },
        colorOverkill = { 0.55, 0.55, 0.55, 1 },
        colorShortfall = { 0.95, 0.55, 0.15, 1 },

        -- Estimator (v1 live-only; the math lands in the engine WO).
        reactivity = 0.5,
        leadTime = 1.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
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
