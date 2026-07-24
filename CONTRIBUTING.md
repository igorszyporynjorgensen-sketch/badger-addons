---
title: Contributing
type: contributing
depends_on:
  - CLAUDE.md
  - docs/engineering-principles.md
related:
  - docs/workorders.md
  - docs/decisions.md
---

# Contributing to Badger Addons

This repo is run **documentation-driven** and **propose-then-act**. The full working agreement is in
[`CLAUDE.md`](CLAUDE.md); the standing code conventions are in
[`docs/engineering-principles.md`](docs/engineering-principles.md). This file is the practical how-to
for getting a change merged.

## The golden rule

**Never push to `main` directly — always work on a prefixed branch and open a pull request.** This
holds for *every* code change, including one-liners. "Commit and push" means *the branch*, then the
PR. **Merging is human-only.** (The one exception: `docs/workorders/*.md` files live-mirror to `main`
— see [`CLAUDE.md`](CLAUDE.md).)

## Branches

`<prefix>/<name>`, where `<prefix>` ∈ `feature · core · fix · chore · docs · refactor · hotfix ·
release · migrate`. Encode the **work-item id with author initials**: a work-order/decision id for
AI-assisted work (`feature/WO-012-IJ-<slug>`, `fix/D-007-IJ-<slug>`), or your tracker's ticket id for
manual work. A `.githooks/pre-commit` hook (activated on `pnpm install`) enforces the id + initials
shape. `main`/`staging` are exempt.

## Work orders & decisions

Work orders and decisions are the **AI-development** record. For **AI-assisted** work, jobs run as
**work orders** ([`docs/workorders.md`](docs/workorders.md)) — write the WO file and get it accepted
**before** cutting the branch; record durable choices in [`docs/decisions.md`](docs/decisions.md).
Before a WO is `Accepted`: resolve every `[NEEDS CLARIFICATION]` marker and confirm it doesn't violate
the engineering principles.

## Document metadata (frontmatter)

Every process document and Claude skill opens with a YAML front-matter block that makes the doc graph
explicit — so a reader (or a tool) can follow dependencies without guessing. Keep these accurate when
you add or move a document.

- `title` — human title. `type` — the doc's role (`working-agreement`, `principles`, `decision-log`,
  `work-orders`, `milestone-log`, `retrospective`, `architecture`, `contributing`, `readme`, `skill`).
- `depends_on` — documents this one assumes/builds on (read those first).
- `related` — sibling documents worth reading alongside.
- `canonical` — (skills only) the document(s) that are the source of truth this skill defers to; on any
  conflict, the canonical doc wins.
- Work-order files additionally carry their machine-readable fields (`wo`, `status`, `assigned`, `mr`,
  `decision`) in the same block.

Paths are repo-relative. A relationship is a one-way pointer; add the reciprocal entry when it's
genuinely mutual.

## Code style

Follow the house style in [`docs/engineering-principles.md`](docs/engineering-principles.md): one
module per file, kebab-case filenames, **everything hangs off the private `ns` table — no `_G` leaks**
(Luacheck enforces this), and colocate a `*_spec.lua` beside behaviour-bearing units.

## Testing & the gate

Add a colocated `*_spec.lua` next to new logic (Busted + the shared WoW mock in
[`tools/wow-mock`](tools/wow-mock)). Test behaviour, not implementation. The single gate is:

```bash
pnpm validate   # nx run-many: stylua --check · luacheck · busted
```

**"Done" = `pnpm validate` is green.** In-game behaviour changes are additionally confirmed with a
real `/reload` on the live TBC Anniversary client — the gate cannot load the addon in WoW.

## In-game / packaging

`Libs/` (Ace3 and friends) is fetched from `.pkgmeta`, never committed. Build an installable copy with
`pnpm nx run badger-arena:build`, then drop `projects/badger-arena/.release/BadgerArena` into your WoW
`Interface/AddOns/`.

## PR checklist

- [ ] On a correctly-prefixed branch, **not** `main`.
- [ ] `pnpm validate` passes (stylua · luacheck · busted).
- [ ] Specs added/updated for the change.
- [ ] Docs updated (decision logged if durable; work order ticked; behavior delta noted).
- [ ] Commit subjects follow `type:` / `WO-0xx:`.
