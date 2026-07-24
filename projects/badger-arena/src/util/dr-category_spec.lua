-- Pure logic — no WoW API needed. Still loaded through the mock loader so it exercises the exact
-- (addonName, ns) contract the client uses to load the file.
local mock = require("tools.wow-mock.init")

describe("dr-category", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-arena/src/util/dr-category.lua")
    end)

    it("maps known crowd-control spells to a DR category", function()
        assert.equals("incapacitate", ns.DrCategory.categoryOf(118)) -- Polymorph
        assert.equals("stun", ns.DrCategory.categoryOf(853)) -- Hammer of Justice
        assert.equals("root", ns.DrCategory.categoryOf(339)) -- Entangling Roots
    end)

    it("returns nil for an unknown spell", function()
        assert.is_nil(ns.DrCategory.categoryOf(999999))
    end)

    it("halves, quarters, then grants immunity across successive applications", function()
        assert.equals(1.0, ns.DrCategory.multiplierForApplication(1))
        assert.equals(0.5, ns.DrCategory.multiplierForApplication(2))
        assert.equals(0.25, ns.DrCategory.multiplierForApplication(3))
        assert.equals(0, ns.DrCategory.multiplierForApplication(4))
    end)

    it("reports immunity only from the fourth application", function()
        assert.is_false(ns.DrCategory.isImmune(3))
        assert.is_true(ns.DrCategory.isImmune(4))
    end)

    it("uses the TBC 18-second DR reset window", function()
        assert.equals(18, ns.DrCategory.RESET_SECONDS)
    end)
end)
