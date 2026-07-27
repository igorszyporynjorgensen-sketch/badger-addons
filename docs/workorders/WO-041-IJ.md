---
wo: WO-041-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-040-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/skin/skin.lua
---

# WO-041-IJ — bar geometry & opacity (pre-1.0 hardening, batch 4)

- **Created / Updated:** 2026-07-27
- **Objective — the display geometry/opacity items:**
  - **#4 Two bar heights** — separate **TTK** height (default **30**) and **utility** height (default **20**),
    replacing the single `barHeight`.
  - **#17 Bar↔border gap → 0** — the border should hug the bar, not sit 12px out.
  - **#23/#24 Opacity** — the bar **fill** fully opaque by default, the **background track** faint; both as
    **sliders** (fill + background), saved to skins.
  - **#25 Text offset** — X/Y offset sliders for the **TTK** text and the **utility** text, from their
    current anchor; saved to skins.
- **Design notes (display.lua + config.lua + core.lua + skin.lua; pure Layout untouched — it ignores
  height/spacing):**
  - `core.lua`: replace `barHeight` with `ttkBarHeight = 30` + `utilityBarHeight = 20`; add `barFgOpacity = 1`,
    `barBgOpacity = 0.1`, `ttkTextX/ttkTextY/utilTextX/utilTextY = 0`.
  - `display.lua`: TTK bar + container use `ttkBarHeight`; utility bars use `utilityBarHeight` and stack
    **above** the TTK bar (`ttkBarHeight + spacing`, then `+ (utilityBarHeight + spacing)` each). Fill alpha
    ×= `barFgOpacity`; background track alpha = `barBgOpacity` (replaces the hard-coded `BG_ALPHA`). Text is
    re-anchored each render with the X/Y offsets. `BORDER_INSET → 0` (border hugs the bar, #17).
  - `skin.lua` `DISPLAY_FIELDS`: swap `barHeight` for `ttkBarHeight` + `utilityBarHeight`; add the two
    opacities + the four text offsets (all saved to skins).
  - `config.lua` Display node: "TTK bar height" + "Utility bar height" sliders; fill/background opacity
    sliders; TTK/utility text X-Y offset sliders (all `setterR`, instant).
- **Acceptance criteria:**
  - TTK and utility bars have independent heights (defaults 30 / 20) and change live; the utility stack sits
    above the TTK bar without gaps/overlap.
  - The border hugs the bar (no big gap).
  - Fill/background opacity sliders work; a skin round-trips heights, opacities, and text offsets.
  - Text X/Y offsets nudge the TTK and utility text live.
  - `pnpm validate` green (display/config edge + pure skin list; Layout/specs unchanged).
- **Out of scope:** per-ability colour (WO-042); status-bar align (WO-043); icons (WO-044); header (WO-045).
- **Behavior delta:** MODIFIED (in-game) — two heights, tight border, fill/bg opacity, text offsets.

**Phase 1 — Geometry & opacity**
1. [ ] `core.lua` defaults, `skin.lua` `DISPLAY_FIELDS`, `display.lua` (heights/stack/opacity/text/border),
       `config.lua` (Display sliders).

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version`; rebuild `.release`.
2. [ ] **In-game (human, required):** two heights, tight border, opacity sliders, text offsets; skins round-trip.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — display/config edge; `DISPLAY_FIELDS` stays a pure list; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
