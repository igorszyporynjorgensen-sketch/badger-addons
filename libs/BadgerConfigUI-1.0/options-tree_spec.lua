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

    it("injects the subtitle description below the banner when opts.banner has one", function()
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            banner = { title = "T", subtitle = "S" },
        })
        local sub = normalized.args.general.args.badgerBannerSub
        assert.is_table(sub)
        assert.equals("medium", sub.fontSize)
        assert.equals("S", sub.name)
    end)

    it("builds a full-width spacer description above the first option", function()
        local arg = ns.BadgerConfigUIOptionsTree.spacerArg(0.002)
        assert.equals("description", arg.type)
        assert.equals("full", arg.width)
        assert.equals(0.002, arg.order)
    end)

    it("injects a header/body spacer between the header block and the options", function()
        local root = {
            name = "Root",
            type = "group",
            args = { general = { type = "group", name = "General", args = {} } },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            banner = { title = "T", subtitle = "S" },
        })
        local spacer = normalized.args.general.args.badgerBannerSpacer
        assert.is_table(spacer)
        assert.equals("description", spacer.type)
        -- Sits below the subtitle (0.001) and above any real option (>= 1).
        assert.is_true(spacer.order > 0.001 and spacer.order < 1)
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

    it("injects an order-0 banner into a non-inline page, preserving its args", function()
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
        local banner = normalized.args.general.args.badgerBanner
        assert.is_table(banner)
        assert.equals("description", banner.type)
        assert.equals(0, banner.order)
        assert.is_truthy(banner.name:find("Root", 1, true))
        assert.is_table(normalized.args.general.args.enabled)
    end)

    it("uses a custom opts.banner title for the injected banner", function()
        local root = {
            type = "group",
            name = "Root",
            args = {
                general = { type = "group", name = "General", args = {} },
            },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {
            banner = { title = "Custom Title" },
        })
        assert.is_truthy(
            normalized.args.general.args.badgerBanner.name:find("Custom Title", 1, true)
        )
    end)

    it("does not banner an inline group", function()
        local root = {
            type = "group",
            name = "Root",
            args = {
                inlineBits = {
                    type = "group",
                    name = "Inline",
                    inline = true,
                    args = {},
                },
            },
        }
        local normalized = ns.BadgerConfigUIOptionsTree.normalize(root, {})
        assert.is_nil(normalized.args.inlineBits.args.badgerBanner)
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
        assert.is_nil(root.args.general.args.badgerBanner)
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
