---
wo: WO-045-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/49
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-044-IJ.md
related:
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - libs/BadgerConfigUI-1.0/options-tree.lua
  - projects/badger-ttk/src/config/config.lua
---

# WO-045-IJ — config header: two-column brand band (image left, title/subtitle right)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** the global header becomes **two side-by-side containers**: (1) the
  **image** (`badger-master`) on the LEFT, taking only the width it needs **plus a right margin**; and
  (2) the **title + subtitle** stacked and **left-aligned** on the RIGHT, taking the remaining space.
  Human pre-approved this batch ("truck through everything and only wait … to merge for you"), so this
  WO lands `Accepted`.
- **Research:** a 3-lens read-only workflow (AceConfig-native / frame-surgery / wiring). Verdicts:
  - Native AceConfig **can't** do a real two-column header (a `description` image binds to one label with
    a ~4px gap and stacks when narrow) — a custom band is justified.
  - The header args are root-level children of the AceGUI Frame's `content`, laid out by Flow **above**
    the tree. Both header and tree share `content`, so insetting `content` shifts everything (dead end
    for the tree, but exactly what we want for pushing native rows *below* a band).
  - `content` is anchored `TOPLEFT(17,-27)/BOTTOMRIGHT(-17,40)`; resize only calls `SetWidth/SetHeight`,
    never re-points `content` — so a one-time `content:SetPoint("TOPLEFT", 17, -27-BAND_H)` **persists**
    across re-Open (`ReleaseChildren` doesn't touch `content`) and resize.
  - A **raw** Texture/FontString on `frame.frame` is **not** an AceGUI child, so `ReleaseChildren`
    (fired on every value-change re-Open) leaves it alone — build it **once**, guarded.
- **Design — robust, self-contained band + native content inset:**
  - **`options-tree.lua` `normalize`:** when `header.image` is set (`hasBand`), **omit** the
    `badgerHeaderTitle`/`badgerHeaderSub` descriptions (the raw band owns them); **keep** the controls
    (`badgerHeaderCtrl<i>`) and the spacer. No image → **unchanged** (badger-arena keeps its text banner).
  - **`BadgerConfigUI-1.0.lua`:** `lib:Register` stores `app.header`. New defensive `polishHeader(frame,
    app)` (beside `polishTree`/`polishStatusBar`, called from `lib:Open`), guarded once per frame:
    - build a raw band frame on `frame.frame`, `TOPLEFT(17,-27)/TOPRIGHT(-17,-27)`, height `BAND_H`;
    - LEFT: a Texture `SetTexture(app.header.image)` sized `imageWidth×imageHeight`, inset a pad from the
      band's top-left, with a **right margin** (`imageMargin`);
    - RIGHT: a large **brand-gold** (`f5c542`) title FontString over a medium subtitle FontString, both
      `JustifyH LEFT`, anchored to the texture's `TOPRIGHT` + the margin;
    - inset the native content **once**: `frame.content:SetPoint("TOPLEFT", 17, -27-BAND_H)` so the
      control row + tree sit **below** the band. `MINOR` 8 → 9.
  - **`config.lua`:** add to `header`: `image = "Interface\\AddOns\\BadgerTTK\\Media\\badger-master"`,
    `imageWidth/imageHeight` (72), `imageMargin` (14). Controls unchanged (stay native).
  - **Deviation (documented):** the two **controls** (Show-preview + Play/Pause) stay **native** and flow
    on their own full-width row **directly below** the brand band — not nested in the right column beside
    the image. Keeping them native preserves their automatic sync with the Preview node (every
    value-change rebuilds them from `get`); re-anchoring recreated widgets into the band each refresh is
    the fragile path the research flagged. If the human wants them beside the image after seeing it
    in-game, that's a follow-up.
- **Acceptance criteria:**
  - badger-ttk header shows the master image on the LEFT (with a right margin) and the title/subtitle
    stacked, left-aligned, on the RIGHT; the control row + tree sit below, none overlapping.
  - The band survives a header-control click (re-Open) and a window resize (the inset re-holds).
  - badger-arena's header is unchanged (no image → text banner as before).
  - `pnpm validate` green; `options-tree_spec` covers the `hasBand` branch (title/sub omitted, controls
    kept).
- **Out of scope:** nesting the controls into the right column (possible follow-up); any new artwork.
- **Behavior delta:** MODIFIED (in-game) — the config header becomes a two-column brand band.
- **Risk:** frame layout is unverifiable off-client — needs a live `/reload`, exercising a header-control
  click (re-Open) and a resize. `LayoutFinished`/pooling notes captured in research if the inset drifts.

**Phase 1 — Band + inset**
1. [x] `options-tree.lua` `hasBand` branch (+ spec); `BadgerConfigUI-1.0.lua` `polishHeader` + `MINOR` 9;
   `config.lua` header image fields.

**Phase 2 — Verify**
1. [x] `pnpm validate` green; bumped 0.9.27; lib re-embedded (MINOR 9). badger-ttk `.toc` `## Version` (0.9.27); rebuild `.release` (re-embed
   the lib). PR for human merge.
2. [ ] **In-game (human, required):** two-column header renders; band holds across control-click + resize;
   badger-arena unchanged.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — pure `normalize` change stays spec'd; the frame band is the
  untestable Ace edge (no spec, like the rest of the lib); shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
