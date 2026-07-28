---
wo: WO-058-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on:
  - docs/workorders/WO-057-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-058-IJ — layout follow-up: shared rows for Behavior sliders + Display H/V/Scale; Lock first in header

- **Created / Updated:** 2026-07-28
- **Objective — from the human** (correcting WO-057's "a row of their own" phrasing):
  - Behavior: Minimum time-to-kill + Minimum confidence SHARE one row.
  - Display: Horizontal offset + Vertical offset + Scale SHARE one row.
  - Global header: "Lock position" placed BEFORE "Show preview".
- **Design notes:** relative fractions (WO-057 semantics): the two Behavior sliders 0.49 each; the three
  Display sliders 0.33 each (0.99 total). Header: reorder the `controls` array in `BCUI:Register`
  (normalize assigns orders by sequence) → Lock, Show preview, Play/Pause.
- **Acceptance:** rows as listed; header order Lock · Show preview · Play/Pause; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — config rows + header control order.
- **Constitution check:** Principles OK — data-only widths/ordering.

**Phase 1** 1. [ ] config.lua widths + header reorder.
**Phase 2** 1. [ ] gate green; bump 0.9.38; rebuild `.release`. PR. 2. [ ] **In-game (human):** rows + header order.
