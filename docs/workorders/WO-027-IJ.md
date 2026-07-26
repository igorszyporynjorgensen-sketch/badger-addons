---
wo: WO-027-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-025-IJ.md
related:
  - projects/badger-ttk/src/live/driver.lua
---

# WO-027-IJ — record the kill rate from first-damage → death (not target-acquisition)

- **Created / Updated:** 2026-07-26
- **Objective:** kill history sometimes shows an **insanely large start-TTK** (the human saw ~1 min and ~30s
  for mobs that die in ≤5s), which then corrects. Make recorded kill rates reflect the **actual fight**, so
  the prior gives a sensible start-TTK.
- **Root cause:** WO-025 records a kill's rate as `fightStartH / (deathTime − targetAcquiredTime)`, where
  `fightStartT` is set when the target is first **selected**. Any gap between selecting a mob and actually
  damaging it (standing on it, buffing, running up) is counted as fight time → the duration is inflated →
  the recorded **rate is too low** → the next kill's prior shows a huge start-TTK (`h / lowRate`) until the
  live estimate overrides it. ~55s idle → 0.017/s → ~60s start; ~25s idle → ~30s start. Matches the report.
- **Fix (driver edge):** start the recording clock at the **first observed health drop**, not at target
  acquisition. Track `prevHealth`; when `h < prevHealth` for the first time on this target, set
  `fightStartT = now` and `fightStartH = prevHealth` (the health just before damage began). On death,
  `rate = fightStartH / (deathTime − fightStartT)` now measures only the damaging window. One-shot / zero-
  duration kills (die within a tick of first damage) are skipped (no measurable rate). Pre-fight idle is
  excluded; a fresh, accurate prior results.
- **Note:** existing records made before this fix may still be inflated — a one-time **Clear history**
  (Config → Estimator) drops them so they re-learn correctly. (No auto-migration; the store just re-fills.)
- **Acceptance criteria:**
  - After the fix, killing a mob (from full or partial health) records a rate ≈ `healthDamaged / actualKill
    seconds`, regardless of how long it was targeted beforehand.
  - On the next kill of that mob at that level, the **start-TTK is sensible** (≈ the real kill time), not
    tens of seconds.
  - `pnpm validate` green (edge-only change; the pure history/estimator specs are untouched).
- **Out of scope:** excluding mid-fight idle *gaps* (rare; still counted as fight time — correct for TTK);
  a warm-up guard on the pure-live first sample (separate, only if new-mob starts still spike); the
  health→time curve.
- **Behavior delta:** MODIFIED — recorded kill rates (and thus the history prior's start-TTK) reflect the
  real fight, not idle-before-combat.

**Phase 1 — Fix the recording window**
1. [ ] `driver.lua` `update()`: track `prevHealth`; set `fightStartT`/`fightStartH` at the first health
       drop (not on GUID change); record on death from that window (skip zero-duration). Reset per target.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.10**, rebuild `.release`.
2. [ ] **In-game (human, required):** **Clear history**, then kill a mob after idling on it → the next kill's
       start-TTK is sensible (no ~30s/1-min spike).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — a small edge fix to the recording window; the pure `History`/
  `Estimator` logic is unchanged; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
