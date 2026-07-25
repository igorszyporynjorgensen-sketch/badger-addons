---
title: Warrior TTK Cooldowns — master data (reference)
type: reference
related:
  - docs/workorders/WO-007-IJ.md
---

# Warrior TTK Cooldowns — curated master data

Source data for **badger-ttk**'s warrior ability model (WO-007 child "Tracked-ability model"). This is
the **static, complete** set of *offensive, finite, timed on-use effects a warrior pops to boost DPS in
a kill window* — deliberately **not** defensives, passives, on-equip/procs, rotational strikes, or
long-duration maintained/pre-pull buffs. Availability (talents/gear/race/profession) is a **live
overlay**, not a filter — the whole list is always shown in config; unavailable entries dim, and
runtime shows a bar only for entries that are **enabled ∩ available**.

**Provenance:** enumerated + adversarially verified against Wowhead Classic (dataEnv=4 tooltip API +
spell pages), 2026-07-25. Target = **Classic Era 1.15.x** (`WOW_PROJECT_CLASSIC`), **not** TBC/WotLK —
several ids differ (see corrections below). Values marked *(live-confirm)* still need a `/reload` aura
check on the real client. Confirmed keep set by the human.

## Keep set (14) — the tracked on-use pops

| Name | id | type | category | dur (s) | cd (s) | sharedCD group | gating | notes |
|---|---|---|---|---|---|---|---|---|
| **Earthstrike** | 21180 | item | attackpower | 20 | 120 | on-use-trinket | — | flat +280 AP · Cenarion Circle exalted quest |
| **Slayer's Crest** | 23041 | item | attackpower | 20 | 120 | on-use-trinket | — | +260 AP use (+64 equip) · Naxx Sapphiron |
| **Kiss of the Spider** | 22954 | item | haste | 15 | 120 | on-use-trinket | — | +20% attack speed · Naxx Maexxna |
| **Jom Gabbar** | 23570 | item | attackpower | 20 | 120 | on-use-trinket | — | **ramps** +65 then +65/2s (~650 peak) — fire early · AQ40 Ouro |
| **Zandalarian Hero Medallion** | 19949 | item | damage | 20 | 120 | on-use-trinket | — | +40 dmg, decays 2/hit (front-loaded) · ZG |
| **Badge of the Swarmguard** | 21670 | item | armorpen | 30 | 180 | — (exempt) | — | stacking −200 armor ×6 · **stacks with a trinket** · AQ40 Sartura |
| **Diamond Flask** | 20130 | item | strength | 60 | 360 | on-use-trinket | Warrior quest | +75 Str + minor heal · long window/CD *(Str value live-confirm)* |
| **Death Wish** | 12328 | spell | damage | 30 | 180 | — | Fury talent | +20% physical dmg (−20% armor/resist) |
| **Recklessness** | 1719 | spell | crit | 15 | 1800 | — | Berserker stance | +100% crit (+20% dmg taken) · ~once/fight |
| **Blood Fury** | 20572 | spell | attackpower | 15 | 120 | — | race: Orc | +25% **base** AP *(dur live-confirm)* |
| **Berserking** | 20554 | spell | haste | 10 | 180 | — | race: Troll | +10–30% haste, ↑ at low HP (warrior buff 26296) *(dur live-confirm)* |
| **Mighty Rage Potion** | 13442 | item | strength | 20 | 120 | **potion** | Alchemy | +60 Str + 45–75 rage |
| **Juju Flurry** | 12450 | item | haste | 20 | 60 | — (not a potion) | — | +3% attack speed · **stacks with a potion** · Winterfall drop |
| **Goblin Sapper Charge** | 10646 | item | damage | — | 300 | — (independent) | Engineering (Goblin) | ~450–750 dmg instant (self-damage) |

## Shared-cooldown groups → lockout behaviour

Popping one member of a group puts its **siblings on the shared cooldown**; the addon should render a
locked-out sibling **dimmed + a lock icon** (it can't be popped until the shared CD clears).

- **`potion`** — all combat potions share **one ~2-min cooldown**; only **one per window**. In the keep
  set only *Mighty Rage Potion* is a potion, but any other combat potion the player drinks locks it (and
  vice-versa). *Juju Flurry is NOT a potion (own CD) — it stacks with a potion.*
- **`on-use-trinket`** — Earthstrike, Slayer's Crest, Kiss of the Spider, Jom Gabbar, Zandalarian Hero
  Medallion, Diamond Flask. **⚠ Open question:** whether Classic Era 1.15 actually enforces a hidden
  shared on-use-trinket cooldown (a later-expansion mechanic) is **unresolved — needs live `/reload`
  verification**. If it does, popping one trinket locks the others; if not, they're independent (you
  only have 2 trinket slots regardless). *Badge of the Swarmguard is exempt either way.*
