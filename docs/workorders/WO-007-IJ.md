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
  plan** — the design (the render model, the estimator, the engine/driver split, show-gating,
  simulation, the character-derived ability model) and the **decomposition into child work orders**
  (WO-008 …). This is a **planning epic: NO code is written under this WO.** "Done" here means the
  design is agreed, the open decisions are resolved into `docs/decisions.md`, and the child-WO map is
  accepted — each child WO is then proposed, accepted, and executed on its own (branch + PR).
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
  - **Planned** (ability/item not yet used): a *static* marker of the ability's **full duration D**,
    right-anchored → its **left edge is the pop-line** ("fire when TTK reaches D"). Does not count down.
  - **Active** (used): timer starts **on use**; shows **real remaining seconds R**, draining in real
    time. Alignment vs the target bar is a live coverage readout — R > TTK ⇒ the bar pokes past the
    target's left edge ("will outlast the kill"); R < TTK ⇒ it falls short inside ("won't cover it");
    R ≈ TTK ⇒ aligned ("tracks the kill").
- **Multiple uses per fight (repeated pop-lines).** When the fight outlives an ability's **cooldown
  C**, it can be fired more than once. Working back from death, the optimal pop-lines sit at
  **TTK = D, D+C, D+2C, …** (while ≤ remaining kill): the death-most line is the *must-hit* (covers the
  kill end); each earlier line says *"use now to fit another full cast in before the end."* A planned
  utility is therefore potentially a **comb of markers spaced by its cooldown**, not a single one.
  *(This is why the human picked a long fight — Gruul — as the illustration.)*
- **Worked example (the corrected sketch):** Bloodlust (D=30) popped at TTK=30, now 5s in → R=25 and
  TTK≈25, bars aligned. Earthstrike (D=20) still **planned**, left edge at TTK=20 (pop when the kill is
  20s out). The number reads the same on every bar: **seconds of runway.**

## Architecture spine (informs the child-WO split)

- **One pure engine, three drivers.** A pure, API-light **fight-state → render-model** engine
  (`{hp, maxhp, t, buff/cooldown events} → {targetBar, utilityBars[]}`) with **no frame creation and no
  direct WoW API**, fed by one of three drivers: **live** (real events), **sim** (a scripted timeline),
  or **spec** (Busted under `tools/wow-mock`). This gives off-client testability (per the engineering
  principles) and the simulation feature for the price of one clean seam. The engine also computes the
  **repeated pop-line comb** (TTK = D, D+C, …) per ability.
- **Tracked set is character-derived (not a static class list).** A master data table maps every
  trackable on-use effect (`spellID|itemID → {duration, cooldown, category}`); the ACTIVE set is
  resolved per character from **known/talented abilities + equipped items with an on-use + racials**,
  then filtered by per-entry **enable/disable** in config. Warrior is the first data-table coverage;
  the engine/display stay class-agnostic. *(Human-confirmed mechanism; the table's contents are
  enumerated in the ability-model child WO.)*
- **Estimator is swappable — v1 is live-only.** v1 = smoothed live rate (EWMA of `UnitHealth`
  sampling). The **historical-blend** estimator (WarcraftLogs-derived per-encounter shape) is
  **explicitly deferred past the first iteration** — WO-009 only PREPARES the seam; the importer is a
  later iteration. *(Human: "prepare for it, not first iteration.")*
- **Flavor — CONFIRMED Vanilla only.** **Classic Era 1.15.x** (`WOW_PROJECT_CLASSIC`, Interface
  `115xx`), covering **normal Classic + Anniversary + Hardcore** (same client; Hardcore is a game-state,
  not a flavor). **Not TBC** (human-confirmed) — the Gruul sample log is TBC content used only to
  illustrate a long fight, never a target. Repo's **first Vanilla addon**, single-flavor **Model 1**
  (per D-004) — does **not** need the deferred both-flavor build machinery.

## Show-gating (config-driven)

- **Which raids/bosses it shows on is config-driven** (human-confirmed): a per-raid / per-boss enable
  set, seeded with a default of raid encounters + world bosses (registry by encounter / mob id;
  `IsInInstance()` == "raid"), user-adjustable.
