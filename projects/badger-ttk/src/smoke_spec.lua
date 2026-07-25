local mock = require("tools.wow-mock.init")

-- Scaffold smoke test (WO-008): badger-ttk has no feature logic yet, so this proves the Busted harness
-- and the wow-mock's VANILLA surface work for this project — the flavor badger-ttk targets (Classic Era
-- 1.15, WOW_PROJECT_CLASSIC, no arena API). Real colocated `<module>_spec.lua` files replace/join it as
-- modules land. Divergence from "spec colocates with a unit" is deliberate: it is a harness smoke test.
describe("badger-ttk vanilla flavor (scaffold smoke)", function()
    before_each(function()
        mock.install({ flavor = "vanilla" })
    end)

    after_each(function()
        mock.reset()
    end)

    it("runs on the Classic (Vanilla) project id", function()
        assert.equals(WOW_PROJECT_CLASSIC, WOW_PROJECT_ID)
    end)

    it("exposes no TBC arena API", function()
        assert.is_nil(_G.IsActiveBattlefieldArena)
    end)
end)
