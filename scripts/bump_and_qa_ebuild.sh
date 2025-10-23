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
RESUME_MODE=1        # Default: enabled
KEEP_TEMP=1          # Default: enabled
NO_UPLOAD=0
NO_COMMIT=0
DRY_RUN=0
VERBOSE=0
STATE_FILE=""
LOG_FILE=""
TEMP_DIR=""
DISTDIR=""
TIMESTAMP=""

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
function cleanup() {
    if [[ $KEEP_TEMP -eq 0 ]]; then
        for x in "${CLEANUP_DIRS_FILES[@]}"; do
            log_verbose "Removing: ${x}"
            rm -rf "${x}"
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
    ver="${ver/-alpha/_alpha}"
    ver="${ver/-beta/_beta}"
    ver="${ver/-rc/_rc}"
    
    if [[ "$ver" =~ (_alpha)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    if [[ "$ver" =~ (_beta)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    if [[ "$ver" =~ (_rc)\.([0-9]+)\.([0-9]+) ]]; then
        ver="${ver/${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}_p${BASH_REMATCH[3]}}"
    fi
    
    ver="${ver/_alpha./_alpha}"
    ver="${ver/_beta./_beta}"
    ver="${ver/_rc./_rc}"
    echo "$ver"
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

# Initialize state file
function init_state_file() {
    STATE_FILE="${__script_dir}/.bump-state-${GENTOO_VERSION}.json"
    TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
    LOG_FILE="${__script_dir}/.bump-${GENTOO_VERSION}-${TIMESTAMP}.log"
    
    log_info "State file: ${STATE_FILE}"
    log_info "Log file: ${LOG_FILE}"
    
    if [[ -f "${STATE_FILE}" ]] && [[ $RESUME_MODE -eq 1 ]]; then
        log_info "Loading existing state from ${STATE_FILE}"
        # Load temp_dir if exists
        if command -v jq &>/dev/null; then
            TEMP_DIR=$(jq -r '.temp_dir // empty' "${STATE_FILE}" 2>/dev/null || echo "")
        fi
    else
        log_info "Creating new state file"
        cat > "${STATE_FILE}" <<EOF
{
  "version": "${GENTOO_VERSION}",
  "original_tag": "${ORIGINAL_TAG}",
  "temp_dir": "",
  "started": "$(date -Iseconds)",
  "last_updated": "$(date -Iseconds)",
  "packages": {}
}
EOF
    fi
}

# Update state file for a package
function update_package_state() {
    local pkg="$1"
    local status="$2"
    local phase="$3"
    local extra="${4:-}"
    
    if ! command -v jq &>/dev/null; then
        log_warning "jq not found, cannot update state file"
        return
    fi
    
    local phases_json="[]"
    if [[ -n "$phase" ]]; then
        # Read existing phases and append new one
        phases_json=$(jq ".packages.\"${pkg}\".phases // []" "${STATE_FILE}" 2>/dev/null || echo "[]")
        phases_json=$(echo "$phases_json" | jq ". + [\"${phase}\"] | unique")
    fi
    
    local timestamp="$(date -Iseconds)"
    local temp_state=$(mktemp)
    
    jq \
        --arg pkg "$pkg" \
        --arg status "$status" \
        --argjson phases "$phases_json" \
        --arg timestamp "$timestamp" \
        --arg extra "$extra" \
        '.last_updated = $timestamp |
         .packages[$pkg].status = $status |
         .packages[$pkg].phases = $phases |
         .packages[$pkg].last_updated = $timestamp |
         if $status == "completed" then .packages[$pkg].completed_at = $timestamp
         elif $status == "failed" then .packages[$pkg].failed_at = $timestamp | .packages[$pkg].error = $extra
         else . end' \
        "${STATE_FILE}" > "$temp_state"
    
    mv "$temp_state" "${STATE_FILE}"
}

# Check if package is already completed
function is_package_completed() {
    local pkg="$1"
    
    if [[ ! -f "${STATE_FILE}" ]] || ! command -v jq &>/dev/null; then
        echo "0"
        return
    fi
    
    local status=$(jq -r ".packages.\"${pkg}\".status // \"\"" "${STATE_FILE}" 2>/dev/null)
    if [[ "$status" == "completed" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

# Update gitignore
function update_gitignore() {
    local gitignore="${__script_dir}/.gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        log_info "Creating .gitignore"
        cat > "$gitignore" <<EOF
.bump-state-*.json
.bump-*.log
EOF
    else
        if ! grep -q ".bump-state-\*.json" "$gitignore"; then
            log_info "Adding state files to .gitignore"
            echo ".bump-state-*.json" >> "$gitignore"
        fi
        if ! grep -q ".bump-\*.log" "$gitignore"; then
            echo ".bump-*.log" >> "$gitignore"
        fi
    fi
}

# Check environment and tools
function check_environment() {
    log_phase "Checking environment..."
    
    local tools=("git" "git-lfs" "gh" "cargo" "ebuild" "pkgdev" "pkgcheck" "zstd" "b2sum" "sha512sum")
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
function prepare_cosmic_epoch() {
    log_phase "Preparing cosmic-epoch repository..."
    
    # Check if we can reuse existing clone
    if [[ -n "${TEMP_DIR}" ]] && [[ -d "${TEMP_DIR}/cosmic-epoch" ]]; then
        log_info "Reusing existing cosmic-epoch clone at ${TEMP_DIR}"
        push_d "${TEMP_DIR}/cosmic-epoch"
        
        # Verify it's the right tag
        local current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
        if [[ "$current_tag" == "${ORIGINAL_TAG}" ]]; then
            log_success "Already on correct tag: ${ORIGINAL_TAG}"
            git submodule update --recursive --force || errorExit 14 "could not update submodules"
            pop_d
            return
        else
            log_warning "Clone at wrong tag (${current_tag}), re-checking out"
            git switch -d "${ORIGINAL_TAG}" || errorExit 13 "could not switch to tag ${ORIGINAL_TAG}"
            git submodule update --recursive --force || errorExit 14 "could not update submodules"
            pop_d
            return
        fi
    fi
    
    # Create new clone
    TEMP_DIR=$(mktemp -d -t cosmic-bump.XXXXXX)
    log_info "Created temp directory: ${TEMP_DIR}"
    
    # Update state file with temp_dir
    if command -v jq &>/dev/null; then
        local temp_state=$(mktemp)
        jq --arg dir "$TEMP_DIR" '.temp_dir = $dir' "${STATE_FILE}" > "$temp_state"
        mv "$temp_state" "${STATE_FILE}"
    fi
    
    CLEANUP_DIRS_FILES+=("${TEMP_DIR}")
    
    push_d "${TEMP_DIR}"
    log_info "Cloning cosmic-epoch..."
    git clone --recurse-submodules https://github.com/pop-os/cosmic-epoch || \
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

# PHASE 1: Generate vendored tarball
function phase_tarball() {
    local pkg="$1"
    local submodule_path="$2"
    
    log_phase "[${pkg}] Phase 1: Tarball generation"
    
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
    log_verbose "[${pkg}] Using temporary CARGO_HOME: ${temp_cargo_home}"
    
    # Export CARGO_HOME for cargo vendor
    export CARGO_HOME="${temp_cargo_home}"
    
    log_info "[${pkg}] Running cargo vendor with isolated CARGO_HOME..."
    local config_file="config.toml"
    local vendor_failed=0
    
    if ! cargo vendor > "${config_file}"; then
        log_error "[${pkg}] cargo vendor failed"
        vendor_failed=1
    fi
    
    # Clean up temporary CARGO_HOME immediately after vendor
    log_verbose "[${pkg}] Cleaning up temporary CARGO_HOME: ${temp_cargo_home}"
    rm -rf "${temp_cargo_home}"
    unset CARGO_HOME
    
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
    if ! zstd --long=31 -15 -T0 "${TEMP_DIR}/${tarball_name}" -o "${tarball_path}"; then
        log_error "[${pkg}] zstd compression failed"
        rm -f "${TEMP_DIR}/${tarball_name}"
        rm -rf vendor "${config_file}"
        pop_d
        return 1
    fi
    
    rm -f "${TEMP_DIR}/${tarball_name}"
    rm -rf vendor "${config_file}"
    
    log_success "[${pkg}] Tarball created in TEMP_DIR: ${tarball_zst}"
    pop_d
    return 0
}

# PHASE 2: Update Manifest with tarball entry
function phase_manifest_update() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 2: Manifest update"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would copy tarball to DISTDIR and update Manifest"
        return 0
    fi
    
    local tarball_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    local temp_tarball_path="${TEMP_DIR}/${tarball_zst}"
    local distdir_tarball_path="${DISTDIR}/${tarball_zst}"
    
    # Skip if no tarball (packages without Cargo.toml)
    if [[ ! -f "${temp_tarball_path}" ]]; then
        log_info "[${pkg}] No tarball found in TEMP_DIR, skipping Manifest update (non-Rust package)"
        return 0
    fi
    
    # Calculate checksum before copying
    log_info "[${pkg}] Calculating checksum..."
    local original_sum=$(b2sum "${temp_tarball_path}" | awk '{print $1}')
    log_verbose "[${pkg}] Original checksum: ${original_sum}"
    
    # Copy tarball to DISTDIR
    log_info "[${pkg}] Copying to DISTDIR..."
    if ! cp "${temp_tarball_path}" "${DISTDIR}/"; then
        log_error "[${pkg}] Failed to copy to DISTDIR"
        return 1
    fi
    
    # Verify checksum after copying
    log_info "[${pkg}] Verifying copied tarball..."
    local copied_sum=$(b2sum "${distdir_tarball_path}" | awk '{print $1}')
    log_verbose "[${pkg}] Copied checksum:   ${copied_sum}"
    
    if [[ "${original_sum}" != "${copied_sum}" ]]; then
        log_error "[${pkg}] Checksum mismatch after copy!"
        log_error "  Original: ${original_sum}"
        log_error "  Copied:   ${copied_sum}"
        rm -f "${distdir_tarball_path}"
        return 1
    fi
    
    log_success "[${pkg}] Tarball copied and verified in DISTDIR"
    
    push_d "${__cosmic_de_dir}/${pkg}"
    
    # Backup existing Manifest
    if [[ -f "Manifest" ]]; then
        cp "Manifest" "Manifest.backup"
    fi
    
    # Calculate hashes from DISTDIR copy
    log_info "[${pkg}] Updating Manifest..."
    local size=$(stat -c%s "${distdir_tarball_path}")
    local blake2b=$(b2sum "${distdir_tarball_path}" | awk '{print $1}')
    local sha512=$(sha512sum "${distdir_tarball_path}" | awk '{print $1}')
    
    # Add entry to Manifest (or update if exists)
    if [[ -f "Manifest" ]]; then
        # Remove old entry if exists
        sed -i "/^DIST ${tarball_zst}/d" "Manifest"
    fi
    
    echo "DIST ${tarball_zst} ${size} BLAKE2B ${blake2b} SHA512 ${sha512}" >> "Manifest"
    
    log_success "[${pkg}] Manifest updated with tarball entry"
    log_info "[${pkg}] Manifest entry:"
    log_info "  File: ${tarball_zst}"
    log_info "  Size: ${size} bytes"
    log_info "  BLAKE2B: ${blake2b}"
    log_info "  SHA512:  ${sha512}"
    
    pop_d
    return 0
}

# PHASE 2.5: Upload tarball to GitHub immediately after Manifest update
function phase_upload_tarball() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 2.5: Upload tarball to GitHub"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would upload tarball to GitHub"
        return 0
    fi
    
    if [[ $NO_UPLOAD -eq 1 ]]; then
        log_warning "[${pkg}] Skipping GitHub upload (--no-upload specified)"
        return 0
    fi
    
    local tarball_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    local tarball_path="${DISTDIR}/${tarball_zst}"
    
    # Skip if no tarball (packages without Cargo.toml)
    if [[ ! -f "${tarball_path}" ]]; then
        log_info "[${pkg}] No tarball to upload (non-Rust package)"
        return 0
    fi
    
    log_info "[${pkg}] Uploading tarball to GitHub..."
    
    # Ensure release exists
    if ! ensure_github_release; then
        log_error "[${pkg}] Failed to ensure GitHub release exists"
        return 1
    fi
    
    # Get local hashes before upload
    log_info "[${pkg}] Calculating local hashes..."
    local local_blake2b
    local_blake2b=$(b2sum "${tarball_path}" | awk '{print $1}')
    local local_sha512
    local_sha512=$(sha512sum "${tarball_path}" | awk '{print $1}')
    local local_size
    local_size=$(stat -c%s "${tarball_path}")
    
    log_info "[${pkg}] Local tarball hashes:"
    log_info "  ${BOLD}File:${NC}     ${tarball_zst}"
    log_info "  ${BOLD}Size:${NC}     ${local_size} bytes"
    log_info "  ${BOLD}BLAKE2B:${NC}  ${local_blake2b}"
    log_info "  ${BOLD}SHA512:${NC}   ${local_sha512}"
    
    # Upload-verify loop: try up to 3 times to get a successful upload with matching hashes
    local max_upload_verify_attempts=3
    local upload_verify_attempt=1
    local verification_passed=0
    
    while [[ $upload_verify_attempt -le $max_upload_verify_attempts ]]; do
        if [[ $upload_verify_attempt -gt 1 ]]; then
            log_warning "[${pkg}] Upload-verify retry ${upload_verify_attempt}/${max_upload_verify_attempts}"
            log_info "[${pkg}] Re-uploading tarball to GitHub..."
        fi
        
        # Upload with retry logic (up to 3 attempts per upload-verify cycle)
        local max_upload_attempts=3
        local upload_attempt=1
        local upload_success=0
        
        while [[ $upload_attempt -le $max_upload_attempts ]]; do
            if [[ $upload_attempt -gt 1 ]]; then
                log_warning "[${pkg}] Upload attempt ${upload_attempt}/${max_upload_attempts}..."
                sleep 2  # Brief delay between upload retries
            else
                log_info "[${pkg}] Uploading to GitHub release ${GENTOO_VERSION}..."
            fi
            
            if gh release upload "${GENTOO_VERSION}" "${tarball_path}" \
                --repo "fsvm88/cosmic-overlay" \
                --clobber 2>&1 | tee -a "${LOG_FILE}"; then
                upload_success=1
                break
            else
                log_warning "[${pkg}] Upload attempt ${upload_attempt}/${max_upload_attempts} failed"
                ((upload_attempt++))
            fi
        done
        
        if [[ $upload_success -eq 0 ]]; then
            log_error "[${pkg}] Failed to upload tarball after ${max_upload_attempts} attempts"
            ((upload_verify_attempt++))
            continue
        fi
        
        log_success "[${pkg}] Tarball uploaded to GitHub"
        
        # Wait for GitHub to process the file (CDN propagation delay)
        local sleep_duration=$((5 + RANDOM % 6))  # Random between 5-10 seconds
        log_info "[${pkg}] Waiting ${sleep_duration}s for GitHub CDN propagation..."
        sleep ${sleep_duration}
        
        # Download and verify checksum
        log_info "[${pkg}] Downloading tarball from GitHub for verification..."
        local verify_temp
        verify_temp=$(mktemp -d)
        
        # Download with retry logic
        local max_download_attempts=3
        local download_attempt=1
        local download_success=0
        
        while [[ $download_attempt -le $max_download_attempts ]]; do
            if [[ $download_attempt -gt 1 ]]; then
                log_warning "[${pkg}] Download retry attempt ${download_attempt}/${max_download_attempts}..."
                sleep 2
            fi
            
            if gh release download "${GENTOO_VERSION}" \
                --repo "fsvm88/cosmic-overlay" \
                --pattern "${tarball_zst}" \
                --dir "${verify_temp}" 2>&1 | tee -a "${LOG_FILE}"; then
                download_success=1
                break
            else
                log_warning "[${pkg}] Download attempt ${download_attempt}/${max_download_attempts} failed"
                ((download_attempt++))
            fi
        done
        
        if [[ $download_success -eq 0 ]]; then
            log_error "[${pkg}] Failed to download tarball for verification after ${max_download_attempts} attempts"
            rm -rf "${verify_temp}"
            ((upload_verify_attempt++))
            continue
        fi
        
        # Calculate hashes of downloaded tarball
        log_info "[${pkg}] Calculating downloaded tarball hashes..."
        local downloaded_blake2b
        downloaded_blake2b=$(b2sum "${verify_temp}/${tarball_zst}" | awk '{print $1}')
        local downloaded_sha512
        downloaded_sha512=$(sha512sum "${verify_temp}/${tarball_zst}" | awk '{print $1}')
        local downloaded_size
        downloaded_size=$(stat -c%s "${verify_temp}/${tarball_zst}")
        
        log_info "[${pkg}] Downloaded tarball hashes:"
        log_info "  ${BOLD}File:${NC}     ${tarball_zst}"
        log_info "  ${BOLD}Size:${NC}     ${downloaded_size} bytes"
        log_info "  ${BOLD}BLAKE2B:${NC}  ${downloaded_blake2b}"
        log_info "  ${BOLD}SHA512:${NC}   ${downloaded_sha512}"
        
        # Compare all hashes
        local hash_mismatch=0
        
        if [[ "$local_blake2b" != "$downloaded_blake2b" ]]; then
            log_warning "[${pkg}] ${BOLD}BLAKE2B mismatch!${NC}"
            log_warning "  ${BOLD}Local:${NC}      ${local_blake2b}"
            log_warning "  ${BOLD}GitHub:${NC}     ${downloaded_blake2b}"
            hash_mismatch=1
        fi
        
        if [[ "$local_sha512" != "$downloaded_sha512" ]]; then
            log_warning "[${pkg}] ${BOLD}SHA512 mismatch!${NC}"
            log_warning "  ${BOLD}Local:${NC}      ${local_sha512}"
            log_warning "  ${BOLD}GitHub:${NC}     ${downloaded_sha512}"
            hash_mismatch=1
        fi
        
        if [[ "$local_size" != "$downloaded_size" ]]; then
            log_warning "[${pkg}] ${BOLD}Size mismatch!${NC}"
            log_warning "  ${BOLD}Local:${NC}      ${local_size} bytes"
            log_warning "  ${BOLD}GitHub:${NC}     ${downloaded_size} bytes"
            hash_mismatch=1
        fi
        
        rm -rf "${verify_temp}"
        
        if [[ $hash_mismatch -eq 1 ]]; then
            log_warning "[${pkg}] Hash verification failed on attempt ${upload_verify_attempt}/${max_upload_verify_attempts}"
            log_warning "[${pkg}] GitHub may have modified or cached an old version of the tarball"
            ((upload_verify_attempt++))
            continue
        fi
        
        # Success! Hashes match
        verification_passed=1
        break
    done
    
    # Final check after all attempts
    if [[ $verification_passed -eq 0 ]]; then
        log_error "[${pkg}] ${BOLD}Hash verification FAILED after ${max_upload_verify_attempts} upload-verify attempts!${NC}"
        log_error "[${pkg}] The tarball on GitHub differs from the local copy!"
        log_error "[${pkg}] This will cause ebuild fetch to fail with hash mismatches."
        return 1
    fi
    
    log_success "[${pkg}] ${BOLD}Hash verification PASSED!${NC}"
    log_success "[${pkg}] All hashes match between local, DISTDIR, and GitHub"
    return 0
}

# PHASE 3: Bump ebuild
function phase_bump() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 3: Ebuild bump"
    
    push_d "${__cosmic_de_dir}/${pkg}"
    
    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"
    
    # Check if already exists
    if [[ -f "${ebuild_file}" ]]; then
        if [[ $RESUME_MODE -eq 1 ]]; then
            log_info "[${pkg}] Ebuild already exists, skipping bump"
            pop_d
            return 0
        else
            log_warning "[${pkg}] Ebuild exists, overwriting"
            rm -f "${ebuild_file}"
        fi
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
    sed -i \
        -e 's:KEYWORDS=.*:KEYWORDS="~amd64":' \
        -e '/^inherit.*live.*/d' \
        -e '/PROPERTIES=/d' \
        -e '/EGIT_BRANCH=/c\EGIT_COMMIT="'"${ORIGINAL_TAG}"'"' \
        -e 's:^MY_PV=.*:MY_PV="'"${ORIGINAL_TAG}"'":' \
        "${ebuild_file}"
    
    # Remove COSMIC_GIT_UNPACK if present
    if grep -q "^COSMIC_GIT_UNPACK=" "${ebuild_file}"; then
        sed -i '/^COSMIC_GIT_UNPACK=/d' "${ebuild_file}"
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
            sed -i \
                -e "s|^\texport VERGEN_GIT_COMMIT_DATE=.*|\texport VERGEN_GIT_COMMIT_DATE='${commit_date}'|" \
                -e "s|^\texport VERGEN_GIT_SHA=.*|\texport VERGEN_GIT_SHA=${commit_sha}|" \
                "${ebuild_file}"
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

# PHASE 4: Fetch upstream source
function phase_fetch() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 4: Fetch upstream source"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[${pkg}] DRY-RUN: Would run ebuild manifest"
        return 0
    fi
    
    push_d "${__cosmic_de_dir}/${pkg}"
    
    local ebuild_file="${pkg}-${GENTOO_VERSION}.ebuild"
    
    if [[ ! -f "${ebuild_file}" ]]; then
        log_error "[${pkg}] Ebuild not found: ${ebuild_file}"
        pop_d
        return 1
    fi
    
    # Backup Manifest before ebuild manifest command
    if [[ -f "Manifest" ]]; then
        cp "Manifest" "Manifest.backup2"
    fi
    
    log_info "[${pkg}] Running ebuild manifest..."
    if ! ebuild "${ebuild_file}" manifest 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "[${pkg}] ebuild manifest failed"
        # Restore Manifest
        if [[ -f "Manifest.backup2" ]]; then
            mv "Manifest.backup2" "Manifest"
        fi
        pop_d
        return 1
    fi
    
    rm -f "Manifest.backup2"
    log_success "[${pkg}] Upstream source fetched and Manifest updated"
    pop_d
    return 0
}

# PHASE 5: Check system dependencies
function phase_sysdeps() {
    local pkg="$1"
    local submodule_path="$2"
    
    log_phase "[${pkg}] Phase 5: System dependency check"
    
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

# PHASE 6: Test src_prepare
function phase_prepare() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 6: Test src_prepare"
    
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
    if ebuild "${ebuild_file}" clean unpack prepare 2>&1 | tee -a "${LOG_FILE}"; then
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
    
    # Try commenting out PATCHES
    log_info "[${pkg}] Commenting out PATCHES block..."
    cp "${ebuild_file}" "${ebuild_file}.backup"
    
    # Add comment before PATCHES and comment out the array
    sed -i '/^PATCHES=/i\# PATCHES commented out during bump due to patch failure - needs manual review' "${ebuild_file}"
    sed -i 's/^PATCHES=/# PATCHES=/' "${ebuild_file}"
    
    # Comment out the array contents
    local in_patches=0
    local temp_file=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ PATCHES= ]]; then
            in_patches=1
            echo "$line" >> "$temp_file"
        elif [[ $in_patches -eq 1 ]]; then
            if [[ "$line" =~ ^\) ]]; then
                echo "# $line" >> "$temp_file"
                in_patches=0
            else
                echo "# $line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "${ebuild_file}"
    mv "$temp_file" "${ebuild_file}"
    
    # Retry
    log_info "[${pkg}] Retrying src_prepare with PATCHES commented..."
    if ebuild "${ebuild_file}" clean unpack prepare 2>&1 | tee -a "${LOG_FILE}"; then
        ebuild "${ebuild_file}" clean >/dev/null 2>&1
        log_warning "[${pkg}] src_prepare passed with PATCHES commented"
        PATCHES_COMMENTED+=("$pkg")
        
        # Update state
        if command -v jq &>/dev/null; then
            local temp_state=$(mktemp)
            jq ".packages.\"${pkg}\".patches_commented = true" "${STATE_FILE}" > "$temp_state"
            mv "$temp_state" "${STATE_FILE}"
        fi
        
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

# PHASE 7: QA scan
function phase_qa() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 7: QA scan"
    
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

# PHASE 8: Commit changes
function phase_commit() {
    local pkg="$1"
    
    log_phase "[${pkg}] Phase 8: Commit changes"
    
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
    
    # Stage files
    git add "${ebuild_file}" Manifest 2>/dev/null || true
    
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
        rm -f "${ebuild_file}.backup" Manifest.backup Manifest.backup2
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
    if ! gh release view "${GENTOO_VERSION}" --repo "fsvm88/cosmic-overlay" &>/dev/null; then
        log_info "Creating GitHub release ${GENTOO_VERSION}..."
        if ! gh release create "${GENTOO_VERSION}" \
            --repo "fsvm88/cosmic-overlay" \
            --title "${GENTOO_VERSION}" \
            --notes "Script-generated vendored crates for COSMIC ${GENTOO_VERSION}"; then
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
    
    # Check if already completed (in resume mode)
    if [[ $RESUME_MODE -eq 1 ]]; then
        local completed=$(is_package_completed "$pkg")
        if [[ "$completed" == "1" ]]; then
            log_info "[${pkg}] Re-validating previously completed package..."
            # Re-run QA check
            phase_qa "$pkg"
            log_success "[${pkg}] Validation passed, skipping"
            COMPLETED_PACKAGES+=("$pkg")
            return 0
        fi
    fi
    
    # Check if this is a meta-package (no source code, just dependencies)
    if is_meta_package "$pkg"; then
        log_info "[${pkg}] Meta-package detected - simplified processing"
        
        # Meta-packages only need bump and commit
        # Phase 1: Bump ebuild
        if ! phase_bump "$pkg"; then
            update_package_state "$pkg" "failed" "bump" "Ebuild bump failed"
            FAILED_PACKAGES+=("$pkg:bump")
            push_d "${__cosmic_de_dir}/${pkg}"
            rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
            pop_d
            return 1
        fi
        update_package_state "$pkg" "in-progress" "bump"
        
        # Phase 2: QA scan (non-fatal)
        phase_qa "$pkg"
        update_package_state "$pkg" "in-progress" "qa"
        
        # Phase 3: Commit
        phase_commit "$pkg"
        update_package_state "$pkg" "completed" "commit"
        
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
    
    # Execute phases
    local tarball_zst="${pkg}-${GENTOO_VERSION}-crates.tar.zst"
    
    # Phase 1: Tarball
    if ! phase_tarball "$pkg" "$submodule_path"; then
        update_package_state "$pkg" "failed" "tarball" "Tarball generation failed"
        FAILED_PACKAGES+=("$pkg:tarball")
        # Cleanup: remove tarball from DISTDIR and temp
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "tarball"
    
    # Phase 2: Manifest update
    if ! phase_manifest_update "$pkg"; then
        update_package_state "$pkg" "failed" "manifest" "Manifest update failed"
        FAILED_PACKAGES+=("$pkg:manifest")
        # Cleanup: restore Manifest, remove tarball
        push_d "${__cosmic_de_dir}/${pkg}"
        [[ -f "Manifest.backup" ]] && mv "Manifest.backup" "Manifest"
        pop_d
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "manifest"
    
    # Phase 2.5: Upload tarball to GitHub (IMMEDIATE - before ebuild fetch!)
    if ! phase_upload_tarball "$pkg"; then
        update_package_state "$pkg" "failed" "upload" "GitHub upload/verification failed"
        FAILED_PACKAGES+=("$pkg:upload")
        # Cleanup: restore Manifest, remove tarball
        push_d "${__cosmic_de_dir}/${pkg}"
        [[ -f "Manifest.backup" ]] && mv "Manifest.backup" "Manifest"
        pop_d
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "upload"
    
    # Phase 3: Bump
    if ! phase_bump "$pkg"; then
        update_package_state "$pkg" "failed" "bump" "Ebuild bump failed"
        FAILED_PACKAGES+=("$pkg:bump")
        # Cleanup: remove ebuild, restore Manifest, remove tarball
        push_d "${__cosmic_de_dir}/${pkg}"
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
        [[ -f "Manifest.backup" ]] && mv "Manifest.backup" "Manifest"
        pop_d
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "bump"
    
    # Phase 4: Fetch
    if ! phase_fetch "$pkg"; then
        update_package_state "$pkg" "failed" "fetch" "Upstream source fetch failed"
        FAILED_PACKAGES+=("$pkg:fetch")
        # Cleanup: remove ebuild, restore Manifest, remove tarball
        push_d "${__cosmic_de_dir}/${pkg}"
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
        [[ -f "Manifest.backup" ]] && mv "Manifest.backup" "Manifest"
        [[ -f "Manifest.backup2" ]] && rm -f "Manifest.backup2"
        git checkout -- "${pkg}-${GENTOO_VERSION}.ebuild" 2>/dev/null || true
        pop_d
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "fetch"
    
    # Phase 5: System dependencies (non-fatal)
    phase_sysdeps "$pkg" "$submodule_path"
    update_package_state "$pkg" "in-progress" "sysdeps"
    
    # Phase 6: src_prepare test
    if ! phase_prepare "$pkg"; then
        update_package_state "$pkg" "failed" "prepare" "src_prepare test failed"
        FAILED_PACKAGES+=("$pkg:prepare")
        # Cleanup: clean workdir, remove ebuild, restore Manifest, remove tarball
        push_d "${__cosmic_de_dir}/${pkg}"
        ebuild "${pkg}-${GENTOO_VERSION}.ebuild" clean >/dev/null 2>&1 || true
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild"
        rm -f "${pkg}-${GENTOO_VERSION}.ebuild.backup"
        [[ -f "Manifest.backup" ]] && mv "Manifest.backup" "Manifest"
        [[ -f "Manifest.backup2" ]] && rm -f "Manifest.backup2"
        git checkout -- "${pkg}-${GENTOO_VERSION}.ebuild" 2>/dev/null || true
        pop_d
        rm -f "${DISTDIR}/${tarball_zst}"
        rm -f "${TEMP_DIR}/${tarball_zst}"
        return 1
    fi
    update_package_state "$pkg" "in-progress" "prepare"
    
    # Phase 7: QA (non-fatal)
    phase_qa "$pkg"
    update_package_state "$pkg" "in-progress" "qa"
    
    # Phase 8: Commit
    phase_commit "$pkg"
    update_package_state "$pkg" "completed" "commit"
    
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
    log "State File:       ${STATE_FILE}"
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
    
    log "To resume/retry: ./scripts/bump_and_qa_ebuild.sh ${ORIGINAL_TAG}"
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
  --no-resume            Force re-process all (ignore state file)
  --clean-temp           Remove temp directory on exit
  --no-upload            Skip GitHub release upload
  --no-commit            Don't commit changes
  -n, --dry-run          Show what would be done
  -v, --verbose          Enable verbose logging
  -h, --help             Show this help

EXAMPLES:
  # Process all packages for beta.3
  $0 epoch-1.0.0-beta.3

  # Process single package
  $0 epoch-1.0.0-beta.3 -p cosmic-edit

  # Dry-run to see what would happen
  $0 -n epoch-1.0.0-beta.3

  # Resume after fixing failures
  $0 epoch-1.0.0-beta.3

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
                REVISION_BUMP="${1}"
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
            --no-resume)
                RESUME_MODE=0
                shift
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
    init_state_file
    update_gitignore
    check_environment
    prepare_cosmic_epoch
    
    # Get package list
    local packages=()
    while IFS= read -r pkg; do
        packages+=("$pkg")
    done < <(get_package_list)
    
    local total=${#packages[@]}
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
