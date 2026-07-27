---
wo: WO-046-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/43
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on: []
related:
  - README.md
---

# WO-046-IJ — README overhaul (polished style · badger-ttk first · multi-flavor target)

- **Created / Updated:** 2026-07-27
- **Objective — from the human:**
  - Rework `README.md` to match the polished look/layout of the reference repos (`payload-wonderly`,
    `payload-zenzo`): centered hero, shields.io badges, emoji section headers, a tech-stack table, a
    `> [!NOTE]` working-agreement callout (#27).
  - **Promote badger-ttk to the first/primary addon** in the README (#27).
  - Reflect that the monorepo now targets **TBC Anniversary *and* Classic Era** (#28) — badger-ttk →
    Classic Era / Hardcore (1.15.x, Interface 11509); badger-arena → TBC Anniversary (2.5.x, Interface 20504).
- **Design notes:** README lives at repo root (outside `docs/`), so it goes via branch + PR. Keep the
  existing YAML frontmatter. Content is Lua/WoW-accurate (no JS app; Nx/pnpm only orchestrate Lua tooling).
  Badges: Lua 5.1, WoW Classic, Ace3, Nx 23, pnpm 10, StyLua, Luacheck, Busted.
- **Acceptance criteria:**
  - README reads as a polished landing page (hero + badges + nav + emoji sections + stack table + callout).
  - **badger-ttk is presented first**; badger-arena second.
  - Target framing = **TBC Anniversary + Classic Era** (per-addon flavors called out).
  - Facts accurate (versions, Interface numbers, slash commands, commands). `pnpm validate` still green
    (README change is doc-only).
- **Out of scope:** the config/display code batch (WO-040..045); CLAUDE.md (already multi-flavor-aware).
- **Behavior delta:** none (docs).

**Phase 1 — README**
1. [x] Rewrote `README.md` in the reference style; badger-ttk first; multi-flavor target.

**Phase 2 — Verify**
1. [x] `pnpm validate` green (86 tests; docs-only). PR for human merge.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge.
- **Constitution check:** Principles OK — docs only; no code/`_G` impact.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
