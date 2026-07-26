---
wo: WO-026-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/28
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-015-IJ.md
related:
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-026-IJ — Behavior toggle: show the utility bars outside a raid *encounter*?

- **Created / Updated:** 2026-07-26
- **Objective:** add a Behavior option (next to **Show on any target**) — **"Show utility bars outside
  raids"** — controlling whether the utility cooldown bars appear when the target is **not a raid boss**.
  Outside a raid the utility bars (Earthstrike, Death Wish, …) are noise on a random mob; the **main TTK
  bar** still shows. When off, on a non-boss target only the TTK bar renders.
- **"Raid" = a raid ENCOUNTER (human decision):** the shared, unique property of raid bosses — in
  instances *and* the open world, and nothing else — is being an **encounter**. Detect it robustly with
  **two signals** (either qualifies):
  1. **`ENCOUNTER_START` / `ENCOUNTER_END`** — the driver tracks an `encounterActive` flag. Reliable for
     **instance** raid bosses (Classic Era wires the DungeonEncounter system).
  2. **`UnitClassification("target") == "worldboss"`** — the boss/skull flag. Catches **open-world** bosses
     (Azuregos, Kazzak, the dragons) whose encounter wiring in Classic Era is uncertain, and most instance
     bosses too. This is the world-boss fallback (the WO-022 `RaidTable` has no NPC ids yet, so exact
     registry matching — for full per-encounter gating — is the deferred enforcement WO).
  - `inRaidEncounter = encounterActive or (UnitClassification("target") == "worldboss")`. Trash never
    qualifies → clean separation.
- **Design:**
  - New profile setting **`showUtilityOutsideRaid`** (Behavior node, next to `showAnyTarget`), default
    **on** (current behavior preserved; turn off to declutter).
  - PURE helper `LiveDriver.showUtility(settings, context)` → `context.inRaidEncounter or
    settings.showUtilityOutsideRaid`. In `update()`, when it's false the driver passes an **empty utility
    list** to the display → only the main TTK bar; otherwise it assembles utilities as today. (The gate /
    main bar are unchanged; the sim preview renders directly and is unaffected.)
- **Acceptance criteria:**
  - A Behavior toggle **"Show utility bars outside raids"** exists next to *Show on any target* and persists.
  - On a **raid boss** (instance encounter or a `worldboss`-classified open-world boss): utility bars show
    regardless of the toggle.
  - On a **non-boss** target with the toggle **off**: only the main TTK bar (no utility bars); with it
    **on**: utilities show as today.
  - `pnpm validate` green — the `showUtility` decision is a pure spec-tested helper; the encounter/
    classification reads are the edge.
- **Out of scope:** the full **registry-based per-encounter gating** (matching the target to the enabled
  Raids checkboxes; needs NPC ids added to `RaidTable`) — the deferred show-gating enforcement WO; hiding
  the main TTK bar.
- **Behavior delta:** ADDED (in-game) — outside a raid encounter, utility bars can be hidden via the toggle.

**Phase 1 — Detection + pure gate helper**
1. [x] `driver.lua`: track `encounterActive` via `ENCOUNTER_START`/`ENCOUNTER_END`; add PURE
       `LiveDriver.showUtility(settings, context)`; in `update()` build `context.inRaidEncounter =
       encounterActive or UnitClassification("target") == "worldboss"` and pass an empty utility list when
       `showUtility` is false. `core.lua`: `showUtilityOutsideRaid = true` default. Spec `showUtility`.

**Phase 2 — Config**
1. [x] `config.lua` Behavior node: **"Show utility bars outside raids"** toggle next to *Show on any target*.
       Whitelist `UnitClassification` in `.luacheckrc` / `.luarc.json`.

**Phase 3 — Verify**
1. [x] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`.
2. [ ] **In-game (human, required):** on a raid boss the utility bars show regardless; on a normal mob the
       toggle hides/shows them (TTK bar stays). (Also confirms whether world bosses fire `ENCOUNTER_START`
       and/or read as `worldboss` — the fallback covers either way.)

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — the show/hide decision is a PURE spec-tested helper; the
  encounter-event + `UnitClassification` reads are the edge; no `_G` leaks.
- **Decisions produced:** — (candidate: "raid" for show-gating = an active encounter OR a `worldboss`-
  classified target; exact per-encounter gating via a future NPC-id registry.)
- **MR:** [PR #28](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/28)
- **Outcome:** Implemented; `pnpm validate` green (72 badger-ttk specs — +2; luacheck 0/0). Encounter + worldboss detection; pure showUtility helper; empty utility list when off. `.toc` -> v0.9.8. **In progress** pending merge of PR #28 + the human's in-game re-test.
