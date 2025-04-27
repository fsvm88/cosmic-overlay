#!/usr/bin/env bash

EPOCH_URL=https://github.com/pop-os/cosmic-epoch
OVERLAY_URL=https://github.com/fsvm88/cosmic-overlay

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"
# Compose the cosmic-de ebuild folder
__cosmic_de_dir="${__script_dir}/cosmic-de"

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
    # for x in "${CLEANUP_DIRS_FILES[@]}"; do
    #     # error "would remove: ${x}"
    #     rm -rf "${x}"
    # done
    echo ""
}
trap cleanup EXIT SIGINT SIGTERM

! which git &>/dev/null &&
    errorExit 2 "git was not found in $PATH, you need git installed to run this script"
! which jq &>/dev/null &&
    errorExit 2 "jq was not found in $PATH, you need jq installed to run this script"
! which gh &>/dev/null &&
    errorExit 2 "GitHub CLI (gh) was not found in $PATH, you need gh installed to run this script"

# Check if gh is authenticated and has required permissions
if ! gh auth status &>/dev/null; then
    errorExit 3 "GitHub CLI is not authenticated. Please run 'gh auth login' first"
fi

# Test release creation permissions by checking repo access
if ! gh repo view "${OVERLAY_URL}" --json 'viewerPermission' -q '.viewerPermission' | grep -q 'ADMIN'; then
    errorExit 4 "GitHub CLI lacks required permissions to create releases. Please ensure you have admin access to ${OVERLAY_URL}"
fi

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

# gets the current hash for the given sub-module
# $1: file to search
# $2: string to search for
function get_commit_hash() {
    [ $# -ne 2 ] && errorExit 254 "function requires 2 args, supplied $#"
    [ ! -f "$1" ] && errorExit 253 "file does not exist: ${1}"
    local hash=
    hash="$(grep " $2" "$1" | awk '{ print $2; }')"
    # shellcheck disable=SC2181
    [ $? -ne 0 ] && errorExit 252 "could not find submodule or hash for: $2 in $1"
    echo -n "${hash:0:7}"
    return 0
}

################# MAIN ####################
# Check if version argument is provided
[ $# -ne 1 ] && errorExit 1 "Usage: $0 <version>"
REQ_TAG="$1"
# Convert tag to Gentoo version format once
gentoo_version="$(convert_version "${REQ_TAG}")"

# Check if the requested tag exists on remote
git ls-remote --exit-code "${EPOCH_URL}" refs/tags/"${REQ_TAG}" &>/dev/null ||
    errorExit 5 "tag ${REQ_TAG} does not exist on remote ${EPOCH_URL}"

# Clone the main repo to a temporary folder
# Switch to the requested tag
__temp_folder=
__temp_folder="$(mktemp -d)"
# shellcheck disable=SC2181
[ $? -ne 0 ] && errorExit 10 "could not create temporary folder for cloning"
echo "Temp folder: ${__temp_folder}"
CLEANUP_DIRS_FILES+=("${__temp_folder}")
push_d "${__temp_folder}"
git clone --recurse-submodules ${EPOCH_URL} || errorExit 12 "could not clone git repo or submodules"
push_d "cosmic-epoch"
# Switch to the requested tag
git switch -d "${1}" || errorExit 13 "could not switch to tag ${1}"
git submodule update --recursive --force || errorExit 14 "could not update submodules"
# Generate list of modules for later querying
__temp_submodule_hashes="${__temp_folder}/git.hashes"
git ls-tree HEAD --format='%(objecttype) %(objectname) %(path)' | grep ^commit >"${__temp_submodule_hashes}"
pop_d
pop_d

# Process all submodules in cosmic-epoch
distdir="${__temp_folder}/distdir"
mkdir -p "${distdir}"
push_d "${__temp_folder}/cosmic-epoch"
while IFS= read -r module_path; do
    echo "Processing submodule: ${module_path}"
    if [ -d "${module_path}" ]; then
        push_d "${module_path}"
        if [ -f "Cargo.toml" ]; then
            # Get the current commit hash
            commit_hash="$(git rev-parse --short HEAD)"
            tarball_path="${__temp_folder}/${module_path}-${gentoo_version}-${commit_hash}-crates.tar"
            zst_path="${tarball_path}.zst"

            # Create vendor directory and archive it
            if cargo vendor "${distdir}/vendor" &&
                tar -C "${distdir}" -cf "${tarball_path}" vendor &&
                zstd --long=31 -15 -T0 "${tarball_path}" -o "${zst_path}"; then
                rm -f "${tarball_path}" # Remove the uncompressed tarball
                rm -rf "${distdir}/vendor"
                log "Created compressed tarball: ${zst_path}"
            else
                rm -f "${tarball_path}" "${zst_path}" # Cleanup on failure
                errorExit 20 "Failed to create tarball for ${module_path}"
            fi

            # Legacy pycargoebuild implementation kept for reference
            # if grep -q '^\[workspace\]' Cargo.toml; then
            #     # This is a workspace, get all members
            #     members=$(cargo metadata --no-deps | jq '.packages[].name' -r | tr '\n' ' ')
            #     pycargoebuild ${members} \
            #         --crate-tarball \
            #         --crate-tarball-path "${tarball_path}"
            # else
            #     # Single crate
            #     pycargoebuild . \
            #         --crate-tarball \
            #         --crate-tarball-path "${tarball_path}"
            # fi
        else
            log "Skipping ${module_path} - no Cargo.toml found"
        fi
        pop_d
    else
        error "Submodule directory not found: ${module_path}"
    fi
done < <(awk '{ print $3; }' "${__temp_submodule_hashes}")
pop_d

# Convert tag to Gentoo version for release
gentoo_version="$(convert_version "${REQ_TAG}")"

# Create GitHub release
log "Creating GitHub release for tag ${gentoo_version}..."
if ! gh release create "${gentoo_version}" \
    --repo "${OVERLAY_URL}" \
    --title "${gentoo_version}" \
    --notes "Script-generated vendored crates for COSMIC ${gentoo_version}"; then
    errorExit 30 "Failed to create GitHub release"
fi

# Upload all generated tarballs
log "Uploading tarballs to release ${gentoo_version}..."
find "${__temp_folder}" -name "*-crates.tar.zst" -type f | while read -r tarball; do
    if ! gh release upload "${gentoo_version}" "${tarball}" --repo "${OVERLAY_URL}"; then
        errorExit 31 "Failed to upload ${tarball} to release"
    fi
    log "Uploaded: $(basename "${tarball}")"
done

exit 0
