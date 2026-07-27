local _, ns = ...

-- Pure options-tree assembly for BadgerConfigUI (Variant B: full-height nav tree, banner over the
-- content pane). String and table work only — no LibStub, no WoW API — so every branch is unit-testable
-- off-client through the (addonName, ns) contract. The LibStub glue captures this table as an upvalue
-- after the XML loads this file first. Exports ns.BadgerConfigUIOptionsTree.
local OptionsTree = {}

-- Badger brand colour, RRGGBB with no alpha. Wrapped as "|cff"..BRAND_COLOR..text.."|r".
OptionsTree.BRAND_COLOR = "f5c542"

local function colour(text)
    return "|cff" .. OptionsTree.BRAND_COLOR .. text .. "|r"
end

local function shallowCopy(t)
    local copy = {}
    for key, value in pairs(t) do
        copy[key] = value
    end
    return copy
end

-- Build the global-header TITLE element: a large-font, full-width type="description". The subtitle is a
-- SEPARATE, smaller description (see subtitleArg) so it reads smaller than the title. The image* fields are
-- passed straight through so real artwork later is a data change, not code. `banner` may carry {title,
-- subtitle, image, imageCoords, imageWidth, imageHeight}; title -> "Badger".
function OptionsTree.bannerArg(banner, order)
    banner = banner or {}
    return {
        type = "description",
        name = colour(banner.title or "Badger"),
        fontSize = "large",
        width = "full",
        image = banner.image,
        imageCoords = banner.imageCoords,
        imageWidth = banner.imageWidth,
        imageHeight = banner.imageHeight,
        order = order or 0,
    }
end

-- The banner SUBTITLE — a medium-font description, deliberately smaller than the large title above it.
function OptionsTree.subtitleArg(subtitle, order)
    return {
        type = "description",
        name = subtitle,
        fontSize = "medium",
        width = "full",
        order = order or 0,
    }
end

-- A blank, full-width spacer. A large-font single space reads as clear vertical margin. Used at the foot
-- of the global header so it sits clear of the tree below.
function OptionsTree.spacerArg(order)
    return {
        type = "description",
        name = " ",
        fontSize = "large",
        width = "full",
        order = order or 0,
    }
end

-- A shallow copy of an option table with its order set — so a header control the CALLER supplied is placed
-- at a known order without mutating the caller's table (its get/set are carried by reference, never called).
local function withOrder(option, order)
    local copy = shallowCopy(option)
    copy.order = order
    return copy
end

-- Return a normalized copy of `root` with childGroups forced to "tree" and ONE global header injected as
-- root-level (non-group) args — which AceConfigDialog feeds ABOVE the left-nav tree, on every page, by its
-- own design (it feeds a group's own controls before building the tree, and skips non-inline subgroups).
-- So the header is a single persistent band for the whole window, not the old per-page banner. The header
-- is `opts.header` = { title, subtitle, image…, controls = { <option tables> } }; `opts.banner` is kept as
-- a back-compat alias (header wins). NON-MUTATING: root and its .args are shallow-copied; child pages are
-- left untouched; supplied control tables are copied (only their order is set).
function OptionsTree.normalize(root, opts)
    opts = opts or {}
    local header = opts.header or opts.banner or { title = root.name }

    local normalized = shallowCopy(root)
    normalized.childGroups = root.childGroups or "tree"

    if type(root.args) == "table" then
        local args = shallowCopy(root.args)
        -- Root-level header items. Orders only sort the header among itself (the tree is added after all of
        -- these regardless of order); child config nodes are groups, so they never collide with these keys.
        args.badgerHeaderTitle = OptionsTree.bannerArg(header, 1)
        local order = 2
        if header.subtitle then
            args.badgerHeaderSub = OptionsTree.subtitleArg(header.subtitle, order)
            order = order + 1
        end
        if type(header.controls) == "table" then
            for i = 1, #header.controls do
                args["badgerHeaderCtrl" .. i] = withOrder(header.controls[i], order)
                order = order + 1
            end
        end
        args.badgerHeaderSpacer = OptionsTree.spacerArg(order) -- gap between the header and the tree
        normalized.args = args
    end

    return normalized
end

-- Build the Blizzard-panel stub group: a single execute button whose func is the supplied opener,
-- plus a note pointing the user at the dedicated Badger window.
function OptionsTree.blizStub(title, openFunc)
    return {
        type = "group",
        name = title,
        args = {
            open = {
                type = "execute",
                name = "Open " .. title,
                func = openFunc,
                order = 1,
            },
            note = {
                type = "description",
                name = "Configuration opens in a dedicated Badger window.",
                order = 2,
            },
        },
    }
end

ns.BadgerConfigUIOptionsTree = OptionsTree
