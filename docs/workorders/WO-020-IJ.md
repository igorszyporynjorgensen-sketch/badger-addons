---
wo: WO-020-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/23
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-013-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/BadgerTTK.toc
  - projects/badger-ttk/.pkgmeta
---

# WO-020-IJ — `badger-ttk` media pickers show visual previews (LSM30 dialog controls)

- **Created / Updated:** 2026-07-25
- **Objective:** the config's media dropdowns currently list media by **name** only. Make **all three** show
  a **visual preview** of each option — so picking a look is by eye, not by guessing a name:
  - **statusbar texture** → the texture drawn as a bar,
  - **font** → each name rendered in its own face,
  - **border ("frame")** → the border texture shown. **Confirmed possible** — the widget lib ships an
    `LSM30_Border` control, so frames get previews just like textures and fonts.
- **Approach:** embed the standard **`AceGUI-3.0-SharedMediaWidgets`** library, which registers AceConfig
  dialog controls that render LibSharedMedia previews, and point each media select at the matching control:
  - statusbar select → `dialogControl = "LSM30_Statusbar"`
  - font select → `dialogControl = "LSM30_Font"`
  - border select → `dialogControl = "LSM30_Border"`
  The options stay ordinary `select`s (same `values = LSM:HashTable(...)`, same get/set) — only the render
  widget changes, so there's **no logic change** and a graceful fallback (a plain dropdown) if the widget
  is ever missing.
- **Packaging:** a new `.pkgmeta` external + a `.toc` load line + the build fetch. The exact wowace external
  path is confirmed at build time (`svn ls`) before it's committed; the lib depends only on LibStub +
  AceGUI-3.0 + LibSharedMedia-3.0, all already embedded. Loads **after** AceGUI/AceConfig and **before**
  `src/config/config.lua`.
- **Acceptance criteria:**
  - In the config, the statusbar / font / border pickers render **per-entry previews** (texture/font/border),
    not just names; selecting still persists and applies as today.
  - `pnpm validate` green (config-only; no pure logic touched). The build embeds the new lib and the full
    `.toc` load graph still resolves.
  - **In-game (human, required):** the dropdowns show previews and still change the look.
- **Out of scope:** the shared `BadgerConfigUI` lib and `badger-arena` (this WO wires previews for
  `badger-ttk` only); a colour-swatch redesign; sound previews (add later if wanted).
- **Behavior delta:** MODIFIED (in-game) — media dropdowns render visual previews.

**Phase 1 — Embed the widget lib**
1. [x] Confirm the wowace external path (`svn ls`), add it to `.pkgmeta`
       (`Libs/AceGUI-3.0-SharedMediaWidgets: <trunk>`), and add the `.toc` load line after the Ace libs,
       before `src/config/config.lua`.

**Phase 2 — Point the media selects at the LSM30 controls**
1. [x] `config.lua`: add `dialogControl = "LSM30_Statusbar" | "LSM30_Font" | "LSM30_Border"` to the three
       media selects in the Skin node.

**Phase 3 — Verify**
1. [x] `pnpm validate` green. Bump `.toc` `## Version` → **0.9.3**, rebuild `.release` (embedding the new
       lib; verify the load graph resolves).
2. [x] **In-game (human, required):** (approved by the human) the pickers show previews and still apply.

- **Verification:** the acceptance criteria; `pnpm validate` green; a rebuilt package whose load graph
  resolves with the new lib; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — vendored lib via `.pkgmeta` (documented divergence, like the Ace
  externals); config-only wiring; no `_G` leaks; no pure logic touched.
- **Decisions produced:** —
- **MR:** [PR #23](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/23)
- **Outcome:** Implemented; `pnpm validate` green (61 badger-ttk specs; luacheck 0/0 — config-only). External
  path confirmed (`svn ls`): `trunk/AceGUI-3.0-SharedMediaWidgets` (widget.xml → prototypes + 5 widgets);
  control types `LSM30_Statusbar` / `LSM30_Font` / `LSM30_Border` verified in the widget sources. Trial
  build embedded the lib and the full `.toc`+XML load graph resolves (72 files, 0 missing). `.toc` → v0.9.3.
  **PR #23 merged**; rebuilt `.release/BadgerTTK` at v0.9.3 (svn-exported the widget lib; load graph resolves
  72/0, 3 LSM30 controls wired, source parity clean). **In-game approved by the human** (tested in the
  bundled v0.9.4 build) → **Done**.
