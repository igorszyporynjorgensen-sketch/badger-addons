---
title: Engineering Principles
type: principles
depends_on:
  - CLAUDE.md
related:
  - docs/architecture.md
  - docs/decisions.md
  - .claude/skills/house-style/SKILL.md
  - .claude/skills/badger-addons/SKILL.md
---

# Engineering Principles

How we build **Badger Addons**. These are principles, not a rulebook: each states an intent, the
reasoning behind it, and how to apply it in this stack (Nx + pnpm orchestrating a Lua toolchain ·
Ace3 · the WoW Classic TBC Lua 5.1 sandbox). When a principle collides with a deadline, surface it —
don't quietly break it.

How the human and the AI collaborate — the rule that nothing changes without human acceptance — is
operational and lives in [../CLAUDE.md](../CLAUDE.md).

---

## House philosophy — the principles behind the principles

Three stances govern how every rule below is read.

- **Bend, not break.** When a tool or the WoW platform pushes against a rule, preserve the rule's
  *intent* and relax the *mechanism* (and document the bend) — never abandon the goal. A divergence is
  only acceptable if the underlying intent still holds by other means.
- **Don't work against your chosen stack.** The house style is discipline *on top of* idiomatic WoW /
  Ace3 / Lua usage — never a campaign to make Lua behave like TypeScript. WoW loads files in `.toc`
  order into a shared Lua state; we lean into that, we don't fight it.
- **Rules constrain the *how*, not the *what*.** Conventions, quality, and the maintain-by-hand
  guarantee are universal; *what an addon does* — its features — stays open. Something outside the
  defaults enters through the front door (a written decision), not by smuggling.

Where a WoW/Lua reality must depart from a universal rule, it carries a **Divergence note**: *what
bends · why · how the spirit is kept · the boundary.*

---

## 1. Code & architecture

### 1.1 Respect the boundary: addons depend on shared tooling, never on each other

Each addon is an Nx project under `projects/*`. Shared, reusable code (the test mock, build helpers,
and any future shared library) lives under `tools/*`. Addons may depend on shared tooling; **one addon
never reaches into another addon's files**, and shared code never reaches back up into an addon.

**Why.** The dependency direction is what keeps each addon shippable on its own and keeps Nx's
`affected`/caching guarantees honest. The moment `badger-arena` imports from a sibling addon, neither
can be built or released independently.

**How to apply.** Promote code into `tools/` (or a future shared lib) when a second consumer is real —
not speculatively. Keep addon projects self-contained: everything an addon ships is under its own
`projects/<addon>/` folder. The shared Busted harness in `tools/wow-mock` is tooling, not shipped code
— it never appears in a `.toc`.

### 1.2 Keep the namespace honest — nothing leaks into `_G`

Every source file receives the addon's private table as a vararg (`local ADDON_NAME, ns = ...`) and
hangs its module off that table (`ns.ArenaDetect = ...`). **No file defines a global.** Luacheck's
`std = "lua51"` + the no-global rule (W111) is the always-on proof; a stray global fails the lint.

**Why.** Every addon shares one Lua state with WoW and every other addon. A leaked global is a
name collision waiting to happen and an invisible dependency. Keeping everything on `ns` is this
stack's equivalent of "named exports only" — a symbol has exactly one home and one name.

**How to apply.** Read API from the WoW globals the sandbox provides (declared in `.luacheckrc`
`read_globals`); *write* only to `ns` and to locals. The only globals we create are what the game
itself owns — the `SavedVariables` table named in the `.toc` — and those are declared, not leaked.
Don't silence a Luacheck warning to make code pass; fix the code, or raise the rule for discussion.

### 1.3 Honour the integration contracts — several config choices are load-bearing

**Why.** Drifting from these breaks the addon in ways that are slow and confusing to diagnose — often
only visible in-game.

**How to apply.**
- **`.toc` load order is code.** Files load top-to-bottom into one state: libraries → locales →
  utilities → modules → `core.lua` → `config.lua`. A module that reads `ns.DrCategory` must be listed
  *after* the file that sets it. Reordering the `.toc` can silently break load.
- **Target Lua 5.1.** WoW runs Lua 5.1. Write 5.1-compatible code only — no integer division `//`,
  no `goto`, no 5.3 bitwise operators (use the `bit` library), no 5.4 `<close>`. The local toolchain
  runs Luacheck/Busted under **LuaJIT (5.1)** so the host matches the client.
