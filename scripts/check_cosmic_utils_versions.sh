#!/usr/bin/env bash

# Script to check for new versions of cosmic-utils packages
# Checks GitHub releases, git tags, and Cargo.toml versions
# Compares against current versions in the cosmic-utils category

set -eo pipefail

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"
__cosmic_utils_dir="${__script_dir}/cosmic-utils"

# GitHub API configuration
GITHUB_API_BASE="https://api.github.com"
GITHUB_ORG="cosmic-utils"

# Try to get GitHub token from GitHub CLI if not already set
if [ -z "${GITHUB_TOKEN:-}" ]; then
    # Check for gh CLI token in default location
    GH_CONFIG="${HOME}/.config/gh/hosts.yml"
    if [ -f "$GH_CONFIG" ]; then
        # Extract oauth_token from hosts.yml (first occurrence)
        GITHUB_TOKEN=$(command grep 'oauth_token:' "$GH_CONFIG" 2>/dev/null | head -1 | awk '{print $2}')
    fi
fi

# Global temp file for results (cleaned up on exit)
TEMP_RESULTS=""

# Cleanup function
cleanup() {
    if [ -n "$TEMP_RESULTS" ] && [ -f "$TEMP_RESULTS" ]; then
        rm -f "$TEMP_RESULTS"
    fi
}
trap cleanup EXIT

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
function log() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
function warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
function error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
function success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }

# Check if required tools are available
for tool in curl jq git; do
    if ! command -v "$tool" &>/dev/null; then
        error "$tool is required but not installed. Please install it."
        exit 1
    fi
done

# Function to make GitHub API calls with rate limit handling
function github_api_call() {
    local endpoint="$1"
    local url="${GITHUB_API_BASE}${endpoint}"
    
    # Make the API call
    local http_code
    local body
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        body=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" -w "\n%{http_code}" "$url")
    else
        body=$(curl -s -w "\n%{http_code}" "$url")
    fi
    
    http_code=$(echo "$body" | tail -n1 | tr -d '[:space:]')
    body=$(echo "$body" | sed '$d')
    
    # Check if http_code is numeric
    if ! [[ "$http_code" =~ ^[0-9]+$ ]]; then
        warn "Invalid HTTP response code: $http_code"
        return 1
    fi
    
    if [ "$http_code" -eq 403 ]; then
        error "GitHub API rate limit exceeded. Set GITHUB_TOKEN environment variable for higher limits."
        return 1
    elif [ "$http_code" -ne 200 ]; then
        warn "GitHub API returned status $http_code for $url"
        return 1
    fi
    
    echo "$body"
}

# Function to get list of repositories from cosmic-utils organization
function get_cosmic_utils_repos() {
    log "Fetching repositories from ${GITHUB_ORG} organization..."
    
    local page=1
    local all_repos="[]"
    
    while true; do
        local repos
        repos=$(github_api_call "/orgs/${GITHUB_ORG}/repos?type=public&per_page=100&page=${page}" || echo "[]")
        
        if [ -z "$repos" ] || [ "$repos" = "[]" ]; then
            break
        fi
        
        all_repos=$(echo "$all_repos $repos" | jq -s 'add')
        
        # Check if we got less than 100 repos (last page)
        if [ "$(echo "$repos" | jq 'length')" -lt 100 ]; then
            break
        fi
        
        ((page++))
    done
    
    # Filter out archived repos, forks, and templates, then sort alphabetically
    echo "$all_repos" | jq -r '.[] | select(.archived == false and .fork == false and .is_template == false) | .name' | sort
}

# Function to get the latest GitHub release version
function get_github_release_version() {
    local repo="$1"
    local release_data
    
    release_data=$(github_api_call "/repos/${GITHUB_ORG}/${repo}/releases/latest" 2>/dev/null) || return 1
    
    if [ -z "$release_data" ]; then
        return 1
    fi
    
    echo "$release_data" | jq -r '.tag_name // empty' || true
}

