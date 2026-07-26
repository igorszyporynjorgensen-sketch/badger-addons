---
wo: WO-026-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-015-IJ.md
related:
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/core.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-026-IJ — Behavior toggle: show the utility bars outside a raid?

- **Created / Updated:** 2026-07-26
- **Objective:** add a config option (near **Show on any target**) — **"Show utility bars outside raids"** —
  controlling whether the utility cooldown bars appear when you're **not in a raid**. Outside a raid the
  utility bars (Earthstrike, Death Wish, …) are usually noise on a random mob; the **main TTK bar** should
  still show. When off, outside a raid only the TTK bar renders.
- **Design:**
  - New profile setting **`showUtilityOutsideRaid`** (Behavior node, next to `showAnyTarget`).
  - The live driver computes **`inRaid = select(2, IsInInstance()) == "raid"`**. When **not** `inRaid` and
    the toggle is **off**, it passes an **empty utility list** to the display → only the main TTK bar shows;
    otherwise it assembles the utility entries as today. (A one-line change in `update()`; the sim preview,
    which renders directly, is unaffected and still shows utilities.)
  - Default: **on** (current behavior preserved) — turn it off to declutter outside raids.
- **["outside a raid" scope — please confirm]** v1 treats "in a raid" as **in a raid instance**
  (`IsInInstance()`), which matches the world-mob / `showAnyTarget` case exactly. Caveat: **world bosses**
  (Azuregos, Kazzak, the dragons) are in the **open world**, so they'd count as "outside a raid" here — the
  utility bars would follow this toggle for them too, until the full **registry-based gating** (matching the
  target to the Raids table, incl. world bosses) lands as the deferred show-gating enforcement WO.
  `[NEEDS CLARIFICATION: is "raid instance" acceptable for v1, or must world bosses count as "in a raid" now?]`
- **Acceptance criteria:**
  - A Behavior toggle **"Show utility bars outside raids"** exists next to *Show on any target* and persists.
  - **In a raid instance**: utility bars show regardless of the toggle.
  - **Outside a raid** with the toggle **off**: only the main TTK bar shows (no utility bars); with it **on**:
    utility bars show as today.
  - `pnpm validate` green — the gating uses the pure `assembleEntries`/`gate` seam; the raid check is a thin
    edge read.
- **Out of scope:** the full registry-based show-gating enforcement (world-boss/encounter matching) — the
  deferred WO; hiding the main TTK bar (it always shows when gated in).
- **Behavior delta:** ADDED (in-game) — outside a raid, utility bars can be hidden via the new toggle.

**Phase 1 — Setting + gating**
1. [ ] `core.lua`: `showUtilityOutsideRaid = true` default. `driver.lua` `update()`: compute `inRaid`; when
       `not inRaid and not showUtilityOutsideRaid`, render with an empty utility list (TTK bar only).

**Phase 2 — Config**
1. [ ] `config.lua` Behavior node: **"Show utility bars outside raids"** toggle next to *Show on any target*.

**Phase 3 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version` (next patch), rebuild `.release`.
2. [ ] **In-game (human, required):** outside a raid, toggling it hides/shows the utility bars (TTK bar stays);
       in a raid instance the utility bars show regardless.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — the show/hide decision stays in the pure gate/assemble seam; the
  `IsInInstance` read is the edge; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
