---
wo: WO-029-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/32
decision: D-008-IJ      # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-027-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/skin/skin.lua
  - libs/BadgerConfigUI-1.0/options-tree.lua
---

# WO-029-IJ — config improvements: Warrior node rework · save-as-skin · header/body spacing

- **Created / Updated:** 2026-07-27
- **Objective — three config improvements from the human:**
  1. **Warrior node rework** — in Abilities → Warrior: a **separator** between each ability; **descriptive
     text** under each (the in-game spell/item tooltip, where available); and make enable/disable **and**
     offset editable **regardless of whether the ability is currently available**.
  2. **Save current config as a skin** — an **input field + "Save" button** next to the skin selector that
     snapshots the current **Skin + Display** options into a new named skin (so a skin is a reusable preset
     of exactly those combinations).
  3. **Header/body spacing** — more **bottom margin** between a page's header (banner title / subtitle /
     description) and its options, to visually separate "header" from "body" across all config pages.
- **Design notes:**
  - **Warrior node (1):** per ability, emit a `header`/`description` line (name + the tooltip text from
    `GetSpellDescription(id)` for spells / an item tooltip scan for items — best-effort, blank if none) and a
    `type="description"` separator between entries; **drop** `disabled = unavailable` on the toggle + offset
    (still *dim the availability* via the label/icon, but keep them editable). Availability only affects
    whether a live bar shows, not whether you can configure it.
  - **Save-as-skin (2):** an input (skin name) + execute button in the Skin node; on click, `RegisterSkin`
    a new skin built from the current profile's media (`statusbar/font/border`), colours, and the Display
    settings. Extend the skin format + `Skin.apply` to also carry the display fields, and persist
    user-made skins to `db.global` so they survive a reload (built-ins stay code-defined).
  - **Spacing (3):** in `BadgerConfigUI` (shared) the injected banner/subtitle get more bottom margin — a
    tall spacer `description` after the subtitle (and before the first option) so every page reads as
    header-then-body. `MINOR` 3 → 4; `options-tree_spec` updated.
- **Acceptance criteria:**
  - Each warrior ability shows a separator + a description line; the toggle and offset are **editable even
    when the ability isn't currently usable**.
  - Typing a name + pressing **Save** creates a new skin (current Skin + Display captured) that appears in
    the skin picker and re-applies on selection; it survives `/reload`.
  - Config pages have clear **spacing** between the header block and the options.
  - `pnpm validate` green — the skin capture/apply + options-tree spacing are spec-tested; config copy edits
    don't break existing specs.
- **Out of scope:** deleting/renaming user skins (add later); per-class ability tables beyond warrior;
  restructuring beyond these items.
- **Behavior delta:** MODIFIED (in-game) — Warrior node has separators + descriptions + always-editable
  entries; a Save-as-skin control; more header/body spacing on every page.

**Phase 1 — Warrior node**
1. [x] `config.lua` `buildAbilities`: per-entry description (`GetSpellDescription`, else a composed hint
       from the table data) + a full-width rule between entries; removed the availability `disabled` gate on
       the toggle + offset — availability now only DIMS the label (greyed + "(unavailable)").

**Phase 2 — Save-as-skin**
1. [x] `skin.lua`: extended the skin format + `apply` to carry optional font-size + full Display blocks
       (apply writes only what a skin carries); added pure `Skin.saveCurrent(profile, name)` (snapshot +
       register + return). `core.lua`: `db.global.skins` default + re-register on `OnInitialize`.
       `config.lua` Skin node: a name input + "Save current as skin" button persisting to `db.global`.

**Phase 3 — Header/body spacing (BadgerConfigUI)**
1. [x] `options-tree.lua`: `spacerArg` injected by `normalize` between the header block and the options on
       every page; `MINOR` 3 → 4; `options-tree_spec` updated.

**Phase 4 — Verify**
1. [x] `pnpm validate` green (84/20/9/4 successes, 0 failures; luacheck 0/0). `.toc` `## Version` → **0.9.12**;
       `.release` rebuilt with the re-embedded BadgerConfigUI-1.0 (MINOR 4); source parity + load graph verified.
2. [ ] **In-game (human, required):** Warrior separators/descriptions/always-editable; Save-as-skin works +
       persists across `/reload`; clearer header/body spacing.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — skin capture is pure/spec-tested; options-tree spacing is
  pure/spec-tested; per-entry tooltip reads are edge; shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** D-008-IJ — a "skin" is a saved preset of Skin + full Display config (incl.
  position); user skins persist in `db.global`, built-ins stay code-defined.
  _Superseded on position/lock by WO-031-IJ / D-010-IJ — skins no longer capture frame position or lock._
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/32 (merged; main green)
- **Outcome:** Branch `feature/WO-029-IJ-config-improvements`, PR #32. Warrior node — rule between entries,
  a description under each (spell tooltip / composed data), toggle+offset always editable (availability only
  dims the label). Save-as-skin — skin format carries optional font-size + full Display blocks; pure
  `Skin.saveCurrent`; name input + Save button persisting to `db.global.skins` (re-registered on init).
  Header/body spacer in BadgerConfigUI (MINOR 4). `.toc` → 0.9.12; gate green; `.release` rebuilt + verified.
  Awaiting human merge + in-game re-test.
