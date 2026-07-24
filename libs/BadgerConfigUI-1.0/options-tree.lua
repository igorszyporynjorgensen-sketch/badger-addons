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

-- Build the banner element for a page's content pane: a large-font, full-width type="description".
-- The image* fields are passed straight through so real artwork later is a data change, not code.
-- `banner` may carry {title, subtitle, image, imageCoords, imageWidth, imageHeight}; title -> "Badger".
function OptionsTree.bannerArg(banner, order)
    banner = banner or {}
    local name = colour(banner.title or "Badger")
    if banner.subtitle then
        name = name .. "\n" .. banner.subtitle
    end
    return {
        type = "description",
        name = name,
        fontSize = "large",
        width = "full",
        image = banner.image,
        imageCoords = banner.imageCoords,
        imageWidth = banner.imageWidth,
        imageHeight = banner.imageHeight,
        order = order or 0,
    }
end

-- Return a normalized copy of `root` with childGroups forced to "tree" and a banner injected at
-- order 0 into every non-inline child group's args. NON-MUTATING: root, each touched page, and its
-- .args are shallow-copied before any write, so the caller's tables are left untouched. Non-group,
-- inline, and non-table args are carried over by reference. `opts.banner` defaults to {title=root.name}.
function OptionsTree.normalize(root, opts)
    opts = opts or {}
    local banner = opts.banner or { title = root.name }

    local normalized = shallowCopy(root)
    normalized.childGroups = root.childGroups or "tree"

    if type(root.args) == "table" then
        local args = shallowCopy(root.args)
        for key, child in pairs(root.args) do
            if type(child) == "table" and child.type == "group" and not child.inline then
                local page = shallowCopy(child)
                page.args = shallowCopy(child.args or {})
                page.args.badgerBanner = OptionsTree.bannerArg(banner, 0)
                args[key] = page
            end
        end
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
