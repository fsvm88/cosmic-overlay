#!/usr/bin/env bash

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"
# Compose the cosmic-de ebuild folder
__cosmic_de_dir="${__script_dir}/cosmic-de"

function log() { echo >&2 "$*"; }
function error() { log "ERROR: $*"; }
function errorExit() { local -r rc="$1"; shift 1; error "$*"; exit "$rc"; }
function push_d() { pushd "$*" &> /dev/null || errorExit 5 "could not pushd to $*"; }
function pop_d() { popd &> /dev/null || errorExit 6 "could not popd from $PWD"; }
CLEANUP_DIRS_FILES=()
# shellcheck disable=SC2317
function cleanup() {
    for x in "${CLEANUP_DIRS_FILES[@]}"; do
        # error "would remove: ${x}"
        rm -rf "${x}"
    done
}
trap cleanup EXIT SIGINT SIGTERM

! which git &> /dev/null &&
    errorExit 2 "git was not found in $PATH, you need git installed to run this script"

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

# Clone the main repo to a temporary folder
__temp_folder=
__temp_folder="$(mktemp -d)"
# shellcheck disable=SC2181
[ $? -ne 0 ] && errorExit 10 "could not create temporary folder for cloning"
CLEANUP_DIRS_FILES+=("${__temp_folder}")
push_d "${__temp_folder}"
git clone https://github.com/pop-os/cosmic-epoch || errorExit 12 "could not clone git repo"
push_d "cosmic-epoch"
# Generate list of modules for later querying
__temp_submodule_hashes="${__temp_folder}/git.hashes"
git ls-tree HEAD --format='%(objecttype) %(objectname) %(path)' | grep ^commit > "${__temp_submodule_hashes}"
pop_d
pop_d

# We bump cosmic-* packages and xdg-desktop-portal-cosmic,
# which are the ones added as sub-modules to the main repo
# https://github.com/pop-os/cosmic-epoch
# ofc not cosmic-meta
push_d "${__cosmic_de_dir}"
awk '{ print $3; }' "${__temp_submodule_hashes}" | while read -r one_pkg; do
    push_d "$one_pkg"
    ebuild_file="${one_pkg}-9999.ebuild"
    [ ! -f "${ebuild_file}" ] &&
        errorExit 3 "could not find expected ebuild file: ${ebuild_file}"
    # This will errorExit if anything goes wrong
    git_commit_hash="$(get_commit_hash "${__temp_submodule_hashes}" "${one_pkg}")"
    if ! grep -q "EGIT_COMMIT=${git_commit_hash}" "${ebuild_file}"; then
        log "UPDATING ${ebuild_file} to EGIT_COMMIT=${git_commit_hash}"
        sed -i \
            -e "s:EGIT_COMMIT=.*:EGIT_COMMIT=${git_commit_hash}:" \
            "${one_pkg}-9999.ebuild" || \
            errorExit 120 "${ebuild_file}: could not update with the latest hash"
        ebuild "${ebuild_file}" digest || \
            errorExit 121 "${ebuild_file}: could not refresh digest"
        git add . || \
            errorExit 122 "${ebuild_file}: could not git-add changes"
        git commit -m "${ebuild_file}: autobump to ${git_commit_hash}" -- "$PWD" || \
            errorExit 123 "${ebuild_file}: could not git-commit changes"
    else
        log "NOT updating ${ebuild_file}, ${git_commit_hash} already present"
    fi
    pop_d
    unset ebuild_file, git_commit_hash
done

log "ALL DONE! do not forget to test and push!"
exit 0