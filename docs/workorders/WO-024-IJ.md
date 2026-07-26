---
wo: WO-024-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-015-IJ.md
related:
  - projects/badger-ttk/src/live/driver.lua
---

# WO-024-IJ — fix live show/hide flicker: minTTK becomes a sticky initial-show gate

- **Created / Updated:** 2026-07-26
- **Objective:** on a real target (the human tested a normal mob with **Show on any target** on) the bars
  **flickered** — showed, vanished, came back, vanished. Fix it so a qualifying target shows **steadily**.
- **Root cause:** `LiveDriver.gate` runs every ~0.15s and returns false — hiding the display — the instant
  `ttk < minTTK` ([driver.lua:60](../../projects/badger-ttk/src/live/driver.lua#L60)). The live EWMA `ttk`
  estimate is **noisy** (bursty melee → the health-loss rate swings → `ttk` crosses `minTTK` repeatedly),
  so the bars flap. Two more faults in the same check:
  - **`showAnyTarget` doesn't bypass it** — so even the testing mode flickers.
  - **It hides the endgame of every fight** — `ttk` naturally counts down to 0, so the bars would vanish in
    the final `minTTK` seconds of *any* fight (raid bosses included), which is exactly when the "fire now"
    signal matters most.
- **Fix — `minTTK` gates the FIRST appearance, then the show is sticky:**
  - Make the gate `LiveDriver.gate(settings, context, wasShown)`. The `minTTK` check applies **only while
    not yet shown** (the initial qualification: "is this fight worth showing for?"). **Once shown, the bars
    stay** as long as the base gate holds (enabled · target present · in-combat · hostile) — through the
    endgame, ignoring `ttk` dips. This kills the flicker AND the last-`minTTK`-seconds vanish.
  - **`showAnyTarget` bypasses the `minTTK` qualification entirely** (testing → immediate, steady show).
  - **Wire `hideOnTargetDead`** (currently in the profile but unused): hide when the target is dead
    (`context.dead`) — the natural end-of-fight hide, distinct from the mid-fight flicker bug.
  - The driver keeps a per-target **`shown`** flag, fed back as `wasShown` and **reset on target change**
    (new GUID must re-qualify). The gate stays PURE + spec-tested; the sticky state lives in the edge.
- **Acceptance criteria:**
  - On a live target that qualifies (or with **Show on any target** on), the bars **show steadily** — no
    show/hide flicker as `ttk` fluctuates.
  - The bars **stay visible through the final seconds** of a fight (no vanish under `minTTK`), and hide when
    the target **dies** (if `hideOnTargetDead`), is lost, or combat ends.
  - `showAnyTarget` shows on any target immediately regardless of `ttk`.
  - `pnpm validate` green — the pure `gate` (initial-qualify + sticky + dead + showAnyTarget-bypass) is
    spec-tested.
- **Out of scope:** a general time-based hide-grace/debounce for other transient sources (combat blips) — a
  possible follow-up if flicker persists; confidence-based gating (`minConfidenceToShow` is still unused);
  the estimator's noise itself.
- **Behavior delta:** MODIFIED (in-game) — a qualifying target shows steadily (no flicker); bars persist
  through the endgame; `hideOnTargetDead` now takes effect.

**Phase 1 — Sticky gate (pure)**
1. [ ] `driver.lua` `LiveDriver.gate(settings, context, wasShown)`: `minTTK` qualifies the initial show only
       (skipped when `showAnyTarget`); `hideOnTargetDead` + `context.dead` hides on death. Update + extend
       `driver_spec.lua` (initial-qualify, sticky-stays-under-minTTK, showAnyTarget-bypass, dead).

**Phase 2 — Wire the edge**
1. [ ] `driver.lua` `update()`: keep a `shown` flag reset on GUID change; pass `context.dead =
       UnitIsDeadOrGhost("target")` and `wasShown = shown`; `shown = LiveDriver.gate(...)`; render when
       shown, else `ns.Display.hide()`.

**Phase 3 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.7**, rebuild `.release`.
2. [ ] **In-game (human, required):** a normal mob with **Show on any target** shows steadily (no flicker);
       the bars persist to the kill and hide on death.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — the gate stays a PURE spec-tested helper; the sticky flag is edge
  state; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
