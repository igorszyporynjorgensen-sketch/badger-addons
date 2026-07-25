---
wo: WO-010-IJ
status: In progress     # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/13
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-009-IJ.md
related:
  - docs/reference/ttk-estimator-inspiration.md
  - docs/reference/warrior-ttk-cooldowns.md
  - tools/wow-mock/init.lua
---

# WO-010-IJ — `badger-ttk` pure fight-state engine + TTK estimator (spec-first)

- **Created / Updated:** 2026-07-25
- **Objective:** build the **pure, API-light core** of badger-ttk — the **TTK estimator** and the
  **render-model geometry** — as modules with **no WoW API and no frame creation**, fully unit-tested
  under `tools/wow-mock`. This is the "one engine" of *one engine, three drivers*: it turns fight-state
  inputs into a render model that the display (frames), the sim, and specs all consume. Child #3 of the
  WO-007 epic; the first **functionality** WO (config came first). **No in-game behavior** — pure logic,
  so no `/reload` is even applicable; Done on merge + green.
- **Acceptance criteria:**
  - **Estimator** (`ns.Estimator`, pure — plain numbers/tables in, no `UnitHealth`/frames):
    - Consumes `(t, healthFraction ∈ [0,1])` samples → a smoothed **TTK** + a **confidence ∈ [0,1]**.
      Uses an **EWMA of the health-loss rate** with a variable-Δt α; the **reactivity** setting (0…1)
      maps to the smoothing constant λ.
    - **Clamps the rate ≥ 0** (heals never yield negative TTK); returns **unknown** (no estimate) while
      warming up or when the rate is below a floor; **resets cleanly on target change**.
    - **Execute-correction:** below `executeThreshold` target health, shortens TTK by `executeModifier`
      (applies on the pure-live path; a real history curve would supersede it).
    - **Confidence** rises with warm-up + sample stability; a caller compares it to `minConfidenceToShow`.
    - **History seam (prepared, unused in v1):** the estimator's signature accepts an **optional history
      profile** (`E(h)`, K=100) argument; v1 always passes `nil` (pure-live). The blend code path is a
      documented stub — WO-014 fills it **without changing the interface**.
  - **Render-model geometry** (`ns.RenderModel`, pure): given the TTK + a list of tracked entries
    `{ id, duration D, cooldown C, offset, state }`, produce per entry:
    - the **anchor** at `TTK = offset` (bi-directional) and the **planned pop-line comb** at
      `TTK = D + offset, +C, +2C, …` while ≤ remaining kill;
    - **planned vs active** bar geometry — right-anchored **time-ratio** lengths (`(seconds/TTK) ×
      targetLen`) reckoned against the entry's shifted anchor;
    - a **coverage classification** for an active entry — `fits` / `over-covers` / `falls-short` —
      comparing its remaining duration to `TTK − offset`.
  - **Specs:** a colocated `<module>_spec.lua` per module, covering the edge cases — heals (rate clamp),
    warm-up/unknown, execute-correction, target reset, offset **±**, the multi-use comb, and each
    coverage class. `pnpm validate` green (StyLua · Luacheck 0/0 · Busted).
  - **Inspiration:** mine the TTK WeakAura in
    [docs/reference/ttk-estimator-inspiration.md](../reference/ttk-estimator-inspiration.md) for
    sampling cadence / smoothing / reset handling — **reimplement in house style, do not copy**.
- **Context / constraints:** house style — one module per file under `src/engine/`, kebab-case, register
  on `ns`, no `_G` leaks; **API-light** so it runs off-client with no framework. The engine reads the
  estimator/offset **settings** (reactivity, leadTime, execute*, per-entry offset) as *plain values
  passed in* — it does not read `db` or the WoW API itself (a driver does). Whether the modules join the
  `.toc` now (dormant) or with the consuming display WO is an implementation choice — lean toward adding
  them so the display WO just consumes `ns.Estimator` / `ns.RenderModel`.
- **Out of scope:** the **live driver** (samples `UnitHealth`, feeds the engine) and the **display**
  (frames) → later WOs; the **sim driver** (#4); the **history blend** itself (WO-014 — seam only here);
  ability *tracking* (which entries are active/usable — the ability-model WO feeds that state in).
- **Behavior delta:** none in-game — pure logic, no frames; nothing visible changes until a driver +
  display consume the engine.

**Phase 1 — Estimator core**
1. [ ] `src/engine/estimator.lua` — EWMA rate (variable-Δt α; reactivity→λ), rate-clamp, warm-up/unknown,
       target reset → TTK. Colocated `_spec` for the base + heal + reset cases.

**Phase 2 — Estimator extras + history seam**
1. [ ] Add execute-correction + confidence to `estimator.lua`; add the **optional history-profile
       argument** as a documented stub (v1 passes nil). Spec the execute + confidence + warm-up paths.

**Phase 3 — Render-model geometry**
1. [ ] `src/engine/render-model.lua` — anchor at TTK=offset, the pop-line comb, planned/active lengths,
       coverage classification. Colocated `_spec` for offset ±, comb, and each coverage class.

**Phase 4 — Verify**
1. [ ] `pnpm validate` green; confirm the modules are pure (no WoW API / frames). No in-game check
       applies (no frames yet).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge. No in-game
  component (pure logic), so Done needs only merge + green.
- **Constitution check:** Principles OK — this is exactly the API-light-testable-logic the house style
  calls for (Ace3-free, frame-free, spec-covered under the mock); no `_G` leaks; simplest-thing-that-fits
  (live-only estimator, history seam prepared not built).
- **Decisions produced:** — (likely none — implements WO-007's accepted engine design; a decision only
  if the estimator/render-model public API shape is worth pinning).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/13
- **Outcome:** Implemented on `feature/WO-010-IJ-engine`; **PR #13 opened**. `src/engine/estimator.lua`
  (EWMA loss-rate, reactivity→λ, heal clamp, warm-up/unknown, reset, execute-correction, confidence, the
  `opts.history` seam) + `src/engine/render-model.lua` (offset anchor, pop-line comb, planned/active
  shapes, coverage in TTK-seconds space) + colocated specs (15 cases). **Human-requested scope add:** the
  estimator's `sample(t, h, damageable)` **pauses through immune/hardened phases** (C'Thun etc.) so
  zero-damage stretches don't corrupt the rate — a weakened/hardened modifier is a noted future hook.
  Engine modules loaded (dormant) in the `.toc`; `types/busted.lua` LSP stub completed with `is_not_nil`.
  **Gate green:** stylua · luacheck 0/0 (8 files) · busted 16/0 · full `pnpm validate` exit 0. No frames
  → no in-game check applies. **Done** once PR #13 merges and `main` is green.
