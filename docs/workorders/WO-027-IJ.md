---
wo: WO-027-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/30
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-025-IJ.md
related:
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/BadgerTTK.toc
  - libs/BadgerConfigUI-1.0/options-tree.lua
  - libs/BadgerConfigUI-1.0/BadgerConfigUI-1.0.lua
---

# WO-027-IJ — polish batch: config hints · Warrior node · category · smaller subtitle · smoother bars · start-TTK

- **Created / Updated:** 2026-07-26
- **Objective — a batch of polish/fixes the human asked to fold together (one build, v0.9.10):**
  1. **Config hints** — **every changeable option** (toggle/range/select/colour/execute) gets a helpful
     `desc` tooltip. Audit: **30 of 51** static options + the generated per-ability / per-encounter toggles
     have none. Re-run the audit → **0 missing**.
  2. **Warrior node** — the **Abilities** node lists warrior abilities directly; nest them under a
     **"Warrior"** sub-node (so more classes can slot in beside it later).
  3. **Flavor text** — the `.toc` **Notes** say "Era / Anniversary / Hardcore"; the addon targets **Era +
     Hardcore** only. Drop "Anniversary" (Notes + the internal Interface-check comment).
  4. **Category** — give the addon an AddOn-list category: `## Category: Combat` (matches the existing
     `X-Category`).
  5. **Smaller subtitle** — the config banner renders title + subtitle in **one `fontSize="large"`**
     description, so they're the same size. Split into two descriptions — **title large, subtitle medium** —
     in `BadgerConfigUI` (shared lib; `MINOR` 2 → 3; all Badger addons benefit).
  6. **Smoother bars** — the status bars `SetValue` directly, so the live 0.15s update cadence (and any
     step) shows as **jerky** jumps. Add lightweight **per-frame value smoothing** (ease each bar's fill
     toward its target) so bars glide regardless of update rate.
  7. **Start-TTK fix** — kill history sometimes shows an **insanely large start-TTK** (~1 min / ~30s for
     ≤5s kills) that corrects. Record the kill rate from **first-damage → death** (not target acquisition),
     so idle-before-combat stops inflating the prior.
- **Design notes:**
  - **Subtitle (5):** `OptionsTree.bannerArg` returns the title description (large, keeps the image);
    `buildTree` also injects a **subtitle description** (`fontSize="medium"`, order just after). Pure module
    → covered by `options-tree_spec`.
  - **Smoothing (6):** `render` stores each bar's **target** fill; a persistent always-shown ticker eases the
    displayed value toward it each frame (`v += (target − v)·min(1, elapsed·SPEED)`). Decouples the visible
    motion from the 0.15s live tick and the sim's per-frame updates. The eased fill is edge; the geometry is
    unchanged.
  - **Warrior node (2):** `buildAbilities` wraps the current toggles/offsets in a `Warrior = { type="group",
    … }` sub-node under `Abilities` (Abilities becomes a container of class nodes).
  - **Start-TTK (7):** track `prevHealth`; set `fightStartT`/`fightStartH` at the first health drop, record
    on death from that window (skip zero-duration). Reset per target. (Human should **Clear history** once to
    drop the old inflated records.)
- **Acceptance criteria:**
  - Audit reports **0 changeable options without `desc`**; hints are concise and accurate.
  - Abilities shows a **Warrior** sub-node containing the warrior list.
  - `.toc` Notes read "Era / Hardcore" (no Anniversary); the addon shows a **Combat** category.
  - The config banner **subtitle is visibly smaller** than the title.
  - The bars **glide smoothly** (no visible 0.15s stepping) in both live and sim.
  - After the start-TTK fix + a Clear history, a kill after idling on the mob records a **sensible** rate.
  - `pnpm validate` green — `options-tree` change spec-tested; config/toc/display/driver edits don't touch the
    pure history/estimator/layout specs.
- **Out of scope:** restructuring the config tree beyond the Warrior node; non-warrior ability tables;
  animating bar *position* (only the fill is smoothed); the health→time curve.
- **Behavior delta:** MODIFIED (in-game) — every option has a hint; Abilities gains a Warrior node; flavor
  text + category corrected; banner subtitle smaller; bars smoother; start-TTK sensible.

**Phase 1 — Config: hints + Warrior node**
1. [x] `config.lua`: add a `desc` to every changeable option lacking one (Behavior / Skin / Display /
       Simulation + the generated per-ability & per-encounter toggles). Re-run the audit → 0 missing.
2. [x] `config.lua` `buildAbilities`: nest the warrior entries under a **Warrior** group inside Abilities.

**Phase 2 — TOC: flavor + category**
1. [x] `BadgerTTK.toc`: Notes → "WoW Classic (Era / Hardcore)"; drop Anniversary from the Interface-check
       comment; add `## Category: Combat`.

**Phase 3 — BadgerConfigUI: smaller subtitle (shared lib)**
1. [x] `options-tree.lua`: title (large) + subtitle (medium) as separate descriptions; `BadgerConfigUI-1.0`
       `MINOR` 2 → 3; update `options-tree_spec.lua`.

**Phase 4 — Display: smoother bars**
1. [x] `display.lua`: store each bar's target fill; ease displayed values toward target on a persistent
       always-shown ticker.

**Phase 5 — Driver: start-TTK window**
1. [x] `driver.lua` `update()`: record from first-damage → death (track `prevHealth`; skip zero-duration).

**Phase 6 — Verify**
1. [x] `pnpm validate` green; audit 0 missing `desc`. Bump `.toc` `## Version` → **0.9.10**, rebuild
       `.release` (re-embedding the updated BadgerConfigUI).
2. [ ] **In-game (human, required):** hints on every option; Warrior node; Combat category; smaller subtitle;
       smooth bars; **Clear history** then a post-idle kill gives a sensible start-TTK.

- **Verification:** the acceptance criteria; `pnpm validate` green; the audit; PR for human merge; in-game.
- **Constitution check:** Principles OK — pure `options-tree` change spec-tested; config copy + toc metadata +
  display smoothing + driver window are edge/data; the shared lib bumps `MINOR`; no `_G` leaks.
- **Decisions produced:** —
- **MR:** [PR #30](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/30)
- **Outcome:** Implemented all 6 parts; `pnpm validate` green (79 badger-ttk + 18 BadgerConfigUI specs; luacheck 0/0); config audit 0 options without a hint. BadgerConfigUI MINOR 2->3. `.toc` -> v0.9.10 + `## Category: Combat`. **PR #30 merged**; rebuilt `.release/BadgerTTK` at v0.9.10 (load graph 74/0, updated BadgerConfigUI embedded, source parity clean). **In progress** pending the human's in-game re-test.
