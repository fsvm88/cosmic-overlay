#!/usr/bin/env bash

# Unified COSMIC Overlay Ebuild Bump & QA Script
# Processes packages one at a time with full validation and reporting

set -euo pipefail

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"
__cosmic_de_dir="${__script_dir}/cosmic-base"

# Color codes for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' NC=''
fi

# Global variables
ORIGINAL_TAG=""
GENTOO_VERSION=""
REVISION_BUMP=""
SINGLE_PACKAGE=""
KEEP_TEMP=1          # Default: enabled
NO_UPLOAD=0
NO_COMMIT=0
DRY_RUN=0
VERBOSE=0
LOG_FILE=""
TEMP_DIR=""
DISTDIR=""
TIMESTAMP=""

# Repository configuration (can be overridden via environment variables)
COSMIC_EPOCH_REPO="${COSMIC_EPOCH_REPO:-https://github.com/pop-os/cosmic-epoch}"
COSMIC_OVERLAY_REPO="${COSMIC_OVERLAY_REPO:-fsvm88/cosmic-overlay}"

# Reproducibility: fixed timestamp for deterministic archives
# Can be overridden via environment variable
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"

# State tracking
declare -a COMPLETED_PACKAGES=()
declare -a FAILED_PACKAGES=()
declare -a PATCHES_COMMENTED=()
declare -A MISSING_DEPS=()
declare -A QA_ISSUES=()

# Logging functions
function log() {
    echo -e "${*}" | tee -a "${LOG_FILE:-/dev/null}" >&2
}

function log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} ${*}" | tee -a "${LOG_FILE:-/dev/null}" >&2
    else
        echo -e "${*}" >> "${LOG_FILE:-/dev/null}"
    fi
}

function log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

function log_success() {
    log "${GREEN}[✓]${NC} $*"
}

function log_warning() {
    log "${YELLOW}[⚠]${NC} $*"
}

function log_error() {
    log "${RED}[✗]${NC} $*"
}

function log_phase() {
    log "${MAGENTA}[PHASE]${NC} $*"
}

function error() {
    log_error "$*"
}

function errorExit() {
    local -r rc="$1"
    shift 1
    error "$*"
    exit "$rc"
}

function push_d() {
    pushd "$*" &>/dev/null || errorExit 5 "could not pushd to $*"
}

function pop_d() {
    popd &>/dev/null || errorExit 6 "could not popd from $PWD"
}

CLEANUP_DIRS_FILES=()
TEMP_FILES_CREATED=()

# Track a temporary file/directory for cleanup
function track_temp() {
    local path="$1"
    TEMP_FILES_CREATED+=("$path")
    log_verbose "Tracking temp file: $path"
}

function cleanup() {
    if [[ $KEEP_TEMP -eq 0 ]]; then
        # Clean up all tracked temp files first
        for x in "${TEMP_FILES_CREATED[@]}"; do
            if [[ -e "$x" ]]; then
                log_verbose "Removing: ${x}"
                rm -rf "${x}"
            fi
        done

        # Then clean up main directories
        for x in "${CLEANUP_DIRS_FILES[@]}"; do
            if [[ -e "$x" ]]; then
                log_verbose "Removing: ${x}"
                rm -rf "${x}"
            fi
        done
    fi
}
trap cleanup EXIT SIGINT SIGTERM

# Convert cosmic version to Gentoo version format
# Example: epoch-1.0.0-alpha.5 → 1.0.0_alpha5
# Example: epoch-1.0.0-beta.1.1 → 1.0.0_beta1_p1
function convert_version() {
    local ver="$1"
    ver="${ver#epoch-}"

    # Handle pre-release versions: -alpha.N, -beta.N, -rc.N
    # Convert to: _alphaN, _betaN, _rcN
    # If there's a second number (N.M), add _pM
    ver="${ver/-alpha\./_alpha}"
    ver="${ver/-beta\./_beta}"
    ver="${ver/-rc\./_rc}"

    # Now handle the second dot if present: alpha.N.M → alphaN_pM
    # Use sed for this complex replacement
    ver=$(echo "$ver" | sed -E 's/_alpha([0-9]+)\.([0-9]+)/_alpha\1_p\2/g')
    ver=$(echo "$ver" | sed -E 's/_beta([0-9]+)\.([0-9]+)/_beta\1_p\2/g')
    ver=$(echo "$ver" | sed -E 's/_rc([0-9]+)\.([0-9]+)/_rc\1_p\2/g')

    echo "$ver"
}

