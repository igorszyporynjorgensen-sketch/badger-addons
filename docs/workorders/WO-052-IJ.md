---
wo: WO-052-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/55
decision: ~
depends_on:
  - docs/workorders/WO-045-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - projects/badger-ttk/src/live/driver.lua
---

# WO-052-IJ — fix: header band leaks across the AceGUI frame pool (#1) + master-switch gate (#5)

- **Created / Updated:** 2026-07-28
- **Objective:** two pre-1.0 audit fixes.
- **Audit #1 (HIGH — regression I shipped in WO-045):** `polishHeader` builds the brand band + insets
  `content` but never tears them down. AceGUI pools Frame widgets globally by type, so a recycled frame
  shows a stale gold band + depressed content in the next standalone config window — even another addon's.
  - **Fix (BadgerConfigUI):** keep the band by ref (`frame.frame.__badgerHeaderBand`) and `Show()` it on
    open; add `teardownHeader(widget)` that hides the band + restores `content:SetPoint("TOPLEFT",17,-27)`,
    called from the frame `OnHide` hook so the frame returns to the pool clean. `MINOR` 9 → 10.
- **Audit #5 (MEDIUM):** the live driver's `update()` samples the estimator and records kill history
  before the show/hide gate, and neither checks `p.enabled` — so the master switch keeps writing
  `db.global.history` while "off".
  - **Fix (driver.lua):** after the sim guard, early-return when `not p.enabled` (reset state + hide),
    mirroring the no-target branch — halting all observation, not just show/hide.
- **Acceptance:** closing Badger's config leaves no band/inset on the recycled frame (another Ace3 addon's
  window opens clean); with the addon disabled nothing is recorded/sampled and the display is hidden;
  `pnpm validate` green.
- **Behavior delta:** FIXED (in-game) — no cross-addon header leak; master switch halts observation.
- **Constitution check:** Principles OK — frame-edge + driver-edge (unspec'd); shared lib bumps `MINOR`.

**Phase 1** 1. [ ] BadgerConfigUI teardown + band-ref; driver enabled gate.
**Phase 2** 1. [ ] gate green; bump 0.9.33; re-embed lib; rebuild `.release`. PR.
2. [ ] **In-game:** open+close Badger, open another Ace3 config → clean; disable addon → no history writes.
