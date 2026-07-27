---
wo: WO-028-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-019-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
---

# WO-028-IJ — display/frame fixes: bar backgrounds · border clip · width anchor

- **Created / Updated:** 2026-07-27
- **Objective — three display/frame fixes from the human:**
  1. **Bar backgrounds** — the **TTK bar** gets a background track like the utility bars, and **both** the
     TTK and utility backgrounds are set to a **faint 10%-opacity** track (alpha ≈ 0.1, human-chosen).
  2. **Border overflow** — with a border on, the bar fill spills past/into the frame edge. Keep the bars
     **inside the border** (no overflow) and clip them to the bar area.
  3. **Width change** — changing **Bar width** in the Display node must (a) update the live bars
     **immediately**, and (b) keep the **right (death) edge fixed** so the display stays put (grows leftward).
- **Design notes:**
  - **Backgrounds (1):** give `targetBar` a `bg` texture (like the utility bars) painted from `colorTarget`;
    set **both** the TTK and utility `bg` alpha to **0.1**. (`display.lua` init + render.)
  - **Border clip (2):** move the backdrop border onto a **separate frame outset** from the bar container
    (so the border wraps *around* the bars instead of overlapping them), and `container:SetClipsChildren(true)`
    so a fill can never render past the bar area. The death (right) edge stays the bar's right edge.
  - **Width (3):** the Bar-width/height/spacing setters call `applyContainer()` **and** re-render so live
    bars resize at once; `applyContainer` anchors the container by its **bottom-right (death) corner** and
    `OnDragStop` records that corner, so resizing never moves the right edge. (Screen-anchor stays the
    reference corner; posX/posY become the death-corner offset.)
- **Acceptance criteria:**
  - The TTK bar shows a **faint background track**; both TTK and utility backgrounds are ~10% opacity.
  - With a border selected, **no bar fill spills outside the border**; bars sit within it.
  - Changing Bar width updates the **live** display immediately and the **right edge stays fixed** (the
    display doesn't jump sideways).
  - `pnpm validate` green (display edits are edge; the pure layout specs still pass).
- **Out of scope:** clipping to a *non-rectangular* border shape (WoW clips to the frame rect only); a config
  option for the background alpha (hard-coded 0.1 for now); the static-preview value / sim (→ WO-030).
- **Behavior delta:** MODIFIED (in-game) — faint bar backgrounds incl. the TTK bar; bars stay inside a
  border; width changes are instant and keep the right edge fixed.

**Phase 1 — Fixes**
1. [ ] `display.lua`: TTK-bar `bg` track; both backgrounds alpha 0.1; outset border frame +
       `SetClipsChildren`; death-corner anchoring; width/height/spacing setters apply + re-render at once.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.11**, rebuild `.release`.
2. [ ] **In-game (human, required):** faint backgrounds; no border overflow; width change is instant and
       keeps the right edge fixed.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — frame/edge changes in display.lua; no `_G` leaks; pure geometry
  untouched.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
