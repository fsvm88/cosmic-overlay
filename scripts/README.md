# COSMIC Overlay Scripts

This directory contains scripts for testing, validating, and managing the COSMIC overlay repository using modern Gentoo QA tools.

## 🚀 Main Version Bump Script (NEW)

### **`bump_and_qa_ebuild.sh`** - Unified Ebuild Bump & QA Tool

**⭐ RECOMMENDED for all version bumps** - Comprehensive script that handles the entire bump process for COSMIC packages, processing one ebuild at a time with full validation.

**Key Features:**

- 🔄 **Resume by default** - Automatically skips completed packages, efficient for large bumps
- 📦 **One package at a time** - Clear progress, atomic commits, easier debugging
- 🎯 **Full validation** - Tarball generation → Manifest → Bump → QA → Commit
- 🔍 **Smart error handling** - Auto-comments failing PATCHES, clean rollback on errors
- 📊 **Comprehensive reports** - Detailed summaries of completed, failed, and problematic packages
- 💾 **State tracking** - JSON state file enables resume after failures or interruptions
- 🌐 **GitHub integration** - Automatic release creation and tarball upload

**Quick Start:**

```bash
# Bump all packages for a new COSMIC release
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3

# Process single package (useful for testing or fixes)
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3 -p cosmic-edit

# Dry-run to preview what would happen
./scripts/bump_and_qa_ebuild.sh -n epoch-1.0.0-beta.3

# Resume after fixing failed packages
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3  # Just run again!
```

**Advanced Options:**

```bash
# Add Gentoo revision bump (-r1, -r2, etc.)
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3 -r1

# Force fresh run, ignore previous state
./scripts/bump_and_qa_ebuild.sh --no-resume epoch-1.0.0-beta.3

# Skip GitHub upload (local testing only)
./scripts/bump_and_qa_ebuild.sh --no-upload epoch-1.0.0-beta.3

# Testing mode - no commits to git
./scripts/bump_and_qa_ebuild.sh --no-commit epoch-1.0.0-beta.3

# Enable verbose logging
./scripts/bump_and_qa_ebuild.sh -v epoch-1.0.0-beta.3

# Clean up temp directory when done
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3 --clean-temp
```

**Process Flow:**

Each package goes through these phases:

1. **Tarball** - Generate vendored crates with `cargo vendor` + zstd compression
2. **Manifest** - Add tarball entry with BLAKE2B and SHA512 hashes
3. **Bump** - Create new ebuild from template, update variables
4. **Fetch** - Run `ebuild manifest` to download upstream source
5. **Sysdeps** - Check for missing system dependencies via cargo tree
6. **Prepare** - Test `src_prepare` phase (unpack + patch application)
7. **QA** - Run pkgcheck scan for quality issues
8. **Commit** - Git commit with descriptive message (one per package)

**Note:** Meta-packages (e.g., `cosmic-meta`, `pop-theme-meta`) only go through phases 3, 7, and 8 (Bump → QA → Commit) since they have no source code.

**State Management:**

- State file: `.bump-state-<version>.json` (auto-gitignored)
- Log file: `.bump-<version>-<timestamp>.log` (auto-gitignored)
- Temp directory: Kept by default for resume capability
- Re-validation: Completed packages are re-validated on resume

**Error Handling:**

- **PATCHES failures**: Automatically commented out, flagged for manual review
- **Package failures**: Logged, cleaned up, script continues to next package
- **Missing dependencies**: Detected and reported, not auto-added (manual review)
- **QA issues**: Scanned and reported, no auto-fixing (safer approach)

**Report Output:**

```
╔═══════════════════════════════════════════════════════════════╗
║       COSMIC OVERLAY BUMP REPORT: 1.0.0_beta3                ║
╚═══════════════════════════════════════════════════════════════╝

✓ COMPLETED PACKAGES (24)
  ✓ cosmic-edit
  ✓ cosmic-files ⚠ PATCHES COMMENTED
  ...

✗ FAILED PACKAGES (3)
  ✗ cosmic-comp (Phase: prepare)
  ...

⚠ PATCHES COMMENTED (Manual Review Required)
  • cosmic-files - Patch application failed

⚠ MISSING SYSTEM DEPENDENCIES
  cosmic-settings: media-libs/libpulse:0

⚠ QA ISSUES
  cosmic-edit: [error] MissingUnpackerDep
```

**Requirements:**

- `git`, `git-lfs` - Repository management
- `gh` - GitHub CLI (authenticated)
- `cargo` - Rust dependency management
- `ebuild`, `pkgdev`, `pkgcheck` - Gentoo package tools
- `zstd`, `b2sum`, `sha512sum` - Compression and hashing
- `jq` - JSON state file handling (optional but recommended)

