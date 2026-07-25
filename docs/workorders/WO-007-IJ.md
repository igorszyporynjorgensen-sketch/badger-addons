---
wo: WO-007-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - CLAUDE.md
  - docs/workorders.md
  - docs/decisions.md
related:
  - docs/architecture.md
  - docs/engineering-principles.md
  - docs/workorders/WO-006-IJ.md
  - assets/images/time-to-kill-idea.webp
---

# WO-007-IJ — `badger-ttk` — the time-to-kill / optimal-cooldown-timing addon (umbrella / epic)

- **Created / Updated:** 2026-07-25
- **Objective:** define a **new Classic-Era addon, `badger-ttk`**, and produce its **phased delivery
  plan** — the design (render model, estimator, engine/driver split, show-gating, simulation, the
  character-derived ability model, the configuration surface) and the **decomposition into child work
  orders**. This is a **planning epic: NO code is written under this WO.** "Done" here means the design
  is agreed, the open decisions are resolved into `docs/decisions.md`, and the child-WO map is accepted
  — each child WO is then proposed, accepted, and executed on its own (branch + PR).
- **What the addon is (one sentence):** an on-screen stack of right-anchored bars that shows the
  estimated **time until the current target dies** and, against it, **when to fire each finite-duration
  cooldown/consumable** so its buff exactly spans the remaining kill — *don't commit a cooldown until
  its duration fits inside the remaining kill.* First class: **warrior** (open-ended for others).
  Reference sketch: [assets/images/time-to-kill-idea.webp](../../assets/images/time-to-kill-idea.webp).

## The render model (as developed with the human)

- **Axis = time until death, right edge anchored to the kill (TTK → 0).** The **target bar** is a
  health bar: full at 100% (pre-combat), shrinking rightward toward the anchor as health drops, with
  the **TTK estimate** (`m:ss`) overlaid. Empty space grows on its left.
- **Utility bars are scaled to the target bar by the time ratio** (`length = (seconds / TTK) ×
  targetBarLength`), so **left edges aligned ⇔ that buff's duration exactly spans the remaining kill.**
- **Utility bars have two states:**
  - **Planned** (not yet used): a *static* marker of the ability's **full duration D**, right-anchored
    → its **left edge is the pop-line** ("fire when TTK reaches D"). Does not count down.
  - **Active** (used): timer starts **on use**; shows **real remaining seconds R**, draining in real
    time. Alignment vs the target bar is a live coverage readout — R > TTK ⇒ pokes past the target's
    left edge ("will outlast the kill"); R < TTK ⇒ falls short inside ("won't cover it"); R ≈ TTK ⇒
    aligned ("tracks the kill").
- **Multiple uses per fight (repeated pop-lines).** When the fight outlives an ability's **cooldown
  C**, it can be fired more than once. Working back from death, the optimal pop-lines sit at
  **TTK = D, D+C, D+2C, …** (while ≤ remaining kill): the death-most line is the *must-hit* (covers the
  kill end); each earlier line says *"use now to fit another full cast in before the end."* A planned
  utility is therefore potentially a **comb of markers spaced by its cooldown**, not a single one.
  *(This is why the human picked a long fight — Gruul — as the illustration.)*
- **Stack orientation matches the sketch:** target bar at the **bottom**, utility bars grow **UP** from
  it; times as `m:ss`.
- **Worked example:** Bloodlust (D=30) popped at TTK=30, now 5s in → R=25 and TTK≈25, bars aligned.
  Earthstrike (D=20) still **planned**, left edge at TTK=20. The number means the same on every bar:
  **seconds of runway.**

## Architecture spine (informs the child-WO split)

- **One pure engine, three drivers.** A pure, API-light **fight-state → render-model** engine
  (`{hp, maxhp, t, buff/cooldown events} → {targetBar, utilityBars[]}`) with **no frame creation and no
  direct WoW API**, fed by **live** (real events), **sim** (a scripted timeline), or **spec** (Busted
  under `tools/wow-mock`). Buys off-client testability + the simulation feature from one seam. The
  engine also computes the **repeated pop-line comb** per ability.