# Function to get the latest git tag
function get_latest_git_tag() {
    local repo="$1"
    local tags_data
    
    tags_data=$(github_api_call "/repos/${GITHUB_ORG}/${repo}/tags?per_page=1" 2>/dev/null) || return 1
    
    if [ -z "$tags_data" ] || [ "$tags_data" = "[]" ]; then
        return 1
    fi
    
    echo "$tags_data" | jq -r '.[0].name // empty' || true
}

# Function to get version from Cargo.toml
function get_cargo_toml_version() {
    local repo="$1"
    local cargo_toml
    
    # Try to fetch Cargo.toml from the main branch
    cargo_toml=$(github_api_call "/repos/${GITHUB_ORG}/${repo}/contents/Cargo.toml" 2>/dev/null) || return 1
    
    if [ -z "$cargo_toml" ]; then
        return 1
    fi
    
    # Decode base64 content and extract version
    local content
    content=$(echo "$cargo_toml" | jq -r '.content // empty' | base64 -d 2>/dev/null) || return 1
    
    if [ -z "$content" ]; then
        return 1
    fi
    
    # Extract version from Cargo.toml (handle both single and double quotes)
    echo "$content" | grep -m1 '^version' | sed -E 's/^version\s*=\s*['"'"'"]([^'"'"'"]+)['"'"'"].*/\1/' || true
}

# Function to normalize version strings (remove v prefix, etc.)
function normalize_version() {
    local version="$1"
    # Remove common prefixes
    version="${version#v}"
    version="${version#V}"
    version="${version#version-}"
    version="${version#release-}"
    echo "$version"
}

# Function to get current version from overlay
function get_current_overlay_version() {
    local package="$1"
    local pkg_dir="${__cosmic_utils_dir}/${package}"
    
    if [ ! -d "$pkg_dir" ]; then
        echo "not-in-overlay"
        return 0
    fi
    
    # Find the latest non-9999 ebuild
    local latest_ebuild
    latest_ebuild=$(find "$pkg_dir" -maxdepth 1 -name "${package}-*.ebuild" ! -name "*-9999.ebuild" -type f 2>/dev/null | sort -V | tail -n1)
    
    if [ -z "$latest_ebuild" ]; then
        echo "9999-only"
        return 0
    fi
    
    # Extract version from filename
    local basename
    basename=$(basename "$latest_ebuild" .ebuild)
    local version="${basename#${package}-}"
    echo "$version"
}

# Function to compare versions (simple string comparison for now)
function version_newer() {
    local current="$1"
    local new="$2"
    
    # If not in overlay, it's newer
    if [ "$current" = "not-in-overlay" ]; then
        return 0
    fi
    
    # If only 9999 exists, any versioned release is newer
    if [ "$current" = "9999-only" ]; then
        return 0
    fi
    
    # Simple string comparison (can be enhanced with version comparison logic)
    if [ "$current" != "$new" ]; then
        return 0
    fi
    
    return 1
}

# Function to check a single repository
function check_repository() {
    local repo="$1"
    local current_version
    local upstream_version=""
    local version_source=""
    
    current_version=$(get_current_overlay_version "$repo")
    
    # Try to get version from GitHub releases first
    upstream_version=$(get_github_release_version "$repo" || true)
    if [ -n "$upstream_version" ]; then
        version_source="GitHub Release"
    else
        # Try git tags
        upstream_version=$(get_latest_git_tag "$repo" || true)
        if [ -n "$upstream_version" ]; then
            version_source="Git Tag"
        else
            # Try Cargo.toml
            upstream_version=$(get_cargo_toml_version "$repo" || true)
            if [ -n "$upstream_version" ]; then
                version_source="Cargo.toml"
            fi
        fi
    fi
    
    # Normalize versions
    if [ -n "$upstream_version" ]; then
        upstream_version=$(normalize_version "$upstream_version")
    fi
    
    # Output results
    if [ -z "$upstream_version" ]; then
        echo "${repo}|${current_version}|no-version-found|N/A|unknown"
    elif version_newer "$current_version" "$upstream_version"; then
        echo "${repo}|${current_version}|${upstream_version}|${version_source}|update-available"
    else
        echo "${repo}|${current_version}|${upstream_version}|${version_source}|up-to-date"
    fi
}

