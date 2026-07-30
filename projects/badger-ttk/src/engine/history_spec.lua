local mock = require("tools.wow-mock.init")

describe("History (D-012 record schema)", function()
    local ns

    before_each(function()
        ns = mock.load("projects/badger-ttk/src/engine/history.lua")
    end)

    local DAY = 24 * 60 * 60
    local function rec(over)
        local r = {
            name = "x",
            level = 60,
            dur = 20,
            size = 40,
            comp = {},
            diff = "normal",
            src = "local",
            when = 1000,
        }
        for k, v in pairs(over or {}) do
            r[k] = v
        end
        return r
    end
    local function store()
        return { encounter = {}, creature = {} }
    end

    describe("ensureShape", function()
        it("creates the split shape from nil/empty", function()
            local s = ns.History.ensureShape(nil)
            assert.is_table(s.encounter)
            assert.is_table(s.creature)
        end)
        it("wipes the pre-D-012 running-mean shape (unrecoverable into records)", function()
            local old = { [60] = { ["123"] = { n = 5, rate = 0.05 } } }
            local s = ns.History.ensureShape(old)
            assert.is_table(s.encounter)
            assert.is_table(s.creature)
            assert.is_nil(s[60])
        end)
        it(
            "strips old-shape residue even when AceDB has injected the default sub-tables",
            function()
                -- AceDB copyDefaults leaves the old [level] keys ALONGSIDE freshly-injected encounter/creature,
                -- so presence of the two spaces is not proof of cleanliness (WO-072 review, finding #4).
                local mixed =
                    { [60] = { ["9"] = { n = 3, rate = 0.1 } }, encounter = {}, creature = {} }
                local s = ns.History.ensureShape(mixed)
                assert.is_nil(s[60]) -- the stale running-mean data is gone
                assert.is_table(s.encounter)
                assert.is_table(s.creature)
            end
        )
        it("keeps an already-correct store", function()
            local s = store()
            s.creature["9"] = { rec() }
            assert.equals(s, ns.History.ensureShape(s))
        end)
    end)

    describe("record", function()
        it("appends a per-kill record under (space, id)", function()
            local s = store()
            ns.History.record(s, "encounter", 663, rec())
            assert.equals(1, #s.encounter[663])
            assert.equals("normal", s.encounter[663][1].diff)
            assert.is_nil(s.creature[663]) -- the two identity spaces never collide
        end)

        it("rejects malformed records (no when / no positive dur / bad space)", function()
            local s = store()
            local noWhen = rec()
            noWhen.when = nil
            ns.History.record(s, "encounter", 663, noWhen)
            ns.History.record(s, "encounter", 663, rec({ dur = 0 }))
            ns.History.record(s, "nope", 663, rec()) -- unknown space table
            assert.is_nil(s.encounter[663])
        end)

        it("keeps only the most-recent 50 by `when` (evicts oldest, never newest)", function()
            local s = store()
            for i = 1, 60 do
                ns.History.record(s, "creature", "wolf", rec({ when = i, dur = i }))
            end
            local list = s.creature.wolf
            assert.equals(50, #list)
            assert.equals(11, list[1].when) -- 1..10 evicted
            assert.equals(60, list[#list].when) -- newest kept
        end)

        it("drops records older than 180 days relative to the newest", function()
            local s = store()
            ns.History.record(s, "creature", "old", rec({ when = 0 }))
            ns.History.record(s, "creature", "old", rec({ when = 200 * DAY })) -- newest; 0 is now >180d stale
            local list = s.creature.old
            assert.equals(1, #list)
            assert.equals(200 * DAY, list[1].when)
        end)
    end)

    describe("rate", function()
        it("returns nil for an unrecorded identity", function()
            assert.is_nil(ns.History.rate(store(), "encounter", 999))
            assert.is_nil(ns.History.rate(store(), "creature", "nope"))
        end)

        it("derives rate = 1/dur (health fraction per second) from a single record", function()
            local s = store()
            ns.History.record(s, "encounter", 663, rec({ dur = 25 }))
            assert.is_true(math.abs(ns.History.rate(s, "encounter", 663) - (1 / 25)) < 1e-9)
        end)

        it("recency-weights: a recent kill leads over an old one", function()
            local s = store()
            ns.History.record(s, "creature", "w", rec({ when = 1, dur = 100 })) -- old, slow (rate 0.01)
            ns.History.record(s, "creature", "w", rec({ when = 2, dur = 10 })) -- recent, fast (rate 0.10)
            local r = ns.History.rate(s, "creature", "w")
            -- weights 1 (newest 0.10) + 0.8 (older 0.01) → biased toward the recent 0.10
            assert.is_true(r > 0.05, "expected recency bias toward the recent fast kill, got " .. r)
        end)

        it("prefers records matching the current group size, else uses all", function()
            local s = store()
            ns.History.record(s, "creature", "w", rec({ when = 1, dur = 10, size = 1 })) -- solo, fast
            ns.History.record(s, "creature", "w", rec({ when = 2, dur = 100, size = 40 })) -- raid, slow
            -- asking as a solo player → only the size-1 record counts
            assert.is_true(
                math.abs(ns.History.rate(s, "creature", "w", { size = 1 }) - (1 / 10)) < 1e-9
            )
            -- no size context → both blend (recency toward the size-40 one)
            local both = ns.History.rate(s, "creature", "w")
            assert.is_true(both > (1 / 100) and both < (1 / 10))
        end)
    end)
end)
