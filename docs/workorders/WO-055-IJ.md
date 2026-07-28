---
wo: WO-055-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/58
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/display/display.lua
---

# WO-055-IJ — show icons: utility ability icons + the target's portrait on the TTK bar

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** with "Show icons" on, each utility bar shows its ability's icon, and
  the TTK bar shows the current target's icon (read live from the target, as the enemy target frame does).
  Currently nothing shows — `showIcons` was a setting with no display code behind it.
- **Design notes (display.lua only — the untestable frame edge):**
  - Give each pooled utility bar + the target bar an `icon` Texture (OVERLAY, TexCoord-trimmed).
  - In `render`, when `p.showIcons`:
    - **Utility bars:** resolve the ability icon from the bar's `b.id` via `ns.AbilityTable` (idType →
      `GetSpellTexture`/`GetItemIcon`), cached; hide if unresolved (sim string ids don't resolve — follow-up).
    - **TTK bar:** `SetPortraitTexture(icon, "target")` when a target exists.
    - Icons sit OUTSIDE the bar on the ANCHOR side (right for a right-ish anchor, left for LEFT), flush, square at the bar's height.
  - Hide all icons when `showIcons` is off or unresolved.
- **Acceptance:** in real combat with Show icons on, utility bars show ability icons and the TTK bar shows
  the target's portrait, updating as the target changes; `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — bar icons.
- **Constitution check:** Principles OK — display edge (no spec); no `_G`/pure-logic change.

**Phase 1** 1. [x] display.lua icon textures + render wiring; anchor-side placement.
**Phase 2** 1. [x] gate green; bumped 0.9.36; rebuilt `.release`. PR #58. 2. [ ] in-game: utility icons + target portrait show with Show icons on.
