---
wo: WO-018-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
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
- **Root causes (from the v0.9.0 in-game test):**
  1. **Dynamic only shows if static is checked.** `Sim.run` reconstructs TTK by feeding scenario samples
     into a fresh EWMA estimator; at low `t` it has too few samples, so `estimator:ttk()` is `nil` →
     `Layout.compute` returns `ok = false` → `render` hides every bar. Static "priming" the container is
     the only reason anything appeared. **Fix:** drive the preview from a **deterministic TTK countdown**
     (`ttk = total − t`), always known, so the dynamic preview stands on its own.
  2. **Utility bars oversized / funky.** The jittering EWMA `ttk` (plus the old health curve + immune
     window) made the pixel windows recompute wildly; `over`-coverage bars clamp to full width. The
     deterministic countdown + the two exactly-fitting pops produce stable, sensible bars.
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

**Phase 1 — Deterministic warrior scenario**
1. [ ] `sim/scenario.lua`: replace the sample/immune `warriorBurst` with a deterministic spec —
       `total = 50`; pops `{ id, name, duration, fireTTK, cooldown, offset }` for Death Wish (30s @ 30
       left) and Earthstrike (20s @ 20 left) only.
2. [ ] `sim/sim.lua` `Sim.run(scenario, t)`: return `(model, ttk, health)` from a **deterministic
       countdown** — `ttk = max(0, total − t)`, `health = ttk/total`; each pop is `active` (with
       `remaining`) once `t ≥ total − fireTTK`, else `planned`; entries carry `name`.

**Phase 2 — Names through the model + display + the width-cap invariant**
1. [ ] `engine/render-model.lua` + `display/layout.lua`: pass `name` through (additive — geometry
       unchanged). **`Layout.compute` clamps every window to `[0, width]`** so no bar can exceed the TTK
       bar's width (an over-long ability fills the full bar); add a spec proving an over-duration entry →
       full-width, never wider.
2. [ ] `display/display.lua` `render`: set each utility bar's text from its `name` (+ remaining when
       `showTimers`), gated by `showBarNames`. Give the static preview entries names too.
3. [ ] `live/driver.lua` `assembleEntries`: carry `name` from the ability table so live bars are labelled.

**Phase 3 — Specs + verify**
1. [ ] Update `sim_spec.lua`, `scenario_spec.lua`, and add `name`-passthrough asserts to the render-model /
       layout specs. `pnpm validate` green.
2. [ ] Bump `.toc` `## Version` → **0.9.1** (new test build), rebuild `.release`.
3. [ ] **In-game (human, required):** dynamic Play with static off shows the 50s warrior countdown with
       named, correctly-sized Death Wish / Earthstrike bars.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; human re-test.
- **Constitution check:** Principles OK — pure geometry/sim changes stay API-light and spec-tested; display
  edit is edge; `name` is an additive passthrough; no `_G` leaks.
- **Decisions produced:** — (candidate D-005: the sim preview is a deterministic *visual* demo, not an
  estimator harness — the estimator's live/immune behavior stays covered by the engine specs.)
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
