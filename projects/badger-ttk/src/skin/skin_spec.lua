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

    it("applies font sizes and a Display block when the skin carries them", function()
        ns.Skin.RegisterSkin("Big", {
            fontSizeMain = 24,
            display = { barWidth = 300, scale = 1.5, anchorPoint = "LEFT" },
        })
        local p = { barWidth = 180, scale = 1.0, anchorPoint = "RIGHT", fontSizeMain = 16 }
        ns.Skin.apply(p, "Big")
        assert.equals(24, p.fontSizeMain)
        assert.equals(300, p.barWidth)
        assert.equals(1.5, p.scale)
        assert.equals("LEFT", p.anchorPoint)
    end)

    it("leaves layout untouched for a media-only skin (no Display block)", function()
        local p = { barWidth = 180, scale = 1.0, colorTarget = { 0, 0, 0, 1 } }
        ns.Skin.apply(p, "Badger") -- built-in: media + colours, no display block
        assert.equals(180, p.barWidth) -- geometry preserved
        assert.equals(1.0, p.scale)
    end)

    it(
        "saveCurrent snapshots media, colours and the full Display config into a new skin",
        function()
            local p = {
                statusbar = "Flat",
                font = "Arial",
                border = "Blizzard",
                fontSizeMain = 20,
                fontSizeOther = 14,
                colorTarget = { 0.1, 0.2, 0.3, 1 },
                colorUtility = { 0, 0, 0, 1 },
                colorWaiting = { 0, 0, 0, 1 },
                colorReady = { 0, 0, 0, 1 },
                colorUsed = { 0, 0, 0, 1 },
                barWidth = 222,
                anchorPoint = "CENTER",
                posX = 10,
                posY = -5,
            }
            local skin = ns.Skin.saveCurrent(p, "MySkin")
            assert.equals("Flat", skin.statusbar)
            assert.equals(20, skin.fontSizeMain)
            assert.same({ 0.1, 0.2, 0.3, 1 }, skin.colors.target)
            assert.equals(222, skin.display.barWidth)
            assert.equals("CENTER", skin.display.anchorPoint)
            assert.equals(10, skin.display.posX)
            -- Registered so it lists and re-applies.
            assert.equals("MySkin", ns.Skin.ListSkins().MySkin)
        end
    )

    it("saveCurrent copies values so later profile edits don't mutate the saved skin", function()
        local p = { colorTarget = { 1, 0, 0, 1 }, barWidth = 100 }
        local skin = ns.Skin.saveCurrent(p, "Snap")
        p.colorTarget[1] = 0
        p.barWidth = 999
        assert.same({ 1, 0, 0, 1 }, skin.colors.target)
        assert.equals(100, skin.display.barWidth)
    end)

    it("round-trips: saveCurrent then apply restores the captured config", function()
        local src = {
            statusbar = "Flat",
            font = "Arial",
            border = "None",
            fontSizeMain = 18,
            fontSizeOther = 11,
            colorTarget = { 0.4, 0.5, 0.6, 1 },
            colorUtility = { 0, 0, 0, 1 },
            colorWaiting = { 0, 0, 0, 1 },
            colorReady = { 0, 0, 0, 1 },
            colorUsed = { 0, 0, 0, 1 },
            barWidth = 210,
            barHeight = 24,
            scale = 1.25,
            anchorPoint = "TOPRIGHT",
        }
        ns.Skin.saveCurrent(src, "RT")
        local dst = { colorTarget = { 0, 0, 0, 1 } }
        ns.Skin.apply(dst, "RT")
        assert.equals("Flat", dst.statusbar)
        assert.equals(18, dst.fontSizeMain)
        assert.same({ 0.4, 0.5, 0.6, 1 }, dst.colorTarget)
        assert.equals(210, dst.barWidth)
        assert.equals(1.25, dst.scale)
        assert.equals("TOPRIGHT", dst.anchorPoint)
    end)
end)
