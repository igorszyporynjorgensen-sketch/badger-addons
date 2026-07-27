-- Pure logic — no WoW API. Loaded through the mock's (addonName, ns) contract exactly as the client
-- loads it; no install() needed, since options-tree touches no stubbed global.
local mock = require("tools.wow-mock.init")

describe("BadgerConfigUI options-tree", function()
    local ns

    before_each(function()
        ns = mock.load("libs/BadgerConfigUI-1.0/options-tree.lua")
    end)

    it("builds a full-width, large description banner with the title and brand colour", function()
        local OptionsTree = ns.BadgerConfigUIOptionsTree
        local arg = OptionsTree.bannerArg({ title = "Badger Arena" }, 0)
        assert.equals("description", arg.type)
        assert.equals("full", arg.width)
        assert.equals("large", arg.fontSize)
        assert.equals(0, arg.order)
        assert.is_truthy(arg.name:find("Badger Arena", 1, true))
        assert.is_truthy(arg.name:find(OptionsTree.BRAND_COLOR, 1, true))
    end)

    it(
        "keeps the subtitle OUT of the title banner (it is a separate, smaller description)",
        function()
            local arg = ns.BadgerConfigUIOptionsTree.bannerArg({
                title = "Badger Arena",
                subtitle = "Arena info",
            }, 0)
            assert.is_nil(arg.name:find("Arena info", 1, true)) -- title banner is title-only
        end
    )

    it("builds a medium-font subtitle description (smaller than the large title)", function()
        local arg = ns.BadgerConfigUIOptionsTree.subtitleArg("Arena info", 0.001)
        assert.equals("description", arg.type)
        assert.equals("medium", arg.fontSize)
        assert.equals("Arena info", arg.name)
    end)

    it("injects the title + subtitle as ROOT-LEVEL header args (one global header)", function()
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = { title = "T", subtitle = "S" },
        })
        -- At root, NOT injected into each page.
        assert.is_table(normalized.args.badgerHeaderTitle)
        assert.is_truthy(normalized.args.badgerHeaderTitle.name:find("T", 1, true))
        assert.is_table(normalized.args.badgerHeaderSub)
        assert.equals("medium", normalized.args.badgerHeaderSub.fontSize)
        assert.equals("S", normalized.args.badgerHeaderSub.name)
        assert.is_nil(normalized.args.general.args.badgerHeaderTitle) -- not per-page
    end)

    it("OMITS the text title/subtitle when header.image is set (the raw band owns them)", function()
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = {
                title = "T",
                subtitle = "S",
                image = "Interface\\AddOns\\BadgerTTK\\Media\\badger-master",
                controls = { { type = "toggle", name = "Show preview" } },
            },
        })
        -- No description banner/subtitle — the consumer draws the two-column brand band instead.
        assert.is_nil(normalized.args.badgerHeaderTitle)
        assert.is_nil(normalized.args.badgerHeaderSub)
        -- Controls stay native, first in order (nothing precedes them), and the spacer still trails.
        assert.is_table(normalized.args.badgerHeaderCtrl1)
        assert.equals(1, normalized.args.badgerHeaderCtrl1.order)
        assert.is_table(normalized.args.badgerHeaderSpacer)
        assert.is_true(
            normalized.args.badgerHeaderSpacer.order > normalized.args.badgerHeaderCtrl1.order
        )
    end)

    it("still emits the text banner when header has NO image (badger-arena path)", function()
        local root = { name = "Root", type = "group", args = { g = { type = "group", args = {} } } }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = { title = "T", subtitle = "S" },
        })
        assert.is_table(normalized.args.badgerHeaderTitle)
        assert.is_table(normalized.args.badgerHeaderSub)
    end)

    it("builds a full-width spacer description", function()
        local arg = ns.BadgerConfigUIOptionsTree.spacerArg(9)
        assert.equals("description", arg.type)
        assert.equals("full", arg.width)
        assert.equals(9, arg.order)
    end)

    it("appends a spacer at the foot of the root header, after the controls", function()
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = {
                title = "T",
                subtitle = "S",
                controls = { { type = "toggle", name = "C" } },
            },
        })
        local spacer = normalized.args.badgerHeaderSpacer
        assert.is_table(spacer)
        assert.equals("description", spacer.type)
        -- Ordered after the title(1)/subtitle(2)/control(3).
        assert.is_true(spacer.order > normalized.args.badgerHeaderCtrl1.order)
    end)

    it("places header controls at root with an injected order, copied (not mutated)", function()
        local ctrl = { type = "toggle", name = "Show preview", get = function() end }
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = { title = "T", controls = { ctrl } },
        })
        local placed = normalized.args.badgerHeaderCtrl1
        assert.is_table(placed)
        assert.equals("toggle", placed.type)
        assert.equals("Show preview", placed.name)
        assert.equals(ctrl.get, placed.get) -- get carried by reference, never called
        assert.is_not_nil(placed.order)
        assert.is_nil(ctrl.order) -- caller's control table left unmutated
    end)

    it("supports opts.banner as a back-compat alias for opts.header", function()
        local root = { name = "Root", type = "group", args = {} }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            banner = { title = "Aliased", subtitle = "Sub" },
        })
        assert.is_truthy(normalized.args.badgerHeaderTitle.name:find("Aliased", 1, true))
        assert.equals("Sub", normalized.args.badgerHeaderSub.name)
    end)

    it("passes banner image fields straight through", function()
        local coords = { 0, 1, 0, 1 }
        local arg = ns.BadgerConfigUIOptionsTree.bannerArg({
            title = "Badger Arena",
            image = "art\\banner",
            imageCoords = coords,
            imageWidth = 256,
            imageHeight = 64,
        }, 0)
        assert.equals("art\\banner", arg.image)
        assert.equals(coords, arg.imageCoords)
        assert.equals(256, arg.imageWidth)
        assert.equals(64, arg.imageHeight)
    end)

    it("defaults to the Badger title and order 0 when called bare", function()
        local arg = ns.BadgerConfigUIOptionsTree.bannerArg()
        assert.is_truthy(arg.name:find("Badger", 1, true))
        assert.equals(0, arg.order)
    end)

    it("forces childGroups to a tree", function()
        local root = { type = "group", name = "Root", args = {} }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {})
        assert.equals("tree", normalized.childGroups)
    end)

    it("defaults the header title to root.name, and leaves child pages un-injected", function()
        local root = {
            type = "group",
            name = "Root",
            args = {
                general = {
                    type = "group",
                    name = "General",
                    args = { enabled = { type = "toggle", name = "Enabled" } },
                },
            },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {})
        local title = normalized.args.badgerHeaderTitle
        assert.is_table(title)
        assert.equals("description", title.type)
        assert.is_truthy(title.name:find("Root", 1, true)) -- default = root.name
        -- The page keeps its own args and gets NO injected header (it's global now).
        assert.is_table(normalized.args.general.args.enabled)
        assert.is_nil(normalized.args.general.args.badgerHeaderTitle)
    end)

    it("uses a custom header title for the root header", function()
        local root = {
            type = "group",
            name = "Root",
            args = {
                general = { type = "group", name = "General", args = {} },
            },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            header = { title = "Custom Title" },
        })
        assert.is_truthy(normalized.args.badgerHeaderTitle.name:find("Custom Title", 1, true))
    end)

    it("leaves the caller's root and nested tables unmutated", function()
        local root = {
            type = "group",
            name = "Root",
            args = {
                general = {
                    type = "group",
                    name = "General",
                    args = { enabled = { type = "toggle", name = "Enabled" } },
                },
            },
        }
        ns.BadgerConfigUIOptionsTree.normalize(root, {})
        assert.is_nil(root.childGroups)
        assert.is_nil(root.args.badgerHeaderTitle) -- header went onto the COPY, not the caller's root
        assert.is_nil(root.args.badgerHeaderSpacer)
    end)

    it("blizStub builds a group whose open button runs the supplied opener", function()
        local calls = 0
        local stub = ns.BadgerConfigUIOptionsTree.blizStub("Badger Arena", function()
            calls = calls + 1
        end)
        assert.equals("group", stub.type)
        assert.equals("execute", stub.args.open.type)
        stub.args.open.func()
        assert.equals(1, calls)
    end)
end)
