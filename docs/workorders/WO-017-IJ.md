---
wo: WO-017-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/20
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-012-IJ.md
  - docs/workorders/WO-016-IJ.md
related:
  - projects/badger-ttk/src/display/display.lua
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/config/config.lua
  - projects/badger-ttk/BadgerTTK.toc
---

# WO-017-IJ — `badger-ttk` build-version stamp + robust preview ownership (fix the vanishing bars)

- **Created / Updated:** 2026-07-25
- **Objective:** two things from the second in-game test:
  1. **Show the build version in the config window** so the human can confirm they are running the latest
     package every time. Single-sourced from the `.toc` `## Version`. Starts at **0.9.0** and is **bumped
     every test build** (0.9.0 → 0.9.1 → …); it becomes **1.0.0 only when the human signs the addon off as
     working**.
  2. **Fix the preview bars vanishing** (both static preview AND dynamic Play flash for ≈1s then disappear).
- **Root cause (what we know):** an exhaustive scan proves the *only* code that hides the display container
  (`BadgerTTKFrame`) is `LiveDriver.update()` (two `ns.Display.hide()` calls, both now behind the WO-016
  `simStatic`/`simPlaying` guard) and `Display.showPreview(false)`. Nothing in AceConfig / AceGUI /
  BadgerConfigUI hides our frame. So by static logic the guard *should* keep the preview up — yet it
  vanishes. Two live possibilities remain, and this WO closes **both**:
  - **(a) Stale install** — the guard isn't in the files WoW actually loaded. The **version stamp makes
    this impossible to miss**: if the config shows the new version, the code is fresh.
  - **(b) A runtime path defeats the per-tick db-flag guard** — so we stop relying on the driver reading
    `db.profile` on each tick and instead **push an explicit suspend command** to the driver at the moment
    the preview is toggled (synchronous, right after the flag is set — no propagation doubt), while keeping
    the db-flag check as a backstop.
  - **Dynamic-only extra:** the Play loop's `OnUpdate` is hosted **on the container itself**
    ([display.lua:199](../../projects/badger-ttk/src/display/display.lua#L199)). In WoW a hidden frame's
    `OnUpdate` stops firing, so a single hide **permanently stalls** playback (it can't re-show itself).
    We move that loop onto a **dedicated, always-shown ticker frame** so it is immune to any container hide.
- **Acceptance criteria:**
  - The config window visibly shows **`v0.9.0`** (title/banner), read from `GetAddOnMetadata` so it can
    never drift from the `.toc`.
  - **Static preview stays up** until the human unticks it (no ~1s vanish).
  - **Dynamic Play animates continuously** (loops the scripted fight) and does not stall.
  - Turning previews off hands control back: a real hostile target still drives the bars in combat.
  - `pnpm validate` green (edge-only changes; the pure `assembleEntries`/`gate`/engine specs are untouched).
- **Out of scope:** any new estimator/ability/gating behavior; the WarcraftLogs seam; boss registry.
- **Behavior delta:** MODIFIED (in-game) — config shows the build version; static + dynamic previews
  persist instead of flashing-then-vanishing.

**Phase 1 — Version stamp**
1. [x] `BadgerTTK.toc` `## Version:` → **0.9.0**.
2. [x] Config window title + banner surface the running version (single-sourced via
       `(C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata`), subtitle
       "Time-to-kill and optimal cooldown timing — v0.9.0". Globals whitelisted in `.luacheckrc`/`.luarc.json`.

**Phase 2 — Robust preview ownership**
1. [x] `LiveDriver.setSuspended(bool)` — module-local flag; `update()` returns early on `suspended`
       (kept **alongside** the `simStatic`/`simPlaying` db-flag backstop).
2. [x] `Display.showPreview` / `Display.playSim` push `setSuspended(simStatic or simPlaying)` at toggle time.
3. [x] `Display.playSim` runs its animation `OnUpdate` on a dedicated always-shown `simFrame`, not the
       hideable container; `render` remains the sole container-shower.

**Phase 3 — Verify**
1. [x] `pnpm validate` green (luacheck 0/0; 53+16 specs). PR #20 opened.
2. [x] After merge: rebuilt `.release`; **confirmed in-game** — the build **version shows** in the config
       (it has on every build since), and the robust preview ownership is the mechanism the human confirmed
       "worked really well" on the v0.9.1 build (WO-018), which includes all of this WO's code.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; human re-test.
- **Constitution check:** Principles OK — edge-only frame/driver coordination; no `_G` leaks; pure logic and
  its specs untouched; house-style module boundaries preserved.
- **Decisions produced:** —
- **MR:** [PR #20](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/20) — merged.
- **Outcome:** Code merged; `pnpm validate` green (luacheck 0/0; 53+16 specs). Rebuilt `.release/BadgerTTK`
  at **v0.9.0** — verified: version 0.9.0 shipped, `LiveDriver.setSuspended` + `suspended`-first guard
  present, display `simFrame`/`syncDriver` present, config version-stamp present, full load graph resolves
  (65 files, 0 missing), source parity clean. **Staying `In progress` pending the human's in-game
  confirmation** — the `/reload` waiver was lifted 2026-07-25, so this WO (which changes in-game behavior)
  is Done only once the human tests the live client: config shows v0.9.0, static + dynamic previews persist,
  a real target still drives the bars.
