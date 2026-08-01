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

_As of 2026-08-01._

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
- **Estimator R&D — the "learning how to learn" phase.** The learning **method** is built and proven,
  fully **client-side** (git holds tools + curated outcomes; harvested data + runs stay local, never in
  git/CI): WCL converters (exact per-event `hitPoints`; V1 key in a gitignored `.env`) → replay +
  batch graders (confidence-gated) → corpus harvest (`tools/wcl-corpus.py`, gitignored
  `tools/fights/corpus/`). Fresh encounter ids = classic id + 150000; each raid is sampled from its own
  relevance window (MC Jan–Mar 25 · BWL Apr–Jul 25 · AQ Jul–Sep 25). Baseline grade (12 Fresh Lucifron
  kills): mean MAPE ~31%, reads long, error grows with fight length. **D-013 Accepted** — the
  regime-aware overhaul (WO-069) runs on fable, its multi-agent design fan-out when the human enables
  ultracode; progress scoreboard: `docs/reference/estimator-scoreboard.json`.
- **Known measurement debt — the lab does not model the client (2026-08-01).** The PR
  [#97](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/97) re-verification confirmed
  that the regime layer's `confCap`s were both **learned and graded under a show gate the client does not
  implement**: `driver.lua:67` consults confidence only while `not wasShown`, so once the bar latches in any
  health bin every later cap — including a hard `0.0` — is unreachable, while `estimator-batch.lua:110` and
  `learn-regime.py:207-208` assume each bin can hide independently. **Viscidus's shipped profile is
  bit-identical to shipping no regime at all**; Skeram and Sulfuron are ~nullified; Onyxia and Buru
  degraded but net-positive; Gahz'ranka unaffected. Two sibling instances of the same root cause: the batch
  tools hard-code `damageable = true` where the driver passes `not dead` (parked — see D-021), and
  `regimeFor` requires `UnitLevel("target") == -1`, **never verified on a live instanced Era boss**. Nothing
  here is player-visible or a 1.0.0 blocker, and the fix is instrument-side. Full record:
  [reference/pr97-verification-2026-08-01.md](reference/pr97-verification-2026-08-01.md); resolution planned
  as WO-076.
- **Docs/process in place.** `CLAUDE.md`, `docs/engineering-principles.md`, `docs/workorders.md` +
  `docs/workorders/WO-001-IJ.md`, this log, `docs/milestones.md`, `docs/architecture.md`.
- **Not in scope (by design).** No company-infra registration, no ports/subdomains/Notion — this is a
  standalone game addon repo. No web/security layer.
- **Inspiration assets.** `assets/` (repo root) holds internet-gathered reference material — see
  `assets/README.md`. Drops land via a lightweight lane: `chore` branch + PR (human merges), **no work
  order**; images are optimized before the first commit (see D-002-IJ).
- **Release cadence + mechanism.** A version bump stays a **deliberate release event**, not a
  per-WO/per-build step (D-011-IJ principle). The **mechanism** is now **`nx release`** (D-017-IJ):
  `projectsRelationship: "independent"` so each addon (`badger-ttk`, `badger-arena`, …) versions/tags/
  releases on its own; the version source is each addon's **`.toc` `## Version:`** (read/written by a
  custom `versionActions` under `tools/release/` — no `package.json` version); the bump **and** the
  per-project changelog are derived from **Conventional Commits**; the full pipeline versions the `.toc`,
  tags `{projectName}/{version}`, builds the zip, and cuts a GitHub Release with the zip attached.
  **CurseForge publish stays manual + gated on the in-game `/reload`** (D-015). **`1.0.0` still only on
  human sign-off.** WO-073 implements.
