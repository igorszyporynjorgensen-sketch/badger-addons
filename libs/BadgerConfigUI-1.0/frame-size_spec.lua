-- Pure arithmetic — no WoW API. Loaded through the mock's (addonName, ns) contract exactly as the
-- client loads it; no install() needed, since frame-size touches no stubbed global.
local mock = require("tools.wow-mock.init")

describe("BadgerConfigUI frame-size", function()
    local ns

    before_each(function()
        ns = mock.load("libs/BadgerConfigUI-1.0/frame-size.lua")
    end)

    it("defaults to 780 by 560", function()
        local width, height = ns.BadgerConfigUIFrameSize.resolve({})
        assert.equals(780, width)
        assert.equals(560, height)
    end)

    it("treats nil opts like an empty table", function()
        local width, height = ns.BadgerConfigUIFrameSize.resolve()
        assert.equals(780, width)
        assert.equals(560, height)
    end)

    it("defaults the missing dimension on a partial override", function()
        local width, height = ns.BadgerConfigUIFrameSize.resolve({ width = 820 })
        assert.equals(820, width)
        assert.equals(560, height)
    end)

    it("passes an in-range override through unchanged", function()
        local width, height = ns.BadgerConfigUIFrameSize.resolve({ width = 820, height = 620 })
        assert.equals(820, width)
        assert.equals(620, height)
    end)

    it("clamps an undersized request up to the minimum", function()
        local FrameSize = ns.BadgerConfigUIFrameSize
        local width, height = FrameSize.resolve({ width = 100, height = 100 })
        assert.equals(FrameSize.MIN_WIDTH, width)
        assert.equals(FrameSize.MIN_HEIGHT, height)
    end)

    it("clamps an oversized request down to the maximum", function()
        local FrameSize = ns.BadgerConfigUIFrameSize
        local width, height = FrameSize.resolve({ width = 5000, height = 5000 })
        assert.equals(FrameSize.MAX_WIDTH, width)
        assert.equals(FrameSize.MAX_HEIGHT, height)
    end)
end)
