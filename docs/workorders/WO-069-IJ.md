---
wo: WO-069-IJ
status: Accepted
assigned: IJ
mr: ~
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-068-IJ.md
related:
  - projects/badger-ttk/src/engine/estimator.lua
  - tools/estimator-replay.lua
  - tools/estimator-sim.lua
  - docs/reference/estimator-replay.md
---

# WO-069-IJ — Estimator regime-aware overhaul (fable + ultracode)

- **Created:** 2026-07-29
- **Anchor decision:** [D-013-IJ] — restructure the estimator into regime-aware strategies behind the
  frozen public API, rather than one overloaded path.
- **Objective — from the human:** *"the estimator might need a structural overhaul… we are asking too many
  functions to do 2+ very different things (raid / party / solo)."* Stop stretching the solo-tuned
  chunk-clock across three structurally different combat regimes; give each regime the handling its rhythm
  needs, and let the raid path learn each **encounter's** shape from logs.
- **The three regimes (why one path can't serve all):**
  - **Solo** — a player far above the mob: few big discrete hits, long gaps. The chunk-clock's home turf.
  - **Party (5-man)** — mixed: some continuity, dungeon-boss mechanics, smaller execute swings.
  - **Raid** — many overlapping attackers → smooth continuous chip, **plus** adds gates, immune/mechanic
    phases, execute + Bloodlust/cooldown **acceleration**. Proven structurally different by the Lucifron
    replay (WO-068): confidence hit 1.00 at 99% HP during the adds gate.
- **Approach (behind the unchanged `Estimator.new/sample/ttk` API):**
  1. **Regime detection** from context — group size, target classification (world/dungeon/raid boss vs
     trash), event density/continuity. Cheap, sticky, re-evaluated on target change.
  2. **Strategy per regime.** Solo = today's chunk-clock (kept). Party/raid = continuous-rate handling +,
     keyed by `encounterID`, **per-encounter rhythm profiles** (adds-down HP · execute HP · end-game
     multiplier) learned from logs, used as an **anticipatory modulator** so the estimate leads known
     acceleration instead of lagging it.
  3. **Regime-aware confidence** — a steady high-HP trickle during an adds gate must read low-confidence
     (bar stays hidden), fixing the Lucifron over-confidence without a generic retune.
- **Method:** a **fable-5 + ultracode** workflow like WO-056 — analyse → N architecture proposals → judge
  panel → synthesise → implement → **adversarial verify**, every step **graded against real fights**
  (`tools/estimator-replay.lua` on a corpus of WCL pulls) and the sim (`tools/estimator-sim.lua`). The
  chunk-clock's solo numbers must not regress.
- **Depends on (before execution):** (a) **human acceptance** of D-013; (b) the **fable + ultracode**
  session (the human switches the model/mode); (c) a **real-fight corpus** — pull more encounters via the
  API converter (needs a read-only WCL client id/secret) so the design is proven on data, not the sample.
- **Constitution check:** Principles OK — the public API stays frozen (§ house-style: engine is
  API-light, Ace-free, specced); per-regime strategies are separate modules with colocated specs; no `_G`
  leak; no version bump until a release (D-011). Verified in-game with `/reload` before Done.
- **Acceptance:** regimes routed correctly; real-fight MAPE on raid encounters materially improved with
  the bar correctly hidden during adds/immune phases; solo (chunk-clock) grades unchanged; sim + real
  corpus + specs green; `/reload` confirmed.

**Phase 0** 1. [x] D-013 Accepted (2026-07-29) · [ ] corpus — in progress: Fresh MC ×10 + BWL ×8 + AQ ×2
(each raid sampled from its own relevance window; Onyxia/Patchwerk excluded — their rankings predate Fresh,
a different variant's population). 2. [x] fable on · [ ] ultracode — deferred; the multi-agent design
fan-out runs when the human enables it.
**Phase 1** 1. [ ] Design workflow → synthesised regime architecture.
**Phase 2** 1. [ ] Implement behind the frozen API (chunk-clock preserved as the solo strategy).
**Phase 3** 1. [ ] Adversarial verify + grade vs real corpus & sim → PR.
