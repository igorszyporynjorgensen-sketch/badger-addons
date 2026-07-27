---
wo: WO-044-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/48
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on: []
related:
  - projects/badger-ttk/BadgerTTK.toc
  - assets/images/badger-master.png
  - assets/images/badger-ttk.png
---

# WO-044-IJ — ship the icons: addon icon (badger-ttk) + brand texture (master)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** attach the **badger-ttk** icon as the addon's icon and ship the **master**
  (publisher/series brand) texture for the config header (used in WO-045). Source PNGs live in
  `assets/images/`.
- **Key constraint:** WoW can't load PNG — textures/`## IconTexture` need **uncompressed TGA** (or BLP),
  power-of-two. The source PNGs are converted to **256×256 uncompressed TGA** (see [[png-to-wow-tga]]).
- **Design notes:**
  - Ship `projects/badger-ttk/Media/badger-ttk-icon.tga` + `badger-master.tga` (converted from the PNGs).
  - `BadgerTTK.toc`: `## IconTexture: Interface\AddOns\BadgerTTK\Media\badger-ttk-icon` (the addon-list icon).
  - Add `tools/png-to-tga.py` (sips-resize + a dependency-free PNG→uncompressed-TGA converter) so the
    conversion is reproducible; commit the source PNGs to `assets/images/`.
  - The manual `.release` rebuild must include the `Media/` folder (the packager already ships the whole
    addon tree).
  - The **master** texture is shipped now but wired into the header in **WO-045** (the two-column header).
- **Acceptance criteria:**
  - `projects/badger-ttk/Media/` ships both TGAs; `## IconTexture` points at the ttk icon.
  - `.release/BadgerTTK/Media/` contains the TGAs; the load graph still resolves; `pnpm validate` green.
- **Out of scope:** the header two-column layout + showing the master image (WO-045).
- **Behavior delta:** ADDED (in-game) — the addon shows the badger-ttk icon in the AddOns list.
- **Risk:** TGA rendering is unverifiable off-client — if the icon is missing/upside-down in the AddOns
  list, it's a path/extension or descriptor-flip tweak (see [[png-to-wow-tga]]).

**Phase 1 — Ship + wire**
1. [x] `Media/*.tga`; `## IconTexture`; `tools/png-to-tga.py`; commit source PNGs; build includes `Media/`.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (86). Bumped 0.9.26; Media in .release. `.toc` `## Version`; rebuild `.release` (with `Media/`).
2. [ ] **In-game (human, required):** the badger-ttk icon shows in the AddOns list.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — assets + `.toc` + a build helper; no Lua behaviour/`_G` change.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
