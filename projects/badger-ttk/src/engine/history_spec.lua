local mock = require("tools.wow-mock.init")

describe("History", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/history.lua")
    end)

    it("returns nil for an unrecorded (level, key)", function()
        assert.is_nil(ns.History.rate({}, 60, "123"))
    end)

    it("records and reads back a rate, keyed by level then key", function()
        local store = {}
        ns.History.record(store, 60, "123", 0.05)
        assert.equals(0.05, ns.History.rate(store, 60, "123"))
        -- a different level is a separate bucket
        assert.is_nil(ns.History.rate(store, 20, "123"))
    end)

    it("running-means repeated kills of the same target", function()
        local store = {}
        ns.History.record(store, 60, "wolf", 0.10)
        ns.History.record(store, 60, "wolf", 0.20)
        assert.is_true(math.abs(ns.History.rate(store, 60, "wolf") - 0.15) < 1e-9) -- mean of 0.10, 0.20
    end)

    it("ignores non-positive or missing rates", function()
        local store = {}
        ns.History.record(store, 60, "x", 0)
        ns.History.record(store, 60, "x", nil)
        assert.is_nil(ns.History.rate(store, 60, "x"))
    end)

    it("keeps adapting after many samples (weight cap → EMA)", function()
        local store = {}
        for _ = 1, 50 do
            ns.History.record(store, 60, "y", 1.0) -- settle high
        end
        local before = ns.History.rate(store, 60, "y")
        ns.History.record(store, 60, "y", 0.0 + 0.01) -- a much lower kill still moves the mean
        assert.is_true(ns.History.rate(store, 60, "y") < before)
    end)
end)
