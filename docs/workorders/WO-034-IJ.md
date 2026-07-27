---
wo: WO-034-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/37
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-029-IJ.md
  - docs/workorders/WO-033-IJ.md
related:
  - libs/BadgerConfigUI-1.0/options-tree.lua
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-arena/src/config/config.lua
---

# WO-034-IJ — a persistent global header in BadgerConfigUI, with a Show-preview control

- **Created / Updated:** 2026-07-27
- **Objective — from the human:** a single **global header area above the main area**, replacing the
  identical per-node banner (title/subtitle) that's currently injected into *every* page — and put a
  **Show preview** checkbox in that header (kept in the Simulation node too).
- **Approach (chosen after a read-only feasibility study — the low-risk one, no frame surgery):**
  AceConfigDialog renders a group's **root-level** (non-subgroup) args **above** the left-nav tree, on
  every page, by its own design. So the header becomes a few **root-level AceConfig args** rather than a
  custom frame band. Crucially, a header **toggle** placed this way is a native Ace control, so it stays in
  two-way sync with the Simulation-node toggle **for free**: both bind the same `db.profile.simStatic`, and
  any control change forces a full frame rebuild that re-reads every `get()`. No manual state wiring, no
  pooled-frame mutation, no re-anchoring.
- **Design notes:**
  - **`options-tree.lua` (`normalize`):** STOP injecting `badgerBanner` / `badgerBannerSub` /
    `badgerBannerSpacer` into each child page. Instead add **root-level** args to the normalized table —
    `badgerHeaderTitle` (large description), `badgerHeaderSub` (medium description), and each header
    **control** — at low orders so they render above the tree. Stays pure (string/table only; it places
    control tables, never calls their get/set).
  - **`BadgerConfigUI-1.0.lua` (`lib:Register`):** accept `opts.header = { title, subtitle, image…,
    controls = { { type="toggle", name, desc, get, set }, … } }`. Keep **`opts.banner` as a back-compat
    alias** (map to `header`; `header` wins if both). `MINOR` 5 → 6.
  - **`config.lua` (badger-ttk):** pass `opts.header` with the title/subtitle + a **Show preview** toggle
    whose get/set are the SAME binding as the Simulation node's `static` (set `simStatic`, clear
    `simPlaying` when off, `Display.showPreview`). Keep the Simulation-node toggle as-is.
  - **badger-arena:** it passes `opts.banner = {title, subtitle}` → via the alias its title/subtitle render
    in the same global header (no controls). Its window swaps the per-page banner for the one global header
    — same content, so the intent is preserved; verify it in-game.
- **Acceptance criteria:**
  - One header (title + subtitle) sits **above the tree** and stays put on **every** node; the per-page
    banner is gone (no duplicate header inside each page).
  - A **Show preview** checkbox in the header toggles the preview; ticking it in the header updates the
    Simulation-node toggle and vice-versa (same state).
  - badger-arena's window still shows its title/subtitle header (via the `banner` alias) and is otherwise
    unchanged.
  - `pnpm validate` green — `options-tree_spec` updated (root-level header injection replaces the per-page
    banner assertions); the toggle sync + rendering are the in-game edge.
- **Out of scope:** contextual/per-node header content (the header is global + static); arbitrary control
  types beyond `toggle` now (the `controls` list is the seam for more later); restyling the header art.
- **Behavior delta:** MODIFIED (in-game) — one persistent header replaces the per-page banner across every
  Badger addon; badger-ttk's header carries a Show-preview toggle.
- **Risk / fallback:** if root-level args don't render above the tree as expected on this Ace build, fall
  back to the documented frame approach (re-anchor `f.content` down by a header height + a raw header frame,
  re-applied via the existing `polishTree`/`chainClose` hooks). Confirm the root-level render in-game first.

**Phase 1 — Header API + root-level render (shared lib)**
1. [x] `options-tree.lua`: root-level header args (title/subtitle + controls + foot spacer) instead of the
       per-page banner; `BadgerConfigUI-1.0.lua`: `opts.header` (+`banner` alias), `MINOR` 5→6.
       `options-tree_spec` rewritten (root-level header; controls placed+copied; alias; non-mutating).
       Approach confirmed against the vendored Ace source (`FeedGroup`→`FeedOptions` feeds root args above
       the tree, skips non-inline subgroups).

**Phase 2 — Consumers**
1. [x] `badger-ttk config.lua`: shared `showPreviewSetter` for the Simulation node AND a header Show-preview
       toggle bound to the same `simStatic`; `Register` passes `opts.header`. badger-arena rides the `banner`
       alias (title/subtitle, no controls).

**Phase 3 — Verify**
1. [x] `pnpm validate` green (85/21/9/4 successes, 0 failures; luacheck 0/0). badger-ttk `.toc` → **0.9.17**;
       `.release` rebuilt with the re-embedded BadgerConfigUI-1.0 (MINOR 6); parity + load-graph verified.
2. [ ] **In-game (human, required):** one header above the tree on every page (both addons); the header
       Show-preview toggle works and stays in sync with the Simulation-node toggle.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge; in-game re-test.
- **Constitution check:** Principles OK — `options-tree` stays pure/spec-tested; the header controls +
  render are the Ace edge; shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** — (candidate: the config header is one global, root-level element; consumers
  declare it via `opts.header`, `opts.banner` kept as an alias.)
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/37 (open, awaiting human merge)
- **Outcome:** Branch `feature/WO-034-IJ-global-header`, PR #37. `normalize` now injects ONE root-level
  header (title/subtitle + controls + spacer) — which AceConfigDialog renders above the tree — instead of
  the per-page banner; `opts.header` API + `opts.banner` alias; lib MINOR 5→6. badger-ttk gains a header
  Show-preview toggle sharing `showPreviewSetter` with the Simulation node (native two-way sync). Approach
  verified against the vendored Ace source. `.toc` → 0.9.17; gate green; `.release` rebuilt + verified.
  Note: badger-arena embeds its own lib copy — a rebuild ships MINOR 6 (LibStub uses the highest loaded).
  Awaiting human merge + in-game re-test.
