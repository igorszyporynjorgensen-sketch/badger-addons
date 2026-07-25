---
wo: WO-022-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/25
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-009-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/core.lua
---

# WO-022-IJ — Raids config node: a sub-node per raid, encounter checkboxes, per-raid master toggle

- **Created / Updated:** 2026-07-25
- **Objective:** the **Raids** config node is still the WO-009 placeholder. Populate it per the WO-007
  design: **one sub-node per Classic-Era raid**; each sub-node lists **its encounters as checkboxes**
  (default all **on**) with an **overall enable/disable for that raid** at the top. This is the show-gating
  *config surface* (which raids/encounters the bars should show on).
- **Scope — this WO builds the CONFIG + storage only.** Actually *enforcing* the gating in combat (detect
  the current zone/encounter → show only where enabled) is the **live gating** step and is **out of scope
  here** (it needs `IsInInstance`/boss detection wired into the live driver). Boss/raid **icons** are also
  deferred (the human procures them later); nodes use a simple placeholder icon for now.
- **Design (mirrors the Abilities node):**
  - **`src/raids/table.lua`** — a pure DATA module `ns.RaidTable`: an ordered list of raids, each
    `{ id, name, encounters = { { id, name }, … } }`. Colocated `raids/table_spec.lua` asserts the shape
    (unique ids, ≥1 encounter each). No WoW API.
  - **`config.lua` `buildRaids(db)`** — replaces the placeholder: for each raid, a **group** (→ a left-nav
    sub-node) whose args are a master **"Enable this raid"** toggle + one **toggle per encounter**. Encounter
    toggles are `disabled` when the raid's master is off (visually greys them, like Abilities' availability).
  - **Storage** — `db.profile.raids[raidId] = { enabled = <bool>, encounters = { [encId] = <bool> } }`,
    filled on demand; **absent = default ON** (getters default to `true`), so a fresh profile shows
    everything enabled without pre-seeding. Mirrors `db.profile.abilities`.
- **Proposed raid list (Classic Era 1.15 — please review / cull, esp. World Bosses):**
  - **Molten Core** — Lucifron · Magmadar · Gehennas · Garr · Baron Geddon · Shazzrah · Sulfuron Harbinger ·
    Golemagg · Majordomo Executus · Ragnaros
  - **Onyxia's Lair** — Onyxia
  - **Blackwing Lair** — Razorgore · Vaelastrasz · Broodlord Lashlayer · Firemaw · Ebonroc · Flamegor ·
    Chromaggus · Nefarian
  - **Zul'Gurub** — Venoxis · Jeklik · Mar'li · Mandokir · Gahz'ranka · Thekal · Arlokk · Jin'do · Hakkar
  - **Ruins of Ahn'Qiraj (AQ20)** — Kurinnaxx · General Rajaxx · Moam · Buru · Ayamiss · Ossirian
  - **Temple of Ahn'Qiraj (AQ40)** — Skeram · Bug Trio · Sartura · Fankriss · Viscidus · Princess Huhuran ·
    Twin Emperors · Ouro · C'Thun
  - **World Bosses** — Azuregos · Lord Kazzak · Ysondre · Lethon · Emeriss · Taerar
- **Acceptance criteria:**
  - The Raids node shows a **sub-node per raid**; selecting one lists its **encounter checkboxes** with a
    **master toggle** on top; **all default on**.
  - Toggling an encounter / a raid master **persists** across `/reload` (in `db.profile.raids`); the master
    off **greys** its encounters.
  - `pnpm validate` green — `ns.RaidTable` shape is spec-tested; the config build has no pure logic to test
    beyond that.
- **Out of scope:** live gating enforcement (zone/boss detection → show/hide); boss/raid icons (deferred);
  per-encounter TTK baselines / WarcraftLogs.
- **Behavior delta:** MODIFIED (config) — the Raids node is populated with per-raid sub-nodes + encounter
  toggles. No in-combat behavior change yet (enforcement is a later WO).

**Phase 1 — Raid registry (pure data + spec)**
1. [x] `src/raids/table.lua`: `ns.RaidTable` (the reviewed list above). `raids/table_spec.lua`: unique raid
       + encounter ids, ≥1 encounter per raid. Add the file to the `.toc` (after abilities, before core).

**Phase 2 — Config node + storage**
1. [x] `config.lua` `buildRaids(db)`: per-raid group (sub-node) with a master toggle + encounter toggles
       (default-on getters; encounters `disabled` when the raid master is off). Replace the placeholder.
2. [x] `core.lua`: add `raids = {}` to the profile defaults (absent = default-on, like `abilities`).

**Phase 3 — Verify**
1. [x] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.5**, rebuild `.release`.
2. [ ] **In-game (human, required):** Raids shows a sub-node per raid with encounter checkboxes + master
       toggle; toggles persist across `/reload`.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — the raid registry is a pure DATA module with a colocated spec
  (house style, like `ns.AbilityTable`); config building is declarative; no `_G` leaks.
- **Decisions produced:** —
- **MR:** [PR #25](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/25)
- **Outcome:** Implemented; `pnpm validate` green (64 badger-ttk specs — +3 for the registry; luacheck 0/0). 7 raids / 49 encounters. `.toc` -> v0.9.5. **PR #25 merged**; rebuilt `.release/BadgerTTK` at v0.9.5 (load graph resolves 73/0, raids/table.lua loads, buildRaids shipped, source parity clean). **In progress** pending the human's in-game re-test.
