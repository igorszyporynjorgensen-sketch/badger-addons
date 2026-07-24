---
name: badger-addons
description: Drive WoW Classic (TBC Anniversary) addon development in this repo — Ace3 patterns, the .toc manifest & load order, SavedVariables, event/frame handling, the Lua 5.1 constraints, embedded libraries via .pkgmeta, and off-client testing with the shared WoW mock. Use when adding or changing addon code, touching a .toc/.pkgmeta, wiring Ace3, or writing specs. CANONICAL details live in docs/architecture.md, docs/engineering-principles.md, and the project files — those win on conflict.
type: skill
canonical:
  - docs/architecture.md
  - docs/engineering-principles.md
related:
  - .claude/skills/house-style/SKILL.md
  - tools/wow-mock
---

# badger-addons — WoW / Ace3 / Classic driver

Applies the addon-specific rules in [`docs/architecture.md`](../../../docs/architecture.md) and
[`docs/engineering-principles.md`](../../../docs/engineering-principles.md). Reference, don't restate —
the docs and project files own the facts.

## Target client

- **WoW Classic — TBC Anniversary realms** (Lua 5.1 sandbox; arena exists in TBC, not Vanilla).
- The `.toc` `## Interface:` is a **2xxxx** value. Confirm it against the live client:
  `/run print(select(4, GetBuildInfo()))`, and update `BadgerArena.toc` if it differs.

## Ace3 patterns

- Bootstrap in `core.lua`: `LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")`.
- `OnInitialize` → `AceDB-3.0:New("BadgerArenaDB", DEFAULTS, true)` (profile defaults) + register slash
  commands. `OnEnable` → wire modules/events. Options schema in `config/config.lua` via `AceConfig-3.0`.
- **Lockstep libraries.** All Ace3 components move as one set. They are **fetched from `.pkgmeta`**,
  never committed. When code needs a new Ace module, add it to **both** `.pkgmeta` (external) and the
  `.toc` (load line) — and regenerate the build.

## The .toc — load order is code

- Order: **libraries → locales → utilities → modules → `core.lua` → `config.lua`**. A file that reads
  `ns.X` must be listed after the file that sets `ns.X`.
- Never list a `*_spec.lua` in the `.toc`. Specs are test-only.

## Namespace, events, saved data

- Every file: `local ADDON_NAME, ns = ...`; hang modules off `ns`; **no `_G` writes** (Luacheck W111).
- Keep testable logic **API-light** (no Ace3, avoid direct `CreateFrame` where practical) so it runs
  under `tools/wow-mock`. Event-driven modules take a frame + `RegisterEvent` + `SetScript("OnEvent", …)`.
- **SavedVariables carry a schema** — version stored state and migrate defensively on load; never
  assume shape.
- **Lua 5.1 only** — no `//`, `goto`, 5.3 bitwise operators (use `bit`), or `<close>`.

## Testing (off-client)

- Busted + [`tools/wow-mock`](../../../tools/wow-mock). Load the unit via `mock.load(path)` so the spec
  exercises the shipped file through the real `(addonName, ns)` contract.
- Drive state/events via the handle: `mock.install()` → `wow.state.*`, `wow.fireEvent(name, ...)`.
  Extend the mock's API surface when a spec needs more of it — a stub that diverges from real WoW is a
  bug in the mock.

## Build & verify

- Gate: `pnpm validate` (stylua · luacheck · busted). **Green ≠ loads in-game.**
- Install: `pnpm nx run badger-arena:build` → copy `projects/badger-arena/.release/BadgerArena` into
  `Interface/AddOns/`, `/reload`, then `/badgerarena` (or `/bga`). Confirm behaviour on the real client.

## On conflict

If this skill and the canonical docs/project files disagree, **the docs win** — fix this skill.
