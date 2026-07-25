local _, ns = ...

-- Pure display layout: map a render-model (TTK-seconds space) to horizontal PIXEL windows on a
-- fixed-width timeline. Right edge (x = width) = death (TTK 0); left edge (x = 0) = now (TTK = ttk). The
-- frame glue (display.lua) stacks these rows vertically, fills the target bar to health, and colours by
-- state — but all the x-geometry lives here so it is unit-tested off-client. No WoW API, no frames.
--
--   xOf(v) = width · (ttk − v) / ttk      -- v = ttk → 0 (now); v = 0 → width (death)
--
-- A planned pop-line at TTK = P opens a window [P − D, P]. An active buff (R left, anchor = offset) spans
-- [offset, offset + R], right-anchored to its anchor, so its length is width · R / ttk. A negative offset
-- pushes the anchor to x > width (past the death line — the display carries a small right-margin).

local Layout = {}

local function xOf(v, ttk, width)
    return width * (ttk - v) / ttk
end

-- compute(model, dims) — dims = { width, height, spacing }. Returns
--   { width, ttk, ok, target = {left,right}, bars = { { id, state, coverage, windows = {{left,right}} } } }.
-- ok = false when TTK is unknown or ≤ 0 (nothing meaningful to place — the display shows "estimating").
function Layout.compute(model, dims)
    local width = dims.width
    local ttk = model.ttk
    if not ttk or ttk <= 0 then
        return {
            width = width,
            ttk = ttk,
            ok = false,
            target = { left = 0, right = width },
            bars = {},
        }
    end

    local bars = {}
    for i = 1, #model.entries do
        local e = model.entries[i]
        local bar = { id = e.id, windows = {} }
        if e.active then
            bar.state = "active"
            bar.coverage = e.active.coverage
            local r = e.active.remaining
            bar.windows[1] =
                { left = xOf(e.offset + r, ttk, width), right = xOf(e.offset, ttk, width) }
        else
            bar.state = "planned"
            local d = e.duration or 0
            local lines = e.planned.popLines
            for j = 1, #lines do
                local p = lines[j]
                bar.windows[j] = { left = xOf(p, ttk, width), right = xOf(p - d, ttk, width) }
            end
        end
        bars[i] = bar
    end

    return { width = width, ttk = ttk, ok = true, target = { left = 0, right = width }, bars = bars }
end

ns.Layout = Layout
