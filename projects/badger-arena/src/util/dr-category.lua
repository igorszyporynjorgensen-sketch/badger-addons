local _, ns = ...

-- Diminishing-returns knowledge for arena crowd control. Pure data + arithmetic — no WoW API — so
-- it is trivially unit-testable. The spell set is an illustrative TBC seed; extend it (or swap in
-- DRList-1.0) as real tracking grows.
local DrCategory = {}

-- Applications age out this many seconds after the aura fades (the TBC DR reset window).
DrCategory.RESET_SECONDS = 18

-- spellId -> DR category. Spells sharing a category diminish one another.
local CATEGORY_BY_SPELL = {
    [118] = "incapacitate", -- Polymorph
    [853] = "stun", -- Hammer of Justice
    [408] = "stun", -- Kidney Shot
    [1833] = "stun", -- Cheap Shot
    [339] = "root", -- Entangling Roots
    [5782] = "fear", -- Fear
}

-- Duration multiplier for the Nth application within the reset window:
-- 1st full, 2nd half, 3rd quarter, 4th and beyond immune.
local MULTIPLIER_BY_APPLICATION = { 1.0, 0.5, 0.25 }

function DrCategory.categoryOf(spellId)
    return CATEGORY_BY_SPELL[spellId]
end

function DrCategory.multiplierForApplication(application)
    if application < 1 then
        return 1.0
    end
    return MULTIPLIER_BY_APPLICATION[application] or 0
end

function DrCategory.isImmune(application)
    return DrCategory.multiplierForApplication(application) == 0
end

ns.DrCategory = DrCategory
