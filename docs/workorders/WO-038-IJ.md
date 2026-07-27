---
wo: WO-038-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
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
1. [ ] `config.lua`: title (#10), node orders (#11), Preview rename (#12), Profiles icon (#8), header
       play/pause (#14), Skin layout (#18) + "Utility size" (#19) + Delete button (#21).
       `skin.lua`: built-in → "Default" + `Skin.deleteSkin`. `core.lua`: default `skin = "Default"`.
       BadgerConfigUI: fixed Blizzard-stub title (keep "Badger TTK"). `.toc` `## Title`.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump `.toc` `## Version`; rebuild `.release` (re-embed the lib if touched).
2. [ ] **In-game (human, required):** titles, tree order (Raids above Abilities), Preview name, Profiles
       icon, header Play/Pause, skin delete/rename, skin-node layout.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — config glue + a pure `Skin.deleteSkin` (spec-tested); no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
