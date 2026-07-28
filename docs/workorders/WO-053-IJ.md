---
wo: WO-053-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/56
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/skin/skin.lua
---

# WO-053-IJ — Skin node: Delete on the picker's line + block saving over "Default" (#2)

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** the Delete button should delete the picker-chosen skin (if not the
  built-in) and sit on the SAME line as the skin picker. Plus audit **#2**: saving a skin named "Default"
  clobbers the un-deletable built-in.
- **Design notes:**
  - **Layout (config.lua buildSkin):** picker `width = 0.75` (was "full") + `deleteSkin` `width = 0.25`
    moved to order 1.5 → they share one row; `newSkinName` `width = 0.75` + `saveSkin` `width = 0.25`
    share the next row. Delete already targets `db.profile.skin` (= the picker selection) and is disabled
    for the built-in — logic unchanged.
  - **Save guard (#2):** `Skin.saveCurrent` returns `nil` for `name == Skin.BUILTIN` (never overwrites the
    code-defined built-in); config `saveSkin` also disables + early-returns when the typed name is the
    built-in. Add a spec for the guard.
- **Acceptance:** Delete sits beside the picker and removes the selected non-built-in skin; typing
  "Default" + Save is refused (built-in intact); `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — Skin node layout; can't clobber Default.
- **Constitution check:** Principles OK — config edge (no spec) + a guarded pure `saveCurrent` (spec added).

**Phase 1** 1. [ ] skin.lua guard + spec; config.lua layout + save guard.
**Phase 2** 1. [ ] gate green; bump 0.9.34; rebuild `.release`. PR. 2. [ ] in-game: delete beside picker; can't save "Default".
