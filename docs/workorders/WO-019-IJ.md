---
wo: WO-019-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/22
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-018-IJ.md
related:
  - projects/badger-ttk/src/display/layout.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-019-IJ — `badger-ttk` utility-bar polish: progress fill · duration sort · timer default-off

- **Created / Updated:** 2026-07-25
- **Objective:** three refinements to the utility bars after the WO-018 in-game test (which "worked really
  well"):
  1. **Progress like the TTK bar.** A utility bar is currently a solid block; it should show a **draining
     fill** so you can see the buff/coverage tick down — mirroring how the main TTK bar drains.
  2. **Sort by duration.** Order the utility bars so the **longest-duration** ones are **closest to the TTK
     bar** (the TTK bar is at the bottom, so longest = bottom row, shortest on top).
  3. **Drop the per-bar timer by default.** The utility bars don't need a countdown number; make it
     **off by default** but keep it configurable.
- **Design:**
  1. **Progress fill (steady frame + draining fill).** Keep the steady coverage segment as the bar's frame,
     but add a **dim background track** (so the full segment stays visible) and a **reverse-filled** status
     bar on top whose value = `remaining / duration` while active (planned = full/dim). Reverse fill anchors
     the fill at death, so it recedes toward death exactly like the TTK bar — and the fill's now-edge lands
     at `xOf(remaining)`, i.e. **in lockstep with the TTK bar's now-edge**. The fill fraction is computed in
     the pure `Layout` (`bar.fill`), so it's spec-tested; the display just sets it.
  2. **Duration sort in the pure `Layout`.** `Layout.compute` returns the bars sorted by **duration
     descending** (deterministic tiebreak by original order), so the display's first row — nearest the TTK
     bar — is the longest cooldown. Spec-tested.
  3. **`showTimers` default → false.** Flip the `core.lua` default; the existing Display-node toggle stays
     (its label clarified to "Utility bar timers"). When on, the count stays the short `Ns` form (not
     mm:ss) — the main TTK bar keeps its own `m:ss` readout regardless.
- **Acceptance criteria:**
  - Each utility bar shows a **draining fill** within a **steady** segment (dim track behind), receding
    toward death in step with the TTK bar; planned bars read full/dim, then drain once active.
  - Utility bars are **ordered longest-duration nearest the TTK bar** (e.g. Death Wish 30s below
    Earthstrike 20s).
  - **No countdown number on utility bars by default**; toggling "Utility bar timers" on restores it.
  - `pnpm validate` green — `fill` + duration-sort covered by `layout_spec`; no live-behavior regressions.
- **Out of scope:** changing the main TTK bar's look; a background track on the TTK bar (it already reads
  as progressing); per-ability colour tweaks.
- **Behavior delta:** MODIFIED (in-game) — utility bars drain like the TTK bar, sort longest-first nearest
  the TTK bar, and hide their countdown by default.

**Phase 1 — Pure layout (fill + sort)**
1. [x] `display/layout.lua`: add `bar.fill` (active → `clamp(remaining/duration, 0, 1)`; planned → 1) and
       sort the returned bars by **duration desc** (stable tiebreak). Specs in `layout_spec.lua`.

**Phase 2 — Display + config**
1. [x] `display/display.lua` `render`: give each utility bar a dim background track + a reverse-filled
       status bar set to `bar.fill`; gate the countdown text on `showTimers` (unchanged gate, now off by
       default).
2. [x] `core.lua`: `showTimers` default → `false`. `config.lua`: clarify the toggle label to
       "Utility bar timers".

**Phase 3 — Verify**
1. [x] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.2**, rebuild `.release`.
2. [x] **In-game (human, required):** (approved by the human) utility bars drain in step with the TTK bar, sorted longest-nearest,
       no countdown by default (toggle restores it).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — fill + sort are pure/spec-tested; the track + reverse-fill are
  edge; default/label are config; no `_G` leaks.
- **Decisions produced:** —
- **MR:** [PR #22](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/22)
- **Outcome:** Implemented; `pnpm validate` green (61 badger-ttk specs — +3 for fill + sort; luacheck 0/0).
  `.toc` → v0.9.2. **PR #22 merged**; rebuilt `.release/BadgerTTK` at v0.9.2 (load graph resolves 65/0,
  source parity clean, fill+sort / track+reverse-fill / timer-default-off markers present). **In-game
  approved by the human** (tested in the bundled v0.9.4 build) → **Done**.
