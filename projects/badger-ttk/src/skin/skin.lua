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
--     display      = { <Display-node LOOK field> = <value>, ... },     -- optional geometry/readout look
--   }
-- All fields are OPTIONAL: apply() only writes what a skin carries, so a bare media/colour skin (the
-- built-ins) restyles WITHOUT touching your layout, while a "save current config" skin (D-008, amended by
-- D-010) also carries the Display LOOK. Frame POSITION and lock are NEVER captured — applying a skin
-- restyles the bars without moving them (see DISPLAY_FIELDS).

local Skin = {}

local registry = {}

-- Colour key in the skin → its db.profile field.
-- Consolidated (WO-040): Target (TTK) + three utility states — utility=waiting, ready=fire, used=fired —
-- plus the bar-text (font) colour. The old separate "waiting" colour is gone (waiting uses `utility`).
local COLOR_FIELD = {
    target = "colorTarget",
    utility = "colorUtility",
    ready = "colorReady",
    used = "colorUsed",
    font = "colorFont",
}

-- Skin-node scalar fields captured/restored alongside the colours (media + bar-text sizes).
local MEDIA_FIELDS = { "statusbar", "font", "border", "fontSizeMain", "fontSizeOther" }

-- The Display-node LOOK a "save current config" skin captures + restores (D-008, amended by D-010). This
-- is the geometry + readout look ONLY — frame position (anchorPoint/posX/posY) and lock are deliberately
-- EXCLUDED, so applying a skin restyles the bars without moving them or changing whether they're locked.
-- (A skin already saved with those fields is harmless: apply() iterates this list, so they're ignored.)
local DISPLAY_FIELDS = {
    "scale",
    "growthDirection",
    "barWidth",
    "ttkBarHeight",
    "utilityBarHeight",
    "barSpacing",
    "maxBars",
    "opacity",
    "barFgOpacity",
    "barBgOpacity",
    "strata",
    "ttkTextX",
    "ttkTextY",
    "utilTextX",
    "utilTextY",
    "showBarNames",
    "showTimers",
    "showIcons",
    "timeFormat",
    "showTrendBand",
    "showConfidence",
}

-- The DEFAULT skin's name — the one applied to a fresh profile. Code-defined built-ins (Default, Modern,
-- …) are registered via RegisterBuiltin and can never be deleted or overwritten.
Skin.BUILTIN = "Default"

local builtins = {} -- set of code-defined skin names — protected from delete/save-over

function Skin.RegisterSkin(name, skin)
    registry[name] = skin
end

-- Register a code-defined built-in: present at load, and protected from delete/overwrite (isBuiltin).
function Skin.RegisterBuiltin(name, skin)
    builtins[name] = true
    registry[name] = skin
end

function Skin.isBuiltin(name)
    return builtins[name] == true
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

-- PURE: delete a user skin from the registry. Refuses any code-defined built-in and unknown names.
-- Returns true if a skin was removed, so the caller can also drop it from db.global + pick a fallback.
function Skin.deleteSkin(name)
    if not name or Skin.isBuiltin(name) or not registry[name] then
        return false
    end
    registry[name] = nil
    return true
end

-- Apply a named skin's values onto `profile`. Only writes what the skin carries: media/sizes (present),
-- the six colours (present), and the Display LOOK block (present) — so a bare built-in restyles without
-- touching layout, and a saved skin also restores the geometry/readout look. Frame position/lock are never
-- in DISPLAY_FIELDS, so a skin never moves the bars. No-op for an unknown skin.
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

