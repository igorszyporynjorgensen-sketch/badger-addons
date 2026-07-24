---
wo: WO-002-IJ
status: Accepted         # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ             # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                    # pull-request URL once opened, else ~
decision: ~              # D-0xx-II once a decision is produced, else ~
depends_on:
  - CLAUDE.md
  - docs/workorders.md
related:
  - docs/decisions.md
---

# WO-002-IJ — Add a top-level `assets/` folder for inspiration & references

- **Created / Updated:** 2026-07-24
- **Objective:** add a repo-root `assets/` folder as the home for inspirational material gathered
  from the internet — screenshots, UI references, pictures, and documents/articles — with a `README.md`
  that explains what belongs there and notes these are references, not redistributed addon assets.
- **Acceptance criteria:**
  - Given the repo root, When I list it, Then an `assets/` folder exists containing `README.md`.
  - Given `assets/`, Then it holds `images/` and `documents/` subfolders (tracked via `.gitkeep`),
    ready to receive references.
  - Given the `README.md`, Then it states the folder's purpose, the subfolder layout, and an
    attribution/copyright note (external references for inspiration only — not shipped in the addon).
  - Given the quality gate, When `pnpm validate` runs, Then it stays green (no Lua is added; the
    Lua toolchain does not touch `assets/`).
- **Context / constraints:** reference-only content that is **outside** `projects/`, so the packager
  never bundles it into an addon build. Images/documents are committed **directly** to git (no Git LFS)
  — keep individual files reasonably sized. `assets/` needs no `.gitignore`/`.gitattributes` changes;
  it is not Lua/`.toc`/`.xml`, so linguist and the gate ignore it.
- **Out of scope:** any actual asset content (the images/documents themselves land later, ad hoc);
  Git LFS setup; wiring assets into the addon, docs, or build pipeline.
- **Behavior delta:** none — no in-game behavior changes (repo housekeeping only).

**Phase 1 — Create the folder**
1. [ ] `assets/README.md` — purpose, subfolder layout, attribution/copyright note.
2. [ ] `assets/images/.gitkeep` and `assets/documents/.gitkeep` so the empty subfolders track.

- **Verification:** `ls assets` shows `README.md`, `images/`, `documents/`; `pnpm validate` stays
  green; PR opened to `main` for human merge.
- **Constitution check:** Principles OK — additive, no code, no toolchain or in-game impact.
- **Decisions produced:** — (none expected)
- **MR:** — (added once the PR is opened)
- **Outcome:** — (running notes; final result on completion)
