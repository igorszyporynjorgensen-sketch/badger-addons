local mock = require("tools.wow-mock.init")

describe("Skin", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/skin/skin.lua")
    end)

    it("ships a built-in Default skin (Skin.BUILTIN)", function()
        assert.equals("Default", ns.Skin.BUILTIN)
        assert.is_not_nil(ns.Skin.GetSkin("Default"))
        assert.equals("Default", ns.Skin.ListSkins().Default)
    end)

    it("registers a third-party skin so it lists and resolves", function()
        ns.Skin.RegisterSkin("Neon", { statusbar = "Flat", colors = {} })
        assert.is_not_nil(ns.Skin.GetSkin("Neon"))
        assert.equals("Neon", ns.Skin.ListSkins().Neon)
    end)

    it("deletes a user skin, but never the built-in or an unknown one", function()
        ns.Skin.RegisterSkin("Temp", { statusbar = "Flat", colors = {} })
        assert.is_true(ns.Skin.deleteSkin("Temp"))
        assert.is_nil(ns.Skin.GetSkin("Temp"))
        assert.is_false(ns.Skin.deleteSkin("Default")) -- the built-in is protected
        assert.is_not_nil(ns.Skin.GetSkin("Default"))
        assert.is_false(ns.Skin.deleteSkin("Nope")) -- unknown
    end)

    it("applies a skin's media + colours (incl. font) onto the profile", function()
        local p = { colorTarget = { 0, 0, 0, 1 } }
        ns.Skin.apply(p, "Default")
        assert.equals("Blizzard", p.statusbar)
        assert.equals("Friz Quadrata TT", p.font)
        assert.same({ 0.85, 0.15, 0.15, 1 }, p.colorTarget)
        assert.same({ 1, 1, 1, 1 }, p.colorFont) -- WO-040 font colour
    end)

    it("is a no-op for an unknown skin", function()
        local p = { statusbar = "keep" }
        ns.Skin.apply(p, "Nope")
        assert.equals("keep", p.statusbar)
    end)

    it("applies font sizes and the Display LOOK, but never frame position/lock", function()
        ns.Skin.RegisterSkin("Big", {
            fontSizeMain = 24,
            -- A skin table may still name position/lock, but apply must IGNORE them (excluded fields).
            display = {
                barWidth = 300,
                scale = 1.5,
                anchorPoint = "LEFT",
                posX = 99,
                posY = 77,
                locked = false,
            },
        })
        local p = {
            barWidth = 180,
            scale = 1.0,
            anchorPoint = "RIGHT",
            posX = 0,
            posY = -12,
            locked = true,
            fontSizeMain = 16,
        }
        ns.Skin.apply(p, "Big")
        assert.equals(24, p.fontSizeMain)
        assert.equals(300, p.barWidth)
        assert.equals(1.5, p.scale)
        -- Position + lock untouched — a skin never moves the bars or changes the lock.
        assert.equals("RIGHT", p.anchorPoint)
        assert.equals(0, p.posX)
        assert.equals(-12, p.posY)
        assert.equals(true, p.locked)
    end)

    it("leaves layout untouched for a media-only skin (no Display block)", function()
        local p = { barWidth = 180, scale = 1.0, colorTarget = { 0, 0, 0, 1 } }
        ns.Skin.apply(p, "Default") -- built-in: media + colours, no display block
        assert.equals(180, p.barWidth) -- geometry preserved
        assert.equals(1.0, p.scale)
    end)

    it(
        "saveCurrent snapshots media, colours and the Display LOOK — but not position/lock",
        function()
            local p = {
                statusbar = "Flat",
                font = "Arial",
                border = "Blizzard",
                fontSizeMain = 20,
                fontSizeOther = 14,
                colorTarget = { 0.1, 0.2, 0.3, 1 },
                colorUtility = { 0, 0, 0, 1 },
                colorReady = { 0, 0, 0, 1 },
                colorUsed = { 0, 0, 0, 1 },
                colorFont = { 0.9, 0.8, 0.7, 1 },
                barWidth = 222,
                ttkBarHeight = 34,
                utilityBarHeight = 26,
                barSpacing = 3,
                scale = 1.4,
                anchorPoint = "CENTER",
                posX = 10,
                posY = -5,
                locked = false,
            }
            local skin = ns.Skin.saveCurrent(p, "MySkin")
            assert.equals("Flat", skin.statusbar)
            assert.equals(20, skin.fontSizeMain)
            assert.same({ 0.1, 0.2, 0.3, 1 }, skin.colors.target)
            assert.same({ 0.9, 0.8, 0.7, 1 }, skin.colors.font) -- font colour captured
            assert.is_nil(skin.colors.waiting) -- the old separate waiting colour is gone
            -- Bar spacing / width / height are captured (#22).
            assert.equals(222, skin.display.barWidth)
            assert.equals(34, skin.display.ttkBarHeight)
            assert.equals(26, skin.display.utilityBarHeight)
            assert.equals(3, skin.display.barSpacing)
            assert.equals(1.4, skin.display.scale)
            -- Frame position + lock are NOT captured.
            assert.is_nil(skin.display.anchorPoint)
            assert.is_nil(skin.display.posX)
            assert.is_nil(skin.display.posY)
            assert.is_nil(skin.display.locked)
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

    it(
        "round-trips the LOOK: saveCurrent then apply restores it without touching position",
        function()
            local src = {
                statusbar = "Flat",
                font = "Arial",
                border = "None",
                fontSizeMain = 18,
                fontSizeOther = 11,
                colorTarget = { 0.4, 0.5, 0.6, 1 },
                colorUtility = { 0, 0, 0, 1 },
                colorReady = { 0, 0, 0, 1 },
                colorUsed = { 0, 0, 0, 1 },
                colorFont = { 0.2, 0.3, 0.4, 1 },
                barWidth = 210,
                ttkBarHeight = 24,
                scale = 1.25,
                anchorPoint = "TOPRIGHT", -- captured from src? no — position is excluded
            }
            ns.Skin.saveCurrent(src, "RT")
            -- dst sits at its OWN position; applying the skin must keep it there.
            local dst = { colorTarget = { 0, 0, 0, 1 }, anchorPoint = "LEFT", posX = 42 }
            ns.Skin.apply(dst, "RT")
            assert.equals("Flat", dst.statusbar)
            assert.equals(18, dst.fontSizeMain)
            assert.same({ 0.4, 0.5, 0.6, 1 }, dst.colorTarget)
            assert.equals(210, dst.barWidth)
            assert.equals(1.25, dst.scale)
            -- dst's own placement is preserved (the skin carried none).
            assert.equals("LEFT", dst.anchorPoint)
            assert.equals(42, dst.posX)
        end
    )
end)
