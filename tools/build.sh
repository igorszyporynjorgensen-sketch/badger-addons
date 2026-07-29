#!/usr/bin/env bash
# Build an installable addon — with .pkgmeta externals fetched — via the BigWigs packager.
# Output: projects/<project>/.release/<PackageName>/  (copy that folder into WoW's Interface/AddOns/).
# Best-effort convenience wrapper; run the packager directly for full control of its flags.
set -euo pipefail

project="${1:?usage: build.sh <project>   (e.g. badger-arena)}"
dir="projects/${project}"

if [ ! -f "${dir}/.pkgmeta" ]; then
    echo "error: ${dir}/.pkgmeta not found" >&2
    exit 1
fi

packager="$(mktemp)"
trap 'rm -f "${packager}"' EXIT
curl -fsSL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh -o "${packager}"
chmod +x "${packager}"

# -d skip upload · -z skip zip · -r <dir> output root (relative to the addon dir).
(cd "${dir}" && "${packager}" -dz -r .release)

# --- Embed monorepo-internal shared libraries (NOT .pkgmeta externals) ---
# The packager copies only the addon's own tree + URL externals; a shared lib that lives ONCE under
# libs/<Name>/ is injected here into the packaged Libs/ for every addon whose .toc names it. Specs and
# project.json are stripped from the ship.
package="$(awk -F': *' '/^package-as:/ { print $2; exit }' "${dir}/.pkgmeta")"
pkgdir="${dir}/.release/${package}"
if [ -d libs ] && [ -d "${pkgdir}" ]; then
    for lib in libs/*/; do
        name="$(basename "${lib}")"
        if grep -qs "${name}" "${dir}"/*.toc; then
            echo "Embedding internal lib ${name} -> ${pkgdir}/Libs/${name}"
            rsync -a --exclude='*_spec.lua' --exclude='project.json' "${lib}" "${pkgdir}/Libs/${name}/"
        fi
    done
fi

# --- Package a versioned zip (WO-064) --------------------------------------------------------------
# The BigWigs packager runs with -z (skip zip) because we embed the internal libs AFTER it; so we make
# the zip ourselves, here, once the package is complete. It is NAMED from the packaged .toc's
# `## Version`, so the filename can never drift from what the client reports (e.g. BadgerTTK-0.9.44.zip).
# Upload this file to CurseForge as a Release (the newest Release is auto-featured); paste the matching
# CHANGELOG section into the file's Changelog box.
if [ -d "${pkgdir}" ] && command -v zip >/dev/null 2>&1; then
    version="$(awk -F': *' '/^## Version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
        "${pkgdir}/${package}.toc")"
    if [ -n "${version}" ]; then
        zipname="${package}-${version}.zip"
        (cd "${dir}/.release" && rm -f "${zipname}" && zip -rq "${zipname}" "${package}")
        echo "Packaged -> ${dir}/.release/${zipname}"
    else
        echo "warning: no '## Version' in ${pkgdir}/${package}.toc — skipped zip" >&2
    fi
elif ! command -v zip >/dev/null 2>&1; then
    echo "warning: 'zip' not found — skipped the versioned zip step" >&2
fi

echo ""
echo "Built -> ${dir}/.release/  — copy the package folder into your WoW Interface/AddOns/,"
echo "or upload the ${package}-<version>.zip to CurseForge."
