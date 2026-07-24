---
wo: WO-003-IJ
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

# WO-003-IJ — Git-ignore the personal `.claude/settings.local.json`

- **Created / Updated:** 2026-07-24
- **Objective:** keep each contributor's **personal** Claude Code config
  (`.claude/settings.local.json`) out of version control by adding one line to `.gitignore`, while
  the shared, committed `.claude/skills/` (and any future `.claude/settings.json`) stay tracked.
- **Acceptance criteria:**
  - Given the repo, When `git check-ignore .claude/settings.local.json` runs, Then it reports the
    path as ignored.
  - Given `.claude/skills/`, Then it remains tracked (the ignore rule targets only the local settings
    file, not the whole `.claude/` directory).
  - Given the quality gate, When `pnpm validate` runs, Then it stays green (no Lua touched).
- **Context / constraints:** follow-on hygiene from setting up local bash permissions
  (`.claude/settings.local.json` was created this session, personal + untracked). No global git
  ignore covers it, so a repo-level rule is required. The Lua toolchain lives on `~/.luarocks/bin` —
  not on the non-interactive shell's `PATH` — so the gate must be run with that dir prepended.
- **Out of scope:** any change to the shared `.claude/settings.json` (none exists yet); the contents
  of `settings.local.json` itself (personal, never committed).
- **Behavior delta:** none — repo hygiene only.

**Phase 1 — Ignore the local settings file**
1. [ ] Add `.claude/settings.local.json` to `.gitignore` under a clearly-labelled Claude Code section.

- **Verification:** `git check-ignore -v .claude/settings.local.json` reports the rule;
  `git status` no longer surfaces the file; `PATH="$HOME/.luarocks/bin:$PATH" pnpm validate` green;
  PR opened to `main` for human merge.
- **Constitution check:** Principles OK — additive, no code, no in-game impact.
- **Decisions produced:** — (none expected)
- **MR:** — (added once the PR is opened)
- **Outcome:** — (running notes; final result on completion)
