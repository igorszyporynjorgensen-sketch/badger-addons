---
wo: WO-050-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/53
decision: ~
depends_on:
  - docs/workorders/WO-047-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-050-IJ — Text-offsets: TTK row + Utility row (50% each)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** TTK and Utility each get their OWN horizontal block — TTK X/Y on one
  row, Utility X/Y on the next — 2 rows, two items at 50% each. (Corrects an initial "25% each" ask,
  which would have put all four on one row.)
- **Design notes:** `width = 0.5` on `ttkTextX`/`ttkTextY`/`utilTextX`/`utilTextY` (numeric relative
  width; 2 × 0.5 fills a row, so the pairs wrap into two rows). Data-only.
- **Acceptance:** TTK X·Y share one row above Utility X·Y; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — two 50% rows.
- **Constitution check:** Principles OK — data-only AceConfig width; no logic change.

**Phase 1** 1. [x] config.lua width 0.5 ×4.
**Phase 2** 1. [x] gate green; bumped 0.9.31. 2. [ ] **In-game (human):** two rows.
