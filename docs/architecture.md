---
title: Architecture
type: architecture
depends_on:
  - docs/engineering-principles.md
related:
  - docs/decisions.md
  - projects/badger-arena/BadgerArena.toc
  - .claude/skills/badger-addons/SKILL.md
---

# Architecture — Badger Addons

How the system is put together. Keep this honest as the project evolves; when a work order changes the
architecture, note it here (ADDED / MODIFIED / REMOVED) on Done.

## Shape

- **Monorepo:** Nx (pnpm workspaces). Addons depend on shared tooling; tooling never on addons; addons
  never on each other.
- **Addons:** `projects/<addon>/` — each a self-contained WoW addon (its own `.toc`, `src/`,
  `Locales/`, `.pkgmeta`). First and only so far: `projects/badger-arena` (folder/TOC `BadgerArena`).
- **Shared tooling:** `tools/wow-mock` (the Busted stand-in for the WoW client) and `tools/build.sh`
  (the packager wrapper). These are test/build support — never shipped in a `.toc`.
- **No JavaScript app.** Node/pnpm/Nx exist only to orchestrate the Lua toolchain and cache its tasks.

## Runtime model (per addon)

- WoW loads the files listed in the `.toc`, in order, into one shared Lua 5.1 state: **libraries →
  locales → utilities → modules → `core.lua` → `config.lua`**.
- Every file gets `local ADDON_NAME, ns = ...` and hangs its module off the private `ns` table.
  Nothing is written to `_G` (Luacheck enforces).
- **Ace3** provides the spine: `AceAddon` (lifecycle), `AceDB` (`SavedVariables` profiles),
  `AceEvent` (messaging), `AceConsole` (slash commands), `AceConfig`/`AceGUI` (the options panel).
- Feature logic worth testing (e.g. `util/dr-category`, `modules/arena-detect`) is kept API-light so it
  runs under the mock without a live client.

## Boundaries & contracts

- **Lua 5.1 target** (no 5.2+ syntax). The local gate runs Luacheck/Busted under LuaJIT (5.1).
- **`.toc` load order is load-bearing** — a module must be listed after whatever `ns` fields it reads.
- **Embedded libraries** come from `.pkgmeta` externals (Ace3, LibStub, …), fetched at build time into
  `Libs/` — gitignored, never committed, moved as a lockstep set.
- **Colocated specs** (`*_spec.lua`) live in the source tree but never ship: excluded from the `.toc`
  and from the packaged build (`.pkgmeta` `ignore`).
- Code organization follows the house style in [engineering-principles.md](engineering-principles.md).

## Quality & delivery

- **Gate:** `pnpm validate` → `nx run-many -t format-check lint test` (StyLua · Luacheck · Busted),
  cached and `affected` by Nx. CI (GitHub Actions) runs the same gate on every PR.
- **Build / install:** `pnpm nx run badger-arena:build` → `tools/build.sh` runs the BigWigs packager,
  fetching `.pkgmeta` externals into `projects/badger-arena/.release/BadgerArena` — copy that into WoW's
  `Interface/AddOns/`.

## badger-arena — first addon (current shape)

- `util/dr-category.lua` — pure DR data + arithmetic (category lookup, per-application multiplier,
  immunity, the 18s reset window). Illustrative TBC seed.
- `modules/arena-detect.lua` — event-driven arena-state tracker with a listener list; API-light.
- `core.lua` — Ace3 bootstrap (DB defaults, slash commands, wires `arena-detect` to a message).
- `config/config.lua` — the AceConfig options schema + Blizzard panel registration.
- `Locales/enUS.lua` — AceLocale base locale.

**Open product decisions (future WOs):** unit-frame approach (custom `CreateFrame` vs an oUF-style
layer), whether to adopt DRList-1.0 for real DR data, trinket/cooldown tracking, and multi-flavor
support if the Anniversary realms progress past TBC.

## Diagram
<!-- Add a component/flow diagram when the shape is worth a picture. -->
