---
name: house-style
description: Apply Badger Addons' Lua/WoW code structure & naming conventions. Use whenever creating, moving, renaming, or placing Lua files/modules, deciding where code lives, or reviewing structure. One module per file; kebab-case names; everything on the private `ns` table (no `_G` leaks); `.toc` load order; colocated specs; API-light testable logic. CANONICAL rules live in docs/engineering-principles.md — if this skill and that doc ever disagree, the doc wins.
type: skill
canonical:
  - docs/engineering-principles.md
related:
  - .claude/skills/badger-addons/SKILL.md
---

# house-style — structure & namespacing driver

This skill applies the house style documented in
[`docs/engineering-principles.md`](../../../docs/engineering-principles.md) (§1). It is an operating
checklist; the doc is the source of truth.

## The unifying rule

**Each file is one module, named for what it is; it registers itself on the private `ns` table under a
key derived from the filename; its spec sits beside it.** One name finds the file, the module, and the
test.

## Checklist (apply on every placement)

- **kebab-case, lowercase** for every file and folder (`dr-category.lua`, `src/modules/`).
- **First line is the vararg contract:** `local ADDON_NAME, ns = ...` (use `_` when the name is unused).
- **Register on `ns` under a derived key:** module/type/config → PascalCase (`ns.DrCategory`); plain
  helper → camelCase (`ns.buildOptions`). **Never write a global** — Luacheck's `std=lua51` + W111 is
  the proof; a leaked global fails the gate.
- **A colocated `<name>_spec.lua`** sits beside every behaviour-bearing unit. Pure data, locale tables,
  and thin Ace3 glue (`core.lua`, `config.lua`) don't need one.
- **Keep testable logic API-light** — free of Ace3 and (where practical) of direct frame creation — so
  it runs under `tools/wow-mock` with no framework setup. Ace3 wiring lives in `core.lua`.
- **`.toc` load order is code:** libraries → locales → utilities → modules → core → config. A module
  must be listed *after* whatever `ns` fields it reads.
- **Promotion:** a helper that gains a second consumer moves to its own module (or into `tools/`) —
  never reach into another module's file. Non-shipped shared code (the mock, build helpers) lives in
  `tools/*`; **shipped** shared libraries live under `libs/<Name-Major.Minor>/` (embedded into each
  addon's `Libs/` at build) — never in a sibling addon.
- **Config windows use `BadgerConfigUI-1.0`:** an addon's options table is normalized, registered, and
  opened through the shared LibStub config-UI library — never `AceConfig`/`AceConfigDialog` ad hoc per
  addon.

## Reject on sight

Any global write (`Foo = ...` at file scope) · logic in a locale file · a data table duplicated
instead of shared · reaching into another module's file · a `.toc` order that contradicts the `ns`
dependencies · PascalCase filenames (except a `libs/` LibStub library's `Name-Major.Minor` entry
`.lua`/`.xml`) · a behaviour-bearing module with no colocated spec · Lua 5.2+ syntax (target is 5.1).

## Bend, not break

Where a WoW/Lua reality forces a departure (e.g. specs colocated in `src/` yet excluded from the `.toc`
and packaged build), it must be a **documented divergence** that keeps the rule's intent. Never
silently break the rule.
