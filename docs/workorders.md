---
title: Work Orders
type: work-orders
depends_on:
  - CLAUDE.md
related:
  - docs/decisions.md
  - docs/workorders/WO-001-IJ.md
  - .claude/skills/docs-process/SKILL.md
---

# Work Orders

Every job in **Badger Addons** runs as a *work order*: a complex task broken into **phases → steps**,
written down and **presented for acceptance before any state-changing action**, then tracked to
completion. A work order *is* the plan. Per [../CLAUDE.md](../CLAUDE.md), work outside `docs/` only
begins once the human has accepted the work order.

## How to use this file

- A job becomes a **Work Order (`WO-0xx-II`)** — **its own file** `docs/workorders/WO-0xx-II.md` —
  *before* execution starts. One file per WO so parallel authors never collide on a shared log.
- **Id scheme — author-initials suffix.** Ids carry uppercase author initials on one shared,
  increasing number (`WO-099-IJ` vs `WO-099-RS`). Ids are stable and never reused.
- **WO ⇒ then branch.** A `WO-0xx`-named code branch may only exist once its WO file is on `main` and
  `Accepted`. On any such branch with no entry: *stop*, reconstruct it (marked retro-logged), present
  it, then continue.
- **Lifecycle:** `Proposed` → `Accepted` → `In progress` → `Done` (or `Blocked` / `Cancelled`).
- Keep **phases small and independently verifiable**. Tick steps (`[x]`) as they complete.
- **Before `Accepted`:** resolve every `[NEEDS CLARIFICATION]` marker, and confirm the WO doesn't
  violate the engineering principles (record the **Constitution check**).
- If scope changes mid-flight, update the WO and **re-present material changes** for acceptance.
- **Link the PR** as an `mr:` value once one is opened, so branch ⇒ commits ⇒ PR ⇒ WO ⇒ decisions
  stay one click apart.

## Git convention — work-order files live-mirror to `main`

- **Work-order files push to `main` immediately.** Every change to a `docs/workorders/*.md` file — a
  new draft, a body edit, a `status` change — is committed straight to `main` and pushed the moment
  it's made (no branch, no PR), for a real-time edit ↔ git loop.
- **Acceptance is the `status` field, not a PR.** A draft lands as `Proposed`; the human accepts by it
  becoming `Accepted`. `assigned:` is auto-filled with the committer's initials (git email local-part,
  uppercased).
- **`Done` is tied to the PR.** `Proposed` / `Accepted` / `In progress` flow freely, but a WO reaches
  **`Done` only once its code PR is merged** and `pnpm validate` passes.
- **The *code* a WO drives still goes via branch + PR** — never push code to `main`:
  - **Branch prefixes** (enforced by `.githooks/pre-commit`): `<prefix>/<name>`, prefix ∈
    `feature core fix chore docs refactor hotfix release migrate`; `main`/`staging` exempt.
  - **Encode the WO id with initials:** `<prefix>/WO-0xx-II-<slug>`.
  - **One branch + one commit per code WO** (squash WIP). `main` stays green — **merging is human-only.**

## Template — new file `docs/workorders/WO-0xx-II.md`