# Main execution
function main() {
    local output_format="${1:-table}"
    local filter="${2:-all}"  # all, updates-only, new-only
    
    log "Checking cosmic-utils repositories for new versions..."
    
    # Inform about authentication status
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        log "Using authenticated GitHub API (rate limit: 5000/hour)"
    else
        warn "No GitHub token found. Rate limit: 60/hour. Set GITHUB_TOKEN or authenticate with 'gh auth login'"
    fi
    
    log "This may take a few minutes depending on the number of repositories..."
    echo ""
    
    # Get list of repositories
    local repos
    repos=$(get_cosmic_utils_repos) || {
        error "Failed to fetch repositories from ${GITHUB_ORG}"
        exit 1
    }
    
    if [ -z "$repos" ]; then
        error "No repositories found in ${GITHUB_ORG}"
        exit 1
    fi
    
    local repo_count
    repo_count=$(echo "$repos" | wc -l)
    log "Found ${repo_count} repositories to check"
    echo ""
    
    # Create temporary file for results
    TEMP_RESULTS=$(mktemp)
    
    # Header
    echo "PACKAGE|CURRENT|UPSTREAM|SOURCE|STATUS" > "$TEMP_RESULTS"
    
    # Check each repository
    local counter=0
    while IFS= read -r repo; do
        counter=$((counter + 1))
        log "[$counter/$repo_count] Checking ${repo}..."
        check_repository "$repo" >> "$TEMP_RESULTS"
    done <<< "$repos"
    
    echo ""
    log "Analysis complete!"
    echo ""
    
    # Display results based on format
    if [ "$output_format" = "table" ]; then
        display_table "$TEMP_RESULTS" "$filter"
    elif [ "$output_format" = "json" ]; then
        display_json "$TEMP_RESULTS" "$filter"
    else
        # CSV output
        cat "$TEMP_RESULTS"
    fi
}

