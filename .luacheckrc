-- Luacheck config for the badger-addons monorepo.
-- Analysed code runs in the WoW Classic Lua 5.1 sandbox. The base lists below describe the
-- FLAVOR-NEUTRAL sandbox (API present on every Classic flavor); each project selects its flavor's
-- extra API (e.g. TBC arena) and its own SavedVariables via a files[...] overlay at the bottom — so
-- a Vanilla / Classic-Era addon that references a TBC-only API fails the lint (W113) instead of
-- passing silently. The load-bearing rule this enforces: addon code must NOT leak into _G (named
-- exports only — everything hangs off the private `ns` table). A stray global assignment fails the lint.

std = "lua51"
max_line_length = 120
codes = true

-- Ace3 methods and event callbacks frequently ignore `self`; an unused `self` is not a smell here.
ignore = { "212/self" }

exclude_files = {
    "**/Libs/**", -- vendored libraries (fetched via .pkgmeta externals, never linted)
    "**/.release/**", -- packager build output
    "node_modules/**",
    ".nx/**",
}

-- WoW API surface the addons may READ. Not exhaustive — extend as new API is used.
-- Mirrored into `.luarc.json` (diagnostics.globals) for the editor LSP, which keeps a FLAT superset
-- of every flavor's globals (the per-project flavor scoping below is a luacheck-only correctness gate).
read_globals = {
    -- Core / frames / timers
    "CreateFrame",
    "UIParent",
    "GetTime",
    "C_Timer",
    "hooksecurefunc",
    "InCombatLockdown",
    "GetLocale",
    "IsInInstance",
    "GetInstanceInfo",
    "PlaySound",
    "PlaySoundFile",
    -- WoW global aliases of stdlib / helpers
    "wipe",
    "tinsert",
    "tremove",
    "tContains",
    "strsplit",
    "strjoin",
    "strtrim",
    "strmatch",
    "format",
    "max",
    "min",
    "abs",
    "floor",
    "ceil",
    "bit",
    -- Units / spells / auras
    "UnitExists",
    "UnitName",
    "UnitClass",
    "UnitGUID",
    "UnitHealth",
    "UnitHealthMax",
    "UnitIsPlayer",
    "UnitIsUnit",
    "UnitAura",
    "GetSpellInfo",
    "GetSpellCooldown",
    "GetSpellTexture",
    -- Libraries
    "LibStub",
    -- Flavor constants (present on every client; only WOW_PROJECT_ID's value differs per flavor)
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    -- Options / interface panels (read by the BadgerConfigUI glue)
    "Settings",
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "InterfaceOptionsFrame_OpenToCategory",
    "HideUIPanel",
}

-- SavedVariables (the only globals an addon may WRITE) are addon-specific, so they live in each
-- project's files[...] overlay below — never in a monorepo-wide table where one project could write
-- another addon's saved data.

-- Spec files speak the Busted DSL (describe / it / before_each / assert / ...).
files["**/*_spec.lua"] = {
    std = "+busted",
}

-- Per-project flavor overlays. The arena API exists only on TBC (2.5.x), not Classic Era/Vanilla, so
-- it is NOT in the flavor-neutral table above — a Vanilla / Classic-Era addon referencing it fails the
-- lint (W113) instead of passing silently. It is granted only to the projects that legitimately use it:
-- the badger-arena addon (a TBC addon), and the shared wow-mock (which simulates the full cross-flavor
-- client surface, so its spec can assert the vanilla flavor omits these). BadgerArenaDB (SavedVariables)
-- is scoped to its owning addon so no other project can write it.
local arena_api = {
    "IsActiveBattlefieldArena",
    "GetNumArenaOpponents",
    "GetArenaOpponentSpec",
    "GetBattlefieldStatus",
}

files["projects/badger-arena/**"] = {
    read_globals = arena_api,
    globals = { "BadgerArenaDB" },
}

files["tools/wow-mock/**"] = {
    read_globals = arena_api,
}

-- badger-ttk is a Vanilla / Classic-Era addon (no arena API), so it inherits the flavor-neutral base
-- surface above plus its own extra reads (the ability-scan / icon APIs the model uses). It scopes in its
-- own SavedVariables. A TBC-only API referenced here would fail the lint (W113), keeping it honest.
files["projects/badger-ttk/**"] = {
    read_globals = {
        "IsPlayerSpell",
        "GetInventoryItemID",
        "GetItemCount",
        "GetItemIcon",
        "UnitCanAttack",
        "UnitIsDeadOrGhost",
    },
    globals = { "BadgerTTKDB" },
}