- **Tracked set is character-derived (auto-detect, prune to taste).** A master data table maps every
  trackable on-use effect (`spellID|itemID → {duration, cooldown, category}`); a per-character scan
  (**known/talented abilities + equipped items with an on-use + racials**) **auto-populates** the active
  set, and config just lets the user **untick** what they don't want (plus free-form add/override for
  scan misses). Warrior table first; engine/display stay class-agnostic.
- **Estimator — v1 is live-only but not naive.** v1 = health-fraction **EWMA of `UnitHealth` sampling**
  (no combat-log damage-summing — keeps the math pure/testable), presented to the user as a single
  **"Reactivity ↔ Stability" slider** (not a raw seconds box). v1 **includes** an **execute-phase
  correction** (below ~20% HP a plain model over-estimates) and a **confidence gate + indicator**
  (grey/hide until trustworthy). The **historical WarcraftLogs blend** is **deferred (WO-015)** — the
  engine only *prepares* the seam.
- **History storage seam.** Kill-history is account-wide observational data → stored in **`db.global`
  (or a separate `BadgerTTKData` SV), NEVER `db.profile`** (AceDB reserves `.profiles`). The
  source-of-truth curve is `E(h)` (elapsed-time-fraction indexed by health, K=100), packed as a byte
  string; the seam is defined in the engine WO, filled in WO-015.
- **Flavor — CONFIRMED Vanilla only.** **Classic Era 1.15.x** (`WOW_PROJECT_CLASSIC`, Interface
  `115xx`), covering **normal Classic + Anniversary + Hardcore** (same client; Hardcore is a game-state,
  not a flavor). **Not TBC** — Gruul was an illustrative long-fight sample, never a target. Repo's
  **first Vanilla addon**, single-flavor **Model 1** (per D-004) — no both-flavor build machinery.

## Configuration surface (developed 2026-07-25)

Registered through `LibStub('BadgerConfigUI-1.0'):Register(...)` + AceDB `db.profile.*` closures (never
ad-hoc AceConfig, never raw SV), `childGroups='tree'`. **Gets its own dedicated child WO** (below).

| Group | v1? | Notes |
|---|---|---|
| **Display** | ✅ | anchor/size/spacing, LibSharedMedia texture+font, six state colours, `m:ss`, growth **UP**, opacity/scale/strata + `showTrendBand`/`showConfidence` |
| **Behavior / show-gating** | ✅ | `showRaidEncounters` · `showWorldBosses` · `showAnyTarget` · `inCombatOnly` · `hideOnTargetDead` · `requireHostile` · `minTTK`. Per-encounter grid → **v1.1** |
| **Estimator** | ✅ | Reactivity↔Stability slider · `leadTime` · `executeThreshold`/`executeModifier` · `minConfidenceToShow`. History-blend/min-sample knobs → **post-v1** |
| **Ability pack** | ✅ | auto-detected list, per-entry enable/disable + add/override/reset. Pack import/export → **v1.1** |
| **History data** | ⛔ | whole group is **WO-015** — absent from v1 config |
| **Simulation** | ◑ | static preview ✅ v1; dynamic playback → **v1.1** |
| **Profiles** | ✅ | drop-in `AceDBOptions-3.0` child node (needs embedding) — like badger-arena's "General" |

**Proposed defaults (adopted unless changed):** growth UP · `m:ss` · anchor RIGHT · locked · `minTTK`
10s · `leadTime` 1.5s · execute 20% / ×1.2 · opacity+scale 1.0 · palette target-red / utility-blue /
planned-amber / active-green / over-covering-grey / falling-short-orange.

## Acceptance criteria (for THIS epic)

- Given this WO on `main`, When it is `Accepted`, Then **every remaining `[NEEDS CLARIFICATION]` below
  is resolved** and the resolutions are recorded as decisions in `docs/decisions.md` (D-005 …), and the
  **child-WO breakdown** below is agreed.
- Given the child-WO map, Then each child is small, independently verifiable, and dependency-ordered,
  and the **first Vanilla-addon** concerns (flavor tag · scoped `.luacheckrc` overlay · `115xx`
  Interface · flavor-aware mock `vanilla` surface) are captured in the scaffold child.
- Given this is a planning epic, Then **no code / `.toc` / `.pkgmeta` / `projects/**` change is made
  under WO-007** — all implementation lands under the child WOs (branch + PR each).

