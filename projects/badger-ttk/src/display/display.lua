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

local container -- movable parent frame
local targetBar -- the TTK / health bar
local pool = {} -- reusable utility bar frames
local play -- dynamic-playback state, or nil

local function profile()
    return ns.addon.db.profile
end

-- Resolve an LSM media name → path, with a safe fallback.
local function media(mtype, name, fallback)
    return (name and LSM:Fetch(mtype, name)) or fallback
end

local function paint(bar, key)
    local c = profile()[key]
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
end

-- coverage / state → the db.profile colour key.
local STATE_COLOR = {
    planned = "colorPlanned",
    fits = "colorActive",
    over = "colorOverkill",
    short = "colorShortfall",
}

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
    container:SetSize(p.barWidth, p.barHeight)
    container:ClearAllPoints()
    container:SetPoint(p.anchorPoint, UIParent, p.anchorPoint, p.posX, p.posY)
    container:EnableMouse(not p.locked)
    if container.SetBackdrop then
        local edge = (p.border and p.border ~= "None") and media("border", p.border, nil) or nil
        container:SetBackdrop(edge and { edgeFile = edge, edgeSize = 12 } or nil)
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
    container = CreateFrame("Frame", "BadgerTTKFrame", UIParent, "BackdropTemplate")
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

    targetBar = CreateFrame("StatusBar", nil, container)
    targetBar:SetReverseFill(true) -- fills from the right (death); empties on the left as health drops
    targetBar:SetMinMaxValues(0, 1)
    targetBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    targetBar.text = targetBar:CreateFontString(nil, "OVERLAY")
    targetBar.text:SetPoint("LEFT", targetBar, "LEFT", 4, 0)

    Display.applyContainer()
end

local function acquireBar(i)
    local bar = pool[i]
    if not bar then
        bar = CreateFrame("StatusBar", nil, container)
        bar.text = bar:CreateFontString(nil, "OVERLAY")
        bar.text:SetPoint("CENTER")
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
    local layout = ns.Layout.compute(
        model,
        { width = p.barWidth, height = p.barHeight, spacing = p.barSpacing }
    )

    targetBar:SetSize(p.barWidth, p.barHeight)
    targetBar:SetStatusBarTexture(tex)
    targetBar.text:SetFont(font, p.fontSizeMain, "OUTLINE")
    paint(targetBar, "colorTarget")
    targetBar:SetValue(health or 0)
    targetBar.text:SetText(Display.formatTime(model.ttk))

    local step = p.barHeight + p.barSpacing
    local shown = 0
    for i = 1, #layout.bars do
        local b = layout.bars[i]
        local w = b.windows[1]
        local bar = acquireBar(i)
        if w and layout.ok then
            local left = math.max(0, w.left)
            local right = math.min(p.barWidth, w.right)
            shown = shown + 1
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", left, shown * step)
            bar:SetSize(math.max(1, right - left), p.barHeight)
            bar:SetStatusBarTexture(tex)
            bar.text:SetFont(font, p.fontSizeOther, "OUTLINE")
            paint(bar, STATE_COLOR[b.coverage or b.state] or "colorUtility")
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

-- Re-apply container settings and re-render the static preview if it is on (called from the config UI).
function Display.refresh()
    Display.applyContainer()
    if profile().simStatic then
        Display.showPreview(true)
    end
end

-- Static preview: render the frozen representative model.
function Display.showPreview(on)
    if on then
        Display.render(ns.Sim.staticPreview(), 0.6)
    elseif container then
        container:Hide()
    end
end

-- Dynamic playback: step the warrior-burst scenario over real time, animating the bars.
function Display.playSim(on, speed)
    if not on then
        play = nil
        if container then
            container:SetScript("OnUpdate", nil)
        end
        return
    end
    Display.init()
    play = { t = 0, speed = speed or 1 }
    container:SetScript("OnUpdate", function(_, elapsed)
        local scenario = ns.SimScenario.warriorBurst
        play.t = play.t + elapsed * play.speed
        if play.t > scenario.duration then
            play.t = 0
        end
        local model, _, health = ns.Sim.run(scenario, play.t)
        Display.render(model, health)
    end)
end

ns.Display = Display
