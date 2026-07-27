---
wo: WO-039-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/42
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-038-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-039-IJ — config copy (pre-1.0 hardening, batch 2)

- **Created / Updated:** 2026-07-27
- **Objective — descriptive copy across the config (config.lua only):**
  - **#3/#13 General:** keep the short intro + **Enable addon** toggle as they are; **after** the toggle,
    add a deeper "how to use / where things live" section (what the addon shows, how to read the bars, and a
    one-line pointer to each node).
  - **#26 Behavior:** a short description line **above** the "When to show" separator.
  - **#6 Raids + Abilities parents:** intro text at the top of each otherwise-empty parent node (Raids says
    what encounter gating does; Abilities says it's the tracked-cooldown list, per class).
  - **#7 minTTK:** sharpen the "Minimum time to kill" description — it gates the **first** appearance (bars
    don't show until the estimate reaches it, then stay; no flicker).
- **Design notes:** all `type="description"` additions + one `desc` edit; orders chosen so text sits where
  intended (General how-to after the toggle; Behavior intro above the header at order < 1).
- **Acceptance criteria:**
  - General reads: intro → Enable → a clear how-to/where-things-are block.
  - Behavior has an intro line above "When to show"; Raids and Abilities parent nodes open with intro text.
  - The minTTK slider's tooltip explains the first-appearance gate.
  - `pnpm validate` green (config copy; no logic change, no spec change).
- **Out of scope:** colours/fonts (WO-040); geometry/opacity (WO-041); per-ability colour (WO-042); chrome
  (WO-043); icons (WO-044); header redesign (WO-045).
- **Behavior delta:** MODIFIED (in-game) — more descriptive text in the config; no functional change.

**Phase 1 — Copy**
1. [x] `config.lua`: General how-to (#3/#13), Behavior intro (#26), Raids + Abilities parent intros (#6),
       minTTK desc (#7).

**Phase 2 — Verify**
1. [x] `pnpm validate` green (86 tests). Bumped `.toc` to 0.9.21; `## Version`; rebuild `.release`.
2. [ ] **In-game (human, required):** the new copy reads well and sits in the right places.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — config copy only; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
