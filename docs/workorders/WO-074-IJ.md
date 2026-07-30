---
wo: WO-074-IJ
status: Done
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/94
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-069-IJ.md
related:
  - projects/badger-ttk/src/raids/rhythms.lua
  - projects/badger-ttk/src/raids/rhythms_spec.lua
---

# WO-074-IJ — Learn Onyxia's rhythm + ship it in 0.9.47

- **Created:** 2026-07-30
- **Anchor:** [D-013-IJ] (rhythm-aware estimator). Onyxia was the one raid boss **deliberately absent** from
  the shipped 41-profile library ("no Fresh-window log corpus exists yet — learnable the moment one does").
  A corpus now exists. Human directive 2026-07-30: "learn onyxia fight which I forgot" + "do 0.9.47".
- **Objective:** learn Onyxia's per-encounter rhythm from real Fresh kills, validate it held-out, add it to
  `rhythms.lua`, and ship it in **badger-ttk 0.9.47** through the `nx release` pipeline.

## The learning (done — client-side R&D)

- **Encounter id:** Onyxia = classic DungeonEncounterID **1084**; WCL's **Fresh** partition names it
  **151084** (= 1084 + 150000, the +150000 convention). Verified against the rankings API (1084 = 2020–21
  original-Classic data; 151084 = Fresh, 43–222s durations).
- **Harvest:** `wcl-corpus.py 151084 --n 40` → 40 real Fresh Onyxia kills (0 archived; 74–222s spread).
- **Learn:** `learn-rhythm.py 151084 --split-even` → TRAIN half (20 kills) → `candidates/rhythm-151084.lua`.
  The profile is **mechanically real**: slow pull (0.62×), fast ground phase (~1.6–1.7×), a sharp **dip to
  0.53× at ~50% health** (the air phase — Onyxia untargetable, whelps), recovery, execute burn (~1.3×).
- **Held-out grade** (the 20 odd-indexed kills, never seen in learning): mean MAPE **74.2% → 52.7%**
  (median 71.1 → 50.7, p90 95.8 → 67.1, "reads-long" bias +49.3s → +34.0s). A genuine, non-overfit win —
  the flat rate can't see the air phase. Onyxia is inherently hard (untargetable phase), so 53% is still
  high, but strictly better, and per the design "a profile can only ever be an improvement over flat."

## Scope (shipped code)

- **`src/raids/rhythms.lua`** — add `[1084] = { kills, bins }` (the learned Onyxia profile) to `profiles`;
  the existing key-aliasing loop auto-adds `[151084]`. Remove Onyxia from the header's "deliberately ABSENT"
  list (Naxxramas remains — still no corpus).
- **`src/raids/rhythms_spec.lua`** — bump the profile-count assertion `41 * 2` → `42 * 2`.
- **CHANGELOG / release** — cut **0.9.47** via `nx release` (version → changelog → zip → PR → human merge →
  tag `badger-ttk/0.9.47` + GitHub Release).

## Out of scope

- Naxxramas (still no Fresh corpus). Regime layer (D-014, 1.1). Re-learning the other 41 profiles.

## Behavior delta

ADDED (one new rhythm profile). The estimator now anticipates Onyxia's shape instead of assuming a flat
rate; every other fight is unchanged (`ns.Rhythms` gains two keys). No API change; estimator sim for
non-Onyxia encounters is byte-identical.

## Constitution check

Principles OK. Pure data addition to `rhythms.lua` (no logic change); values learned by the lab, not
hand-authored (regenerable); `rhythms_spec` updated; no `_G` leak. The learning ran **client-side** (WCL
key in `.env`, corpus gitignored) — never in CI.

## Acceptance

- Onyxia profile in `rhythms.lua` (dual-keyed 1084 + 151084), 20 bins, from the lab's candidate.
- `pnpm validate` green (incl. the `42 * 2` spec).
- Held-out grade shows the profile beats flat (done: 74.2% → 52.7%).
- Shipped as **0.9.47** through the pipeline; PR human-merged; tag + GitHub Release cut. CurseForge +
  in-game `/reload` remain the human's (D-015).

**Phase 1** 1. [x] harvest + learn + held-out + fresh-batch grade. 2. [x] integrate into rhythms.lua + spec; gate green. 3. [x] cut 0.9.47 (PR #94 merged); tag `badger-ttk/0.9.47` + GitHub Release + zip.

**Outcome:** Onyxia shipped in 0.9.47. Two out-of-sample validations (held-out 74.2%→52.7%, fresh dps batch 79.8%→59.3%). By time-left: error is ~3s in the final 10s, ~17s at 30s-left, and the rhythm roughly halves mid-fight error (the air-phase navigation). The residual (air phase, ~99% shown) is the seam D-018/0.9.48 addresses.
