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

## M-002 — badger-ttk v1 core loop (2026-07-25)

The repo's **second addon and first Vanilla (Classic Era 1.15) addon**, `badger-ttk`, works in a real
fight: a right-anchored time-to-kill bar plus utility bars showing **when to fire each cooldown** so its
buff covers the kill. Designed from a sketch + a reference WeakAura through the work-order apparatus
(epic WO-007), then built child-by-child (WO-008 → WO-015). Everything above the frame edge is pure and
spec-tested (53 specs); the change of nature: from *design* to a *functioning addon*.

### What stands
- **The loop** — one pure engine (health-fraction EWMA estimator + render-model geometry) driven by
  **three drivers** (live combat / sim / Busted specs), rendered by a skinnable frame display.
- **Estimator** — reactivity slider · execute-correction · confidence gate · **boss phase/immune pause**
  (C'Thun / Ragnaros submerge) · the WarcraftLogs history seam (`db.global`) prepared, not built.
- **Ability model** — a static, complete warrior master table + a live availability/usability overlay;
  per-entry enable/disable + a bi-directional pop-offset; the multi-use pop-line comb.
- **Config** — the full `BadgerConfigUI` tree (General/Behavior/Skin/Display/Estimator/Abilities/
  Simulation/Profiles), icon-rich, with an **open user-authored skin system** (`RegisterSkin` + LSM).
- **Live driver** — samples the real target, tracks cooldowns, feeds the display, gated by Behavior.

### What's next
- **Show-gating** — the Raids node / per-encounter registry (today: Behavior toggles + any-target).
- **WarcraftLogs history** — import + the live×history blend (the seam is in place).
- The first **in-game `/reload`** confirmation (the human has waived it during the build).

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
