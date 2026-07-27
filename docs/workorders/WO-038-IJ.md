---
wo: WO-038-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/41
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-037-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/skin/skin.lua
  - projects/badger-ttk/BadgerTTK.toc
---

# WO-038-IJ — config structure & labels (pre-1.0 hardening, batch 1)

- **Created / Updated:** 2026-07-27
- **Objective — low-risk config structure/label changes from the pre-1.0 batch:**
  - **#10 Title** → "Badger Time To Kill (TTK)" for the window title + the header title + the addon `.toc`
    `## Title`. Keep the internal appName (`BadgerTTK`) and the **Blizzard-panel stub name** unchanged.
  - **#11** Move the **Raids** node to just above **Abilities** in the tree.
  - **#12** Rename the **Simulation** node → **Preview**.
  - **#8** Give the **Profiles** node an icon.
  - **#14** Add a **Play/Pause button in the header**, next to the Show-preview toggle (same `simPlaying`
    binding as the Preview node's, so they stay in sync).
  - **#19** Skin node: rename **"Other bars size" → "Utility size"**.
  - **#18** Skin node: the skin **picker on its own line**; the New-skin name / Save / Delete on a line below.
  - **#21** Skin node: a **Delete** button that removes the selected user skin (never the built-in). Rename
    the built-in skin **"Badger" → "Default"** (and the default profile's `skin`).
- **Design notes:**
  - Title (#10): `opts.title` + `opts.header.title` → "Badger Time To Kill (TTK)"; `.toc` `## Title`. The
    Blizzard stub currently uses `app.title` — pass a separate fixed stub title ("Badger TTK") so the
    Blizzard entry name is unchanged (small BadgerConfigUI `blizStub`/`Register` tweak, no MINOR needed for
    a new optional opt — but bump `MINOR` if the signature changes). Keep it back-compatible.
  - Header play/pause (#14): add a second entry to `opts.header.controls` — an `execute` whose name flips
    Play/Pause, `disabled` unless `simStatic`, toggling `simPlaying` + `Display.playSim`.
  - Delete/rename skins (#21): `skin.lua` register the built-in as **"Default"**; `Skin.deleteSkin(name)`
    (pure — refuse the built-in, drop from the registry); `config.lua` Delete button removes from
    `db.global.skins` + registry and falls back to "Default"; `core.lua` default `skin = "Default"`.
  - Layout (#18): give the skin `select` and the save/delete row explicit `width`s so they sit on their own
    lines.
- **Acceptance criteria:**
  - Window + header + addon list read "Badger Time To Kill (TTK)"; the Blizzard options entry still reads
    "Badger TTK"; `/bttk` etc. unchanged.
  - Tree order: General, Behavior, Skin, Display, Estimator, **Raids, Abilities**, Preview, Profiles (Raids
    directly above Abilities); the sim node is titled **Preview**; Profiles has an icon.
  - The header shows Show preview + a Play/Pause button that mirrors the Preview node's.
  - Skin node: picker on its own line; a New-skin/Save/**Delete** row below; Delete removes a user skin (not
    the built-in **Default**); "Utility size" label.
  - `pnpm validate` green — `skin_spec` covers `deleteSkin` + the renamed built-in.
- **Out of scope:** config copy (WO-039); colours/fonts (WO-040); geometry/opacity (WO-041); per-ability
  colour (WO-042); status-bar alignment (WO-043).
- **Behavior delta:** MODIFIED (in-game) — titles, tree order, node names, header play/pause, skin
  delete/rename, skin-node layout.

**Phase 1 — Structure & labels**
1. [x] `config.lua`: title via `options.name` + `header.title` (#10), Raids order 6.5 (#11), Preview rename
       (#12), Profiles icon (#8), header Play/Pause control (#14), Skin picker full-width + Save/Delete row
       (#18) + "Utility size" (#19) + Delete button (#21). `skin.lua`: built-in → "Default" (`Skin.BUILTIN`)
       + pure `Skin.deleteSkin`. `core.lua`: default `skin = "Default"` + `"Badger"→"Default"` migration.
       No lib change needed — the Blizzard stub keeps `opts.title` = "Badger TTK". `.toc` `## Title`.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (86/21/9/4 successes, 0 failures; luacheck 0/0). `.toc` `## Title` updated,
       `## Version` → **0.9.20**; `.release` rebuilt (lib MINOR 7 from the WO-037 stack); parity verified.
2. [ ] **In-game (human, required):** titles, tree order (Raids above Abilities), Preview name, Profiles
       icon, header Play/Pause, skin delete/rename, skin-node layout.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — config glue + a pure `Skin.deleteSkin` (spec-tested); no `_G` leaks.
- **Decisions produced:** —
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/41 (open; stacked on #40)
- **Outcome:** Branch `feature/WO-038-IJ-config-structure` (stacked on the WO-037 fix branch), PR #41. All 8
  items done (config.lua + skin.lua + core.lua + `.toc`); built-in skin "Badger"→"Default" with migration;
  pure `Skin.deleteSkin`. `.toc` Title updated + 0.9.20; gate green (86 successes); `.release` rebuilt.
  Merge #40 first, then #41. Awaiting human merge + in-game re-test.
