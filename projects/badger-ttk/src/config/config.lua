local ADDON_NAME, ns = ...

-- The badger-ttk options tree (WO-009). This is the FULL navigable window: every setting exists,
-- reads/writes db.profile, and persists across /reload — but it drives NO in-game behavior yet; each
-- functionality work order reads these values when it lands. The data-driven nodes (Raids, Abilities,
-- Simulation) are placeholders here and are populated by their own work orders. Registered/opened through
-- the shared BadgerConfigUI library (no ad-hoc AceConfig). Kept declarative so the schema is easy to grow.
--
-- Node icons use AceConfig's native `icon` field (a texture path) — no BadgerConfigUI change. Per-entry
-- spell/item label-icons (a `|T...|t` helper) arrive with the ability/raid work orders that need them.

local ICON = "Interface\\ICONS\\"

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
-- Only the shipped default for now; the RegisterSkin registry (skin engine WO) repopulates this list.
local SKINS = { Badger = "Badger (default)" }

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
    end
end

-- A data-driven node not built here — its options come with the named work order.
local function placeholder(name, order, icon, wo)
    return {
        type = "group",
        name = name,
        order = order,
        icon = icon,
        args = {
            soon = {
                type = "description",
                name = name .. " options arrive with " .. wo .. ".",
                order = 1,
            },
        },
    }
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
                name = "Time-to-kill and optimal cooldown timing. On-screen bars arrive in later updates.",
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
                order = 2,
                get = getter(db, "inCombatOnly"),
                set = setter(db, "inCombatOnly"),
            },
            hideOnTargetDead = {
                type = "toggle",
                name = "Hide when target dies",
                order = 3,
                get = getter(db, "hideOnTargetDead"),
                set = setter(db, "hideOnTargetDead"),
            },
            requireHostile = {
                type = "toggle",
                name = "Hostile targets only",
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
    return {
        type = "group",
        name = "Skin",
        order = 4,
        icon = ICON .. "INV_Misc_Cape_18",
        args = {
            skin = {
                type = "select",
                name = "Skin",
                desc = "Choose a bar skin. Add your own with the RegisterSkin API (arrives with the skin engine).",
                order = 1,
                values = SKINS,
                get = getter(db, "skin"),
                set = setter(db, "skin"),
            },
            mediaNote = {
                type = "description",
                name = "Font, texture and border pickers arrive with the skin engine (they use LibSharedMedia).",
                order = 2,
            },
            sizeHeader = { type = "header", name = "Font sizes", order = 10 },
            fontSizeMain = {
                type = "range",
                name = "Main TTK size",
                order = 11,
                min = 8,
                max = 32,
                step = 1,
                get = getter(db, "fontSizeMain"),
                set = setter(db, "fontSizeMain"),
            },
            fontSizeOther = {
                type = "range",
                name = "Other bars size",
                order = 12,
                min = 8,
                max = 24,
                step = 1,
                get = getter(db, "fontSizeOther"),
                set = setter(db, "fontSizeOther"),
            },
            colorHeader = { type = "header", name = "State colours", order = 20 },
            colorTarget = {
                type = "color",
                name = "Target (TTK)",
                order = 21,
                hasAlpha = true,
                get = colorGetter(db, "colorTarget"),
                set = colorSetter(db, "colorTarget"),
            },
            colorUtility = {
                type = "color",
                name = "Utility",
                order = 22,
                hasAlpha = true,
                get = colorGetter(db, "colorUtility"),
                set = colorSetter(db, "colorUtility"),
            },
            colorPlanned = {
                type = "color",
                name = "Planned (pop-line)",
                order = 23,
                hasAlpha = true,
                get = colorGetter(db, "colorPlanned"),
                set = colorSetter(db, "colorPlanned"),
            },
            colorActive = {
                type = "color",
                name = "Active (draining)",
                order = 24,
                hasAlpha = true,
                get = colorGetter(db, "colorActive"),
                set = colorSetter(db, "colorActive"),
            },
            colorOverkill = {
                type = "color",
                name = "Over-covering",
                order = 25,
                hasAlpha = true,
                get = colorGetter(db, "colorOverkill"),
                set = colorSetter(db, "colorOverkill"),
            },
            colorShortfall = {
                type = "color",
                name = "Falling short",
                order = 26,
                hasAlpha = true,
                get = colorGetter(db, "colorShortfall"),
                set = colorSetter(db, "colorShortfall"),
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
                order = 2,
                values = ANCHORS,
                get = getter(db, "anchorPoint"),
                set = setter(db, "anchorPoint"),
            },
            locked = {
                type = "toggle",
                name = "Lock position",
                order = 3,
                get = getter(db, "locked"),
                set = setter(db, "locked"),
            },
            posX = {
                type = "range",
                name = "Horizontal offset",
                order = 4,
                min = -800,
                max = 800,
                step = 1,
                get = getter(db, "posX"),
                set = setter(db, "posX"),
            },
            posY = {
                type = "range",
                name = "Vertical offset",
                order = 5,
                min = -800,
                max = 800,
                step = 1,
                get = getter(db, "posY"),
                set = setter(db, "posY"),
            },
            scale = {
                type = "range",
                name = "Scale",
                order = 6,
                min = 0.5,
                max = 2.0,
                step = 0.05,
                get = getter(db, "scale"),
                set = setter(db, "scale"),
            },
            growthDirection = {
                type = "select",
                name = "Growth direction",
                desc = "Which way the utility bars stack from the target bar.",
                order = 7,
                values = GROWTH,
                get = getter(db, "growthDirection"),
                set = setter(db, "growthDirection"),
            },
            barWidth = {
                type = "range",
                name = "Bar width",
                order = 8,
                min = 60,
                max = 400,
                step = 1,
                get = getter(db, "barWidth"),
                set = setter(db, "barWidth"),
            },
            barHeight = {
                type = "range",
                name = "Bar height",
                order = 9,
                min = 8,
                max = 40,
                step = 1,
                get = getter(db, "barHeight"),
                set = setter(db, "barHeight"),
            },
            barSpacing = {
                type = "range",
                name = "Bar spacing",
                order = 10,
                min = 0,
                max = 20,
                step = 1,
                get = getter(db, "barSpacing"),
                set = setter(db, "barSpacing"),
            },
            maxBars = {
                type = "range",
                name = "Max utility bars",
                order = 11,
                min = 1,
                max = 20,
                step = 1,
                get = getter(db, "maxBars"),
                set = setter(db, "maxBars"),
            },
            opacity = {
                type = "range",
                name = "Opacity",
                order = 12,
                min = 0,
                max = 1,
                step = 0.05,
                isPercent = true,
                get = getter(db, "opacity"),
                set = setter(db, "opacity"),
            },
            strata = {
                type = "select",
                name = "Frame strata",
                order = 13,
                values = STRATA,
                get = getter(db, "strata"),
                set = setter(db, "strata"),
            },
            readoutHeader = { type = "header", name = "Readout", order = 20 },
            showBarNames = {
                type = "toggle",
                name = "Show names",
                order = 21,
                get = getter(db, "showBarNames"),
                set = setter(db, "showBarNames"),
            },
            showTimers = {
                type = "toggle",
                name = "Show timers",
                order = 22,
                get = getter(db, "showTimers"),
                set = setter(db, "showTimers"),
            },
            showIcons = {
                type = "toggle",
                name = "Show icons",
                order = 23,
                get = getter(db, "showIcons"),
                set = setter(db, "showIcons"),
            },
            timeFormat = {
                type = "select",
                name = "Time format",
                order = 24,
                values = TIMEFMT,
                get = getter(db, "timeFormat"),
                set = setter(db, "timeFormat"),
            },
            showTrendBand = {
                type = "toggle",
                name = "Show trend band",
                desc = "A translucent band around the estimate showing its historical spread (once history exists).",
                order = 25,
                get = getter(db, "showTrendBand"),
                set = setter(db, "showTrendBand"),
            },
            showConfidence = {
                type = "toggle",
                name = "Show confidence",
                order = 26,
                get = getter(db, "showConfidence"),
                set = setter(db, "showConfidence"),
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
            raids = placeholder(
                "Raids",
                3,
                ICON .. "INV_Misc_Head_Dragon_01",
                "the show-gating work order"
            ),
            skin = buildSkin(db),
            display = buildDisplay(db),
            estimator = buildEstimator(db),
            abilities = placeholder(
                "Abilities",
                7,
                ICON .. "Ability_Warrior_Trauma",
                "the ability-model work order"
            ),
            simulation = placeholder(
                "Simulation",
                8,
                ICON .. "INV_Gizmo_02",
                "the simulation work order"
            ),
        },
    }

    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
    options.args.profiles.order = 9

    LibStub("BadgerConfigUI-1.0"):Register(ADDON_NAME, options, {
        title = "Badger TTK",
        banner = { title = "Badger TTK", subtitle = "Time-to-kill and optimal cooldown timing" },
        blizzard = true,
        status = "Reopen with /bttk or /badgerttk",
    })
end
