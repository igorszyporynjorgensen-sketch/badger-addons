local ADDON_NAME, ns = ...

-- The badger-ttk options tree. The FULL navigable window: every setting reads/writes db.profile and
-- persists across /reload, and the live driver / display / estimator read these values. The data-driven
-- nodes are built from their registries — Abilities (per class, the warrior list from ns.AbilityTable),
-- Raids (ns.RaidTable), Simulation. Registered/opened through the shared BadgerConfigUI library (no
-- ad-hoc AceConfig). Kept declarative so the schema is easy to grow. Every changeable option carries a
-- `desc` hint (WO-027).
--
-- Node icons use AceConfig's native `icon` field (a texture path) — no BadgerConfigUI change. Per-entry
-- spell/item label-icons (a `|T...|t` helper) arrive with the ability/raid work orders that need them.

local ICON = "Interface\\ICONS\\"
local LSM = LibStub("LibSharedMedia-3.0")

local ANCHORS = {
    TOPRIGHT = "Top-right",
    RIGHT = "Right",
    BOTTOMRIGHT = "Bottom-right",
    CENTER = "Center",
    LEFT = "Left",
}
local GROWTH = { UP = "Up", DOWN = "Down" }
local STRATA =
    { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog" }
local TIMEFMT = { mmss = "m:ss", seconds = "Seconds" }

-- Bind an option to db.profile.<key> in one line.
local function getter(db, key)
    return function()
        return db.profile[key]
    end
end

local function setter(db, key)
    return function(_, value)
        db.profile[key] = value
    end
end

local function colorGetter(db, key)
    return function()
        local c = db.profile[key]
        return c[1], c[2], c[3], c[4]
    end
end

local function colorSetter(db, key)
    return function(_, r, g, b, a)
        local c = db.profile[key]
        c[1], c[2], c[3], c[4] = r, g, b, a
        if ns.Display then
            ns.Display.refresh()
        end
    end
end

-- Setter that persists, then refreshes the display (re-applies + re-renders the preview if active).
-- All Display-node settings use this so every change (not just width) is instant.
local function setterR(db, key)
    return function(_, value)
        db.profile[key] = value
        if ns.Display then
            ns.Display.refresh()
        end
    end
end

-- Per-entry ability config (db.profile.abilities[id] = { enabled, offset }; default enabled / 0).
local function abilityGet(db, id, field, default)
    return function()
        local a = db.profile.abilities[id]
        if a and a[field] ~= nil then
            return a[field]
        end
        return default
    end
end

local function abilitySet(db, id, field)
    return function(_, value)
        db.profile.abilities[id] = db.profile.abilities[id] or {}
        db.profile.abilities[id][field] = value
    end
end

-- Per-raid / per-encounter show-gating config (db.profile.raids[raidId] = { enabled, encounters }).
-- Absent = ON, so a fresh profile shows everything without pre-seeding.
local function raidEnabledGet(db, raidId)
    return function()
        local r = db.profile.raids[raidId]
        return not r or r.enabled ~= false
    end
end

local function raidEnabledSet(db, raidId)
    return function(_, value)
        db.profile.raids[raidId] = db.profile.raids[raidId] or {}
        db.profile.raids[raidId].enabled = value
    end
end

local function encounterGet(db, raidId, encId)
    return function()
        local r = db.profile.raids[raidId]
        return not (r and r.encounters and r.encounters[encId] == false)
    end
end

local function encounterSet(db, raidId, encId)
    return function(_, value)
        local r = db.profile.raids[raidId] or {}
        db.profile.raids[raidId] = r
        r.encounters = r.encounters or {}
        r.encounters[encId] = value
    end
end

-- Inline spell/item icon for an ability entry's label.
local function abilityIcon(entry)
    local tex = (entry.idType == "spell") and GetSpellTexture(entry.id) or GetItemIcon(entry.id)
    return ns.iconMarkup(tex, 16)
end

-- Prettier labels for the curated ability metadata (kind / category), used in the composed fallback hint.
local KIND_LABEL = {
    trinket = "On-use trinket",
    spell = "Spell",
    consumable = "Consumable",
    engineering = "Engineering",
}
local CATEGORY_LABEL = {
    attackpower = "attack power",
    haste = "haste",
    damage = "damage",
    crit = "crit",
    armor = "armor",
}

-- Descriptive hint under an ability: the in-game spell tooltip text where we have it (spells), otherwise a
-- line composed from the curated table data (kind · category · buff · cooldown). Best-effort, edge (no spec).
local function abilityDesc(entry)
    if entry.idType == "spell" and GetSpellDescription then
        local d = GetSpellDescription(entry.id)
        if d and d ~= "" then
            return d
        end
    end
    local parts = {}
    parts[#parts + 1] = KIND_LABEL[entry.kind] or entry.kind
    if entry.category then
        parts[#parts + 1] = CATEGORY_LABEL[entry.category] or entry.category
    end
    if entry.duration then
        parts[#parts + 1] = entry.duration .. "s buff"
    end
    if entry.cooldown then
        parts[#parts + 1] = entry.cooldown .. "s cooldown"
    end
    return table.concat(parts, "  ·  ")
end

local function buildGeneral(db)
    return {
        type = "group",
        name = "General",
        order = 1,
        icon = ICON .. "INV_Misc_Gear_01",
        args = {
            about = {
                type = "description",
                name = "Time-to-kill and optimal cooldown timing — a right-anchored TTK bar plus utility"
                    .. " bars that show when to fire each cooldown so its buff covers the kill.",
                fontSize = "medium",
                order = 1,
            },
            enabled = {
                type = "toggle",
                name = "Enable addon",
                desc = "Master switch. When off, nothing is shown or recorded.",
                order = 2,
                get = getter(db, "enabled"),
                set = setter(db, "enabled"),
            },
        },
    }
end

local function buildBehavior(db)
    return {
        type = "group",
        name = "Behavior",
        order = 2,
        icon = ICON .. "INV_Misc_Spyglass_02",
        args = {
            header = { type = "header", name = "When to show", order = 1 },
            inCombatOnly = {
                type = "toggle",
                name = "In combat only",
                desc = "Only show the bars while you are in combat.",
                order = 2,
                get = getter(db, "inCombatOnly"),
                set = setter(db, "inCombatOnly"),
            },
            hideOnTargetDead = {
                type = "toggle",
                name = "Hide when target dies",
                desc = "Hide the bars the moment the target dies, instead of lingering on the corpse.",
                order = 3,
                get = getter(db, "hideOnTargetDead"),
                set = setter(db, "hideOnTargetDead"),
            },
            requireHostile = {
                type = "toggle",
                name = "Hostile targets only",
                desc = "Only show on targets you can attack (skip friendly/neutral units).",
                order = 4,
                get = getter(db, "requireHostile"),
                set = setter(db, "requireHostile"),
            },
            showAnyTarget = {
                type = "toggle",
                name = "Show on any target (testing)",
                desc = "Bypass raid/encounter gating and show on any chosen target.",
                order = 5,
                get = getter(db, "showAnyTarget"),
                set = setter(db, "showAnyTarget"),
            },
            showUtilityOutsideRaid = {
                type = "toggle",
                name = "Show utility bars outside raids",
                desc = "Show the utility cooldown bars on non-raid-boss targets too. When off, only the"
                    .. " main time-to-kill bar shows outside a raid encounter (utility bars are usually"
                    .. " noise on a random mob). A raid boss = an active encounter or a world boss.",
                order = 5.5,
                get = getter(db, "showUtilityOutsideRaid"),
                set = setter(db, "showUtilityOutsideRaid"),
            },
            minTTK = {
                type = "range",
                name = "Minimum time-to-kill",
                desc = "Hide the bars until the estimate is at least this many seconds (kills trash flicker).",
                order = 6,
                min = 0,
                max = 120,
                step = 1,
                get = getter(db, "minTTK"),
                set = setter(db, "minTTK"),
            },
            minConfidenceToShow = {
                type = "range",
                name = "Minimum confidence",
                desc = "Hide the estimate until it is at least this confident.",
                order = 7,
                min = 0,
                max = 1,
                step = 0.05,
                isPercent = true,
                get = getter(db, "minConfidenceToShow"),
                set = setter(db, "minConfidenceToShow"),
            },
        },
    }
end

local function buildSkin(db)
    local pendingSkinName = "" -- transient: name typed into the save-as-skin box (not persisted)
    return {
        type = "group",
        name = "Skin",
        order = 4,
        icon = ICON .. "INV_Misc_Cape_18",
        args = {
            skin = {
                type = "select",
                name = "Skin",
                desc = "Choose a bar skin (a preset applied onto the settings below). Save your own with"
                    .. " the box below, or add one in code with BadgerTTK:RegisterSkin — see"
                    .. " src/skin/skin.lua.",
                order = 1,
                values = function()
                    return ns.Skin.ListSkins()
                end,
                get = getter(db, "skin"),
                set = function(_, v)
                    db.profile.skin = v
                    ns.Skin.apply(db.profile, v)
                    if ns.Display then
                        ns.Display.refresh()
                    end
                end,
            },
            newSkinName = {
                type = "input",
                name = "New skin name",
                desc = "Type a name, then press Save to capture the current Skin + Display settings as a"
                    .. " reusable skin.",
                order = 2,
                get = function()
                    return pendingSkinName
                end,
                set = function(_, v)
                    pendingSkinName = v
                end,
            },
            saveSkin = {
                type = "execute",
                name = "Save current as skin",
                desc = "Save all current Skin and Display settings as a new skin under the name above. It"
                    .. " appears in the picker and persists across /reload.",
                order = 3,
                disabled = function()
                    return strtrim(pendingSkinName or "") == ""
                end,
                func = function()
                    local nm = strtrim(pendingSkinName or "")
                    if nm ~= "" then
                        local skin = ns.Skin.saveCurrent(db.profile, nm)
                        db.global.skins = db.global.skins or {}
                        db.global.skins[nm] = skin
                        db.profile.skin = nm
                        pendingSkinName = ""
                    end
                end,
            },
            mediaHeader = { type = "header", name = "Media", order = 4 },
            -- The LSM30_* dialogControls (from AceGUI-3.0-SharedMediaWidgets, embedded via the .toc) render
            -- a visual preview per entry instead of a plain name list. If the widget is ever missing,
            -- AceConfigDialog falls back to an ordinary dropdown, so the option still works.
            statusbar = {
                type = "select",
                dialogControl = "LSM30_Statusbar",
                name = "Bar texture",
                desc = "The status-bar texture used for all bars (each option previews in the dropdown).",
                order = 5,
                values = function()
                    return LSM:HashTable("statusbar")
                end,
                get = getter(db, "statusbar"),
                set = setterR(db, "statusbar"),
            },
            font = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = "Font",
                desc = "The font for all bar text (each option previews in its own face).",
                order = 6,
                values = function()
                    return LSM:HashTable("font")
                end,
                get = getter(db, "font"),
                set = setterR(db, "font"),
            },
            border = {
                type = "select",
                dialogControl = "LSM30_Border",
                name = "Border",
                desc = "An optional border drawn around the bar container.",
                order = 7,
                values = function()
                    return LSM:HashTable("border")
                end,
                get = getter(db, "border"),
                set = setterR(db, "border"),
            },
            sizeHeader = { type = "header", name = "Font sizes", order = 10 },
            fontSizeMain = {
                type = "range",
                name = "Main TTK size",
                desc = "Font size of the time-to-kill text on the main bar.",
                order = 11,
                min = 8,
                max = 32,
                step = 1,
                get = getter(db, "fontSizeMain"),
                set = setterR(db, "fontSizeMain"),
            },
            fontSizeOther = {
                type = "range",
                name = "Other bars size",
                desc = "Font size of the text on the utility bars.",
                order = 12,
                min = 8,
                max = 24,
                step = 1,
                get = getter(db, "fontSizeOther"),
                set = setterR(db, "fontSizeOther"),
            },
            colorHeader = { type = "header", name = "State colours", order = 20 },
            colorTarget = {
                type = "color",
                name = "Target (TTK)",
                desc = "Colour of the main time-to-kill bar.",
                order = 21,
                hasAlpha = true,
                get = colorGetter(db, "colorTarget"),
                set = colorSetter(db, "colorTarget"),
            },
            colorUtility = {
                type = "color",
                name = "Utility",
                desc = "Fallback colour for a utility bar with no specific state colour.",
                order = 22,
                hasAlpha = true,
                get = colorGetter(db, "colorUtility"),
                set = colorSetter(db, "colorUtility"),
            },
            colorWaiting = {
                type = "color",
                name = "Waiting (fire moment ahead)",
                desc = "Colour of a utility bar before its optimal fire moment.",
                order = 23,
                hasAlpha = true,
                get = colorGetter(db, "colorWaiting"),
                set = colorSetter(db, "colorWaiting"),
            },
            colorReady = {
                type = "color",
                name = "Ready (fire now)",
                desc = "Colour when a utility is ready to fire (its optimal moment has arrived).",
                order = 24,
                hasAlpha = true,
                get = colorGetter(db, "colorReady"),
                set = colorSetter(db, "colorReady"),
            },
            colorUsed = {
                type = "color",
                name = "Used (draining)",
                desc = "Colour once a utility has been fired and its buff is draining.",
                order = 25,
                hasAlpha = true,
                get = colorGetter(db, "colorUsed"),
                set = colorSetter(db, "colorUsed"),
            },
        },
    }
end

local function buildDisplay(db)
    return {
        type = "group",
        name = "Display",
        order = 5,
        icon = ICON .. "INV_Misc_PocketWatch_01",
        args = {
            layoutHeader = { type = "header", name = "Layout", order = 1 },
            anchorPoint = {
                type = "select",
                name = "Screen anchor",
                desc = "Which screen point the bar container is pinned to.",
                order = 2,
                values = ANCHORS,
                get = getter(db, "anchorPoint"),
                set = setterR(db, "anchorPoint"),
            },
            locked = {
                type = "toggle",
                name = "Lock position",
                desc = "Lock the bars in place; unlock to drag them with the mouse.",
                order = 3,
                get = getter(db, "locked"),
                set = setterR(db, "locked"),
            },
            posX = {
                type = "range",
                name = "Horizontal offset",
                desc = "Fine-tune the horizontal position from the anchor.",
                order = 4,
                min = -800,
                max = 800,
                step = 1,
                get = getter(db, "posX"),
                set = setterR(db, "posX"),
            },
            posY = {
                type = "range",
                name = "Vertical offset",
                desc = "Fine-tune the vertical position from the anchor.",
                order = 5,
                min = -800,
                max = 800,
                step = 1,
                get = getter(db, "posY"),
                set = setterR(db, "posY"),
            },
            scale = {
                type = "range",
                name = "Scale",
                desc = "Overall size of the bar display.",
                order = 6,
                min = 0.5,
                max = 2.0,
                step = 0.05,
                get = getter(db, "scale"),
                set = setterR(db, "scale"),
            },
            growthDirection = {
                type = "select",
                name = "Growth direction",
                desc = "Which way the utility bars stack from the target bar.",
                order = 7,
                values = GROWTH,
                get = getter(db, "growthDirection"),
                set = setterR(db, "growthDirection"),
            },
            barWidth = {
                type = "range",
                name = "Bar width",
                desc = "Width of every bar, in pixels.",
                order = 8,
                min = 60,
                max = 400,
                step = 1,
                get = getter(db, "barWidth"),
                set = setterR(db, "barWidth"),
            },
            barHeight = {
                type = "range",
                name = "Bar height",
                desc = "Height of each bar, in pixels.",
                order = 9,
                min = 8,
                max = 40,
                step = 1,
                get = getter(db, "barHeight"),
                set = setterR(db, "barHeight"),
            },
            barSpacing = {
                type = "range",
                name = "Bar spacing",
                desc = "Vertical gap between stacked bars, in pixels.",
                order = 10,
                min = 0,
                max = 20,
                step = 1,
                get = getter(db, "barSpacing"),
                set = setterR(db, "barSpacing"),
            },
            maxBars = {
                type = "range",
                name = "Max utility bars",
                desc = "The most utility bars to show at once.",
                order = 11,
                min = 1,
                max = 20,
                step = 1,
                get = getter(db, "maxBars"),
                set = setterR(db, "maxBars"),
            },
            opacity = {
                type = "range",
                name = "Opacity",
                desc = "Overall transparency of the display.",
                order = 12,
                min = 0,
                max = 1,
                step = 0.05,
                isPercent = true,
                get = getter(db, "opacity"),
                set = setterR(db, "opacity"),
            },
            strata = {
                type = "select",
                name = "Frame strata",
                desc = "Which UI layer the display draws on (higher sits in front of more frames).",
                order = 13,
                values = STRATA,
                get = getter(db, "strata"),
                set = setterR(db, "strata"),
            },
            resetPosition = {
                type = "execute",
                name = "Reset position",
                desc = "Move the display back to the default screen position.",
                order = 14,
                func = function()
                    if ns.Display then
                        ns.Display.resetPosition()
                    end
                end,
            },
            readoutHeader = { type = "header", name = "Readout", order = 20 },
            showBarNames = {
                type = "toggle",
                name = "Show names",
                desc = "Show each utility's name on its bar.",
                order = 21,
                get = getter(db, "showBarNames"),
                set = setterR(db, "showBarNames"),
            },
            showTimers = {
                type = "toggle",
                name = "Utility bar timers",
                desc = "Show a countdown on each utility bar. Off by default — the bar's fill already shows"
                    .. " how much of the buff remains.",
                order = 22,
                get = getter(db, "showTimers"),
                set = setterR(db, "showTimers"),
            },
            showIcons = {
                type = "toggle",
                name = "Show icons",
                desc = "Show each ability/item icon on its bar.",
                order = 23,
                get = getter(db, "showIcons"),
                set = setterR(db, "showIcons"),
            },
            timeFormat = {
                type = "select",
                name = "Time format",
                desc = "How the time-to-kill reads: m:ss or raw seconds.",
                order = 24,
                values = TIMEFMT,
                get = getter(db, "timeFormat"),
                set = setterR(db, "timeFormat"),
            },
            showTrendBand = {
                type = "toggle",
                name = "Show trend band",
                desc = "A translucent band around the estimate showing its historical spread (once history exists).",
                order = 25,
                get = getter(db, "showTrendBand"),
                set = setterR(db, "showTrendBand"),
            },
            showConfidence = {
                type = "toggle",
                name = "Show confidence",
                desc = "Show how confident the current estimate is.",
                order = 26,
                get = getter(db, "showConfidence"),
                set = setterR(db, "showConfidence"),
            },
        },
    }
end

local function buildEstimator(db)
    return {
        type = "group",
        name = "Estimator",
        order = 6,
        icon = ICON .. "INV_Misc_PocketWatch_02",
        args = {
            reactivity = {
                type = "range",
                name = "Reactivity vs. Stability",
                desc = "Lower = a smoother, steadier estimate; higher = snappier but noisier.",
                order = 1,
                min = 0,
                max = 1,
                step = 0.05,
                isPercent = true,
                get = getter(db, "reactivity"),
                set = setter(db, "reactivity"),
            },
            leadTime = {
                type = "range",
                name = "Lead time",
                desc = "Nudge every pop-line earlier by this many seconds to cover GCD + latency.",
                order = 2,
                min = 0,
                max = 5,
                step = 0.1,
                get = getter(db, "leadTime"),
                set = setter(db, "leadTime"),
            },
            executeHeader = { type = "header", name = "Execute phase", order = 10 },
            executeThreshold = {
                type = "range",
                name = "Execute threshold",
                desc = "Below this target health, shorten the estimate (raids dump burst).",
                order = 11,
                min = 0,
                max = 0.5,
                step = 0.01,
                isPercent = true,
                get = getter(db, "executeThreshold"),
                set = setter(db, "executeThreshold"),
            },
            executeModifier = {
                type = "range",
                name = "Execute modifier",
                desc = "How much to shorten the estimate in execute range.",
                order = 12,
                min = 1,
                max = 2,
                step = 0.05,
                get = getter(db, "executeModifier"),
                set = setter(db, "executeModifier"),
            },
            historyHeader = { type = "header", name = "Kill history", order = 20 },
            recordHistory = {
                type = "toggle",
                name = "Record kills",
                desc = "Remember how fast you kill each creature, organised by your level, to steady the"
                    .. " estimate over time.",
                order = 21,
                get = getter(db, "recordHistory"),
                set = setter(db, "recordHistory"),
            },
            useHistory = {
                type = "toggle",
                name = "Use history for the estimate",
                desc = "Blend the recorded per-level kill rate in as a stable prior — fewer TTK spikes, and"
                    .. " an estimate that appears sooner. Off = pure live estimate.",
                order = 22,
                get = getter(db, "useHistory"),
                set = setter(db, "useHistory"),
            },
            clearHistory = {
                type = "execute",
                name = "Clear history",
                desc = "Wipe all recorded kill data (account-wide).",
                order = 23,
                confirm = true,
                func = function()
                    if ns.addon and ns.addon.db and ns.addon.db.global then
                        ns.addon.db.global.history = {}
                    end
                end,
            },
        },
    }
end

-- Simulation node — drives the display preview (WO-012): a frozen static preview + dynamic playback.
local function buildSimulation(db)
    return {
        type = "group",
        name = "Simulation",
        order = 8,
        icon = ICON .. "INV_Gizmo_02",
        args = {
            about = {
                type = "description",
                name = "Preview the bars with no live target. One setup: show it frozen to style the"
                    .. " display, then press Play to animate that same setup on a loop.",
                order = 1,
            },
            static = {
                type = "toggle",
                name = "Show preview",
                desc = "Show the preview bars — a frozen warrior setup reading 0:25. Style the display"
                    .. " against it; press Play to animate the same bars.",
                order = 2,
                get = getter(db, "simStatic"),
                set = function(_, v)
                    db.profile.simStatic = v
                    if not v then
                        db.profile.simPlaying = false -- hiding the preview also stops playback
                    end
                    if ns.Display then
                        ns.Display.showPreview(v)
                    end
                end,
            },
            play = {
                type = "execute",
                -- A start/stop button that flips its label with the state.
                name = function()
                    return db.profile.simPlaying and "Stop" or "Play"
                end,
                desc = "Animate the shown preview on a loop; Stop returns to the frozen 0:25 still (the"
                    .. " same bars either way).",
                order = 3,
                disabled = function()
                    return not db.profile.simStatic -- only meaningful once the preview is shown
                end,
                func = function()
                    db.profile.simPlaying = not db.profile.simPlaying
                    if ns.Display then
                        ns.Display.playSim(db.profile.simPlaying, db.profile.simSpeed)
                    end
                end,
            },
            speed = {
                type = "range",
                name = "Playback speed",
                desc = "How fast the dynamic simulation plays back the scripted fight.",
                order = 4,
                min = 0.25,
                max = 4,
                step = 0.25,
                get = getter(db, "simSpeed"),
                set = setter(db, "simSpeed"),
            },
        },
    }
end

-- Raids node — the show-gating surface (WO-022): one sub-node per raid (ns.RaidTable), each a master
-- enable toggle + an encounter checkbox list (default on; encounters greyed when the raid master is off).
-- Live gating enforcement (zone/boss detection → show/hide) and boss icons are later WOs.
local function buildRaids(db)
    local raidArgs = {}
    for i = 1, #ns.RaidTable do
        local raid = ns.RaidTable[i]
        local masterOff = function()
            return not raidEnabledGet(db, raid.id)()
        end
        local args = {
            master = {
                type = "toggle",
                name = "Enable " .. raid.name,
                desc = "Show the bars on encounters in " .. raid.name .. ".",
                order = 1,
                get = raidEnabledGet(db, raid.id),
                set = raidEnabledSet(db, raid.id),
            },
            header = { type = "header", name = "Encounters", order = 2 },
        }
        for j = 1, #raid.encounters do
            local enc = raid.encounters[j]
            args["e" .. enc.id] = {
                type = "toggle",
                name = enc.name,
                desc = "Show the bars on the " .. enc.name .. " encounter.",
                order = 2 + j,
                width = "full",
                disabled = masterOff,
                get = encounterGet(db, raid.id, enc.id),
                set = encounterSet(db, raid.id, enc.id),
            }
        end
        raidArgs["r" .. raid.id] = {
            type = "group",
            name = raid.name,
            order = i,
            icon = ICON .. "INV_Misc_Head_Dragon_01",
            args = args,
        }
    end
    return {
        type = "group",
        name = "Raids",
        order = 3,
        icon = ICON .. "INV_Misc_Head_Dragon_01",
        args = raidArgs,
    }
end

-- Abilities node — the full static warrior list (ns.AbilityTable); a per-entry enable/disable + offset,
-- dimmed when the character can't currently use it (WO-014). The live tracking + display is WO-015.
local function buildAbilities(db)
    -- One class node per class; today just Warrior. The tracked list is nested under it so more classes
    -- can slot in beside it later.
    local warrior = {}
    for i = 1, #ns.AbilityTable do
        local e = ns.AbilityTable[i]
        local base = i * 10
        -- A thin full-width rule between entries (not before the first) so each ability reads as its own block.
        if i > 1 then
            warrior["sep" .. e.id] = { type = "header", name = "", order = base }
        end
        warrior["a" .. e.id] = {
            type = "toggle",
            -- The label DIMS (greyed + tagged) while the ability isn't currently usable, but the control
            -- stays fully editable — availability gates the live bar, not your ability to configure it.
            name = function()
                local label = abilityIcon(e) .. " " .. e.name
                if not ns.Abilities.available(e, ns.Abilities.scanCharacter()) then
                    return "|cff808080" .. label .. "|r  |cff808080(unavailable)|r"
                end
                return label
            end,
            desc = "Track "
                .. e.name
                .. " and show its timing bar. Editable even while unavailable.",
            order = base + 1,
            width = "full",
            get = abilityGet(db, e.id, "enabled", true),
            set = abilitySet(db, e.id, "enabled"),
        }
        warrior["d" .. e.id] = {
            type = "description",
            name = abilityDesc(e),
            fontSize = "small",
            order = base + 2,
        }
        warrior["o" .. e.id] = {
            type = "range",
            name = "offset (s)",
            desc = "Fire earlier (+) or later (−) than the exact fit.",
            order = base + 3,
            min = -30,
            max = 60,
            step = 1,
            get = abilityGet(db, e.id, "offset", 0),
            set = abilitySet(db, e.id, "offset"),
        }
    end
    return {
        type = "group",
        name = "Abilities",
        order = 7,
        icon = ICON .. "Ability_Warrior_Trauma",
        args = {
            warrior = {
                type = "group",
                name = "Warrior",
                order = 1,
                icon = ICON .. "Ability_Warrior_Trauma",
                args = warrior,
            },
        },
    }
end

-- Assemble the tree and register it. Left-nav order (agreed): General, Behavior, Raids, Skin, Display,
-- Estimator, Abilities, Simulation, Profiles.
function ns.buildOptions(addon)
    local db = addon.db
    local options = {
        type = "group",
        name = "Badger TTK",
        args = {
            general = buildGeneral(db),
            behavior = buildBehavior(db),
            raids = buildRaids(db),
            skin = buildSkin(db),
            display = buildDisplay(db),
            estimator = buildEstimator(db),
            abilities = buildAbilities(db),
            simulation = buildSimulation(db),
        },
    }

    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
    options.args.profiles.order = 9

    -- Single-source the version from the .toc (`## Version`), so what the window shows can never drift from
    -- the packaged build. Surfacing it lets a tester confirm they're on the latest .release every time.
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = (getMeta and getMeta(ADDON_NAME, "Version")) or "?"

    local BCUI = LibStub("BadgerConfigUI-1.0")
    BCUI:Register(ADDON_NAME, options, {
        title = "Badger TTK  v" .. version,
        banner = {
            title = "Badger TTK",
            subtitle = "Time-to-kill and optimal cooldown timing  —  v" .. version,
        },
        blizzard = true,
        status = "Reopen with /bttk or /badgerttk",
    })
    -- Closing the config window shuts down any preview and hands control back to the live driver (WO-030).
    BCUI:SetCloseCallback(ADDON_NAME, function()
        local p = db.profile
        if p.simStatic or p.simPlaying then
            p.simStatic, p.simPlaying = false, false
            if ns.Display then
                ns.Display.showPreview(false)
            end
        end
    end)
end
