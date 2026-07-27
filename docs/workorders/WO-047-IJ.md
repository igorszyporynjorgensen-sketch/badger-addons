---
wo: WO-047-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/50
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on: []
related:
  - projects/badger-ttk/src/config/config.lua
---

# WO-047-IJ — Display node: pair the Text-offset sliders two-per-row

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** in the Display node's **Text offsets** section, put the two **TTK**
  sliders (X, Y) next to each other on one line, and the two **Utility** sliders (X, Y) next to each
  other on the line **below** — a 2×2 grid instead of the current single-column stack.
- **Design notes:** the four `range` sliders (`ttkTextX` 15.1, `ttkTextY` 15.2, `utilTextX` 15.3,
  `utilTextY` 15.4) currently have no explicit `width`, so AceConfig flows them one per row. Set each to
  `width = "half"`: two half-width controls fill a row, so the flow wraps after each pair —
  `[TTK X · TTK Y]` on row one, `[Utility X · Utility Y]` on row two. Order already groups them
  correctly (TTK pair before the Utility pair), and `width = "half"` is the established idiom in this
  config (the per-ability colour pickers already use it). Pure data change to the options table.
- **Acceptance criteria:**
  - The Text-offsets section shows TTK X + TTK Y side by side, with Utility X + Utility Y on the next
    line. No other Display controls move.
  - `pnpm validate` green (no logic change; config is the unspec'd AceConfig edge).
- **Out of scope:** any slider ranges/steps/behaviour; other Display sections.
- **Behavior delta:** MODIFIED (in-game) — the Text-offset sliders lay out as a 2×2 grid.
- **Risk:** layout is unverifiable off-client — if a pair fails to sit on one row (padding/rounding),
  the fallback is an explicit full-width line-break between the pairs; confirm with a `/reload`.

**Phase 1 — Layout**
1. [x] `config.lua`: `width = "half"` on `ttkTextX` / `ttkTextY` / `utilTextX` / `utilTextY`.

**Phase 2 — Verify**
1. [x] `pnpm validate` green; bumped 0.9.28.; rebuild `.release`. PR for
   human merge.
2. [ ] **In-game (human, required):** the two TTK sliders share a line above the two Utility sliders.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — a data-only tweak to the AceConfig options table (the unspec'd
  edge); no `ns`/`_G`/logic change.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
