#!/usr/bin/env bash

EPOCH_URL=https://github.com/pop-os/cosmic-epoch
OVERLAY_URL=https://github.com/fsvm88/cosmic-overlay

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
! which zstd &>/dev/null &&
    errorExit 2 "zstd was not found in $PATH, you need zstd installed to run this script"
! which git-lfs &>/dev/null &&
    errorExit 2 "git-lfs was not found in $PATH, you need git-lfs installed to run this script"

# Check if gh is authenticated and has required permissions
if ! gh auth status &>/dev/null; then
    errorExit 3 "GitHub CLI is not authenticated. Please run 'gh auth login' first"
fi

# Test release creation permissions by checking repo access
if ! gh repo view "${OVERLAY_URL}" --json 'viewerPermission' -q '.viewerPermission' | grep -q 'ADMIN'; then
    errorExit 4 "GitHub CLI lacks required permissions to create releases. Please ensure you have admin access to ${OVERLAY_URL}"
fi

# Check if we can read make.conf
if [ ! -f /etc/portage/make.conf ]; then
    errorExit 5 "Could not find /etc/portage/make.conf"
fi

# Source make.conf to check DISTDIR
# shellcheck disable=SC1091
source /etc/portage/make.conf

# Verify DISTDIR is set and writable
if [ -z "${DISTDIR}" ]; then
    error "DISTDIR not found in /etc/portage/make.conf"
    DISTDIR="/var/cache/distfiles" # Use default Gentoo location as fallback
fi
if [ ! -w "${DISTDIR}" ]; then
    errorExit 6 "DISTDIR (${DISTDIR}) is not writable"
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

function usage() {
    echo "Usage: $0 [-n|--dry-run] <version> [-rX] [package1 package2 ...]"
    echo "  -n, --dry-run   Only print the commands that would be run for tarball creation and GitHub upload."
    echo "  <version>      The tag or version to use (e.g. epoch-1.0.0-alpha.5)"
    echo "  -rX            Optional Gentoo release bump (e.g. -r1)"
    echo "  [packages...]  Optional list of submodules to process (default: all)"
}

# Parse arguments, allowing -n anywhere
args=()
dry_run=0
for arg in "$@"; do
    case "$arg" in
    -n | --dry-run)
        dry_run=1
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        args+=("$arg")
        ;;
    esac
done
set -- "${args[@]}"

