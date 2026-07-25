---
wo: WO-018-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/21
decision: D-007-IJ
depends_on:
  - docs/workorders/WO-012-IJ.md
  - docs/workorders/WO-017-IJ.md
related:
  - projects/badger-ttk/src/sim/scenario.lua
  - projects/badger-ttk/src/sim/sim.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/engine/render-model.lua
  - projects/badger-ttk/src/display/layout.lua
---

# WO-018-IJ — `badger-ttk` simulated-preview fidelity (deterministic warrior demo + bar names)

- **Created / Updated:** 2026-07-25
- **Objective:** the v0.9.0 preview showed up but the *dynamic* sim misbehaves. Make the dynamic preview a
  clean, deterministic **warrior** demonstration to the human's spec, fix its geometry, and add the missing
  utility-bar names/timers.
- **Human spec for the sim:** warrior; **total TTK starts at 50s** and counts down to 0; fire the two
  example utilities — **Death Wish (30s) at 30s-left** and **Earthstrike (20s) at 20s-left** — and *only*
  those two. (Both then expire exactly at death → a textbook "perfectly covered kill".)
- **Coordinate model — FIXED TIMELINE, SIM ONLY (human decision, → D-007).** The render rescales the x-axis
  to the *current* TTK (window is always "now → death"), so a linear countdown makes bars grow. The human
  wants steady bars **in the sim preview only** — **live keeps the rescale-to-current-TTK model unchanged**
  (a real estimate genuinely fluctuates, so rescaling is correct there). Implementation is purely additive:
  the render model gains an optional **`total`** scale — `xOf(v) = width · (total − v) / total` — that
  **defaults to `ttk`** (so live behaves exactly as today). The **sim passes `total = 50`** (fixed), so its
  utility bars are placed by absolute time-from-death and hold the same width/position their whole life
  (planned AND active); only the health fill + a "now" marker move.
- **Root causes (from the v0.9.0 in-game test):**
  1. **Dynamic only shows if static is checked.** `Sim.run` reconstructs TTK by feeding scenario samples
     into a fresh EWMA estimator; at low `t` it has too few samples, so `estimator:ttk()` is `nil` →
     `Layout.compute` returns `ok = false` → `render` hides every bar. Static "priming" the container is
     the only reason anything appeared. **Fix:** drive the preview from a **deterministic TTK countdown**
     (`ttk = total − t`), always known, so the dynamic preview stands on its own.
  2. **Utility bars oversized / funky / growing (in the sim).** Two causes: the jittering EWMA `ttk`, and
     the rescale-to-current-TTK model (a linear countdown still grows the bars). **Fix:** the deterministic
     countdown + the **sim-only fixed-timeline** `total` scale → sim bars are steady; and the pure `Layout`
     clamps every window to `[0, width]` (all modes) so none can exceed the TTK bar.
  3. **No names on utility bars.** `render()` only ever sets the *main* bar's text. **Fix:** thread a
     display `name` through the render model → layout → display, and set each utility bar's text
     (honouring `showBarNames` / `showTimers`: active → "Name  Ns", planned → "Name").
- **Acceptance criteria:**
  - **Dynamic Play works with static OFF** — bars are visible from the first second, no priming needed.
  - The dynamic preview is the warrior 50s countdown: main bar reads 0:50 → 0:00; **Death Wish** appears as
    a planned pop-line at 30s-left then becomes an active bar when the countdown passes it; **Earthstrike**
    likewise at 20s-left; no other utilities.
  - Utility bars are **right-anchored to death**, length ∝ their time window, and **can never be wider than
    the TTK bar** — an ability longer than the total TTK (e.g. Diamond Flask 60s vs a 50s kill) just fills
    the **full** width, it does not overflow. This cap is a **spec-tested invariant in the pure `Layout`**
    (windows clamped to `[0, width]`), not just a display-side clamp. Stable, no jitter/oversizing.
  - **Utility bars show their name** (and, with `showTimers`, the remaining seconds while active).
  - `pnpm validate` green — sim/scenario/render-model/layout specs updated to the new deterministic contract
    and the `name` passthrough.
