---
wo: WO-007-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
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
  character-derived ability model, a skinnable display, and the configuration surface) and the
  **decomposition into child work orders**. This is a **planning epic: NO code is written under this
  WO.** "Done" here means the design is agreed, the decisions are recorded in `docs/decisions.md`, and
  the child-WO map is accepted — each child WO is then proposed, accepted, and executed on its own.
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
    time. Alignment vs the target bar is a live coverage readout — R > TTK ⇒ pokes past ("outlasts the
    kill"); R < TTK ⇒ falls short inside ("won't cover it"); R ≈ TTK ⇒ aligned ("tracks the kill").
- **Multiple uses per fight (repeated pop-lines).** When the fight outlives an ability's **cooldown
  C**, the optimal pop-lines sit at **TTK = D, D+C, D+2C, …** (while ≤ remaining kill): the death-most
  line is the *must-hit*; each earlier line says *"use now to fit another full cast in before the end."*
  A planned utility is therefore potentially a **comb of markers spaced by its cooldown**.
- **Stack orientation matches the sketch:** target bar at the **bottom**, utility bars grow **UP**; `m:ss`.
- **Worked example:** Bloodlust (D=30) popped at TTK=30, 5s in → R=25, TTK≈25, aligned. Earthstrike
  (D=20) still **planned**, left edge at TTK=20. The number means the same on every bar: seconds of runway.

## Architecture spine (informs the child-WO split)

- **One pure engine, three drivers.** A pure, API-light **fight-state → render-model** engine
  (`{hp, maxhp, t, buff/cooldown events} → {targetBar, utilityBars[]}`) with **no frame creation and no
  direct WoW API**, fed by **live** / **sim** / **spec** (Busted under `tools/wow-mock`). Off-client
  testability + the simulation feature from one seam. The engine computes the **pop-line comb** per ability.
- **Display is skin-driven, and skins are open/addable.** The display never hardcodes looks — it renders
  from a **skin table** `{ media (statusbar texture + border via LibSharedMedia), one font family + two
  font-sizes (the main TTK number · all other bars), state colours, bar metrics (height/spacing/inset),
  spark }`. A skin owns *look only* — **placement & size** (anchor, position, scale, growth, width,
  opacity) stay user-config outside the skin, so a shared skin looks right wherever it's dropped. A public **`RegisterSkin(name, skinTable)` API** lets **anyone** ship a skin (a tiny addon or
  a pasted file that registers on load); built-in skins ship with the addon; all registered skins appear
  in the config **skin picker**, over which per-element overrides still apply. **Data-driven (no code) in
  v1** for safety; an optional post-layout hook can come later. *(If a second Badger addon wants
  skinning, the registry graduates to a shared `BadgerSkin-1.0` lib per §1.1 — not yet.)*
- **Tracked set = a static complete master table + a live availability overlay.** A master data table
  lists **every DPS-relevant, finite, timed on-use effect a warrior can pop**
  (`spellID|itemID → {duration, cooldown, category}`) — **not** defensives, passives, or long-duration
  maintained buffs — and it does **not** shrink to the current character. Config shows the **full list**, each entry
  enable/disable-able. A live character scan (**talents/known abilities + equipped on-use items + race +
  profession**) marks each entry **available or not-currently-available** (dimmed + icon) rather than
  hiding it, so the user can pre-configure for gear/specs they don't have yet. **Runtime shows a bar only
  for entries that are enabled AND currently available.** Free-form add/override covers table misses.
  Warrior table first; engine/display class-agnostic.
