---
wo: WO-030-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-018-IJ.md
related:
  - projects/badger-ttk/src/sim/sim.lua
  - projects/badger-ttk/src/sim/scenario.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/config/config.lua
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
---

# WO-030-IJ — simulation rework: one preview, play/stop it, 0:25, and stop on config close

- **Created / Updated:** 2026-07-27
- **Objective — unify the preview and tidy its lifecycle:**
  1. **One simulation** — today the *static* preview (a frozen generic stack) and the *dynamic* playback (a
     separate warrior scenario) are two different things. Make them **one**: the **static setup is the single
     source of the UI representation**, and the **dynamic Play/Stop button just loops that same setup**
     (start = animate it, stop = freeze it). The bars you see static are the bars that animate.
  2. **Reads 0:25** — the frozen/starting preview shows a time-to-kill of **0:25**.
  3. **Stop on close** — if a preview is up and the **config window is closed**, the preview **shuts down**
     (hands control back to the live driver).
- **Design notes:**
  - **Unify (1):** collapse to **one scenario** that both modes share. The static preview = that scenario
    frozen at a representative moment; Play = the same scenario looped over real time; Stop = freeze it again
    (not hide). So `showPreview` renders the scenario at the freeze-time, and `playSim(true/false)` toggles the
    animation of that *same* scenario. The two config controls become: **Static preview** = show/hide the
    preview; **Play / stop** = animate that shown preview (Stop returns to the frozen view). One source →
    what you style is what plays.
  - **0:25 (2):** the scenario's total / freeze-time yields `ttk = 25` at the frozen moment (e.g. a 50s
    scenario frozen at t=25, or the scenario re-scaled so the still shows 0:25). The utility bars shown at
    that moment illustrate the setup.
  - **Stop on close (3):** `BadgerConfigUI` fires a close callback (hook `AceConfigDialog` close /
    `OnClose`); badger-ttk turns off `simStatic`/`simPlaying`, hides the preview, and resumes the live driver
    (`Display.showPreview(false)` / `playSim(false)`), so a preview never lingers after the window closes.
- **Acceptance criteria:**
  - Turning on **Static preview** shows the setup (bars) frozen at **0:25**; pressing **Play** animates
    *those same* bars on a loop; **Stop** returns to the frozen 0:25 view (same bars).
  - There is **one** set of preview bars — styling/config changes are reflected in both the frozen and the
    animated view.
  - **Closing the config window** with a preview up turns the preview off and lets the live driver resume.
  - `pnpm validate` green — the unified `Sim` (freeze + run one scenario) is spec-tested; the close hook is
    the edge.
- **Out of scope:** editing the scenario from the UI (the setup is still code-defined data); multiple saved
  sim setups; the display frame fixes (→ WO-028).
- **Behavior delta:** MODIFIED (in-game) — a single unified preview (static = frozen, Play = looped) reading
  0:25; closing the config stops any preview.

**Phase 1 — One scenario / unified Sim**
1. [ ] `sim.lua` + `scenario.lua`: one scenario is the single source; `showPreview` renders it frozen at the
       0:25 moment, `playSim` animates/loops the same scenario, Stop re-freezes it. Update sim/scenario specs.

**Phase 2 — Config + close hook**
1. [ ] `config.lua` Simulation node: reword controls to "show the preview" + "play/stop the shown preview".
2. [ ] `BadgerConfigUI-1.0.lua`: a close callback; badger-ttk turns off the preview + resumes the driver when
       the window closes.

**Phase 3 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`.
2. [ ] **In-game (human, required):** one preview (frozen 0:25 → Play loops same bars → Stop re-freezes);
       closing the config kills the preview and the live display resumes.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — unified `Sim` stays pure/spec-tested; the close hook + preview
  toggles are edge; no `_G` leaks.
- **Decisions produced:** — (candidate: the sim is one scenario; static = frozen view, dynamic = looped view
  of the same setup.)
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
