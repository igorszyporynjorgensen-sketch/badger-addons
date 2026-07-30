# Release runbook — `nx release` (multi-output, independent)

How a Badger addon goes from merged code to a tagged, zipped, GitHub-released build. The mechanism is
**`nx release`** (D-017-IJ / WO-073-IJ); this file is the operator's guide. Each addon
(`badger-ttk`, `badger-arena`, …) versions and releases **independently**.

> **The two rules this ritual is built around** (from `CLAUDE.md`): the AI **never pushes `main`** and
> **never merges a PR** — every code change, including a version bump, lands via a branch + PR the human
> merges; and the CurseForge publish is **manual, gated on an in-game `/reload`** (D-015). So `nx release`
> is configured to **touch no git** on its own (`git.commit/tag/push` all off); the tag + GitHub Release
> happen **post-merge, human-gated**.

## What's wired (nx.json `release`)

- **`projectsRelationship: "independent"`** — each addon has its own version/tag/changelog/release.
- **Version source = the addon's `.toc` `## Version:` line** — read/written by `tools/release/toc-version-actions.js`
  (a custom `VersionActions`). No `package.json` versions.
- **`currentVersionResolver: "git-tag"`** with **`fallbackCurrentVersionResolver: "disk"`** — the current
  version comes from the latest `{projectName}/{version}` tag; on an addon's **first** release (no such tag
  yet) it falls back to reading the `.toc`.
- **`specifierSource: "conventional-commits"`** — the bump is derived from commit messages since the last
  tag (see the commit convention in `CLAUDE.md`). You can always override with an explicit specifier.
- **`releaseTag.pattern: "{projectName}/{version}"`** — e.g. `badger-ttk/1.0.0`.
- **`changelog.projectChangelogs: true`, `workspaceChangelog: false`, `automaticFromRef: true`** — one
  per-addon `CHANGELOG.md`, no root changelog; a brand-new addon's first changelog bootstraps from its first
  commit, and every release thereafter is a clean tag-to-tag delta.

## Prerequisites (one-time, local)

- **A modern bash** for the BigWigs packager (needs ≥ 4.3; **macOS ships 3.2**):

  ```sh
  brew install bash        # tools/build.sh auto-detects it; or set MODERN_BASH=/path/to/bash
  ```

- **`gh`** authenticated (`gh auth status`) for the GitHub Release step.

### Pipeline / CI note (`brew` is a macOS-only concern)

`brew install bash` matters **only on macOS** (the local dev machine, or a macOS CI runner). `tools/build.sh`
detects a usable bash generically — it tries `$MODERN_BASH`, the Homebrew paths, **and the PATH `bash`** —
so on a **Linux runner (`ubuntu-latest`) the native bash is already 5.x** and the packager runs with **no
brew, no setup**. The BigWigs packager is designed for Linux addon-CI; bash 3.2 is purely a macOS quirk. So:

- **Automating the zip build on CI later? Use `ubuntu-latest`** — nothing to install.
- On a macOS runner, `brew` is pre-installed → add `brew install bash` to the job (or use a runner that
  already has it). Detection handles both `/opt/homebrew/bin/bash` (ARM) and `/usr/local/bin/bash` (Intel).

(There is **no** release/build pipeline today — the ritual below is local + human-gated by design. This note
is only so build.sh is ready if you ever add one. Note the separate standing constraint that **learning**
never runs on CI; releases have no such rule.)

## The ritual — releasing one addon

Everything below is **dry-run-first**. `--dry-run` makes **zero** changes and is the primary safety net.

### 1. Pick the version

- **Normal release:** let conventional-commits decide — omit the specifier.
- **The `1.0.0` cut (or any deliberate version):** pass it explicitly.

```sh
# Preview — no changes, nothing pushed:
pnpm exec nx release version --projects=badger-ttk --dry-run                # bump from commits
pnpm exec nx release version 1.0.0 --projects=badger-ttk --dry-run          # explicit
```

The preview shows: git-tag lookup (or the disk fallback), the derived/explicit version, and the exact
`.toc` `## Version:` rewrite.

### 2. Branch, then version + changelog for real

```sh
git checkout -b release/badger-ttk-<version>
pnpm exec nx release version   --projects=badger-ttk [<version>]   # writes the .toc (no git)
pnpm exec nx release changelog <version> --projects=badger-ttk     # writes CHANGELOG.md (no git)
```

`nx release` is configured to make **no git commit/tag/push**. Review the `.toc` + `CHANGELOG.md` diffs,
then commit them yourself with a conventional message:

```sh
git add -A && git commit -m "chore(release): badger-ttk <version>"
```

### 3. Build the versioned zip

```sh
pnpm exec nx build badger-ttk         # → projects/badger-ttk/.release/BadgerTTK-<version>.zip
```

(Requires the modern bash from Prerequisites. The zip is named from the **packaged** `.toc`, so it can't
drift from what the client reports.)

### 4. PR → **human merges**

Open the PR; the human reviews and merges. The AI never merges (repo rule).

### 5. Post-merge, on `main` — tag + GitHub Release (human-gated)

Pushing is intended **here**, on `main`, after the merge:

```sh
git checkout main && git pull
git tag badger-ttk/<version>
git push origin badger-ttk/<version>
gh release create badger-ttk/<version> \
    --title "badger-ttk <version>" \
    --notes-file <(printf '%s\n' "see CHANGELOG.md") \
    projects/badger-ttk/.release/BadgerTTK-<version>.zip
```

(Or, equivalently, let nx create the release with generated notes at this step — it needs push, which is
fine post-merge: `pnpm exec nx release changelog <version> --projects=badger-ttk --create-release=github`.
Attach the zip with `gh release upload` afterward.)

### 6. CurseForge — manual, **only after the in-game `/reload`** (D-015)

Upload the zip to CurseForge and paste the matching `CHANGELOG.md` section into the file's Changelog box.
**Never** before the human has `/reload`ed the build in WoW.

## The `1.0.0` cut — one-time notes

- **Explicit specifier:** `nx release version 1.0.0 --projects=badger-ttk` (conventional-commits would not
  reach `1.0.0` from `0.9.x` without a `feat!`/`BREAKING CHANGE`; the milestone is a deliberate human call —
  D-011 principle).
- **CHANGELOG.md handoff (auto-owns, chosen 2026-07-30):** nx **prepends** new version sections to the top
  of the file and has no "insert below a title/preamble" mode. So at the `1.0.0` cut, retire the manual
  scaffolding (`# Changelog` title, preamble, the RELEASE-PROCESS comment, and `## [Unreleased]`) so the
  file becomes a clean stack of `## [version]` sections — the historical `0.9.x` entries **stay below**, and
  nx owns everything from `1.0.0` up. (`badger-arena` has no `CHANGELOG.md` yet, so nx creates a clean one on
  its first release — no handoff needed.)
- **In-game `/reload` gates the publish**, not the tag/zip. Artifacts may be cut; CurseForge waits for the
  human's live check.

## Adding a new addon later

No special work: it inherits the `release` block. Its first `nx release version` falls back to its `.toc`
(no tag yet); its first changelog bootstraps from its first commit. Tag namespace is `{newaddon}/{version}`.
