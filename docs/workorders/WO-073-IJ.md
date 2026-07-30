---
wo: WO-073-IJ
status: In progress
assigned: IJ
mr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/92
decision: D-017-IJ
depends_on: []
related:
  - nx.json
  - tools/release/toc-version-actions.js
  - tools/build.sh
  - projects/badger-ttk/BadgerTTK.toc
  - projects/badger-arena/BadgerArena.toc
  - CLAUDE.md
  - docs/reference/release-runbook.md
---

# WO-073-IJ — Multi-output release strategy via `nx release` (independent, Conventional Commits, full pipeline)

- **Created:** 2026-07-30
- **Anchor:** [D-017-IJ] (Nx Release, Conventional Commits, full pipeline). Chosen by the human 2026-07-30
  (AskUserQuestion: *Conventional Commits* + *Full pipeline* + tag scheme *`{projectName}/{version}`*).
  **Accepted** on the human's build directive ("use the NX plugin … multi output release strategy") + those
  three design answers; no `[NEEDS CLARIFICATION]` open; Constitution check passes (below).
- **Objective:** turn the repo's release output from a single hand-run `tools/build.sh` into a
  **multi-output `nx release`** pipeline where each addon (`badger-ttk`, `badger-arena`, + future) versions,
  changelogs, tags, zips, and releases **independently** — with the addon's **`.toc` `## Version:`** line as
  the single source of truth (no `package.json` versions), the bump + changelog derived from **Conventional
  Commits**, and the release surfaced on git as a per-project tag + **GitHub Release** with the zip attached.

## The mechanism, grounded in the installed Nx 23.1.0 API

Verified against `node_modules/nx` (not assumed):
- `nx release` exists; custom version logic is a class **extending `VersionActions`**, imported from the
  **public** entrypoint **`nx/release`** (`const { VersionActions } = require('nx/release')`).
- `@nx/js` is **not installed** (its default `versionActions` would need it) — so a custom `versionActions`
  path is **required**, which is exactly our case (`.toc`, not `package.json`).
- The `versionActions` config value is a **module path**, resolved via `require.resolve(path)` then
  `require.resolve(join(workspaceRoot, path))`, and the class is taken as `loaded.default ?? loaded`. Repo is
  CommonJS (no root `"type":"module"`, no root tsconfig) → the module is a **plain CommonJS `.js`**
  (`module.exports = TocVersionActions`), zero build step.
- With `validManifestFilenames = null`, the base `init()`/`validate()` do **no** manifest-existence checks
  (validated by reading `version-actions.js`), so we own all `.toc` read/write — the right fit because the
  `.toc` filename varies per addon (`BadgerTTK.toc`, `BadgerArena.toc`).
- `currentVersionResolver: "disk"` calls our `readCurrentVersionFromSourceManifest` — we read the `.toc`
  `## Version:` line. This sidesteps the "no matching git tag yet" bootstrap (existing tags are `v0.9.44` /
  `v0.9.45`, the legacy single-output scheme; the new independent scheme is `{projectName}/{version}`).
- `calculateNewVersion` default is semver-correct (our versions are semver) → **not overridden**. (Note:
  `adjustSemverBumpsForZeroMajorVersion` governs how `0.x` breaking bumps behave — kept at Nx default.)

## Scope (shipped infra)

