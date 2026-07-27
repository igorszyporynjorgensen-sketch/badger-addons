local _, ns = ...

-- Frame glue for the bar display — the thin, off-client-untestable edge (an in-game /reload check, not a
-- spec). ALL x-geometry comes from the spec-tested ns.Layout; the look (texture / font / border / colours)
-- comes from the selected skin, applied onto db.profile by ns.Skin and fetched here via LibSharedMedia.
-- This file only creates frames and applies the rects / media / colours / text / fill, and drives the sim
-- preview. Frames are built lazily in init(), so the module loads clean (nothing happens at load).

local Display = {}

local LSM = LibStub("LibSharedMedia-3.0")
local FALLBACK_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local container -- movable parent frame that hosts the bars + the border child
local borderFrame -- outset child of the container so the border wraps the bars (never overlaps them)
local targetBar -- the TTK / health bar
local pool = {} -- reusable utility bar frames
local BORDER_INSET = 0 -- px the border frame extends beyond the bar area — 0 so the border hugs the bar (WO-041)
local play -- dynamic-playback state, or nil
local simFrame -- dedicated ticker for dynamic playback — ALWAYS shown, never hidden, so its OnUpdate
-- can't stall (a hidden frame's OnUpdate stops firing; the container gets hidden, so it must NOT host this)
local smoothFrame -- always-shown ticker that eases each bar's fill toward its target (`bar.__target`) so
-- the display glides instead of stepping at the 0.15s live cadence
local SMOOTH_SPEED = 10 -- higher = snappier ease; ~90% of the way to target in ~0.15s at 60fps

local function profile()
    return ns.addon.db.profile
end

-- Ease a status bar's displayed value toward its stored target this frame (exponential smoothing).
local function smoothStep(bar, elapsed)
    if not bar or bar.__target == nil then
        return
    end
    local cur = bar:GetValue()
    local diff = bar.__target - cur
    if math.abs(diff) < 0.001 then
        bar:SetValue(bar.__target)
    else
        bar:SetValue(cur + diff * math.min(1, elapsed * SMOOTH_SPEED))
    end
end

-- Command the live driver directly: while a preview (static or dynamic) owns the container, the driver
-- must not touch it. Pushed the instant a preview is toggled — synchronous, no per-tick db read.
local function syncDriver()
    if ns.LiveDriver then
        local p = profile()
        ns.LiveDriver.setSuspended(p.simStatic or p.simPlaying)
    end
end

-- Resolve an LSM media name → path, with a safe fallback.
local function media(mtype, name, fallback)
    return (name and LSM:Fetch(mtype, name)) or fallback
end

-- Utility-bar colour is an ACTION signal: waiting (fire moment ahead) → ready (fire now, green) → used
-- (fired + draining, gray). Maps a layout bar to its db.profile colour key.
local function utilityColorKey(bar)
    if bar.state == "active" then
        return "colorUsed" -- Utility (fired)
    elseif bar.ready then
        return "colorReady" -- Utility (fire)
    end
    return "colorUtility" -- Utility (waiting)
end

-- m:ss (or raw seconds) per the config; "" when TTK is unknown.
function Display.formatTime(ttk)
    if not ttk or ttk <= 0 then
        return ""
    end
    if profile().timeFormat == "seconds" then
        return string.format("%d", ttk)
    end
    return string.format("%d:%02d", math.floor(ttk / 60), math.floor(ttk % 60))
end

