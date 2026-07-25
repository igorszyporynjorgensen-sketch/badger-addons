---
wo: WO-011-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/14
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-010-IJ.md
related:
  - docs/reference/warrior-ttk-cooldowns.md
  - tools/wow-mock/init.lua
---

# WO-011-IJ — `badger-ttk` simulation driver (scripted fight → render model)

- **Created / Updated:** 2026-07-25
- **Objective:** build the **sim driver** — the second of *one engine, three drivers*. It feeds the
  WO-010 engine (`ns.Estimator` / `ns.RenderModel`) a **scripted fight** (a health-over-time curve +
  ability pop events + optional immune windows) and produces the **render model** the display draws —
  with **no live target and no frames**. Delivers the **static preview** (a frozen representative stack
  for styling/layout without a fight) as pure data. Child #4 of the WO-007 epic; it's the **dev harness**
  the display WO (#5) is validated against, and half of the user's "simulation" feature. Pure logic →
  spec-tested; **no in-game behavior** (the display renders the output later), so Done on merge + green.
- **Acceptance criteria:**
  - **Scenario data** (`src/sim/scenario.lua`, pure): at least one representative scripted scenario — a
    warrior burst kill: a `(t, healthFraction)` curve, a few **ability pop events** `{ id, at, duration,
    cooldown, offset }`, and an optional **immune window** `{ from, to }` (drives the estimator's
    `damageable = false`). Data + small builders; no WoW API.
  - **Sim stepper** (`src/sim/sim.lua`, pure — `ns.Sim`): given a scenario + a time `t`, drive
    `ns.Estimator` (samples honoring immune windows) and assemble the tracked entries' **planned/active**
    states (active `remaining` from pop events + `duration`), then call `ns.RenderModel.build(ttk,
    entries)` → the **render model at `t`**. Reuses WO-010; adds no estimator/geometry math.
  - **Static preview** (`ns.Sim.staticPreview()`): a **frozen** representative render model — a target
    bar + utility bars spanning the render-model states (a **planned** pop-line, an **active** bar that
    *fits*, one *over-covering*, one *falling-short*) — pure data the display renders for layout/skin
    styling. *(The dimmed not-usable / immune-paused visual states are display-side — showcased by the
    display's own preview, WO #5.)*
  - **Specs:** colocated `_spec.lua` — the render model is well-formed; the static preview contains each
    state; stepping the scenario yields a **decreasing** TTK; an immune window **pauses** the estimate
    (doesn't blow up). `pnpm validate` green (StyLua · Luacheck 0/0 · Busted).
  - The sim modules load (dormant) in the `.toc`, ready for the display's static-preview toggle.
- **Context / constraints:** house style — one module per file under `src/sim/`, kebab-case, register on
  `ns`, no `_G` leaks; **pure** (no frames / no WoW API) so it runs under the mock. It only *composes*
  the engine — no new estimation/geometry logic.
- **Out of scope:** **dynamic playback** (animating over real time needs a ticker/`OnUpdate` → **v1.1**,
  lands with the display); the **visible preview + the Simulation config node** wiring (display WO #5);
  frames; the live driver (samples real `UnitHealth`).
- **Behavior delta:** none in-game — pure logic; the static preview only becomes *visible* when the
  display renders it (WO #5).

**Phase 1 — Scenario**
1. [x] `src/sim/scenario.lua` — a representative warrior-burst scenario (health curve + pop events +
       an immune window) + builders.

**Phase 2 — Sim stepper + static preview**
1. [x] `src/sim/sim.lua` — `ns.Sim` drives the engine from a scenario → render model at `t`;
       `ns.Sim.staticPreview()` returns the frozen representative model. Load both in the `.toc` (dormant).

**Phase 3 — Verify**
1. [x] Colocated specs (well-formed model · every preview state · decreasing TTK · immune pause);
       `pnpm validate` green. No in-game check applies (no frames).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge. Pure logic
  → Done needs only merge + green.
- **Constitution check:** Principles OK — API-light, Ace3-/frame-free, spec-covered under the mock; no
  `_G` leaks; reuses the WO-010 engine rather than duplicating math (simplest thing that fits); dynamic
  playback deferred to v1.1.
- **Decisions produced:** — (none expected — composes WO-010; a decision only if the scenario/preview
  data shape is worth pinning as a public contract).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/14
- **Outcome:** Implemented on `feature/WO-011-IJ-sim`; **PR #14 opened**. `src/sim/scenario.lua`
  (a warrior-burst scenario — health curve flat inside a 5s immune window, two pop events) +
  `src/sim/sim.lua` (`ns.Sim.run(scenario, t)` replays samples through `ns.Estimator` → planned/active
  entries → `ns.RenderModel`; `ns.Sim.staticPreview()` returns a frozen planned + fits/over/short model)
  + colocated specs (8 cases incl. the immune-window no-blow-up and the decreasing TTK). Sim modules
  loaded (dormant) in the `.toc`. **Gate green:** stylua · luacheck 0/0 (12 files) · busted 24/0 · full
  `pnpm validate` exit 0. No frames → no in-game check applies. **PR #14 merged; `main` green.** **Done.**
