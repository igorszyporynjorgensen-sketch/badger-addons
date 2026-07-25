local _, ns = ...

-- Thin LibStub glue for BadgerConfigUI-1.0 — the untestable Ace3/frame edge, so it carries NO spec
-- (mirroring core.lua/config.lua). Every branch worth testing lives in the two sibling pure files
-- (options-tree.lua, frame-size.lua) which the XML loads FIRST; this file captures them off `ns` as
-- upvalues. It is the only file here that calls LibStub or reads the Blizzard Settings/Interface
-- globals.
--
-- Obtain the shared instance with:  local BCUI = LibStub("BadgerConfigUI-1.0")
-- Consumers register a UNIQUE appName (their ADDON_NAME) so status/registry tables never collide.

local MAJOR, MINOR = "BadgerConfigUI-1.0", 2
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

-- Register an addon's options table, seed its dialog size, and optionally add a Blizzard-panel stub.
-- opts = {banner, width, height, title, status, blizzard}. Returns the normalized options table.
function lib:Register(appName, options, opts)
    opts = opts or {}

    local normalized = OptionsTree.normalize(options, opts)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, normalized)

    local width, height = FrameSize.resolve(opts)
    LibStub("AceConfigDialog-3.0"):SetDefaultSize(appName, width, height)

    local app = {
        title = opts.title or options.name or appName,
        status = opts.status,
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
