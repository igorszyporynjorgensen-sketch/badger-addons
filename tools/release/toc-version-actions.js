// @ts-check
'use strict';

/**
 * Custom `nx release` version actions for WoW addons.
 *
 * The single source of truth for an addon's version is the `## Version:` line of its
 * TOC file (e.g. `projects/badger-ttk/BadgerTTK.toc`) — the same line the WoW client and
 * CurseForge read. There is no `package.json` version to sync, so the default `@nx/js`
 * version actions do not apply (and `@nx/js` is not even installed here). This module
 * teaches `nx release` to read and write that TOC line instead.
 *
 * Wired via `nx.json` → `release.version.versionActions` (a module path). Nx resolves the
 * path and takes the class as `loaded.default ?? loaded`, so a bare `module.exports = Class`
 * is correct. See D-017-IJ / WO-073-IJ.
 *
 * Config expectations (nx.json):
 *   - `currentVersionResolver: "disk"`  → Nx calls `readCurrentVersionFromSourceManifest`.
 *   - `specifierSource: "conventional-commits"` → Nx derives the bump; base `calculateNewVersion`
 *     (semver) is inherited unchanged.
 *
 * The base class is re-exported from the public `nx/release` entrypoint.
 */

const { join } = require('node:path');
const { VersionActions } = require('nx/release');

/** Matches `## Version: X.Y.Z` (TOC directive), capturing the prefix and the value separately. */
const VERSION_LINE = /^(##\s*Version:\s*)(.+?)[ \t]*$/m;

class TocVersionActions extends VersionActions {
    /**
     * We manage the TOC file directly (its name varies per addon — `BadgerTTK.toc`,
     * `BadgerArena.toc`), so we opt out of Nx's generic manifest machinery. With this
     * `null`, the base `init()`/`validate()` perform no manifest lookup or existence check.
     * @type {string[] | null}
     */
    validManifestFilenames = null;

    /**
     * Locate the addon's TOC file inside the project root.
     * @param {import('nx/src/generators/tree').Tree} tree
     * @returns {string | null} workspace-relative path to the `.toc`, or null if absent
     */
    _tocPath(tree) {
        const root = this.projectGraphNode.data.root;
        const tocName = (tree.children(root) || []).find((f) => f.toLowerCase().endsWith('.toc'));
        return tocName ? join(root, tocName) : null;
    }

    /**
     * Resolve the current version from the TOC `## Version:` line.
     * Called only when `currentVersionResolver` is `"disk"`.
     * @param {import('nx/src/generators/tree').Tree} tree
     */
    async readCurrentVersionFromSourceManifest(tree) {
        const manifestPath = this._tocPath(tree);
        if (!manifestPath) {
            return null;
        }
        const contents = tree.read(manifestPath, 'utf-8') || '';
        const match = contents.match(VERSION_LINE);
        if (!match) {
            throw new Error(
                `No "## Version:" line found in ${manifestPath} for project "${this.projectGraphNode.name}".`
            );
        }
        return { currentVersion: match[2], manifestPath };
    }

    /**
     * No remote registry backs a WoW addon — decline so Nx surfaces a clear error if a
     * user ever sets `currentVersionResolver: "registry"` for these projects.
     */
    async readCurrentVersionFromRegistry() {
        return null;
    }

    /**
     * Addons are standalone — there are no inter-addon dependencies to resolve.
     */
    async readCurrentVersionOfDependency() {
        return { currentVersion: null, dependencyCollection: null };
    }

    /**
     * Write the newly-derived version back into the TOC `## Version:` line, leaving the rest
     * of the file byte-identical.
     * @param {import('nx/src/generators/tree').Tree} tree
     * @param {string} newVersion
     */
    async updateProjectVersion(tree, newVersion) {
        const manifestPath = this._tocPath(tree);
        if (!manifestPath) {
            throw new Error(
                `No .toc file found in "${this.projectGraphNode.data.root}" for project "${this.projectGraphNode.name}".`
            );
        }
        const contents = tree.read(manifestPath, 'utf-8') || '';
        const updated = contents.replace(VERSION_LINE, `$1${newVersion}`);
        if (updated === contents) {
            throw new Error(`Could not update the "## Version:" line in ${manifestPath}.`);
        }
        tree.write(manifestPath, updated);
        return [`✍️  ${manifestPath} → ## Version: ${newVersion}`];
    }

    /**
     * Nothing to update — addons carry no dependency version specifiers.
     */
    async updateProjectDependencies() {
        return [];
    }
}

module.exports = TocVersionActions;
