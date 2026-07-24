local _, ns = ...

-- Pure sizing math for the BadgerConfigUI dialog: a default seed size plus min/max clamps. No WoW API,
-- so resolve() is unit-testable off-client through the (addonName, ns) contract. SetDefaultSize only
-- seeds the first-ever open; the user then resizes and Ace persists it per-app. Exports
-- ns.BadgerConfigUIFrameSize.
local FrameSize = {}

FrameSize.DEFAULT_WIDTH = 780
FrameSize.DEFAULT_HEIGHT = 560
FrameSize.MIN_WIDTH = 600
FrameSize.MIN_HEIGHT = 400
FrameSize.MAX_WIDTH = 1200
FrameSize.MAX_HEIGHT = 900

local function clamp(value, low, high)
    if value < low then
        return low
    elseif value > high then
        return high
    end
    return value
end

-- resolve(opts) -> width, height. opts.width/opts.height default to DEFAULT_* then clamp into
-- [MIN_*, MAX_*]. Pure — no side effects.
function FrameSize.resolve(opts)
    opts = opts or {}
    local width =
        clamp(opts.width or FrameSize.DEFAULT_WIDTH, FrameSize.MIN_WIDTH, FrameSize.MAX_WIDTH)
    local height =
        clamp(opts.height or FrameSize.DEFAULT_HEIGHT, FrameSize.MIN_HEIGHT, FrameSize.MAX_HEIGHT)
    return width, height
end

ns.BadgerConfigUIFrameSize = FrameSize