Every WO opens with a **machine-readable YAML front-matter** block — the single home for `status`
(no body `Status:` bullet, so it can't drift). The human narrative follows.

```
---
wo: WO-0xx-II
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: II            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
---

# WO-0xx-II — <short title>
- **Created / Updated:** YYYY-MM-DD
- **Objective:** one or two sentences — what "done" looks like.
- **Acceptance criteria:** testable bullets (Given/When/Then).
- **Context / constraints:** relevant files, prerequisites, links. Tag unknowns `[NEEDS CLARIFICATION: …]`.
- **Out of scope:** what this WO deliberately will not touch.
- **Behavior delta:** ADDED / MODIFIED / REMOVED — what observable (in-game) behavior changes. Omit if none.

**Phase 1 — <name>**
1. [ ] <step>

- **Verification:** how we'll prove it works (commands + expected results, and any in-game check).
- **Constitution check:** Principles OK — or the exception + reason.
- **Decisions produced:** — (fill with D-0xx-II as they're made)
- **MR:** — (pull-request URL, added once one is opened)
- **Outcome:** — (running notes; final result on completion)
```

---

## Work order log
<!-- Newest on top. New WOs are their own files under docs/workorders/; this section is a thin index. -->

- **WO-021-IJ** — **UI polish**: (1) config left-nav — a small gap between each node's icon and name +
  vertical centring, via re-anchoring the AceGUI TreeGroup buttons in the shared `BadgerConfigUI` lib
  (guarded `hooksecurefunc`, no vendored-lib edits, so all Badger addons get it); (2) **right-align** the
  utility-bar text (badger-ttk). See `docs/workorders/WO-021-IJ.md`. Status: In progress — PR #24 opened.
- **WO-020-IJ** — `badger-ttk` media pickers show **visual previews**: embed `AceGUI-3.0-SharedMediaWidgets`
  and point the statusbar/font/border selects at the `LSM30_*` dialog controls, so the config dropdowns
  render a preview per entry instead of just names (see `docs/workorders/WO-020-IJ.md`). Status: Done — PR #23 merged; in-game approved.
- **WO-019-IJ** — `badger-ttk` **utility-bar polish**: give utility bars a draining **progress fill** (in
  lockstep with the TTK bar, steady segment + dim track), **sort** them longest-duration nearest the TTK
  bar, and make the per-bar **countdown off by default** (kept configurable). See
  `docs/workorders/WO-019-IJ.md`. Status: Done — PR #22 merged; in-game approved.
- **WO-018-IJ** — `badger-ttk` **simulated-preview fidelity**: make the dynamic sim a deterministic warrior
  demo to spec (50s TTK countdown; Death Wish @30s-left, Earthstrike @20s-left, only those two) so it shows
  standalone (no static needed); add utility-bar **names/timers**; and make "no bar wider than the TTK bar"
  a spec-tested `Layout` invariant (over-long abilities fill the full bar). Fixes the three v0.9.0 in-game
  bugs (see `docs/workorders/WO-018-IJ.md`). Status: Done — PR #21 merged; D-007 recorded; in-game confirmed.
- **WO-017-IJ** — `badger-ttk`: show the **build version** in the config window (single-sourced from the
  `.toc`, starts `0.9.0`, bumped every test build → `1.0.0` on human sign-off) **and** fix the preview bars
  still vanishing after ~1s — make the display the sole owner during preview (push an explicit suspend to
  the live driver at toggle time + backstop db guard) and run dynamic playback on a dedicated always-shown
  ticker frame, immune to the hidden-container `OnUpdate` stall (see `docs/workorders/WO-017-IJ.md`).
  Status: Done — PR #20 merged; in-game confirmed (version shows; preview persists).
- **WO-016-IJ** — `badger-ttk` fix (from the first in-game test): `.toc` Interface → 11509; the live
  driver yields while a sim preview is active so it stops clobbering/hiding it (see
  `docs/workorders/WO-016-IJ.md`). Status: Done — PR #19 merged; `.release` rebuilt.
- **WO-015-IJ** — `badger-ttk` live driver **(b)**: samples real `UnitHealth` + tracks auras/cooldowns
  → assembles the render-model → feeds the display in combat (gated by Behavior). Pure `assembleEntries`
  + `gate` helpers + the event/ticker edge. **Closes the v1 loop.** Child #7b of WO-007 (see
  `docs/workorders/WO-015-IJ.md`). Status: Done — PR #18 merged.
- **WO-014-IJ** — `badger-ttk` warrior ability model **(a)**: the static master table + pure
  availability/usability/active logic + the Abilities config node (full list · enable/disable · offset ·
  availability dim). Live driver is WO-015. Child #7 of WO-007 (see `docs/workorders/WO-014-IJ.md`).
  Status: Done — PR #17 merged.