- **Out of scope:** live-target naming polish beyond wiring `name` from the ability table; new estimator
  behavior; the WarcraftLogs seam; boss registry.
- **Behavior delta:** MODIFIED (in-game) — dynamic preview is a deterministic warrior countdown that no
  longer needs static; utility bars are correctly sized and now labelled.

**Phase 1 — Fixed-timeline `total` scale (additive; live unchanged)**
1. [x] `engine/render-model.lua`: `RenderModel.build(ttk, entries, total)` — `total` **defaults to `ttk`**
       (live callers unchanged), carried onto the model.
2. [x] `display/layout.lua`: scale by `model.total` (`xOf(v) = width·(total−v)/total`) with `total`
       defaulting to `ttk`; **clamp every window to `[0, width]`** (all modes — the width cap). `ok` follows
       `total > 0`. Existing ttk-scale specs still hold (total defaults to ttk); add specs for the
       fixed-`total` case and an over-duration entry → full-width (never wider).

**Phase 2 — Deterministic warrior scenario (steady, sim only)**
1. [x] `sim/scenario.lua`: replace the sample/immune `warriorBurst` with a deterministic spec —
       `total = 50`; pops `{ id, name, duration, fireTTK, cooldown, offset }` for Death Wish (30s @ 30
       left) and Earthstrike (20s @ 20 left) only.
2. [x] `sim/sim.lua` `Sim.run(scenario, t)`: return `(model, ttk, health)` from a **deterministic
       countdown** — `ttk = max(0, total − t)`, `health = ttk/total`; each pop is `active` (with
       `remaining`) once `t ≥ total − fireTTK`, else `planned`; build with `RenderModel.build(ttk, entries,
       total)` so the sim bars are steady. `staticPreview` likewise passes a fixed `total`.

**Phase 3 — Names through the model + display**
1. [x] `engine/render-model.lua` + `display/layout.lua`: pass `name` through (additive).
2. [x] `display/display.lua` `render`: set each utility bar's text from its `name` (+ remaining when
       `showTimers`), gated by `showBarNames`. Static preview entries get names too. (Main bar keeps
       filling to `health` — which the sim sets to `ttk/total`, and which is the real health fraction
       live — so no change was needed there.)
3. [x] `live/driver.lua` `assembleEntries`: carry `name` from the ability table so live bars are labelled.

**Phase 4 — Specs + verify**
1. [x] Update `sim_spec.lua`, `scenario_spec.lua`, and add `total`-scale, width-cap, and `name`-passthrough
       asserts to the render-model / layout specs. `pnpm validate` green.
2. [x] Bump `.toc` `## Version` → **0.9.1** (new test build), rebuild `.release`.
3. [x] **In-game (human, required):** dynamic Play with static off shows the 50s warrior countdown with
       named, steady, correctly-sized Death Wish / Earthstrike bars. **Confirmed by the human — "worked
       really well".**

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; human re-test.
- **Constitution check:** Principles OK — pure geometry/sim changes stay API-light and spec-tested; display
  edit is edge; `name` is an additive passthrough; no `_G` leaks.
- **Decisions produced:** **D-007-IJ** — the display timeline is scaled by a `total` (defaults to `ttk`,
  so live is unchanged); the sim uses a fixed `total` for steady bars; utility bars are coverage segments
  clamped to `[0, width]`; the sim is a deterministic visual demo, not an estimator harness.
- **MR:** [PR #21](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/21)
- **Outcome:** Implemented; `pnpm validate` green (58 badger-ttk specs + 16/9/4; luacheck 0/0). `.toc` →
  v0.9.1. One deviation from the plan text: the main bar keeps filling to `health` (= `ttk/total` in the
  sim, real health live) rather than a separate `ttk/total` path — equivalent for the sim, correct for
  live. **PR #21 merged**; rebuilt `.release/BadgerTTK` at v0.9.1 (load graph resolves 65/0, source parity
  clean, all fix markers present). **In progress** pending the human's in-game re-test (dynamic Play with
  static off → steady named Death Wish / Earthstrike bars on the 50s countdown; config shows v0.9.1).