- **The `(addonName, ns)` vararg contract.** Every source file's first line is `local ADDON_NAME, ns
  = ...` (use `_` for the name when unused). Tests load files through the same contract
  (`tools/wow-mock`'s `load`), so a spec exercises the exact file the client loads.
- **Ace3 is embedded and lockstep.** Libraries are fetched from `.pkgmeta`, never committed, and moved
  as a set. Don't mix Ace3 component versions.
- **SavedVariables carry a schema.** State stored across sessions is versioned; migrate on load rather
  than assuming shape. Treat the saved table as data you must defensively read.

### 1.4 Prefer the simplest thing that fits, and delete what you replace

Write the least code that solves the problem at the right altitude, remove dead code rather than
commenting it out, and make new code read like the code around it.

**Why.** Every line is a liability someone later has to understand. Duplication and dead branches cost
more over their lifetime than the keystrokes they save today.

**How to apply.** Reach for an existing utility before writing a new one. Prefer a small pure module
(testable off-client) over logic tangled into an event handler. When you replace something, the old
version goes with it.

### 1.5 House style — one module per file; name, file, key and test all match

The unifying rule: **each file is one module, named for what it is; it registers itself on `ns` under
a key derived from the filename; its spec sits beside it.** One name finds the file, the module, and
the test.

**Naming.**
- **kebab-case, lowercase** for every file and folder (`dr-category.lua`, `arena-detect.lua`,
  `src/util/`, `src/modules/`).
- **The `ns` key is derived** from the filename: a module/type/config → **PascalCase**
  (`dr-category` → `ns.DrCategory`); a plain helper → camelCase (`ns.buildOptions`). One name, one home.
- **Everything is named — nothing hangs off an anonymous global or a bare `return`** (WoW ignores a
  file's return value; the `ns` table *is* the export surface).
- A behaviour-bearing unit has a colocated **`<name>_spec.lua`** beside it. Pure data, locale tables,
  and thin Ace3 glue (`core.lua`, `config.lua`) don't need one.

**Structure.**
- **Main entries** are the first-level files/folders of an area (`src/util/*`, `src/modules/*`); a
  module is the unit of reuse and testing.
- **Support** helpers serving one module live beside it (one level of subdivision, flat siblings, no
  deep nesting). The moment a helper gains a second consumer, promote it to its own module — never
  reach into another module's file.
- **API-light where it counts.** Logic worth testing (DR math, state machines) is kept free of Ace3
  and of direct frame creation where practical, so it tests against the mock with no framework setup.
  The Ace3 wiring that consumes it lives in `core.lua`.

**Divergence note — colocated specs (bend, not break).** House style says "tests live next to the
code", so `*_spec.lua` sits inside `src/`. But WoW would try to load any `.lua` listed in the `.toc`,
and the packager would ship it. *What bends:* specs live in the source tree yet must never reach the
client. *How the spirit is kept:* the `.toc` lists files explicitly (specs are simply never listed) and
`.pkgmeta`'s `ignore` drops `**/*_spec.lua` from every build. *Boundary:* a spec is test-only; it never
`require`s shipped code except through the mock loader.

**Anti-patterns (reject on sight).** Any global write (`Foo = ...` at file scope); logic in a locale
file; a spell/data table duplicated instead of shared; reaching into another module's file; a `.toc`
whose load order contradicts the `ns` dependencies; PascalCase filenames; a behaviour-bearing module
with no colocated spec.

---

## 2. Testing & verification

### 2.1 Busted is the one runner; tests live next to the code

Every project tests with [Busted](https://lunarmodules.github.io/busted/) against the shared WoW mock
(`tools/wow-mock`). Specs are colocated as `<name>_spec.lua` beside the unit they cover and load the
unit through the mock's `load()` — the same `(addonName, ns)` contract the client uses.

**Why.** One runner and one harness means any test is runnable and legible everywhere. Colocation
keeps a test discoverable and makes it obvious when code changed but its test didn't. Loading through
the real contract means the test exercises the shipped file, not a copy.

**How to apply.** Add a `<name>_spec.lua` next to new logic. Drive game state and events through the
mock handle (`wow.state.*`, `wow.fireEvent(...)`); extend the mock's API surface when a spec needs
more of it. Keep the mock a faithful stand-in — if a stub diverges from real WoW behaviour, that's a
bug in the mock.

### 2.2 Test behaviour, not implementation

Assert what a caller observes — a returned category, a multiplier, a state transition, a fired
listener — not internal structure a refactor should be free to change.

**Why.** Implementation-coupled tests break on safe refactors and stay green through real regressions.
Behavioural tests are the ones worth keeping.

**How to apply.** Assert outcomes and transitions; cover meaningful edge cases — unknown spell, immune
application, no-op transition — rather than chasing a coverage number.

### 2.3 "Done" means the validate gate is green

A change is complete when **`pnpm validate`** passes — `stylua --check`, `luacheck`, and `busted`
across every project, cached and `affected` by Nx. Not when it "should work".

**Why.** `validate` is the same gate CI runs; passing it locally is the strongest cheap signal a
change is sound. It is the shared definition of done.

**How to apply.** Run `validate` before calling work finished. When it's genuinely blocked, state that
explicitly rather than narrowing what "done" means.

### 2.4 Verify against reality, and report it faithfully

Claims about behaviour are backed by something actually observed — a passing spec, a real in-game
`/reload` — never by assumption.

**Why.** "It should load" and "I confirmed it loads and `/badgerarena` opens the panel" are different
statements, and only one is trustworthy.

**How to apply — and the honest limitation.** The gate runs off-client: it proves formatting, the
namespace discipline, and the logic under a Lua 5.1 host. **It does not load the addon in WoW.** A
green gate is *not* proof the addon loads, that the `.toc` `Interface` matches the client, or that a
frame renders. Prove those on the real client: build (`pnpm nx run badger-arena:build`), copy into
`Interface/AddOns/`, `/reload`, exercise it, and check `/run print(select(4, GetBuildInfo()))` for the
Interface number. If a step was skipped or a spec failed, say so plainly, with the output — never round
a partial result up to "done".
