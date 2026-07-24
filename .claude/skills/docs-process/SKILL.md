---
name: docs-process
description: Drive Badger Addons' documentation-driven workflow for AI-assisted work — work orders (the plan), decisions (durable choices), and the gates. Use before cutting a branch, when planning any non-trivial change, when an ambiguity needs resolving, or when recording a durable choice. CANONICAL process lives in CLAUDE.md, docs/workorders.md, and docs/decisions.md — those win on any conflict.
type: skill
canonical:
  - CLAUDE.md
  - docs/workorders.md
  - docs/decisions.md
related: []
---

# docs-process — the AI-development apparatus

This skill drives the in-repo process that keeps an AI-assisted change's *plan* and *why* in the repo
(not in a disposable chat). It applies what's documented in [`CLAUDE.md`](../../../CLAUDE.md),
[`docs/workorders.md`](../../../docs/workorders.md), and
[`docs/decisions.md`](../../../docs/decisions.md).

## Work orders (the plan *is* the document)

- Non-trivial work runs as a **work order** — one file that *is* the plan: objective, **acceptance
  criteria**, phases/steps, decisions, PR link, outcome. It opens with a **YAML front-matter** block
  (`wo` / `status` / `assigned` / `mr` / `decision`) — the single home for `status`.
- **Work-order files LIVE-MIRROR to `main`.** The moment you draft a WO, edit its body, or change its
  `status`, **commit it straight to `main` and push immediately** (no branch, no PR) — a real-time edit
  ↔ git loop.
- Lifecycle **Proposed → Accepted → In progress → Done**. A draft lands as `Proposed`; **acceptance is
  the `status` field, not a PR**. **The WO is on `main` and `Accepted` before its code branch** (a
  `WO-…` branch with no accepted WO file is a stop signal). **Only the WO *file* is direct-to-`main`;
  the *code* it drives goes via branch + PR — and `Done` is tied to that PR** (flip to `Done` only once
  the code PR is **merged** and `pnpm validate` is green).
- **Auto-fill `assigned:`** with the committer's initials — `git config user.email`, take the part
  before `@`, uppercase (e.g. `ij@… → IJ`), matching the `WO-0xx-II` id suffix.
- **Gates before `Accepted`:** resolve every **`[NEEDS CLARIFICATION]`** marker; pass the one-line
  **Constitution check** (doesn't violate the engineering principles, or names the exception).
- On **Done:** note the **behaviour delta** (ADDED / MODIFIED / REMOVED) and update the topic doc.

## Decisions

Durable choices go in `docs/decisions.md`: a living **Current state** snapshot + an append-only
`D-xxx-II` log — **never edited**, superseded by new entries, so a cold restart recovers *why*.

## Working agreement (propose-then-act)

Read-only is free; anything state-changing needs **explicit, specific human acceptance** first. `docs/`
is the one standing edit grant. **Work-order files live-mirror to `main`**; for **everything else,
Branch + PR — never push `main`**; **merging is human-only**. "Done" means **`pnpm validate` is green**,
verified against reality — and for in-game behaviour, an actual `/reload` on the live client (the gate
runs off-client and can't load the addon in WoW).

## On conflict

If this skill and the canonical docs disagree, **the docs win** — and fix this skill (or raise it).
