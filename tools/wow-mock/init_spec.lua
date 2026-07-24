local mock = require("tools.wow-mock.init")

describe("wow-mock", function()
    after_each(function()
        mock.reset()
    end)

    it("installs the arena API and reflects spec-driven state", function()
        local wow = mock.install()
        assert.is_false(IsActiveBattlefieldArena())
        wow.state.activeArena = true
        assert.is_true(IsActiveBattlefieldArena())
    end)

    it("dispatches events only to frames registered for them", function()
        local wow = mock.install()
        local frame = CreateFrame("Frame")
        local hits = {}
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:SetScript("OnEvent", function(_, event)
            table.insert(hits, event)
        end)
        wow.fireEvent("PLAYER_LOGIN")
        wow.fireEvent("SOMETHING_ELSE")
        assert.same({ "PLAYER_LOGIN" }, hits)
    end)

    it("restores globals on reset", function()
        mock.install()
        assert.is_function(CreateFrame)
        mock.reset()
        assert.is_nil(CreateFrame)
    end)
end)
