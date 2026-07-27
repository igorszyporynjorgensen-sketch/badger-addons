---
wo: WO-035-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-033-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-035-IJ — Reset rewinds the sim to 100% (0:50), independent of Play

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** the Simulation **Reset** button should rewind the timeline to the
  **start — 100% health, 0:50** — NOT to the 0:25 still. And Reset must be **independent of Play**: it does
  not stop or start playback; a running animation simply continues from the start via its own loop.
- **Design notes (display.lua + config.lua):**
  - `Display.resetSim()`: set the run to `t = 0` (the timeline start → TTK 0:50, full health) and render
    that frame. Do **not** clear `play`, detach the ticker, or touch `simPlaying`. If the animation is
    playing it keeps playing from the start; if paused/idle it shows the 0:50 frame (and a `play` at t=0 is
    created so a later Play/refresh continues from there).
  - Config Simulation `reset` button: drop the `simPlaying = false` line — Reset no longer affects the
    play/pause state, only the position. Still gated on **Show preview**.
- **Acceptance criteria:**
  - Reset shows the bars at **100% / 0:50** (both cooldowns planned, full TTK bar).
  - Pressing Reset while **playing** keeps it playing (from 0:50); while **paused** shows 0:50 frozen; the
    Play/Pause label is unchanged by Reset.
  - `pnpm validate` green (display + config are the off-client edge).
- **Out of scope:** the initial "Show preview" still (stays the 0:25 styling snapshot); the global header
  (WO-034); badger-arena (WO-036).
- **Behavior delta:** MODIFIED (in-game) — Reset rewinds to 0:50 and no longer stops playback.

**Phase 1 — Reset to start**
1. [ ] `display.lua` `resetSim()`: rewind to `t=0` (0:50), keep play/pause state; `config.lua` reset button:
       drop `simPlaying = false`.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`.
2. [ ] **In-game (human, required):** Reset → 0:50 / 100%; Reset while playing keeps playing; while paused
       freezes at 0:50.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — frame/edge change; no `_G` leaks; pure sim/layout untouched.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
