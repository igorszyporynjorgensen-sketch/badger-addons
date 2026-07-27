---
wo: WO-049-IJ
status: In progress
assigned: IJ
mr: ~
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/skin/skin.lua
---

# WO-049-IJ — default profile tuning (fresh-profile values + built-in Default skin)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** set the fresh-profile defaults: bar width **220**, background opacity
  **45%**, statusbar texture **"Blizzard Raid Bar"**, font **"Arial Narrow"**, utility font size **10**,
  main TTK font size **13**, utility(waiting) colour **black**. Also confirm fg/bg opacity save in skins.
- **Design notes:** update `core.lua` `DEFAULTS.profile` (barWidth 180→220, barBgOpacity 0.1→0.45,
  statusbar "Blizzard"→"Blizzard Raid Bar", font "Friz Quadrata TT"→"Arial Narrow", fontSizeMain 16→13,
  fontSizeOther 12→10, colorUtility →{0,0,0,1}); mirror the overlapping fields in the built-in **Default**
  skin (`skin.lua`) so applying it matches. **fg/bg opacity already save** — `barFgOpacity`/`barBgOpacity`
  are already in `DISPLAY_FIELDS`; no change needed there.
- **Acceptance:** fresh profile shows the new look; `pnpm validate` green.
- **Behavior delta:** MODIFIED (in-game) — new default look.

**Phase 1** 1. [ ] core.lua defaults + built-in Default skin.
**Phase 2** 1. [ ] `pnpm validate` green; bump 0.9.30; rebuild `.release`. PR for human merge.
2. [ ] **In-game (human):** clear profile → new defaults; select Default skin → matches.
- **Constitution check:** Principles OK — data-only default values; no `_G`/logic change.
