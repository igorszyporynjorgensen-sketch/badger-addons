---
wo: WO-016-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/19
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-012-IJ.md
  - docs/workorders/WO-015-IJ.md
related:
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/BadgerTTK.toc
---

# WO-016-IJ — `badger-ttk` fix: Interface 11509 + live driver clobbers the sim preview

- **Created / Updated:** 2026-07-25
- **Objective:** two small fixes from the human's first in-game test: (1) set the `.toc` Interface to the
  live client build **11509**; (2) the **sim preview flashes then disappears** — the live driver's ticker
  hides the display when there's no target, clobbering the static/dynamic preview.
- **Root cause (bug 2):** `ns.LiveDriver` runs a ~0.15s ticker (started at `OnEnable`); when there is no
  valid target it calls `ns.Display.hide()`. While the user previews in the config (no target), that
  ticker fires just after the preview renders and hides it — the display has **two owners** (the sim
  preview and the live driver) with no coordination.
- **Acceptance criteria:**
  - `BadgerTTK.toc`: `## Interface: 11509`.
  - `LiveDriver` **yields while a preview is active**: when `db.profile.simStatic` or `simPlaying` is set,
    `update()` returns early and does not touch the display (the sim owns it). Turning the preview off
    hands control back (the driver resumes hide/show on target).
  - **Gate:** `pnpm validate` green (the change is inside the edge `update()`; the pure helpers/specs are
    unchanged — no test regressions).
  - **In-game (human):** the static preview stays up; dynamic playback animates without flicker; a real
    target still drives the bars.
- **Out of scope:** any behavior beyond these two fixes.
- **Behavior delta:** MODIFIED (in-game) — the sim preview no longer flickers/vanishes; `.toc` targets
  the live build.

**Phase 1 — Fix**
1. [x] `BadgerTTK.toc` Interface → 11509; `driver.lua` `update()` early-returns while `simStatic`/
       `simPlaying` is set.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (`format-check, lint, test` for 4 projects; luacheck 0/0). PR #19 opened.
2. [x] PR #19 merged; rebuilt the `.release/BadgerTTK` package for the in-game re-test.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; the human
  re-tests the preview + a real target.
- **Constitution check:** Principles OK — a targeted edge fix; no `_G` leaks; pure logic untouched.
- **Decisions produced:** —
- **MR:** [PR #19](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/19)
- **Outcome:** Both edits made; `pnpm validate` green; **PR #19 merged**. Rebuilt the `.release/BadgerTTK`
  package (macOS ships bash 3.2, so the BigWigs packager can't run — the addon-own tree was refreshed in
  place over the proven-good, unchanged `Libs/`). Verified: Interface **11509**; the `simStatic`/`simPlaying`
  yield present in the shipped `driver.lua`; the full `.toc` + nested-XML **load graph resolves (65 files,
  0 missing)**; shipped `src`/`Locales` byte-identical to the repo; no `_spec`/`project.json`/`.pkgmeta`
  leak. Package: `projects/badger-ttk/.release/BadgerTTK/` (73 files) + `BadgerTTK.zip`. Awaiting the
  human's in-game re-test of the preview fix.
