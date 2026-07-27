---
wo: WO-032-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-028-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
---

# WO-032-IJ — fix two display regressions from WO-028 (clipped utility bars · stray border)

- **Created / Updated:** 2026-07-27
- **Objective — fix two bugs the human hit testing 0.9.14:**
  1. **Utility bars disappeared** from the simulation (and any multi-bar display). WO-028 added
     `container:SetClipsChildren(true)`, but the container is only **one bar tall** (`SetSize(barWidth,
     barHeight)`); the utility bars are anchored **above** it (`BOTTOMLEFT … shown*step`), so clipping
     erases them. The TTK bar fills the container rect exactly, so it survives — hence "only the main bar".
  2. **Editing a Display value pops a stray preview.** `borderFrame` is a **sibling** of the container
     (parented to `UIParent`) and `applyContainer` calls `borderFrame:Show()` whenever a border is
     configured — regardless of whether the bars are shown — while `container:Hide()` never hides it (it's
     not a child). So changing any Display setting (→ `setterR` → `refresh` → `applyContainer`) shows the
     border box on screen, and it lingers. Preview visibility must be governed **only** by the two
     Simulation checkboxes (Show preview / Play) + a live target.
- **Design notes — one clean fix covers both:** the ONLY reason `borderFrame` was a sibling was to dodge
  the clip (see its comment). Remove the clip and re-parent `borderFrame` to the **container**, so its
  visibility tracks the container automatically (a child renders only when its parent is shown).
  - `init`: drop `container:SetClipsChildren(true)`; `borderFrame = CreateFrame("Frame", nil, container,
    "BackdropTemplate")` (child, not `UIParent`).
  - `applyContainer`: drop the now-redundant `borderFrame:SetScale/SetAlpha/SetFrameStrata` (inherited
    from the container); keep the backdrop + outset anchors + Show/Hide.
  - The WO-028 border-overflow fix stays intact: the border is still the **outset** frame 12px beyond the
    bar area, so the fill never overlaps it — the clip was redundant insurance.
- **Acceptance criteria:**
  - The simulation shows the utility bars again (Death Wish + Earthstrike), stacked above the TTK bar.
  - Changing a Display value with both Simulation checkboxes off (and no target) shows **nothing** — no
    border box, no bars. The preview appears only when Show preview / Play is on (or a live target gates in).
  - With a border selected + a preview up, the border still wraps the bar area with no fill overflow.
  - `pnpm validate` green (display edits are the off-client edge; pure layout specs untouched).
- **Out of scope:** whether the border should wrap the **whole** utility stack vs. just the TTK bar (it
  wraps the TTK-bar box, as it always has); the Simulation play/pause/reset rework (→ WO-033); the global
  header (→ WO-034).
- **Behavior delta:** FIXED (in-game) — utility bars render again; no stray border/preview on Display edits.

**Phase 1 — Fix**
1. [ ] `display.lua`: remove `SetClipsChildren`; re-parent `borderFrame` to the container; drop its
       redundant scale/alpha/strata (inherited).

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.15**, rebuild `.release`.
2. [ ] **In-game (human, required):** sim shows utility bars; editing Display values with the preview off
       shows nothing; border still wraps the bars cleanly with a preview up.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — frame/edge change in display.lua; no `_G` leaks; pure geometry
  (ns.Layout) untouched.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
