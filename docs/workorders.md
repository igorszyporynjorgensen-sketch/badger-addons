---
title: Work Orders
type: work-orders
depends_on:
  - CLAUDE.md
related:
  - docs/decisions.md
  - docs/workorders/WO-001-IJ.md
  - .claude/skills/docs-process/SKILL.md
---

# Work Orders

Every job in **Badger Addons** runs as a *work order*: a complex task broken into **phases → steps**,
written down and **presented for acceptance before any state-changing action**, then tracked to
completion. A work order *is* the plan. Per [../CLAUDE.md](../CLAUDE.md), work outside `docs/` only
begins once the human has accepted the work order.

## How to use this file

- A job becomes a **Work Order (`WO-0xx-II`)** — **its own file** `docs/workorders/WO-0xx-II.md` —
  *before* execution starts. One file per WO so parallel authors never collide on a shared log.
- **Id scheme — author-initials suffix.** Ids carry uppercase author initials on one shared,
  increasing number (`WO-099-IJ` vs `WO-099-RS`). Ids are stable and never reused.
- **WO ⇒ then branch.** A `WO-0xx`-named code branch may only exist once its WO file is on `main` and
  `Accepted`. On any such branch with no entry: *stop*, reconstruct it (marked retro-logged), present
  it, then continue.
- **Lifecycle:** `Proposed` → `Accepted` → `In progress` → `Done` (or `Blocked` / `Cancelled`).
- Keep **phases small and independently verifiable**. Tick steps (`[x]`) as they complete.
- **Before `Accepted`:** resolve every `[NEEDS CLARIFICATION]` marker, and confirm the WO doesn't
  violate the engineering principles (record the **Constitution check**).
- If scope changes mid-flight, update the WO and **re-present material changes** for acceptance.
- **Link the PR** as an `mr:` value once one is opened, so branch ⇒ commits ⇒ PR ⇒ WO ⇒ decisions
  stay one click apart.

## Git convention — work-order files live-mirror to `main`

- **Work-order files push to `main` immediately.** Every change to a `docs/workorders/*.md` file — a
  new draft, a body edit, a `status` change — is committed straight to `main` and pushed the moment
  it's made (no branch, no PR), for a real-time edit ↔ git loop.
- **Acceptance is the `status` field, not a PR.** A draft lands as `Proposed`; the human accepts by it
  becoming `Accepted`. `assigned:` is auto-filled with the committer's initials (git email local-part,
  uppercased).
- **`Done` is tied to the PR.** `Proposed` / `Accepted` / `In progress` flow freely, but a WO reaches
  **`Done` only once its code PR is merged** and `pnpm validate` passes.
- **The *code* a WO drives still goes via branch + PR** — never push code to `main`:
  - **Branch prefixes** (enforced by `.githooks/pre-commit`): `<prefix>/<name>`, prefix ∈
    `feature core fix chore docs refactor hotfix release migrate`; `main`/`staging` exempt.
  - **Encode the WO id with initials:** `<prefix>/WO-0xx-II-<slug>`.
  - **One branch + one commit per code WO** (squash WIP). `main` stays green — **merging is human-only.**

## Template — new file `docs/workorders/WO-0xx-II.md`

Every WO opens with a **machine-readable YAML front-matter** block — the single home for `status`
(no body `Status:` bullet, so it can't drift). The human narrative follows.

```
---
wo: WO-0xx-II
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: II            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
---

# WO-0xx-II — <short title>
- **Created / Updated:** YYYY-MM-DD
- **Objective:** one or two sentences — what "done" looks like.
- **Acceptance criteria:** testable bullets (Given/When/Then).
- **Context / constraints:** relevant files, prerequisites, links. Tag unknowns `[NEEDS CLARIFICATION: …]`.
- **Out of scope:** what this WO deliberately will not touch.
- **Behavior delta:** ADDED / MODIFIED / REMOVED — what observable (in-game) behavior changes. Omit if none.

**Phase 1 — <name>**
1. [ ] <step>

- **Verification:** how we'll prove it works (commands + expected results, and any in-game check).
- **Constitution check:** Principles OK — or the exception + reason.
- **Decisions produced:** — (fill with D-0xx-II as they're made)
- **MR:** — (pull-request URL, added once one is opened)
- **Outcome:** — (running notes; final result on completion)
```

---

## Work order log
<!-- Newest on top. New WOs are their own files under docs/workorders/; this section is a thin index. -->

- **WO-006-IJ** — Make the monorepo honestly multi-flavor (framing + lint) and record the standard
  (D-004) + flavor-aware mock; defer split-TOC/packager machinery (see
  `docs/workorders/WO-006-IJ.md`). Status: In progress.
- **WO-005-IJ** — `.luarc.json` so the lua-language-server LSP understands the repo (Lua 5.1 · WoW
  globals · busted) (see `docs/workorders/WO-005-IJ.md`). Status: Done.
- **WO-004-IJ** — Normalized Ace3 config window — shared embeddable `BadgerConfigUI` + retrofit
  `badger-arena` (see `docs/workorders/WO-004-IJ.md`). Status: In progress.
- **WO-003-IJ** — Git-ignore the personal `.claude/settings.local.json` (see
  `docs/workorders/WO-003-IJ.md`). Status: Done.
- **WO-002-IJ** — Add a top-level `assets/` folder for inspiration & references (see
  `docs/workorders/WO-002-IJ.md`). Status: Done.
- **WO-001-IJ** — Scaffold the project (see `docs/workorders/WO-001-IJ.md`). Status: Done.
