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
  `Locales/`, `.pkgmeta`). `projects/badger-arena` (TBC, folder/TOC `BadgerArena`) and
  `projects/badger-ttk` (the repo's first **Vanilla / Classic Era** addon, folder/TOC `BadgerTTK`;
  currently a scaffold — see WO-007/WO-008).
- **Shared tooling:** `tools/wow-mock` (the Busted stand-in for the WoW client) and `tools/build.sh`
  (the packager wrapper). These are test/build support — never shipped in a `.toc`.
- **Shared shipped libraries:** `libs/<Name-Major.Minor>/` — LibStub libraries embedded into each
  addon's `Libs/` at build (e.g. `libs/BadgerConfigUI-1.0`). Distinct from `tools/`: a `libs/` library
  **is** shipped code, named in the consuming addon's `.toc`.
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
- **Per-project flavor targeting** — the repo spans multiple WoW Classic flavors; each addon declares
  its own via a `flavor:*` tag in `project.json`, its `.toc` `## Interface:`, and a scoped `.luacheckrc`
  API overlay. `badger-arena` → TBC (2.5.x, `WOW_PROJECT_BURNING_CRUSADE_CLASSIC`, arena API); a hardcore
  addon → Classic Era / Vanilla (1.15.x, `WOW_PROJECT_CLASSIC`, no arena). Guard flavor-specific code
  with `WOW_PROJECT_ID`; probe optional APIs with `type(fn) == "function"`; the shared mock is
  flavor-aware (`install({ flavor })`). One addon shipping to *both* flavors (split `_Suffix.toc` or a
  multi-`## Interface` TOC + packager `-S`) is deferred until needed (see D-004-IJ).
- **`.toc` load order is load-bearing** — a module must be listed after whatever `ns` fields it reads.
- **Embedded libraries** — most `Libs/` come from `.pkgmeta` externals (Ace3, LibStub, …), fetched at
  build time into `Libs/` — gitignored, never committed, moved as a lockstep set. Monorepo-internal
  shared libs under `libs/` are **not** externals: `tools/build.sh` copies them into the packaged
  `Libs/` after the packager runs, opt-in via the addon's `.toc`.
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
- `config/config.lua` — the AceConfig options schema, normalized + registered + opened through
  `BadgerConfigUI-1.0` (native-tree window + banner); a thin Blizzard launcher stub.
- `Locales/enUS.lua` — AceLocale base locale.

**Open product decisions (future WOs):** unit-frame approach (custom `CreateFrame` vs an oUF-style
layer), whether to adopt DRList-1.0 for real DR data, and trinket/cooldown tracking. *(Per-project
flavor targeting is established — see D-004-IJ; the both-flavor build machinery is deferred until a
both-flavor addon exists.)*

## badger-ttk — second addon (Vanilla / Classic Era, scaffold)

The repo's **first Vanilla (Classic Era 1.15) addon** and the first exercise of the D-004 multi-flavor
setup in a *non-TBC* project (`flavor:vanilla` tag · scoped `.luacheckrc` overlay with no arena API ·
the mock's `vanilla` surface). Currently **scaffold + the full config tree** (WO-008/WO-009): `core.lua`
Ace3 bootstrap with AceDB `profile` (every setting, real-typed defaults) + a reserved `global`
(kill-history seam), and a complete `BadgerConfigUI` options window (General/Behavior/Skin/Display/
Estimator wired to `db.profile`; Raids/Abilities/Simulation placeholders their feature WOs fill;
Profiles) that **persists settings but drives no gameplay yet**. The full design — the right-anchored time-to-kill render model, one pure engine + three
drivers (live / sim / spec), a live-only-smart TTK estimator, a static-master-table ability model with a
live availability/usability overlay, config-driven per-encounter gating, and an open user-authored skin
system — lives in [WO-007](workorders/WO-007-IJ.md) and lands via its child WOs (**config first**). See
D-005-IJ / D-006-IJ. Warrior cooldown data: [reference/warrior-ttk-cooldowns.md](reference/warrior-ttk-cooldowns.md).

## Diagram
<!-- Add a component/flow diagram when the shape is worth a picture. -->