---

## QA and Testing Scripts (Python)

_Replaced bash versions on 2025-09-04 for better maintainability and enhanced functionality._

### 🐳 Docker-based Testing

**`test-qa-pipeline.py`** - Full pipeline test using Docker

- **Container Testing**: Uses official Gentoo Docker image for clean environment
- **Pipeline Simulation**: Runs the same commands as GitHub Actions workflow
- **Environment Setup**: Automatically installs pkgcheck/pkgdev in container
- **Interactive Mode**: Supports interactive container sessions for debugging
- **Fallback Integration**: Can fall back to simple QA check if Docker unavailable
- **Requirements:** Docker, Python 3 (standard library only)
- **Usage:** `python3 scripts/test-qa-pipeline.py [--interactive] [--fallback]`

### ⚡ Native QA Testing

**`simple-qa-check.py`** - Modern QA validation using native tools

- **Tool Detection**: Automatically detects available QA tools (pkgcheck/pkgdev/emerge)
- **Centralized Configuration**: Uses `scripts/pkgcheck.conf` for consistent settings
- **Comprehensive Checks**: Overlay structure, pkgcheck scan, manifest integrity
- **Graceful Degradation**: Falls back to basic validation when tools unavailable
- **Report Integration**: Automatically generates HTML/Markdown reports
- **Requirements:** Python 3, pkgcheck/pkgdev (auto-detected, optional)
- **Usage:** `python3 scripts/simple-qa-check.py [--quiet] [--config CONFIG]`

## Repository Management Scripts (Bash)

### 🔄 Package Updates

**`check_cosmic_utils_versions.sh`** - Check for new cosmic-utils packages ⭐ **NEW**

