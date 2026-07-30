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

# --- Build reproducibility: the BigWigs packager needs bash >= 4.3 (associative arrays), but macOS
# ships bash 3.2. This wrapper runs fine on 3.2; only the packager must be invoked with a modern bash
# (its own `#!/usr/bin/env bash` would otherwise pick up the system 3.2). Locate one; fail loudly if none.
# Portable by design: candidates include the PATH `bash`, so a Linux CI runner (native bash 5.x) needs no
# setup — `brew install bash` is a macOS-only concern. See docs/reference/release-runbook.md.
bash_ge_43() { # $1 = a bash executable; succeeds if its version is >= 4.3
    local v
    v="$("$1" -c 'printf "%s.%s" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"' 2>/dev/null)" || return 1
    case "${v}" in
        [5-9].* | [1-9][0-9].*) return 0 ;; # major >= 5
        4.[3-9] | 4.[1-9][0-9]) return 0 ;; # 4.3 .. 4.99
        *) return 1 ;;
    esac
}
modern_bash=""
brew_bash=""
command -v brew >/dev/null 2>&1 && brew_bash="$(brew --prefix 2>/dev/null)/bin/bash"
for cand in "${MODERN_BASH:-}" "${brew_bash}" /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash || true)"; do
    [ -n "${cand}" ] && [ -x "${cand}" ] || continue
    if bash_ge_43 "${cand}"; then
        modern_bash="${cand}"
        break
    fi
done
if [ -z "${modern_bash}" ]; then
    {
        echo "error: the BigWigs packager needs bash >= 4.3, but none was found on this machine."
        echo "       macOS ships bash 3.2. Install a modern bash once and re-run:"
        echo "         brew install bash"
        echo "       (or point MODERN_BASH=/path/to/bash at one you already have)."
    } >&2
    exit 1
fi

# Pin the BigWigs packager to a RELEASED tag, not `master` — fetching master made the build a moving target
# (it silently broke when upstream tightened its path checks). Bump this deliberately to adopt a newer
# packager. Latest tags: https://github.com/BigWigsMods/packager/releases
packager_version="v2.5.1"
packager="$(mktemp)"
stage="$(mktemp -d)"
trap 'rm -f "${packager}"; rm -rf "${stage}"' EXIT
curl -fsSL "https://raw.githubusercontent.com/BigWigsMods/packager/${packager_version}/release.sh" -o "${packager}"
chmod +x "${packager}"

package="$(awk -F': *' '/^package-as:/ { print $2; exit }' "${dir}/.pkgmeta")"
if [ -z "${package}" ]; then
    echo "error: no 'package-as:' in ${dir}/.pkgmeta" >&2
    exit 1
fi

# Monorepo staging. The packager expects topdir to be a STANDALONE addon checkout — its .toc, .pkgmeta AND a
# literal .git directory all in one place (it reads the TOC from topdir and requires a real .git there). Here
# the addon is a subdir and the only .git is the repo root's, which the packager can't reconcile (repo-root
# topdir hides the addon .toc; addon-dir topdir has no .git). So copy the addon into a temp dir, give it its
# own throwaway .git, and package THERE — then pull the packaged tree back into projects/<addon>/.release.
# Externals (Libs/) are re-fetched by the packager; the repo's .release/ and any fetched Libs/ are excluded.
rsync -a --exclude='.release/' --exclude='Libs/' --exclude='.git' --exclude='.DS_Store' "${dir}/" "${stage}/"
(
    cd "${stage}"
    git init -q
    git add -A
    git -c user.name='badger-build' -c user.email='build@local' commit -qm "stage ${project} for packaging" >/dev/null
    # -d skip upload · -z skip zip (we make the versioned zip below, after embedding internal libs).
    "${modern_bash}" "${packager}" -dz -r "${stage}/.release"
)
mkdir -p "${dir}/.release"
rm -rf "${dir:?}/.release/${package:?}"
cp -R "${stage}/.release/${package}" "${dir}/.release/${package}"

# --- Embed monorepo-internal shared libraries (NOT .pkgmeta externals) ---
# The packager copies only the addon's own tree + URL externals; a shared lib that lives ONCE under
# libs/<Name>/ is injected here into the packaged Libs/ for every addon whose .toc names it. Specs and
# project.json are stripped from the ship. (`package` was resolved from .pkgmeta above.)
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