-- Container-level settings (scale / opacity / strata / size / position / lock / border).
function Display.applyContainer()
    if not container then
        return
    end
    local p = profile()
    container:SetScale(p.scale)
    container:SetAlpha(p.opacity)
    container:SetFrameStrata(p.strata)
    container:SetSize(p.barWidth, p.ttkBarHeight)
    container:ClearAllPoints()
    -- Anchored by a right-side point (RIGHT by default), so a width change grows leftward and the death
    -- (right) edge stays fixed.
    container:SetPoint(p.anchorPoint, UIParent, p.anchorPoint, p.posX, p.posY)
    container:EnableMouse(not p.locked)
    -- The main bar tracks the container size immediately; utility bars re-layout on the next render.
    if targetBar then
        targetBar:SetSize(p.barWidth, p.ttkBarHeight)
    end
    -- Border on the outset child frame so it wraps the bars without overlapping them. Scale / alpha /
    -- strata are INHERITED from the container (it's a child now), so we only set the backdrop + anchors.
    if borderFrame then
        local edge = (p.border and p.border ~= "None") and media("border", p.border, nil) or nil
        if edge then
            borderFrame:ClearAllPoints()
            borderFrame:SetPoint("TOPLEFT", container, "TOPLEFT", -BORDER_INSET, BORDER_INSET)
            borderFrame:SetPoint(
                "BOTTOMRIGHT",
                container,
                "BOTTOMRIGHT",
                BORDER_INSET,
                -BORDER_INSET
            )
            borderFrame:SetBackdrop({ edgeFile = edge, edgeSize = 12 })
            borderFrame:Show()
        else
            borderFrame:SetBackdrop(nil)
            borderFrame:Hide()
        end
    end
end

function Display.resetPosition()
    local p = profile()
    p.anchorPoint, p.posX, p.posY = "RIGHT", 0, 0
    Display.applyContainer()
end

-- Build the parent + target bar the first time we render.
function Display.init()
    if container then
        return
    end
    container = CreateFrame("Frame", "BadgerTTKFrame", UIParent)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self)
        if not profile().locked then
            self:StartMoving()
        end
    end)
    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local p = profile()
        p.anchorPoint, p.posX, p.posY = point, x, y
    end)

    -- The border lives on its OWN frame outset around the bar area, so it wraps the bars rather than
    -- overlapping them. A CHILD of the container (not a sibling): its visibility then tracks the
    -- container's — so it hides with the bars and never lingers on screen when nothing is shown. It's
    -- anchored beyond the container (12px outset) and nothing clips it (the container no longer clips).
    borderFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")

    targetBar = CreateFrame("StatusBar", nil, container)
    targetBar:SetReverseFill(true) -- fills from the right (death); empties on the left as health drops
    targetBar:SetMinMaxValues(0, 1)
    targetBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    targetBar.bg = targetBar:CreateTexture(nil, "BACKGROUND") -- faint background track (like the utility bars)
    targetBar.bg:SetAllPoints(targetBar)
    targetBar.text = targetBar:CreateFontString(nil, "OVERLAY")
    targetBar.text:SetPoint("LEFT", targetBar, "LEFT", 4, 0)

    -- Ease every bar's fill toward its target each frame, so the display glides rather than stepping at the
    -- live 0.15s cadence. Skips work while the display is hidden.
    smoothFrame = CreateFrame("Frame")
    smoothFrame:SetScript("OnUpdate", function(_, elapsed)
        if not container:IsShown() then
            return
        end
        smoothStep(targetBar, elapsed)
        for i = 1, #pool do
            smoothStep(pool[i], elapsed)
        end
    end)

    Display.applyContainer()
end

local function acquireBar(i)
    local bar = pool[i]
    if not bar then
        bar = CreateFrame("StatusBar", nil, container)
        bar:SetMinMaxValues(0, 1)
        bar:SetReverseFill(true) -- drain toward death (right edge), in step with the TTK bar
        bar.bg = bar:CreateTexture(nil, "BACKGROUND") -- dim track so the steady segment stays visible
        bar.bg:SetAllPoints(bar)
        bar.text = bar:CreateFontString(nil, "OVERLAY")
        bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0) -- right-aligned at the death edge
        bar.text:SetJustifyH("RIGHT")
        pool[i] = bar
    end
    return bar
end

-- Render a render-model + the current health fraction (0..1) into the frames, using the resolved skin.
function Display.render(model, health)
    Display.init()
    local p = profile()
    local tex = media("statusbar", p.statusbar, FALLBACK_TEX)
    local font = media("font", p.font, FALLBACK_FONT)
    local fc = p.colorFont or { 1, 1, 1, 1 } -- bar text colour
    local fg = p.barFgOpacity or 1 -- fill opacity
    local bgOp = p.barBgOpacity or 0.1 -- background-track opacity
    local ttkH, utilH = p.ttkBarHeight, p.utilityBarHeight
    -- Layout is x-only (it ignores height/spacing); the Y stacking + sizes are done here.
    local layout = ns.Layout.compute(model, { width = p.barWidth })

    targetBar:SetSize(p.barWidth, ttkH)
    targetBar:SetStatusBarTexture(tex)
    targetBar.text:SetFont(font, p.fontSizeMain, "OUTLINE")
    targetBar.text:SetTextColor(fc[1], fc[2], fc[3], fc[4])
    targetBar.text:ClearAllPoints()
    targetBar.text:SetPoint("LEFT", targetBar, "LEFT", 4 + p.ttkTextX, p.ttkTextY)
    local tc = p.colorTarget
    targetBar:SetStatusBarColor(tc[1], tc[2], tc[3], (tc[4] or 1) * fg)
    targetBar.bg:SetTexture(tex) -- faint background track, tinted from the target colour
    targetBar.bg:SetVertexColor(tc[1] * 0.3, tc[2] * 0.3, tc[3] * 0.3, bgOp)
    targetBar.__target = health or 0 -- the smoother eases the fill toward this
    targetBar.text:SetText(Display.formatTime(model.ttk))

    local shown = 0
    for i = 1, #layout.bars do
        local b = layout.bars[i]
        local w = b.windows[1]
        local bar = acquireBar(i)
        if w and layout.ok then
            local left = math.max(0, w.left)
            local right = math.min(p.barWidth, w.right)
            shown = shown + 1
            -- Stack above the TTK bar: first utility bar sits at ttkH + spacing, each next one a utility
            -- height + spacing higher.
            local uy = ttkH + p.barSpacing + (shown - 1) * (utilH + p.barSpacing)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", left, uy)
            bar:SetSize(math.max(1, right - left), utilH)
            bar:SetStatusBarTexture(tex)
            bar.text:SetFont(font, p.fontSizeOther, "OUTLINE")
            bar.text:SetTextColor(fc[1], fc[2], fc[3], fc[4])
            bar.text:ClearAllPoints()
            bar.text:SetPoint("RIGHT", bar, "RIGHT", -3 + p.utilTextX, p.utilTextY)
            -- Colour by action state (waiting/ready/used); the track (bg) is the same texture at a dim
            -- tint. While WAITING, an ability may override the global Utility (waiting) colour with its own
            -- (WO-042) — looked up by the bar's ability id. Fire/fired keep the global state colours.
            local key = utilityColorKey(b)
            local c = p[key] or p.colorUtility
            if key == "colorUtility" then
                local ac = p.abilities and p.abilities[b.id]
                if ac and ac.color then
                    c = ac.color
                end
            end
            bar:SetStatusBarColor(c[1], c[2], c[3], (c[4] or 1) * fg)
            bar.bg:SetTexture(tex)
            bar.bg:SetVertexColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, bgOp)
            bar.__target = b.fill or 1 -- the smoother eases the fill toward this
            -- Label: the entry's name (showBarNames) + remaining seconds while active (showTimers, off by
            -- default). Read from the sorted bar, not model.entries (the layout reorders by duration).
            local label = (p.showBarNames and b.name) or ""
            if p.showTimers and b.state == "active" and b.remaining then
                local secs = math.floor(b.remaining + 0.5)
                if secs > 0 then
                    label = (label ~= "" and (label .. "  ") or "") .. secs .. "s"
                end
            end
            bar.text:SetText(label)
            bar:Show()
        else
            bar:Hide()
        end
    end
    for i = #layout.bars + 1, #pool do
        pool[i]:Hide()
    end
    container:Show()
