---
wo: WO-012-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/15
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-010-IJ.md
  - docs/workorders/WO-011-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - tools/wow-mock/init.lua
---

# WO-012-IJ — `badger-ttk` display: frames, layout & movable container (sim-driven)

- **Created / Updated:** 2026-07-25
- **Objective:** the **first visible feature** — render a render-model into on-screen `CreateFrame`
  bars. Driven by the **sim** (static preview + dynamic playback), so the user gets **animated,
  draggable bars** without the live-combat driver yet. Part **(a)** of the split display (child #5);
  the **skin engine** is part (b), WO-013. Styling here uses the **config's state colours + a default
  texture/font**; the rich `RegisterSkin` system layers on in WO-013.
- **Design split (testable vs in-game):** the **seconds→pixels layout math is a pure helper**
  (`src/display/layout.lua`, `ns.Layout`) — render-model (TTK-seconds coords) + bar width/scale → **pixel
  rects** — so it's spec-tested under the mock. The **frame glue** (`src/display/display.lua`) is the thin
  untestable edge that applies the rects/colours/text to real frames.
- **Acceptance criteria:**
  - **`ns.Layout`** (pure): given a render-model + `{ width, height, spacing, scale }`, return pixel rects
    — target bar full width = its TTK; each utility bar **right-anchored to death**, length = time-ratio
    (`(seconds / ttk) × width`), with the **offset anchor** shifted (incl. **negative** → right of the
    death line via a small right-margin) and **pop-line x-positions**. Spec-tested: bars **resize as TTK
    changes**, right-anchoring holds, ± offset shifts correctly.
  - **`ns.Display`** (frame glue): stacked bars (target **bottom**, utilities grow **UP**) built with
    `CreateFrame`, applying the layout rects + **per-state colours** (`db.profile.color*`), `m:ss`/seconds
    text (`db.profile.timeFormat`), drain, and **pop-line comb** markers. **Re-renders every update** from
    the current render-model (so bars resize dynamically as TTK fluctuates).
  - **Movable container:** lock/unlock **drag-to-place** (`EnableMouse` / `RegisterForDrag`; `OnDragStop`
    persists `posX`/`posY`), a **reset-position** action, and **`scale`** / anchor / opacity / strata
    applied — all bound to the WO-009 `db.profile` settings.
  - **Sim-driven:** wire the **Simulation** config node — **static preview** (render
    `ns.Sim.staticPreview()`) and **dynamic playback** (an `OnUpdate` / `C_Timer` ticker steps
    `ns.Sim.run` over the scenario, animating the bars) with play/pause + speed.
  - **Config comes alive:** the WO-009 Display/Skin settings (colours, sizes, layout, format) now visibly
    drive the sim display; add the **reset-position** button to the Display node.
  - **Gate:** `pnpm validate` green; `ns.Layout` carries a colocated `_spec`. Frame glue loads under the
    mock without error (its geometry is delegated to the spec-tested `ns.Layout`).
  - **In-game (human, deferred for now):** `/reload`, toggle the sim → bars appear, animate, drag, and
    respect the colour/scale settings.
- **Context / constraints:** house style — `src/display/` modules on `ns`, no `_G` leaks; the pure layout
  math is spec-covered, the frame creation is the documented untestable edge (an in-game check, currently
  waived). Add any WoW globals the frames use to the badger-ttk `.luacheckrc` overlay.
- **Out of scope:** the **skin engine** — the `RegisterSkin` format, built-in skins, LSM font/texture/
  border pickers (**WO-013**); the **live-combat driver** (real `UnitHealth` sampling) and **ability
  tracking** (which entries are live) → they feed the same display once the **ability model (WO #7)**
  lands; the **trend band** (needs history, post-v1).
- **Behavior delta:** ADDED (in-game) — the on-screen bars appear for the first time, driven by the
  sim/preview. Real-combat data arrives with the live driver + ability model.

**Phase 1 — Layout helper**
1. [x] `src/display/layout.lua` (`ns.Layout`) — render-model + dims → pixel rects (right-anchored,
       time-ratio, offset, pop-lines). Colocated `_spec` (resize, anchoring, ± offset).

**Phase 2 — Frames + movable container**
1. [x] `src/display/display.lua` (`ns.Display`) — `CreateFrame` bars applying the rects + colours + text
       + pop-line markers; lock/unlock drag, reset-position, scale/anchor/opacity/strata. Load in `.toc`.

**Phase 3 — Sim wiring**
1. [x] Wire the Simulation config node: static preview + dynamic playback ticker (`ns.Sim`); add the
       Display **reset-position** button.

**Phase 4 — Verify**
1. [x] `pnpm validate` green; `ns.Layout` spec passes; frame glue loads under the mock. In-game
       appear/drag/animate check deferred to the human.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; the in-game
  appearance/drag check is the human's (currently waived).
- **Constitution check:** Principles OK — the geometry math is API-light and spec-covered (house rule);
  frame creation is the documented off-client-untestable edge; no `_G` leaks; the skin engine + live
  driver are split out so this PR stays reviewable (simplest thing that fits).
- **Decisions produced:** — (a decision only if the `ns.Layout` public shape or the frame structure is
  worth pinning).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/15
- **Outcome:** Implemented on `feature/WO-012-IJ-display`; **PR #15 opened**. `ns.Layout` (pure,
  spec-tested — render-model → pixel windows, right-anchored/time-ratio/± offset/resize) + `ns.Display`
  (frame glue: statusbar pool, per-state colours, `m:ss`, reverse-fill target, movable container with
  drag/reset/scale, static preview + dynamic playback). Config gains the real **Simulation** node + a
  **reset-position** button; position/lock/scale re-apply live. Forward-compatible tweaks: render-model
  carries `duration`, `Sim.run` also returns `health`. **Gate green:** stylua · luacheck 0/0 (15 files)
  · busted 31/0 · full `pnpm validate` exit 0. **In-game appear/drag/animate check deferred (waived).**
  **PR #15 merged; `main` green.** **Done** — the addon's first on-screen bars.