- **Estimator — v1 is live-only but not naive.** v1 = health-fraction **EWMA of `UnitHealth` sampling**
  (no combat-log damage-summing — keeps the math pure/testable), surfaced as a **"Reactivity ↔ Stability"
  slider**. v1 **includes** an **execute-phase correction** (below ~20% HP a plain model over-estimates)
  and a **confidence gate + indicator**. The **historical WarcraftLogs blend** is **deferred (WO #8)** —
  the engine only *prepares* the seam.
- **History storage seam.** Account-wide observational data → **`db.global`/`BadgerTTKData`, NEVER
  `db.profile`** (AceDB reserves `.profiles`). Source-of-truth curve `E(h)` (elapsed-time-fraction by
  health, K=100), packed as a byte string; seam defined in the engine WO, filled in WO #8.
- **Flavor — CONFIRMED Vanilla only.** **Classic Era 1.15.x** (`WOW_PROJECT_CLASSIC`, Interface
  `115xx`), covering **normal Classic + Anniversary + Hardcore**. **Not TBC** (Gruul was an illustrative
  long fight). Repo's **first Vanilla addon**, single-flavor **Model 1** (per D-004).

## Configuration surface (developed 2026-07-25)

Registered through `LibStub('BadgerConfigUI-1.0'):Register(...)` + AceDB `db.profile.*` closures (never
ad-hoc AceConfig, never raw SV), `childGroups='tree'`. **Gets its own dedicated child WO** (#2 below).
*(Note: `BadgerConfigUI-1.0` skins the **config window**; skinning the **addon bars** is the separate
skin layer above.)*

**Tree (agreed order):** General · Behavior · Raids · Skin · Display · Estimator · Abilities ·
Simulation · Profiles. **Skin** and **Raids** are their own nodes; **General** is the landing node.

| Node | v1? | Contents |
|---|---|---|
| **General** | ✅ | master `Enable` + a short status/help blurb (landing node) |
| **Behavior** | ✅ | general rules — `inCombatOnly` · `hideOnTargetDead` · `requireHostile` · `minTTK` · `showAnyTarget` (testing). Detailed where-it-shows → **Raids** |
| **Raids** *(own node)* | ✅ | per-raid sub-nodes: a **raid master toggle** + **per-encounter checkboxes** (default all on); a **World Bosses** grouping. Backed by an authored Vanilla raid/encounter registry (mob/encounter ids). *Per-encounter gating: v1.1 → **v1**.* |
| **Skin** *(own node)* | ✅ | skin picker (built-in + registered) · one font family + two sizes (main TTK · other bars) · texture · border · 6 state colours. Skin paste-import → **v1.1** |
| **Display** | ✅ | *Layout* — anchor/position/scale/growth **UP**/width/height/spacing/opacity/strata/max-bars · *Readout* — names/timers/icons · `m:ss` · `showTrendBand`/`showConfidence` |
| **Estimator** | ✅ | Reactivity↔Stability slider · `leadTime` · `executeThreshold`/`executeModifier` · `minConfidenceToShow`. History-blend/min-sample → **post-v1** |
| **Abilities** | ✅ | full **static** master list (everything a warrior can use), enable/disable per entry; **availability overlay** (dim + icon for not-currently-available) from the live scan; add/override/reset. Runtime shows enabled ∩ available. Pack import/export → **v1.1** |
| **Simulation** | ◑ | static preview ✅ v1; dynamic playback → **v1.1** |
| **Profiles** | ✅ | drop-in `AceDBOptions-3.0` child node (needs embedding) |
| **History** | ⛔ | whole node is **WO #8** — absent from the v1 tree |

**Proposed defaults (adopted unless changed):** growth UP · `m:ss` · anchor RIGHT · locked · `minTTK`
10s · `leadTime` 1.5s · execute 20% / ×1.2 · opacity+scale 1.0 · a shipped **"Badger" default skin**
(brand texture/font, palette target-red / utility-blue / planned-amber / active-green / over-grey /
short-orange).

## Acceptance criteria (for THIS epic) — MET

- The design + decisions are agreed and recorded here; the four residual unknowns are **delegated to
  their owning child WOs** (below), so the epic itself carries no blocking clarification.
- The child-WO map is accepted; the **first Vanilla-addon** concerns are captured in the scaffold child.
- **No code / `.toc` / `.pkgmeta` / `projects/**` change under WO-007** — all implementation lands under
  the child WOs (branch + PR each). **Accepted by the human 2026-07-25** ("I approve of all").

## Decisions — resolved with the human

To be recorded as D-005 … in `docs/decisions.md` when the first child WO lands:
- **Render model:** health-fraction target bar + time-ratio utility placement; growth UP, `m:ss`;
  two-state utilities; **multi-use pop-line comb** (TTK = D, D+C, …).
- **Flavor:** Vanilla / normal Classic Era 1.15 **only**, not TBC (Model 1).
- **Estimator:** live-only v1 = health-fraction EWMA (Reactivity↔Stability slider) **+ execute-correction
  + confidence gate**, no combat-log damage-summing; WarcraftLogs blend deferred; history in `db.global`.
- **Tracked-ability model:** a **static, complete** master table shown in full in config (enable/disable
  per entry) + a **live availability overlay** (dim/icon for not-currently-available); runtime shows
  **enabled ∩ available**. Not auto-pruned to the current character. **Table scope = offensive, finite,
  timed burst effects** (AP/haste/crit/str/damage on-use) worth timing to a kill — **excludes**
  defensives (Shield Wall/Stoneform…), passives (Perception/procs/on-equip), and long-duration
  maintained buffs (Winterfall Firewater, elixirs/flasks). *(Defensives may return with the deferred
  "your TTK vs the mob's" mode.)*
- **Skinnable UI:** display is skin-driven; **user-authored, addable skins** via a public data-driven
  registry API; built-in skins; fonts + sizes global and per-element.
- **Config gets its own child WO;** config precedes functionality.
- **Config tree:** landing **General** node; order General → Behavior → Raids → Skin → Display →
  Estimator → Abilities → Simulation → Profiles; **Skin** and **Raids** are their own nodes. The
  **Raids** node = per-raid master toggle + **per-encounter checkboxes** (default on) → **per-encounter
  gating is v1** (needs an authored Vanilla raid/encounter registry).

## Delegated to owning child WOs (resolved when that child is drafted)

- **[Classic 1.15 detection APIs]** — web-verify `ENCOUNTER_START/END` / boss frames / `C_…` vs. mob-id
  registry → **show-gating WO (#6)**.
- **[target scope]** — current target only for v1 (focus/boss later)? Lean yes → **display/engine (#3/#5)**.
- **[ability-table contents]** — the concrete warrior spellIDs/itemIDs + racials → **ability WO (#7)**.
- **[idle/unknown rendering]** — bars when TTK unknown (pre-combat, rate ≤ 0, swap, phase) vs. the
  confidence gate → **display WO (#5)**.

## Child-work-order breakdown (the "detailed plan")

Dependency-ordered; ids provisional (assigned when each is drafted). Each is its own WO file,
`Proposed → Accepted → In progress → Done`, code via branch + PR.

**Human priority — config before functionality.** The config-skeleton WO (#2) precedes every
functionality WO; each functionality WO (#3–#7) then *fills its own config subtree* and wires behavior
behind it. The only thing ahead of config is the **scaffold (#1)** — the empty project vessel (`.toc`,
AceDB, embeds) that config must attach to; that is plumbing, not functionality.

1. **Scaffold `badger-ttk` (Vanilla/Era, Model 1).** `projects/badger-ttk` (folder `BadgerTTK`): `.toc`
   `Interface 115xx` + `flavor:vanilla`; scoped `.luacheckrc` overlay (+ `BadgerTTKDB`); `.pkgmeta`/`.toc`
   embed **LibStub, Ace3, LibSharedMedia, AceDBOptions-3.0** (+ LibSerialize/LibDeflate reserved);
   `core.lua` Ace3 bootstrap with **`db.profile` + `db.global`/`BadgerTTKData`**; `Locales/enUS`.
   Exercises the mock's `vanilla` surface. **Milestone: repo's first Vanilla addon.**
2. **Config skeleton (dedicated config WO).** The options tree via `BadgerConfigUI-1.0`; profile/global
   split; `profiles` via `AceDBOptions-3.0`; real-typed defaults. Builds skeleton + `display`(incl. the
   **skin picker + font/size controls**)/`behavior`/`estimator` tables; feature WOs fill their subtrees.
3. **Pure fight-state engine + estimator (spec-first).** Health-fraction EWMA (reactivity→λ);
   **execute-correction + confidence gate**; geometry (pop-line comb) + **coverage decision logic**
   (fits/over/short); the **prepared-but-unused history seam** (`E(h)` K=100 in `db.global`). Pure, no
   frames, Busted-tested under `tools/wow-mock`.
4. **Simulation driver.** Static preview **[v1]**; dynamic scripted-timeline playback **[v1.1]**.
5. **Display layer (frames) + skin engine.** `CreateFrame` stacked bars (target bottom, grow UP),
   right-anchored, drain animation, `m:ss`, per-state colouring, pop-line comb + trend/confidence
   rendering, anchoring/drag. **The skin system: the documented skin-table format (a public contract),
   the `RegisterSkin` API, built-in skins, and rendering from the selected skin + overrides.** Fills the
   `display` subtree; validated vs the sim.
6. **Show-gating — Behavior + Raids nodes + encounter registry.** `behavior` general rules; the
   **Raids** node (per-raid master toggle + **per-encounter checkboxes**, default on) + a **World
   Bosses** grouping, backed by an **authored Vanilla raid/encounter registry** (mob/encounter ids);
   raid/instance detection + **verify `ENCOUNTER_START` on Era 1.15** to map the target to a registry
   entry; any-target testing option. **Per-encounter gating is v1** (not v1.1).
7. **Tracked-ability model.** The **static complete** master table; the config list shown in **full**
   (enable/disable per entry) with a **live availability overlay** (talents/known + equipped on-use +
   race + profession → available vs dimmed + icon); add/override/reset; planned/active + cooldown state
   via `UnitAura` / `GetSpellCooldown` / `GetItemCooldown`; **runtime shows enabled ∩ available**.
   Warrior table first; pack import/export → v1.1.
8. **(POST-v1) Historical kill-data model + WarcraftLogs importer.** `E(h)` recompute, weighted
   percentiles + baseline ranges ("usually 2:37–4:21 · best 2:14"), the live×history blend, the
   `history` config group, paste/SV import (LibSerialize+LibDeflate), + an off-client Nx `tools/wcl-import`
   WCL-v2 converter. Fills the engine seam. Sample data:
   `fresh.warcraftlogs.com/character/eu/spineshatter/splynx?zone=1048&boss=50650`.
9. **(Later)** other-class tables; focus/boss-frame scope; a defensive "your TTK vs the mob's TTK" mode.

## Out of scope (this epic)

Any code / `.toc` / `.pkgmeta` / `projects/**` change; the actual implementation (all in child WOs);
non-warrior ability-table contents; the both-flavor build machinery (deferred by D-004; not needed);
the WarcraftLogs history import/blend (post-v1 — seam only); skin *code hooks* (v1 skins are data-only);
web fetching (addons can't).

- **Behavior delta:** none under this WO (planning only). Each child WO notes its own delta.
- **Verification:** decisions recorded into `docs/decisions.md` when the first child lands;
  `architecture.md` updated with the badger-ttk shape then. No gate impact under this WO (no code).
- **Constitution check:** Principles OK — planning artifact only; engine/driver split honors the
  API-light-testable rule; skin-registry, character-derived-active-set, swappable-estimator, and
  dedicated-config-skeleton seams follow "simplest thing that fits, promote on a real second consumer"
  (§1.4/§1.1). No `_G` leaks (no code yet).
- **Decisions produced:** — (D-005 … recorded at first-child-drop: render model incl. multi-use comb ·
  flavor · estimator incl. execute/confidence + history-deferral + `db.global` seam · engine/driver
  architecture · character-derived ability model · open skin system · dedicated config skeleton).
- **MR:** — (none — planning epic; child WOs carry their own PRs)
- **Outcome:** 2026-07-25 — **Accepted by the human** ("I approve of all"). Design fully developed:
  render model (+ multi-use comb), Vanilla flavor, live-only-but-smart estimator (execute + confidence),
  auto-detect ability model, `db.global` history seam, a 7-group config surface (config precedes
  functionality, dedicated config WO), and an **open user-authored skin system** (data-driven skin
  format + `RegisterSkin` API + built-in skins + global/per-element fonts & sizes). Four residual
  unknowns delegated to their child WOs. Next: config discussion, then draft the scaffold + config child
  WOs. — (child WOs and PRs linked here as they land)
