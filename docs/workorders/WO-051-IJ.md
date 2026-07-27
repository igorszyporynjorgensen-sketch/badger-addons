---
wo: WO-051-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/54
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/core.lua
---

# WO-051-IJ — fix: profile switch/reset leaves the display stale (+ preview-state & skin-normalize)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** "when I cleared my profile the bars were not aligned properly." Plus two
  correctness fixes the pre-1.0 audit confirmed.
- **Root cause (audit #4):** no AceDB `OnProfileChanged/Reset/Copied` callbacks — AceDB points `db.profile`
  at a new table on a switch/reset and nothing re-applies the container, so scale/position/size/strata keep
  the old profile's values. `Display.refresh()` (which calls `applyContainer()` + re-renders, reading the
  live `profile()`) fixes it.
- **Design notes (core.lua only — the unspec'd Ace edge):**
  - Extract `normalizeProfile(p)`: rename retired "Badger"→Default (WO-038), drop `barHeight` (WO-041),
    point any unknown/deleted skin at `Skin.BUILTIN` (**audit #7** — inactive profiles were never migrated),
    and clear persisted `simStatic`/`simPlaying` (**audit #3** — a stale preview state suppressed the live
    display after `/reload`). Run it on init AND on every profile change.
  - Register `OnProfileChanged/OnProfileReset/OnProfileCopied` → `normalizeProfile` + `ns.Display.refresh()`
    + `AceConfigRegistry-3.0:NotifyChange` (so the panel reflects the new profile).
  - Register user skins BEFORE normalizing so a profile pointing at a saved skin validates.
- **Acceptance:** clearing/switching a profile re-aligns + re-skins the display; `/reload` with a preview
  up no longer suppresses the live display; `pnpm validate` green.
- **Behavior delta:** FIXED (in-game) — profile switch/reset re-applies the display; no stuck preview.
- **Constitution check:** Principles OK — Ace-lifecycle wiring in core.lua (no spec, like the rest); no `_G`.

**Phase 1** 1. [ ] core.lua normalizeProfile + profile callbacks.
**Phase 2** 1. [ ] gate green; bump 0.9.32; rebuild `.release`. PR.
2. [ ] **In-game (human):** reset profile → bars re-align; switch profile → display updates; /reload w/ preview → live display returns.
