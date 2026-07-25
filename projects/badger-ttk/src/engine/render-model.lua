local _, ns = ...

-- Pure render-model geometry: turn a TTK estimate + the tracked entries into the coordinates the display
-- draws. Everything is in TTK-SECONDS space (right edge = death = TTK 0); the display maps seconds→pixels
-- and applies the skin. No WoW API / frames, so it runs under Busted. An entry's `offset` shifts its
-- anchor off death to TTK = offset (bi-directional): positive = fire earlier, negative = fire later.

local RenderModel = {}

local ALIGN_EPSILON = 0.5 -- seconds within which an active buff counts as "aligned" to its anchor

-- Planned pop-lines: TTK = D + offset, +C, +2C, … while ≤ the remaining kill. The death-most (smallest
-- TTK, first in the list) is the must-hit; each later one is an earlier "fit another cast in" moment.
-- Empty when the ability's window already exceeds the remaining kill.
local function popLines(ttk, duration, cooldown, offset)
    local lines = {}
    local step = (cooldown and cooldown > 0) and cooldown or nil
    local x = duration + offset
    while x <= ttk do
        lines[#lines + 1] = x
        if not step then
            break
        end
        x = x + step
    end
    return lines
end

-- Coverage of an active buff vs its anchor: `over` (outlasts the anchor), `short` (ends before it), or
-- `fits`. Compares remaining duration R to (ttk − offset) = the time left until the anchor.
local function coverage(ttk, offset, remaining)
    local diff = remaining - (ttk - offset)
    if diff > ALIGN_EPSILON then
        return "over"
    elseif diff < -ALIGN_EPSILON then
        return "short"
    end
    return "fits"
end

-- entries: array of { id, duration, cooldown, offset = 0, active = false, remaining }.
-- Returns { ttk, entries = { { id, offset, anchor, planned = { popLines } | active = { remaining,
-- endTTK, coverage } } } }.
function RenderModel.build(ttk, entries)
    local out = { ttk = ttk, entries = {} }
    for i = 1, #entries do
        local e = entries[i]
        local offset = e.offset or 0
        local info = { id = e.id, offset = offset, anchor = offset }
        if e.active then
            local r = e.remaining or 0
            info.active = { remaining = r, endTTK = ttk - r, coverage = coverage(ttk, offset, r) }
        else
            info.planned = { popLines = popLines(ttk, e.duration, e.cooldown, offset) }
        end
        out.entries[i] = info
    end
    return out
end

ns.RenderModel = RenderModel
