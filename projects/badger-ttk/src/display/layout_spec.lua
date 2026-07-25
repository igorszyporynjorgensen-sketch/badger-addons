local mock = require("tools.wow-mock.init")

describe("Layout", function()
    local ns
    local DIMS = { width = 200, height = 20, spacing = 2 }

    before_each(function()
        ns = {}
        mock.load("projects/badger-ttk/src/engine/render-model.lua", ns)
        mock.load("projects/badger-ttk/src/display/layout.lua", ns)
    end)

    it("spans the target bar the full width", function()
        local model = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 0 } })
        local l = ns.Layout.compute(model, DIMS)
        assert.is_true(l.ok)
        assert.equals(0, l.target.left)
        assert.equals(200, l.target.right)
    end)

    it("places a planned window right-anchored, length = width*D/ttk", function()
        local model = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 0 } })
        local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
        assert.equals(200, w.right) -- anchor (offset 0) = death = right edge
        assert.equals(100, w.left) -- 200 * 20/40
    end)

    it("resizes the window as TTK shrinks (pop-line reaches now)", function()
        local model = ns.RenderModel.build(20, { { id = "a", duration = 20, offset = 0 } })
        local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
        assert.equals(0, w.left) -- pop-line at TTK=20 == ttk → x=0 (now)
    end)

    it("an active buff that fits reaches the left edge (now)", function()
        local model =
            ns.RenderModel.build(40, { { id = "a", active = true, remaining = 40, offset = 0 } })
        local bar = ns.Layout.compute(model, DIMS).bars[1]
        assert.equals("active", bar.state)
        assert.equals(0, bar.windows[1].left)
    end)

    it("a positive offset shifts the window earlier", function()
        local model = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 10 } })
        -- pop-line at D+offset=30 → [xOf(30), xOf(10)] = [50, 150]
        local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
        assert.equals(50, w.left)
        assert.equals(150, w.right)
    end)

    it("a negative offset pushes the anchor past the death line", function()
        local model = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = -5 } })
        local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
        assert.is_true(w.right > 200) -- anchor at TTK=-5 → x > width
    end)

    it("reports not-ok when TTK is unknown/zero", function()
        local model = ns.RenderModel.build(0, { { id = "a", duration = 20, offset = 0 } })
        assert.is_false(ns.Layout.compute(model, DIMS).ok)
    end)
end)