- **WO-013-IJ** — `badger-ttk` skin engine **(b)**: an open data-only skin format + public
  `RegisterSkin` API + built-in Badger skin + LibSharedMedia font/texture/border pickers; the display
  renders a resolved look (skin + config overrides). Child #5b of WO-007 (see
  `docs/workorders/WO-013-IJ.md`). Status: Done — PR #16 merged.
- **WO-012-IJ** — `badger-ttk` display **(a)**: frames + a pure layout helper (render-model → pixel
  rects) + movable container (drag/scale), **sim-driven** (static preview + dynamic playback) — the
  first visible feature. Skin engine split to WO-013. Child #5a of WO-007 (see
  `docs/workorders/WO-012-IJ.md`). Status: Done — PR #15 merged.
- **WO-011-IJ** — `badger-ttk` simulation driver: feeds the engine a scripted fight (health curve +
  pop events + immune windows) → render model; ships the **static preview** as pure data. Dev harness
  for the display; no frames. Child #4 of WO-007 (see `docs/workorders/WO-011-IJ.md`). Status: Done — PR #14 merged.
- **WO-010-IJ** — `badger-ttk` pure fight-state engine + TTK estimator (spec-first): the API-light core
  (EWMA estimator · execute-correction · confidence · render-model geometry — pop-line comb, per-entry
  offset, coverage) unit-tested under the mock; no frames/behavior. First functionality WO; child #3 of
  WO-007 (see `docs/workorders/WO-010-IJ.md`). Status: Done — PR #13 merged.
- **WO-009-IJ** — `badger-ttk` config skeleton — the full options tree (framework + AceDB defaults +
  icons + the General/Behavior/Skin/Display/Estimator/Profiles nodes; Raids/Abilities/Simulation as
  placeholders for their feature WOs). No behavior yet. Child #2 of WO-007 (see
  `docs/workorders/WO-009-IJ.md`). Status: Done — PR #12 merged.
- **WO-008-IJ** — Scaffold `badger-ttk` (Vanilla/Era, Model 1) — the empty vessel: `.toc`, flavor tag,
  scoped lint, `.pkgmeta` embeds, Ace3 bootstrap (AceDB profile+global), skeleton config window. Child
  #1 of WO-007 (see `docs/workorders/WO-008-IJ.md`). Status: Done — PR #11 merged.
- **WO-007-IJ** — `badger-ttk` time-to-kill / optimal-cooldown-timing addon — **umbrella/epic** plan
  (design + child-WO breakdown; no code). Repo's first Classic-Era/Vanilla addon; skinnable UI, config
  before functionality (see `docs/workorders/WO-007-IJ.md`). Status: Accepted.
- **WO-006-IJ** — Make the monorepo honestly multi-flavor (framing + lint) and record the standard
  (D-004) + flavor-aware mock; defer split-TOC/packager machinery (see
  `docs/workorders/WO-006-IJ.md`). Status: Done.
- **WO-005-IJ** — `.luarc.json` so the lua-language-server LSP understands the repo (Lua 5.1 · WoW
  globals · busted) (see `docs/workorders/WO-005-IJ.md`). Status: Done.
- **WO-004-IJ** — Normalized Ace3 config window — shared embeddable `BadgerConfigUI` + retrofit
  `badger-arena` (see `docs/workorders/WO-004-IJ.md`). Status: In progress.
- **WO-003-IJ** — Git-ignore the personal `.claude/settings.local.json` (see
  `docs/workorders/WO-003-IJ.md`). Status: Done.
- **WO-002-IJ** — Add a top-level `assets/` folder for inspiration & references (see
  `docs/workorders/WO-002-IJ.md`). Status: Done.
- **WO-001-IJ** — Scaffold the project (see `docs/workorders/WO-001-IJ.md`). Status: Done.
