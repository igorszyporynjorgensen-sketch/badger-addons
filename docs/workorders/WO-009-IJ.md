---
wo: WO-009-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-008-IJ.md
related:
  - docs/decisions.md
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
---

# WO-009-IJ — `badger-ttk` config skeleton — the full options tree (no behavior yet)

- **Created / Updated:** 2026-07-25
- **Objective:** build `badger-ttk`'s **complete, navigable options window** — the agreed left-nav tree,
  AceDB profile/global wiring with **real-typed defaults**, icons, and the appearance/settings nodes —
  so every setting exists, reads/writes `db.profile`, and persists across `/reload`, **while driving no
  in-game behavior yet**. Child #2 of the WO-007 epic; realises **config-before-functionality**: each
  functionality WO later *reads* these settings + fills its own data-driven node. Replaces the WO-008
  skeleton (General + Profiles) with the real tree.
- **Node ownership (the boundary this WO sets):** WO-009 builds the **framework + the settings/appearance
  nodes** whose options are static (no feature data needed): **General · Behavior · Skin · Display ·
  Estimator · Profiles**. The **data-driven** nodes — **Raids** (needs the encounter registry),
  **Abilities** (needs the master table + character scan), **Simulation** (needs the sim driver) — are
  created as **placeholder groups** here and *populated by their feature WOs*. *(Confirm this split on
  acceptance; the alternative is folding every node here.)*
- **Acceptance criteria:**
  - **Tree** registered via `LibStub("BadgerConfigUI-1.0"):Register(...)` with `childGroups='tree'`;
    left-nav order **General · Behavior · Raids · Skin · Display · Estimator · Abilities · Simulation ·
    Profiles**. Raids/Abilities/Simulation render as placeholders (a `description` naming their WO).
  - **AceDB**: a central **real-typed defaults** table (booleans/numbers, never `"true"`/`"180"`) under
    `db.profile`, plus the reserved `db.global` (from WO-008); every option below is get/set-bound to
    `db.profile.*` (no raw SV).
  - **Icons**: spell/item/class icons via **label texture-escapes** (`|T<tex>:16|t Name`,
    `GetSpellTexture`/`GetItemIcon`/class atlas) — no `BadgerConfigUI` change required. *(A richer
    custom-widget treatment may extend `BadgerConfigUI-1.0` later; not now.)* Raid/boss icons use the
    generic **fallback** (curated assets deferred — human-procured).
  - **General** — `enable` master toggle + a status/help `description`.
  - **Behavior** — `inCombatOnly` · `hideOnTargetDead` · `requireHostile` · `minTTK` · `showAnyTarget` ·
    `minConfidenceToShow` (persist only; gating logic is the show-gating WO).
  - **Display** — *Layout* (anchor · lock+drag+`posX`/`posY`+reset · scale · `growthDirection` (UP) ·
    bar width/height/spacing · opacity · strata · `maxBars`) + *Readout* (show names/timers/icons ·
    `timeFormat` (m:ss) · `showTrendBand` · `showConfidence`).
  - **Skin** — the **skin picker** (a `select` populated from the skin registry — reads it; the registry
    + `RegisterSkin` API + built-in "Badger" skin + rendering are the display WO) · one **font family** +
    **two sizes** (main TTK · other bars) · texture · border · the **six state colours**.
  - **Estimator** — **Reactivity↔Stability** slider (maps to λ) · `leadTime` · `executeThreshold` ·
    `executeModifier` · `minConfidenceToShow` reference. (The math is the engine WO.)
  - **Profiles** — `AceDBOptions-3.0:GetOptionsTable(db)` as a child node (order −1).
  - **Defaults** match WO-007: growth UP · `m:ss` · anchor RIGHT · locked · `minTTK` 10 · `leadTime` 1.5 ·
    execute 0.20 / 1.2 · opacity+scale 1.0 · Badger skin · the six state colours.
  - **Gate:** `pnpm validate` green; any **pure config helper** (e.g. a defaults/normalize builder) is
    kept API-light and carries a colocated `_spec`; the WO-008 smoke spec still passes.
  - **In-game (human, deferred):** `/reload` → the window shows all nodes; icons render; changing a
    setting and `/reload`-ing **persists** it.
- **Out of scope:** any in-game behavior (feature WOs read these settings later); the **Raids /
  Abilities / Simulation** node *contents* (their feature WOs); the **skin engine + rendering** and the
  `RegisterSkin` registry/built-ins (display WO #5); **skin paste-import** and **ability pack
  import/export** (v1.1); the **History** node (post-v1); extending `BadgerConfigUI-1.0` with
  custom-widget icons (later, only if the label-escape look is insufficient).
- **Behavior delta:** MODIFIED (in-game, editor-only) — the config window gains the full node tree,
  icons, and a skin picker; settings persist but do **not** yet change gameplay.

**Phase 1 — Framework**
1. [ ] Central real-typed `DEFAULTS.profile` table + the tree registration via `BadgerConfigUI`; an icon
       helper (label texture-escape). Replace the WO-008 skeleton options.

**Phase 2 — Settings/appearance nodes**
1. [ ] Build **General · Behavior · Skin · Display · Estimator** option tables, each option get/set-bound
       to `db.profile` with the WO-007 defaults; icons on entries where they apply.

**Phase 3 — Profiles + placeholders**
1. [ ] Add the `AceDBOptions` **Profiles** node; add **Raids / Abilities / Simulation** placeholder
       groups (a `description` naming their feature WO).

**Phase 4 — Verify**
1. [ ] `pnpm validate` green; spec any pure config helper. In-game `/reload` persistence check deferred
       to the human.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; the
  in-game persistence/appearance check is the human's.
- **Constitution check:** Principles OK — additive config; the shared `BadgerConfigUI-1.0` standard (no
  ad-hoc AceConfig); AceDB profiles; house style (one module per file, `ns`, no `_G` leaks); API-light
  config with pure helpers spec'd; icons via stock label-escapes so **no shared-lib change** (and no
  badger-arena impact) is forced now.
- **Decisions produced:** — (none expected — implements WO-007's accepted config design; a decision
  only if the node-ownership split or an icon-approach change warrants recording).
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
