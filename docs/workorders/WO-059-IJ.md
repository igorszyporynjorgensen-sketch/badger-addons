---
wo: WO-059-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on:
  - docs/workorders/WO-055-IJ.md
related:
  - projects/badger-ttk/src/sim/scenario.lua
  - projects/badger-ttk/src/display/display.lua
---

# WO-059-IJ — preview icons: real ability ids in the sim + a Ragnaros stand-in on the TTK bar

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** the preview shows no icons with "Show icons" on. Mock them: Ragnaros
  for the TTK bar, Earthstrike + Death Wish icons for the utility bars.
- **Design notes:** the clean fix is audit #6's remedy — the sim scenario's synthetic string ids
  (`"deathwish"`/`"earthstrike"`) never matched the AbilityTable, so icon (and per-ability colour)
  lookups missed. Switch the scenario to the REAL ids — Death Wish spell **12328**, Earthstrike item
  **21180** — and the existing display resolution just works (icons AND per-ability colours now show in
  preview; audit #6 closed). The TTK bar has no target in preview, so `render` shows a **Ragnaros**
  stand-in (`Interface\ICONS\INV_Hammer_Unique_Sulfuras`) while previewing, the live target portrait
  otherwise. `scenario_spec` re-keyed to the real ids.
- **Acceptance:** with Show icons on, the preview shows Ragnaros + Death Wish + Earthstrike icons; live
  behaviour unchanged; per-ability colours now also affect preview bars; `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — preview icons; per-ability colours visible in preview (audit #6).
- **Constitution check:** Principles OK — data change (scenario ids) + display edge; specs updated.

**Phase 1** 1. [ ] scenario.lua real ids (+ spec); display.lua preview TTK stand-in.
**Phase 2** 1. [ ] gate green; bump 0.9.39; rebuild `.release`. PR (after #60). 2. [ ] **In-game (human):** preview icons show.
