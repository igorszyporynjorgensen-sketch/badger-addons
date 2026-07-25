local mock = require("tools.wow-mock.init")

describe("Skin", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/skin/skin.lua")
    end)

    it("ships a built-in Badger skin", function()
        assert.is_not_nil(ns.Skin.GetSkin("Badger"))
        assert.equals("Badger", ns.Skin.ListSkins().Badger)
    end)

    it("registers a third-party skin so it lists and resolves", function()
        ns.Skin.RegisterSkin("Neon", { statusbar = "Flat", colors = {} })
        assert.is_not_nil(ns.Skin.GetSkin("Neon"))
        assert.equals("Neon", ns.Skin.ListSkins().Neon)
    end)

    it("applies a skin's media + colours onto the profile", function()
        local p = { colorTarget = { 0, 0, 0, 1 } }
        ns.Skin.apply(p, "Badger")
        assert.equals("Blizzard", p.statusbar)
        assert.equals("Friz Quadrata TT", p.font)
        assert.same({ 0.85, 0.15, 0.15, 1 }, p.colorTarget)
    end)

    it("is a no-op for an unknown skin", function()
        local p = { statusbar = "keep" }
        ns.Skin.apply(p, "Nope")
        assert.equals("keep", p.statusbar)
    end)
end)