## Decisions — resolved with the human vs still open

**Resolved (to be recorded as D-005 … at Accept):**
- **Axis model — CONFIRMED:** health-fraction target bar + time-ratio utility placement; growth UP,
  `m:ss` (both per the sketch); execute-acceleration reads as the TTK number racing ahead of the bar.
- **Flavor — CONFIRMED:** Vanilla / normal Classic Era 1.15 **only**, not TBC (Model 1).
- **History source & timing — RESOLVED:** WarcraftLogs, but **out of the first iteration** — prepare
  the seam only; v1 ships the live estimator. Stored in `db.global`/`BadgerTTKData`, `E(h)` K=100.
- **Tracked-ability model — RESOLVED:** master table × character scan; **auto-detect then prune** in
  config (untick unwanted + free-form add/override). Table contents still to enumerate.
- **Multi-use — RESOLVED (design):** repeated pop-line comb (TTK = D, D+C, …).
- **Config gets its own child WO — RESOLVED:** a dedicated **config WO** builds the tree skeleton +
  AceDB profile/global split + BadgerConfigUI registration + AceDBOptions embed; feature WOs fill their
  subtrees.
- **v1 estimator smarts — RESOLVED:** v1 EWMA **plus execute-correction + confidence gate** (not the
  dead-simple variant); presented as a Reactivity↔Stability slider; no combat-log damage-summing.

**Still open — resolve before `Accepted`:**
- **[NEEDS CLARIFICATION: Classic 1.15 detection APIs]** Web-verify boss/encounter detection on Era
  1.15 (`ENCOUNTER_START/END`, boss frames, `C_…`) vs. registry-by-mob-id. (Show-gating WO.)
- **[NEEDS CLARIFICATION: target scope]** Current target only for v1 (focus/boss-frame later)? Lean yes.
- **[NEEDS CLARIFICATION: ability-table contents]** The concrete warrior spellIDs/itemIDs + racials
  (Death Wish, Recklessness, Sweeping Strikes, trinkets, Mighty Rage Potion, Blood Fury/Berserking…).
- **[NEEDS CLARIFICATION: idle/unknown rendering]** How bars render when TTK is unknown (pre-combat,
  rate ≤ 0, target swap, phase freeze) — blank / full / "—" (interacts with the confidence gate).

## Child-work-order breakdown (the "detailed plan")

Dependency-ordered; ids are provisional (assigned when each is drafted). Each is its own WO file,
`Proposed → Accepted → In progress → Done`, code via branch + PR.

