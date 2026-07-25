---
wo: WO-013-IJ
status: Done            # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/16
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-007-IJ.md
  - docs/workorders/WO-012-IJ.md
related:
  - docs/workorders/WO-009-IJ.md
  - tools/wow-mock/init.lua
---

# WO-013-IJ — `badger-ttk` skin engine — open, user-authored skins (part b)

- **Created / Updated:** 2026-07-25
- **Objective:** make the display **skinnable and high-end** — a documented, data-only **skin format**, a
  public **`RegisterSkin` API** anyone can call to add a skin, a built-in **Badger** skin, and
  **LibSharedMedia** font/texture/border pickers. The display renders from a **resolved look** (the
  selected skin's values, with the user's explicit config overrides winning). Part **(b)** of the split
  display (child #5); layers theming on WO-012's bars.
- **Design split (testable vs edge):** the **skin registry + resolve is pure** (`src/skin/skin.lua`,
  `ns.Skin`) — spec-tested; **LSM fetching + applying the look to frames** is the untestable edge (in
  `display.lua`).
- **Acceptance criteria:**
  - **`ns.Skin`** (pure): `RegisterSkin(name, skin)` · `GetSkin(name)` · `ListSkins()`; a built-in
    **"Badger"** skin; **`resolve(profile) → look`** = the selected skin's values **overridden** by the
    user's explicit config choices (overrides win; unknown skin → the Badger default). Spec-tested:
    register/list, resolve precedence, unknown-skin fallback.
  - **Public skin format (a contract):** a **data-only** table
    `{ statusbar = <LSM name>, border = <LSM name>, font = <LSM name>, colors = { target, utility,
    planned, active, over, short } }` — no code (v1). Documented in the module header (and, later, a
    `docs/reference/`). **Anyone adds a skin** via `BadgerTTK:RegisterSkin(name, skin)` (exposed on the
    AceAddon object, reachable with `LibStub("AceAddon-3.0"):GetAddon("BadgerTTK", true)`) — a tiny
    companion addon registers on load and it appears in the picker.
  - **LibSharedMedia:** add `LibSharedMedia-3.0` to the `.toc` (already a `.pkgmeta` external); resolve
    the look's `statusbar`/`font`/`border` **names → paths** via LSM.
  - **Display refactor:** `display.lua` reads `ns.Skin.resolve(profile)` and applies the resolved
    texture / font / border / colours (replacing the raw `db.profile.color*` + hardcoded texture/font
    from WO-012). Bars still resize via the spec-tested `ns.Layout`.
  - **Config Skin node:** the **skin picker** is populated from `ns.Skin.ListSkins()`; the WO-009 media
    stubs become real **LSM pickers** — font family, statusbar texture, border (a `select` from
    `LSM:List(...)`). The state colours + font sizes remain as overrides.
  - **Gate:** `pnpm validate` green; `ns.Skin` carries a colocated `_spec`; `display.lua` still loads
    clean under the mock.
  - **In-game (human, deferred/waived):** pick a skin → texture/font/border/colours change on the sim
    preview; a companion `RegisterSkin` call shows up in the picker.
- **Context / constraints:** house style — `src/skin/` module on `ns`, kebab-case, no `_G` leaks; the
  registry/resolve stays pure/spec-covered; LSM + frame application is the documented untestable edge.
  Add any WoW globals used to the badger-ttk `.luacheckrc` overlay.
- **Out of scope:** **skin paste import/export** (serialized share strings via LibSerialize+LibDeflate →
  **v1.1**); **code-hook skins** (v1 is data-only); the **live-combat driver** + ability tracking (feed
  the same display later); an `AceGUI` shared-media dialog widget (a plain LSM `select` is enough for v1).
- **Behavior delta:** MODIFIED (in-game) — the bars become skinnable (texture/font/border from the
  chosen skin + LSM), and third parties can add skins.

**Phase 1 — Skin registry + resolve**
1. [x] `src/skin/skin.lua` (`ns.Skin`) — registry + built-in Badger skin + `resolve(profile)`. Colocated
       `_spec` (register/list · resolve precedence · unknown-skin fallback).

**Phase 2 — LSM + display**
1. [x] Add `LibSharedMedia-3.0` to the `.toc`; `display.lua` renders from `ns.Skin.resolve` (LSM-fetched
       texture/font/border + resolved colours). Expose `BadgerTTK:RegisterSkin` on the addon.

**Phase 3 — Config**
1. [x] Skin node: picker from `ns.Skin.ListSkins()`; LSM font/texture/border `select`s replacing the WO-009
       stubs.

**Phase 4 — Verify**
1. [x] `pnpm validate` green; `ns.Skin` spec passes; frame glue loads under the mock. In-game skin-switch
       check deferred to the human.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR opened for human merge; in-game
  skin/media check is the human's (waived for now).
- **Constitution check:** Principles OK — the registry/resolve is API-light + spec-covered; LSM/frame
  application is the documented off-client-untestable edge; no `_G` leaks; the shared-media dialog widget
  + import/export deferred (simplest thing that fits). The open `RegisterSkin` format is the D-006 skin
  decision realised.
- **Decisions produced:** — (possibly a short decision pinning the **skin-table format** as a public
  contract, if worth recording in `docs/decisions.md`).
- **MR:** https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/16
- **Outcome:** Implemented on `feature/WO-013-IJ-skin`; **PR #16 opened**. `ns.Skin` (pure — registry +
  built-in Badger skin + `apply(profile, name)`; spec-tested) + `BadgerTTK:RegisterSkin` exposed for
  other addons; `display.lua` renders from the resolved skin via `LSM:Fetch` (texture/font/border +
  fallbacks, BackdropTemplate) with a `refresh()` for the config; the Skin node gets the registry-driven
  picker + **LSM** texture/font/border selects (replacing the WO-009 stubs), colour/media changes refresh
  the preview; `LibSharedMedia-3.0` added to the `.toc`. **Gate green:** stylua · luacheck 0/0 (17 files)
  · busted 35/0 · full `pnpm validate` exit 0. Paste import/export deferred to v1.1. **In-game
  skin-switch check deferred (waived).** **PR #16 merged; `main` green.** **Done.**
