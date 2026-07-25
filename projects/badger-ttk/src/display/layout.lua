local _, ns = ...

-- Pure display layout: map a render-model (TTK-seconds space) to horizontal PIXEL windows on a
-- fixed-width timeline. Right edge (x = width) = death (TTK 0); the x-scale is `model.total` (the whole
-- fight), which DEFAULTS to `ttk` — so live keeps rescaling to the current estimate, while the sim passes
-- a fixed total and its bars hold steady. The frame glue (display.lua) stacks these rows vertically, fills
-- the target bar, and colours by state — but all the x-geometry lives here so it is unit-tested off-client.
--
--   xOf(v) = width · (total − v) / total    -- v = total → 0 (window start); v = 0 → width (death)
--
-- A planned pop-line at TTK = P opens a window [P − D, P]. An active buff is a steady coverage SEGMENT
-- [offset, offset + duration], right-anchored to its anchor (length width · duration / total) — NOT the
-- draining remaining, so it doesn't shrink; the countdown is text and the colour carries the coverage
-- verdict. Every window is clamped to [0, width]: nothing can be wider than the TTK bar (an ability longer
-- than the timeline just fills the full bar).

local Layout = {}

-- Map a TTK-seconds value to a pixel on the timeline, using the fixed-timeline `scale` (= model.total).
local function xOf(v, scale, width)
    return width * (scale - v) / scale
end

-- The TTK bar's width is the hard maximum: an ability longer than the timeline just fills the full bar
-- rather than overflowing (the width-cap invariant). Clamp every window edge to [0, width].
local function clamp(x, width)
    if x < 0 then
        return 0
    elseif x > width then
        return width
    end
    return x
end

-- compute(model, dims) — dims = { width, height, spacing }. Returns
--   { width, ttk, total, ok, target = {left,right}, bars = { {id, name, state, coverage, windows} } }.
-- The x-scale is `model.total` (defaults to ttk → the live rescale behavior); the sim passes a fixed total
-- so bars are steady. ok = false when TTK/total is unknown or ≤ 0 (the display shows nothing meaningful).
function Layout.compute(model, dims)
    local width = dims.width
    local ttk = model.ttk
    local total = model.total or ttk
    if not ttk or ttk <= 0 or not total or total <= 0 then
        return {
            width = width,
            ttk = ttk,
            total = total,
            ok = false,
            target = { left = 0, right = width },
            bars = {},
        }
    end

    local bars = {}
    for i = 1, #model.entries do
        local e = model.entries[i]
        local bar = { id = e.id, name = e.name, windows = {} }
        if e.active then
            bar.state = "active"
            bar.coverage = e.active.coverage
            -- Steady coverage SEGMENT: anchor → anchor + duration (the buff's whole window), NOT the
            -- draining remaining — so on a fixed timeline the bar holds its size/position for the buff's
            -- whole life (the countdown is shown as text, and the colour carries the coverage verdict).
            -- Falls back to remaining when no duration is supplied.
            local span = e.duration or e.active.remaining or 0
            bar.windows[1] = {
                left = clamp(xOf(e.offset + span, total, width), width),
                right = clamp(xOf(e.offset, total, width), width),
            }
        else
            bar.state = "planned"
            local d = e.duration or 0
            local lines = e.planned.popLines
            for j = 1, #lines do
                local p = lines[j]
                bar.windows[j] = {
                    left = clamp(xOf(p, total, width), width),
                    right = clamp(xOf(p - d, total, width), width),
                }
            end
        end
        bars[i] = bar
    end

    return {
        width = width,
        ttk = ttk,
        total = total,
        ok = true,
        target = { left = 0, right = width },
        bars = bars,
    }
end

ns.Layout = Layout
