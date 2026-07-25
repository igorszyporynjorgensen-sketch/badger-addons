---
wo: WO-023-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-018-IJ.md
  - docs/workorders/WO-019-IJ.md
related:
  - projects/badger-ttk/src/engine/render-model.lua
  - projects/badger-ttk/src/display/layout.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/sim/scenario.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/skin/skin.lua
---

# WO-023-IJ — utility-bar colour = an ACTION signal (waiting → ready/green → used/gray)

- **Created / Updated:** 2026-07-25
- **Objective:** re-work the utility-bar colour scheme from *coverage* (fits/over/short) to an **action
  signal** that tells the player **when to fire**:
  - **Waiting** — the optimal fire moment is still ahead → a calm neutral colour.
  - **Ready** — the fire moment has arrived (and stays "ready" while overdue, until used) → **green**
    ("fire this now").
  - **Used** — the ability has been fired and its buff is draining → **gray**.
- **How "ready" is decided:** a utility's **optimal fire moment** is `TTK = duration + offset` (fire there
  and the buff exactly spans the remaining kill). So for a planned (not-yet-used) entry:
  `ready = (ttk <= duration + offset)` — true at the optimal moment **and while overdue**, until it goes
  active. `used` = the buff is active/draining. This is computed in the **pure `RenderModel`** (spec-tested).
- **Sim demo — Earthstrike used 4s late:** in the dynamic sim, **Death Wish** is fired on time (at 30s-left)
  so it goes straight waiting → gray; **Earthstrike** is fired **4 seconds late** (optimal 20s-left, used at
  16s-left), so its bar shows a **4-second green window** (TTK 20 → 16) before it turns gray — a clear
  picture of "you were late". (`scenario.lua`: Earthstrike's `fireTTK` 20 → 16; its optimal stays 20 via
  `duration`.)
- **Geometry note:** planned bars become the same **steady coverage segment** as active bars
  (`[offset, offset+duration]`), shown whether waiting or ready — so a bar doesn't vanish when overdue; it
  just holds its place and changes colour, then drains once used. (The display already only draws the
  primary window, so the multi-pop comb rendering is unaffected in practice.)
- **Colours (new, configurable; retire the coverage set):** replace `colorPlanned/colorActive/colorOverkill/
  colorShortfall` with **`colorReady`** (green), **`colorUsed`** (gray), **`colorWaiting`** (neutral).
  `colorTarget` (main bar) and `colorUtility` (fallback) stay. Proposed defaults — waiting = muted blue
  `{0.30, 0.50, 0.80}`, ready = green `{0.15, 0.85, 0.25}`, used = gray `{0.55, 0.55, 0.55}` (all editable in
  the Skin node; the built-in Badger skin carries the same).
- **Acceptance criteria:**
  - A utility bar is **neutral while waiting**, turns **green the moment it's ready to fire** (and stays
    green while overdue), and turns **gray with a draining fill once used**.
  - The dynamic sim shows **Earthstrike green for ~4s** (used 4s late) then gray; **Death Wish** on-time
    (waiting → gray, no green window).
  - The three action colours are **editable** in the Skin node and shipped in the built-in skin.
  - `pnpm validate` green — the `ready` rule + planned geometry are spec-tested; sim/scenario specs updated.
- **Out of scope:** live cooldown-availability gating of "ready" (a planned ability whose own CD isn't up);
  a "fired too early / shortfall" red state; the main TTK bar's colour.
- **Behavior delta:** MODIFIED (in-game) — utility bars are coloured by action state (waiting/ready/used),
  not coverage; the sim demonstrates a late Earthstrike.

**Phase 1 — Pure `ready` state + planned geometry**
1. [ ] `render-model.lua`: add `ready = (ttk <= duration + offset)` to a planned entry. `layout.lua`: draw
       the planned bar as the steady coverage segment (like active) and carry `bar.ready`. Update the
       render-model / layout specs (ready rule; planned window now duration-based).

**Phase 2 — Colours + display mapping**
1. [ ] `display.lua`: colour utility bars by state — `used → colorUsed`, planned+`ready → colorReady`, else
       `→ colorWaiting`.
2. [ ] `core.lua` defaults + `config.lua` pickers + `skin.lua` (keys + built-in skin): add
       `colorReady/colorUsed/colorWaiting`, retire `colorPlanned/colorActive/colorOverkill/colorShortfall`.

**Phase 3 — Sim demo (late Earthstrike)**
1. [ ] `scenario.lua`: Earthstrike `fireTTK` 20 → 16 (used 4s late; optimal stays 20 via `duration`).
       Update sim/scenario specs.

**Phase 4 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.6**, rebuild `.release`.
2. [ ] **In-game (human, required):** utility bars go waiting → green (ready) → gray (used); the sim shows
       Earthstrike green for ~4s (late) then gray.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — `ready` is pure/spec-tested; colours are config/skin; display is
  edge; no `_G` leaks.
- **Decisions produced:** — (candidate: utility-bar colour is an action signal, not a coverage signal.)
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
