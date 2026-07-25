local _, ns = ...

-- Pure helper: a WoW texture-escape (`|T...|t`) for an inline icon in a config label. The caller resolves
-- the path (GetSpellTexture / GetItemIcon); this only formats the escape, so it is unit-testable
-- off-client. Introduced for the Abilities list's per-entry spell/item icons (deferred from WO-009).
local function iconMarkup(texture, size)
    if not texture then
        return ""
    end
    return ("|T%s:%d|t"):format(texture, size or 0)
end

ns.iconMarkup = iconMarkup
