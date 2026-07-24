---
title: Decisions Log
type: decision-log
depends_on: []
related:
  - docs/engineering-principles.md
  - docs/workorders.md
  - docs/milestones.md
---

# Decisions Log

The durable memory for **Badger Addons**. Its job: let anyone (human or AI) pick up cold after a
session closes and recover *what was decided and why* — without re-reading the whole git history.

Related: engineering principles → [engineering-principles.md](engineering-principles.md) ·
working agreement → [../CLAUDE.md](../CLAUDE.md).

## How to use this file

- **[Current state](#current-state)** is a living snapshot — read it first to re-orient. It is
  rewritten to stay true; it always describes *now*.
- **[Decision log](#decision-log)** is append-only history, newest on top. Each decision has a stable
  id (`D-0xx-II`, uppercase author initials). Decisions are never edited in place once recorded; if one
  is reversed, add a new entry and mark the old one `Superseded by D-0xx`.
- Entry shape: **`[D-0xx-II] Decision`** — *why*; with `Status:` when not simply `Accepted`.

---

## Current state

_As of 2026-07-24._

- **Scaffolded and verified green.** Nx (pnpm) monorepo orchestrating a Lua toolchain — StyLua ·
  Luacheck (LuaJIT/5.1) · Busted — behind one `pnpm validate` gate. Target client: WoW Classic TBC
  Anniversary. Framework: Ace3. `pnpm validate` passes (stylua · luacheck 0/0 · busted 12/12).
- **Layout.** `projects/badger-arena` (the first addon, folder `BadgerArena`) · `tools/wow-mock`
  (shared Busted harness) · `tools/build.sh` (packager wrapper). No JavaScript app.
- **Docs/process in place.** `CLAUDE.md`, `docs/engineering-principles.md`, `docs/workorders.md` +
  `docs/workorders/WO-001-IJ.md`, this log, `docs/milestones.md`, `docs/architecture.md`.
- **Not in scope (by design).** No company-infra registration, no ports/subdomains/Notion — this is a
  standalone game addon repo. No web/security layer.
- **Next id:** D-002-IJ.

---

## Decision log

### 2026-07-24

- **[D-001-IJ] Stack + conventions chosen at scaffold.** An Nx + pnpm monorepo of WoW Classic (TBC
  Anniversary) UI addons under the *Badger* brand, first addon `badger-arena`; Ace3 as the framework;
  the mandatory quality floor (StyLua + Luacheck + Busted behind `pnpm validate`); a shared WoW mock
  for off-client unit tests; the documentation-driven process; and the Lua/WoW house style (one module
  per file, everything on `ns`, no `_G` leaks). *Why:* keep the scandesigns way — a single cached CI
  gate, type-of-truth discipline via the linter's namespace rule, and the AI-development apparatus —
  while adapting the stack from web (Next/Payload) to Lua/WoW and dropping the infra/cross-project
  layer, which does not apply to a game addon. Toolchain de-pinned, resolved to current at scaffold;
  Luacheck/Busted bound to **LuaJIT (Lua 5.1)** to match the WoW runtime (host Lua 5.5 is too new for
  those rocks). Scaffolded by the adapted `scaffold-project` wizard (see `WO-001-IJ`).