end

-- Render the ONE preview scenario frozen at 0:25 (the single source the dynamic playback animates).
local function renderFrozen()
    local model, _, health = ns.Sim.staticPreview()
    Display.render(model, health)
end

-- Re-apply container settings and re-render the preview if it's up (called from the config UI on any
-- setting change). While playing, the loop re-renders every frame; while PAUSED (a `play` exists but the
-- ticker is off), redraw that same frozen point so a Display edit doesn't snap back to 0:25; otherwise
-- (plain Show-preview) redraw the 0:25 still.
function Display.refresh()
    Display.applyContainer()
    if profile().simPlaying then
        return
    elseif play then
        local model, _, health = ns.Sim.run(ns.SimScenario.warriorBurst, play.t)
        Display.render(model, health)
    elseif profile().simStatic then
        renderFrozen()
    end
end

-- Hide the whole stack (no target / gated out by the live driver).
function Display.hide()
    if container then
        container:Hide()
    end
end

-- Show / hide the preview (WO-030). While shown it's either the frozen 0:25 still or, if playback is on,
-- the animated loop of that SAME scenario. Turning it off stops any playback and resumes the live driver.
function Display.showPreview(on)
    if on then
        if profile().simPlaying then
            Display.playSim(true, profile().simSpeed) -- shown + playing → animate the same setup
        else
            renderFrozen() -- shown, not playing → the frozen 0:25 still
            syncDriver()
        end
    else
        play = nil
        if simFrame then
            simFrame:SetScript("OnUpdate", nil)
        end
        if container then
            container:Hide()
        end
        syncDriver()
    end
end

-- Play / PAUSE the shown preview (WO-033): Play animates the one scenario on a loop; Pause freezes it
-- exactly where it is (keeps `play`, so Play resumes from the same point — pausing never resets the
-- timeline). Reset (below) is the explicit way back to the 0:25 start. The OnUpdate lives on the dedicated
-- always-shown simFrame (NOT the container) so a container hide can't stall it.
function Display.playSim(on, speed)
    if not simFrame then
        simFrame = CreateFrame("Frame")
    end
    if not on then
        -- Pause: stop the ticker but keep `play` and the current frame on screen.
        simFrame:SetScript("OnUpdate", nil)
        syncDriver()
        return
    end
    Display.init()
    play = play or { t = 0 } -- resume a paused run from where it left off, or start a fresh one
    play.speed = speed or play.speed or 1
    simFrame:SetScript("OnUpdate", function(_, elapsed)
        local scenario = ns.SimScenario.warriorBurst
        play.t = play.t + elapsed * play.speed
        if play.t >= scenario.total then
            play.t = 0 -- loop the fight (reset before TTK hits 0 so it never blanks)
        end
        local model, _, health = ns.Sim.run(scenario, play.t)
        Display.render(model, health)
    end)
    syncDriver()
end

-- Reset rewinds the run to the START of the timeline — t=0, so TTK 0:50 at 100% health (WO-035). It is
-- INDEPENDENT of play/pause: it never stops or starts playback. If the animation is playing it just keeps
-- playing from the start (via its own loop); if paused/idle we render the 0:50 frame and keep the (now
-- start-positioned) `play` so a later Play/refresh continues from there.
function Display.resetSim()
    play = play or { t = 0, speed = profile().simSpeed or 1 }
    play.t = 0
    local model, _, health = ns.Sim.run(ns.SimScenario.warriorBurst, 0)
    Display.render(model, health)
    syncDriver()
end

ns.Display = Display
