---
wo: WO-006-IJ
status: In progress      # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ             # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/10
decision: D-004-IJ       # D-0xx-II once a decision is produced, else ~
depends_on:
  - CLAUDE.md
  - docs/workorders.md
  - docs/engineering-principles.md
related:
  - docs/decisions.md
  - docs/architecture.md
---

# WO-006-IJ — Make the monorepo honestly multi-flavor (framing + lint) and record the standard

- **Created / Updated:** 2026-07-24
- **Objective:** the repo assumes a single flavor ("TBC Anniversary") repo-wide, but it targets
  **multiple WoW client flavors** — TBC Anniversary (2.5.x) *and* Classic Era **Hardcore** (Vanilla
  1.15.x), possibly one addon for both. This WO makes that honest at the **framing + lint** level and
  **records the flavor-targeting standard (D-004)** — while deliberately **deferring the per-flavor
  build/mock machinery** until the first non-TBC addon actually exists. `badger-arena` stays TBC-only.
- **Scope decision (why this shape):** research (web-verified) found exactly one *latent correctness
  bug* — `.luacheckrc` scopes the TBC arena APIs monorepo-wide, so a future Vanilla addon calling
  `GetArenaOpponentSpec` would lint clean. Everything else (flavor-aware mock, split/multi-Interface
  `.toc`, packager `-S`) is machinery with **no consumer yet**. Per §1.4/§1.1 we fix the bug + set the
  framing now and defer the rest, capturing its design in D-004 so it's ready when needed. **(Human
  elected to also include the small, non-breaking flavor-aware `wow-mock` now — it unblocks
  hardcore-addon specs immediately; split `.toc` + packager `-S` stay deferred.)**
- **Key facts (from research, confirm live with `/dump select(4, GetBuildInfo())`):**
  - Flavors: **TBC** = Interface `20504`, suffix `_TBC.toc`, `WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC` (5).
    **Vanilla/Era (incl. Hardcore)** = Interface ~`11507`, suffix `_Vanilla.toc`, `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` (2).
  - **Hardcore is NOT a distinct project id** — it reports `WOW_PROJECT_CLASSIC`; detect it via game-state
    (`C_GameRules.IsHardcoreActive()`), not the flavor constant.
  - Arenas are **TBC-only** — Classic Era has none. So `badger-arena` is inherently TBC-only.
  - Two targeting models: **Model 1** = one flavor per Nx project (today's reality, recommended default);
    **Model 2** = one addon → multiple flavors (split `_Suffix.toc` files or a single multi-`## Interface`
    TOC + packager `-S`). Guard flavor-divergent code with `WOW_PROJECT_ID`; probe APIs with
    `type(fn) == "function"`.
- **Acceptance criteria:**
  - `.luacheckrc`: the four TBC arena globals + `BadgerArenaDB` (SavedVariables) are **scoped to
    `projects/badger-arena/**`** (a `files[...]` override), out of the flat monorepo tables; the header
    is reworded (base = flavor-neutral sandbox, each project selects its flavor). A TBC arena API
    referenced *outside* badger-arena would fail luacheck (W113). `pnpm validate` green.
  - `projects/badger-arena/project.json`: a declarative **flavor tag** (e.g. `"flavor:tbc"`) as the
    single source of truth for lint scoping / future build logic.
  - `tools/wow-mock`: `install()` gains an optional `{ flavor }` (default `"tbc"`, so no existing spec
    breaks); it stubs `WOW_PROJECT_ID` + the `WOW_PROJECT_*` constants and installs the arena surface
    **only** for TBC; a new `init_spec.lua` case asserts the `vanilla` surface (`IsActiveBattlefieldArena`
    absent, `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC`). `pnpm validate` green.
  - Docs broadened from single-flavor: `CLAUDE.md` (the "TBC Anniversary" framing),
    `engineering-principles.md`, `architecture.md` (a flavor-targeting bullet + the "future WOs" note);
    **D-004** recorded (multi-flavor stance · the two models · `WOW_PROJECT_ID` guarding · the deferral);
    `decisions.md` Current-state updated and **Next id → D-005**.
  - `badger-arena` stays **Model 1 / TBC-only**: `BadgerArena.toc` `Interface 20504` unchanged.
- **Out of scope — deferred to a future WO, triggered by the first both-flavor addon** (design captured
  in D-004 so it's ready): **split / multi-`## Interface` `.toc`** files, the packager **`-S`** flag, and
  the mock `load()` addon-name arg. `.pkgmeta` needs no flavor change. *(The flavor-aware `wow-mock` is
  now **in scope** — see Phase 3.)*
- **Behavior delta:** none in-game — lint scoping, project metadata, and docs only; `badger-arena`
  ships identically.

**Phase 1 — Lint correctness (the real fix)**
1. [ ] Move the TBC arena `read_globals` + `BadgerArenaDB` into `files["projects/badger-arena/**"]`
       overrides; reword the header. Verify `pnpm validate` green and that a TBC API outside
       badger-arena is now rejected.

**Phase 2 — Declarative flavor**
1. [ ] Add a `flavor:tbc` tag to `projects/badger-arena/project.json`.

**Phase 3 — Flavor-aware mock**
1. [ ] `tools/wow-mock/init.lua`: add a `FLAVORS` table + `install(opts)` with `opts.flavor` (default
       `tbc`); stub `WOW_PROJECT_ID` + `WOW_PROJECT_*`; gate the arena getters behind TBC. Add a
       `vanilla`-surface case to `init_spec.lua`; note `install({ flavor })` in the badger-addons skill.

**Phase 4 — Framing + decision**
1. [ ] Broaden `CLAUDE.md` / `engineering-principles.md` / `architecture.md`; record **D-004**; update
       `decisions.md` Current-state + Next id → D-005.

- **Verification:** `pnpm validate` green; a temporary `luacheck` probe confirms the arena scoping
  rejects a TBC API outside badger-arena; PR opened for human merge.
- **Constitution check:** aligns with §1.4 (simplest thing that fits) and §1.1 (promote when a second
  consumer is real, not speculatively) — fix the latent bug + set the framing now, defer speculative
  infra; the deferred design is recorded in D-004, not lost.
- **Decisions produced:** D-004-IJ (per-project flavor-targeting standard) — recorded in Phase 3.
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/10
- **Outcome:** implemented on `feature/WO-006-IJ-multiflavor`. `.luacheckrc` scopes the TBC arena APIs +
  `BadgerArenaDB` to badger-arena (and the mock) — proven: a TBC arena API is rejected (W113) outside
  badger-arena, accepted inside. `project.json` gains `flavor:tbc`; `tools/wow-mock` is flavor-aware
  (`install({ flavor })`, tbc default, + `WOW_PROJECT_*` stubs + a vanilla-surface spec). Docs broadened
  (CLAUDE.md / principles / architecture / badger-addons skill); **D-004** recorded; Next id → D-005.
  Gate green: stylua · luacheck 0/0 · busted 29/0. No in-game behavior change (Model 1, TBC-only
  `badger-arena` unchanged). PR #10 opened for human merge. Flips to `Done` once merged and `main` green.
