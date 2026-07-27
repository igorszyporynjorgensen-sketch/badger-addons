---
wo: WO-040-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/44
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-039-IJ.md
related:
  - projects/badger-ttk/src/skin/skin.lua
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/display/display.lua
---

# WO-040-IJ — skin colours consolidated + a font colour (pre-1.0 batch 3)

- **Created / Updated:** 2026-07-27
- **Objective — colours from the pre-1.0 batch (human answered: keep Target + 3 utility):**
  - **#1/#2 Consolidate the state colours** to **four**: **Target (TTK)**, **Utility (waiting)**,
    **Utility (fire)**, **Utility (fired)**. The old "Utility" fallback becomes **Utility (waiting)** and the
    duplicate **"Waiting"** colour is removed (waiting state now uses that colour).
  - **#20 Font colour** — a new colour picker for the bar text; saved to skins.
  - **#22** Confirm skins already save **bar spacing / width / height** (they're in `DISPLAY_FIELDS`) — verify,
    no change expected.
- **Design notes:**
  - `display.lua` `utilityColorKey`: the waiting case returns **`colorUtility`** (not `colorWaiting`), so
    the renamed "Utility (waiting)" colour drives the waiting state. `render`: apply `colorFont` to the TTK
    and utility text via `SetTextColor`.
  - `skin.lua` `COLOR_FIELD`: drop `waiting`, add `font = "colorFont"`; built-in **Default** colours lose
    `waiting`, gain `font` (white). Old skins carrying `waiting` are harmlessly ignored on apply.
  - `core.lua` defaults: remove `colorWaiting`, add `colorFont = {1,1,1,1}` (white text).
  - `config.lua` Skin node "State colours": relabel Target/Utility(waiting)/Utility(fire)/Utility(fired),
    remove the Waiting picker, add a **Font** colour picker.
  - `skin_spec`: update for the new `COLOR_FIELD` (no `waiting`, `font` captured/applied).
- **Acceptance criteria:**
  - Skin colours read: **Target (TTK)**, **Utility (waiting)**, **Utility (fire)**, **Utility (fired)**, plus
    a **Font** colour; changing each recolours the right thing live (waiting/fire/fired states + text).
  - Saving a skin captures + restores those colours (incl. font) and the bar spacing/width/height.
  - `pnpm validate` green — `skin_spec` covers the new colour set.
- **Out of scope:** two bar heights + opacity + text offset (WO-041); per-ability colour (WO-042); icons +
  header (WO-044/045).
- **Behavior delta:** MODIFIED (in-game) — fewer, clearer colour pickers; a font colour; waiting uses the
  renamed "Utility (waiting)".

**Phase 1 — Colours + font**
1. [x] `display.lua` (utilityColorKey + font colour), `skin.lua` (COLOR_FIELD + built-in), `core.lua`
       (defaults), `config.lua` (pickers), `skin_spec`.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (86). Bumped 0.9.22. `.toc` `## Version`; rebuild `.release`.
2. [ ] **In-game (human, required):** four colours + font recolour live; skins round-trip them.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — pure skin map + spec; display/config edge; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