- **Option — any chosen target** makes the bars show (for testing / general use).
- **Simulation** — first-class: **static** (frozen representative bars, for layout/anchoring) and
  **dynamic** (a scripted kill timeline animating TTK + buff usage end-to-end via the sim driver).

## Acceptance criteria (for THIS epic)

- Given this WO on `main`, When it is `Accepted`, Then **every remaining `[NEEDS CLARIFICATION]` below
  is resolved** and the resolutions are recorded as decisions in `docs/decisions.md` (D-005 …), and the
  **child-WO breakdown** below is agreed (ids/order may be edited before acceptance).
- Given the child-WO map, Then each child is small, independently verifiable, and dependency-ordered,
  and the **first Vanilla-addon** concerns (flavor tag · scoped `.luacheckrc` overlay · `115xx`
  Interface · flavor-aware mock `vanilla` surface) are captured in the scaffold child (WO-008).
- Given this is a planning epic, Then **no code, `.toc`, `.pkgmeta`, or `projects/**` change is made
  under WO-007** — all implementation lands under the child WOs (branch + PR each).

## Decisions — resolved with the human (2026-07-25) vs still open

**Resolved (to be recorded as D-005 … at Accept):**
- **Axis model — CONFIRMED:** health-fraction target bar + time-ratio utility placement (Model A);
  execute-acceleration reads as the TTK number racing ahead of the bar.
- **Flavor — CONFIRMED:** Vanilla / normal Classic Era 1.15 **only**, not TBC (Model 1). Gruul is an
  illustrative long-fight sample, not a target.
- **History source & timing — RESOLVED:** source is **WarcraftLogs**, but the import/blend is **out of
  the first iteration** — *prepare the seam only.* v1 ships the pure live-smoothed estimator.
- **Show-gating — RESOLVED:** the raids/bosses to invoke on are **config-driven** (per-raid/boss enable
  set, defaulting to raids + world bosses).
- **Tracked-ability model — RESOLVED (mechanism):** master `{spellID|itemID → duration/cooldown/
  category}` table × character scan (known/talented abilities + equipped on-use items + racials), with
  per-entry enable/disable in config. (Table CONTENTS still to enumerate — see below.)
- **Multi-use — RESOLVED (design):** abilities whose cooldown is shorter than the fight get a
  **repeated pop-line comb** (TTK = D, D+C, …); folded into the render model above.

**Still open — resolve before `Accepted`:**
- **[NEEDS CLARIFICATION: Classic 1.15 detection APIs]** Web-verify what boss/encounter detection
  exists on Era 1.15 (`ENCOUNTER_START/END`, boss frames, `C_…`) vs. registry-by-mob-id. (WO-012.)
- **[NEEDS CLARIFICATION: target scope]** Current target only for v1 (focus/boss-frame later)? Lean yes.
- **[NEEDS CLARIFICATION: estimator tuning defaults]** Smoothing-window + lead-time-offset defaults;
  whether to model the post-buff DPS jump (v1: ignore, err early).
- **[NEEDS CLARIFICATION: ability-table contents]** The concrete warrior spellIDs/itemIDs + racials
  (Death Wish, Recklessness, Sweeping Strikes, trinkets, Mighty Rage Potion, Blood Fury/Berserking…)
  and the user-editable-override format.
- **[NEEDS CLARIFICATION: idle/unknown rendering]** How bars render when TTK is unknown (pre-combat,
  rate ≤ 0, target swap, phase freeze) — blank / full / "—".
- **[NEEDS CLARIFICATION: config scope]** Whether the options surface warrants its own child WO
  (show-gating selection + ability enable/disable now live in config) — pending the config discussion.

## Proposed child-work-order breakdown (the "detailed plan")

Dependency-ordered; ids are provisional (assigned when each is drafted). Each is its own WO file,
`Proposed → Accepted → In progress → Done`, code via branch + PR.

1. **WO-008 — Scaffold `badger-ttk` (Vanilla/Era, Model 1).** New `projects/badger-ttk` (folder
   `BadgerTTK`): `.toc` `Interface 115xx` + `flavor:vanilla` tag; scoped `.luacheckrc` overlay
   (Vanilla API surface incl. `BadgerTTKDB`); `.pkgmeta` (LibStub, Ace3, LibSharedMedia?); `core.lua`
   Ace3 bootstrap; config via `BadgerConfigUI-1.0`; `Locales/enUS`. Exercises the flavor-aware mock's
   `vanilla` surface. **Milestone: repo's first Vanilla addon.** Gate green.