1. **`tools/release/toc-version-actions.js`** (new, pure Node CommonJS) — `class TocVersionActions extends
   VersionActions`:
   - `validManifestFilenames = null` (we handle the `.toc` directly).
   - `readCurrentVersionFromSourceManifest(tree)` — locate `*.toc` in `this.projectGraphNode.data.root`
     (via `tree.children`), parse `## Version:\s*(\S+)`, return `{ currentVersion, manifestPath }`.
   - `updateProjectVersion(tree, newVersion)` — rewrite the `## Version:` line in-place, return a log line.
   - `readCurrentVersionFromRegistry` → `null` (no registry). `readCurrentVersionOfDependency` →
     `{currentVersion:null, dependencyCollection:null}`; `updateProjectDependencies` → `[]` (addons are
     standalone — no inter-addon deps).
   - A colocated **`toc-version-actions_spec`** is not a Busted target (it's Node, not Lua) — instead a tiny
     Node self-check or a `--dry-run` proof covers it (see Acceptance). Documented divergence from house-style
     (§ specs), which targets the Lua units.
2. **`nx.json` `release` block:**
   - `projectsRelationship: "independent"`.
   - `projects: ["badger-ttk", "badger-arena"]` (WoW addons; excludes `tools/*`).
   - `releaseTagPattern: "{projectName}/{version}"` (human's pick — a path-like tag namespace, e.g.
     `badger-ttk/1.0.0`; parses back on the last `/`. Explicit override of Nx's `@` default, which
     `releaseTagPattern` supports).
   - `version`: `{ currentVersionResolver: "disk", specifierSource: "conventional-commits",
     versionActions: "./tools/release/toc-version-actions.js" }`.
   - `changelog`: `{ projectChangelogs: true, workspaceChangelog: false, createRelease: "github" }` — one
     `CHANGELOG.md` per addon (the existing hand-curated ones stay; generated entries append on top), no root
     changelog, a GitHub Release per tag.
   - `git`: **no auto-push to `main`** — `nx release` writes files + tags **on a release branch**; the AI
     opens a PR; the human merges. (`git.push:false`; tag-push + asset-upload are the post-merge, human-gated
     step. See the runbook.)
3. **`tools/build.sh` build-reproducibility fix** — the BigWigs packager needs **bash ≥ 4.3**; the mac system
   bash is 3.2. Make the script locate a modern bash (prefer `$(brew --prefix)/bin/bash`), and fail with a
   clear message if none. One-time human setup: `brew install bash` (a dependency install — part of this WO's
   acceptance). The zip is built **from the versioned `.toc`** (i.e. after the version bump), named
   `<pkg>-<version>.zip`.
4. **`docs/reference/release-runbook.md`** (new) — the exact release ritual (branch → `nx release version` →
   `nx build` the zip → PR → human merge → tag + GitHub Release + `gh release upload <tag> <zip>`; CurseForge
   stays **manual + gated on the in-game `/reload`**, D-015).
5. **`CLAUDE.md`** — record the **Conventional Commits** convention (the AI authors commits as
   `type(scope): subject`, scope = addon, `feat!`/`BREAKING CHANGE` for majors) so the bump/changelog derive
   correctly. *(CLAUDE.md is outside `docs/` → it lands on the WO branch + PR, not direct-to-`main`.)*

## The release ritual (how `nx release` fits the working agreement)

Never pushes to `main`; the human always merges; publish stays gated. Per addon:
1. Branch `release/<addon>-<version>` (or fold into the feature branch for the 1.0.0 cut).
2. `nx release version --projects=<addon>` — writes the `.toc` + (via changelog step) the addon `CHANGELOG.md`,
   commits on the branch. **No push.**
3. `nx build <addon>` — builds the versioned zip (needs the bash-repro fix).
4. Open PR → **human reviews + merges** (merging is human-only).
5. **Post-merge, on `main` (human-gated):** create the tag `{addon}/{version}` + the GitHub Release
   (`nx release changelog --create-release=github` or `gh release create`), then `gh release upload` the zip.
6. **CurseForge:** manual upload, only after the human's in-game `/reload` (D-015) — never automated here.

`nx release --dry-run` validates the whole thing with **zero** side effects — the primary acceptance proof.

## Out of scope

- CurseForge auto-packaging / auto-publish (D-015: manual + gated). The monorepo also blocks CF's
  single-repo auto-packaging.
- A workspace-level (root) changelog — per-addon only.
- Inter-addon dependency versioning (addons are standalone; the dependency methods are no-ops).
- Back-porting to the `scaffold-project` creator — a **follow-up**, explicitly gated: **not until a real
  release cycle has been run for real** (a live `nx release` → tag → GitHub Release → zip, not a dry-run),
  per the human's 2026-07-30 directive. Prove it in anger here first, then propagate.

## Behavior delta

ADDED (release infra: `nx release` + custom `.toc` version actions + runbook). No in-game/runtime addon
behavior changes; the shipped Lua is untouched. `tools/build.sh` MODIFIED (bash-repro). `CLAUDE.md` MODIFIED
(commit convention).

## Constitution check

Principles OK. No shipped-Lua change (estimator/driver/engine untouched → sim stays byte-identical). The new
module is Node tooling under `tools/` (never shipped), consistent with "non-shipped shared code lives in
`tools/*`". House-style spec-colocation is a **documented divergence** for a Node (non-Lua) tool — covered by
a `--dry-run`/Node self-check instead of Busted. No `_G`/global leak in Lua. Version bump remains a deliberate
human-gated release act (D-011 principle; D-017 mechanism).

## Acceptance

- `nx release --dry-run --projects=badger-ttk` (and `badger-arena`) runs clean: resolves the current `.toc`
  version from disk, derives a bump from Conventional Commits, previews the new `.toc` + `CHANGELOG.md` + tag
  `{projectName}/{version}` + the GitHub Release — **no files changed, nothing pushed.**
- The custom version actions round-trip a `.toc`: read `0.9.45` → write a bumped version → the `## Version:`
  line is the only change.
- `tools/build.sh` produces the versioned zip on this machine (bash-repro fixed).
- `pnpm validate` stays green (no Lua touched; the gate is unaffected).
- The runbook + `CLAUDE.md` convention are in place.
- Reviewed, PR opened, **human merges**. (The first real `1.0.0` cut through this pipeline is a *separate*
  human-gated act, still behind the in-game `/reload`.)

## Phases

**Phase 1 — infra**
1. [ ] `tools/release/toc-version-actions.js` (the 6 `VersionActions` members).
2. [ ] `nx.json` `release` block (independent · disk · conventional-commits · versionActions path · per-project
   changelogs · createRelease github · git no-push).
3. [ ] Validate `nx release --dry-run` for both addons; iterate off the dry-run output (no side effects).

**Phase 2 — build + docs**
4. [ ] `tools/build.sh` bash-repro fix (`brew install bash`; locate bash ≥4.3) → versioned zip builds.
5. [ ] `docs/reference/release-runbook.md` + `CLAUDE.md` Conventional-Commits convention.
6. [ ] Branch + PR (human-merged). WO → In progress on branch cut; → Done on merge + gate green.
