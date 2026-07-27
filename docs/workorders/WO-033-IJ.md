---
wo: WO-033-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-030-IJ.md
  - docs/workorders/WO-032-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-033-IJ — simulation: Play becomes Play/Pause, plus a Reset button

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** the Simulation **Play** button becomes a **play/pause toggle** that does
  **not** reset the timeline — Pause freezes the animation *in place* and Play resumes *from there*. A new
  **Reset** button is the explicit way back to the start (the frozen 0:25 still).
- **Design notes (display.lua + config.lua only; no pure-logic change):**
  - Today `playSim(false)` acts as *Stop* — it re-freezes to the 0:25 still and discards `play`. Split that:
    - **Pause** (`playSim(false)`): detach the ticker but **keep `play`** (preserve `play.t`) and leave the
      current frame on screen — no hide, no re-freeze. **Play** (`playSim(true)`) resumes from `play.t`
      (or starts a fresh run at the timeline start if there is no `play`).
    - **Reset** (`Display.resetSim()`): clear `play`, stop the ticker, and render the frozen 0:25 still —
      the old *Stop* behavior, now its own button.
  - `Display.refresh()` must re-render a **paused** frame at `play.t` (not snap to the 0:25 still) when a
    Display setting changes mid-pause; unchanged for playing (the loop re-renders) and for the plain still.
  - Config Simulation node: the `play` execute button's label flips **Play ⇄ Pause** with `simPlaying`; add
    a **Reset** execute button. Both disabled until **Show preview** is on. Reset also clears
    `db.profile.simPlaying` so the toggle label returns to "Play".
- **Acceptance criteria:**
  - Play animates; Pause freezes the bars **where they are** (not back to 0:25); Play again resumes from
    that point — the countdown is never reset by pausing.
  - Reset returns the preview to the frozen **0:25** still and stops playback.
  - Changing a Display value while paused keeps the paused frame (re-rendered with the new setting), not a
    snap to 0:25.
  - `pnpm validate` green (display + config are the off-client edge; no pure-logic change).
- **Out of scope:** changing where a fresh Play starts on the timeline; the global header (→ WO-034).
- **Behavior delta:** MODIFIED (in-game) — Play/Pause preserves position; a Reset button returns to 0:25.

**Phase 1 — Play/Pause + Reset**
1. [ ] `display.lua`: `playSim(false)` = pause (keep `play`/frame); add `Display.resetSim()`; `refresh()`
       re-renders a paused frame at `play.t`.
2. [ ] `config.lua` Simulation node: Play⇄Pause label on the toggle button; add a Reset button (both gated
       on Show preview).

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`.
2. [ ] **In-game (human, required):** Pause freezes in place; Play resumes; Reset returns to 0:25.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — frame/edge changes; no `_G` leaks; pure sim/layout untouched.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