2. **WO-009 — Pure fight-state engine + render-model (spec-first).** The TTK live estimator (EWMA), the
   geometry math (right-anchored lengths, planned/active states, the **repeated pop-line comb**
   TTK = D, D+C, …), and a **prepared-but-unused seam** for the future historical blend. Pure, no
   frames, fully unit-tested under `tools/wow-mock`.
3. **WO-010 — Simulation driver (static + dynamic).** Slots here so it can drive display development;
   reuses the engine. Static frozen state + dynamic scripted timeline.
4. **WO-011 — Display layer (frames).** `CreateFrame` stacked bars, right-anchored, drain animation,
   `m:ss` formatting, anchoring/drag, per-bar/per-state coloring, **pop-line comb rendering**, and the
   appearance config schema. Consumes the engine render model; validated against the sim driver.
5. **WO-012 — Show-gating + encounter/world-boss registry.** Config-driven raid/boss enable set,
   raid/instance detection, mob-id registry, the "any chosen target" option. Resolves the
   1.15-detection clarification.
6. **WO-013 — Tracked-ability model (master table + character scan).** The master
   `{spellID|itemID → duration/cooldown/category}` table; a character scan (known/talented abilities +
   equipped on-use items + racials) resolving the active set; per-entry enable/disable; planned-vs-
   active + cooldown state via `UnitAura` / `GetSpellCooldown` / `GetItemCooldown`. Warrior table first.
7. **WO-014 — (POST-v1) Historical kill-data model + WarcraftLogs importer.** Deferred past the first
   iteration (human). Normalized encounter-profile schema; the live×historical blend; the paste/file
   import path (+ optional off-client Nx WCL-v2 converter). WO-009 only prepares the seam; this WO is a
   later iteration, expected to split further. Sample data on file: `fresh.warcraftlogs.com/character/
   eu/spineshatter/splynx?zone=1048&boss=50650`.
8. **(Later, out of this epic's plan)** other-class tables; focus/boss-frame scope; a defensive
   "your TTK vs the mob's TTK" mode (notable Hardcore value).

## Out of scope (this epic)

Any code / `.toc` / `.pkgmeta` / `projects/**` change; the actual implementation (all in child WOs);
non-warrior ability-table contents; the both-flavor build machinery (deferred by D-004; not needed —
badger-ttk is single-flavor Model 1); the WarcraftLogs history import/blend (post-v1 — seam only); web
fetching (addons can't — any future import is manual paste/file or an off-client tool).

- **Behavior delta:** none under this WO (planning only). In-game behavior is introduced by the child
  WOs, each noting its own delta.
- **Verification:** remaining open decisions resolved into `docs/decisions.md`; child-WO map accepted by
  the human (status → `Accepted`); `architecture.md` updated with the badger-ttk shape when the first
  child lands. No gate impact under this WO (no code).
- **Constitution check:** Principles OK — planning artifact only; the engine/driver split honors the
  API-light-testable-logic rule (§ house style / off-client testing), and the character-derived-active-
  set + swappable-estimator seams follow "simplest thing that fits, promote on a real second consumer"
  (§1.4/§1.1). No `_G` leaks (no code yet). First-Vanilla-addon flavor discipline is carried into WO-008.
- **Decisions produced:** — (D-005 … to be recorded at Accept: render model incl. multi-use comb ·
  flavor targeting · estimator approach incl. history-deferral · engine/driver architecture ·
  character-derived ability model).
- **MR:** — (none — planning epic; child WOs carry their own PRs)
- **Outcome:** 2026-07-25 — human resolved five open items: (1) axis model confirmed (Model A);
  (2) **flavor = Vanilla/normal Classic only, not TBC** (Gruul was an illustrative long fight);
  (3) history source = WarcraftLogs but **deferred out of first iteration** (prepare seam only);
  (4) raids/bosses-to-invoke-on = **config-driven**; (5) tracked abilities = **character-derived**
  (talents/known + equipped on-use + racials) against a master duration/cooldown table, enable/disable
  in config. Also captured the **multi-use / repeated-pop-line-comb** refinement. Config surface +
  history math being developed next. — (child WOs and PRs linked here as they land)
