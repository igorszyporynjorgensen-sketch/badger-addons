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

- **Loop 3 outcome (PR #77, 2026-07-29):** **Magmadar ×50 — the biggest win yet, and the first second
  encounter.** Held-out 25: mean MAPE **38.5% → 20.5%**, bias +6.7s → +2.3s, within-15% 23.8% → **65.0%**,
  better on **24/25** (25/25 train; train ≈ test ⇒ no overfitting). His learned shape is genuinely
  different — sub-average 0.84–0.94× through 90–70% HP (the **Frenzy/tranq windows**, a real mechanic
  visible in data) — and the worse baseline bias was exactly that phase fooling the backward-looking
  rate. Two encounters, two shapes, one method.

- **Loop 4 outcome (PR #78, 2026-07-29):** **Gehennas ×50 — the largest absolute drop yet.** Held-out 25:
  mean MAPE **48.4% → 26.8%** (−21.6pp), bias +4.8s → +2.1s, within-15% 15.8% → 50.5%, better on 22/25;
  test beats train ⇒ zero overfit. Shape: cleave-soft opening (0.79–0.90× at 95–85%, the Flamewaker
  Elites) + the strongest execute spike so far (2.02×). **Three encounters, three shapes, three held-out
  wins** — the method is routine.

- **Loop 5 outcome (PR #79, 2026-07-29):** **Garr ×50 — the adds-explosion stress test, passed.** Held-out
  25: mean MAPE **44.2% → 29.1%**, bias +6.9s → +3.0s, within-15% 34.5% → 54.7%, better on **24/25**. The
  8 Firesworn leave fingerprints: the mildest execute of any boss (1.4–1.6×; staggered explosions smear
  the burn) and the first small train→test gap (24.6% vs 29.1% — strategy variance costs a little
  generalization; a finding, not a failure). **Four encounters, four held-out wins.**

- **Loop 6 outcome (PR #80, 2026-07-29):** **Shazzrah ×50 — the short-fight floor holds.** On 7–13s
  fights, held-out 25: mean MAPE **41.1% → 22.8%**, bias +3.2s → +1.2s, within-15% 17.0% → 61.2%, better
  on 22/25; test beats train. 3 never-confident kills identical in both configs (correctly hidden). His
  signature: the most violent execute yet (**3.20×** at 20–15%). **Five encounters, five held-out wins.**

- **Loop 7 outcome (PR #81, 2026-07-29):** **Baron Geddon ×50 — six for six, noisiest boss yet.** Held-out
  25: mean MAPE **52.0% → 39.8%**, median **40.5% → 25.9%**, bias +5.8s → +3.1s, better on **24/25**.
  Mean ≫ median on both sides (Living Bomb chaos pulls = MC's highest kill variance) — the median is the
  honest center, in line with every other boss. Shape: a 1.2–1.3× mid ramp into a 1.88× execute.

- **Loop 8 outcome (PR #82, 2026-07-29):** **Sulfuron ×50 — the heal-suppression boss; biggest correction
  yet.** Baseline is MC's worst (**91.9% mean, +16.1s bias** — the four Flamewaker Priests heal him, so a
  backward rate reads the suppressed net damage as "forever"). Profile: **→ 49.5% mean / 37.9% median,
  +6.2s**, better on 24/25. Shape = the mechanic: 0.83–0.90× while priests live → **2.57×** collapse.
  *Honest residual:* weakest absolute endpoint (heal pollution is structural — for the regime work, not
  more data). **Seven encounters, seven held-out wins.**

- **Loop 9 outcome (PR #83, 2026-07-30):** **Golemagg ×50 — the first perfect sweep: 25/25 held-out kills
  better.** Mean MAPE **30.6% → 20.4%**, within-15% 43.0% → 68.7%, bias +5.7s → +2.7s; train ≈ test
  *exactly* (20.4% both). Textbook shape (gate 0.41× → flat burn → 1.3–1.5× enrage). **Eight encounters,
  eight held-out wins, zero overfit in eight straight splits.** Ragnaros closes the library next.

- **Loop 10 outcome (PR #84, 2026-07-30):** **Ragnaros ×50 — THE MC LIBRARY IS COMPLETE.** Held-out 25:
  mean MAPE **44.4% → 30.0%**, median 34.6% → 24.7%, bias +11.5s → +5.2s, better on 24/25; train ≈ test
  for the ninth straight split. Shape: softest gate (0.55×), a visible submerge dip at 25–20%, execute.
  **Final scoreline: nine encounters, nine held-out wins, zero overfit — median error roughly halved
  across the raid.** Next: the driver-side `opts.rhythm` wiring PR (the first shipped-code change —
  in-game, needs `/reload`).

- **Rhythm wiring (PR #85, 2026-07-30) — the first SHIPPED-CODE change:** `opts.rhythm` in the shipped
  estimator + `src/raids/rhythms.lua` (nine MC profiles, dual-keyed classic/+150000) + driver resolution
  (`ENCOUNTER_START` id capture · pure `rhythmFor` — boss-level targets only · one-shot at-pull upgrade ·
  stash continuity). Proof: gate green; `estimator-sim` byte-identical to main (solo untouched); full
  506-fight corpus bit-identical to the ten-loop candidate; whole-corpus median 25.3% vs 41.5% baseline.
  CHANGELOG `[Unreleased]` entry added; no version bump (D-011). **Merged 2026-07-30; the human explicitly DEFERRED
  in-game verification** — the behavior delta remains unverified-live until a later `/reload` + MC pull
  (open item; the id-space question rides on it). Proceeding with the BWL library meanwhile.** Post-pass learnings recorded in
  `docs/reference/estimator-replay.md` (§ Learnings after the MC pass).

- **Loop 11 outcome (PR #86, 2026-07-30):** **Razorgore ×50 — BWL begins; best median endpoint yet.**
  Held-out 25 (baseline = pre-wiring estimator): mean **26.4% → 20.4%**, median 22.1% → **15.3%**,
  within-15% 32.2% → 55.7%, better on 20/25; train ≈ test. Ranked window = the post-egg burn (soft
  roll-in 0.77×, clean 2× execute). **Ten encounters, ten held-out wins.** BWL profiles stay in the lab
  until the wing ships as a set.

- **Loop 12 outcome (PR #87, 2026-07-30):** **Vaelastrasz ×50 — perfect 50/50 sweep** (25/25 held-out AND
  train): mean **61.5% → 26.6%**, bias +6.0s → +1.9s. The 30%-start math (scale-invariance) proven live;
  his shape is the library's only *decelerating* one (6× Essence burn → 0.38× Burning-Adrenaline end).
  **Eleven encounters, eleven held-out wins, zero overfit in eleven splits.** Dashboard rebuilt as a
  program-state view (before→after per boss · coverage · campaign learnings) on the human's re-think ask.

- **Loop 13 outcome (PR #88, 2026-07-30):** **BWL COMPLETE — six bosses in one go (per the human), wing
  SHIPPED as a set.** Held-out: Broodlord 41.1→25.8 (24/25) · Firemaw 81.8→31.6 (25/25 — the wing's
  Sulfuron: Flame-Buffet ramp) · Ebonroc 66.4→32.4 (24/25) · Flamegor 36.1→20.4 (25/25) · Chromaggus
  71.2→54.1 (25/25; residual = random vulnerability rotations, structural) · Nefarian 32.6→21.8 (25/25).
  `rhythms.lua` regenerated with all **seventeen** profiles (Vael top-bins neutralized); spec + CHANGELOG
  extended. **Program: 17 encounters · 400/425 held-out kills better · mean 50%→29% · bias +8.5→+3.3s ·
  0/17 overfit.**

- **Loop 14 outcome (PR #89, 2026-07-30):** **the remaining-raids sweep — ZG + AQ20 + AQ40 in one go; the
  library ships at 41 profiles across five raids.** Crown jewels: **Viscidus 608→86 (bias +270s→−13s)**,
  **C'Thun 225→55**, Bug Trio 379→84, Sartura 178→60. Structural tier (improves, stays rough — regime
  agenda): Twin Emperors, Rajaxx, Skeram, Thekal, Buru. Excluded honestly: Edge of Madness (4 random
  bosses per id, ungated), **Naxx + Onyxia (no Fresh-window corpus exists — probed)**. Program:
  **41 bosses · 973/1025 held-out kills better · 0/41 overfit · ~1,868 kills.**

**Phase 0** 1. [x] D-013 Accepted (2026-07-29) · [ ] corpus — in progress: Fresh MC ×10 + BWL ×8 + AQ ×2
(each raid sampled from its own relevance window; Onyxia/Patchwerk excluded — their rankings predate Fresh,
a different variant's population). 2. [x] fable on · [ ] ultracode — deferred; the multi-agent design
fan-out runs when the human enables it.
**Phase 1** 1. [ ] Design workflow → synthesised regime architecture.
**Phase 2** 1. [~] Implement behind the frozen API — the rhythm path is SHIPPED (PR #85, pending /reload); regime detection + confidence remain.
**Phase 3** 1. [ ] Adversarial verify + grade vs real corpus & sim → PR.
