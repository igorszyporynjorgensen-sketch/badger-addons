local _, ns = ...

-- The static warrior master table: the curated, Wowhead-verified on-use cooldowns from
-- docs/reference/warrior-ttk-cooldowns.md. DATA only (no WoW API). The list is static and complete — the
-- character scan (abilities.lua) only annotates which are currently available; it never shrinks this.
-- Entry: { id, idType = "spell"|"item", name, kind, category, duration (s|nil), cooldown (s|nil) }.
-- `kind` drives availability: spell → known; trinket → equipped; consumable/engineering → in bags.

ns.AbilityTable = {
    -- On-use trinkets (equipped)
    {
        id = 21180,
        idType = "item",
        name = "Earthstrike",
        kind = "trinket",
        category = "attackpower",
        duration = 20,
        cooldown = 120,
    },
    {
        id = 23041,
        idType = "item",
        name = "Slayer's Crest",
        kind = "trinket",
        category = "attackpower",
        duration = 20,
        cooldown = 120,
    },
    {
        id = 22954,
        idType = "item",
        name = "Kiss of the Spider",
        kind = "trinket",
        category = "haste",
        duration = 15,
        cooldown = 120,
    },
    {
        id = 23570,
        idType = "item",
        name = "Jom Gabbar",
        kind = "trinket",
        category = "attackpower",
        duration = 20,
        cooldown = 120,
    },
    {
        id = 19949,
        idType = "item",
        name = "Zandalarian Hero Medallion",
        kind = "trinket",
        category = "damage",
        duration = 20,
        cooldown = 120,
    },
    {
        id = 21670,
        idType = "item",
        name = "Badge of the Swarmguard",
        kind = "trinket",
        category = "armorpen",
        duration = 30,
        cooldown = 180,
    },
    {
        id = 20130,
        idType = "item",
        name = "Diamond Flask",
        kind = "trinket",
        category = "strength",
        duration = 60,
        cooldown = 360,
    },
    -- Class abilities (known / talented)
    {
        id = 12328,
        idType = "spell",
        name = "Death Wish",
        kind = "ability",
        category = "damage",
        duration = 30,
        cooldown = 180,
    },
    {
        id = 1719,
        idType = "spell",
        name = "Recklessness",
        kind = "ability",
        category = "crit",
        duration = 15,
        cooldown = 1800,
    },
    -- Racials (known if your race)
    {
        id = 20572,
        idType = "spell",
        name = "Blood Fury",
        kind = "racial",
        category = "attackpower",
        duration = 15,
        cooldown = 120,
    },
    {
        id = 20554,
        idType = "spell",
        name = "Berserking",
        kind = "racial",
        category = "haste",
        duration = 10,
        cooldown = 180,
    },
    -- Consumables (in bags)
    {
        id = 13442,
        idType = "item",
        name = "Mighty Rage Potion",
        kind = "consumable",
        category = "strength",
        duration = 20,
        cooldown = 120,
    },
    {
        id = 12450,
        idType = "item",
        name = "Juju Flurry",
        kind = "consumable",
        category = "haste",
        duration = 20,
        cooldown = 60,
    },
    {
        id = 10646,
        idType = "item",
        name = "Goblin Sapper Charge",
        kind = "engineering",
        category = "damage",
        duration = nil,
        cooldown = 300,
    },
}
