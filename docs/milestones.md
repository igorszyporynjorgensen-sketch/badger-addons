---
title: Milestones
type: milestone-log
depends_on: []
related:
  - docs/decisions.md
  - docs/workorders.md
  - docs/retrospective.md
---

# Milestones

Coarse-grained markers for **Badger Addons** — the moments where a whole phase became *done* and the
nature of the work changed. Day-to-day history lives in [decisions.md](decisions.md) and
[workorders.md](workorders.md); this file records only the summits. Append-only, newest on top.

---

## M-001 — Foundation (2026-07-24)

The project exists and stands on its own: an Nx + pnpm monorepo of WoW Classic (TBC Anniversary) UI
addons under the *Badger* brand, with the first addon skeleton, a shared off-client test harness, the
mandatory Lua quality floor, and the documentation-driven process — all scaffolded and verified green.

### What stands
- **Monorepo + first addon** — Nx (pnpm) orchestrating Lua tooling · `projects/badger-arena`
  (Ace3, folder `BadgerArena`) · `tools/wow-mock` (shared Busted harness).
- **Quality floor** — StyLua · Luacheck (LuaJIT/5.1, no-`_G`-leak enforced) · Busted (12 specs) behind
  one `pnpm validate` gate.
- **Process** — CLAUDE.md working agreement · engineering principles (Lua/WoW dialect) · decisions log
  · work orders · this file. First work order: `WO-001-IJ`.

### What's next
- First product milestone — the first real on-screen feature (arena enemy frames / DR tracking).
  Fill in as the work begins.
