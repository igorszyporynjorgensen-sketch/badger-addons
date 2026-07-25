---
wo: WO-021-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/24
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-004-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/BadgerTTK.toc
---

# WO-021-IJ — UI polish: config left-nav icon/name spacing + utility-bar text right-align

- **Created / Updated:** 2026-07-25
- **Objective:** two small UI-polish tweaks:
  1. **Config left-nav** — put **a little space between each node's icon and its name**, and **vertically
     centre the name on the icon** (today ~2px gap, text ~2px above the icon).
  2. **Utility bars** — **right-align the text** on each utility bar (today it's centred), so names align
     at the bars' shared right (death) edge.
- **Root cause:** the spacing/alignment is hard-coded in the **vendored** AceGUI `AceGUIContainer-TreeGroup`
  widget's `UpdateButton` — icon at `LEFT, 8·level, (level==1 and 0 or 1)`, text at `LEFT, (icon and 16)+…,
  2`. We **must not edit the vendored lib** (it's re-fetched from `.pkgmeta` every build).
- **Approach (in our shared `BadgerConfigUI-1.0` lib — no vendored edits):** after `AceConfigDialog:Open`,
  the tree is a child of the root frame (`OpenFrames[appName]`). `BadgerConfigUI` finds that `TreeGroup`
  child and **re-anchors each line button's text**: `text:SetPoint("LEFT", button.icon, "RIGHT", GAP, 0)` —
  which both adds the gap **and** vertically centres the text on the icon (LEFT↔RIGHT anchor at y-offset 0).
  It's made durable with a **guarded `hooksecurefunc` on the tree's `RefreshTree`** (re-applied after every
  expand/collapse/select), and fully **defensive**: it checks the `buttons` / `icon` / `text` fields exist
  and no-ops if the AceGUI internals ever differ. Only buttons that actually have an icon are touched.
- **Approach (2 — utility-bar text):** in `display.lua` `acquireBar`, anchor each utility bar's text to the
  bar's **RIGHT** (`SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)` + `SetJustifyH("RIGHT")`) instead of
  `CENTER`. One-time setup per bar (the anchor doesn't change per render); the text then right-aligns at the
  death edge.
- **Scope note — shared lib:** `BadgerConfigUI-1.0` is the **shared** config-window lib, so the left-nav fix
  also improves `badger-arena`'s config (consistent Badger look — desirable). The lib's `MINOR` bumps
  `1 → 2`. The utility-bar change is `badger-ttk`-only.
- **Acceptance criteria:**
  - In-game, each left-nav node shows a **small gap** between icon and name, and the name is **vertically
    centred** on the icon.
  - Utility bar text is **right-aligned** (at the bars' right/death edge).
  - Nodes still select / expand / collapse normally; no Lua errors; the tree tweak silently no-ops if the
    AceGUI internals aren't as expected.
  - `pnpm validate` green (both changes are in the untestable frame edge — `BadgerConfigUI` glue and the
    display; no pure logic touched).
- **Out of scope:** other tree styling (fonts, row height, highlight); the right-hand options pane; per-addon
  spacing config (a single sensible `GAP` constant for now).
- **Behavior delta:** MODIFIED (in-game) — config left-nav icons/names are spaced + vertically aligned (all
  Badger addons); utility-bar text is right-aligned (badger-ttk).

**Phase 1 — Config left-nav (BadgerConfigUI)**
1. [x] `BadgerConfigUI-1.0.lua`: add a guarded `reanchorTreeButtons(tree)` + a one-time
       `hooksecurefunc(tree, "RefreshTree", …)`; call both from `lib:Open` after locating the `TreeGroup`
       child of `OpenFrames[appName]`. Bump `MINOR → 2`.

**Phase 2 — Utility-bar text (display)**
1. [x] `display.lua` `acquireBar`: anchor the bar text `RIGHT` (`SetJustifyH("RIGHT")`) instead of `CENTER`.

**Phase 3 — Verify**
1. [x] `pnpm validate` green. Bump badger-ttk `.toc` `## Version` → **0.9.4**, rebuild `.release`
       (re-embedding the updated `BadgerConfigUI`), load graph resolves.
2. [ ] **In-game (human, required):** node icons have a gap before the name and the name is vertically
       centred; nodes still work.

- **Verification:** the acceptance criteria; `pnpm validate` green; a rebuilt package; PR for human merge;
  in-game re-test.
- **Constitution check:** Principles OK — the fix lives in our own shared lib (not the vendored AceGUI),
  guarded/defensive, frame-edge (no spec, matching the file's role); `hooksecurefunc` is an allowed global;
  no `_G` leaks.
- **Decisions produced:** —
- **MR:** [PR #24](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/24)
- **Outcome:** Implemented both parts; `pnpm validate` green (61 badger-ttk + 16 BadgerConfigUI specs;
  luacheck 0/0). BadgerConfigUI `MINOR` 1→2. `.toc` → v0.9.4. **PR #24 merged**; rebuilt `.release/BadgerTTK`
  at v0.9.4 (load graph resolves 72/0, the updated BadgerConfigUI is embedded byte-identical incl.
  `polishTree`, source parity clean). **In progress** pending the human's in-game re-test.
