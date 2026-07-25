local _, ns = ...

-- Deterministic warrior preview scenario (WO-018). Unlike a live fight there is no estimator noise — the
-- sim exists to DEMONSTRATE the display, so TTK is scripted (see src/sim/sim.lua) and the utility bars are
-- steady on a fixed timeline. A clean 50s time-to-kill counting down to 0, with the two example on-use
-- cooldowns fired at their optimal moments. No WoW API; consumed by src/sim/sim.lua and the specs.
--
--   total   — the whole fight in seconds (the fixed-timeline scale the bars are drawn against).
--   pops[i] — { id, name, duration, fireTTK, cooldown, offset }: fired when TTK hits `fireTTK`
--             ("N seconds left"); duration/cooldown drive the bar length + planned pop-lines.

local warriorBurst = {
    name = "Warrior burst",
    total = 50,
    -- Death Wish is fired ON TIME (fireTTK == its optimal 30s-left) → waiting → used, no green window.
    -- Earthstrike is fired 4s LATE (optimal is 20s-left via duration, but used at 16s-left) → its bar shows
    -- ~4s of green ("ready, fire now!") before it turns used — a picture of being late.
    pops = {
        {
            id = "deathwish",
            name = "Death Wish",
            duration = 30,
            fireTTK = 30,
            cooldown = 180,
            offset = 0,
        },
        {
            id = "earthstrike",
            name = "Earthstrike",
            duration = 20,
            fireTTK = 16,
            cooldown = 120,
            offset = 0,
        },
    },
}

ns.SimScenario = {
    warriorBurst = warriorBurst,
}
