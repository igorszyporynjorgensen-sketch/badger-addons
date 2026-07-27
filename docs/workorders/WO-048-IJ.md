---
wo: WO-048-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/51
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-044-IJ.md
related:
  - tools/png-to-tga.py
  - projects/badger-ttk/Media/badger-ttk-icon.tga
  - projects/badger-ttk/Media/badger-master.tga
---

# WO-048-IJ — fix: the addon/header icons don't show in-game (TGA must be bottom-origin)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** the badger-ttk AddOns-list icon and the header brand image do not
  render in the WoW Classic Era client.
- **Diagnosis:** the TGAs are valid uncompressed 32-bit BGRA with correct alpha (the AddOns-list icon is
  fully opaque, so invisibility is **not** transparency) — but the image descriptor is **`0x28`**, whose
  `0x20` bit marks the file **top-origin**. WoW's texture loader expects the **canonical bottom-origin**
  TGA; the top-origin file fails to load (both textures share this pipeline, so both are absent). The
  converter's own header comment already flagged this as the fix. See [[png-to-wow-tga]].
- **Design notes:**
  - `tools/png-to-tga.py` `write_tga`: emit descriptor **`0x08`** (32-bit, 8 alpha bits, **origin
    bottom-left**) and write pixel rows **bottom-to-top** (the PNG decodes top-to-bottom, so iterate
    rows in reverse). Update the module docstring (the fix is now applied, not pending).
  - Regenerate both `Media/*.tga` from the committed source PNGs in `assets/images/`.
  - No Lua change; no `BadgerConfigUI` change (the header band code is fine — it just had nothing valid
    to draw). Rebuild `.release` (Media only).
- **Acceptance criteria:**
  - Both TGAs re-encode with descriptor `0x08` (bottom-origin), still 256×256 uncompressed 32-bit,
    correct BGRA + alpha; `file(1)` no longer reports "top".
  - `pnpm validate` green (no Lua touched). `.release/BadgerTTK/Media/` updated.
- **Out of scope:** the header-band pool-leak teardown (audit #1 — separate WO); any layout/defaults.
- **Behavior delta:** FIXED (in-game) — the AddOns-list icon and the header brand image render.
- **Risk:** still unverifiable off-client. If bottom-origin renders **upside-down** (i.e. WoW wanted
  top-origin after all), revert to `0x28` + top-to-bottom; if still absent, the next hypothesis is BLP
  or a path/folder-name mismatch. Confirm with a `/reload`.

**Phase 1 — Convert**
1. [x] `png-to-tga.py` bottom-origin; regenerate both TGAs; verify descriptor `0x08` + `file(1)`.

**Phase 2 — Verify**
1. [x] `pnpm validate` green; bumped 0.9.29; Media in .release.; rebuild `.release` (Media).
   PR for human merge.
2. [ ] **In-game (human, required):** the AddOns-list icon and the config-header brand image both show,
   right-side-up.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — a build-helper + regenerated assets; no Lua/`ns`/`_G` change.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
