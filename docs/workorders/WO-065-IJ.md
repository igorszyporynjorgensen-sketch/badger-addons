---
wo: WO-065-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/69
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-065-IJ — config layout pass: Behavior / Display / Estimator / Abilities

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** tidy several nodes' layouts. (First WO under D-011: **no version bump**;
  logged under CHANGELOG `[0.9.44]`.)
- **Changes (all data — AceConfig orders/widths):**
  - **Behavior:** remove the "Choose when the bars appear on screen." intro line and the "When to show"
    separator below it.
  - **Display** rows (relWidth; renders by `order`, so re-order in place): Lock · Reset · | Screen anchor ·
    Growth direction | Horizontal offset · Vertical offset · Scale | Bar width · Bar spacing · Max utility
    bars | TTK bar height · Utility bar height | Frame strata (own row) | Opacity · Fill · Background
    (final). Text offsets + Readout unchanged. (Position/scale-up-top per the human's pick.)
  - **Estimator:** "Use history for the estimate" was truncating — give both history toggles `width="full"`
    so the long label isn't cut off.
  - **Abilities:** widen the per-ability **offset** slider ~3× (`width = 1.5`); add a spacer between each
    ability's enable toggle + description ("local header") and its offset/colour row.
- **Acceptance:** the nodes render as described; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — config layout only.
- **Constitution check:** Principles OK — data-only options; no logic/`_G` change; **no `.toc` bump** (D-011).

**Phase 1** 1. [x] config.lua node layouts.
**Phase 2** 1. [ ] gate green; CHANGELOG [0.9.44] entry. PR. 2. [ ] **In-game (human):** the four nodes.
