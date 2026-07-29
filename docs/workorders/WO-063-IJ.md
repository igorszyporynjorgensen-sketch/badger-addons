---
wo: WO-063-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/raids/table.lua
---

# WO-063-IJ — add Naxxramas to the raid registry

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** the Raids show-gating list is missing the final Classic-Era raid,
  **Naxxramas** — add it. (A normal 0.9.x release, not the TBC flavor.)
- **Design notes:** pure DATA addition to `ns.RaidTable` (the config Raids node builds from it, so no
  config change). Insert **Naxxramas** after Temple of Ahn'Qiraj (release order), before World Bosses,
  with its 15 encounters at in-game granularity (Four Horsemen as one; Sapphiron + Kel'Thuzad separate).
  Globally-unique encounter ids (spec-enforced). Update the order assertion in `table_spec`.
- **Acceptance:** Naxxramas + its bosses appear in the Raids node; `table_spec` order/uniqueness pass;
  `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — Naxxramas in the Raids gating list.
- **Constitution check:** Principles OK — pure data + spec; no API/`_G` change.

**Phase 1** 1. [ ] table.lua Naxxramas block; table_spec order.
**Phase 2** 1. [ ] gate green; bump 0.9.44; rebuild `.release`. PR. 2. [ ] **In-game (human):** Naxxramas lists.
