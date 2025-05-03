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
function convert_version() {
    local ver="$1"
    # Remove epoch- prefix if present
    ver="${ver#epoch-}"
    # Replace dash before alpha/beta/rc with underscore
    ver="${ver/-alpha/_alpha}"
    ver="${ver/-beta/_beta}"
    ver="${ver/-rc/_rc}"
    # Remove dots only in alpha/beta/rc version numbers
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

    template_file="${pkg_dir}-9999.ebuild"
    ebuild_file="${pkg_dir}-${VERSION}.ebuild"

    [ ! -f "${template_file}" ] &&
        errorExit 4 "could not find template file: ${template_file}"

    if [ ! -f "${ebuild_file}" ]; then
        cp "${template_file}" "${ebuild_file}" ||
            errorExit 5 "could not create ${ebuild_file} from template"
        log "Created new ebuild ${ebuild_file} from template"

        # Update version, remove live ebuild settings, set KEYWORDS, and update git ref
        sed -i \
            -e "s:9999:${VERSION}:" \
            -e 's:KEYWORDS=.*:KEYWORDS="~amd64":' \
            -e '/^inherit.*live.*/d' \
            -e '/PROPERTIES=/d' \
            -e '/EGIT_BRANCH=/c\EGIT_COMMIT="'"${ORIGINAL_VERSION}"'"' \
            "${ebuild_file}" ||
            errorExit 120 "${ebuild_file}: could not update version"

        # Ensure COSMIC_GIT_UNPACK is set
        if ! grep -q "COSMIC_GIT_UNPACK=" "${ebuild_file}"; then
            sed -i \
                -e '/^inherit cosmic-de/i COSMIC_GIT_UNPACK=1\n' \
                "${ebuild_file}" ||
                errorExit 124 "${ebuild_file}: could not add COSMIC_GIT_UNPACK"
        fi

        ebuild "${ebuild_file}" digest ||
            errorExit 121 "${ebuild_file}: could not refresh digest"
        git add "${ebuild_file}" ||
            errorExit 122 "${ebuild_file}: could not git-add changes"
        bumped_pkgs+=("${pkg_dir}-${VERSION}")
        log "Added ${ebuild_file} to staging"
    else
        log "SKIPPING ${ebuild_file}, already exists"
    fi
    pop_d
done

# Commit all changes if any packages were bumped
if [ ${#bumped_pkgs[@]} -gt 0 ]; then
    commit_msg="cosmic-base: add version ${VERSION} for:"$'\n'
    for pkg in "${bumped_pkgs[@]}"; do
        commit_msg+="- ${pkg}"$'\n'
    done
    git commit -m "${commit_msg}" ||
        errorExit 123 "could not commit changes for: ${bumped_pkgs[*]}"
    log "Committed changes for: ${bumped_pkgs[*]}"
fi

log "ALL DONE! do not forget to test and push!"
exit 0
