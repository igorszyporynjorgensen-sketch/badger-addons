---
wo: WO-005-IJ
status: In progress      # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ             # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/9
decision: ~              # D-0xx-II once a decision is produced, else ~
depends_on:
  - CLAUDE.md
  - docs/workorders.md
related:
  - .luacheckrc
---

# WO-005-IJ — `.luarc.json` so the lua-language-server LSP understands the repo

- **Created / Updated:** 2026-07-24
- **Objective:** add a checked-in `.luarc.json` (+ a minimal busted/luassert type stub) so the
  editor's `lua-language-server` (the just-enabled `lua-lsp` plugin) stops emitting false
  "undefined global/field" diagnostics on addon and spec files — it should know the **Lua 5.1**
  runtime, the **WoW API globals** (mirrored from `.luacheckrc`), and **busted/luassert**
  (`describe`/`it`/`assert.*`).
- **Acceptance criteria:**
  - Given a WoW-API-using source file (e.g. `core.lua`), When the LSP checks it, Then `CreateFrame`,
    `LibStub`, etc. are **not** flagged as undefined globals.
  - Given a spec file, When the LSP checks it, Then `describe`/`it`/`assert.same`/`assert.is_truthy`
    are recognized (no undefined global/field).
  - Given `lua-language-server --check` run on a representative addon file and a spec file, Then it
    reports **0 diagnostics** (or only genuine ones), verified before/after.
  - Given the quality gate, When `pnpm validate` runs, Then it is **unaffected** and green — the LSP
    config touches neither luacheck, stylua, nor busted, and the `types/` stub is outside every Nx
    project so it is not linted/tested/shipped.
- **Context / constraints:** dev-tooling only; nothing ships and the gate is untouched. WoW globals
  are the single source of truth in `.luacheckrc` `read_globals` — mirror them so the two never drift
  far (a comment in `.luarc.json` notes the mirror). `types/` holds only `---@meta` definitions.
- **Out of scope:** full WoW API signatures (silencing via globals is enough); any addon behavior; the
  gate; per-file `---@diagnostic` annotations.
- **Behavior delta:** none — editor experience only.

**Phase 1 — Config + stubs**
1. [ ] `.luarc.json` — `runtime.version` Lua 5.1; `diagnostics.globals` = WoW read_globals (from
       `.luacheckrc`) + the `bit`/WoW namespace; `workspace.library` → `types/`.
2. [ ] `types/busted.lua` — `---@meta` stub for the busted functions and the luassert `assert.*` methods.

**Phase 2 — Verify**
1. [ ] `lua-language-server --check` on `projects/badger-arena/src/core.lua` and a `*_spec.lua`:
       diagnostics drop to 0 (before/after captured).
2. [ ] `pnpm validate` still green (gate unaffected).

- **Verification:** the acceptance criteria above; PR opened for human merge.
- **Constitution check:** Principles OK — additive dev-tooling, no `_G` leaks (meta files are
  definitions, not runtime code), no shipped/gate impact.
- **Decisions produced:** —
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/9
- **Outcome:** `.luarc.json` (Lua 5.1 · WoW globals mirrored from `.luacheckrc` · `types/` library ·
  ignore dirs) + `types/busted.lua` `---@meta` stub added on `chore/WO-005-IJ-luarc`. Verified with
  `lua-language-server --check`: **37 problems → 0** across first-party Lua. `pnpm validate` unaffected
  and green. PR #9 opened for human merge. Flips to `Done` once merged and `main` green.
