---
wo: WO-004-IJ
status: Proposed         # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ             # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                    # pull-request URL once opened, else ~
decision: ~              # D-0xx-II once a decision is produced, else ~
depends_on:
  - CLAUDE.md
  - docs/workorders.md
  - docs/engineering-principles.md
related:
  - docs/decisions.md
  - docs/architecture.md
---

# WO-004-IJ — Normalized Ace3 config window (shared embeddable module)

- **Created / Updated:** 2026-07-24
- **Objective:** establish a **unified config-window standard** for all Badger addons: a shared,
  embeddable module that opens a standalone config window with a consistent look — and retrofit
  `badger-arena` onto it as the proof — so every addon's options screen is laid out and branded the
  same way.
- **Design (locked choices):**
  - **Layout — native tree (Variant B).** Pure `AceConfigDialog-3.0` tree layout
    (`childGroups = "tree"`): full-height nav tree on the left, content pane on the right, with a
    **banner/header at the top of the content pane**. Spec: `assets/images/common-config-ui-layout.webp`
    is the original top-banner concept (Variant A); the build target is the native-tree variant (B).
  - **Home — shared embeddable LibStub library.** A single `BadgerConfigUI-1.0` library lives in the
    monorepo and is **embedded into each addon at build** (like the Ace libs), registered via LibStub
    so multiple addons dedupe on one copy. No runtime cross-addon dependency; no `_G` leaks beyond the
    idiomatic LibStub registration.
  - **Public API (proposed, to firm up in Phase 1):**
    `local BCUI = LibStub("BadgerConfigUI-1.0")` → `BCUI:Open(appName)` opens the normalized window
    for an already `AceConfig`-registered options table; the library applies the standard frame size,
    banner header, and status text.
- **Acceptance criteria:**
  - A `BadgerConfigUI-1.0` LibStub library exists in the repo, embeddable into any addon, with the
    pure/assemblable logic covered by colocated `*_spec.lua` against `wow-mock`.
  - `badger-arena` embeds it; opening its config shows the **Variant-B** window — full-height left
    tree + content pane + banner header — with the existing `enabled` / `showDR` toggles under a group.
  - `pnpm validate` green (stylua · luacheck 0/0 · busted). In-game load confirmed via `/reload`
    (out of the gate's reach — the gate proves lint/format/tests, not that WoW renders the frame).
  - Docs land with the code: **D-003** recorded; an engineering-principles / house-style rule that
    "config windows use `BadgerConfigUI`"; `docs/architecture.md` updated.
- **Context / constraints:** UI/frame code can't be unit-tested off-client — keep the **pure logic**
  (options-tree assembly, defaults, banner text) testable and the frame code thin, per the engineering
  principles. `.toc` load order must place the lib before addon code.
- **Out of scope:** other addons (only `badger-arena` is retrofit as proof); real banner artwork
  (Phase 1 uses a branded text/placeholder header); expanding the option schema beyond today's two
  toggles.
- **Behavior delta:** MODIFIED — `badger-arena` options move from the embedded Blizzard panel to the
  normalized standalone window.

**Phase 1 — Shared library `BadgerConfigUI-1.0`**
1. [ ] Create the LibStub library (frame sizing, native tree via AceConfigDialog, content-pane banner
       header, status text) with an API-light surface; pure helpers colocated-spec'd against wow-mock.

**Phase 2 — Embed + retrofit `badger-arena`**
1. [ ] Bundle the lib into the addon at build (`.pkgmeta` / `tools/build.sh` + `.toc` load order).
2. [ ] Rework `src/config/config.lua` to open the normalized window via `BadgerConfigUI:Open`.

**Phase 3 — Docs**
1. [ ] Record **D-003**; add the house-style / engineering-principles rule; update `docs/architecture.md`.

- **Verification:** `pnpm validate` green; manual `/reload` shows the Variant-B window with the banner
  header and the two toggles under a tree node; PR opened for human merge.
- **Constitution check:** aligns with house style (module-per-file, everything on `ns`, no `_G` leaks
  beyond the idiomatic LibStub registration; API-light testable logic). Frame code is the untestable
  edge — kept thin, verified in-client.
- **Decisions produced:** D-003-IJ (config-window standard) — recorded in Phase 3.
- **MR:** — (added once the PR is opened)
- **Outcome:** — (running notes; final result on completion)

### Open questions — resolve before `Accepted`
- **[NEEDS CLARIFICATION: banner content]** — Phase 1 default is a Badger-branded **text/color header**
  placeholder (real art later). OK, or do you have banner artwork in mind now?
- **[NEEDS CLARIFICATION: entry points]** — default is a **slash command** (`/badgerarena`,
  `/ba`) opening the window **plus** a small Blizzard Interface-Options stub whose button opens it.
  Keep both, or slash-only?
- **[NEEDS CLARIFICATION: embed mechanism]** — the lib is monorepo-internal, so `.pkgmeta` externals
  (which fetch from remote repos) don't fit directly; default is to have **`tools/build.sh` copy the
  shared lib into the addon's `Libs/` at package time**. Confirm that's the mechanism you want.
