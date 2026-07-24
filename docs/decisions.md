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
  (shared Busted harness) · `tools/build.sh` (packager wrapper) · `libs/BadgerConfigUI-1.0` (shared
  **shipped** LibStub config-UI library, embedded into each addon's `Libs/` at build). No JavaScript app.
- **Config-window standard.** Every Badger addon registers, sizes, and opens its options through the
  shared `BadgerConfigUI-1.0` LibStub library — a native `AceConfigDialog` tree window + branded banner
  — never ad hoc per addon. Shipped shared libraries live under a top-level `libs/<Name-Major.Minor>/`
  (distinct from never-shipped `tools/`) and are embedded into `Libs/` by `tools/build.sh`, opt-in via
  each addon's `.toc` (see D-003-IJ).
- **Docs/process in place.** `CLAUDE.md`, `docs/engineering-principles.md`, `docs/workorders.md` +
  `docs/workorders/WO-001-IJ.md`, this log, `docs/milestones.md`, `docs/architecture.md`.
- **Not in scope (by design).** No company-infra registration, no ports/subdomains/Notion — this is a
  standalone game addon repo. No web/security layer.
- **Inspiration assets.** `assets/` (repo root) holds internet-gathered reference material — see
  `assets/README.md`. Drops land via a lightweight lane: `chore` branch + PR (human merges), **no work
  order**; images are optimized before the first commit (see D-002-IJ).
- **Next id:** D-004-IJ.

---

## Decision log

### 2026-07-24

- **[D-003-IJ] Config windows use the shared `BadgerConfigUI-1.0` LibStub library; shipped shared
  libraries live under a new top-level `libs/<Name-Major.Minor>/`, embedded into each addon's `Libs/` by
  `tools/build.sh` (not `.pkgmeta` externals).** One branded config-window standard across every Badger
  addon — a native `AceConfigDialog` tree + banner header, sized/registered/opened once through the lib
  rather than each addon wiring `AceConfig`/`AceConfigDialog` ad hoc. *Why the new home:* `tools/` is
  defined as never-shipped tooling (§1.1), but a lib listed in a `.toc` **is** shipped — so a shipped
  shared lib needs its own place, and `libs/` makes the shipped-vs-tooling boundary honest. The lib is a
  LibStub library (deduped across addons via `NewLibrary`), copied into `Libs/` at build like the Ace
  externals and opt-in via each addon's `.toc` — not a URL external, since the source lives inside the
  monorepo. *The bend:* the folder **and its entry `.lua`/`.xml`** are named `Name-Major.Minor`
  (`BadgerConfigUI-1.0`) rather than kebab-case, matching its `Libs/` copy target so the embed is a
  straight copy (internal sub-modules stay kebab-case) — the same documented divergence already granted
  to vendored `Libs/`. See WO-004.
- **[D-002-IJ] `assets/` drops use a lightweight lane — `chore` branch + PR, no work order; images
  optimized first.** Adding reference/inspiration material to `assets/` is treated as *content*, not a
  code "job": it lands on a `chore/` branch and reaches `main` via a PR the human merges (never a
  direct push), but skips the work-order ceremony. Images are optimized **before** the first commit —
  git keeps binaries in history permanently, so a 3.1 MB screenshot became a 280 KB WebP (`cwebp q90`,
  full resolution retained) rather than bloating history. *Why:* a WO per screenshot is overhead out of
  all proportion to the change, while the branch+PR+human-merge gate still protects `main`; front-loading
  optimization keeps the repo lean forever. Established when the first inspiration screenshot was added
  (`assets/images/arena-ui-1.webp`, PR #4). Does **not** loosen the rule for *code* — code still runs
  through work orders.
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
