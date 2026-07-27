---
wo: WO-036-IJ
status: Accepted        # Proposed | Accepted | In progress | Done | Blocked | Cancelled
assigned: IJ            # assignee initials — auto-filled from the committer (git email local-part)
mr: ~                   # pull-request URL once opened, else ~
decision: ~             # D-0xx-II once a decision is produced, else ~
depends_on:
  - docs/workorders/WO-034-IJ.md
related:
  - projects/badger-arena/src/config/config.lua
---

# WO-036-IJ — badger-arena adopts the global-header API

- **Created / Updated:** 2026-07-27
- **Objective — from the human ("bring badger-arena up to speed"):** now that WO-034 landed the global
  header in the shared lib, have badger-arena use the **explicit `opts.header` API** rather than the
  `opts.banner` back-compat alias, so both addons are on the current API. (Arena already renders correctly
  via the alias — this makes the intent explicit and future-proofs it.)
- **Design notes:**
  - `badger-arena config.lua`: change the `Register(...)` opts from `banner = { title, subtitle }` to
    `header = { title, subtitle }` (no controls — arena has no live preview). Same on-screen result.
  - Bump `BadgerArena.toc` `## Version` 0.1.0 → 0.1.1 to mark the change.
- **Out of scope — the arena `.release` build.** Arena has **no built `.release` yet** (its `.pkgmeta`
  externals — LibStub / Ace3 / LibSharedMedia / DRList — have never been fetched, and the BigWigs packager
  can't run on this macOS bash 3.2). Building it is a separate, network-heavy task; not done here. Whenever
  it IS built, `tools/build.sh` embeds the current `libs/BadgerConfigUI-1.0/` (now **MINOR 6**), so it ships
  the global header automatically. Offered on request.
- **Acceptance criteria:**
  - Arena registers its window with `opts.header` (not `banner`); `pnpm validate` green.
  - No behavior change vs the alias — same title/subtitle header above the tree.
- **Behavior delta:** none observable (explicit API adoption; the alias already produced the same header).

**Phase 1 — Adopt header**
1. [ ] `badger-arena config.lua`: `banner` → `header`. Bump `BadgerArena.toc` to 0.1.1.

**Phase 2 — Verify**
1. [ ] `pnpm validate` green.
2. [ ] **In-game:** deferred — arena has no `.release` build yet (see Out of scope). Its header renders via
       the shared lib once a build is produced.

- **Verification:** the acceptance criteria; `pnpm validate` green; PR for human merge.
- **Constitution check:** Principles OK — a config-glue edit; no `_G` leaks; uses the shared lib's public API.
- **Decisions produced:** —
- **MR:** —
- **Outcome:** — (running notes; filled on completion)
