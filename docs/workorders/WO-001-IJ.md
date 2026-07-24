---
wo: WO-001-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/1
decision: D-001-IJ
depends_on:
  - CLAUDE.md
  - docs/workorders.md
related:
  - docs/decisions.md
  - docs/architecture.md
---

# WO-001-IJ — Scaffold Badger Addons

- **Created / Updated:** 2026-07-24
- **Objective:** stand up the project — an Nx + pnpm monorepo of WoW Classic (TBC Anniversary) UI
  addons under the *Badger* brand, with the first addon `badger-arena`, the mandatory Lua quality
  floor, a shared off-client test harness, and the documentation/process layer — verified green.
- **Acceptance criteria:**
  - `pnpm install` clean; the git hooks are wired.
  - `pnpm validate` green: `stylua --check` · `luacheck` (0 warnings) · `busted` (all specs pass)
    across `badger-arena` and `wow-mock`.
  - `pnpm nx run badger-arena:build` documented as the path to an installable build (needs `curl`).
  - The house style, engineering principles, and working agreement are captured under `docs/` +
    `CLAUDE.md`; project-local Claude drivers seeded in `.claude/skills/`.
- **Context / constraints:** scaffolded by the adapted `scaffold-project` wizard. De-pinned — versions
  resolved to current at scaffold time. Luacheck/Busted bound to LuaJIT (Lua 5.1) to match the WoW
  runtime (host Lua 5.5 is too new for those rocks). The `.toc` `Interface` is set to `20504` and must
  be confirmed against the live Anniversary client (`/run print(select(4, GetBuildInfo()))`).
  **Retro-logged:** the scaffold ran as one unit; this WO documents it and, per the birth exception,
  the WO file lands via the scaffold PR rather than pre-existing on `main`.
- **Out of scope:** any product features (real unit frames, DR/trinket tracking UI) — this WO is the
  foundation only. No company-infra registration, no ports/Notion, no web/security layer (N/A to a
  game addon).
- **Behavior delta:** ADDED — the whole baseline (monorepo, first addon skeleton, gate, docs/process).

**Phase 1 — Workspace + toolchain**
1. [x] Rename `arena-pro` → `badger-addons`; git init on `main`; wire the GitHub remote (ssh).
2. [x] Nx workspace (`nx.json`, `package.json`, pnpm) orchestrating Lua tools; shared `stylua.toml`,
       `.luacheckrc`, `.busted`; dotfiles.
3. [x] Install StyLua + Luacheck + Busted (Luacheck/Busted on LuaJIT/5.1).

**Phase 2 — First addon + test harness**
1. [x] `tools/wow-mock` — shared Busted stand-in for the WoW client + `load()` (addonName, ns) contract.
2. [x] `projects/badger-arena` — `.toc`, `.pkgmeta`, Ace3 bootstrap (`core.lua`, `config/config.lua`),
       `Locales/enUS.lua`, pure `util/dr-category.lua`, event module `modules/arena-detect.lua`, and
       colocated `*_spec.lua` for both.
3. [x] Nx `project.json` targets (`format` / `format-check` / `lint` / `test` / `build`).

**Phase 3 — Quality floor + docs/process + Claude drivers**
1. [x] `pnpm validate` green (stylua · luacheck 0/0 · busted 12/12).
2. [x] CLAUDE.md · engineering-principles · decisions (`D-001`) · this WO · milestones (`M-001`) ·
       retrospective · architecture · CONTRIBUTING · README · LICENSE.
3. [x] Project-local skills (`house-style` · `docs-process` · `badger-addons`); pre-commit hook;
       GitHub Actions validate workflow + PR template.

- **Verification:** the acceptance criteria above, all green locally; CI runs the same gate on the PR.
  In-game load is confirmed manually on the live client (out of the automated gate's reach).
- **Constitution check:** Principles OK (the scaffold *is* the principles).
- **Decisions produced:** D-001-IJ (stack + conventions).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/1
- **Outcome:** scaffold complete and gate-green on branch `core/WO-001-IJ-scaffold`; PR opened for
  human merge. Flips to `Done` once the PR is merged and `main` is green.
