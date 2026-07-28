---
wo: WO-054-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/57
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-054-IJ — config layout: Lock in header + group Display/Behavior controls onto shared lines

- **Created / Updated:** 2026-07-28
- **Objective — from the human:**
  - Add a **Lock position** control to the window header (beside Show preview + Play/Pause).
  - Display node: **Screen anchor · Lock position · Reset position** on one line; **Horizontal · Vertical
    offset** on one line; **Scale · Growth direction** on one line. Leave the rest as is.
  - Behavior node: **Minimum time-to-kill · Minimum confidence** on one line.
- **Design notes:** relative `width`s + `order`s (AceConfig sorts by order, so Reset just needs order 2.6,
  no code move). Header Lock binds `db.profile.locked` via `setterR` — stays in sync with the Display
  Lock toggle. Data-only.
  - anchor 0.4 / lock 0.3 / reset 0.3 (orders 2 / 2.3 / 2.6); posX 0.5 / posY 0.5 (3 / 3.5);
    scale 0.5 / growth 0.5 (4 / 4.5); minTTK 0.5 / minConfidence 0.5.
- **Acceptance:** the named controls share their rows; header has a working Lock toggle; `pnpm validate`
  green.
- **Behavior delta:** MODIFIED (in-game) — config layout; header Lock.
- **Constitution check:** Principles OK — data-only AceConfig widths/orders; no logic change.

**Phase 1** 1. [ ] config.lua widths/orders + header Lock control.
**Phase 2** 1. [ ] gate green; bump 0.9.35; rebuild `.release`. PR. 2. [ ] in-game: rows grouped; header Lock works.
