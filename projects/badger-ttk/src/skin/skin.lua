local _, ns = ...

-- Open skin engine. A skin is a DATA-ONLY preset: media (LibSharedMedia names), font sizes, the state
-- colours, and an optional Display block ("save current config" snapshots — see saveCurrent / D-008).
-- Anyone adds one with BadgerTTK:RegisterSkin(name, skin) (exposed on the addon, reachable via
-- LibStub("AceAddon-3.0"):GetAddon("BadgerTTK", true)); it then appears in the picker. Selecting a skin
-- applies its values onto the profile (which the user can then tweak per-setting). The registry + apply
-- are pure so they unit-test off-client; the LSM fetch + frame paint live in display.lua.
--
-- Skin format (public contract — data only, no code):
--   {
--     statusbar    = "<LSM statusbar name>",   -- e.g. "Blizzard"
--     font         = "<LSM font name>",        -- e.g. "Friz Quadrata TT"
--     border       = "<LSM border name>",      -- e.g. "None"
--     fontSizeMain = <n>, fontSizeOther = <n>, -- optional bar-text sizes
--     colors       = { target=, utility=, waiting=, ready=, used= },  -- each { r, g, b, a }
--     display      = { <Display-node field> = <value>, ... },         -- optional full Display config
--   }
-- All fields are OPTIONAL: apply() only writes what a skin carries, so a bare media/colour skin (the
-- built-ins) restyles WITHOUT touching your layout, while a "save current config" skin (D-008) also
-- carries the Display block and restores geometry/position on apply.

local Skin = {}

local registry = {}

-- Colour key in the skin → its db.profile field.
local COLOR_FIELD = {
    target = "colorTarget",
    utility = "colorUtility",
    waiting = "colorWaiting",
    ready = "colorReady",
    used = "colorUsed",
}

-- Skin-node scalar fields captured/restored alongside the colours (media + bar-text sizes).
local MEDIA_FIELDS = { "statusbar", "font", "border", "fontSizeMain", "fontSizeOther" }

-- The full Display-node config a "save current config" skin captures + restores (D-008). Includes
-- position/lock, so applying such a skin restores the exact saved layout; built-in skins omit this
-- block entirely and therefore never move your bars.
local DISPLAY_FIELDS = {
    "anchorPoint",
    "locked",
    "posX",
    "posY",
    "scale",
    "growthDirection",
    "barWidth",
    "barHeight",
    "barSpacing",
    "maxBars",
    "opacity",
    "strata",
    "showBarNames",
    "showTimers",
    "showIcons",
    "timeFormat",
    "showTrendBand",
    "showConfidence",
}

function Skin.RegisterSkin(name, skin)
    registry[name] = skin
end

function Skin.GetSkin(name)
    return registry[name]
end

-- { name = name } for the config select (AceConfig `values`).
function Skin.ListSkins()
    local out = {}
    for name in pairs(registry) do
        out[name] = name
    end
    return out
end

-- Apply a named skin's values onto `profile`. Only writes what the skin carries: media/sizes (present),
-- the six colours (present), and the Display block (present) — so a bare built-in restyles without
-- touching layout, and a saved-config skin also restores geometry/position. No-op for an unknown skin.
function Skin.apply(profile, name)
    local skin = registry[name]
    if not skin then
        return
    end
    for i = 1, #MEDIA_FIELDS do
        local field = MEDIA_FIELDS[i]
        if skin[field] ~= nil then
            profile[field] = skin[field]
        end
    end
    for key, field in pairs(COLOR_FIELD) do
        local c = skin.colors and skin.colors[key]
        if c then
            profile[field] = { c[1], c[2], c[3], c[4] }
        end
    end
    if skin.display then
        for i = 1, #DISPLAY_FIELDS do
            local field = DISPLAY_FIELDS[i]
            if skin.display[field] ~= nil then
                profile[field] = skin.display[field]
            end
        end
    end
end

-- PURE: snapshot the current profile as a new skin table (media/sizes + the six colours + the full
-- Display config), register it under `name`, and return it so the caller can persist it (db.global).
-- Captures a value copy of every field, so later profile edits don't mutate the saved skin.
function Skin.saveCurrent(profile, name)
    local skin = { colors = {}, display = {} }
    for i = 1, #MEDIA_FIELDS do
        local field = MEDIA_FIELDS[i]
        skin[field] = profile[field]
    end
    for key, field in pairs(COLOR_FIELD) do
        local c = profile[field]
        if c then
            skin.colors[key] = { c[1], c[2], c[3], c[4] }
        end
    end
    for i = 1, #DISPLAY_FIELDS do
        local field = DISPLAY_FIELDS[i]
        skin.display[field] = profile[field]
    end
    registry[name] = skin
    return skin
end

-- Built-in default skin — the Badger brand palette + safe stock media.
Skin.RegisterSkin("Badger", {
    statusbar = "Blizzard",
    font = "Friz Quadrata TT",
    border = "None",
    colors = {
        target = { 0.85, 0.15, 0.15, 1 },
        utility = { 0.25, 0.50, 0.90, 1 },
        waiting = { 0.30, 0.50, 0.80, 1 },
        ready = { 0.15, 0.85, 0.25, 1 },
        used = { 0.55, 0.55, 0.55, 1 },
    },
})

ns.Skin = Skin
