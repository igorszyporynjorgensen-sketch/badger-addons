---
wo: WO-015-IJ
status: Proposed        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-014-IJ.md
related:
  - docs/workorders/WO-010-IJ.md
  - docs/workorders/WO-012-IJ.md
  - tools/wow-mock/init.lua
---

# WO-015-IJ — `badger-ttk` live driver — real combat → the display (part b)

- **Created / Updated:** 2026-07-25
- **Objective:** the **live driver** — the third of *one engine, three drivers* and part **(b)** of the
  ability model. It samples the player's **real target** (`UnitHealth` → the estimator) and tracks the
  **enabled, available** warrior cooldowns' live state (auras / cooldowns / usability / stock), assembles
  the render-model, and feeds `ns.Display` **in combat**. **This closes the v1 core loop** — everything
  so far is sim-driven; this makes it work in a real fight. Child #7 (b) of WO-007.
- **Design split (pure vs edge):** two **pure, spec-tested** helpers — `assembleEntries` (master table +
  config + character + per-entry game states → the render-model entries) and `gate` (Behavior settings +
  context → show/hide). Everything else — the event/ticker loop, `UnitHealth`/`UnitAura`/cooldown reads —
  is the off-client-untestable edge.
- **Acceptance criteria:**
  - **`ns.LiveDriver.assembleEntries(table, config, character, states)`** (pure): for each master entry
    that is **enabled ∩ available**, emit `{ id, duration, cooldown, offset, active|remaining or usable }`
    (offset from `config`, state from `states[id]` via `ns.Abilities.deriveState`). Spec-tested: only
    enabled+available entries appear; offset + active/planned states carry through.
  - **`ns.LiveDriver.gate(settings, context)`** (pure): show only when `enabled` and, per Behavior,
    `inCombatOnly`⇒in combat, `requireHostile`⇒hostile target, a valid `ttk ≥ minTTK`, or `showAnyTarget`
    bypasses target gating. Spec-tested across the toggles.
  - **The driver** (`src/live/driver.lua`, `ns.LiveDriver` — the edge): a per-target **estimator**
    (`ns.Estimator`, **reset on `PLAYER_TARGET_CHANGED`**, `damageable = false` while the target is
    **immune/untargetable**); a ticker (~0.1–0.2s) sampling `UnitHealth("target")/UnitHealthMax`; live
    per-entry state from `UnitAura` (active + remaining), `GetSpellCooldown`/`GetItemCooldown` +
    `IsUsableSpell`/`IsUsableItem` + `GetItemCount`; then `assembleEntries` → `ns.RenderModel.build` →
    `ns.Display.render(model, health)`. Gated by `gate(...)`; hidden otherwise. Started/stopped on
    combat + target events; honours the master `enabled`.
  - **Gate:** `pnpm validate` green; the two pure helpers carry colocated specs; the driver loads clean
    under the mock (edge logic delegated to the pure helpers).
  - **In-game (human — the first real end-to-end check):** target a hostile mob in combat → the target
    TTK bar tracks its health, your available cooldowns show as planned pop-lines, and an active buff
    drains; a dead/lost target hides it. (Deferred/waived per the standing agreement, but this is *the*
    one to look at.)
- **Context / constraints:** house style — `src/live/` on `ns`, no `_G` leaks; the assembly + gating are
  pure/spec-covered, the sampling/events are the documented edge. Add the WoW globals used
  (`GetItemCooldown`, `IsUsableSpell`, `IsUsableItem`, `UnitCanAttack`, `UnitIsDeadOrGhost`, event
  frames…) to the badger-ttk `.luacheckrc` overlay + `.luarc.json`. Reuse `ns.Estimator` /
  `ns.RenderModel` / `ns.Abilities` — no new math.
- **Out of scope:** the **Raids node / encounter registry** (config-driven per-encounter gating is its
  own WO — here only the Behavior toggles + `showAnyTarget` gate); the **history blend** (post-v1);
  pop-moment **alerts / sounds** (future); focus/boss-frame scope; non-warrior tracking.
- **Behavior delta:** ADDED (in-game) — badger-ttk now works in a **real fight**: the bars are driven by
  live combat and gated by the Behavior settings. (Raid/encounter gating still pending.)

**Phase 1 — Pure helpers**
1. [ ] `src/live/driver.lua` — `assembleEntries` + `gate` (pure) with colocated specs (enabled∩available
       filtering · offset/state carry-through · each gate toggle).

**Phase 2 — The driver (edge)**
1. [ ] Same module: the estimator lifecycle (reset/pause), the sampling ticker, live aura/cooldown/stock
       reads, assemble → `ns.RenderModel` → `ns.Display`; event wiring + gate; started from `core`/enable.
       Load in the `.toc`; scope the new globals.

**Phase 3 — Verify**
1. [ ] `pnpm validate` green; pure helpers pass; driver loads under the mock. In-game end-to-end check
       is the human's (waived, but recommended — first real fight test).

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; the in-game
  real-fight check is the human's.
- **Constitution check:** Principles OK — assembly + gating are API-light + spec-covered (house rule);
  the sampling/event loop is the documented off-client-untestable edge; no `_G` leaks; reuses the
  engine/estimator/ability model rather than duplicating; Raids gating + history split out (simplest
  thing that fits).
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
