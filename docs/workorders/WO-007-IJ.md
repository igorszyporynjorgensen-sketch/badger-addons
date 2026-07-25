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
  simulation, the warrior ability pack) and the **decomposition into child work orders** (WO-008 …).
  This is a **planning epic: NO code is written under this WO.** "Done" here means the design is
  agreed, the open decisions are resolved into `docs/decisions.md`, and the child-WO map is accepted —
  each child WO is then proposed, accepted, and executed on its own (branch + PR).
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
- **Worked example (the corrected sketch):** Bloodlust (D=30) popped at TTK=30, now 5s in → R=25 and
  TTK≈25, bars aligned. Earthstrike (D=20) still **planned**, left edge at TTK=20 (pop when the kill is
  20s out). The number reads the same on every bar: **seconds of runway.**

## Architecture spine (informs the child-WO split)

- **One pure engine, three drivers.** A pure, API-light **fight-state → render-model** engine
  (`{hp, maxhp, t, buff/cooldown events} → {targetBar, utilityBars[]}`) with **no frame creation and no
  direct WoW API**, fed by one of three drivers: **live** (real events), **sim** (a scripted timeline),
  or **spec** (Busted under `tools/wow-mock`). This gives off-client testability (per the engineering
  principles) and the simulation feature for the price of one clean seam.
- **Class = data pack, not code.** A class contributes a table of `{spellID|itemID, duration,
  cooldown, category}`; the engine and display are class-agnostic. Warrior ships first.
- **Estimator is swappable.** v1 = smoothed live rate (EWMA of `UnitHealth` sampling); v2 blends a
  **historical per-encounter shape** (imported) to handle acceleration/phases. Same engine seam.
- **Flavor:** **Classic Era 1.15.x** (`WOW_PROJECT_CLASSIC`, Interface `115xx`) — one flavor covers
  **Anniversary + Hardcore + normal Era** (same client; Hardcore is a game-state, not a flavor). This
  is the repo's **first Vanilla addon**, single-flavor **Model 1** (per D-004) — it does **not** need
  the deferred both-flavor build machinery.

## Show-gating (config-driven)

- **Default:** raid encounters in raid instances + world bosses only (registry-driven by encounter /
  mob id; `IsInInstance()` == "raid").
- **Option — any chosen target** makes the bars show (for testing / general use).
- **Simulation** — first-class: **static** (frozen representative bars, for layout/anchoring) and
  **dynamic** (a scripted kill timeline animating TTK + buff usage end-to-end via the sim driver).

## Acceptance criteria (for THIS epic)

- Given this WO on `main`, When it is `Accepted`, Then **every `[NEEDS CLARIFICATION]` below is
  resolved** and the resolutions are recorded as decisions in `docs/decisions.md` (D-005 …), and the
  **child-WO breakdown** below is agreed (ids/order may be edited before acceptance).
- Given the child-WO map, Then each child is small, independently verifiable, and dependency-ordered,
  and the **first Vanilla-addon** concerns (flavor tag · scoped `.luacheckrc` overlay · `115xx`
  Interface · flavor-aware mock `vanilla` surface) are captured in the scaffold child (WO-008).
- Given this is a planning epic, Then **no code, `.toc`, `.pkgmeta`, or `projects/**` change is made
  under WO-007** — all implementation lands under the child WOs (branch + PR each).

## Open decisions — resolve before `Accepted` (become D-005 …)

