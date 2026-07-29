---
wo: WO-069-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/75
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
  4. **Rhythm modifier as an injected dependency (the human's architecture, 2026-07-29):** the estimator
     stays pure — `Estimator.new(opts)` gains an optional `opts.rhythm` (a per-encounter profile: kill-rate
     shape vs health remaining). Profiles are **data**, learned offline from log corpora and shipped as
     defaults for raid bosses (later blended with the D-012 local history); the **driver** resolves which
     profile to inject from `ENCOUNTER_START`'s encounterID, and no profile ⇒ today's behavior. Live
     observation calibrates the *scale* (this group's speed); the profile supplies the *shape* (what the
     fight does next) — the anticipatory fix for the reads-long bias. Candidates iterate in `tools/`
     (`ttk-lab.py grade --est`) and only touch the shipped estimator once the loop proves an improvement.
     Loop-1 note: learning and grading on the same 20 kills proves the *mechanism*; validation on freshly
     hunted kills follows in the next loop (corpus refreshes between loops).
- **Method:** a **fable-5 + ultracode** workflow like WO-056 — analyse → N architecture proposals → judge
  panel → synthesise → implement → **adversarial verify**, every step **graded against real fights**
  (`tools/estimator-replay.lua` on a corpus of WCL pulls) and the sim (`tools/estimator-sim.lua`). The
  chunk-clock's solo numbers must not regress.
- **The learning loop — protocol from the human (2026-07-29):** *"run the same fight from various sources
  to sim against, and after each batch is run, you learn and then run the same volume again and see if you
  do better or worse — then repeat as many times as we want."* Concretely: **freeze the corpus** (the exam
  never changes mid-loop) → grade the candidate (`python3 tools/ttk-lab.py grade --est <candidate.lua>`)
  → read *where/why* it drifted → change the estimator → **re-grade the SAME volume** → compare the delta
  (scoreboard run N vs N−1, web dashboard trend) → repeat at will. Corpus refreshes happen *between*
  loops, never inside one. Baseline to beat (run 2, 126 kills): mean MAPE 117.1% · median 41.5% · bias
  +17.7s · within-15% 26.1%.
- **Depends on (before execution):** (a) **human acceptance** of D-013; (b) the **fable + ultracode**
  session (the human switches the model/mode); (c) a **real-fight corpus** — pull more encounters via the
  API converter (needs a read-only WCL client id/secret) so the design is proven on data, not the sample.
- **Constitution check:** Principles OK — the public API stays frozen (§ house-style: engine is
  API-light, Ace-free, specced); per-regime strategies are separate modules with colocated specs; no `_G`
  leak; no version bump until a release (D-011). Verified in-game with `/reload` before Done.
- **Acceptance:** regimes routed correctly; real-fight MAPE on raid encounters materially improved with
  the bar correctly hidden during adds/immune phases; solo (chunk-clock) grades unchanged; sim + real
  corpus + specs green; `/reload` confirmed.

- **Loop 1 outcome (PR #75, 2026-07-29):** the rhythm-DI mechanism is **proven**. Lucifron's profile
  (learned by `tools/learn-rhythm.py` from the human's frozen 20-kill hunt: pull-gate 0.30× → steady
  ~1.0–1.3× → execute 1.5–1.85×) injected via `opts.rhythm` in the candidate
  (`tools/candidates/estimator-rhythm.lua`): mean MAPE **34.7% → 21.1%**, median 39.4% → 20.0%, p90
  49.8% → 30.7%, bias +2.9s → +1.1s, within-15% 30.7% → 53.8%, **better on 18/20 kills**, bar-shown
  identical (confidence untouched). Scoreboard run 3; dashboard refreshed. Next loop: validate on fresh
  kills (train/test), more encounters' profiles, then the driver-side wiring to ship.

- **Loop 2 outcome (PR #76, 2026-07-29):** the validation **holds on unseen kills**. Lucifron ×50, trained
  on the 25-kill even/odd TRAIN half only: held-out 25 mean MAPE **35.5% → 25.6%** (bias +3.3s → +1.4s,
  better 18/25); train ≈ test (24.7% vs 25.6%) ⇒ **no overfitting**; the 30 kills no loop ever saw:
  38.7% → 26.9% (better 25/30). Retrained profile reproduces loop 1's shape ⇒ **the rhythm is a stable
  property of the encounter**. The batch grader now resolves + injects profiles by `encounterID`
  (the driver's role) — next encounter batches are plug-in. Protocol per the human: 50-sample batches,
  one PR each, AI picks the learning.

**Phase 0** 1. [x] D-013 Accepted (2026-07-29) · [ ] corpus — in progress: Fresh MC ×10 + BWL ×8 + AQ ×2
(each raid sampled from its own relevance window; Onyxia/Patchwerk excluded — their rankings predate Fresh,
a different variant's population). 2. [x] fable on · [ ] ultracode — deferred; the multi-agent design
fan-out runs when the human enables it.
**Phase 1** 1. [ ] Design workflow → synthesised regime architecture.
**Phase 2** 1. [ ] Implement behind the frozen API (chunk-clock preserved as the solo strategy).
**Phase 3** 1. [ ] Adversarial verify + grade vs real corpus & sim → PR.
