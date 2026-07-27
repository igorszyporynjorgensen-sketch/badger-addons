---
wo: WO-037-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/40
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-030-IJ.md
  - docs/workorders/WO-034-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - libs/BadgerConfigUI-1.0/options-tree.lua
---

# WO-037-IJ — fix: close callback fires on every close path · halve the header bottom margin

- **Created / Updated:** 2026-07-27
- **Objective — two BadgerConfigUI fixes (one MINOR bump):**
  1. **Close callback misses most close paths (#9 — a bug).** The window's close callback (which badger-ttk
     uses to turn the preview off) only fires on the **X button**. Closing via **ESC / a slash-toggle /
     `:Close`** goes through Ace's deferred `RefreshOnUpdate`, which just `:Hide()`s the frame and **never
     fires the AceGUI `OnClose`** — so `chainClose` never runs and the preview lingers on screen.
  2. **Header bottom margin too tall (#15).** The spacer at the foot of the global header should be **half**
     its current height.
- **Design notes:**
  - **Close (1):** every close path ends in the frame being **hidden**, so hook the AceGUI Frame's
    underlying `frame.frame:HookScript("OnHide", …)` in `lib:Open` (guarded once per frame instance) and fire
    `app.onClose` there. Robust across X / ESC / `:Close` / `:CloseAll`. `RefreshOnUpdate`'s *refresh* path
    re-Opens without hiding, and control changes re-feed without hiding, so `OnHide` fires **only on real
    closes**. Keep the existing `chainClose` `OnClose` hook too (idempotent `onClose`, belt-and-suspenders).
  - **Margin (2):** `options-tree.spacerArg` (used for the header foot spacer) drops from `fontSize="large"`
    to `"medium"` — roughly half the vertical space. Pure/spec-tested.
  - `MINOR` 6 → 7.
- **Acceptance criteria:**
  - Closing the config **any** way (X, ESC, `/bttk` toggle) turns the preview off — no bars linger.
  - The gap between the header and the tree is visibly smaller (about half).
  - `pnpm validate` green — `options-tree_spec` covers the spacer; the close hook is the Ace edge.
- **Out of scope:** the status-bar / Close-button alignment (#16 — separate); the bar↔border gap (#17 — a
  badger-ttk display change); the rest of the pre-1.0 config batch.
- **Behavior delta:** FIXED (in-game) — preview always closes with the window; tighter header margin.

**Phase 1 — Fixes**
1. [x] `BadgerConfigUI-1.0.lua`: `hookHide()` in `lib:Open` firing `app.onClose` on the frame `OnHide`
       (guarded), + kept `chainClose`. `options-tree.lua`: `spacerArg` fontSize large → medium. `MINOR` 6→7.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (85/21/9/4 successes, 0 failures; luacheck 0/0). badger-ttk `.toc` → **0.9.19**;
       `.release` rebuilt with the re-embedded lib (MINOR 7); parity verified.
2. [ ] **In-game (human, required):** preview turns off on ESC / toggle / X close; header margin ~half.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — `options-tree` stays pure/spec-tested; the OnHide hook is the Ace
  edge; shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** —
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/40 (merged; main green)
- **Outcome:** Branch `fix/WO-037-IJ-close-callback-header-margin`, PR #40. `hookHide()` fires `app.onClose`
  on the frame `OnHide` so every close path (X/ESC/toggle/:Close) turns the preview off; header foot spacer
  large→medium. `MINOR` 7; `.toc` 0.9.19. Gate green; `.release` rebuilt. Awaiting human merge + in-game.
