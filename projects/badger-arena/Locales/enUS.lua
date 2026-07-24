local ADDON_NAME = ...

-- English (base) locale. A `true` value means "the key is its own display string". Add real
-- translations by shipping sibling locale files (deDE, ruRU, ...) with the same keys.
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)
if not L then
    return
end

L["Enabled"] = true
L["Show diminishing returns"] = true