# Validate ORIGINAL_TAG format
# Ensures tag follows epoch-X.Y.Z or similar naming convention
function validate_original_tag() {
    local tag="$1"
    
    if [[ -z "$tag" ]]; then
        errorExit 100 "ORIGINAL_TAG cannot be empty"
    fi
    
    # Tag should start with 'epoch-' followed by version-like pattern
    # Allow: epoch-1.0.0, epoch-1.0.0-alpha.1, epoch-1.0.0-beta.2, etc.
    if ! [[ "$tag" =~ ^epoch-[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        errorExit 100 "Invalid tag format: ${tag}
Expected format: epoch-X.Y.Z or epoch-X.Y.Z-{alpha|beta|rc}.N
Examples: epoch-1.0.0, epoch-1.0.0-alpha.1, epoch-1.0.0-beta.2"
    fi
    
    # Reject tags with suspicious shell metacharacters or control characters
    # Using character class that doesn't need as much escaping
    if [[ "$tag" =~ [\;\|\&\<\>\$\`] ]]; then
        errorExit 100 "Tag contains suspicious characters: ${tag}"
    fi
    
    log_verbose "Tag validation passed: ${tag}"
}

# Validate SINGLE_PACKAGE input
# Ensures package name is sane and won't cause path traversal issues
function validate_single_package() {
    local pkg="$1"
    
    if [[ -z "$pkg" ]]; then
        return 0  # Empty is OK, means process all packages
    fi
    
    # Package names should only contain alphanumerics and hyphens
    if ! [[ "$pkg" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        errorExit 101 "Invalid package name: ${pkg}
Package names must contain only alphanumerics, hyphens, underscores, and dots"
    fi
    
    # Reject suspicious patterns like path traversal
    if [[ "$pkg" =~ \.\. ]] || [[ "$pkg" =~ ^/ ]]; then
        errorExit 101 "Package name cannot contain '..' or start with '/': ${pkg}"
    fi
    
    log_verbose "Package validation passed: ${pkg}"
}

# Validate repository paths for sanity
# Ensures repo paths don't contain suspicious elements that could cause issues
function validate_repo_path() {
    local path_desc="$1"
    local path="$2"
    
    if [[ -z "$path" ]]; then
        errorExit 102 "${path_desc} cannot be empty"
    fi
    
    # Reject obvious malicious patterns
    if [[ "$path" =~ [\;\|\&\<\>\`\'\"] ]]; then
        errorExit 102 "${path_desc} contains shell metacharacters: ${path}"
    fi
    
    # Check if it's a URL, path should look reasonable
    if [[ "$path" == https://* ]] || [[ "$path" == http://* ]]; then
        # URLs should be well-formed
        if ! [[ "$path" =~ ^https?://[a-zA-Z0-9._-]+(/[a-zA-Z0-9._/-]*)?$ ]]; then
            errorExit 102 "Invalid repository URL: ${path}"
        fi
    fi
    
    log_verbose "${path_desc} validation passed"
}

# Manifest race condition prevention
# When multiple script instances run on different packages in the same cosmic-base/ directory,
# they can corrupt the Manifest file. This happens because:
#
# Instance A (package cosmic-edit):
#   1. Read Manifest (contains entries for N packages)
#   2. Add entry for cosmic-edit
#   3. Write Manifest back
#
# Instance B (package cosmic-settings, starting simultaneously):
#   1. Read Manifest (contains entries for N packages) <- sees state BEFORE A's write
#   2. Add entry for cosmic-settings
#   3. Write Manifest back <- OVERWRITES A's changes! Instance A's edit is lost
#
# Result: Manifest is corrupted, one package's entry is missing
#
# SOLUTION: Use file locking around Manifest operations
# - acquire_manifest_lock: Obtain exclusive lock on Manifest file
# - release_manifest_lock: Release the lock
# - MANIFEST_LOCK_FD: File descriptor used for lock (defaults to 200)
#
# This serializes Manifest modifications across concurrent script invocations.

MANIFEST_LOCK_FD=200

function acquire_manifest_lock() {
    local pkg="$1"
    local lock_dir="${__cosmic_de_dir}/${pkg}"
    
    # Use directory as lock to avoid permission issues with lock files
    if ! mkdir -p "${lock_dir}/.manifest.lock" 2>/dev/null; then
        log_warning "[${pkg}] Could not acquire Manifest lock - proceeding without lock (may cause corruption if concurrent)"
        return 1
    fi
    
    log_verbose "[${pkg}] Acquired Manifest lock"
    return 0
}

function release_manifest_lock() {
    local pkg="$1"
    local lock_dir="${__cosmic_de_dir}/${pkg}"
    
    if [[ -d "${lock_dir}/.manifest.lock" ]]; then
        if rmdir "${lock_dir}/.manifest.lock" 2>/dev/null; then
            log_verbose "[${pkg}] Released Manifest lock"
        fi
    fi
}

# Map -sys crates to Gentoo packages
function map_sys_crate_to_package() {
    local crate="$1"
    case "$crate" in
        "dirs-sys"|"drm-sys"|"inotify-sys"|"libbz2-rs-sys"|"linux-raw-sys"|"cosmic-settings-sys")
            # Raw bindings, no system lib needed
            echo ""
            ;;
        "bzip2-sys") echo "app-arch/bzip2:0" ;;
        "clang-sys") echo "llvm-core/clang" ;;
        "gbm-sys") echo "media-libs/mesa:0" ;;
        "gettext-sys") echo "sys-devel/gettext:0" ;;
        "gio-sys"|"glib-sys"|"gobject-sys") echo "dev-libs/glib:2" ;;
        "gstreamer-sys") echo "media-libs/gstreamer:1.0" ;;
        "gstreamer-app-sys"|"gstreamer-audio-sys"|"gstreamer-base-sys"|"gstreamer-pbutils-sys"|"gstreamer-tag-sys"|"gstreamer-video-sys")
            echo "media-libs/gstreamer:1.0 media-libs/gst-plugins-base:1.0"
            ;;
        "input-sys") echo "dev-libs/libinput:0/10" ;;
        "libdbus-sys") echo "sys-apps/dbus:0" ;;
        "libdisplay-info-sys") echo "media-libs/libdisplay-info:0" ;;
        "libflatpak-sys") echo "sys-apps/flatpak:0" ;;
        "libseat-sys") echo "sys-auth/seatd:0" ;;
        "libspa-sys"|"pipewire-sys") echo "media-video/pipewire:0" ;;
        "libudev-sys") echo "virtual/libudev:0" ;;
        "openssl-sys") echo "dev-libs/openssl:0/3" ;;
        "pam-sys") echo "sys-libs/pam:0" ;;
        "wayland-sys") echo "dev-libs/wayland:0" ;;
        "zstd-sys") echo "app-arch/zstd:0" ;;
        "liblzma-sys") echo "app-arch/xz-utils:0" ;;
        "libpulse-sys") echo "media-libs/libpulse:0" ;;
        "pixman-sys") echo "x11-libs/pixman:0" ;;
        *)
            log_warning "Unknown -sys crate: ${crate}"
            echo "UNKNOWN:${crate}"
            ;;
    esac
}

# Initialize logging (state file removed - no resume mode)
function init_logging() {
    TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
    LOG_FILE="${__script_dir}/.bump-${GENTOO_VERSION}-${TIMESTAMP}.log"

    log_info "Log file: ${LOG_FILE}"
}

# Update gitignore
function update_gitignore() {
    local gitignore="${__script_dir}/.gitignore"

    if [[ ! -f "$gitignore" ]]; then
        log_info "Creating .gitignore"
        cat > "$gitignore" <<EOF
.bump-*.log
EOF
    else
        if ! grep -q ".bump-\*.log" "$gitignore"; then
            log_info "Adding bump log files to .gitignore"
            echo ".bump-*.log" >> "$gitignore"
        fi
    fi
}

# Manifest backup/restore helpers
function backup_manifest() {
    local pkg="$1"
    push_d "${__cosmic_de_dir}/${pkg}"
    if [[ -f "Manifest" ]]; then
        cp "Manifest" "Manifest.backup"
        log_verbose "[${pkg}] Manifest backed up"
    fi
    pop_d
}

function restore_manifest() {
    local pkg="$1"
    push_d "${__cosmic_de_dir}/${pkg}"
    if [[ -f "Manifest.backup" ]]; then
        mv "Manifest.backup" "Manifest"
        log_verbose "[${pkg}] Manifest restored from backup"
    fi
    pop_d
}

function cleanup_manifest_backup() {
    local pkg="$1"
    push_d "${__cosmic_de_dir}/${pkg}"
    rm -f "Manifest.backup"
    log_verbose "[${pkg}] Manifest backup cleaned up"
    pop_d
}

# Rollback package on failure
# Arguments: pkg phase [cleanup_ebuild] [cleanup_workdir]
# cleanup_ebuild: if 1, remove the generated ebuild file
# cleanup_workdir: if 1, run 'ebuild clean' to clear work directory
function rollback_package() {
    local pkg="$1"
    local phase="${2:-unknown}"
    local cleanup_ebuild="${3:-0}"
    local cleanup_workdir="${4:-0}"

    log_verbose "[${pkg}] Rolling back from phase: ${phase}"

    # Always restore Manifest if it was modified
    if ! restore_manifest "$pkg" 2>&1; then
        log_warning "[${pkg}] Manifest restore failed or not needed (may not have been modified)"
    fi

    # Always clean up Manifest.backup to prevent partial state leakage
    push_d "${__cosmic_de_dir}/${pkg}"
    if [[ -f "Manifest.backup" ]]; then
        rm -f "Manifest.backup"
        log_verbose "[${pkg}] Cleaned up Manifest.backup"
    fi
    pop_d

    # Remove generated ebuild if requested
    if [[ $cleanup_ebuild -eq 1 ]]; then
        push_d "${__cosmic_de_dir}/${pkg}"
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild.backup"

        # Clean workdir if requested
        if [[ $cleanup_workdir -eq 1 ]]; then
            ebuild "${pkg}-${GENTOO_VERSION}.ebuild" clean >/dev/null 2>&1 || true
        fi

        # Try to restore from git
        if ! git checkout -- "${pkg}-${GENTOO_VERSION}.ebuild" 2>&1 | tee -a "${LOG_FILE}"; then
            log_warning "[${pkg}] Could not restore ebuild from git (may not be tracked)"
        else
            log_verbose "[${pkg}] Restored ebuild from git"
        fi
        pop_d
    fi

    # Clean up source archive
    local source_archive="${pkg}-${GENTOO_VERSION}.tar.zst"
    if [[ -f "${DISTDIR}/${source_archive}" ]]; then
        log_verbose "[${pkg}] Cleaning up failed source archive from DISTDIR"
        rm -f "${DISTDIR}/${source_archive}"
    fi
    rm -f "${TEMP_DIR}/${source_archive}"

    # Clean up crates tarball
    local tarball_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    if [[ -f "${DISTDIR}/${tarball_zst}" ]]; then
        log_verbose "[${pkg}] Cleaning up failed crates tarball from DISTDIR"
        rm -f "${DISTDIR}/${tarball_zst}"
    fi
    rm -f "${TEMP_DIR}/${tarball_zst}"
}

# Execute a phase with standard error handling
# Arguments: pkg phase_name phase_function [cleanup_ebuild] [cleanup_workdir]
# Returns: 0 on success, 1 on failure
# Note: run_phase function removed - phases now handle errors directly in process_package()

# Retry a command with exponential backoff
# Arguments: max_attempts command [args...]
# Returns: 0 on success, 1 on failure
function retry_with_backoff() {
    local max_attempts="$1"
    shift
    local -a cmd=("$@")
    local attempt=1
    local wait_time=2

    while [[ $attempt -le $max_attempts ]]; do
        if "${cmd[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Attempt ${attempt}/${max_attempts} failed, retrying in ${wait_time}s..."
            sleep "$wait_time"
            # Exponential backoff: 2s, 4s, 8s, etc
            wait_time=$((wait_time * 2))
        fi

        ((attempt++))
    done

    log_error "All ${max_attempts} attempts failed"
    return 1
}

# Check environment and tools
function check_environment() {
    log_phase "Checking environment..."

    local tools=("git" "git-lfs" "gh" "cargo" "ebuild" "pkgdev" "pkgcheck" "zstd" "b2sum" "sha512sum" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            errorExit 2 "${tool} not found in PATH - required for this script"
        fi
        log_verbose "Found: ${tool}"
    done

    # Check GitHub CLI auth
    if ! gh auth status &>/dev/null; then
        errorExit 3 "GitHub CLI not authenticated. Run: gh auth login"
    fi

    # Validate repository paths
    validate_repo_path "COSMIC_EPOCH_REPO" "$COSMIC_EPOCH_REPO"
    validate_repo_path "COSMIC_OVERLAY_REPO" "$COSMIC_OVERLAY_REPO"

    # Check DISTDIR
    if [[ -f /etc/portage/make.conf ]]; then
        # shellcheck disable=SC1091
        source /etc/portage/make.conf
    fi

    if [[ -z "${DISTDIR}" ]]; then
        DISTDIR="/var/cache/distfiles"
        log_warning "DISTDIR not set, using default: ${DISTDIR}"
    fi

    if [[ ! -w "${DISTDIR}" ]]; then
        errorExit 6 "DISTDIR (${DISTDIR}) is not writable"
    fi

    log_success "Environment check passed"
}

# Clone or reuse cosmic-epoch repository
# Validate archive names for safety
# Prevents path traversal, special characters, and collision risks
function validate_archive_names() {
    local pkg="$1"

    local archive_source="${pkg}-${GENTOO_VERSION}.tar.zst"
    local archive_crates="${pkg}-${GENTOO_VERSION}-crates.tar.zst"

    # Check for suspicious characters or patterns in package name
    if [[ "${pkg}" =~ [^a-zA-Z0-9_-] ]]; then
        log_error "Invalid package name: '${pkg}' contains suspicious characters"
        return 1
    fi

    # Check archive names don't contain path traversal
    if [[ "${archive_source}" == *".."* ]] || [[ "${archive_crates}" == *".."* ]]; then
        log_error "Archive name validation failed: path traversal detected"
        return 1
    fi

    # Validate version string doesn't contain path separators
    if [[ "${GENTOO_VERSION}" =~ / ]]; then
        log_error "Invalid version string: '${GENTOO_VERSION}' contains path separators"
        return 1
    fi

    return 0
}

function prepare_cosmic_epoch() {
    log_phase "Preparing cosmic-epoch repository..."

    # Create new clone
    TEMP_DIR=$(mktemp -d -t cosmic-bump.XXXXXX)
    log_info "Created temp directory: ${TEMP_DIR}"

    # Verify TEMP_DIR is writable (fail early if not)
    if [[ ! -w "${TEMP_DIR}" ]]; then
        errorExit 11 "TEMP_DIR (${TEMP_DIR}) is not writable"
    fi

    CLEANUP_DIRS_FILES+=("${TEMP_DIR}")

    push_d "${TEMP_DIR}"
    log_info "Cloning cosmic-epoch..."
    git clone --recurse-submodules "$COSMIC_EPOCH_REPO" || \
        errorExit 12 "could not clone cosmic-epoch repository"

    push_d "cosmic-epoch"

    # Verify tag exists
    if ! git tag | grep -q "^${ORIGINAL_TAG}\$"; then
        errorExit 15 "Tag ${ORIGINAL_TAG} does not exist in repository"
    fi

    log_info "Checking out tag: ${ORIGINAL_TAG}"
    git switch -d "${ORIGINAL_TAG}" || errorExit 13 "could not switch to tag ${ORIGINAL_TAG}"

    log_info "Updating submodules..."
    git submodule update --recursive --force || errorExit 14 "could not update submodules"

    pop_d # cosmic-epoch
    pop_d # TEMP_DIR

    log_success "cosmic-epoch prepared at ${TEMP_DIR}/cosmic-epoch"
}

# Check if a package is a meta-package (no source, just dependencies)
function is_meta_package() {
    local pkg="$1"
    # cosmic-meta and pop-theme-meta are meta packages
    [[ "$pkg" == "cosmic-meta" ]] || [[ "$pkg" == "pop-theme-meta" ]]
}

# Generate list of packages to process
function get_package_list() {
    if [[ -n "${SINGLE_PACKAGE}" ]]; then
        echo "${SINGLE_PACKAGE}"
        return
    fi

    push_d "${__cosmic_de_dir}"
    for pkg_dir in cosmic-* xdg-desktop-portal-cosmic; do
        if [[ -d "${pkg_dir}" ]]; then
            echo "${pkg_dir}"
        fi
    done | sort
    pop_d
}

# PHASE 1: Generate source archive (deterministic)
# Creates a reproducible source tarball from the git submodule
function phase_source_archive() {
    local pkg="$1"
    local submodule_path="$2"

    log_phase "[${pkg}] Phase 1: Source archive generation"

    local submodule_dir="${TEMP_DIR}/cosmic-epoch/${submodule_path}"

    if [[ ! -d "${submodule_dir}" ]]; then
        log_warning "[${pkg}] Submodule directory not found: ${submodule_dir}"
        return 1
    fi

    local archive_name="${pkg}-${GENTOO_VERSION}.tar.zst"
    local archive_path="${TEMP_DIR}/${archive_name}"

    # Remove existing archive if present
    if [[ -f "${archive_path}" ]]; then
        log_info "[${pkg}] Removing existing source archive"
        rm -f "${archive_path}"
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would create ${archive_name}"
        return 0
    fi

    push_d "${submodule_dir}"

    # Get the commit SHA for reproducibility (not tag, which can move)
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    log_verbose "[${pkg}] Creating archive from commit: ${commit_sha}"

    # Create deterministic archive:
    # - git archive produces sorted, reproducible output for same commit
    # - --prefix ensures consistent directory structure
    # - SOURCE_DATE_EPOCH (set globally) ensures reproducible timestamps in zstd
    # - zstd with fixed parameters for reproducible compression
    log_info "[${pkg}] Creating source archive..."
    if ! git archive \
        --format=tar \
        --prefix="${pkg}-${GENTOO_VERSION}/" \
        "${commit_sha}" \
    | zstd --long=31 --ultra -22 -T0 -o "${archive_path}"; then
        log_error "[${pkg}] Failed to create source archive"
        pop_d
        return 1
    fi

    pop_d

    local archive_size archive_blake2b archive_sha512
    archive_size=$(stat -c%s "${archive_path}")
    archive_blake2b=$(b2sum "${archive_path}" | awk '{print $1}')
    archive_sha512=$(sha512sum "${archive_path}" | awk '{print $1}')
    log_success "[${pkg}] Source archive: ${archive_name} (${archive_size} bytes)"
    log_verbose "[${pkg}] BLAKE2B: ${archive_blake2b}"
    log_verbose "[${pkg}] SHA512:  ${archive_sha512}"

    return 0
}

# PHASE 2: Generate vendored crates tarball
function phase_crates_tarball() {
    local pkg="$1"
    local submodule_path="$2"

    log_phase "[${pkg}] Phase 2: Crates tarball generation"

    if [[ ! -d "${TEMP_DIR}/cosmic-epoch/${submodule_path}" ]]; then
        log_warning "[${pkg}] Submodule directory not found, skipping"
        return 1
    fi

    push_d "${TEMP_DIR}/cosmic-epoch/${submodule_path}"

    if [[ ! -f "Cargo.toml" ]]; then
        log_info "[${pkg}] No Cargo.toml found, skipping tarball generation"
        pop_d
        return 0
    fi

    # Pull LFS files if needed
    if [[ -f ".gitattributes" ]] && grep -q "filter=lfs" .gitattributes; then
        log_info "[${pkg}] Pulling LFS files..."
        git lfs pull || log_warning "[${pkg}] LFS pull failed, continuing anyway"
    fi

    local tarball_name="${pkg}-${GENTOO_VERSION}-crates.tar"
    local tarball_zst="${tarball_name}.zst"
    local tarball_path="${TEMP_DIR}/${tarball_zst}"

    # Remove existing tarball if present (force regeneration)
    if [[ -f "${DISTDIR}/${tarball_zst}" ]]; then
        log_info "[${pkg}] Removing existing tarball in DISTDIR"
        rm -f "${DISTDIR}/${tarball_zst}"
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would create ${tarball_zst}"
        pop_d
        return 0
    fi

    # Create temporary CARGO_HOME for this package to avoid conflicts
    local temp_cargo_home
    temp_cargo_home=$(mktemp -d -t "cargo-home-${pkg}-XXXXXX")
    track_temp "${temp_cargo_home}"
    log_verbose "[${pkg}] Using temporary CARGO_HOME: ${temp_cargo_home}"

    # Save current CARGO_HOME (if set) and restore after vendor
    local saved_cargo_home="${CARGO_HOME:-}"
    export CARGO_HOME="${temp_cargo_home}"
    log_info "[${pkg}] Running cargo vendor with isolated CARGO_HOME..."
    local config_file="config.toml"
    local vendor_failed=0

    if ! cargo vendor 2>/dev/null > "${config_file}"; then
        log_error "[${pkg}] cargo vendor failed"
        vendor_failed=1
    fi

    # Validate cargo vendor output
    if [[ $vendor_failed -eq 0 ]]; then
        if [[ ! -f "${config_file}" ]] || [[ ! -s "${config_file}" ]]; then
            log_error "[${pkg}] cargo vendor output is missing or empty"
            vendor_failed=1
        elif [[ ! -d "vendor" ]] || [[ -z "$(ls -A vendor 2>/dev/null)" ]]; then
            log_error "[${pkg}] vendor directory is missing or empty"
            vendor_failed=1
        fi
    fi

    # Restore previous CARGO_HOME
    log_verbose "[${pkg}] Cleaning up temporary CARGO_HOME: ${temp_cargo_home}"
    rm -rf "${temp_cargo_home}"
    if [[ -n "${saved_cargo_home}" ]]; then
        export CARGO_HOME="${saved_cargo_home}"
    else
        unset CARGO_HOME
    fi

    # Check if vendor failed
    if [[ $vendor_failed -eq 1 ]]; then
        pop_d
        return 1
    fi

    log_info "[${pkg}] Creating tarball..."
    if ! tar -cf "${TEMP_DIR}/${tarball_name}" vendor "${config_file}"; then
        log_error "[${pkg}] tar creation failed"
        rm -rf vendor "${config_file}"
        pop_d
        return 1
    fi

    log_info "[${pkg}] Compressing with zstd..."
    if ! zstd --long=31 --ultra -22 -T0 "${TEMP_DIR}/${tarball_name}" -o "${tarball_path}"; then
        log_error "[${pkg}] zstd compression failed"
        rm -f "${TEMP_DIR}/${tarball_name}"
        rm -rf vendor "${config_file}"
        pop_d
        return 1
    fi

    rm -f "${TEMP_DIR}/${tarball_name}"
    rm -rf vendor "${config_file}"

    local tarball_size tarball_blake2b tarball_sha512
    tarball_size=$(stat -c%s "${tarball_path}")
    tarball_blake2b=$(b2sum "${tarball_path}" | awk '{print $1}')
    tarball_sha512=$(sha512sum "${tarball_path}" | awk '{print $1}')
    log_success "[${pkg}] Crates tarball: ${tarball_zst} (${tarball_size} bytes)"
    log_verbose "[${pkg}] BLAKE2B: ${tarball_blake2b}"
    log_verbose "[${pkg}] SHA512:  ${tarball_sha512}"
    pop_d
    return 0
}

# PHASE 3: Write Manifest entries for both archives
# We are the source of truth - these hashes are authoritative
function phase_manifest_write() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 3: Write Manifest entries"

    local source_zst="${pkg}-${GENTOO_VERSION}.tar.zst"
    local crates_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    local source_path="${TEMP_DIR}/${source_zst}"
    local crates_path="${TEMP_DIR}/${crates_zst}"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would copy archives to DISTDIR and write Manifest"
        return 0
    fi

    # Source archive is required
    if [[ ! -f "${source_path}" ]]; then
        log_error "[${pkg}] Source archive not found: ${source_path}"
        return 1
    fi

    # Verify package directory exists
    if [[ ! -d "${__cosmic_de_dir}/${pkg}" ]]; then
        log_error "[${pkg}] Package directory not found: ${__cosmic_de_dir}/${pkg}"
        return 1
    fi

    # Backup existing Manifest before any modifications
    backup_manifest "$pkg"

    push_d "${__cosmic_de_dir}/${pkg}"

    # Acquire Manifest lock to prevent race conditions with concurrent script instances
    # This ensures only one script modifies the Manifest at a time
    acquire_manifest_lock "$pkg" || log_warning "[${pkg}] Could not acquire Manifest lock - race conditions possible"

    # Ensure Manifest file exists
    touch "Manifest"

    # Process source archive
    log_info "[${pkg}] Processing source archive: ${source_zst}"

    # Copy to DISTDIR
    if ! cp "${source_path}" "${DISTDIR}/"; then
        log_error "[${pkg}] Failed to copy source archive to DISTDIR"
        release_manifest_lock "$pkg"
        pop_d
        return 1
    fi

    # Sanity check: verify DISTDIR copy matches source byte-for-byte
    if ! cmp -s "${source_path}" "${DISTDIR}/${source_zst}"; then
        log_error "[${pkg}] DISTDIR copy does not match source (byte-for-byte check failed)"
        rm -f "${DISTDIR}/${source_zst}"
        release_manifest_lock "$pkg"
        pop_d
        return 1
    fi

    # Calculate hashes from TEMP copy (source of truth)
    local src_size src_blake2b src_sha512
    src_size=$(stat -c%s "${source_path}") || { log_error "[${pkg}] Failed to get source archive size"; release_manifest_lock "$pkg"; pop_d; return 1; }
    [[ -n "$src_size" && "$src_size" =~ ^[0-9]+$ ]] || { log_error "[${pkg}] Invalid source archive size: $src_size"; release_manifest_lock "$pkg"; pop_d; return 1; }

    src_blake2b=$(b2sum "${source_path}" | awk '{print $1}') || { log_error "[${pkg}] Failed to calculate BLAKE2B hash"; release_manifest_lock "$pkg"; pop_d; return 1; }
    [[ -n "$src_blake2b" && ${#src_blake2b} -eq 128 ]] || { log_error "[${pkg}] Invalid BLAKE2B hash: $src_blake2b"; release_manifest_lock "$pkg"; pop_d; return 1; }

    src_sha512=$(sha512sum "${source_path}" | awk '{print $1}') || { log_error "[${pkg}] Failed to calculate SHA512 hash"; release_manifest_lock "$pkg"; pop_d; return 1; }
    [[ -n "$src_sha512" && ${#src_sha512} -eq 128 ]] || { log_error "[${pkg}] Invalid SHA512 hash: $src_sha512"; release_manifest_lock "$pkg"; pop_d; return 1; }

    # Remove old entry and write new one (using temp file for atomic operation)
    local manifest_temp=$(mktemp)
    track_temp "${manifest_temp}"
    grep -v "^DIST ${source_zst}" "Manifest" > "${manifest_temp}" || true
    echo "DIST ${source_zst} ${src_size} BLAKE2B ${src_blake2b} SHA512 ${src_sha512}" >> "${manifest_temp}"
    mv "${manifest_temp}" "Manifest"

    log_success "[${pkg}] Source archive entry written:"
    log_info "  File: ${source_zst}"
    log_info "  Size: ${src_size} bytes"
    log_info "  BLAKE2B: ${src_blake2b}"
    log_info "  SHA512:  ${src_sha512}"

    # Process crates archive if it exists (some packages may not have Cargo.toml)
    if [[ -f "${crates_path}" ]]; then
        log_info "[${pkg}] Processing crates archive: ${crates_zst}"

        # Copy to DISTDIR
        if ! cp "${crates_path}" "${DISTDIR}/"; then
            log_error "[${pkg}] Failed to copy crates archive to DISTDIR"
            release_manifest_lock "$pkg"
            pop_d
            return 1
        fi

        # Sanity check: verify DISTDIR copy matches source byte-for-byte
        if ! cmp -s "${crates_path}" "${DISTDIR}/${crates_zst}"; then
            log_error "[${pkg}] DISTDIR copy does not match source (byte-for-byte check failed)"
            rm -f "${DISTDIR}/${crates_zst}"
            release_manifest_lock "$pkg"
            pop_d
            return 1
        fi

        # Calculate hashes from TEMP copy (source of truth)
        local crates_size crates_blake2b crates_sha512
        crates_size=$(stat -c%s "${crates_path}") || { log_error "[${pkg}] Failed to get crates archive size"; release_manifest_lock "$pkg"; pop_d; return 1; }
        [[ -n "$crates_size" && "$crates_size" =~ ^[0-9]+$ ]] || { log_error "[${pkg}] Invalid crates archive size: $crates_size"; release_manifest_lock "$pkg"; pop_d; return 1; }

        crates_blake2b=$(b2sum "${crates_path}" | awk '{print $1}') || { log_error "[${pkg}] Failed to calculate crates BLAKE2B hash"; release_manifest_lock "$pkg"; pop_d; return 1; }
        [[ -n "$crates_blake2b" && ${#crates_blake2b} -eq 128 ]] || { log_error "[${pkg}] Invalid crates BLAKE2B hash: $crates_blake2b"; release_manifest_lock "$pkg"; pop_d; return 1; }

        crates_sha512=$(sha512sum "${crates_path}" | awk '{print $1}') || { log_error "[${pkg}] Failed to calculate crates SHA512 hash"; release_manifest_lock "$pkg"; pop_d; return 1; }
        [[ -n "$crates_sha512" && ${#crates_sha512} -eq 128 ]] || { log_error "[${pkg}] Invalid crates SHA512 hash: $crates_sha512"; release_manifest_lock "$pkg"; pop_d; return 1; }

        # Remove old entry and write new one (using temp file for atomic operation)
        local manifest_temp=$(mktemp)
        track_temp "${manifest_temp}"
        grep -v "^DIST ${crates_zst}" "Manifest" > "${manifest_temp}" || true
        echo "DIST ${crates_zst} ${crates_size} BLAKE2B ${crates_blake2b} SHA512 ${crates_sha512}" >> "${manifest_temp}"
        mv "${manifest_temp}" "Manifest"

        log_success "[${pkg}] Crates archive entry written:"
        log_info "  File: ${crates_zst}"
        log_info "  Size: ${crates_size} bytes"
        log_info "  BLAKE2B: ${crates_blake2b}"
        log_info "  SHA512:  ${crates_sha512}"
    else
        log_info "[${pkg}] No crates archive (non-Rust package)"
    fi

    # Release lock after all Manifest modifications are complete
    release_manifest_lock "$pkg"

    pop_d
    log_success "[${pkg}] Manifest entries written successfully"
    return 0
}

# Upload and verify a single file to GitHub with byte-for-byte verification
# Arguments: local_file filename
# Returns: 0 on success, 1 on failure
function upload_and_verify() {
    local local_file="$1"
    local filename="$2"

    log_info "Uploading ${filename}..."

    # Upload with retry
    # NOTE: Capture exit code from retry_with_backoff (tee would return 0)
    retry_with_backoff 3 gh release upload "${GENTOO_VERSION}" "${local_file}" \
        --repo "$COSMIC_OVERLAY_REPO" --clobber 2>&1 | tee -a "${LOG_FILE}"
    local upload_exit=${PIPESTATUS[0]}

    if [[ $upload_exit -ne 0 ]]; then
        log_error "Failed to upload ${filename}"
        return 1
    fi

    log_success "Uploaded ${filename}"

    # Wait for CDN propagation
    local sleep_duration=$((5 + RANDOM % 6))
    log_info "Waiting ${sleep_duration}s for CDN propagation..."
    sleep "$sleep_duration"

    # Download for verification
    local verify_temp
    verify_temp=$(mktemp -d)
    track_temp "$verify_temp"

    # NOTE: Capture exit code from retry_with_backoff (tee would return 0)
    retry_with_backoff 2 gh release download "${GENTOO_VERSION}" \
        --repo "$COSMIC_OVERLAY_REPO" --pattern "${filename}" --dir "${verify_temp}" 2>&1 | tee -a "${LOG_FILE}"
    local download_exit=${PIPESTATUS[0]}

    if [[ $download_exit -ne 0 ]]; then
        log_error "Failed to download ${filename} for verification"
        rm -rf "${verify_temp}"
        return 1
    fi

    # Byte-for-byte comparison (more reliable than hash comparison)
    if ! cmp -s "${local_file}" "${verify_temp}/${filename}"; then
        log_error "Byte-for-byte verification FAILED for ${filename}"
        log_error "The file on GitHub differs from the local copy"
        # Clean up corrupted file from DISTDIR to prevent reuse
        rm -f "${local_file}"
        log_info "Removed corrupted file from DISTDIR: ${filename}"
        rm -rf "${verify_temp}"
        return 1
    fi

    rm -rf "${verify_temp}"
    log_success "Verified ${filename} - byte-for-byte match"
    return 0
}

# PHASE 4: Upload both archives to GitHub
function phase_upload() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 4: Upload archives to GitHub"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would upload archives to GitHub"
        return 0
    fi

    if [[ $NO_UPLOAD -eq 1 ]]; then
        log_warning "[${pkg}] Skipping GitHub upload (--no-upload specified)"
        return 0
    fi

    local source_zst="${pkg}-${GENTOO_VERSION}.tar.zst"
    local crates_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    local source_path="${DISTDIR}/${source_zst}"
    local crates_path="${DISTDIR}/${crates_zst}"

    # Ensure release exists
    if ! ensure_github_release; then
        log_error "[${pkg}] Failed to ensure GitHub release exists"
        return 1
    fi

    # Upload source archive (required)
    if [[ ! -f "${source_path}" ]]; then
        log_error "[${pkg}] Source archive not found in DISTDIR: ${source_path}"
        return 1
    fi

    log_info "[${pkg}] Uploading source archive..."
    if ! upload_and_verify "${source_path}" "${source_zst}"; then
        log_error "[${pkg}] Source archive upload/verification failed"
        return 1
    fi

    # Upload crates archive if it exists
    if [[ -f "${crates_path}" ]]; then
        log_info "[${pkg}] Uploading crates archive..."
        if ! upload_and_verify "${crates_path}" "${crates_zst}"; then
            log_error "[${pkg}] Crates archive upload/verification failed"
            return 1
        fi
    else
        log_info "[${pkg}] No crates archive to upload (non-Rust package)"
    fi

    log_success "[${pkg}] All archives uploaded and verified successfully"
    return 0
}

# PHASE 5: Bump ebuild
function phase_bump() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 5: Ebuild bump"

    push_d "${__cosmic_de_dir}/${pkg}"

    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"

    # Check if already exists (always overwrite, no resume mode)
    if [[ -f "${ebuild_file}" ]]; then
        log_warning "[${pkg}] Ebuild exists, overwriting"
        rm -f "${ebuild_file}"
    fi

    # Find template
    local template_file=""
    local candidates=()
    for f in "${pkg}"-*.ebuild; do
        [[ "$f" == *-9999.ebuild ]] && continue
        [[ -e "$f" ]] && candidates+=("$f")
    done

    if [[ ${#candidates[@]} -gt 0 ]]; then
        template_file=$(printf '%s\n' "${candidates[@]}" | sort -V | tail -n1)
    else
        template_file="${pkg}-9999.ebuild"
    fi

    if [[ ! -f "${template_file}" ]]; then
        log_error "[${pkg}] Template file not found: ${template_file}"
        pop_d
        return 1
    fi

    log_info "[${pkg}] Using template: ${template_file}"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would create ${ebuild_file}"
        pop_d
        return 0
    fi

    # Copy and transform
    cp "${template_file}" "${ebuild_file}"

    log_info "[${pkg}] Applying transformations..."
    if ! sed -i \
        -e 's|KEYWORDS=.*|KEYWORDS="~amd64"|' \
        -e '/^inherit.*live.*/d' \
        -e '/PROPERTIES=/d' \
        -e '/EGIT_BRANCH=/c\EGIT_COMMIT="'"${ORIGINAL_TAG}"'"' \
        -e 's:^MY_PV=.*:MY_PV="'"${ORIGINAL_TAG}"'":' \
        "${ebuild_file}"; then
        log_error "[${pkg}] sed transformation failed on ebuild file"
        pop_d
        return 1
    fi

    # Remove COSMIC_GIT_UNPACK if present
    if grep -q "^COSMIC_GIT_UNPACK=" "${ebuild_file}"; then
        if ! sed -i '/^COSMIC_GIT_UNPACK=/d' "${ebuild_file}"; then
            log_error "[${pkg}] sed failed to remove COSMIC_GIT_UNPACK"
            pop_d
            return 1
        fi
    fi

    # Update VERGEN variables if present
    if grep -q "VERGEN_GIT" "${ebuild_file}"; then
        log_info "[${pkg}] Updating VERGEN variables..."

        # Get git information from the submodule
        local submodule_path="${pkg}"
        if [[ ! -d "${TEMP_DIR}/cosmic-epoch/${pkg}" ]]; then
            if [[ "$pkg" == "xdg-desktop-portal-cosmic" ]] && [[ -d "${TEMP_DIR}/cosmic-epoch/xdg-desktop-portal-cosmic" ]]; then
                submodule_path="xdg-desktop-portal-cosmic"
            fi
        fi

        if [[ -d "${TEMP_DIR}/cosmic-epoch/${submodule_path}" ]]; then
            push_d "${TEMP_DIR}/cosmic-epoch/${submodule_path}"

            local commit_date=$(git log -1 --format=%cd)
            local commit_sha=$(git rev-parse HEAD)

            pop_d

            log_verbose "[${pkg}] VERGEN_GIT_COMMIT_DATE='${commit_date}'"
            log_verbose "[${pkg}] VERGEN_GIT_SHA=${commit_sha}"

            # Update the variables in the ebuild
            if ! sed -i \
                -e "s|^\texport VERGEN_GIT_COMMIT_DATE=.*|\texport VERGEN_GIT_COMMIT_DATE='${commit_date}'|" \
                -e "s|^\texport VERGEN_GIT_SHA=.*|\texport VERGEN_GIT_SHA=${commit_sha}|" \
                "${ebuild_file}"; then
                log_error "[${pkg}] sed failed to update VERGEN variables"
                pop_d
                return 1
            fi
        else
            log_warning "[${pkg}] Submodule not found, cannot update VERGEN variables"
        fi
    fi

    # Verify SRC_URI exists (skip for meta-packages as they don't have source)
    if ! is_meta_package "$pkg" && ! grep -q "SRC_URI=" "${ebuild_file}"; then
        log_error "[${pkg}] No SRC_URI found in ebuild"
        rm -f "${ebuild_file}"
        pop_d
        return 1
    fi

    git add "${ebuild_file}" || log_warning "[${pkg}] Could not git add ebuild"

    log_success "[${pkg}] Ebuild created: ${ebuild_file}"
    pop_d
    return 0
}

# PHASE 6: Verify fetch works with our Manifest entries
# We do NOT run 'ebuild digest' - our Manifest entries are authoritative
function phase_verify_fetch() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 6: Verify fetch"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would verify ebuild fetch"
        return 0
    fi

    push_d "${__cosmic_de_dir}/${pkg}"

    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"

    if [[ ! -f "${ebuild_file}" ]]; then
        log_error "[${pkg}] Ebuild not found: ${ebuild_file}"
        pop_d
        return 1
    fi

    # Verify that portage can fetch with our Manifest entries
    # This confirms our hashes are correctly written
    # Note: Files are already in DISTDIR, so this mainly validates the Manifest format
    log_info "[${pkg}] Verifying Manifest entries are valid..."

    # NOTE: Use PIPESTATUS to capture ebuild exit code (tee always returns 0)
    ebuild "${ebuild_file}" fetch 2>&1 | tee -a "${LOG_FILE}"
    local fetch_exit=${PIPESTATUS[0]}

    if [[ $fetch_exit -ne 0 ]]; then
        log_error "[${pkg}] ebuild fetch failed - Manifest entries may be incorrect"
        pop_d
        return 1
    fi

    log_success "[${pkg}] Manifest entries verified via fetch"
    pop_d
    return 0
}

# PHASE 7: Check system dependencies
function phase_sysdeps() {
    local pkg="$1"
    local submodule_path="$2"

    log_phase "[${pkg}] Phase 7: System dependency check"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would analyze system dependencies"
        return 0
    fi

    if [[ ! -d "${TEMP_DIR}/cosmic-epoch/${submodule_path}" ]]; then
        log_warning "[${pkg}] Submodule not found, skipping sysdeps check"
        return 0
    fi

    push_d "${TEMP_DIR}/cosmic-epoch/${submodule_path}"

    if [[ ! -f "Cargo.toml" ]]; then
        pop_d
        return 0
    fi

    log_info "[${pkg}] Analyzing cargo dependencies..."
    local sys_crates=$(cargo tree 2>/dev/null | grep -oE '[A-Za-z0-9-]+-sys' | sort -u || echo "")

    if [[ -z "$sys_crates" ]]; then
        log_info "[${pkg}] No -sys crates found"
        pop_d
        return 0
    fi

    # Get ebuild dependencies
    local ebuild_file="${__cosmic_de_dir}/${pkg}/${pkg}-${GENTOO_VERSION}.ebuild"
    local ebuild_deps=""
    if [[ -f "$ebuild_file" ]]; then
        ebuild_deps=$(grep -E '^\s*(DEPEND|RDEPEND|BDEPEND)=' "$ebuild_file" || echo "")
    fi

    local missing=()
    while IFS= read -r crate; do
        [[ -z "$crate" ]] && continue
        local gentoo_pkg=$(map_sys_crate_to_package "$crate")
        if [[ -n "$gentoo_pkg" ]] && [[ "$gentoo_pkg" != UNKNOWN:* ]]; then
            # Check if any part of the package is in ebuild
            local found=0
            for pkg_part in $gentoo_pkg; do
                local pkg_name=$(echo "$pkg_part" | cut -d: -f1)
                if echo "$ebuild_deps" | grep -q "$pkg_name"; then
                    found=1
                    break
                fi
            done

            if [[ $found -eq 0 ]]; then
                missing+=("${crate}:${gentoo_pkg}")
            fi
        fi
    done <<< "$sys_crates"

    pop_d

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "[${pkg}] Missing dependencies detected: ${#missing[@]}"
        MISSING_DEPS["$pkg"]="${missing[*]}"
        for dep in "${missing[@]}"; do
            log_verbose "  - ${dep}"
        done
    else
        log_success "[${pkg}] All system dependencies accounted for"
    fi

    return 0
}

# PHASE 8: Test src_prepare
function phase_prepare() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 8: Test src_prepare"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would test src_prepare"
        return 0
    fi

    push_d "${__cosmic_de_dir}/${pkg}"

    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"

    if [[ ! -f "${ebuild_file}" ]]; then
        log_error "[${pkg}] Ebuild not found: ${ebuild_file}"
        pop_d
        return 1
    fi

    log_info "[${pkg}] Testing unpack and prepare phases..."

    # First attempt
    # NOTE: Pipe ebuild output to tee, then check PIPESTATUS[0] for ebuild exit code
    # (tee always returns 0, so we need PIPESTATUS to get actual command result)
    ebuild "${ebuild_file}" clean unpack prepare 2>&1 | tee -a "${LOG_FILE}"
    local ebuild_exit=${PIPESTATUS[0]}

    if [[ $ebuild_exit -eq 0 ]]; then
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        log_success "[${pkg}] src_prepare test passed"
        pop_d
        return 0
    fi

    # Check if it's a PATCHES error
    log_warning "[${pkg}] src_prepare failed, checking for PATCHES issue..."

    if ! grep -q "^PATCHES=" "${ebuild_file}"; then
        log_error "[${pkg}] src_prepare failed (not PATCHES related)"
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        pop_d
        return 1
    fi

    # Try commenting out PATCHES - more defensive approach
    log_info "[${pkg}] Commenting out PATCHES block..."
    cp "${ebuild_file}" "${ebuild_file}.backup"

    # Use awk to safely comment out PATCHES definition and its contents
    # Handles both single-line PATCHES="..." and multi-line PATCHES=(...) arrays
    local temp_file=$(mktemp)
    track_temp "${temp_file}"
    awk '
        /^PATCHES=/ {
            if (!patches_seen) {
                print "# PATCHES commented out during bump due to patch failure - needs manual review"
                print "# " $0
                patches_seen = 1
                in_patches = 1
            }
            next
        }
        in_patches == 1 {
            if (/^\)/) {
                print "# " $0
                in_patches = 0
            } else if (/^[[:space:]]*$/) {
                # Empty lines within patches stay empty
                print ""
            } else {
                print "# " $0
            }
            next
        }
        { print }
    ' "${ebuild_file}" > "${temp_file}"

    if [[ ! -s "${temp_file}" ]]; then
        log_error "[${pkg}] Failed to process PATCHES (output empty)"
        mv "${ebuild_file}.backup" "${ebuild_file}"
        rm -f "${temp_file}"
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        pop_d
        return 1
    fi

    mv "${temp_file}" "${ebuild_file}"

    # Retry
    log_info "[${pkg}] Retrying src_prepare with PATCHES commented..."
    if ebuild "${ebuild_file}" clean unpack prepare 2>&1 | tee -a "${LOG_FILE}"; then
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        log_warning "[${pkg}] src_prepare passed with PATCHES commented"
        PATCHES_COMMENTED+=("$pkg")

        pop_d
        return 0
    else
        # Still failing, restore
        log_error "[${pkg}] src_prepare still failing even with PATCHES commented"
        mv "${ebuild_file}.backup" "${ebuild_file}"
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        pop_d
        return 1
    fi
}

# PHASE 9: QA scan
function phase_qa() {
    local pkg="$1"

    log_phase "[${pkg}] Phase 9: QA scan"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would run QA scan"
        return 0
    fi

    log_info "[${pkg}] Running pkgcheck scan..."
    local qa_output=$(pkgcheck scan --color false "cosmic-base/${pkg}" 2>&1 || true)

    if [[ -n "$qa_output" ]]; then
        log_warning "[${pkg}] QA issues found:"
        echo "$qa_output" | tee -a "${LOG_FILE}"
        QA_ISSUES["$pkg"]="$qa_output"
    else
        log_success "[${pkg}] No QA issues found"
    fi

    return 0
}

# PHASE 10: Commit changes
function phase_commit() {
    local pkg="$1"
    local submodule_path="$2"

    log_phase "[${pkg}] Phase 10: Commit changes"

    if [[ $NO_COMMIT -eq 1 ]]; then
        log_info "[${pkg}] --no-commit set, skipping commit"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would commit changes"
        return 0
    fi

    push_d "${__cosmic_de_dir}/${pkg}"

    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"

    # Stage files - verify success before committing
    if ! git add "${ebuild_file}" Manifest 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "[${pkg}] Failed to stage ${ebuild_file} and Manifest"
        pop_d
        return 1
    fi

    # Verify files were actually staged
    local staged_files=$(git diff --cached --name-only 2>/dev/null)
    if [[ -z "${staged_files}" ]]; then
        log_error "[${pkg}] No files were staged (${ebuild_file} and Manifest may not exist)"
        pop_d
        return 1
    fi

    # Build commit message
    local msg="cosmic-base/${pkg}: add ${GENTOO_VERSION}"

    # Check if PATCHES were commented
    local patches_commented=0
    for p in "${PATCHES_COMMENTED[@]}"; do
        if [[ "$p" == "$pkg" ]]; then
            patches_commented=1
            break
        fi
    done

    if [[ $patches_commented -eq 1 ]] || [[ -n "${MISSING_DEPS[$pkg]:-}" ]]; then
        msg="${msg}"$'\n\n'

        if [[ $patches_commented -eq 1 ]]; then
            msg="${msg}PATCHES commented out due to patch application failure."$'\n'
            msg="${msg}Manual review and patch updates required."$'\n'
        fi

        if [[ -n "${MISSING_DEPS[$pkg]:-}" ]]; then
            msg="${msg}Missing system dependencies detected - see bump report."$'\n'
        fi
    fi

    # Commit
    if git commit -m "$msg" 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "[${pkg}] Changes committed"
        # Clean up backup files
        rm -f "${ebuild_file}.backup"
        cleanup_manifest_backup "$pkg"
    else
        log_warning "[${pkg}] Commit failed, but changes are staged"
    fi

    pop_d
    return 0
}

# Ensure GitHub release exists
function ensure_github_release() {
    if [[ $NO_UPLOAD -eq 1 ]] || [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi

    # Check if release exists, create if needed
    if ! gh release view "${GENTOO_VERSION}" --repo "$COSMIC_OVERLAY_REPO" &>/dev/null; then
        log_info "Creating GitHub release ${GENTOO_VERSION}..."
        if ! gh release create "${GENTOO_VERSION}" \
            --repo "$COSMIC_OVERLAY_REPO" \
            --title "${GENTOO_VERSION}" \
            --notes "Script-generated source and crates archives for COSMIC ${GENTOO_VERSION}"; then
            log_error "Failed to create GitHub release"
            return 1
        fi
    fi
    return 0
}

# Process a single package
function process_package() {
    local pkg="$1"
    local pkg_num="$2"
    local total_pkgs="$3"

    log ""
    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BOLD}[${pkg_num}/${total_pkgs}] Processing: ${pkg}${NC}"
    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Validate archive names (safety check)
    if ! validate_archive_names "$pkg"; then
        log_error "[${pkg}] Archive name validation failed"
        FAILED_PACKAGES+=("$pkg:validation")
        return 1
    fi

    # Check if this is a meta-package (no source code, just dependencies)
    if is_meta_package "$pkg"; then
        log_info "[${pkg}] Meta-package detected (no sources, simplified: bump → QA → commit)"

        # Meta-packages: Phase 5, 9, 10 (bump, QA, commit - skipping 1-4, 6-8)
        if ! phase_bump "$pkg"; then
            FAILED_PACKAGES+=("$pkg:bump")
            push_d "${__cosmic_de_dir}/${pkg}"
            rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
            pop_d
            return 1
        fi

        phase_qa "$pkg"

        phase_commit "$pkg"

        COMPLETED_PACKAGES+=("$pkg")
        log_success "[${pkg}] Meta-package processing completed!"
        return 0
    fi

    # Find submodule path (for regular packages with source code)
    local submodule_path="$pkg"
    if [[ ! -d "${TEMP_DIR}/cosmic-epoch/${pkg}" ]]; then
        # Try xdg-desktop-portal-cosmic
        if [[ "$pkg" == "xdg-desktop-portal-cosmic" ]] && [[ -d "${TEMP_DIR}/cosmic-epoch/xdg-desktop-portal-cosmic" ]]; then
            submodule_path="xdg-desktop-portal-cosmic"
        else
            log_warning "[${pkg}] Submodule not found in cosmic-epoch, skipping"
            return 0
        fi
    fi

    # Execute phases - 10-phase architecture (Manifest written BEFORE upload to fail fast on hash issues):
    # 1: Source archive  2: Crates tarball  3: Write Manifest (hashes from TEMP_DIR)
    # 4: Upload (verify byte-for-byte)  5: Bump  6: Verify fetch  7: Sysdeps  8: Prepare  9: QA  10: Commit

    # Phase 1: Source archive
    if ! phase_source_archive "$pkg" "$submodule_path"; then
        FAILED_PACKAGES+=("$pkg:source_archive")
        rollback_package "$pkg" "source_archive"
        return 1
    fi

    # Phase 2: Crates tarball
    if ! phase_crates_tarball "$pkg" "$submodule_path"; then
        FAILED_PACKAGES+=("$pkg:crates_tarball")
        rollback_package "$pkg" "crates_tarball"
        return 1
    fi

    # Phase 3: Write Manifest (we are the source of truth)
    if ! phase_manifest_write "$pkg"; then
        FAILED_PACKAGES+=("$pkg:manifest_write")
        rollback_package "$pkg" "manifest_write"
        return 1
    fi

    # Phase 4: Upload both archives to GitHub (before ebuild fetch!)
    if ! phase_upload "$pkg"; then
        FAILED_PACKAGES+=("$pkg:upload")
        rollback_package "$pkg" "upload"
        return 1
    fi

    # Phase 5: Bump ebuild
    if ! phase_bump "$pkg"; then
        FAILED_PACKAGES+=("$pkg:bump")
        rollback_package "$pkg" "bump" 1
        return 1
    fi

    # Phase 6: Verify fetch (validates our Manifest entries work)
    if ! phase_verify_fetch "$pkg"; then
        FAILED_PACKAGES+=("$pkg:verify_fetch")
        rollback_package "$pkg" "verify_fetch" 1
        return 1
    fi

    # Phase 7: System dependencies (non-fatal)
    phase_sysdeps "$pkg" "$submodule_path"

    # Phase 8: src_prepare test
    if ! phase_prepare "$pkg"; then
        FAILED_PACKAGES+=("$pkg:prepare")
        rollback_package "$pkg" "prepare" 1 1
        return 1
    fi

    # Phase 9: QA scan (non-fatal)
    phase_qa "$pkg"

    # Phase 10: Commit
    phase_commit "$pkg"

    COMPLETED_PACKAGES+=("$pkg")
    log_success "[${pkg}] Package processing completed!"
    return 0
}

# Legacy batch upload function (kept for compatibility, but uploads happen per-package now)
function upload_to_github() {
    if [[ $NO_UPLOAD -eq 1 ]]; then
        log_info "GitHub upload was handled per-package during processing"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "DRY-RUN: Per-package uploads would have occurred during processing"
        return 0
    fi

    log_info "All package tarballs were uploaded during individual package processing"
    return 0
}

# Generate final report
function generate_report() {
    log ""
    log "${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    log "${BOLD}║       COSMIC OVERLAY BUMP REPORT: ${GENTOO_VERSION}                        ║${NC}"
    log "${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "Upstream Tag:     ${ORIGINAL_TAG}"
    log "Gentoo Version:   ${GENTOO_VERSION}"
    log "Log File:         ${LOG_FILE}"
    log ""
    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BOLD}PACKAGE SUMMARY${NC}"
    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log ""
    local completed_count=${#COMPLETED_PACKAGES[@]}
    local failed_count=${#FAILED_PACKAGES[@]}
    log "Total Packages:   $(( completed_count + failed_count ))"
    log "  ${GREEN}✓${NC} Completed:    ${completed_count}"
    log "  ${RED}✗${NC} Failed:       ${failed_count}"
    log ""

    if [[ ${completed_count} -gt 0 ]]; then
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${GREEN}✓ COMPLETED PACKAGES${NC}"
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log ""
        for pkg in "${COMPLETED_PACKAGES[@]}"; do
            local marker=""
            local patches_count=${#PATCHES_COMMENTED[@]}
            if [[ ${patches_count} -gt 0 ]]; then
                for p in "${PATCHES_COMMENTED[@]}"; do
                    if [[ "$p" == "$pkg" ]]; then
                        marker=" ${YELLOW}⚠ PATCHES COMMENTED${NC}"
                        break
                    fi
                done
            fi
            log "  ${GREEN}✓${NC} ${pkg}${marker}"
        done
        log ""
    fi

    local failed_count_check=${#FAILED_PACKAGES[@]}
    if [[ ${failed_count_check} -gt 0 ]]; then
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${RED}✗ FAILED PACKAGES${NC}"
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log ""
        for pkg_phase in "${FAILED_PACKAGES[@]}"; do
            local pkg="${pkg_phase%:*}"
            local phase="${pkg_phase#*:}"
            log "  ${RED}✗${NC} ${pkg}"
            log "    Phase:  ${phase}"
            log "    Action: Review logs and fix manually"
            log ""
        done
    fi

    local patches_count_check=${#PATCHES_COMMENTED[@]}
    if [[ ${patches_count_check} -gt 0 ]]; then
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${YELLOW}⚠ PATCHES COMMENTED (Manual Review Required)${NC}"
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log ""
        for pkg in "${PATCHES_COMMENTED[@]}"; do
            log "  • ${pkg}"
            log "    Reason: Patch application failed during src_prepare"
            log "    File:   cosmic-base/${pkg}/${pkg}-${GENTOO_VERSION}.ebuild"
            log "    Action: Review patches in files/ directory, update or remove"
            log ""
        done
    fi

    local missing_deps_count=${#MISSING_DEPS[@]}
    if [[ ${missing_deps_count} -gt 0 ]]; then
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${YELLOW}⚠ MISSING SYSTEM DEPENDENCIES (Manual Review Required)${NC}"
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log ""
        for pkg in "${!MISSING_DEPS[@]}"; do
            log "  ${pkg}:"
            IFS=' ' read -ra deps <<< "${MISSING_DEPS[$pkg]}"
            for dep in "${deps[@]}"; do
                local crate="${dep%:*}"
                local gentoo="${dep#*:}"
                log "    Missing: ${gentoo}"
                log "    Crate:   ${crate}"
            done
            log "    Note:    Add to DEPEND or RDEPEND as appropriate"
            log ""
        done
    fi

    local qa_issues_count=${#QA_ISSUES[@]}
    if [[ ${qa_issues_count} -gt 0 ]]; then
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${YELLOW}⚠ QA ISSUES (Manual Review Required)${NC}"
        log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log ""
        for pkg in "${!QA_ISSUES[@]}"; do
            log "  ${pkg}:"
            echo "${QA_ISSUES[$pkg]}" | sed 's/^/    /' | tee -a "${LOG_FILE}"
            log ""
        done
    fi

    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BOLD}NEXT STEPS${NC}"
    log "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log ""

    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        log "1. Fix failed packages and re-run:"
        for pkg_phase in "${FAILED_PACKAGES[@]}"; do
            local pkg="${pkg_phase%:*}"
            log "   ./scripts/bump_and_qa_ebuild.sh ${ORIGINAL_TAG} -p ${pkg}"
        done
        log ""
    fi

    if [[ ${#PATCHES_COMMENTED[@]} -gt 0 ]]; then
        log "2. Review and update commented PATCHES"
        log ""
    fi

    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        log "3. Add missing system dependencies to affected ebuilds"
        log ""
    fi

    if [[ ${#QA_ISSUES[@]} -gt 0 ]]; then
        log "4. Address QA issues"
        log ""
    fi

    log "To clean temp:   ./scripts/bump_and_qa_ebuild.sh ${ORIGINAL_TAG} --clean-temp"
    log ""
    log "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
}

# Usage
function usage() {
    cat << EOF
Usage: $0 [OPTIONS] <cosmic-epoch-tag>

Process COSMIC packages: generate tarballs, bump ebuilds, and run QA checks.

ARGUMENTS:
  <cosmic-epoch-tag>    Tag from cosmic-epoch repo (e.g., epoch-1.0.0-beta.3)

OPTIONS:
  -r<N>, --revision <N>  Gentoo revision bump (e.g., -r1)
  -p, --package <pkg>    Process single package only
  --clean-temp           Remove temp directory on exit
  --no-upload            Skip GitHub release upload
  --no-commit            Don't commit changes
  -n, --dry-run          Show what would be done
  -v, --verbose          Enable verbose logging
  -h, --help             Show this help

ENVIRONMENT VARIABLES:
  COSMIC_EPOCH_REPO      URL to cosmic-epoch repository
                         (default: https://github.com/pop-os/cosmic-epoch)
  COSMIC_OVERLAY_REPO    GitHub repo for releasing tarballs
                         (default: fsvm88/cosmic-overlay)

EXAMPLES:
  # Process all packages for beta.3
  $0 epoch-1.0.0-beta.3

  # Process single package
  $0 epoch-1.0.0-beta.3 -p cosmic-edit

  # Dry-run to see what would happen
  $0 -n epoch-1.0.0-beta.3

  # Use alternative repository
  COSMIC_OVERLAY_REPO=myuser/cosmic-overlay $0 epoch-1.0.0-beta.3

EOF
}

# Main
function main() {
    # Parse arguments
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r*)
                REVISION_BUMP="$1"
                shift
                ;;
            --revision)
                REVISION_BUMP="-r${2}"
                shift 2
                ;;
            -p|--package)
                SINGLE_PACKAGE="$2"
                shift 2
                ;;
            --clean-temp)
                KEEP_TEMP=0
                shift
                ;;
            --no-upload)
                NO_UPLOAD=1
                shift
                ;;
            --no-commit)
                NO_COMMIT=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#args[@]} -lt 1 ]]; then
        error "Missing required argument: <cosmic-epoch-tag>"
        usage
        exit 1
    fi

    ORIGINAL_TAG="${args[0]}"
    
    # Validate inputs early to fail fast on bad inputs
    validate_original_tag "$ORIGINAL_TAG"
    validate_single_package "$SINGLE_PACKAGE"
    
    local base_version=$(convert_version "${ORIGINAL_TAG}")

    if [[ -n "$REVISION_BUMP" ]]; then
        GENTOO_VERSION="${base_version}${REVISION_BUMP}"
    else
        GENTOO_VERSION="${base_version}"
    fi

    log_info "COSMIC Overlay Bump & QA Script"
    log_info "Upstream tag: ${ORIGINAL_TAG}"
    log_info "Gentoo version: ${GENTOO_VERSION}"
    log ""

    # Initialize
    init_logging
    update_gitignore
    check_environment
    prepare_cosmic_epoch

    # Get package list
    local packages=()
    while IFS= read -r pkg; do
        packages+=("$pkg")
    done < <(get_package_list)

    local total=${#packages[@]}

    # Warn if no packages found
    if [[ $total -eq 0 ]]; then
        log_warning "No packages found to process!"
        if [[ -n "${SINGLE_PACKAGE}" ]]; then
            log_error "Single package specified (-p ${SINGLE_PACKAGE}) was not found in cosmic-base/"
            errorExit 1 "Package not found"
        else
            log_error "No packages found in cosmic-base/ directory"
            errorExit 1 "Empty package list"
        fi
    fi

    log_info "Processing ${total} package(s)"
    log ""

    # Process packages
    local pkg_num=0
    for pkg in "${packages[@]}"; do
        pkg_num=$((pkg_num + 1))
        process_package "$pkg" "$pkg_num" "$total" || true
    done

    # Upload to GitHub
    upload_to_github

    # Generate report
    generate_report

    log_success "All done!"

    if [[ $KEEP_TEMP -eq 1 ]]; then
        log_info "Temp directory kept at: ${TEMP_DIR}"
        log_info "To clean up: $0 ${ORIGINAL_TAG} --clean-temp"
    fi
}

main "$@"
