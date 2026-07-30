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
- **WO-071-IJ** — **`ttk-lab` live terminal dashboard**: one client-run command (`tools/ttk-lab.py hunt|grade [--est candidate]`) with a real-time ANSI raid-meter display, grading each fight as it lands; ends with a `_run-summary.json` handoff ("tell Claude when done"). Single-file mode added to `estimator-batch.lua` (see `docs/workorders/WO-071-IJ.md`). Status: Done — PR #74 merged; main green.
- **WO-070-IJ** — **corpus harvest + batch-grade** (the "learning how to learn" data engine): `tools/wcl-corpus.py` (WCL V1 rankings → many real kills across the performer spectrum → fixtures in a gitignored harvest zone) + `tools/estimator-batch.lua` (aggregate MAPE/bias/shown over the corpus). Feeds WO-069 (see `docs/workorders/WO-070-IJ.md`). Status: Done — PR #73 merged; main green.
- **WO-069-IJ** — **estimator regime-aware overhaul** (fable + ultracode): stop stretching the solo-tuned chunk-clock across solo/party/raid; regime-detect + per-regime strategies behind the frozen API, with per-encounter rhythm profiles for the raid path (anchor [D-013-IJ]). Proven against real fights via the replay pipeline (see `docs/workorders/WO-069-IJ.md`). Status: In progress — loop 13 (PR #88): BWL COMPLETE, wing shipped; 17 encounters, 400/425 held-out wins; /reload still deferred.
- **WO-068-IJ** — **Warcraft Logs → fight-file converters** (piece 2): `tools/wcl-v1-to-fight.py` (V1 API, exact per-event `hitPoints`, key from a gitignored `.env`) pulls a whole fight + adds timeline in one call; CSV + V2 fallbacks; grader now scores only confidence-gated (shown) ticks. First real fight (Lucifron) graded — CSV artifact corrected by the exact API pull (see `docs/workorders/WO-068-IJ.md`). Status: Done — PR #72 merged; main green.
- **WO-067-IJ** — **replay-and-grade harness**: `tools/estimator-replay.lua` grades the estimator's predicted TTK vs a real fight's health curve (ground truth), the "dev mode" replay of Warcraft Logs fights (see `docs/workorders/WO-067-IJ.md`). Status: Done — PR #71 merged; main green.
- **WO-066-IJ** — **validate the estimator for party/raid + composition**: extend the sim harness with caster/melee/healer/heroism/immune-phase traces, document the analysis + roadmap (`docs/reference/estimator-party-raid.md`) (see `docs/workorders/WO-066-IJ.md`). Status: Done — PR #70 merged; main green.
- **WO-065-IJ** — **config layout pass**: Behavior (drop intro+separator), Display row restructure (position/scale up top), Estimator (widen history toggles), Abilities (wider offset slider + header spacing); first WO under D-011 — no version bump (see `docs/workorders/WO-065-IJ.md`). Status: Done — PR #69 merged; main green.
- **WO-064-IJ** — **CHANGELOG + release process**: add `projects/badger-ttk/CHANGELOG.md` (Keep a Changelog); each version WO renames `[Unreleased]` → the new version and that section feeds the CurseForge changelog box (see `docs/workorders/WO-064-IJ.md`). Status: Done — PR #67 merged; main green.
- **WO-063-IJ** — **add Naxxramas** to the raid registry (the missing final Classic-Era tier); pure data addition to `ns.RaidTable`, 15 encounters, after AQ40 (see `docs/workorders/WO-063-IJ.md`). Status: Done — PR #66 merged; main green.
- **WO-062-IJ** — **skin Export/Import windows + named skins + built-in "Modern"**: `lib:TextPopup` (AceGUI copy/paste window, MINOR 10→11); `Skin.serialize` adds `name`, new pure `Skin.deserialize`; `RegisterBuiltin`/`isBuiltin` (Default + Modern); Export/Import buttons next to Delete (see `docs/workorders/WO-062-IJ.md`). Status: Done — PR #65 merged; main green.
- **WO-061-IJ** — **estimator verify follow-ups**: floor released after a slowdown flush, prior counts toward confidence + 90s per-GUID retarget cache (no more swap-back blackout), countdown floors at 0.05s (no display blanking), verify panel's mutation-tested gap specs adopted (see `docs/workorders/WO-061-IJ.md`). Status: Done — PR #64 merged; main green.
- **WO-060-IJ** — **skin export**: pure `Skin.serialize` (paste-ready `RegisterSkin` literal) + a read-only multiline Export box in the Skin node (see `docs/workorders/WO-060-IJ.md`). Status: Done — PR #63 merged; main green.
- **WO-059-IJ** — **preview icons**: sim scenario switched to the REAL ability ids (Death Wish 12328, Earthstrike 21180) so icons + per-ability colours resolve in preview (closes audit #6), plus a Ragnaros stand-in on the TTK bar while previewing (see `docs/workorders/WO-059-IJ.md`). Status: Done — PR #61 merged; main green.
- **WO-058-IJ** — **layout follow-up**: Behavior's two sliders share one row (0.49 each), Display's H·V·Scale share one row (0.33 each), header order Lock · Show preview · Play/Pause (see `docs/workorders/WO-058-IJ.md`). Status: Done — PR #60 merged; main green.
- **WO-057-IJ** — **fix the WO-053/054 layout widths**: numeric AceConfig widths are 170px multiples (0.5 = an 85px sliver), not row fractions — switch to `width="relative"`+`relWidth` / `"full"` per the human's row list (see `docs/workorders/WO-057-IJ.md`). Status: Done — PR #59 merged; main green.
- **WO-056-IJ** — **estimator stability**: the TTK readout jumps between swings (spike-train sampling + EWMA decay + conf saturating in ticks killing the history prior); ultracode diagnose+design → rewrite of the pure estimator + simulation-proven (see `docs/workorders/WO-056-IJ.md`). Status: Done — PR #62 merged; main green.53s→2.39s worst jump, countdown dev 0.01s).
- **WO-055-IJ** — **show icons**: utility bars show their ability icon + the TTK bar shows the current target's portrait (SetPortraitTexture, live) when Show icons is on; display.lua only (see `docs/workorders/WO-055-IJ.md`). Status: Done — PR #58 merged; main green.
- **WO-054-IJ** — **config layout grouping**: Lock in the header; Display anchor·lock·reset / H·V offset / scale·growth on shared lines; Behavior minTTK·confidence on one line (see `docs/workorders/WO-054-IJ.md`). Status: Done — PR #57 merged; main green.
- **WO-053-IJ** — **Skin node: Delete on the picker's line + block saving over "Default"** (audit #2); config layout (picker 0.75 + delete 0.25) + `saveCurrent` refuses the built-in name (see `docs/workorders/WO-053-IJ.md`). Status: Done — PR #56 merged; main green.
- **WO-052-IJ** — **fix: header band leaks across the AceGUI frame pool** (audit #1, my WO-045 regression) + **master-switch gate** (audit #5); BadgerConfigUI teardown (MINOR 9→10) + driver enabled early-return (see `docs/workorders/WO-052-IJ.md`). Status: Done — PR #55 merged; main green.
- **WO-051-IJ** — **fix: profile switch/reset leaves display stale** (audit #4 = the "bars not aligned after clearing profile" bug) + reset preview state on init (#3) + normalize unknown skin on inactive profiles (#7); AceDB profile callbacks in core.lua (see `docs/workorders/WO-051-IJ.md`). Status: Done — PR #54 merged; main green.
- **WO-050-IJ** — **Text-offsets one row**: `width = 0.25` on the four TTK/Utility text-offset sliders so all four share a row (see `docs/workorders/WO-050-IJ.md`). Status: Done — PR #53 merged; main green.
- **WO-049-IJ** — **default profile tuning**: fresh-profile defaults (bar 220, bg opacity 45%, Blizzard Raid Bar, Arial Narrow, util size 10, TTK size 13, util-waiting black) + built-in Default skin match (see `docs/workorders/WO-049-IJ.md`). Status: In progress — PR #52 opened.

- **WO-048-IJ** — **fix: icons don't render** — the TGAs were top-origin (descriptor `0x28`); WoW needs bottom-origin. Fix `png-to-tga.py` to emit `0x08` + bottom-to-top rows, regenerate both `Media/*.tga` (see `docs/workorders/WO-048-IJ.md`). Status: Done — PR #51 merged; main green.
- **WO-047-IJ** — **Display node: pair the Text-offset sliders two-per-row** — `width = "half"` on the four TTK/Utility text-offset sliders so they lay out as a 2×2 grid (TTK X·Y over Utility X·Y) (see `docs/workorders/WO-047-IJ.md`). Status: Done — PR #50 merged; main green.
- **WO-045-IJ** — **config header: two-column brand band** (image left + right-margin, title/subtitle stacked left on the right); a self-contained raw band in BadgerConfigUI (`polishHeader`, MINOR 8→9) + a one-time `content` inset, `normalize` omits the text descriptions when `header.image` is set; controls stay native below the band (see `docs/workorders/WO-045-IJ.md`). Status: Done — PR #49 merged; main green.
- **WO-046-IJ** — **README overhaul**: rework README.md in the polished payload-wonderly/zenzo style (hero + badges + emoji sections + stack table + NOTE callout), promote **badger-ttk to first**, and reflect the **TBC Anniversary + Classic Era** target (#27/#28) (see `docs/workorders/WO-046-IJ.md`). Status: Done — PR #43 merged; main green.
- **WO-044-IJ** — **ship the icons**: convert the PNGs to uncompressed TGA, ship `badger-ttk-icon.tga` + `badger-master.tga` in `Media/`, set `## IconTexture` (badger-ttk), add `tools/png-to-tga.py`, commit the source PNGs (see `docs/workorders/WO-044-IJ.md`). Status: Done — PR #48 merged; main green.
- **WO-043-IJ** — **config window: align status bar + Close button** with the content L/R inset (#16); a defensive `polishStatusBar` re-anchor in BadgerConfigUI (MINOR 7→8) (see `docs/workorders/WO-043-IJ.md`). Status: Done — PR #47 merged; main green.
- **WO-042-IJ** — **per-ability colour** (pre-1.0 batch 5): each Warrior ability gets a colour that overrides the global Utility (waiting) colour for its bar while waiting (#5) (see `docs/workorders/WO-042-IJ.md`). Status: Done — PR #46 merged; main green.
- **WO-041-IJ** — **bar geometry & opacity** (pre-1.0 batch 4): two bar heights — TTK 30 / utility 20 (#4); border hugs the bar (#17); fill + background opacity sliders (#23/#24); TTK/utility text X-Y offsets (#25); all saved to skins (see `docs/workorders/WO-041-IJ.md`). Status: Done — PR #45 merged; main green.
- **WO-040-IJ** — **skin colours + font colour** (pre-1.0 batch 3): consolidate state colours to four — Target (TTK) / Utility (waiting) / Utility (fire) / Utility (fired), dropping the duplicate Waiting (#1/#2); add a Font colour picker (#20); confirm skins save spacing/width/height (#22) (see `docs/workorders/WO-040-IJ.md`). Status: Done — PR #44 merged; main green.
- **WO-039-IJ** — **config copy** (pre-1.0 batch 2): deeper General how-to (#3/#13), a Behavior intro line (#26), intro text on the Raids + Abilities parent nodes (#6), sharper minTTK tooltip (#7) (see `docs/workorders/WO-039-IJ.md`). Status: Done — PR #42 merged; main green.
- **WO-038-IJ** — **config structure & labels** (pre-1.0 batch 1): title → "Badger Time To Kill (TTK)"
  (#10); Raids moved above Abilities (#11); Simulation → **Preview** (#12); Profiles icon (#8); a header
  **Play/Pause** button (#14); Skin node — picker on its own line + New/Save/**Delete** row (#18/#21),
  "Utility size" (#19), built-in skin **Badger → Default** (#21) (see `docs/workorders/WO-038-IJ.md`).
  Status: Done — PR #41 merged; main green.
- **WO-037-IJ** — **fix: config close callback + header margin**: the window's close callback only fired on
  the X button (ESC / slash-toggle / `:Close` go through Ace's deferred hide and never fire `OnClose`), so
  the preview lingered — hook the frame `OnHide` instead; and halve the global-header bottom spacer. Shared
  lib (MINOR 6→7) (see `docs/workorders/WO-037-IJ.md`). Status: Done — PR #40 merged; main green.
- **WO-036-IJ** — **badger-arena adopts the global-header API**: switch its config from the `banner` alias
  to the explicit `opts.header` (already renders via the alias; this makes it current). Arena has no built
  `.release` yet, so an in-game build is deferred; whenever built it embeds BadgerConfigUI MINOR 6 (see
  `docs/workorders/WO-036-IJ.md`). Status: Done — PR #39 merged; main green.
- **WO-035-IJ** — **Reset rewinds the sim to 100% (0:50), independent of Play**: Reset returns to the
  timeline start (full health) instead of the 0:25 still, and no longer stops playback (see
  `docs/workorders/WO-035-IJ.md`). Status: Done — PR #38 merged; main green.
- **WO-034-IJ** — **persistent global header in BadgerConfigUI**: replace the identical per-node banner with
  one global header (title/subtitle) rendered above the tree via root-level AceConfig args, and add a **Show
  preview** toggle to it (kept in the Simulation node too; native two-way sync). Shared lib (MINOR 5→6),
  `opts.banner` kept as an alias (see `docs/workorders/WO-034-IJ.md`). Status: Done — PR #37 merged; main green.
- **WO-033-IJ** — **simulation: Play → Play/Pause + a Reset button**: Pause freezes the animation in place
  (Play resumes from there — pausing never resets the timeline); a new Reset button returns to the frozen
  0:25 still (see `docs/workorders/WO-033-IJ.md`). Status: Done — PR #36 merged; main green.
- **WO-032-IJ** — **fix two WO-028 display regressions** (found testing 0.9.14): utility bars vanished
  (container `SetClipsChildren` clips the bars stacked above the one-bar-tall container) and editing a
  Display value pops a stray border box (the sibling `borderFrame` isn't tied to container visibility). One
  fix: drop the clip + re-parent the border to the container (see `docs/workorders/WO-032-IJ.md`).
  Status: Done — PR #35 merged; main green.
- **WO-031-IJ** — **skins exclude frame position & lock** (amends D-008): a saved skin no longer captures
  `anchorPoint/posX/posY/locked`, so applying a skin restyles the bars **without moving them or changing
  the lock** (the geometry/readout *look* still applies). Records **D-010-IJ** (see
  `docs/workorders/WO-031-IJ.md`). Status: Done — PR #34 merged; main green.
- **WO-030-IJ** — **simulation rework**: make the sim ONE thing — the static preview is the single source
  of the UI, and Play/Stop just loops/freezes that same setup; the preview reads **0:25**; and closing the
  config window **shuts down** any preview (see `docs/workorders/WO-030-IJ.md`). Status: Done — PR #33 merged; main green.
- **WO-029-IJ** — **config improvements**: Warrior node rework (separators + in-game tooltip text +
  always-editable regardless of availability); **Save current config as a skin** (name + button; captures
  Skin + Display); more **header/body spacing** on every page (BadgerConfigUI, MINOR→4) (see
  `docs/workorders/WO-029-IJ.md`). Status: Done — PR #32 merged; main green.
- **WO-028-IJ** — **display/frame fixes**: give the TTK bar a background track and set **both** backgrounds
  to a faint 10% opacity; keep bar fills **inside a border** (no overflow, clipped); make a **Bar width**
  change apply immediately and keep the **right (death) edge fixed** (see `docs/workorders/WO-028-IJ.md`).
  Status: Done — PR #31 merged; main green. (In-game re-test with the human.)
- **WO-027-IJ** — **polish batch** (one build): (1) a hint (`desc`) on **every changeable config option**;
  (2) nest warrior abilities under a **Warrior** node; (3) `.toc` flavor "Era / Hardcore" (drop Anniversary)
  + `## Category: Combat`; (4) config-banner **subtitle smaller than title** (BadgerConfigUI, MINOR→3); (5)
  **smoother** status bars (per-frame fill easing); (6) record kill rate from **first-damage → death** to fix
  the huge start-TTK. See `docs/workorders/WO-027-IJ.md`. Status: Done — PR merged; main green.
- **WO-026-IJ** — **Behavior toggle: show utility bars outside a raid?**: a new option next to *Show on any
  target* — when off and the target is **not a raid boss**, only the main TTK bar shows (utility bars hidden
  as noise on random mobs). "raid" = an active **encounter** (`ENCOUNTER_START`/`END`) **or** a
  `worldboss`-classified target — covering instance + open-world bosses (human-approved); pure `showUtility`
  helper, empty utility list via the existing seam (see `docs/workorders/WO-026-IJ.md`). Status: Done — PR #28 merged; in-game approved.
- **WO-025-IJ** — **recorded kill history → steadier TTK**: record every observed kill into
  `db.global.history[level][npcId]` (running-mean health-loss rate) and blend it as a **prior** to smooth
  the noisy live estimate — organized **by player level**, for trash and raids. Pure `history` +
  estimator-blend (confidence ramp + prior-floor) spec-tested; Record/Use toggles + Clear button. The
  local half of the `db.global` history seam (D-005); WarcraftLogs import still later (see
  `docs/workorders/WO-025-IJ.md`). Status: Done — PR #29 merged; in-game approved (WO-027 refines the start-TTK).
- **WO-024-IJ** — **fix live show/hide flicker**: the gate hid the bars the instant `ttk < minTTK` every
  ~0.15s, so a noisy live estimate flapped them (and it hid the endgame of every fight). Make `minTTK` a
  **sticky initial-show gate** (qualify once, then stay through the fight), have `showAnyTarget` bypass it,
  and wire `hideOnTargetDead`; pure `gate(settings, context, wasShown)` spec-tested (see
  `docs/workorders/WO-024-IJ.md`). Status: Done — PR #27 merged; in-game confirmed.
- **WO-023-IJ** — **utility-bar colour = action signal**: recolour utility bars **waiting → ready (green)
  → used (gray)** so the player sees exactly when to fire (`ready = ttk ≤ duration+offset`, pure/spec-
  tested); new `colorReady/colorUsed/colorWaiting` (retire the coverage colours); sim demos **Earthstrike
  used 4s late** (a 4s green window). See `docs/workorders/WO-023-IJ.md`. Status: Done — PR #26 merged; in-game approved.
- **WO-022-IJ** — **Raids config node**: replace the WO-009 placeholder with a **sub-node per Classic-Era
  raid**, each listing its **encounters as checkboxes** (default on) + a per-raid **master toggle**; a pure
  `ns.RaidTable` registry (spec-tested) + `buildRaids` + `db.profile.raids` storage. Config surface only —
  live gating enforcement + boss icons deferred (see `docs/workorders/WO-022-IJ.md`). Status: Done — PR #25 merged; in-game approved.
- **WO-021-IJ** — **UI polish**: (1) config left-nav — a small gap between each node's icon and name +
  vertical centring, via re-anchoring the AceGUI TreeGroup buttons in the shared `BadgerConfigUI` lib
  (guarded `hooksecurefunc`, no vendored-lib edits, so all Badger addons get it); (2) **right-align** the
  utility-bar text (badger-ttk). See `docs/workorders/WO-021-IJ.md`. Status: Done — PR #24 merged; in-game approved.
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
