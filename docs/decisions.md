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

_As of 2026-07-25._

- **Scaffolded and verified green.** Nx (pnpm) monorepo orchestrating a Lua toolchain — StyLua ·
  Luacheck (LuaJIT/5.1) · Busted — behind one `pnpm validate` gate. Framework: Ace3. `pnpm validate`
  passes (stylua · luacheck 0/0 · busted green).
- **Layout.** `projects/badger-arena` (first addon — TBC, folder `BadgerArena`) · `projects/badger-ttk`
  (second addon — the repo's first **Vanilla / Classic Era** addon, folder `BadgerTTK`; scaffolded) · `tools/wow-mock`
  (shared Busted harness) · `tools/build.sh` (packager wrapper) · `libs/BadgerConfigUI-1.0` (shared
  **shipped** LibStub config-UI library, embedded into each addon's `Libs/` at build). No JavaScript app.
- **Config-window standard.** Every Badger addon registers, sizes, and opens its options through the
  shared `BadgerConfigUI-1.0` LibStub library — a native `AceConfigDialog` tree window + branded banner
  — never ad hoc per addon. Shipped shared libraries live under a top-level `libs/<Name-Major.Minor>/`
  (distinct from never-shipped `tools/`) and are embedded into `Libs/` by `tools/build.sh`, opt-in via
  each addon's `.toc` (see D-003-IJ).
- **Multi-flavor.** The repo targets multiple WoW Classic flavors — `badger-arena` → **TBC Anniversary**
  (2.5.x); addons may target **Classic Era / Hardcore** (Vanilla 1.15.x). Each project declares its
  flavor (`project.json` `flavor:*` tag · `.toc` `## Interface:` · a scoped `.luacheckrc` API overlay, so
  a Vanilla addon can't reference TBC-only APIs); runtime guards use `WOW_PROJECT_ID`; the shared mock is
  flavor-aware (`install({ flavor })`). Both-flavor build machinery is deferred (see D-004-IJ).
- **Time-to-kill addon (`badger-ttk`).** A second addon (Vanilla Era 1.15, Model 1 — the repo's first
  Vanilla addon): a right-anchored *time-until-the-target-dies* bar plus utility bars showing **when to
  fire each finite cooldown** to cover the kill. One pure engine + three drivers; a live-only-smart TTK
  estimator (WarcraftLogs history deferred); a static, complete, curated warrior cooldown table
  (`docs/reference/warrior-ttk-cooldowns.md`) with a live availability/usability overlay; config-driven
  per-encounter gating; an open user-authored skin system. Design in WO-007; scaffolded by WO-008
  (D-005/D-006). Functionality WOs follow — config first.
- **Docs/process in place.** `CLAUDE.md`, `docs/engineering-principles.md`, `docs/workorders.md` +
  `docs/workorders/WO-001-IJ.md`, this log, `docs/milestones.md`, `docs/architecture.md`.
- **Not in scope (by design).** No company-infra registration, no ports/subdomains/Notion — this is a
  standalone game addon repo. No web/security layer.
- **Inspiration assets.** `assets/` (repo root) holds internet-gathered reference material — see
  `assets/README.md`. Drops land via a lightweight lane: `chore` branch + PR (human merges), **no work
  order**; images are optimized before the first commit (see D-002-IJ).
- **Release cadence.** A version bump is a **deliberate release event**, not a per-WO/per-build step
  (D-011-IJ, from 2026-07-29 — supersedes the old "bump every test build"): code WOs merge to `main`
  **without touching `## Version`**; player-facing changes accumulate under `[Unreleased]` in
  `projects/badger-ttk/CHANGELOG.md`. A release bumps `## Version`, promotes `[Unreleased]` to the new
  section, and builds the auto-named zip (`tools/build.sh`). **`1.0.0` still only on human sign-off.**
- **Kill-history schema.** Based on the **Warcraft Logs** standard (D-012-IJ): local recording and web-log
  import share one record shape (encounter/NPC · duration→rate · group size · comp · difficulty); import is
  copy-paste (LibSerialize+LibDeflate) via an external converter (the addon can't fetch the web). Schema
  locked before 1.0; importer later. Schema finalised (reliability-first, TBC/Retail forward-compat): `docs/reference/kill-history-schema.md`.
- **Next id:** D-013-IJ.

---

## Decision log

### 2026-07-29

- **[D-012-IJ] The kill-history schema follows the Warcraft Logs standard; local recording and web-log
  import share ONE record shape; import is a copy-paste, converted externally.** (Refines the D-005
  WarcraftLogs-import seam.) *Source (confirmed by the human):* **Warcraft Logs** (warcraftlogs.com) — the
  community-standard web log, itself built on WoW's own combat log. Our per-kill record is a *subset/mapping*
  of that field set (encounter / NPC id · fight duration → rate · group size · composition · difficulty),
  so a **locally-observed kill and an imported one are the same shape** and blend into one prior. *Sandbox
  constraint (load-bearing):* a WoW addon **cannot fetch a URL or read a log file**, so "import" is a
  **copy-paste** (like the skin export/import); a small **external converter** — a companion tool/site —
  turns a WCL export (its GraphQL API) or a raw `WoWCombatLog.txt` into our paste string, and is the only
  web-touching piece (outside the addon). *Transport:* the community addon-string standard —
  **LibSerialize + LibDeflate → base64** (the "WeakAuras string" convention) — not a bespoke blob. *Local
  side:* the addon reads group size + composition live (roster APIs) into the same schema, so richer priors
  come free and the prior can be **selected/scaled by the current group** — the fix for the
  group-dependent-prior caveat (WO-066). *Timing:* lock the **record schema** before 1.0 so local recording
  is forward-compatible from day one; build the importer + converter later. Strawman schema:
  `docs/reference/kill-history-schema.md`. *Why:* basing on the standard everyone already uses makes import
  a thin mapping (not a translation) and makes our data interoperable, instead of inventing a private
  format we'd have to bridge. Confirmed by the human 2026-07-29.

- **[D-011-IJ] Version bumps are a deliberate release decision, not per build/WO (supersedes the
  bump-every-build convention).** Routine code WOs merge to `main` **without changing `## Version`**;
  player-facing changes accumulate under `## [Unreleased]` in `projects/badger-ttk/CHANGELOG.md`. When the
  human decides to release, ONE step: bump `## Version`, rename `[Unreleased]` → `## [x.y.z] - YYYY-MM-DD`,
  run `tools/build.sh badger-ttk` (which auto-names the zip from the `.toc` version), and upload to
  CurseForge as a *Release* with that CHANGELOG section pasted into the file's Changelog box (newest
  Release is auto-featured — the filename is cosmetic). `1.0.0` remains gated on **explicit human
  sign-off**. *Why:* the old per-build bump (WO-017) made every tiny change a version and created constant
  `.toc` version-line merge conflicts between parallel WOs; a version should mark a real, chosen release,
  and the CHANGELOG `[Unreleased]` lane (WO-064) is exactly the accumulator for it. *Note:* between
  releases, verify against merged `main` directly; in-game confirmation of behaviour changes is still
  required before a WO is `Done`. Set by the human 2026-07-29.

### 2026-07-27

- **[D-010-IJ] `badger-ttk` — skins exclude frame position & lock (amends D-008).** A saved skin captures
  the Skin-node fields (media, colours, font sizes) and the Display **look** (size, scale, opacity, strata,
  growth, the readout toggles) — but **not** `anchorPoint / posX / posY / locked`. So applying a skin (or
  switching skins) **restyles the bars without moving them or changing whether they're locked**;
  `DISPLAY_FIELDS` in `skin.lua` no longer lists the four placement fields, so both `saveCurrent` (capture)
  and `apply` (restore) follow from the one list. Backward-compatible: a skin already saved under D-008 may
  still hold those fields, but `apply` iterates `DISPLAY_FIELDS` and simply ignores them — no migration.
  *Why:* the human decided placement is not part of a "look" — a skin should re-theme the bars in place,
  not teleport them; the "save current config" faithfulness that motivated D-008's inclusion is outweighed
  by the foot-gun of a skin moving your frame. Recorded by WO-031-IJ.

- **[D-009-IJ] `badger-ttk` — the preview is ONE scenario: the static view is it frozen, the dynamic
  Play/Stop just animates/re-freezes that same setup; closing the config stops the preview.** Collapsed
  the two previously-separate previews (a bespoke 4-bar static stack + a different warrior playback) into a
  single source: `Sim.staticPreview()` now returns the warrior scenario **frozen at the moment it reads
  0:25** (`Sim.run(scenario, total − 25)`), and dynamic playback loops that exact scenario — so the bars
  you style static are the bars that animate. The config controls became **"Show preview"** (show/hide the
  frozen still) + a **Play/Stop button** (disabled until the preview is shown; Stop re-freezes to the 0:25
  still rather than hiding). A new `BadgerConfigUI-1.0` close callback (`SetCloseCallback`, MINOR 4→5,
  chaining the AceGUI Frame's `OnClose`) lets badger-ttk **turn the preview off + resume the live driver
  when the window closes**. *Why:* the human observed the static and dynamic previews were "two different
  things" and wanted one setup as the single source of the UI representation, plus a preview that never
  lingers after the config is dismissed. Builds on D-007 (fixed-timeline geometry). Recorded by WO-030-IJ.

- **[D-008-IJ] `badger-ttk` — a "skin" is a saved preset of the Skin *and* Display config; user skins
  persist in `db.global`.** *Amended by [D-010-IJ] — frame position/lock are NO LONGER captured.* The skin
  format (still data-only, no code) gains two OPTIONAL blocks on top of
  media + colours: bar-text sizes and a **full Display block** (geometry, scale/opacity/strata, growth,
  the readout toggles — **and** frame position/lock). `Skin.apply` writes **only what a skin carries**, so
  the built-ins (media + colours, no Display block) restyle **without touching your layout**, while a
  user-saved skin also **restores the exact captured layout incl. position** on select. A new pure
  `Skin.saveCurrent(profile, name)` value-copies the current profile into a skin, registers it, and
  returns it; the config Skin node gets a **name input + "Save current as skin"** button that persists the
  result to `db.global.skins[name]` (re-registered on `OnInitialize`, so it survives `/reload`); built-ins
  stay code-defined. *Why:* the human observed a skin is "just combinations of options in skin and
  display" and wanted to snapshot the current look as a reusable preset. Capturing the **full** Display
  (including position) is the faithful reading of "save current config" — applying such a skin is an
  explicit "restore this exact setup", so the frame moving is expected; built-ins deliberately omit the
  block to keep skin-switching a pure restyle. Recorded by WO-029-IJ.

### 2026-07-25

- **[D-007-IJ] `badger-ttk` render geometry — the display timeline is scaled by a `total`, and the sim
  uses a FIXED `total` for steady bars (live keeps rescaling to the current TTK).** The render model /
  layout scale the x-axis by a `total` value (`xOf(v) = width·(total−v)/total`, right edge = death) that
  **defaults to the current `ttk`** — so the **live** driver is unchanged (its window is always "now →
  death" and legitimately rescales as the estimate fluctuates). The **sim preview passes a fixed `total`**
  (50s), so a utility bar is placed by its **absolute time-from-death and holds the same size/position its
  whole life** — planned *and* active — because on a linear countdown a fixed scale doesn't grow/shrink.
  Two more geometry rules landed with it: **(a)** a utility bar is a **coverage SEGMENT** `[anchor, anchor
  + duration]` (colour = coverage verdict, countdown = text), NOT the draining remaining, so it doesn't
  shrink as the buff ticks; **(b)** every window is **clamped to `[0, width]`** in the pure layout — the
  TTK bar's width is the hard maximum, so an ability longer than the timeline (e.g. Diamond Flask 60s vs a
  50s kill) fills the full bar and can never overflow. *Why:* the human's first dynamic-preview test showed
  bars growing/jittering; the human chose steady bars for the sim (a clean demonstration) while keeping the
  live estimate honest. The sim is thereby a **deterministic visual demo** (TTK = total − t), not an
  estimator harness — the estimator's live/immune behavior stays covered by the engine specs. Recorded by
  WO-018-IJ.
- **[D-005-IJ] `badger-ttk` — a second addon: a time-to-kill / optimal-cooldown-timing bar UI for
  Classic Era 1.15 (Vanilla, Model 1), the repo's first Vanilla addon.** A right-anchored bar shows the
  estimated *time until the current target dies*; utility bars sit against it to show **when to fire each
  finite-duration cooldown** so its buff exactly spans the remaining kill — a static *planned* pop-line
  becomes an *active* draining bar, and a repeated **comb** at TTK = D, D+C… appears when the fight
  outlives the cooldown. Built as **one pure engine + three drivers** (live events / a simulation script
  / Busted specs) so the timing math is off-client-testable per the house rule. v1 estimates TTK
  **live-only but not naively** — a health-fraction EWMA (`UnitHealth` sampling, surfaced to the user as
  a *Reactivity↔Stability* slider) with an execute-phase correction and a confidence gate; the
  **WarcraftLogs historical blend is deferred** (v1 only prepares the seam — an `E(h)` kill-curve stored
  in AceDB `db.global`, not `db.profile`). *Why:* every Vanilla burst cooldown is finite and long-CD, and
  the optimal pop moment (fit the duration inside the kill; squeeze extra uses when the fight is long) is
  non-obvious and shifts second-to-second with live DPS — surfacing it is a genuine skill lift, and an
  engine-first build keeps it testable and drivable from live/sim/spec alike. Design in WO-007;
  scaffolded by WO-008.
- **[D-006-IJ] `badger-ttk` ability, config & skin model.** The tracked cooldowns are a **static,
  complete master table** (warrior curated + Wowhead-verified in
  `docs/reference/warrior-ttk-cooldowns.md` — *offensive, finite, timed on-use effects only*; defensives,
  passives/procs, and long maintained/pre-pull buffs excluded), shown in **full** in config. A live scan
  only **annotates** each entry — *known* (abilities/racials) · *equipped* (items) · *in bags*
  (consumables) → usable, else dimmed — and a bar renders only when **enabled ∩ usable-now (or its buff
  is already active)**. **Not-usable / shared-CD lockout is read from the game's live usability**
  (`GetItemCooldown` / `IsUsableItem` / `IsUsableSpell`), not modeled as relations — which also sidesteps
  the unresolved Classic shared-trinket-CD question. Show-gating is **config-driven per raid/encounter**
  (a dedicated Raids node). The bar UI is **skinnable via an open, user-authored `RegisterSkin` data
  format** (built-in + third-party skins; one font family + a main-vs-other size split; skin owns *look*,
  placement stays user config); the options window targets a **high-end, icon-rich** look (may extend
  `BadgerConfigUI-1.0` with icon support). **Config precedes functionality** — a dedicated config-skeleton
  WO runs before the feature WOs. *Why:* a static list lets a player pre-configure for gear/specs they
  don't have yet; reading live usability is far cheaper than a relations graph and is always correct; an
  open skin format lets the community theme it. See WO-007 + the reference data.

### 2026-07-24

- **[D-004-IJ] The monorepo targets multiple WoW Classic flavors; each addon declares its own, and
  flavor-divergent API is scoped per project.** Not everything is TBC: `badger-arena` targets **TBC
  Anniversary** (2.5.x, `WOW_PROJECT_BURNING_CRUSADE_CLASSIC`, arena API), while future addons target
  **Classic Era / Hardcore** (Vanilla 1.15.x, `WOW_PROJECT_CLASSIC`, no arena; Hardcore is a runtime
  game-state on the Vanilla client, not a distinct flavor). *Mechanism:* each project declares its flavor
  via a `flavor:*` tag in `project.json` and its `.toc` `## Interface:`; flavor-specific API lives in a
  scoped `.luacheckrc` overlay (`files["projects/<addon>/**"]`) so a Vanilla addon referencing a TBC-only
  API fails the lint (W113) instead of passing silently; runtime code guards with `WOW_PROJECT_ID ==
  WOW_PROJECT_*` and probes optional APIs with `type(fn) == "function"`; the shared `wow-mock` is
  flavor-aware (`install({ flavor })`, `tbc` default). *Why now, and why partial:* the flat
  monorepo-wide luacheck globals were a latent bug (a future Vanilla addon would lint TBC APIs as valid),
  and the "TBC Anniversary" framing across `CLAUDE.md` / principles / architecture was inaccurate — both
  fixed now. Per §1.4/§1.1 the **build machinery for one addon shipping to *multiple* flavors** (split
  `_Suffix.toc` / multi-`## Interface` TOC + packager `-S`) is **deferred** until a both-flavor addon
  exists; its design (Model 2) is on record here. Two targeting models: **Model 1** = one flavor per Nx
  project (today's default); **Model 2** = one addon → multiple flavors (deferred). Recorded by WO-006-IJ.
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