if [ $# -lt 1 ]; then
    usage
    errorExit 1
fi

REQ_TAG="$1"
shift

# Check for optional -rX release bump
release_bump=""
if [[ "$1" =~ ^-r[0-9]+$ ]]; then
    release_bump="$1"
    shift
fi

# Remaining arguments are packages to process (if any)
if [ $# -gt 0 ]; then
    packages_to_process=("$@")
else
    packages_to_process=()
fi

# Convert tag to Gentoo version format once
base_gentoo_version="$(convert_version "${REQ_TAG}")"
if [ -n "$release_bump" ]; then
    gentoo_version="${base_gentoo_version}${release_bump}"
else
    gentoo_version="${base_gentoo_version}"
fi

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
git switch -d "${REQ_TAG}" || errorExit 13 "could not switch to tag ${REQ_TAG}"
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
    # If packages_to_process is set, skip modules not in the list
    if [ ${#packages_to_process[@]} -gt 0 ]; then
        skip=1
        for pkg in "${packages_to_process[@]}"; do
            if [[ "${module_path}" == "${pkg}" ]]; then
                skip=0
                break
            fi
        done
        if [ $skip -eq 1 ]; then
            continue
        fi
    fi
    echo "Processing submodule: ${module_path}"
    if [ -d "${module_path}" ]; then
        push_d "${module_path}"
        tarball_path_crates="${__temp_folder}/${module_path}-${gentoo_version}-crates.tar"
        zst_path_crates="${tarball_path_crates}.zst"
        tarball_path_repo="${__temp_folder}/${module_path}-${gentoo_version}-repo.tar"
        zst_path_repo="${tarball_path_repo}.zst"
        config_file="config.toml"

        # Pull LFS files if this is an LFS-enabled repository
        if [ -f ".gitattributes" ] && grep -q "filter=lfs" .gitattributes; then
            log "LFS repository detected, pulling LFS files..."
            if ! git lfs pull; then
                errorExit 21 "Failed to pull LFS files for ${module_path}"
            fi
        fi

        # Always package the full repository
        if [ $dry_run -eq 1 ]; then
            echo "DRY-RUN: Would run: tar -cf \"${tarball_path_repo}\" ."
            echo "DRY-RUN: Would run: zstd --long=31 -15 -T0 \"${tarball_path_repo}\" -o \"${zst_path_repo}\""
        else
            if tar -cf "${tarball_path_repo}" . &&
                zstd --long=31 -15 -T0 "${tarball_path_repo}" -o "${zst_path_repo}"; then
                rm -f "${tarball_path_repo}"
                log "Created compressed tarball (full repo): ${zst_path_repo}"
            else
                rm -f "${tarball_path_repo}" "${zst_path_repo}"
                errorExit 22 "Failed to create full-repo tarball for ${module_path}"
            fi
        fi

        # If Cargo.toml exists, also package the crates tarball
        if [ -f "Cargo.toml" ]; then
            if [ $dry_run -eq 1 ]; then
                echo "DRY-RUN: Would run: cargo vendor | head -n -0 >\"${config_file}\""
                echo "DRY-RUN: Would run: tar -cf \"${tarball_path_crates}\" vendor \"${config_file}\""
                echo "DRY-RUN: Would run: zstd --long=31 -15 -T0 \"${tarball_path_crates}\" -o \"${zst_path_crates}\""
            else
                if cargo vendor | head -n -0 >"${config_file}" &&
                    tar -cf "${tarball_path_crates}" vendor "${config_file}" &&
                    zstd --long=31 -15 -T0 "${tarball_path_crates}" -o "${zst_path_crates}"; then
                    rm -f "${tarball_path_crates}" # Remove the uncompressed tarball
                    rm -rf vendor "${config_file}"
                    log "Created compressed tarball: ${zst_path_crates}"
                else
                    rm -f "${tarball_path_crates}" "${zst_path_crates}" # Cleanup on failure
                    rm -rf vendor "${config_file}"                      # Clean vendor files on failure
                    errorExit 20 "Failed to create tarball for ${module_path}"
                fi
            fi
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
release_exists=0
if gh release view "${gentoo_version}" --repo "${OVERLAY_URL}" &>/dev/null; then
    log "Release ${gentoo_version} already exists, reusing."
    release_exists=1
fi
if [ $dry_run -eq 1 ]; then
    echo "DRY-RUN: Would run: gh release create \"${gentoo_version}\" --repo \"${OVERLAY_URL}\" --title \"${gentoo_version}\" --notes ... (unless it already exists)"
else
    if [ $release_exists -eq 0 ]; then
        if ! gh release create "${gentoo_version}" \
            --repo "${OVERLAY_URL}" \
            --title "${gentoo_version}" \
            --notes "Script-generated vendored crates for COSMIC ${gentoo_version}"; then
            errorExit 30 "Failed to create GitHub release"
        fi
    fi
fi

# Upload all generated tarballs (both crates and repo)
log "Uploading tarballs to release ${gentoo_version}..."
find "${__temp_folder}" -type f \( -name "*-crates.tar.zst" -o -name "*-repo.tar.zst" \) | while read -r tarball; do
    if [ $dry_run -eq 1 ]; then
        echo "DRY-RUN: Would run: gh release upload \"${gentoo_version}\" \"${tarball}\" --repo \"${OVERLAY_URL}\""
    else
        if ! gh release upload "${gentoo_version}" "${tarball}" --repo "${OVERLAY_URL}"; then
            errorExit 31 "Failed to upload ${tarball} to release"
        fi
        log "Uploaded: $(basename "${tarball}")"
    fi
done

# Copy tarballs to DISTDIR (both crates and repo)
log "Copying tarballs to DISTDIR (${DISTDIR})..."
find "${__temp_folder}" -type f \( -name "*-crates.tar.zst" -o -name "*-repo.tar.zst" \) | while read -r tarball; do
    if ! cp "${tarball}" "${DISTDIR}/"; then
        errorExit 32 "Failed to copy ${tarball} to ${DISTDIR}"
    fi
    log "Copied: $(basename "${tarball}") to ${DISTDIR}"
done

exit 0
