#!/usr/bin/env bash

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"
# Compose the cosmic-base ebuild folder
__cosmic_de_dir="${__script_dir}/cosmic-base"

function log() { echo >&2 "$*"; }
function error() { log "ERROR: $*"; }
function errorExit() {
    local -r rc="$1"
    shift 1
    error "$*"
    exit "$rc"
}
function push_d() { pushd "$*" &>/dev/null || errorExit 5 "could not pushd to $*"; }
function pop_d() { popd &>/dev/null || errorExit 6 "could not popd from $PWD"; }
CLEANUP_DIRS_FILES=()
# shellcheck disable=SC2317
function cleanup() {
    for x in "${CLEANUP_DIRS_FILES[@]}"; do
        # error "would remove: ${x}"
        rm -rf "${x}"
    done
}
trap cleanup EXIT SIGINT SIGTERM

# Convert cosmic version to Gentoo version format
# Example: epoch-1.0.0-alpha.5 → 1.0.0_alpha5
# Example: epoch-1.0.0-beta.1.1 → 1.0.0_beta1_p1
function convert_version() {
    local ver="$1"
    # Remove epoch- prefix if present
    ver="${ver#epoch-}"
    # Replace dash before alpha/beta/rc with underscore
    ver="${ver/-alpha/_alpha}"
    ver="${ver/-beta/_beta}"
    ver="${ver/-rc/_rc}"
    
    # Handle minor release versions (patch versions) first
    # Match patterns like _alpha.X.Y or _beta.X.Y and convert to _alphaX_pY or _betaX_pY
    if [[ "$ver" =~ (_alpha)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    if [[ "$ver" =~ (_beta)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    if [[ "$ver" =~ (_rc)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    
    # Remove dots only in alpha/beta/rc version numbers (for cases without minor versions)
    ver="${ver/_alpha./_alpha}"
    ver="${ver/_beta./_beta}"
    ver="${ver/_rc./_rc}"
    echo "$ver"
}

# Check if version argument is provided
[ $# -ne 1 ] && errorExit 1 "Usage: $0 <version>"
ORIGINAL_VERSION="$1"
VERSION="$(convert_version "${ORIGINAL_VERSION}")"

# Process each cosmic package
push_d "${__cosmic_de_dir}"
declare -a bumped_pkgs=()

for pkg_dir in cosmic-* xdg-desktop-portal-cosmic; do
    [ ! -d "${pkg_dir}" ] && continue
    push_d "${pkg_dir}"

    # Find the latest tagged ebuild (excluding 9999) using shell globs and array
    candidates=()
    for f in "${pkg_dir}"-*.ebuild; do
        [[ "$f" == *-9999.ebuild ]] && continue
        [ -e "$f" ] && candidates+=("$f")
    done
    if [ ${#candidates[@]} -gt 0 ]; then
        template_file=$(printf '%s\n' "${candidates[@]}" | sort -V | tail -n1)
    else
        template_file="${pkg_dir}-9999.ebuild"
    fi
    ebuild_file="${pkg_dir}-${VERSION}.ebuild"

    [ ! -f "${template_file}" ] &&
        errorExit 4 "could not find template file: ${template_file}"

    if [ ! -f "${ebuild_file}" ]; then
        log "Processing ${pkg_dir}..."
        
        # Step 1: Create new ebuild and substitute variables
        cp "${template_file}" "${ebuild_file}" ||
            errorExit 5 "could not create ${ebuild_file} from template"
        log "  Created new ebuild ${ebuild_file} from template"

        # Update version, remove live ebuild settings, set KEYWORDS, update git ref, and update MY_PV
        sed -i \
            -e 's:KEYWORDS=.*:KEYWORDS="~amd64":' \
            -e '/^inherit.*live.*/d' \
            -e '/PROPERTIES=/d' \
            -e '/EGIT_BRANCH=/c\EGIT_COMMIT="'"${ORIGINAL_VERSION}"'"' \
            -e 's:^MY_PV=.*:MY_PV="'"${ORIGINAL_VERSION}"'":' \
            "${ebuild_file}" ||
            errorExit 120 "${ebuild_file}: could not update version"

        # Ensure COSMIC_GIT_UNPACK is NOT set for tagged releases (they use SRC_URI)
        if grep -q "^COSMIC_GIT_UNPACK=" "${ebuild_file}"; then
            sed -i \
                -e '/^COSMIC_GIT_UNPACK=/d' \
                "${ebuild_file}" ||
                errorExit 124 "${ebuild_file}: could not remove COSMIC_GIT_UNPACK"
        fi
        log "  Updated ebuild variables"

        # Step 2: Generate manifest (only if package has SRC_URI)
        ebuild "${ebuild_file}" manifest ||
            errorExit 121 "${ebuild_file}: could not generate manifest"
        
        # Step 3: Commit ebuild and manifest together (if manifest exists)
        if [ -f "Manifest" ]; then
            log "  Generated manifest"
            git add "${ebuild_file}" Manifest ||
                errorExit 122 "${ebuild_file}: could not git-add changes"
        else
            log "  No manifest needed (no SRC_URI)"
            git add "${ebuild_file}" ||
                errorExit 122 "${ebuild_file}: could not git-add ebuild"
        fi
        
        git commit -m "cosmic-base/${pkg_dir}: add ${VERSION}" ||
            errorExit 123 "${ebuild_file}: could not commit changes"
        
        bumped_pkgs+=("${pkg_dir}-${VERSION}")
        log "  Committed ${pkg_dir}-${VERSION}"
        log ""
    else
        log "SKIPPING ${ebuild_file}, already exists"
    fi
    pop_d
done

# Summary
if [ ${#bumped_pkgs[@]} -gt 0 ]; then
    log "Successfully bumped ${#bumped_pkgs[@]} package(s) to version ${VERSION}:"
    for pkg in "${bumped_pkgs[@]}"; do
        log "  - ${pkg}"
    done
else
    log "No packages were bumped (all already exist)"
fi

log "ALL DONE! do not forget to test and push!"
exit 0
