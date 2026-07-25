-- Shared Busted harness: a minimal stand-in for the WoW client so pure logic and event-driven
-- modules can be unit-tested off-client.
--
-- It installs the slice of the WoW API our specs touch as globals. Those are written through `_G`
-- on purpose: luacheck then sees field writes on the standard `_G` table rather than new global
-- definitions, so the mock never trips the no-global-leak rule the addon code is held to.
--
-- A spec drives game state and fires events; `reset()` restores `_G`. Extend the surface as specs
-- need more of the API.

local M = {}

local G = _G
local saved = {} -- global name -> { present = bool, value = any }, for restore on reset()
local frames = {} -- every CreateFrame() result, so fireEvent() can dispatch to it
local state = {} -- spec-controlled game state

-- WoW flavor -> the API surface it exposes. `projectId` is the value the real client puts in the
-- global WOW_PROJECT_ID; `arena = true` means the arena API globals exist (TBC and up; absent on
-- Classic Era / Vanilla, where calling them is a nil error — exactly the surface a hardcore spec sees).
-- Hardcore is not a distinct flavor here: it runs on the Vanilla client (WOW_PROJECT_CLASSIC) and is a
-- runtime game-state, not a project id.
local FLAVORS = {
    vanilla = { projectId = 2 }, -- WOW_PROJECT_CLASSIC (Classic Era, incl. Hardcore): no arena API
    tbc = { projectId = 5, arena = true }, -- WOW_PROJECT_BURNING_CRUSADE_CLASSIC
}

local function setGlobal(name, value)
    if saved[name] == nil then
        saved[name] = { present = G[name] ~= nil, value = G[name] }
    end
    G[name] = value
end

local function makeFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:RegisterAllEvents()
        self.allEvents = true
    end
    function frame:SetScript(handler, fn)
        self.scripts[handler] = fn
    end
    function frame:GetScript(handler)
        return self.scripts[handler]
    end
    function frame:Show()
        self.shown = true
    end
    function frame:Hide()
        self.shown = false
    end
    frame.SetPoint = function() end
    frame.SetSize = function() end
    frames[#frames + 1] = frame
    return frame
end

-- Dispatch an event to every frame registered for it (or registered for all events).
function M.fireEvent(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] or frame.allEvents then
            local fn = frame.scripts.OnEvent
            if fn then
                fn(frame, event, ...)
            end
        end
    end
end

-- Install the mocked WoW API. `opts.flavor` selects the client surface ("tbc" default, so existing
-- specs keep the arena API); returns a handle for driving state and firing events.
function M.install(opts)
    local flavor = (opts and opts.flavor) or "tbc"
    local spec = assert(FLAVORS[flavor], "wow-mock: unknown flavor '" .. tostring(flavor) .. "'")

    state = { activeArena = false, numArenaOpponents = 0, time = 0 }
    frames = {}

    -- Common surface — present on every flavor.
    setGlobal("CreateFrame", function()
        return makeFrame()
    end)
    setGlobal("GetTime", function()
        return state.time
    end)
    setGlobal("C_Timer", {
        After = function(_, fn)
            fn()
        end,
    })
    setGlobal("tinsert", table.insert)
    setGlobal("tremove", table.remove)
    setGlobal("wipe", function(t)
        for key in pairs(t) do
            t[key] = nil
        end
        return t
    end)
    setGlobal("format", string.format)
    setGlobal("print", function() end)

    -- Flavor constants: the numbers exist on every client; only WOW_PROJECT_ID's value differs.
    setGlobal("WOW_PROJECT_MAINLINE", 1)
    setGlobal("WOW_PROJECT_CLASSIC", 2)
    setGlobal("WOW_PROJECT_BURNING_CRUSADE_CLASSIC", 5)
    setGlobal("WOW_PROJECT_ID", spec.projectId)

    -- Arena surface: TBC-and-up only. Absent on Vanilla, so an addon that calls these on the wrong
    -- flavor errors on nil — matching the real client.
    if spec.arena then
        setGlobal("IsActiveBattlefieldArena", function()
            return state.activeArena
        end)
        setGlobal("GetNumArenaOpponents", function()
            return state.numArenaOpponents
        end)
    end

    return {
        state = state,
        frames = frames,
        flavor = flavor,
        fireEvent = M.fireEvent,
        advanceTime = function(seconds)
            state.time = state.time + seconds
        end,
    }
end

-- Restore `_G` to its pre-install state.
function M.reset()
    for name, prev in pairs(saved) do
        if prev.present then
            G[name] = prev.value
        else
            G[name] = nil
        end
    end
    saved = {}
    frames = {}
    state = {}
end

-- Load a WoW addon source file the way the client does — passing (addonName, ns) as varargs — and
-- return the populated namespace. Paths are relative to the repo root (Busted's working directory).
function M.load(path, ns)
    ns = ns or {}
    local chunk = assert(loadfile(path))
    chunk("BadgerArena", ns)
    return ns
end

return M
