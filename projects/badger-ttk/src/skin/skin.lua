local _, ns = ...

-- Open skin engine. A skin is a DATA-ONLY preset: media (LibSharedMedia names) + the six state colours.
-- Anyone adds one with BadgerTTK:RegisterSkin(name, skin) (exposed on the addon, reachable via
-- LibStub("AceAddon-3.0"):GetAddon("BadgerTTK", true)); it then appears in the picker. Selecting a skin
-- applies its values onto the profile (which the user can then tweak per-setting). The registry + apply
-- are pure so they unit-test off-client; the LSM fetch + frame paint live in display.lua.
--
-- Skin format (public contract — data only, no code in v1):
--   {
--     statusbar = "<LSM statusbar name>",   -- e.g. "Blizzard"
--     font      = "<LSM font name>",        -- e.g. "Friz Quadrata TT"
--     border    = "<LSM border name>",      -- e.g. "None"
--     colors    = { target=, utility=, planned=, active=, over=, short= },  -- each { r, g, b, a }
--   }

local Skin = {}

local registry = {}

-- Colour key in the skin → its db.profile field.
local COLOR_FIELD = {
    target = "colorTarget",
    utility = "colorUtility",
    planned = "colorPlanned",
    active = "colorActive",
    over = "colorOverkill",
    short = "colorShortfall",
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

-- Apply a named skin's values onto `profile` (media + the six colours). No-op for an unknown skin.
function Skin.apply(profile, name)
    local skin = registry[name]
    if not skin then
        return
    end
    profile.statusbar = skin.statusbar
    profile.font = skin.font
    profile.border = skin.border
    for key, field in pairs(COLOR_FIELD) do
        local c = skin.colors and skin.colors[key]
        if c then
            profile[field] = { c[1], c[2], c[3], c[4] }
        end
    end
end

-- Built-in default skin — the Badger brand palette + safe stock media.
Skin.RegisterSkin("Badger", {
    statusbar = "Blizzard",
    font = "Friz Quadrata TT",
    border = "None",
    colors = {
        target = { 0.85, 0.15, 0.15, 1 },
        utility = { 0.25, 0.50, 0.90, 1 },
        planned = { 0.96, 0.77, 0.26, 1 },
        active = { 0.20, 0.80, 0.30, 1 },
        over = { 0.55, 0.55, 0.55, 1 },
        short = { 0.95, 0.55, 0.15, 1 },
    },
})

ns.Skin = Skin
