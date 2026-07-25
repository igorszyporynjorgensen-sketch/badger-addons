local _, ns = ...

-- Pure scenario data for the sim driver: a scripted fight the sim replays through the WO-010 engine — a
-- (t, healthFraction) curve, ability pop events, and optional immune windows (which drive the
-- estimator's damageable = false). No WoW API. Consumed by src/sim/sim.lua and the specs.

-- Is time `t` inside any immune window? (immune may be nil/empty.)
local function inImmune(immune, t)
    if not immune then
        return false
    end
    for i = 1, #immune do
        local w = immune[i]
        if t >= w.from and t < w.to then
            return true
        end
    end
    return false
end

-- Build a health-over-time curve at 1s steps: health declines at ~0.03/s, but stays FLAT inside any
-- immune window (the boss can't be damaged), so the sim exercises the estimator's pause.
local function buildSamples(duration, immune)
    local samples = {}
    local h = 1.0
    for t = 0, duration do
        samples[#samples + 1] = { t = t, h = h }
        if not inImmune(immune, t) then
            h = h - 0.03
            if h < 0 then
                h = 0
            end
        end
    end
    return samples
end

local WARRIOR_IMMUNE = { { from = 18, to = 23 } }

-- A representative warrior burst kill: steady damage, a 5s immune "phase" (t=18–22), and two cooldowns
-- popped (Death Wish at 5s, Earthstrike at 15s).
local warriorBurst = {
    name = "Warrior burst",
    duration = 39,
    immune = WARRIOR_IMMUNE,
    samples = buildSamples(39, WARRIOR_IMMUNE),
    pops = {
        { id = "deathwish", at = 5, duration = 30, cooldown = 180, offset = 0 },
        { id = "earthstrike", at = 15, duration = 20, cooldown = 120, offset = 0 },
    },
}

ns.SimScenario = {
    warriorBurst = warriorBurst,
    inImmune = inImmune,
}
