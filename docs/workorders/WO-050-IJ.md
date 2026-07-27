---
wo: WO-050-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on:
  - docs/workorders/WO-047-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-050-IJ — Text-offsets: four sliders on one row (25% each)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** the Text-offsets group has too much empty space at 2-per-row; put all
  four sliders on one row at ~25% width each (minus normal spacing).
- **Design notes:** change `width = "half"` → `width = 0.25` on `ttkTextX` / `ttkTextY` / `utilTextX` /
  `utilTextY` (AceConfig numeric width = relative fraction; 4 × 0.25 fills one row). Data-only.
- **Acceptance:** the four Text-offset sliders share one row; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — Text-offset sliders single-row.
- **Constitution check:** Principles OK — data-only AceConfig width; no logic change.

**Phase 1** 1. [ ] config.lua width 0.25 ×4.
**Phase 2** 1. [ ] gate green; bump 0.9.31; rebuild `.release`. PR. 2. [ ] in-game: one row.
