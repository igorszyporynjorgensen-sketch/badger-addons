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

echo ""
echo "Built -> ${dir}/.release/  — copy the package folder into your WoW Interface/AddOns/."