- **Independent (no lockout):** Badge of the Swarmguard, Goblin Sapper Charge, all racials (Blood
  Fury/Berserking), and the class abilities (Death Wish, Recklessness).

**Implementation:** the addon does **not** model these relations. It reads each entry's **live
usability** (`GetItemCooldown` / `GetSpellCooldown` effective CD, `IsUsableItem` / `IsUsableSpell`) and
dims + lock-icons anything not usable now — so the on-use-trinket question below is **moot at runtime**
(the API reflects whatever the client enforces). `sharedCooldownGroup` above is informational only.

## Runtime visibility (per kind)

A bar renders only when the entry is **usable right now** — or its buff is already active:

- **Abilities / racials** — known/talented (and stance-permitting).
- **On-use items (trinkets etc.)** — currently **equipped** (`GetInventoryItemID` + `PLAYER_EQUIPMENT_CHANGED`).
- **Consumables** — **count in bags > 0** (`GetItemCount` + `BAG_UPDATE`).
- **Active-buff override** — if the entry's buff is currently active, its draining bar shows **regardless**
  of equip/stock (drank the last potion, or swapped a trinket after popping it).

The config list always shows the **full static** set; not-currently-usable entries **dim** there.

## Live `/reload` verification items

- ~~On-use-trinket shared cooldown on Classic Era 1.15~~ — **moot**: the addon reads live usability, so
  it reflects whatever the client enforces without needing to know.
- Buff **durations** rendered `n/a` by the tooltip API: Blood Fury (15s), Berserking (10s), Diamond
  Flask window, Last Stand — confirm via a live aura check.
- Berserking warrior detection: key on base `20554` and/or the 5-rage warrior buff `26296`; never the
  rogue `26297`.
- Consumable buff spellIDs for aura tracking: Mighty Rage 17528/17552, Juju Flurry 16322.

## Classic-Era id corrections (caught by the verify pass)

- **Death Wish = 12328**, **Sweeping Strikes = 12292** — the **reverse** of TBC/WotLK (using the TBC ids
  maps to the wrong spell).
- **Berserking = 20554** (base) / **26296** (5-rage warrior) — **not** 26297 (rogue/energy variant).
- **Earthstrike = 21180** (not 18803).

## Culled / excluded (provenance)

Deliberately out of the tracked set — categories, not exhaustive:

- **Borderline, culled by human ruling:** Retaliation (20230), Sweeping Strikes (12292, cleave),
  Rage/Great Rage Potion (5631/5633, rage-gen only), Bloodrage/Berserker Rage (enablers), Thorium/Iron
  Grenade + Gnomish Death Ray (tiny dmg / self-root / CC).
- **Rotational strikes** (no timed buff): Heroic Strike, Cleave, Slam, Execute, Whirlwind, Mortal
  Strike, Bloodthirst, Shield Slam, Overpower, Revenge.
- **Maintained buffs/debuffs:** Battle Shout, Rend, Sunder Armor, Demoralizing Shout, Thunder Clap,
  Hamstring.
- **Defensives:** Shield Wall, Last Stand, Shield Block; Stoneform; Free Action / Living Action /
  Limited Invulnerability / Restorative potions; Lifegiving Gem; The Burrower's Shell, Zandalarian Hero
  Badge, Arena Grand Master, Fetish of Chitinous Spikes, Petrified Scarab.
- **Utility / CC / mobility:** Charge, Intercept, Pummel, Shield Bash, Disarm, Piercing Howl, War Stomp,
  Intimidating/Challenging/Mocking Shout, Concussion Blow; Tidal Charm, Insignia of the Horde,
  Vanquished Tentacle of C'Thun; Rocket Boots, Gnomish Battle Chicken, Mind Control Cap, Reckless
  Charge; Will of the Forsaken, Cannibalize, Shadowmeld, Escape Artist, Perception.
- **Long-duration pre-pull buffs:** Winterfall Firewater (12820), Juju Power (12451), Elixir of the
  Mongoose / of Giants, R.O.I.D.S., Flask of the Titans.
- **Passive / on-equip / proc / caster-only / wrong-class:** Hand of Justice, Blackhand's Breadth, Drake
  Fang Talisman (19406), Mark of the Chosen (17774), Mark of Tyranny, Rune of the Guard Captain, Smoking
  Heart of the Mountain, Force of Will, Essence of the Pure Flame, Mark of the Champion; Zandalarian
  Hero **Charm** (19950, caster), Talisman of Ephemeral Power (spell-power), Renataki's/Gri'lek's
  (class-locked).