# Function to display results as a table
function display_table() {
    local results_file="$1"
    local filter="$2"
    
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                      COSMIC-UTILS VERSION CHECK RESULTS                       ║"
    echo "╟────────────────────────────────────┬───────────┬───────────┬─────────────────╢"
    echo "║ Package                            │ Current   │ Upstream  │ Status          ║"
    echo "╟────────────────────────────────────┼───────────┼───────────┼─────────────────╢"
    
    local update_count=0
    local new_count=0
    local uptodate_count=0
    local unknown_count=0
    
    while IFS='|' read -r package current upstream source status; do
        # Skip header
        if [ "$package" = "PACKAGE" ]; then
            continue
        fi
        
        # Apply filter
        if [ "$filter" = "updates-only" ] && [ "$status" != "update-available" ]; then
            continue
        fi
        if [ "$filter" = "new-only" ] && [ "$current" != "not-in-overlay" ]; then
            continue
        fi
        
        # Count status
        case "$status" in
            update-available)
                if [ "$current" = "not-in-overlay" ]; then
                    new_count=$((new_count + 1))
                else
                    update_count=$((update_count + 1))
                fi
                ;;
            up-to-date)
                uptodate_count=$((uptodate_count + 1))
                ;;
            unknown)
                unknown_count=$((unknown_count + 1))
                ;;
        esac
        
        # Format output with colors
        local status_display
        case "$status" in
            update-available)
                if [ "$current" = "not-in-overlay" ]; then
                    status_display="${GREEN}NEW${NC}"
                else
                    status_display="${YELLOW}UPDATE${NC}"
                fi
                ;;
            up-to-date)
                status_display="${GREEN}UP-TO-DATE${NC}"
                ;;
            unknown)
                status_display="${RED}NO VERSION${NC}"
                continue  # Skip packages with no version info
                ;;
        esac
        
        # Truncate package name if too long
        local pkg_display="$package"
        if [ ${#pkg_display} -gt 34 ]; then
            pkg_display="${pkg_display:0:31}..."
        fi
        
        # Truncate versions if too long
        local curr_display="$current"
        if [ "$curr_display" = "not-in-overlay" ]; then
            curr_display="---"
        elif [ ${#curr_display} -gt 9 ]; then
            curr_display="${curr_display:0:8}…"
        fi
        
        local up_display="$upstream"
        if [ ${#up_display} -gt 9 ]; then
            up_display="${up_display:0:8}…"
        fi
        
        printf "║ %-34s │ %-9s │ %-9s │ %-15s ║\n" "$pkg_display" "$curr_display" "$up_display" "$(echo -e "$status_display")"
    done < "$results_file"
    
    echo "╚════════════════════════════════════╧═══════════╧═══════════╧═════════════════╝"
    echo ""
    echo "Summary:"
    echo "  ${GREEN}●${NC} New packages available:    $new_count"
    echo "  ${YELLOW}●${NC} Updates available:         $update_count"
    echo "  ${GREEN}●${NC} Up-to-date packages:       $uptodate_count"
    echo "  ${RED}●${NC} No version info:           $unknown_count"
    echo ""
    
    if [ $new_count -gt 0 ] || [ $update_count -gt 0 ]; then
        echo "To see details about a specific package, check: https://github.com/cosmic-utils/<package>"
    fi
}

# Function to display results as JSON
function display_json() {
    local results_file="$1"
    local filter="$2"
    
    echo "{"
    echo "  \"checked_at\": \"$(date -Iseconds)\","
    echo "  \"organization\": \"${GITHUB_ORG}\","
    echo "  \"packages\": ["
    
    local first=true
    while IFS='|' read -r package current upstream source status; do
        # Skip header
        if [ "$package" = "PACKAGE" ]; then
            continue
        fi
        
        # Apply filter
        if [ "$filter" = "updates-only" ] && [ "$status" != "update-available" ]; then
            continue
        fi
        if [ "$filter" = "new-only" ] && [ "$current" != "not-in-overlay" ]; then
            continue
        fi
        
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        echo "    {"
        echo "      \"name\": \"$package\","
        echo "      \"current_version\": \"$current\","
        echo "      \"upstream_version\": \"$upstream\","
        echo "      \"version_source\": \"$source\","
        echo "      \"status\": \"$status\","
        echo "      \"repository_url\": \"https://github.com/${GITHUB_ORG}/${package}\""
        echo -n "    }"
    done < "$results_file"
    
    echo ""
    echo "  ]"
    echo "}"
}

# Show usage
function show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Check for new versions of cosmic-utils packages from GitHub.

OPTIONS:
    table              Display results as a formatted table (default)
    json               Display results as JSON
    csv                Display results as CSV
    updates-only       Show only packages with updates available
    new-only           Show only packages not yet in the overlay

EXAMPLES:
    $0                          # Show all results in table format
    $0 json                     # Output as JSON
    $0 table updates-only       # Show only packages with updates
    $0 table new-only           # Show only new packages

ENVIRONMENT:
    GITHUB_TOKEN               Optional GitHub personal access token for higher API rate limits

NOTES:
    - Checks GitHub releases first, then git tags, then Cargo.toml
    - Requires curl, jq, and git to be installed
    - Results are compared against packages in cosmic-utils/ category
    - Rate limit: 60 requests/hour without token, 5000 with token

EOF
}

# Parse arguments
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_usage
    exit 0
fi

FORMAT="${1:-table}"
FILTER="${2:-all}"

# Validate format
case "$FORMAT" in
    table|json|csv|updates-only|new-only)
        ;;
    *)
        error "Invalid format: $FORMAT"
        show_usage
        exit 1
        ;;
esac

# Handle shorthand filters
if [ "$FORMAT" = "updates-only" ]; then
    FILTER="updates-only"
    FORMAT="table"
elif [ "$FORMAT" = "new-only" ]; then
    FILTER="new-only"
    FORMAT="table"
fi

# Run main function
main "$FORMAT" "$FILTER"
