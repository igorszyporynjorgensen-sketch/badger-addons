local mock = require("tools.wow-mock.init")

describe("arena-detect", function()
    local ns, wow

    before_each(function()
        wow = mock.install()
        ns = mock.load("projects/badger-arena/src/modules/arena-detect.lua")
    end)

    after_each(function()
        mock.reset()
    end)

    it("starts outside an arena", function()
        assert.is_false(ns.ArenaDetect.isInArena())
    end)

    it("detects an active arena once enabled", function()
        wow.state.activeArena = true
        ns.ArenaDetect.enable()
        assert.is_true(ns.ArenaDetect.isInArena())
    end)

    it("notifies listeners on the transition into an arena", function()
        local seen = {}
        ns.ArenaDetect.onStateChange(function(inArena)
            table.insert(seen, inArena)
        end)
        ns.ArenaDetect.enable() -- evaluates once while still outside: no notification
        wow.state.activeArena = true
        wow.fireEvent("ZONE_CHANGED_NEW_AREA")
        assert.same({ true }, seen)
        assert.is_true(ns.ArenaDetect.isInArena())
    end)

    it("does not re-notify when the state is unchanged", function()
        local count = 0
        ns.ArenaDetect.onStateChange(function()
            count = count + 1
        end)
        wow.state.activeArena = true
        ns.ArenaDetect.enable() -- transition false -> true: one notification
        wow.fireEvent("PLAYER_ENTERING_WORLD") -- still true: no further notification
        assert.equals(1, count)
    end)
end)
