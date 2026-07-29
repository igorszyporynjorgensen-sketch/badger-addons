---
wo: WO-062-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/65
decision: ~
depends_on:
  - docs/workorders/WO-060-IJ.md
related:
  - projects/badger-ttk/src/skin/skin.lua
  - projects/badger-ttk/src/config/config.lua
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
---

# WO-062-IJ — skin Export/Import windows + a named skin format + the built-in "Modern" skin

- **Created / Updated:** 2026-07-29
- **Objective — from the human (last change before 1.0.0 sign-off; stays 0.9.x pending testers):**
  - Replace the always-open export box with an **Export button** (next to Delete) that opens a **window**
    with the paste-ready snippet on top of the config.
  - An **Import button** next to Export (same row) opens a window to paste a skin in.
  - Skins therefore carry a **`name`** field so an import lands under its own name in the dropdown.
  - Bake in a built-in skin named **"Modern"** (table supplied by the human).
- **Design notes:**
  - **BadgerConfigUI:** new `lib:TextPopup(opts)` — a standalone AceGUI Frame + MultiLineEditBox: a copy
    box (text pre-selected) or, with `buttonText`+`onAccept`, a paste box whose button calls
    `onAccept(text)` and closes only on a truthy return (a failed import keeps the window open).
    `MINOR` 10 → 11 (untestable frame edge).
  - **skin.lua:** `serialize` now prepends `name = "<name>"`. New pure `Skin.deserialize(text)` →
    (skin | nil, err): sandboxed `(loadstring or load)` (empty env via `setfenv` on 5.1), requires a
    string `name`. Generalize built-ins: `RegisterBuiltin`/`isBuiltin` (Default **and** Modern);
    `deleteSkin`/`saveCurrent` refuse any built-in. Register the supplied **Modern** skin.
  - **config.lua Skin node:** picker `relWidth` 0.74→0.46; Delete 0.25→0.18; add **Export** (0.18) +
    **Import** (0.18) executes on the same row (picker · Delete · Export · Import). Export → `TextPopup`
    copy box of `serialize(selected)`; Import → `TextPopup` paste box → `deserialize` → register + persist
    to `db.global.skins` + select + `NotifyChange`, with `:Print` feedback. Remove the old export input.
- **Acceptance:** Export opens a copy window; Import opens a paste window and adds the skin under its name;
  Modern appears in the picker and isn't deletable; a serialize→deserialize round-trip re-registers;
  `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — Export/Import windows, the Modern skin.
- **Constitution check:** Principles OK — pure serialize/deserialize + built-in table (spec'd); the popup
  is the shared-lib frame edge (`MINOR` bump); no `_G` leaks.

**Phase 1** 1. [x] BadgerConfigUI TextPopup + MINOR 11; skin.lua name/deserialize/builtins/Modern (+ specs);
   config.lua Export/Import buttons.
**Phase 2** 1. [ ] gate green; bump 0.9.43; rebuild `.release` (re-embed lib). PR.
2. [ ] **In-game (human):** Export copies; Import adds a skin; Modern selectable.