**Human priority — config before functionality.** The config-skeleton WO (#2) precedes every
functionality WO; each functionality WO (#3–#7) then *fills its own config subtree* and wires behavior
behind it. The only thing ahead of config is the **scaffold (#1)** — the empty project vessel (`.toc`,
AceDB, embeds) that config must attach to; that is plumbing, not functionality.

1. **Scaffold `badger-ttk` (Vanilla/Era, Model 1).** New `projects/badger-ttk` (folder `BadgerTTK`):
   `.toc` `Interface 115xx` + `flavor:vanilla` tag; scoped `.luacheckrc` overlay (Vanilla API surface +
   `BadgerTTKDB`); `.pkgmeta`/`.toc` embed **LibStub, Ace3, LibSharedMedia, AceDBOptions-3.0**
   (+ LibSerialize/LibDeflate reserved for later sharing); `core.lua` Ace3 bootstrap with **both
   `db.profile` (settings) and `db.global`/`BadgerTTKData` (history) namespaces**; `Locales/enUS`.
   Exercises the flavor-aware mock's `vanilla` surface. **Milestone: repo's first Vanilla addon.**
2. **Config skeleton (dedicated config WO).** The options tree via `BadgerConfigUI-1.0`; the
   profile/global split; the `profiles` group via `AceDBOptions-3.0`; real-typed defaults. Builds the
   skeleton + `display`/`behavior`/`estimator` tables; feature WOs fill their own subtrees + get/set.
3. **Pure fight-state engine + estimator (spec-first).** Health-fraction EWMA (reactivity→λ);
   **execute-correction + confidence gate**; geometry (right-anchored lengths, planned/active states,
   the **pop-line comb**); the **coverage decision logic** (fits-inside-remaining-kill / over / short);
   the **prepared-but-unused history seam** (`E(h)` K=100 in `db.global`). Pure, no frames, fully
   Busted-tested under `tools/wow-mock`.
4. **Simulation driver.** Static preview **[v1]**; dynamic scripted-timeline playback **[v1.1]**.
5. **Display layer (frames).** `CreateFrame` stacked bars (target bottom, utilities grow UP),
   right-anchored, drain animation, `m:ss`, per-bar/per-state colouring, **pop-line comb** +
   **trend/confidence** rendering, anchoring/drag; fills the `display` subtree. Validated vs the sim.
6. **Show-gating + encounter/world-boss registry.** `behavior` group; config-driven raid/boss enable;
   raid/instance detection; **verify `ENCOUNTER_START` on Era 1.15**; mob-id registry; any-target
   option; per-encounter grid deferred to v1.1.
7. **Tracked-ability model.** Master `{spellID|itemID → duration/cooldown/category}` table; character
   scan (known/talented + equipped on-use + racials) → **auto-detected active set**; per-entry
   enable/disable + add/override/reset; planned/active + cooldown state via `UnitAura` /
   `GetSpellCooldown` / `GetItemCooldown`. Warrior table first; pack import/export deferred to v1.1.
8. **(POST-v1) Historical kill-data model + WarcraftLogs importer.** Deferred. `E(h)` recompute,
   weighted percentiles + baseline ranges ("usually 2:37–4:21 · best 2:14"), the live×history blend,
   the `history` config group, paste/SV import (LibSerialize+LibDeflate), + an off-client Nx
   `tools/wcl-import` WCL-v2 converter. Fills the engine seam. Sample data on file:
   `fresh.warcraftlogs.com/character/eu/spineshatter/splynx?zone=1048&boss=50650`.
9. **(Later, out of this epic's plan)** other-class tables; focus/boss-frame scope; a defensive
   "your TTK vs the mob's TTK" mode (notable Hardcore value).

## Out of scope (this epic)

Any code / `.toc` / `.pkgmeta` / `projects/**` change; the actual implementation (all in child WOs);
non-warrior ability-table contents; the both-flavor build machinery (deferred by D-004; not needed);
the WarcraftLogs history import/blend (post-v1 — seam only); web fetching (addons can't — any future
import is manual paste/file or an off-client tool).

- **Behavior delta:** none under this WO (planning only). In-game behavior is introduced by the child
  WOs, each noting its own delta.
- **Verification:** remaining open decisions resolved into `docs/decisions.md`; child-WO map accepted by
  the human (status → `Accepted`); `architecture.md` updated with the badger-ttk shape when the first
  child lands. No gate impact under this WO (no code).
- **Constitution check:** Principles OK — planning artifact only; the engine/driver split honors the
  API-light-testable-logic rule (§ house style / off-client testing); the character-derived-active-set,
  swappable-estimator, and dedicated-config-skeleton seams follow "simplest thing that fits, promote on
  a real second consumer" (§1.4/§1.1). No `_G` leaks (no code yet). First-Vanilla-addon flavor
  discipline is carried into the scaffold WO.
- **Decisions produced:** — (D-005 … to be recorded at Accept: render model incl. multi-use comb ·
  flavor targeting · estimator approach incl. execute-correction/confidence + history-deferral +
  `db.global` storage seam · engine/driver architecture · character-derived auto-detect ability model ·
  dedicated config skeleton).
- **MR:** — (none — planning epic; child WOs carry their own PRs)
- **Outcome:** 2026-07-25 — human resolved axis/flavor/history-defer/ability/config-scope/estimator
  and the multi-use comb (see Decisions above). Config surface developed via research (7 groups, v1 vs
  v1.1 vs post-v1 tagged) with two architecture corrections folded in — history in `db.global` (not
  `db.profile`), and a health-fraction EWMA estimator surfaced as a Reactivity↔Stability slider (not
  combat-log damage-summing). Three follow-up calls: **config gets its own WO**, ability list is
  **auto-detect-then-prune**, v1 estimator **includes execute-correction + confidence gate.** Remaining
  open items are the four `[NEEDS CLARIFICATION]` above. — (child WOs and PRs linked here as they land)
