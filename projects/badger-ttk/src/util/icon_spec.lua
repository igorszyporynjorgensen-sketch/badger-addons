local mock = require("tools.wow-mock.init")

describe("iconMarkup", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/util/icon.lua")
    end)

    it("wraps a texture in a sized escape", function()
        assert.equals("|TInterface\\ICONS\\Foo:16|t", ns.iconMarkup("Interface\\ICONS\\Foo", 16))
    end)

    it("defaults the size to 0", function()
        assert.equals("|TFoo:0|t", ns.iconMarkup("Foo"))
    end)

    it("returns empty for a missing texture", function()
        assert.equals("", ns.iconMarkup(nil))
    end)
end)
