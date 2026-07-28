---
wo: WO-055-IJ
status: Accepted
assigned: IJ
mr: ~
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
      `GetSpellTexture`/`GetItemIcon`), cached; anchor a bar-height square at the bar's LEFT; hide if
      unresolved (the sim's synthetic string ids won't resolve — preview icons are a follow-up, audit #6).
    - **TTK bar:** `SetPortraitTexture(icon, "target")` when a target exists; anchor a bar-height square at
      the LEFT and shift the time text right by the icon width so they don't overlap.
  - Hide all icons when `showIcons` is off or unresolved.
- **Acceptance:** in real combat with Show icons on, utility bars show ability icons and the TTK bar shows
  the target's portrait, updating as the target changes; `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — bar icons.
- **Constitution check:** Principles OK — display edge (no spec); no `_G`/pure-logic change.

**Phase 1** 1. [ ] display.lua icon textures + render wiring.
**Phase 2** 1. [ ] gate green; bump 0.9.36; rebuild `.release`. PR. 2. [ ] in-game: utility icons + target portrait show with Show icons on.
