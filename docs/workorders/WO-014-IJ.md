---
wo: WO-014-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/reference/warrior-ttk-cooldowns.md
related:
  - docs/workorders/WO-012-IJ.md
  - tools/wow-mock/init.lua
---

# WO-014-IJ — `badger-ttk` warrior ability model (table + pure logic + Abilities node) — part a

- **Created / Updated:** 2026-07-25
- **Objective:** the **tracked-ability model** — the static warrior master table, the **pure** logic that
  decides each entry's **availability / usability / active** state, and the **Abilities** config node
  (the full static list with enable/disable + a per-entry offset). This is what turns "which cooldowns"
  into data + rules. Child #7 of WO-007. **Part (a)** — the model; the **live driver** that samples real
  `UnitHealth` + auras/cooldowns and feeds the display in combat is **part (b), WO-015**. Mirrors the
  display split: keep the logic pure/spec-tested, leave the API/event wiring to the edge WO.
- **Acceptance criteria:**
  - **Master table** (`src/abilities/table.lua`, `ns.AbilityTable`): the **14 curated warrior entries**
    from [docs/reference/warrior-ttk-cooldowns.md](../reference/warrior-ttk-cooldowns.md) as data
    `{ id, idType, name, kind, category, duration, cooldown, requires }`. A colocated `_spec` asserts it
    is well-formed (ids present, durations/cooldowns numeric where expected).
  - **Pure logic** (`src/abilities/abilities.lua`, `ns.Abilities`) — no WoW API, spec-tested:
    - `available(entry, character)` → is it usable-**if-owned** given the character (known/talented spells,
      equipped items, race, professions)? **Static list stays complete** — this only annotates.
    - `deriveState(entry, game)` → `{ active, remaining, usable }` from plain inputs (aura remaining,
      cooldown start/duration, item count, equipped). Encodes the visibility rule: a bar shows when
      **enabled ∩ (usable-now OR buff-active)** — abilities = known, items = equipped, consumables = in
      bags — with the **active-buff override**.
  - **Character scan** (`ns.Abilities.scanCharacter`) — the **edge** (thin, untestable): gather
    known/talented (`IsPlayerSpell`), equipped (`GetInventoryItemID`), `UnitRace`, professions → the
    `character` table the pure `available()` consumes.
  - **Abilities config node:** replace the placeholder with the **full static list** (all master entries,
    grouped by category), each with an **enable/disable** toggle, a **bi-directional offset slider**
    (−30…+60s, default 0), and **dimmed** (`disabled`) when the scan says not-currently-available. Persist
    per-entry state in `db.profile.abilities[id] = { enabled, offset }` (default enabled = true, offset = 0).
  - **Gate:** `pnpm validate` green; `ns.AbilityTable` + `ns.Abilities` carry colocated specs.
  - **In-game (human, deferred/waived):** the Abilities node lists every warrior cooldown with its icon,
    toggles + offsets persist, and unavailable ones dim.
- **Context / constraints:** house style — `src/abilities/` modules on `ns`, kebab-case, no `_G` leaks;
  the table is data, the resolve/state logic is pure/spec-covered, only `scanCharacter` touches the API.
  Add any WoW globals used to the badger-ttk `.luacheckrc` overlay. Per-entry **spell/item icons** in the
  list use the label texture-escape (`|T…|t`) helper this WO introduces (deferred from WO-009).
- **Out of scope:** the **live driver** — sampling `UnitHealth`, watching `UNIT_AURA`/cooldown events,
  assembling live tracked entries, feeding the display in combat (**WO-015**); **add/override** custom
  spellIDs + pack import/export (**v1.1**); non-warrior tables (later); show-gating / the Raids node
  (its own WO).
- **Behavior delta:** MODIFIED (in-game, config-only) — the Abilities node becomes real (list · toggles ·
  offsets · availability dim); nothing tracks or shows live yet (that's WO-015).

**Phase 1 — Table + pure logic**
1. [ ] `src/abilities/table.lua` (`ns.AbilityTable`) + `src/abilities/abilities.lua` (`ns.Abilities`:
       `available` / `deriveState` / the visibility rule). Colocated specs (well-formed table · available
       by known/equipped/race · state active/usable/locked · the buff-active override).

**Phase 2 — Character scan + icons**
1. [ ] `ns.Abilities.scanCharacter` (the API edge) + a pure `iconMarkup(texture, size)` label-escape
       helper (with its spec) for per-entry icons.

**Phase 3 — Abilities config node**
1. [ ] Build the Abilities node from the table: per-entry enable/disable + offset slider + availability
       dim; persist under `db.profile.abilities[id]`.

**Phase 4 — Verify**
1. [ ] `pnpm validate` green; specs pass. In-game list/toggle/dim check deferred to the human.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; in-game
  list/dim check is the human's (waived).
- **Constitution check:** Principles OK — the table is data, the availability/state logic is
  API-light + spec-covered (house rule), only `scanCharacter` is the documented edge; no `_G` leaks; the
  live driver + add/override split out (simplest thing that fits). Realises the D-006 static-list +
  availability-overlay decision.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
