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

# WO-027-IJ — config: every changeable option gets a hint + record kill-rate from first-damage

- **Created / Updated:** 2026-07-26
- **Objective (two folded-in fixes):**
  1. **Config hints** — **every changeable option** (toggle / range / select / colour / execute) gets a
     helpful **`desc`** hint (the AceConfig tooltip). An audit found **30 of 51** static options with no
     hint, plus the generated **per-ability enable** and **per-encounter** toggles. Add concise hints to all.
  2. **Start-TTK fix** — kill history sometimes shows an **insanely large start-TTK** (the human saw ~1 min
     and ~30s for mobs that die in ≤5s), which then corrects. Make recorded kill rates reflect the **actual
     fight**, so the prior gives a sensible start-TTK.
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
  - **Every** changeable config option shows a hint on hover (audit re-run reports **0 missing `desc`**),
    including the per-ability and per-encounter toggles. Hints are concise and say what the setting does.
  - After the start-TTK fix, killing a mob (from full or partial health) records a rate ≈ `healthDamaged /
    actualKill seconds`, regardless of how long it was targeted beforehand; the next kill's **start-TTK is
    sensible** (≈ the real kill time), not tens of seconds.
  - `pnpm validate` green (config copy + an edge-only driver change; the pure history/estimator specs are
    untouched).
- **Out of scope:** excluding mid-fight idle *gaps* (rare; still counted as fight time — correct for TTK);
  a warm-up guard on the pure-live first sample (separate, only if new-mob starts still spike); the
  health→time curve; restructuring the config tree (hints only).
- **Behavior delta:** MODIFIED — every changeable option has a tooltip hint; recorded kill rates (and thus
  the history prior's start-TTK) reflect the real fight, not idle-before-combat.

**Phase 1 — Config hints**
1. [ ] `config.lua`: add a `desc` to every changeable option lacking one — Behavior (in-combat / hide-on-
       dead / hostile-only), Skin (texture/font/border + the 5 colours + font sizes), Display (anchor / lock
       / offsets / scale / bar size+spacing / max bars / opacity / strata / reset / names / icons / time
       format / confidence), Simulation (playback speed), and the generated **per-ability** + **per-
       encounter** toggles. Re-run the audit → 0 missing.

**Phase 2 — Start-TTK fix (recording window)**
1. [ ] `driver.lua` `update()`: track `prevHealth`; set `fightStartT`/`fightStartH` at the first health
       drop (not on GUID change); record on death from that window (skip zero-duration). Reset per target.

**Phase 3 — Verify**
1. [ ] `pnpm validate` green; audit reports 0 changeable options without `desc`. Bump `.toc` `## Version` →
       **0.9.10**, rebuild `.release`.
2. [ ] **In-game (human, required):** every option shows a hint on hover; after **Clear history**, killing a
       mob after idling on it gives a sensible start-TTK (no ~30s/1-min spike).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — a small edge fix to the recording window; the pure `History`/
  `Estimator` logic is unchanged; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
