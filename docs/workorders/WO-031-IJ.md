---
wo: WO-031-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/34
decision: D-010-IJ      # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-029-IJ.md
related:
  - projects/badger-ttk/src/skin/skin.lua
---

# WO-031-IJ — skins exclude frame position & lock (amends D-008)

- **Created / Updated:** 2026-07-27
- **Objective — a skin is a LOOK preset, not a placement one.** Per the human, a saved skin must **not**
  carry the frame's **position or lock** — so applying a skin restyles the bars **without moving them or
  changing whether they're locked**. Everything else a skin captures stays (media, colours, font sizes,
  and the geometry/readout *look*: size, scale, opacity, strata, growth, the readout toggles).
- **Design notes:**
  - `skin.lua` `DISPLAY_FIELDS`: drop `anchorPoint`, `posX`, `posY`, `locked`. `Skin.saveCurrent` then
    never snapshots them and `Skin.apply` never writes them — a pure-list change, both directions follow.
  - **Backward-compatible:** a skin already saved (0.9.12/0.9.13) may still hold those four fields in its
    stored `display` block; since `apply` iterates `DISPLAY_FIELDS`, the stale fields are simply ignored —
    no migration needed.
  - This **amends D-008** (which captured the full Display incl. position). Record **D-010-IJ** and mark
    D-008 amended.
  - `config.lua` save-as-skin `desc`: clarify that your placement/lock are kept (not captured).
- **Acceptance criteria:**
  - Saving a skin and re-applying it (or applying a different skin) **never moves the bars** and never
    flips the lock; size/scale/opacity/strata/growth/colours/media/font-sizes/readout toggles still apply.
  - `Skin.saveCurrent` output has **no** `anchorPoint/posX/posY/locked` in its `display` block.
  - `pnpm validate` green — `skin_spec` updated to assert position/lock are excluded (both capture + apply).
- **Out of scope:** any other skin field; a UI to choose *which* fields a skin captures (fixed contract).
- **Behavior delta:** MODIFIED (in-game) — applying a skin no longer moves the frame or changes its lock.

**Phase 1 — Exclude position/lock**
1. [x] `skin.lua`: removed `anchorPoint/posX/posY/locked` from `DISPLAY_FIELDS`; updated the comments.
   `skin_spec`: asserts `saveCurrent` omits them (capture) + `apply` leaves an existing profile's
   `anchorPoint/posX/posY/locked` untouched (apply, all four). `config.lua`: save-as-skin copy clarifies
   placement/lock are kept.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (85/20/9/4 successes, 0 failures; luacheck 0/0). `.toc` `## Version` → **0.9.14**;
   `.release` rebuilt + parity/load-graph verified. D-010-IJ recorded; D-008 marked amended. A read-only
   3-lens adversarial review confirmed correctness (no consumer reads the excluded fields; single-source
   list; backward-compat); its one should-fix (missing apply-side `posY` assertion) was folded in.
2. [ ] **In-game (human, required):** save a skin at one spot, move the bars, re-apply — the bars stay put
   and the lock is unchanged; the look still applies.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — pure `DISPLAY_FIELDS` list change, spec-tested; no `_G` leaks.
- **Decisions produced:** D-010-IJ (amends D-008 — skins exclude frame position/lock).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/34 (merged; main green)
- **Outcome:** Branch `feature/WO-031-IJ-skin-exclude-position`, PR #34. Removed the four placement fields
  from the single `DISPLAY_FIELDS` list, so both capture (`saveCurrent`) and restore (`apply`) drop
  position/lock. Backward-compatible (stale fields on already-saved skins are ignored). `skin_spec` locks
  in both directions; config copy updated; D-010 recorded, D-008 marked amended. `.toc` → 0.9.14; gate
  green; `.release` rebuilt + verified; adversarial 3-lens review clean (one posY assertion folded in).
  Awaiting human merge + in-game re-test.
