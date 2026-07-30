---
wo: WO-072-IJ
status: Accepted
assigned: IJ
mr: ~
decision: D-015-IJ
depends_on:
  - docs/workorders/WO-069-IJ.md
related:
  - projects/badger-ttk/src/engine/history.lua
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/core.lua
  - docs/reference/kill-history-schema.md
---

# WO-072-IJ — Kill-history recording → the D-012 record schema (the 1.0.0 forward-compat MUST)

- **Created:** 2026-07-30
- **Anchor:** [D-015-IJ] (Path B 1.0.0). Closes the 1.0.0 gap audit's Tier-1 #3
  (`docs/reference/v1.0.0-gap-audit.md`).
- **Objective:** make local recording write the **D-012 record schema** it was declared to
  (`docs/reference/kill-history-schema.md`), so a locally-observed kill and a future Warcraft-Logs import
  are the SAME shape and blend into one prior. Today `history.lua` writes the old WO-025 running-mean shape
  (`store[level][key]={n,rate}`) with none of the WCL-shared fields — the forward-compat promise is unmet.
- **Scope (shipped code):**
  - **`src/engine/history.lua`** — rewrite (pure). `db.global.history = { encounter = {[encounterID]=…},
    creature = {[creatureID]=…} }`; each list holds per-kill records
    `{ name, level, dur, size, comp={CLASS=n}, diff, src, when }` (rate = 1/dur). `History.record` appends
    + prunes (most-recent **50**, drop **>180 days**). `History.rate` derives a recency-weighted,
    size-preferring prior rate (health-fraction/s) — same units the estimator's `priorRate` already
    consumes. `History.ensureShape` normalizes/migrates (old shape is unrecoverable → wiped).
  - **`src/live/driver.lua`** — record path stamps the live record (roster scan → `size`+`comp`, encounter
    id + boss-level → identity, `time()` → `when`); prior lookup resolves encounter-vs-creature identity;
    identity captured at engage (avoids the ENCOUNTER_END race); threaded through the retarget stash.
  - **`src/core.lua`** — default `history = { encounter = {}, creature = {} }` + a one-time `ensureShape`
    migration in `OnInitialize` (wipes old-shape data).
  - **`src/engine/history_spec.lua`** — rewrite for the new pure API. **CHANGELOG `[Unreleased]`**: note the
    schema change + the one-time history reset.
- **Out of scope:** the WCL importer + external converter (D-012 piece 2, deferred); prior comp/DPS-proxy
  scaling (record captures `comp` now for forward-compat; blending stays size-preferring for v1).
- **Behavior delta:** MODIFIED (recording shape; a one-time reset of old local history — a prior that
  regenerates as you play). No user-visible bar change.
- **Constitution check:** Principles OK — `history.lua` stays PURE (no WoW API; `now`/`when` passed in) and
  specced; the WoW-API roster/encounter reads live in the driver's untestable edge; no `_G` leak; no
  version bump (D-011, the bump is the 1.0.0 sign-off).
- **Acceptance:** gate green (incl. rewritten `history_spec`); records written in the D-012 shape with all
  fields; old shape migrated/wiped; the estimator prior still derives a sensible rate; **estimator-sim
  byte-identical** (recording/prior changes don't touch the pure estimator). Verified in-game with the
  1.0.0 `/reload`.

**Phase 1** 1. [ ] history.lua + spec (pure schema). 2. [ ] driver record/prior + core migration. 3. [ ] adversarial review + PR.
