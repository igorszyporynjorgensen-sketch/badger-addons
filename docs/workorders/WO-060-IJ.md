---
wo: WO-060-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/63
decision: ~
depends_on: []
related:
  - projects/badger-ttk/src/skin/skin.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-060-IJ — export a skin as a paste-ready Lua snippet

- **Created / Updated:** 2026-07-28
- **Objective — from the human:** export a skin as copy-paste text (a window/box with the skin in it to
  mark and copy) — the human will craft skins and hand them over to be baked in as built-ins.
- **Design notes:** pure `Skin.serialize(name)` (spec'd) emits a deterministic Lua-table literal in the
  EXACT format `RegisterSkin` accepts (media → colors → display, fixed key order) — so a pasted export
  bakes in verbatim. Config Skin node gains an **Export** section: a read-only `multiline` input whose
  `get` returns the serialization of the picker-selected skin (select-all + copy in-game; `set` no-op).
- **Acceptance:** the box shows the selected skin as a valid Lua literal; round-trips through
  `RegisterSkin`; `pnpm validate` green.
- **Behavior delta:** ADDED (in-game) — Export box in the Skin node.
- **Constitution check:** Principles OK — pure serializer + spec; config is the unspec'd edge.

**Phase 1** 1. [x] skin.lua serialize + spec; config.lua Export box.
**Phase 2** 1. [ ] gate green; bump 0.9.41; rebuild `.release`. PR (merge after #62). 2. [ ] **In-game (human):** copy an export.
