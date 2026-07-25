---
title: CLAUDE.md — working agreement
type: working-agreement
depends_on: []
related:
  - docs/engineering-principles.md
  - docs/workorders.md
  - docs/decisions.md
  - CONTRIBUTING.md
---

# CLAUDE.md — Badger Addons

Operational guidance for AI agents (Claude Code) working in this repository. Engineering
principles for the code itself live in [docs/engineering-principles.md](docs/engineering-principles.md).

**What this repo is:** an Nx + pnpm monorepo of lightweight **WoW Classic** unit-frame / on-screen-info
UI addons under the *Badger* brand, each targeting its own client **flavor** per project (`badger-arena`
→ TBC Anniversary 2.5.x; addons may also target Classic Era / Hardcore, Vanilla 1.15.x). Each addon is
an Nx project under `projects/`; the first is `badger-arena`. The code is Lua (the WoW client's Lua 5.1 sandbox); Nx and
pnpm exist only to orchestrate the Lua tooling (StyLua · Luacheck · Busted) — there is no JavaScript
application here.

## Working agreement — nothing happens without human acceptance

The overriding rule, ahead of everything else in this repo: **never take an action that changes
anything without explicit human acceptance first.**

**Why.** The human is the decision-maker and owns the outcome. Speed is worth nothing if the human
is surprised by what landed. Propose-then-act keeps the human in control, makes every change
reviewable *before* it exists, and means "done" is always something the human chose.

**How this works in practice.**

- **Free without asking** — read-only, no side effects: reading files, searching, running the gate
  read-only (`pnpm validate`, `pnpm test`, `luacheck`, `stylua --check`), and *proposing* plans or diffs.
- **Requires explicit acceptance first** — creating, editing, or deleting files; installing or
  removing dependencies (pnpm packages, luarocks, brew); running generators or the packager; git
  operations; and anything that reaches an external service.
- **Acceptance is explicit and specific.** A clear "yes, do X" is acceptance for X — not the next
  thing. Silence is never acceptance. When in doubt, stop and ask.
- **Present before performing.** Show the proposed change (file + content, or the exact command) and
  wait. Batch related proposals so review stays efficient, but never act ahead of the "go".
- **Standing exception — `docs/`.** The AI may create and edit any file under `docs/` (decisions log,
  work orders) without asking. Everything outside `docs/` still requires explicit acceptance.
- **Branch + PR — never push to `main` directly.** Every code change lands on a prefixed branch
  (`<prefix>/<name>`, prefix ∈ `feature core fix chore docs refactor hotfix release migrate`) and
  reaches `main` only via a pull request. When the change belongs to a work order, encode the id with
  author initials: `<prefix>/WO-0xx-II-<slug>` (or `<prefix>/D-0xx-II-<slug>` when a decision is the
  anchor). **The WO entry comes before the branch:** the work order must already be on `main` and
  `Accepted` before its branch is cut; a `WO-0xx` branch with no accepted WO file is a stop signal —
  reconstruct the entry (marked retro-logged) and present it before any further execution. The branch
  convention is enforced by `.githooks/pre-commit`.
- **Exception — work-order files are a LIVE MIRROR to `main` (no branch, no PR).** Every change to a
  `docs/workorders/*.md` file — drafting a new WO, editing its body, any `status` change — is committed
  straight to `main` and pushed immediately, so the plan is reflected in git in real time. A drafted WO
  lands as `status: Proposed`, and **the human acceptance gate is the `status` field** — you accept by
  it becoming `Accepted`, not via a PR. `Proposed` / `Accepted` / `In progress` flow freely, but
  **`Done` is tied to the PR** — set `Done` only once the WO's code PR is **merged** and `pnpm validate`
  is green. **Only the work-order *files* are direct-to-`main`; the *code* a WO drives still goes via
  branch + PR.**
- **Merging is human-only.** The AI never merges a pull request — not even with prior blanket
  permission. Wide grants ("proceed", "fix it") cover the branch, the commits, and *opening* the PR;
  the merge click is the human's review gate. The AI's job ends at "PR is ready for your review".

## Work orders & decisions

This documentation-driven process — work orders and decisions under `docs/` — is the
**AI-development apparatus**: it keeps the plan and the *why* in the repo, where the chat that
produced them cannot live. When a change is made **manually** by a person, that role is filled by the
team's own tickets instead; the in-repo work-order trail is for AI-driven work.

Jobs run as **work orders** ([docs/workorders.md](docs/workorders.md)) — a WO *is* the plan,
proposed → accepted → executed. Durable choices get a **decision** entry
([docs/decisions.md](docs/decisions.md)). Before marking a WO `Accepted`: resolve every
`[NEEDS CLARIFICATION]` marker and confirm it doesn't violate the engineering principles (the
"Constitution check"). **"Done" means `pnpm validate` is green** — and, for anything that changes
in-game behaviour, confirmed with an actual `/reload` on the live client (the gate proves
lint/format/tests, not that the addon loads in WoW — see the engineering principles).
