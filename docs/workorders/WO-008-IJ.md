---
wo: WO-008-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - CLAUDE.md
  - docs/architecture.md
related:
  - docs/decisions.md
  - docs/reference/warrior-ttk-cooldowns.md
  - projects/badger-arena/BadgerArena.toc
---

# WO-008-IJ — Scaffold `badger-ttk` (Vanilla/Era, Model 1) — the empty vessel

- **Created / Updated:** 2026-07-25
- **Objective:** stand up a new, loadable **`badger-ttk`** addon project — the repo's **first Vanilla
  (Classic Era 1.15) addon** — with nothing functional yet: `.toc`, flavor tag, scoped lint, `.pkgmeta`
  embeds, an Ace3 bootstrap with the AceDB **profile + global** namespaces, and a **skeleton config
  window** that opens. This is the plumbing the config WO (WO-009) and every functionality WO attach to.
  Child #1 of the WO-007 epic; **config-before-functionality** means this is the only thing ahead of config.
- **Acceptance criteria:**
  - **Project** `projects/badger-ttk/` (addon folder/TOC name `BadgerTTK`) with an Nx `project.json`
    carrying a **`flavor:vanilla`** tag and the standard targets (`format-check`, `lint`, `test`, `build`),
    matching `badger-arena`'s shape.
  - **`.toc`** `BadgerTTK.toc`: `## Interface: 11507` *(confirm live with `/run print((select(4,GetBuildInfo())))` on the Anniversary/Era client)*,
    Title "Badger TTK", Notes, Author, `## Version: 0.1.0`, `## SavedVariables: BadgerTTKDB`; load order =
    Libs → Locales → (src util/modules later) → `core.lua` → `config/config.lua`.
  - **Flavor discipline (D-004):** a scoped **`.luacheckrc`** overlay `files["projects/badger-ttk/**"]`
    declaring `BadgerTTKDB` (+ any Vanilla globals the bootstrap uses); **no TBC APIs**. A TBC-only API
    referenced here would fail luacheck.
  - **`.pkgmeta`**: externals — LibStub, CallbackHandler-1.0, AceAddon/AceEvent/AceConsole/AceDB/AceConfig/
    AceGUI/AceLocale-3.0, **LibSharedMedia-3.0**, **AceDBOptions-3.0**; `ignore: **/*_spec.lua`;
    `BadgerConfigUI-1.0` injected by `tools/build.sh` (opt-in `.toc` line), not a URL external.
    *(LibSerialize/LibDeflate reserved for v1.1 import/export — not embedded yet.)*
  - **`core.lua`** — `local ADDON_NAME, ns = ...`; `NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")`;
    AceDB with a **`profile`** defaults table (empty/skeleton) **and** a **`global`** namespace reserved for
    kill-history (per WO-007's `db.global` seam); a slash command (`/bttk`, `/badgerttk`) that opens the config.
  - **`config/config.lua`** — registers a **skeleton** options table through
    `LibStub("BadgerConfigUI-1.0"):Register(ADDON_NAME, …)` with a single **General** node (name/version
    blurb) + the `AceDBOptions-3.0` **Profiles** node; opens/closes cleanly. (The real tree is WO-009.)
  - **`Locales/enUS.lua`** — AceLocale base locale stub.
  - **Gate:** `pnpm validate` green (StyLua · Luacheck 0/0 · Busted); `pnpm nx run badger-ttk:build`
    produces `projects/badger-ttk/.release/BadgerTTK`.
  - **In-game (human, deferred like WO-004):** `/reload` loads **BadgerTTK**; the slash opens the skeleton
    config window; no errors.
- **Context / constraints:** dev plumbing only — **no TTK/ability/display logic**. Mirror `badger-arena`'s
  project shape and the house style (one module per file, everything on `ns`, no `_G` leaks, kebab-case,
  `.toc` load order). Single-flavor **Model 1** (Vanilla) — the deferred both-flavor build machinery is not touched.
- **Out of scope:** the config tree contents (WO-009); the engine/estimator, display/skin, show-gating,
  ability model (their own WOs); LibSerialize/LibDeflate; any TTK behavior.
- **Behavior delta:** ADDED — a new addon that loads and opens an (empty) skeleton config window; no
  time-to-kill behavior yet.

**Phase 1 — Project skeleton**
1. [ ] `projects/badger-ttk/project.json` (targets + `flavor:vanilla` tag); `BadgerTTK.toc` (Interface/
       metadata/load order); scoped `.luacheckrc` overlay (`BadgerTTKDB` + Vanilla globals); `.pkgmeta`
       (externals + spec ignore + BadgerConfigUI note).

**Phase 2 — Ace3 bootstrap**
1. [ ] `core.lua` — `NewAddon` + AceDB (`profile` defaults + reserved `global` history namespace) + slash
       command; `Locales/enUS.lua` AceLocale stub.

**Phase 3 — Config skeleton + embeds**
1. [ ] `config/config.lua` — BadgerConfigUI registration with a **General** node + `AceDBOptions` Profiles
       node; confirm LibSharedMedia-3.0 + AceDBOptions-3.0 are in `.pkgmeta`/`.toc`.

**Phase 4 — Verify**
1. [ ] `pnpm validate` green; `badger-ttk:build` packages; record the D-005… decision bundle from WO-007
       into `docs/decisions.md` (render model · flavor · estimator · ability model · skin system · config)
       and update `architecture.md` with the badger-ttk shape. In-game `/reload` deferred to the human.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; in-game
  `/reload` confirmation is the human's (the gate can't load the addon in WoW).
- **Constitution check:** Principles OK — additive first-Vanilla-addon plumbing; house style + `.toc`
  order honored; flavor discipline per D-004 (flavor tag · scoped luacheckrc · mock `vanilla` surface);
  no `_G` leaks; simplest-thing-that-fits (skeleton config, real tree deferred to WO-009).
- **Decisions produced:** records the **D-005…** bundle from WO-007 into `docs/decisions.md` on Done
  (no new choices — implements WO-007's accepted design).
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
