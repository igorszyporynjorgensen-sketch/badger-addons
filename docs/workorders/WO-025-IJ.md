---
wo: WO-025-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/29
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-010-IJ.md
  - docs/workorders/WO-024-IJ.md
related:
  - projects/badger-ttk/src/engine/estimator.lua
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-025-IJ — recorded kill history → a steadier TTK estimate (per player level)

- **Created / Updated:** 2026-07-26
- **Objective:** the live EWMA estimate is **noisy** (a crit spikes the health-loss rate; between hits the
  rate decays and TTK balloons — the human saw TTK "up a lot then back down"). **Record every kill the
  addon observes** and use that history as a **stable prior** to smooth the estimate — kept **organized by
  the player's level** (and by target), for trash and raid bosses alike. This is the **local-recording**
  half of the long-reserved `db.global.history` seam (WO-007 / D-005); a future WarcraftLogs import can
  populate the same store.
- **Design:**
  - **Store (`db.global.history`)** keyed **`[level][key]`**: `key` = the target's **NPC id** (parsed from
    its GUID; only Creatures recorded), so a level-52 kill of a wolf and a level-20 kill of the same wolf
    stay separate. Each entry is a compact **running mean of the observed health-loss rate**
    (fraction of max HP per second) + a count: `{ n, rate }`.
  - **Record** (`src/engine/history.lua`, PURE): `record(store, level, key, rate)` updates the running mean
    (count capped so it keeps adapting to recent kills); `rate(store, level, key)` looks it up. Spec-tested.
    The live driver computes a kill's **average** rate = `healthDamaged / fightDuration` (stable, unlike the
    EWMA) when a tracked target **dies**, and records it.
  - **Blend** (`estimator.lua`, PURE — fills the existing `self.history`/blend seam): `Estimator.new` takes a
    **`priorRate`**. In `ttk()` the effective rate is `confidence·liveRate + (1−confidence)·priorRate`
    (confidence ramps `0→1` over the first ~8 rate updates, so early on it **leans on history**, then on
    live), and is **floored at a fraction of `priorRate`** so between-hit decay can't balloon TTK. With a
    prior, TTK is also **available immediately** (before live warm-up) — no nil-gap. No prior → unchanged
    pure-live behavior. Spec-tested.
  - **Wire** (`driver.lua`, edge): on a new target, parse its NPC id + read `UnitLevel("player")`, look up
    the prior, pass it to `Estimator.new`; track `fightStart` and, on death, record the kill's average rate.
  - **Config** (Estimator node): **Record kills** (default on), **Use history for the estimate** (default
    on), and a **Clear history** button. History lives in `db.global` (account-wide, survives profile
    switches — correct for observational data, per D-005).
- **Acceptance criteria:**
  - Kills of a creature are recorded to `db.global.history[level][npcId]` while **Record kills** is on;
    **Clear history** empties it.
  - With **Use history** on and prior kills recorded, the TTK estimate is **visibly steadier** (fewer/smaller
    TTK spikes) than pure-live, and an estimate appears sooner (from the prior). Turning it off reverts to
    pure-live.
  - `pnpm validate` green — `history.record`/`rate` and the estimator blend (ramp + prior-floor + immediate
    prior) are spec-tested; no live regressions when there's no history.
- **Out of scope:** the **WarcraftLogs import** (still deferred — same store, a later WO); a full health→time
  *curve* `E(h)` (this WO uses a single mean rate per key; a curve is a future refinement); cross-level
  generalization (each level keyed separately, as requested); boss phase-specific priors.
- **Behavior delta:** ADDED — kills are recorded; the estimate blends a per-level historical prior (toggle).

**Phase 1 — History store (pure) + config seam**
1. [x] `src/engine/history.lua`: `record` (running mean, capped) + `rate` lookup. `history_spec.lua`. Add
       to `.toc`. `core.lua`: profile defaults `recordHistory = true`, `useHistory = true` (history table
       already reserved in `db.global`).

**Phase 2 — Estimator blend (pure)**
1. [x] `estimator.lua`: `Estimator.new{ priorRate }`; `ttk()` blends by confidence, floors at a fraction of
       the prior, and returns the prior immediately before warm-up. Extend `estimator_spec.lua`.

**Phase 3 — Live wiring + config**
1. [x] `driver.lua`: parse NPC id from GUID + `UnitLevel("player")`; look up the prior for `Estimator.new`;
       track `fightStart`; record the kill's average rate on death (when `recordHistory`).
2. [x] `config.lua` Estimator node: **Record kills** / **Use history** toggles + **Clear history** button.

**Phase 4 — Verify**
1. [x] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.9**, rebuild `.release`.
2. [ ] **In-game (human, required):** kill some mobs; the estimate steadies on repeat kills of the same mob
       at your level; **Clear history** resets it; toggling **Use history** off reverts to pure-live.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — record/lookup + blend are PURE spec-tested modules; GUID/level/db
  reads are the edge; observational data in `db.global` (D-005); no `_G` leaks.
- **Decisions produced:** — (candidate: self-recorded per-level kill history blended as a prior; single mean
  rate per NPC id for v1, a curve later.)
- **MR:** [PR #29](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/29)
- **Outcome:** Implemented; `pnpm validate` green (79 badger-ttk specs — +7; luacheck 0/0). Pure `history` store + estimator prior blend (confidence ramp + 0.5x-prior floor + immediate prior); driver records kills by NPC id + level, config Record/Use toggles + Clear. `.toc` -> v0.9.9. **In progress** pending merge of PR #29 + the human's in-game re-test.
