local _, ns = ...

-- Thin LibStub glue for BadgerConfigUI-1.0 — the untestable Ace3/frame edge, so it carries NO spec
-- (mirroring core.lua/config.lua). Every branch worth testing lives in the two sibling pure files
-- (options-tree.lua, frame-size.lua) which the XML loads FIRST; this file captures them off `ns` as
-- upvalues. It is the only file here that calls LibStub or reads the Blizzard Settings/Interface
-- globals.
--
-- Obtain the shared instance with:  local BCUI = LibStub("BadgerConfigUI-1.0")
-- Consumers register a UNIQUE appName (their ADDON_NAME) so status/registry tables never collide.

local MAJOR, MINOR = "BadgerConfigUI-1.0", 9
assert(LibStub, MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
end

-- Captured from the sibling files the XML loaded just before this one. Only the first-loading addon
-- reaches here (later addons hit the NewLibrary guard above and return), so all addons share this one
-- instance and these upvalues.
local OptionsTree = ns.BadgerConfigUIOptionsTree
local FrameSize = ns.BadgerConfigUIFrameSize

-- Per-appName state (title, status bar text, Blizzard category). Survives an in-place MINOR upgrade.
lib.apps = lib.apps or {}

-- ── Left-nav polish ──────────────────────────────────────────────────────────────────────────────
-- The AceGUI TreeGroup widget (vendored — never edited here) anchors each node's text tight against the
-- icon (~2px) and ~2px above it. We re-anchor the text to the icon's RIGHT edge + a gap at y-offset 0,
-- which both adds space AND vertically centres the name on the icon. Defensive: no-ops if the AceGUI
-- internals aren't as expected, and only touches buttons that actually have an icon.
local ICON_TEXT_GAP = 6

local function reanchorTreeButtons(tree)
    if not (tree and tree.buttons) then
        return
    end
    for _, button in ipairs(tree.buttons) do
        local icon, text = button.icon, button.text
        if icon and text and icon.GetTexture and icon:GetTexture() then
            text:ClearAllPoints()
            text:SetPoint("LEFT", icon, "RIGHT", ICON_TEXT_GAP, 0)
        end
    end
end

-- Find the left-nav TreeGroup child of the opened frame and keep its buttons re-anchored (RefreshTree
-- runs on every expand/collapse/select). Hook once per tree instance; re-anchor immediately.
local function polishTree(frame)
    if not (frame and frame.children) then
        return
    end
    for _, child in ipairs(frame.children) do
        if child.type == "TreeGroup" then
            if not child.__badgerTreePolished and type(child.RefreshTree) == "function" then
                child.__badgerTreePolished = true
                hooksecurefunc(child, "RefreshTree", function()
                    reanchorTreeButtons(child)
                end)
            end
            reanchorTreeButtons(child)
            return
        end
    end
end

-- Align the bottom status bar + Close button with the content's L/R inset. AceGUI insets the content 17px
-- but the status bar sits at 15 (left) and the Close button at -27 (right). Re-anchor them so all three
-- lines read flush; applied once per Open (Ace doesn't re-anchor these on refresh). Fully defensive: it
-- no-ops on any shape mismatch, and only touches the status bar's parent + the text-bearing child Button.
local function polishStatusBar(frame)
    if not frame then
        return
    end
    local statustext = frame.statustext
    local statusbg = statustext and statustext.GetParent and statustext:GetParent()
    if statusbg and statusbg.ClearAllPoints then
        statusbg:ClearAllPoints()
        statusbg:SetPoint("BOTTOMLEFT", 17, 15)
        statusbg:SetPoint("BOTTOMRIGHT", -122, 15)
    end
    local root = frame.frame
    if root and root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            -- The Close button is the direct-child Button with text; the status bar bg is a text-less Button.
            if
                child ~= statusbg
                and child.GetObjectType
                and child:GetObjectType() == "Button"
                and child.GetText
                and child:GetText()
                and child:GetText() ~= ""
            then
                child:ClearAllPoints()
                child:SetPoint("BOTTOMRIGHT", -17, 17)
            end
        end
    end
end

-- ── Two-column brand header ──────────────────────────────────────────────────────────────────────
-- When an app registers `header.image`, draw a self-contained brand band across the top of the window:
-- the image on the LEFT (with a right margin) and the title + subtitle stacked, left-aligned, on the
-- RIGHT. The band is RAW (a frame + texture + two FontStrings on frame.frame, NOT AceGUI children), so
-- AceConfig's ReleaseChildren — fired on every value-change re-Open — never destroys it; built once,
-- guarded by a plain (non-userdata) flag that survives widget Release. The native content (the control
-- row + tree) is pushed BELOW the band by re-pointing content's TOPLEFT down by the band height: content
-- is anchored TOPLEFT(17,-27)/BOTTOMRIGHT at Frame construction and never re-pointed afterwards (resize
-- only calls content:SetWidth/SetHeight), so this single absolute SetPoint holds across re-Open + resize.
-- Fully defensive: no-ops unless header.image is present and the frame shape is as expected. When no app
-- registers an image (badger-arena), normalize keeps the text banner and this never runs.
local HEADER_PAD = 10 -- inset of the band's artwork/text from the band's top-left
local HEADER_BRAND = { 0.961, 0.773, 0.259 } -- Badger brand gold (f5c542)

local function polishHeader(frame, app)
    local header = app and app.header
    if not (frame and frame.frame and frame.content and header and header.image) then
        return
    end
    local imgW = header.imageWidth or 72
    local imgH = header.imageHeight or 72
    local margin = header.imageMargin or 14
    local bandH = HEADER_PAD + imgH + HEADER_PAD

    -- Push the native content (control row + tree) below the band. Absolute offset → idempotent.
    frame.content:SetPoint("TOPLEFT", 17, -27 - bandH)

    if frame.frame.__badgerHeaderBuilt then
        return
    end
    frame.frame.__badgerHeaderBuilt = true

    local band = CreateFrame("Frame", nil, frame.frame)
    band:SetPoint("TOPLEFT", 17, -27)
    band:SetPoint("TOPRIGHT", -17, -27)
    band:SetHeight(bandH)

    -- LEFT container: the artwork, sized to itself, with a right margin (the text starts past it).
    local tex = band:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(header.image)
    tex:SetSize(imgW, imgH)
    tex:SetPoint("TOPLEFT", HEADER_PAD, -HEADER_PAD)

    -- RIGHT container: title over subtitle, both left-aligned, filling the remaining width.
    local title = band:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetJustifyH("LEFT")
    title:SetPoint("TOPLEFT", tex, "TOPRIGHT", margin, -2)
    title:SetPoint("RIGHT", band, "RIGHT", -HEADER_PAD, 0)
    title:SetText(header.title or "")
    title:SetTextColor(HEADER_BRAND[1], HEADER_BRAND[2], HEADER_BRAND[3])

    if header.subtitle then
        local sub = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetJustifyH("LEFT")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        sub:SetPoint("RIGHT", band, "RIGHT", -HEADER_PAD, 0)
        sub:SetText(header.subtitle)
    end
end

-- Register an addon's options table, seed its dialog size, and optionally add a Blizzard-panel stub.
-- opts = {header, banner, width, height, title, status, blizzard}. `header` = { title, subtitle, image…,
-- controls = { <AceConfig option tables> } } becomes ONE persistent header above the tree (see
-- normalize); `banner` is the back-compat alias for `header` (title/subtitle only). Returns the normalized
-- options table.
function lib:Register(appName, options, opts)
    opts = opts or {}

    local normalized = OptionsTree.normalize(options, opts)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, normalized)

    local width, height = FrameSize.resolve(opts)
    LibStub("AceConfigDialog-3.0"):SetDefaultSize(appName, width, height)

    local app = {
        title = opts.title or options.name or appName,
        status = opts.status,
        -- Kept for polishHeader: when this carries an `image`, normalize omitted the text banner and we
        -- draw the two-column brand band instead (title/subtitle/image live here).
        header = opts.header or opts.banner,
    }
    self.apps[appName] = app

    if opts.blizzard then
        local opener = function()
            -- Close the native Settings/Interface panel first, then open the Badger window.
            if SettingsPanel then
                HideUIPanel(SettingsPanel)
            elseif InterfaceOptionsFrame then
                HideUIPanel(InterfaceOptionsFrame)
            end
            self:Open(appName)
        end
        local blizName = appName .. "_Bliz"
        LibStub("AceConfig-3.0"):RegisterOptionsTable(
            blizName,
            OptionsTree.blizStub(app.title, opener)
        )
        -- AddToBlizOptions returns (frame, categoryID); Settings.OpenToCategory needs the ID, and the
        -- legacy InterfaceOptionsFrame_OpenToCategory fallback accepts that same name/ID string.
        local _, categoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(blizName, app.title)
        app.blizCategory = categoryID
    end

    return normalized
end

-- Register a callback fired when this app's window closes (X button or :Close/:CloseAll) — used by
-- consumers to tear down transient UI state (e.g. a live preview) when the config is dismissed.
function lib:SetCloseCallback(appName, fn)
    local app = self.apps[appName]
    if app then
        app.onClose = fn
    end
end

-- Chain the AceGUI Frame's OnClose so app.onClose fires whenever the window closes. Ace re-sets the
-- widget's OnClose to its own teardown on every Open (AceConfigDialog), so we re-wrap after each Open,
-- capturing Ace's handler (`prev`) and calling it first — never replacing the cleanup, only extending it.
local function chainClose(self, appName, frame)
    if not frame then
        return
    end
    local prev = frame.events and frame.events["OnClose"]
    frame:SetCallback("OnClose", function(widget, event, ...)
        if prev then
            prev(widget, event, ...)
        end
        local name = (widget.GetUserData and widget:GetUserData("appName")) or appName
        local app = self.apps[name]
        if app and app.onClose then
            app.onClose(name)
        end
    end)
end

-- Every close path (X, ESC, slash-toggle, :Close, :CloseAll) ends in the window being HIDDEN, but only the
-- X fires the AceGUI OnClose — :Close defers to a RefreshOnUpdate that just :Hide()s the frame. So also fire
-- app.onClose on the underlying frame's OnHide, guarded once per frame instance, to catch them all. Ace's
-- refresh/re-Open path never hides, so OnHide fires only on real closes. Idempotent with chainClose above.
local function hookHide(self, appName, widget)
    local frame = widget and widget.frame
    if not (frame and frame.HookScript) or frame.__badgerHideHooked then
        return
    end
    frame.__badgerHideHooked = true
    frame:HookScript("OnHide", function()
        local app = self.apps[appName]
        if app and app.onClose then
            app.onClose(appName)
        end
    end)
end

-- Open (building Ace's own frame if needed) and best-effort seed the status bar. Ace overwrites the
-- status text on validation, so this is only the initial hint.
function lib:Open(appName)
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:Open(appName)

    local app = self.apps[appName]
    local frame = dialog.OpenFrames[appName]
    if frame and app and app.status then
        frame:SetStatusText(app.status)
    end
    polishTree(frame)
    polishStatusBar(frame)
    polishHeader(frame, app)
    chainClose(self, appName, frame)
    hookHide(self, appName, frame)
end

function lib:Close(appName)
    LibStub("AceConfigDialog-3.0"):Close(appName)
end

function lib:CloseAll()
    LibStub("AceConfigDialog-3.0"):CloseAll()
end

function lib:IsOpen(appName)
    return LibStub("AceConfigDialog-3.0").OpenFrames[appName] ~= nil
end

function lib:Toggle(appName)
    if self:IsOpen(appName) then
        self:Close(appName)
    else
        self:Open(appName)
    end
end

-- Open the addon's Blizzard settings entry. No-op unless it was registered with blizzard=true.
function lib:OpenBlizzard(appName)
    local app = self.apps[appName]
    if not (app and app.blizCategory) then
        return
    end
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(app.blizCategory)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(app.blizCategory)
    end
end
