---
wo: WO-064-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on: []
related:
  - projects/badger-ttk/CHANGELOG.md
---

# WO-064-IJ — add a CHANGELOG and a per-release changelog process

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** every new version needs a changelog entry for CurseForge (and git).
- **Design notes:** one **`projects/badger-ttk/CHANGELOG.md`** (Keep a Changelog format, newest first),
  the single source of truth. Player-facing bullets only. It is NOT copied into the shipped `.release`
  (keeps the addon lean) — it lives in git and feeds the CurseForge box.
  - **Process (folds into every version bump):** accumulate changes under `## [Unreleased]`; when a
    version WO bumps the `.toc`, rename `[Unreleased]` → `## [x.y.z] - YYYY-MM-DD`, and paste that
    section's body into the CurseForge file's **Changelog** field on upload. Start a fresh empty
    `[Unreleased]`.
  - Seed the first entry as **0.9.44** (the initial public pre-1.0 release) with the headline features.
- **Acceptance:** `CHANGELOG.md` exists with a 0.9.44 entry + an `[Unreleased]` stub; `pnpm validate`
  unaffected (non-Lua). No `.toc` bump — it documents the existing 0.9.44.
- **Behavior delta:** none (in-game) — repo/docs artifact.
- **Constitution check:** Principles OK — documentation; no code/`_G` change.

**Phase 1** 1. [ ] Add CHANGELOG.md (0.9.44 + Unreleased).
**Phase 2** 1. [ ] PR. (Ongoing: every version WO updates [Unreleased] → the new version section.)
