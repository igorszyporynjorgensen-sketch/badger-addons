---
wo: WO-043-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-034-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
---

# WO-043-IJ — config window: align the status bar + Close button with the content

- **Created / Updated:** 2026-07-27
- **Objective — #16:** the bottom status bar ("Reopen with …") and the **Close** button don't line up
  left/right with the content/tree above them. Align both to the content's L/R inset (17px).
- **Design notes:** in the vendored AceGUI Frame widget the content is inset **17**px L/R, but the status
  bar sits at **15** (left) and the Close button at **-27** (right). Re-anchor them in a defensive
  `polishStatusBar(frame)` (mirroring `polishTree`), applied once per `lib:Open`:
  - the status bar = the parent of the exposed `frame.statustext`; re-anchor `BOTTOMLEFT(17,15)` /
    `BOTTOMRIGHT(-122,15)` (leaving room for the Close button).
  - the Close button = the direct-child `Button` with non-empty text (the status bar bg is a text-less
    Button); re-anchor `BOTTOMRIGHT(-17,17)`.
  - No-op on any shape mismatch (Ace internals may change). `MINOR` 7 → 8.
- **Acceptance criteria:**
  - The status bar's left edge and the Close button's right edge line up with the content L/R.
  - `pnpm validate` green (the re-anchor is the Ace edge; options-tree specs unchanged).
- **Out of scope:** icons (WO-044); the two-column header redesign (WO-045).
- **Behavior delta:** MODIFIED (in-game) — the status bar + Close button align with the content.

**Phase 1 — Align**
1. [ ] `BadgerConfigUI-1.0.lua`: `polishStatusBar` in `lib:Open`; `MINOR` 7→8.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump badger-ttk `.toc` `## Version`; rebuild `.release` (re-embed the lib).
2. [ ] **In-game (human, required):** status bar + Close button align L/R with the content.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — defensive Ace-frame edge; shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
