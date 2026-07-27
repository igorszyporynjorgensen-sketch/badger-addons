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
        showUtilityOutsideRaid = true, -- show utility bars on non-raid-boss targets (else TTK bar only)
        minTTK = 10,
        minConfidenceToShow = 0.5,

        -- Display: layout.
        anchorPoint = "RIGHT",
        locked = true,
        posX = 0,
        posY = 0,
        scale = 1.0,
        growthDirection = "UP",
        barWidth = 220,
        ttkBarHeight = 30, -- main TTK bar height (WO-041)
        utilityBarHeight = 20, -- utility bars height (WO-041)
        barSpacing = 2,
        maxBars = 8,
        opacity = 1.0, -- overall container opacity
        barFgOpacity = 1.0, -- bar fill opacity (WO-041)
        barBgOpacity = 0.45, -- bar background-track opacity (WO-041)
        strata = "MEDIUM",
        -- Bar-text offsets from their current anchor (WO-041): TTK text (left-anchored) + utility text
        -- (right-anchored). X = horizontal, Y = vertical.
        ttkTextX = 0,
        ttkTextY = 0,
        utilTextX = 0,
        utilTextY = 0,

        -- Display: readout.
        showBarNames = true,
        showTimers = false, -- utility-bar countdown text — off by default (the bar's fill shows progress)
        showIcons = true,
        timeFormat = "mmss",
        showTrendBand = true,
        showConfidence = true,

        -- Skin: the selected skin (a preset applied onto these), LSM media names, sizes, and the six
        -- state colours. Colours are { r, g, b, a }. Media default to the built-in Badger skin.
        skin = "Default",
        statusbar = "Blizzard Raid Bar",
        font = "Arial Narrow",
        border = "None",
        fontSizeMain = 13,
        fontSizeOther = 10,
        colorTarget = { 0.85, 0.15, 0.15, 1 }, -- Target (TTK) bar
        -- Utility-bar action signal (WO-040): waiting (fire moment ahead) → fire (fire now) → fired (draining).
        colorUtility = { 0, 0, 0, 1 }, -- Utility (waiting)
        colorReady = { 0.15, 0.85, 0.25, 1 }, -- Utility (fire)
        colorUsed = { 0.55, 0.55, 0.55, 1 }, -- Utility (fired)
        colorFont = { 1, 1, 1, 1 }, -- bar text colour

        -- Estimator (v1 live-only; the math lands in the engine WO).
        reactivity = 0.5,
        leadTime = 1.5,
        executeThreshold = 0.20,
        executeModifier = 1.2,
        -- Recorded kill history (WO-025): record observed kills, and blend the per-level prior into the
        -- estimate to steady it. The history data itself lives in db.global (below).
        recordHistory = true,
        useHistory = true,

        -- Simulation preview (WO-012).
        simStatic = false,
        simPlaying = false,
        simSpeed = 1.0,

        -- Per-entry ability config: [id] = { enabled, offset }. Filled on demand by the Abilities node.
        abilities = {},

        -- Show-gating config: raids[raidId] = { enabled, encounters = { [encId] = bool } }. Filled on
        -- demand by the Raids node; an absent raid/encounter defaults to ON (see config.lua getters).
        raids = {},
    },
    -- Account-wide namespace reserved for imported/recorded kill history (see WO-007). History is
    -- observational data, not a per-settings-profile value, so it lives in `global`, never `profile`.
    global = {
        history = {},
        -- User-saved skins (WO-029): [name] = skin table (see src/skin/skin.lua). Persisted here so a
        -- "save current config as a skin" survives /reload; built-in skins stay code-defined.
        skins = {},
    },
}

function BadgerTTK:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BadgerTTKDB", DEFAULTS, true)
    -- The built-in skin was renamed "Badger" → "Default" (WO-038); carry old profiles across.
    if self.db.profile.skin == "Badger" then
        self.db.profile.skin = ns.Skin.BUILTIN
    end
    -- `barHeight` was split into ttkBarHeight / utilityBarHeight (WO-041); drop the retired field.
    self.db.profile.barHeight = nil
    -- Re-register persisted user skins into the runtime registry so they list + re-apply after a reload.
    for name, skin in pairs(self.db.global.skins or {}) do
        ns.Skin.RegisterSkin(name, skin)
    end
    ns.buildOptions(self)
    self:RegisterChatCommand("badgerttk", "OpenOptions")
    self:RegisterChatCommand("bttk", "OpenOptions")
end

function BadgerTTK:OnEnable()
    ns.LiveDriver.start()
end

function BadgerTTK:OpenOptions()
    LibStub("BadgerConfigUI-1.0"):Toggle(ADDON_NAME)
end

-- Public: other addons add a bar skin with
--   local BadgerTTK = LibStub("AceAddon-3.0"):GetAddon("BadgerTTK", true)
--   if BadgerTTK then BadgerTTK:RegisterSkin("MySkin", { ... }) end
-- See src/skin/skin.lua for the skin format.
function BadgerTTK:RegisterSkin(name, skin)
    ns.Skin.RegisterSkin(name, skin)
end
