---
wo: WO-021-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-004-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - projects/badger-ttk/BadgerTTK.toc
---

# WO-021-IJ — config left-nav: space between node icon and name + vertical alignment

- **Created / Updated:** 2026-07-25
- **Objective:** in the config window's **left-nav node list**, put **a little space between each node's
  icon and its name**, and **vertically centre the name on the icon**. Today they're cramped (~2px gap) and
  the text sits ~2px above the icon.
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
- **Scope note — shared lib:** `BadgerConfigUI-1.0` is the **shared** config-window lib, so
  `badger-arena`'s config gets the same nicer spacing (consistent Badger look — desirable). The lib's
  `MINOR` bumps `1 → 2`.
- **Acceptance criteria:**
  - In-game, each left-nav node shows a **small gap** between icon and name, and the name is **vertically
    centred** on the icon.
  - Nodes still select / expand / collapse normally; no Lua errors; the tweak silently no-ops if the AceGUI
    tree internals aren't as expected.
  - `pnpm validate` green (the change is in the untestable Ace/frame edge of `BadgerConfigUI`, like the rest
    of that file; the lib's pure siblings are unaffected).
- **Out of scope:** any other tree styling (fonts, row height, highlight); the right-hand options pane;
  per-addon spacing config (a single sensible `GAP` constant for now).
- **Behavior delta:** MODIFIED (in-game) — config left-nav icons/names are spaced and vertically aligned
  (all Badger addons).

**Phase 1 — BadgerConfigUI tweak**
1. [ ] `BadgerConfigUI-1.0.lua`: add a guarded `reanchorTreeButtons(tree)` + a one-time
       `hooksecurefunc(tree, "RefreshTree", …)`; call both from `lib:Open` after locating the `TreeGroup`
       child of `OpenFrames[appName]`. Bump `MINOR → 2`.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green. Bump badger-ttk `.toc` `## Version` → **0.9.4**, rebuild `.release`
       (re-embedding the updated `BadgerConfigUI`), load graph resolves.
2. [ ] **In-game (human, required):** node icons have a gap before the name and the name is vertically
       centred; nodes still work.

- **Verification:** the acceptance criteria; `pnpm validate` green; a rebuilt package; PR for human merge;
  in-game re-test.
- **Constitution check:** Principles OK — the fix lives in our own shared lib (not the vendored AceGUI),
  guarded/defensive, frame-edge (no spec, matching the file's role); `hooksecurefunc` is an allowed global;
  no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