-- PURE: snapshot the current profile as a new skin table (media/sizes + the six colours + the Display
-- LOOK — geometry/readout, NOT frame position/lock), register it under `name`, and return it so the caller
-- can persist it (db.global). Captures a value copy of every field, so later profile edits don't mutate it.
function Skin.saveCurrent(profile, name)
    -- Never overwrite a code-defined built-in: a saved "Default"/"Modern" would shadow it and can't be
    -- deleted (deleteSkin refuses built-ins), so it would be un-removable (audit #2).
    if not name or Skin.isBuiltin(name) then
        return nil
    end
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

-- PURE: serialize a registered skin as a paste-ready Lua-table literal (WO-060) — the EXACT format
-- RegisterSkin accepts, so an exported skin can be handed over and baked in verbatim. Deterministic
-- field order (media → colors → display, fixed key sequence); returns "" for an unknown skin.
local COLOR_ORDER = { "target", "utility", "ready", "used", "font" }

local function fmtNum(n)
    return string.format("%.4g", n)
end

local function fmtVal(v)
    if type(v) == "string" then
        return string.format("%q", v)
    elseif type(v) == "boolean" then
        return tostring(v)
    end
    return fmtNum(v)
end

function Skin.serialize(name)
    local skin = registry[name]
    if not skin then
        return ""
    end
    local out = { "{" }
    -- The name leads, so a pasted export lands in the picker under its own name (WO-062).
    out[#out + 1] = string.format("    name = %s,", string.format("%q", name))
    for i = 1, #MEDIA_FIELDS do
        local field = MEDIA_FIELDS[i]
        if skin[field] ~= nil then
            out[#out + 1] = string.format("    %s = %s,", field, fmtVal(skin[field]))
        end
    end
    if skin.colors then
        out[#out + 1] = "    colors = {"
        for i = 1, #COLOR_ORDER do
            local c = skin.colors[COLOR_ORDER[i]]
            if c then
                out[#out + 1] = string.format(
                    "        %s = { %s, %s, %s, %s },",
                    COLOR_ORDER[i],
                    fmtNum(c[1]),
                    fmtNum(c[2]),
                    fmtNum(c[3]),
                    fmtNum(c[4] or 1)
                )
            end
        end
        out[#out + 1] = "    },"
    end
    if skin.display then
        out[#out + 1] = "    display = {"
        for i = 1, #DISPLAY_FIELDS do
            local field = DISPLAY_FIELDS[i]
            if skin.display[field] ~= nil then
                out[#out + 1] =
                    string.format("        %s = %s,", field, fmtVal(skin.display[field]))
            end
        end
        out[#out + 1] = "    },"
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n")
end

-- PURE: parse a serialized skin literal (from serialize / a hand-written export) back into a table.
-- Returns (skin, nil) or (nil, errmsg). Sandboxed: the chunk runs in an EMPTY environment (setfenv on
-- the 5.1 client), so a paste can only build a table literal, never call anything. Requires a string
-- `name` so the import lands under a known picker entry (WO-062).
local loadchunk = loadstring or load

function Skin.deserialize(text)
    if type(text) ~= "string" or not text:match("%S") then
        return nil, "nothing to import"
    end
    local chunk = loadchunk("return " .. text)
    if not chunk then
        return nil, "not a valid skin (Lua syntax error)"
    end
    if setfenv then
        setfenv(chunk, {}) -- WoW/5.1: block any global access from the pasted text
    end
    local ok, tbl = pcall(chunk)
    if not ok or type(tbl) ~= "table" then
        return nil, "not a skin table"
    end
    if type(tbl.name) ~= "string" or tbl.name == "" then
        return nil, "the skin needs a name field"
    end
    return tbl
end

-- Built-in "Default" skin — the Badger brand palette + safe stock media. Always present; never deletable.
Skin.RegisterBuiltin(Skin.BUILTIN, {
    statusbar = "Blizzard Raid Bar",
    font = "Arial Narrow",
    border = "None",
    colors = {
        target = { 0.85, 0.15, 0.15, 1 }, -- Target (TTK)
        utility = { 0, 0, 0, 1 }, -- Utility (waiting)
        ready = { 0.15, 0.85, 0.25, 1 }, -- Utility (fire)
        used = { 0.55, 0.55, 0.55, 1 }, -- Utility (fired)
        font = { 1, 1, 1, 1 }, -- bar text
    },
})

-- Built-in "Modern" skin (WO-062) — a clean look with the full Display block. Depends on the "Clean"
-- statusbar + "Accidental Presidency" font being registered with LibSharedMedia; media() falls back if not.
Skin.RegisterBuiltin("Modern", {
    statusbar = "Clean",
    font = "Accidental Presidency",
    border = "None",
    fontSizeMain = 14,
    fontSizeOther = 11,
    colors = {
        target = { 0.85, 0.15, 0.15, 1 },
        utility = { 0, 0, 0, 1 },
        ready = { 0.15, 0.85, 0.25, 1 },
        used = { 0.55, 0.55, 0.55, 1 },
        font = { 1, 1, 1, 1 },
    },
    display = {
        scale = 1,
        growthDirection = "UP",
        barWidth = 180,
        ttkBarHeight = 30,
        utilityBarHeight = 20,
        barSpacing = 0,
        maxBars = 8,
        opacity = 1,
        barFgOpacity = 0.95,
        barBgOpacity = 1,
        strata = "MEDIUM",
        ttkTextX = 0,
        ttkTextY = 0,
        utilTextX = 0,
        utilTextY = 0,
        showBarNames = true,
        showTimers = true,
        showIcons = true,
        timeFormat = "mmss",
        showTrendBand = true,
        showConfidence = true,
    },
})

ns.Skin = Skin
