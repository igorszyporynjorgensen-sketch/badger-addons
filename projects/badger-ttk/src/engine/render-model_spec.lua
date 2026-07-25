local mock = require("tools.wow-mock.init")

describe("RenderModel", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/render-model.lua")
    end)

    it("plans one pop-line for a no-cooldown ability at TTK = duration", function()
        local m = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 0 } })
        assert.same({ 20 }, m.entries[1].planned.popLines)
    end)

    it("combs repeated pop-lines spaced by the cooldown while they fit", function()
        -- D=20, C=120, ttk=300 → 20, 140, 260 (380 excluded)
        local m =
            ns.RenderModel.build(300, { { id = "a", duration = 20, cooldown = 120, offset = 0 } })
        assert.same({ 20, 140, 260 }, m.entries[1].planned.popLines)
    end)

    it("shifts the comb by a positive offset (fire earlier)", function()
        local m = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 10 } })
        assert.same({ 30 }, m.entries[1].planned.popLines)
        assert.equals(10, m.entries[1].anchor)
    end)

    it("supports a negative offset (fire later, anchor past death)", function()
        local m = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = -5 } })
        assert.same({ 15 }, m.entries[1].planned.popLines)
        assert.equals(-5, m.entries[1].anchor)
    end)

    it("returns an empty comb when the window exceeds the remaining kill", function()
        local m = ns.RenderModel.build(10, { { id = "a", duration = 20, offset = 0 } })
        assert.same({}, m.entries[1].planned.popLines)
    end)

    it("classifies an active buff's coverage against its anchor", function()
        local fits =
            ns.RenderModel.build(30, { { id = "a", active = true, remaining = 30, offset = 0 } })
        assert.equals("fits", fits.entries[1].active.coverage)
        local short =
            ns.RenderModel.build(30, { { id = "a", active = true, remaining = 10, offset = 0 } })
        assert.equals("short", short.entries[1].active.coverage)
        local over =
            ns.RenderModel.build(30, { { id = "a", active = true, remaining = 50, offset = 0 } })
        assert.equals("over", over.entries[1].active.coverage)
    end)

    it("respects the offset in coverage (anchor shifted)", function()
        -- ttk=30, offset=10 → anchor at TTK 10, so the buff should last (30 − 10) = 20s to fit
        local m =
            ns.RenderModel.build(30, { { id = "a", active = true, remaining = 20, offset = 10 } })
        assert.equals("fits", m.entries[1].active.coverage)
    end)

    it(
        "defaults `total` to ttk, or carries an explicit fixed total (the sim's steady scale)",
        function()
            local d = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 0 } })
            assert.equals(40, d.total) -- defaults to ttk → live rescale behavior unchanged
            local f = ns.RenderModel.build(40, { { id = "a", duration = 20, offset = 0 } }, 50)
            assert.equals(50, f.total) -- fixed timeline scale
        end
    )

    it("passes an entry's display name through", function()
        local m = ns.RenderModel.build(
            30,
            { { id = "dw", name = "Death Wish", active = true, remaining = 30 } }
        )
        assert.equals("Death Wish", m.entries[1].name)
    end)
end)
