---
wo: WO-057-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/59
decision: ~
depends_on:
  - docs/workorders/WO-054-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-057-IJ — fix the WO-053/054 layout widths: numeric widths are 170px multiples, not row fractions

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** the last round's layout is wrong everywhere: Behavior's two sliders were
  to have a row EACH; Display's Horizontal / Vertical / Scale each need their own row; Text offsets must be
  a 2×2 (TTK X·Y row, then Utility X·Y row) not one crammed row; Skin picker+Delete on a row of their own,
  New-skin-name+Save on a row of their own.
- **Root cause (vendored AceConfigDialog:49,1444-1452):** a NUMERIC `width` is a multiple of
  `width_multiplier = 170px` — so `width = 0.5` renders an **85px sliver**, and several slivers flow onto
  one row. Row-fractions need **`width = "relative"` + `relWidth = <fraction>`** (whitelisted by
  AceConfigRegistry `relWidth=optnumber`; Flow computes `paneWidth × relWidth`). Flow wraps on strict `>`,
  so rows are kept at ≤ 0.99 total to dodge float edge cases.
- **Fix (config.lua, data-only):**
  - Behavior: `minTTK` + `minConfidenceToShow` → `width = "full"` (a row each).
  - Display: `posX`, `posY`, `scale` → `"full"` (a row each); `growthDirection` back to default width;
    the anchor·lock·reset row → relative 0.4 / 0.3 / 0.29 (one properly-sized row).
  - Text offsets: all four sliders → relative 0.49 (TTK X·Y row, Utility X·Y row — a true 2×2).
  - Skin: picker 0.74 + Delete 0.25 (relative, own row); New-skin-name 0.74 + Save 0.25 (own row).
- **Acceptance:** in-game rows match the human's list exactly; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — config rows corrected.
- **Constitution check:** Principles OK — data-only widths; no logic change.

**Phase 1** 1. [x] config.lua width corrections (relative/full).
**Phase 2** 1. [ ] gate green; bump 0.9.37; rebuild `.release`. PR. 2. [ ] **In-game (human):** rows as listed.