- **[NEEDS CLARIFICATION: axis model]** Confirm **health-fraction target bar + time-ratio utility
  placement** (Model A, matches the human's "full at 100% health" description) over a pure time-linear
  axis (Model B). Confirm how execute-acceleration should read (TTK number racing ahead of the bar).
- **[NEEDS CLARIFICATION: Classic 1.15 detection APIs]** Web-verify (like WO-006) which encounter/boss
  detection exists on Era 1.15 — `ENCOUNTER_START`/`END`, boss unit frames, `C_...` encounter APIs —
  vs. registry-by-mob-id. Determines the show-gating child (WO-011).
- **[NEEDS CLARIFICATION: history data source + schema]** Which export ("raidlog"? WarcraftLogs?
  Classic logs site?) — need a **sample paste** to define the normalized import schema and whether an
  off-client Nx converter tool is warranted.
- **[NEEDS CLARIFICATION: estimator v1 scope]** Ship v1 with **pure live-smoothed** TTK + a couple of
  hand-authored boss profiles, with import deferred to a later child? Confirm smoothing window and a
  **lead-time offset** (pop slightly early for GCD/latency); decide whether to model the post-buff DPS
  jump (v1: ignore, err early).
- **[NEEDS CLARIFICATION: target scope]** Current target only for v1 (focus/boss-frame later)? Confirm.
- **[NEEDS CLARIFICATION: warrior default pack]** Which cooldowns are in the shipped default —
  Death Wish (30s/3m), Recklessness (15s/30m — include given the long CD?), Blood Fury, Berserking,
  trinkets (Earthstrike, Kiss of the Spider, Slayer's Crest, Diamond Flask), Mighty Rage Potion, Juju
  Flurry, engineering gadgets — and the user-editable-list format.
- **[NEEDS CLARIFICATION: idle/unknown rendering]** How bars render when TTK is unknown (pre-combat,
  rate ≤ 0, target swap, phase freeze) — blank / full / "—".

## Proposed child-work-order breakdown (the "detailed plan")

Dependency-ordered; ids are provisional (assigned when each is drafted). Each is its own WO file,
`Proposed → Accepted → In progress → Done`, code via branch + PR.

1. **WO-008 — Scaffold `badger-ttk` (Vanilla/Era, Model 1).** New `projects/badger-ttk` (folder
   `BadgerTTK`): `.toc` `Interface 115xx` + `flavor:vanilla` tag; scoped `.luacheckrc` overlay
   (Vanilla API surface incl. `BadgerTTKDB`); `.pkgmeta` (LibStub, Ace3, LibSharedMedia?); `core.lua`
   Ace3 bootstrap; config via `BadgerConfigUI-1.0`; `Locales/enUS`. Exercises the flavor-aware mock's
   `vanilla` surface. **Milestone: repo's first Vanilla addon.** Gate green.
2. **WO-009 — Pure fight-state engine + render-model (spec-first).** The TTK live estimator (EWMA) and
   the geometry math (right-anchored lengths, planned/active utility states, pop-line). Pure, no
   frames, fully unit-tested under `tools/wow-mock`.
3. **WO-010 — Simulation driver (static + dynamic).** Slots here so it can drive display development;
   reuses the engine. Static frozen state + dynamic scripted timeline.
4. **WO-011 — Display layer (frames).** `CreateFrame` stacked bars, right-anchored, drain animation,
   `m:ss` formatting, anchoring/drag, per-bar coloring + the appearance config schema. Consumes the
   engine render model; validated against the sim driver.
5. **WO-012 — Show-gating + encounter/world-boss registry.** Raid/instance detection, mob-id registry,
   the "any chosen target" option, config toggles. Resolves the 1.15-detection clarification.
6. **WO-013 — Warrior ability pack + aura/cooldown tracking.** The curated warrior list feeding
   planned-vs-active state via `UnitAura` / `GetSpellCooldown` / `GetItemCooldown`; user-editable list.
7. **WO-014 — Historical kill-data model + importer.** Normalized encounter-profile schema; the
   live×historical blending estimator; the paste/file import path (+ optional off-client Nx converter).
   Largest/riskiest — expected to split further; v1 may ship hand-authored profiles only.
8. **(Later, out of this epic's plan)** other-class packs; focus/boss-frame scope; a defensive
   "your TTK vs the mob's TTK" mode (notable Hardcore value).

## Out of scope (this epic)

Any code / `.toc` / `.pkgmeta` / `projects/**` change; the actual implementation (all in child WOs);
non-warrior classes; the both-flavor build machinery (deferred by D-004; not needed — badger-ttk is
single-flavor Model 1); web fetching (addons can't — import is manual paste/file).

- **Behavior delta:** none under this WO (planning only). In-game behavior is introduced by the child
  WOs, each noting its own delta.
- **Verification:** open decisions resolved into `docs/decisions.md`; child-WO map accepted by the
  human (status → `Accepted`); `architecture.md` updated with the badger-ttk shape when the first child
  lands. No gate impact under this WO (no code).
- **Constitution check:** Principles OK — planning artifact only; the engine/driver split honors the
  API-light-testable-logic rule (§ house style / off-client testing), and the class-pack-as-data and
  swappable-estimator seams follow "simplest thing that fits, promote on a real second consumer"
  (§1.4/§1.1). No `_G` leaks (no code yet). First-Vanilla-addon flavor discipline is carried into WO-008.
- **Decisions produced:** — (D-005 … to be recorded as the open decisions above are resolved:
  render model · flavor targeting · estimator approach · engine/driver architecture).
- **MR:** — (none — planning epic; child WOs carry their own PRs)
- **Outcome:** — (running notes; the child WOs and their PRs will be linked here as they land)