- **Purpose:** Monitors 38+ community packages from [cosmic-utils](https://github.com/cosmic-utils) organization
- **Check Methods:** GitHub releases → Git tags → Cargo.toml (in priority order)
- **Comparison:** Compares upstream versions against local cosmic-utils/ category
- **Output Formats:** Table (default), JSON, CSV
- **Filtering:** Show all, updates-only, or new-only packages
- **Rate Limits:** 60 req/hour (no auth), 5000 req/hour (with GITHUB_TOKEN)
- **Requirements:** curl, jq, git

**Usage:**

```bash
# Show all packages in table format
./scripts/check_cosmic_utils_versions.sh

# Show only packages with updates available
./scripts/check_cosmic_utils_versions.sh updates-only

# Show only new packages not yet in overlay
./scripts/check_cosmic_utils_versions.sh new-only

# Output as JSON for automation
./scripts/check_cosmic_utils_versions.sh json

# With GitHub authentication (higher rate limit)
export GITHUB_TOKEN="ghp_your_token_here"
./scripts/check_cosmic_utils_versions.sh
```

**Output Example:**

```
╔════════════════════════════════════════════════════════════════════════════════╗
║                      COSMIC-UTILS VERSION CHECK RESULTS                       ║
╟────────────────────────────────────┬───────────┬───────────┬─────────────────╢
║ Package                            │ Current   │ Upstream  │ Status          ║
╟────────────────────────────────────┼───────────┼───────────┼─────────────────╢
║ calculator                         │ 0.1.0     │ 0.2.0     │ UPDATE          ║
║ tasks                              │ not-in... │ 0.3.0     │ NEW             ║
║ forecast                           │ 1.0.0     │ 1.0.0     │ UP-TO-DATE      ║
╚════════════════════════════════════╧═══════════╧═══════════╧═════════════════╝
```

### 🛠️ Maintenance

**`digests_and_cache.sh`** - Regenerate manifests and metadata cache

- Updates Manifest files for all packages
- Regenerates metadata cache
- **Usage:** `./scripts/digests_and_cache.sh`

**`get_sys_deps.sh`** - Extract system dependencies ⚠️ **INTEGRATED**

- **Functionality integrated into `bump_and_qa_ebuild.sh`**
- Kept for standalone use if needed
- Analyzes and lists system dependencies
- **Usage:** `./scripts/get_sys_deps.sh [tag]`

---

## 📋 Migration Guide

**Moving from legacy scripts to unified script:**

| Old Workflow                                                                                                             | New Workflow                                |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| `generate_tarballs_for_tag.sh epoch-1.0.0-beta.3`<br>`bump_all_tagged_ebuilds.sh epoch-1.0.0-beta.3`<br>Manual QA checks | `bump_and_qa_ebuild.sh epoch-1.0.0-beta.3`  |
| Manual dependency checking with `get_sys_deps.sh`                                                                        | Automatic during bump process               |
| Manual manifest updates                                                                                                  | Automatic during bump process               |
| Manual PATCHES fixes                                                                                                     | Auto-commented with report                  |
| Manual GitHub uploads                                                                                                    | Automatic with `--no-upload` option to skip |

**Benefits:**

- ✅ One command instead of multiple steps
- ✅ Automatic resume on failures
- ✅ Per-package commits for clean git history
- ✅ Comprehensive reporting of all issues
- ✅ Safe error handling with automatic rollback

## Configuration

### pkgcheck.conf

Centralized configuration for all QA tools:

- **Minimal overrides:** Only essential settings
- **Architecture filtering:** Limited to amd64,arm64
- **Warning suppression:** Disabled overlay-irrelevant checks (RequiredUseDefaults, RedundantVersion)
- **Exit behavior:** Configured to exit on errors and warnings

## Features

### Modern Python Implementation

- **Standard library only:** No external Python dependencies (json, pathlib, subprocess, argparse, datetime, re)
- **Robust JSON parsing:** Native handling of pkgcheck line-delimited JSON format
- **Enhanced HTML reports:** Table-based layout with one row per package issue
- **Responsive design:** Mobile-friendly with sticky headers, hover effects, and color-coded severity
- **Backwards compatibility:** Same CLI interfaces as bash versions with additional options
- **Better error handling:** Comprehensive exception handling and graceful recovery

### HTML Report Improvements

- **Table Layout**: One row per package issue with package names in monospace
- **Color-Coded Severity**: Error=red, Warning=orange, Info=blue, Style=purple
- **Modern CSS**: CSS Grid for statistics, Flexbox layouts, custom properties
- **Mobile-Friendly**: Responsive design that collapses multi-column lists
- **Tool Identification**: Clear indication of which tool generated each issue

### Quality Assurance

- **Automated tool detection:** Checks for pkgcheck/pkgdev/portage availability
- **Graceful degradation:** Falls back to basic validation when tools unavailable
- **Comprehensive logging:** Clear progress indicators and error messages
- **Exit code compliance:** Proper exit codes for CI/CD integration

## Quick Start Guide

### Local Development Testing

1. **Quick validation:** `python3 scripts/simple-qa-check.py`
2. **Full pipeline test:** `python3 scripts/test-qa-pipeline.py` (if Docker available)

### CI/CD Integration

1. **Add new packages:** Create ebuilds and metadata.xml
2. **Update versions:** Use bump scripts for version updates
3. **Validate changes:** `python3 scripts/simple-qa-check.py`

### Docker Testing

1. **Full Docker test:** `python3 scripts/test-qa-pipeline.py`
2. **Interactive debugging:** `python3 scripts/test-qa-pipeline.py --interactive`
3. **Fallback mode:** `python3 scripts/test-qa-pipeline.py --fallback`

## Dependencies

### Python Standard Library Only

- `json` - JSON parsing
- `pathlib` - File system operations
- `subprocess` - External command execution
- `argparse` - Command line argument parsing
- `datetime` - Timestamp generation
- `re` - Regular expression matching

### External Tools (Auto-detected)

- `pkgcheck` - Modern QA scanning (preferred)
- `pkgdev` - Manifest integrity checking
- `emerge` - Portage tools (optional)
- `docker` - Container testing (test-qa-pipeline.py only)

## Troubleshooting

### Common Issues

- **Python not found:** Ensure Python 3.8+ is installed
- **pkgcheck missing:** Install pkgcheck for full functionality
- **Docker issues:** Check Docker daemon status and permissions
- **Permission errors:** Ensure scripts are executable (`chmod +x`)

### Debug Mode

- **Verbose output:** Remove `--quiet` flag for detailed logging
- **Interactive Docker:** Use `--interactive` flag for manual debugging
- **Config validation:** Check `scripts/pkgcheck.conf` for custom settings

## Migration from Bash

The Python scripts maintain full compatibility with existing workflows:

- **Same command line interfaces** with additional options
- **Same output file formats** and directory structure
- **Same configuration files** (pkgcheck.conf)
- **Same exit codes** for CI/CD integration
- **Enhanced functionality** with better error handling

## Performance

- **Faster startup**: No bash subshell overhead
- **Better JSON parsing**: Native JSON support instead of text processing
- **Improved error handling**: Graceful degradation and clear error messages
- **More efficient file operations**: Native Python file I/O

---

**Migration Date**: 2025-09-04  
**Replaced Scripts**: `generate-qa-report.sh`, `simple-qa-check.sh`, `test-qa-pipeline.sh`  
**Compatibility**: Maintains full backwards compatibility with existing CI/CD pipeline

**Note:** Bash versions of QA scripts have been replaced with Python implementations for better maintainability and enhanced functionality.
