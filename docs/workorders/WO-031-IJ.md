---
wo: WO-031-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
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
1. [ ] `skin.lua`: remove the four placement fields from `DISPLAY_FIELDS`; update the comment.
   `skin_spec`: assert `saveCurrent` omits them + `apply` leaves the frame position/lock untouched.
   `config.lua`: save-as-skin copy clarifies placement is kept.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`. Record D-010-IJ,
   mark D-008 amended.
2. [ ] **In-game (human, required):** save a skin at one spot, move the bars, re-apply — the bars stay put
   and the lock is unchanged; the look still applies.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — pure `DISPLAY_FIELDS` list change, spec-tested; no `_G` leaks.
- **Decisions produced:** D-010-IJ (amends D-008 — skins exclude frame position/lock).
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
