---
wo: WO-042-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-040-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/display/display.lua
---

# WO-042-IJ — per-ability colour (pre-1.0 hardening, batch 5)

- **Created / Updated:** 2026-07-27
- **Objective — #5:** each ability in the Warrior node gets its own **colour** that overrides the global
  **Utility (waiting)** colour for that ability's bar (only the waiting state — fire/fired keep the global
  colours). Persisted per ability (`db.profile.abilities[id].color`); saved with the profile.
- **Design notes (config.lua + display.lua only — no pipeline/spec change):**
  - The layout bar already carries `id`, so `display.render` looks up `profile().abilities[b.id].color`
    directly for the **waiting** state (`utilityColorKey == "colorUtility"`); falls back to the global
    `colorUtility` when unset. Fire/fired use the global `colorReady`/`colorUsed` as before.
  - `config.lua` `buildAbilities`: a per-entry `color` picker bound to `abilities[id].color`; it defaults
    to showing the global waiting colour until set (so unset abilities read as "the global colour").
- **Acceptance criteria:**
  - Each Warrior ability has a colour picker; setting it recolours that ability's bar **while waiting**;
    unset abilities use the global Utility (waiting) colour.
  - Fire/fired states still use the global colours.
  - `pnpm validate` green (config/display edge; pure layout/model untouched).
- **Out of scope:** the sim preview showing per-ability colours (its scenario ids aren't real ability ids —
  it keeps the global waiting colour); status-bar align (WO-043); icons (WO-044); header (WO-045).
- **Behavior delta:** MODIFIED (in-game) — a per-ability waiting colour.

**Phase 1 — Per-ability colour**
1. [ ] `config.lua` per-entry colour picker; `display.lua` waiting-state per-ability lookup.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version`; rebuild `.release`.
2. [ ] **In-game (human, required):** a per-ability colour recolours that bar while waiting.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — config/display edge; no pure-logic/`_G` change.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
