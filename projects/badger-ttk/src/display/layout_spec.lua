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

    it("clamps a negative-offset anchor to the death line (never past width)", function()
        local model = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = -5 } })
        local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
        assert.equals(200, w.right) -- anchor at TTK=-5 would map to x=225 → clamped to width (the cap)
    end)

    it("reports not-ok when TTK is unknown/zero", function()
        local model = ns.RenderModel.build(0, { { id = "a", duration = 20, offset = 0 } })
        assert.is_false(ns.Layout.compute(model, DIMS).ok)
    end)

    it(
        "scales by a fixed `total`, so an active coverage segment is steady as TTK shrinks",
        function()
            -- Same ability (D=30, offset 0) on a fixed total=50; only ttk + remaining differ. The segment is
            -- duration-based, so both frames yield the SAME window — it does not grow or shrink.
            local a = ns.RenderModel.build(
                40,
                { { id = "x", duration = 30, active = true, remaining = 40, offset = 0 } },
                50
            )
            local b = ns.RenderModel.build(
                20,
                { { id = "x", duration = 30, active = true, remaining = 20, offset = 0 } },
                50
            )
            local wa = ns.Layout.compute(a, DIMS).bars[1].windows[1]
            local wb = ns.Layout.compute(b, DIMS).bars[1].windows[1]
            assert.equals(80, wa.left) -- xOf(30, 50) = 200*(50-30)/50
            assert.equals(200, wa.right) -- xOf(0, 50) = death
            assert.equals(wa.left, wb.left)
            assert.equals(wa.right, wb.right)
        end
    )

    it(
        "never draws a bar wider than the TTK bar (over-long ability fills the full width)",
        function()
            -- Diamond-Flask style: duration 60 > total 50 → the left edge would be negative → clamped to 0.
            local model = ns.RenderModel.build(
                30,
                { { id = "df", duration = 60, active = true, remaining = 60, offset = 0 } },
                50
            )
            local w = ns.Layout.compute(model, DIMS).bars[1].windows[1]
            assert.equals(0, w.left)
            assert.equals(200, w.right)
        end
    )

    it("passes the entry name through to the bar", function()
        local model = ns.RenderModel.build(
            50,
            { { id = "dw", name = "Death Wish", duration = 30, active = true, remaining = 30 } },
            50
        )
        assert.equals("Death Wish", ns.Layout.compute(model, DIMS).bars[1].name)
    end)

    it("fills an active bar to remaining/duration (drains within the steady segment)", function()
        local active = ns.RenderModel.build(
            50,
            { { id = "a", duration = 30, active = true, remaining = 15, offset = 0 } },
            50
        )
        assert.equals(0.5, ns.Layout.compute(active, DIMS).bars[1].fill) -- 15 / 30
    end)

    it("fills a planned (not-yet-fired) bar full", function()
        local planned = ns.RenderModel.build(50, { { id = "b", duration = 30, offset = 0 } }, 50)
        assert.equals(1, ns.Layout.compute(planned, DIMS).bars[1].fill)
    end)

    it("sorts bars longest-duration first (nearest the TTK bar)", function()
        local model = ns.RenderModel.build(50, {
            { id = "short", duration = 20, offset = 0 },
            { id = "long", duration = 30, offset = 0 },
        }, 50)
        local bars = ns.Layout.compute(model, DIMS).bars
        assert.equals("long", bars[1].id) -- 30s → first row = nearest the TTK bar
        assert.equals("short", bars[2].id)
    end)
end)
