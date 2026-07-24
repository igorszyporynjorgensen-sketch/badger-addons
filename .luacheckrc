-- Luacheck config for the badger-addons monorepo.
-- Analysed code runs in the WoW Classic (TBC Anniversary) Lua 5.1 sandbox; the lists below
-- describe that sandbox so real bugs surface and API calls don't read as "undefined global".
-- The load-bearing rule this enforces: addon code must NOT leak into _G (named exports only —
-- everything hangs off the private `ns` table). A stray global assignment fails the lint.

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
    -- PvP / Arena (TBC)
    "IsActiveBattlefieldArena",
    "GetNumArenaOpponents",
    "GetArenaOpponentSpec",
    "GetBattlefieldStatus",
    -- Libraries
    "LibStub",
}

-- Globals the game creates and WRITES for us (SavedVariables). Writable, not just readable.
globals = {
    "BadgerArenaDB",
}

-- Spec files speak the Busted DSL (describe / it / before_each / assert / ...).
files["**/*_spec.lua"] = {
    std = "+busted",
}