- **Kill-history schema.** The Warcraft-Logs-based record schema (D-012-IJ,
  `docs/reference/kill-history-schema.md`: encounter/creature split, per-kill records, 50-cap) is
  **implemented in code as of WO-072 (PR #91 merged; the 1.0.0 `/reload` still pending)** — recording
  writes per-kill records with all WCL-shared fields, the old WO-025 running-mean data is migrated/wiped,
  and co-boss encounters blend under one id (accepted, D-016). Closes the 1.0.0 gap audit's Tier-1 #3.
  Importer + external converter stay deferred (D-012 piece 2).
- **Estimator, shipped (0.9.45).** The full **41-profile rhythm library** across five raids (MC · BWL · ZG
  · AQ20 · AQ40) is released — learned from ~2,000 real WCL kills, held-out-validated, injected as
  `opts.rhythm` behind the frozen estimator API. The **regime structural-tail layer** (D-014, injected
  `opts.regime` + minimal seams) is **designed and accepted (D-014); pulled forward to ship as 0.9.48**,
  before 1.0.0 (D-018) — the Onyxia air-phase weakness made it the next priority.
- **1.0.0 status (Path B, D-015).** Out of alpha ships on the released rhythm library + the existing
  confidence gate. WO-072 (PR #91) is **merged**; remaining before the human's version bump: the **deferred
  in-game `/reload`** (loads clean · confirms the `663` vs `150663` encounter id-space · `.toc` Interface ·
  bars track · Majordomo-style hides). The regime layer (WO-069 impl, WO-075) now ships as **0.9.48**
  (D-018), so 1.0.0 includes it; the CLEU off-target tier remains a later follow-up.
- **Release infra (WO-073, D-017) — shipped (PR #92 merged).** `nx release` multi-output pipeline:
  custom `.toc` `versionActions`, `currentVersionResolver: git-tag` + `disk` fallback, Conventional-Commits
  bump + nx-owned per-project changelog, tag `{projectName}/{version}`, zip + a post-merge/human-gated
  GitHub Release (never auto-pushed). Build reproducibility fixed — BigWigs packager **pinned to v2.5.1**,
  the monorepo handled by **staging the addon as a standalone checkout**, `manual-changelog` ships the
  curated `CHANGELOG.md`. CurseForge stays manual + gated on the `/reload` (D-015).
- **First real release through the pipeline — `badger-ttk/0.9.46` (2026-07-30).** Cut via `nx release`
  (version off the `badger-ttk/0.9.45` tag → patch; nx-owned changelog handoff; zip), tagged
  `badger-ttk/0.9.46`, GitHub Release (Latest) with `BadgerTTK-0.9.46.zip`. Ships the WO-072 kill-history
  schema. **Git releases retrofitted** to the new scheme: `v0.9.44`/`v0.9.45` → `badger-ttk/0.9.44`/`0.9.45`
  (releases moved, zips kept; old `v*` deleted). The pipeline is now **proven in production**, so the
  **`scaffold-project` back-port is unlocked** (was gated on a real cycle). CurseForge publish + the 1.0.0
  cut still await the human's in-game `/reload`.
- **Onyxia shipped (0.9.47).** The last missing raid boss now has a learned rhythm (dual-key 1084/151084),
  held-out + fresh-batch validated (MAPE ~74%→~53–60%); released via the pipeline (tag `badger-ttk/0.9.47`,
  GitHub Release). It exposed the rhythm ceiling (the untargetable air phase), which motivated D-018.
- **0.9.48 SHIPPED (2026-08-01) — the regime layer is live.** WO-075 Done (PRs #95/#96/#97) and released via
  the pipeline (tag `badger-ttk/0.9.48` + GitHub Release + zip). **14 regime profiles** ship: the bar goes
  QUIET where it is measurably wrong instead of showing a confident-wrong countdown. Headline held-out
  numbers: Buru **188.6%→37.3%** (bias +74s→+3.2s), Twin Emperors 407%→**silent**, Thekal **silent** (+ his
  resurrect resets the estimate), Viscidus 117→44%, Skeram 113→70%, Rajaxx 207→132%, C'Thun 52→38%, Onyxia
  56→49%; Chromaggus and Ouro measured readable → correctly **no caps**. The `freeze` tier was **removed**
  (D-020). Solo play and every un-profiled fight remain **byte-identical**.
- **THE ONE REMAINING GATE for 1.0.0: the human's in-game `/reload`.** Everything else for Path B is done
  (rhythm library, kill-history schema, regime layer, release pipeline). The `/reload` must confirm: the
  addon loads clean · the `663` vs `150663` encounter id-space (which of the two the live client fires) ·
  the `.toc` Interface number · bars track · the Majordomo-style hides behave. It also gates every
  CurseForge upload (D-015), including 0.9.46/0.9.47/0.9.48, none of which are on CurseForge yet.
- **Next id:** D-021-IJ.

---

## Decision log

### 2026-08-01

- **[D-021-IJ] A verification finding that can be neither confirmed nor refuted is PARKED — it does not
  license a change to shared code. Status: Accepted.** *(Human directive 2026-08-01, on the PR #97 re-verification:
  "this only pertains to one or very few bosses, and I can not test it yet, so this will stay in limbo, work
  around that so we don't do damage because of no refutation possible.")* The trigger: an adversarial sweep of
  PR [#97](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/97) produced a finding that
  survived refutation — `resetOnRise` may be **structurally unreachable on the live client**, because
  `estimator.lua:129-132` nils `prevSampleT` whenever `damageable == false` and `:133-137` then re-anchors and
  returns, while `driver.lua:294/379` pass `not UnitIsDeadOrGhost("target")` across the multi-second window at
  `h == 0` that precedes Thekal's resurrect. The reviewer could not refute it; **neither can it be confirmed**,
  because that needs a real ZG kill.

  **It is parked rather than fixed, and the reasoning is the general rule.** *(a) Blast radius asymmetry.* The
  suspect code is the sampling gate **every** boss traverses; the finding concerns **one**. A speculative fix
  trades a possible no-op on one encounter for a possible regression on fourteen. *(b) It threatens the
  layer's load-bearing guarantee.* 0.9.48 rests on `regime == nil` ⇒ the estimator is **byte-identical**,
  enforced by diffing `tools/estimator-sim.lua` against `main`; an edit to the sampling gate is precisely the
  kind that breaks it. *(c) The evidence is circular.* The finding's own claim is that **the lab measures a
  configuration the client never runs** (`estimator-perbin.lua`/`estimator-batch.lua` hard-code
  `damageable = true`; the driver passes `not dead`). Using a mis-calibrated instrument to justify surgery on
  the thing it mis-measures proves nothing — this is D-019(c) ("facts must be live while measuring") recurring
  on an axis nobody had closed. *(d) Nothing is on fire.* 0.9.46–0.9.48 are GitHub-only, not on CurseForge
  (D-015), so the finding costs no player anything while it waits.

  *Consequence:* **permitted now** — aligning the lab instruments to pass `damageable = not dead` like the
  driver, and re-measuring; that is instrument-side, cannot regress the addon, and either reproduces the no-op
  or dissolves the finding (if caps move materially, *that* is the finding, and it would mean 0.9.48's caps
  were calibrated against a configuration the client never runs). **Forbidden without data** — touching
  `estimator.lua`'s sampling gate, the `damageable` hold, or Thekal's profile. *Resolution path:* protocol step
  **B4** in [in-game-verification.md](reference/in-game-verification.md) — during a real ZG kill, does the
  estimate visibly reset across the resurrect? Either answer closes it. Until then the finding stays **open**,
  and open is the correct state. Full record:
  [reference/pr97-verification-2026-08-01.md](reference/pr97-verification-2026-08-01.md).

### 2026-07-31

- **[D-020-IJ] The regime `freeze` tier is REMOVED, not kept-inert; an immune phase is stated as FACT by the
  driver, never inferred from the health curve. Status: Accepted.** *(Resolves the keep-or-remove call D-019
  deferred to PR3 — WO-075.)* The tier let a profile declare health bands in which the countdown should hold,
  inferring "the boss cannot be damaged right now" from health alone. It is removed because every argument
  ran against it: **(a) nothing used it** — across the whole structural roster no learned freeze band improved
  a grade, and freezing *alone* made Viscidus **worse** (85.5%→90.5%); wherever a fight stalls, the confidence
  caps have already quieted the bar, so holding it changes nothing. **(b) It duplicated a better mechanism
  that already exists** — `sample(t, h, damageable)` lets the DRIVER assert an immune/hardened phase as fact
  (the estimator has held that path since WO-056), which is strictly more reliable than guessing the same
  thing from the curve; the future CLEU tier should use it. **(c) It was a bug farm** — three real defects
  (a cadence-dependent gate, a stuck freeze, a delayed in-band release) were found by verification in code no
  profile ever invoked; each cost a review cycle to find and fix. That is exactly the cost the engineering
  principle warns about ("promote when a second consumer is real, not speculatively"). *Consequence:* the
  schema loses `freeze`/`stallSec`; `regimes_spec` now **fails the gate if the assembler ever emits one
  again** (dead data in a generated file is otherwise invisible); the lab keeps stall detection as a printed
  **diagnostic only** (that Viscidus stalls at h≈0.92 in 29/30 kills is real knowledge for the CLEU tier)
  but never emits it. The implementation stays recoverable in git history (PR #95). *This departs from the
  accepted D-014 design, which specified the tier — the measurement, not the design, is authoritative here.*

- **[D-019-IJ] Regime confidence caps are LEARNED from the estimator's own measured error, and the FREEZE
  tier is subsumed by them (it ships unused). Status: Accepted.** *(Refines D-014's method; forced by the
  PR2 measurement over 11 bosses / 800 real Fresh kills — WO-075.)* **(a) The statistic.** A `confCap` is
  derived by replaying the *shipped* estimator over a boss's corpus and measuring its real per-health-bin
  error (`tools/estimator-perbin.lua`), **not** from the design's proposed proxy (per-bin dispersion of
  remaining time). The proxy is an artifact: its denominator vanishes as the fight ends, so it would have
  **silenced the endgame** — the stretch the readout gets most right (~3s error with 10s to live). Caps use
  two currencies (≤30% relative **or** ≤5s absolute is useful; ≥45s absolute never is; between, the cap
  crosses the client's 0.5 show threshold at exactly 50% error), because a ratio alone misjudges the endgame
  and an absolute alone misjudges the pull. **(b) Measurement beats the blanket default.** The universal
  raid cap is NOT folded into a measured boss — doing so silenced Chromaggus' most readable band and made his
  grade *worse*; it remains the fallback for un-profiled bosses only. A measured boss therefore always ships a
  profile, even one with no caps ("measured: nothing to cap"), so the default cannot re-impose itself.
  **(c) Facts must be live while measuring** — Buru's caps learned without `suppressFlush` were calibrated to
  an estimator ~3× worse and over-silenced a usable readout. **(d) The freeze tier is subsumed.** Across the
  structural roster **no freeze band improved a grade**, and freeze-*only* made Viscidus worse (85.5%→90.5%):
  where a fight stalls, the caps have already quieted the bar, so freezing adds nothing. **No shipped profile
  uses `freeze`.** The mechanism stays in the estimator — nil-guarded, tested, inert — pending the CLEU tier;
  **PR3 decides keep-or-remove** (an unused seam is a cost, per the "promote when a second consumer is real"
  principle). *Consequence:* the hand-authored cap guesses of PR1 are replaced by measured ones, and two
  bosses the design predicted would need caps (Chromaggus, Ouro) provably do not.

### 2026-07-30

- **[D-018-IJ] The regime structural-tail layer moves from 1.1 to 0.9.48 — it ships BEFORE 1.0.0.
  Status: Accepted.** *(Human directive 2026-07-30, on seeing Onyxia's air-phase weakness: "whatever 1.1
  does, I want it next but as 0.9.48." Supersedes D-015's deferral of the regime layer to 1.1; the D-014
  design stands unchanged.)* Shipping the Onyxia rhythm (0.9.47) exposed the limit a rhythm profile provably
  can't cross: through a structural phase where the boss is untargetable (Onyxia's ~40s air phase, zero
  damage events), the confidence-gated bar still shows a confidently-wrong countdown (~99% shown, reads
  long) — measured, not assumed. D-014's **Minimal Seams** design is exactly the fix: an injected
  `opts.regime` table + nil-guarded, health-anchored seams that freeze/immune/reset off `h` **and cap
  confidence so the bar goes QUIET instead of guessing** through such a phase. The human wants that quality
  in players' hands next, not deferred past 1.0.0. *Consequence:* the release order is 0.9.47 (Onyxia) →
  **0.9.48 (regime, WO-069's 3 PR-sized increments)** → … → 1.0.0, so **1.0.0 now ships WITH the regime
  layer** — a stronger out-of-alpha than Path B's rhythm-only 1.0.0. Implementation stays gated by sim
  byte-identity + corpus regression, human-merged (D-014 §4). **WO-075 implements.**

- **[D-017-IJ] Releases move to Nx Release — independent multi-output, Conventional Commits, full
  pipeline. Status: Accepted.** *(Supersedes the D-011 changelog/version-bump **mechanism**; D-011's
  deliberate-release + `1.0.0`-on-human-sign-off **principle** persists.)* The monorepo ships N addons
  (`badger-ttk`, `badger-arena`, + future), each needing its own version · tag · changelog · zip ·
  release. Chosen by the human (2026-07-30): **`nx release`** (Nx 23) with
  **`projectsRelationship: "independent"`** so each addon versions/releases separately. *Version source* =
  each addon's **`.toc` `## Version:`** line, read/written by a **custom `versionActions`** module under
  `tools/release/` (no `package.json` version — the `.toc` stays the single source of truth the WoW client
  + CurseForge read). *Specifier + changelog* = **Conventional Commits**: the bump **and** the changelog
  are derived from commit messages (`feat`/`fix`/`feat!`|`BREAKING` → minor/patch/major), attributed to an
  addon by the files each commit touches. *Full pipeline per `nx release <addon>`:* version → per-project
  tag `{projectName}/{version}` (human's pick — e.g. `badger-ttk/1.0.0`) → changelog appended to the addon's `CHANGELOG.md` → build the versioned
  zip → **GitHub Release** with the zip attached. *CurseForge* stays a **manual, gated** upload (D-015: no
  publish without the in-game test; the monorepo also blocks CF auto-packaging). *Build reproducibility* is
  fixed so the zip builds without hand-assembly. *Consequences:* commits now follow **Conventional
  Commits**, scoped/attributable per addon (the AI authors them — recorded in `CLAUDE.md`); the historical
  hand-curated `CHANGELOG.md` entries stay, new ones are generated on top; the `1.0.0` milestone is an
  explicit human specifier + a seeded section, with conventional-commits driving subsequent releases.
  *Portable by design* (a `tools/release/` module + an `nx.json` block, no repo-specific hardcoding) so it
  back-ports to the `scaffold-project` creator — a follow-up **gated on a real release cycle first** (a live
  `nx release`, not a dry-run; human directive 2026-07-30). **WO-073 implements.**

- **[D-016-IJ] Multi-boss encounters blend their co-bosses under one `encounterID` in local kill history —
  accepted, not fixed. Status: Accepted.** *Surfaced by the WO-072 adversarial review (finding #2,
  confirmed).* When one `ENCOUNTER_START` covers several bosses (Four Horsemen, Twin Emperors, Bug Trio) or
  ??-level adds, the recorder keys every boss-level (`UnitLevel == -1`) target on the single `encounterID`,
  so each co-boss death lands as a separate partial-window record under that id (their `dur`s won't equal a
  WCL whole-fight `dur`). *Why accept rather than fix:* this is a direct consequence of D-012's deliberate
  `encounterID`-keying — the two proposed code fixes were both **rejected on verification**: a per-encounter
  boss-id mapping table is exactly what D-012 refused ("no fragile encounter↔creature mapping table"), and a
  `UnitClassification == "worldboss"` gate is unverified for instanced Era bosses *and* still can't split
  equally-boss co-targets. The blend is a still-reasonable prior; the affected encounters are few; the WCL
  importer normalizes on its side. Documented in `docs/reference/kill-history-schema.md`; recorded before
  1.0 because the recorded data is irreversible. *A later CLEU/`UnitGUID`-of-boss refinement could split
  them, but is out of scope for 1.0/1.1.*

- **[D-015-IJ] 1.0.0 = "Path B" (minimal-honest, out of alpha on the released rhythm feature); local
  kill-history recording migrates to the D-012 record schema NOW. Status: Accepted.** *Decided by the human
  2026-07-30 on the 1.0.0 gap audit's recommendation (`docs/reference/v1.0.0-gap-audit.md`).* **1.0.0
  ships** on the released, held-out-validated 41-profile rhythm library + the existing sticky confidence
  gate (`minConfidenceToShow`) — **not** the regime structural-tail layer, which lands as **1.1** (D-014
  Accepted, implementation deferred). *Why that's honest:* the catastrophe that motivated D-013 (Lucifron
  1.00 confidence at 99% HP) was a **CSV data artifact** (WO-068), not a live bug — on the exact curve the
  existing gate already hides the bar ~5s and shows at 0.72 — so the gate-heavy structural bosses are a
  quality *improvement* for 1.1, not a 1.0 correctness blocker. *The one pre-1.0 MUST that IS taken now:*
  **local kill-history recording is migrated to the D-012 record schema** (encounter/creature split,
  per-kill records) — the audit's Tier-1 #3 — so kills a 1.0 user records are forward-compatible with the
  future WCL importer from day one; the old running-mean data (unrecoverable into records) is **wiped** on
  upgrade. *1.0.0's remaining gate* is then the human's in-game `/reload` verification (unchanged, still
  open) + the version bump on sign-off (D-011). WO-072 implements the migration.

- **[D-014-IJ] Regime behavior ships as injected per-encounter DATA + minimal nil-guarded seams inside the
  estimator — not a strategy-class split (refines D-013). Status: Accepted.** *Origin:* the WO-069 Phase-1
  **fable-5 + ultracode** design fan-out (4 deep-readers → 4 independent architectures → 3-judge panel)
  chose, **unanimously across all three judge lenses**, the "minimal seams" architecture: a new
  `opts.regime` injected dependency (mirroring the shipped `opts.rhythm`) consumed by ~45 **nil-guarded,
  health-anchored** lines inside `estimator.lua` — freeze bands (immune/gate/submerge), `hideBar`
  (Majordomo), `resetOnRise` (Thekal's tiger phase), `suppressFlush` (Buru's egg cliffs), and per-bin
  **confidence caps** — plus a `ns.Regimes` data table (numbers learned from the same even/odd corpus
  pipeline as the 41 rhythm profiles; categorical flags hand-authored) and a **universal raid-gate
  `confCap` default** applied to every boss-level target (fixes D-013's motivating defect: Lucifron's
  1.00 confidence at 99% HP). *Why not the full solo/party/raid strategy split D-013 sketched:* the rate
  **integrator** provably never needs to fork (solo already nails smooth curves) — only **confidence and
  phase behavior** differ, which injected regime data delivers. *The decisive constraint:* the grader
  (`tools/estimator-batch.lua`) hard-wires `sample(t,h,true)`, so the **only** way a freeze/immune
  mechanism is byte-identically provable **offline and live** is for the estimator to freeze **itself**
  off the health it already receives — one injection point, zero offline↔live divergence. *Honest about
  limits:* heal-pollution (Sulfuron/Jin'do) and second-pool/targeting-artifact bosses (Twins/Skeram) are
  **physically invisible to health polling** → the design **caps confidence** (never a fake fix) and
  reserves forward-compatible CLEU slots for a scheduled follow-up WO (WO-072). *Design of record:*
  `docs/reference/estimator-regime-design.md` (3 PR-sized increments, each gated by sim byte-identity +
  corpus regression). *Status:* **Accepted (2026-07-30).** The architecture is approved; per the human's
  1.0.0-shape decision (**Path B** — see D-015), the three implementation increments ship as **1.1**, not
  1.0.0: out-of-alpha 1.0.0 goes on the released 41-profile rhythm library + the existing confidence gate,
  and the structural-tail regime layer follows on the field this design prepared.

### 2026-07-29

- **[D-013-IJ] The estimator is restructured into regime-aware strategies (solo · party · raid) behind
  the frozen public API — not one overloaded path. Status: Accepted.** *Context:* the "chunk-clock"
  estimator (D-of-WO-056) was designed for the **solo, chunky** regime (a player far above a mob's level:
  few big discrete hits) and then stretched to party/raid. The first **real-fight** replay — an
  Anniversary MC **Lucifron** kill (`encounterID 663`), pulled through the new converter + grader — showed
  the raid regime is *structurally* different. On the **exact API pull** (per-event `hitPoints`) the
  solo-tuned chunk-clock reads systematically **long** on the raid curve (Lucifron: bias ~+9s, MAPE ~66%,
  can't anticipate the cooldown/execute acceleration) — a calmer picture than the first **CSV**
  reconstruction implied (its ~1069% MAPE / "confident 30-min adds-gate" was a data artifact: a ~5.5s
  pre-pull clock offset + cleave; corrected once the API's exact curve was used). *This is per-encounter /
  per-regime knowledge, NOT a generic tuning fault* (the human's explicit correction). *Decision (proposed):* detect the combat **regime** from context (group size ·
  target classification · event density/continuity) and route to a regime-appropriate strategy behind the
  unchanged `Estimator.new/sample/ttk` API. The **chunk-clock stays as the solo strategy** (it's strong
  there). Party/raid gain continuous-rate handling and, keyed by `encounterID`, **per-encounter rhythm
  profiles** learned from a **curated log corpus** — kills from the encounter's *relevance window*
  (release → next tier / `classicSeasonID`), spanning progression→farm and pug→speedguild as the performer
  spectrum, using exact-API curves only — used as an *anticipatory modulator* so the estimate can lead the
  acceleration instead of lagging it; **confidence becomes regime-aware** (it must not reach certainty from
  a thin, unrepresentative early window). *Method:* a **fable-5 + ultracode** design→build→adversarially-verify workflow (as WO-056),
  proven against **real fights** via the replay pipeline (`tools/wcl-*-to-fight.py` + `estimator-replay.lua`)
  plus the sim. *Why:* the regimes have irreconcilable rhythms; separating them (rather than adding more
  `if raid` branches) is what makes each correct — and the D-012 history + the log-replay loop are exactly
  the data to learn the raid path from. *Status:* **Accepted** (2026-07-29) — the human greenlit
  proceeding on **fable** ("switched to fable, but not ultracode — proceed"); the ultracode multi-agent
  design fan-out runs when the human enables it. Corpus gathering (WO-069 Phase 0) under way via the
  WO-070 engine.

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
  bump-every-build convention).** *(MECHANISM superseded by D-017 — Nx Release + Conventional Commits;
  the deliberate-release + `1.0.0`-on-human-sign-off principle below persists.)* Routine code WOs merge to `main` **without changing `## Version`**;
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
