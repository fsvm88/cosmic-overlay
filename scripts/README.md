# COSMIC Overlay Scripts

This directory contains scripts for testing, validating, and managing the COSMIC overlay repository using modern Gentoo QA tools.

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

### 📊 Report Generation

**`generate-qa-report.py`** - Generate HTML/Markdown reports

- **Enhanced HTML Output**: Modern table-based layout with responsive design
- **Package-Issue Layout**: One row per package issue (improved from card layout)
- **Color-Coded Severity**: Error=red, Warning=orange, Info=blue, Style=purple
- **JSON Parsing**: Native handling of pkgcheck JSON and line-delimited JSON formats
- **Mobile-Friendly**: Responsive design with sticky headers and hover effects
- **Backwards Compatibility**: Falls back to text-based parsing for legacy tools
- **Requirements:** Python 3 (standard library only)
- **Usage:** `python3 scripts/generate-qa-report.py [--overlay-root PATH] [--reports-dir PATH]`

## Repository Management Scripts (Bash)

### 🔄 Package Updates

**`bump_all_ebuilds.sh`** - Update all packages to latest versions

- Updates both stable and live ebuilds
- Fetches latest tags from upstream repositories
- **Usage:** `./scripts/bump_all_ebuilds.sh`

**`bump_all_tagged_ebuilds.sh`** - Update stable packages only

- Updates only tagged releases (skips live ebuilds)
- Safer option for production overlays
- **Usage:** `./scripts/bump_all_tagged_ebuilds.sh`

### 🛠️ Maintenance

**`digests_and_cache.sh`** - Regenerate manifests and metadata cache

- Updates Manifest files for all packages
- Regenerates metadata cache
- **Usage:** `./scripts/digests_and_cache.sh`

**`generate_tarballs_for_tag.sh`** - Create release archives

- Generates tarballs for specific git tags
- Used for release management
- **Usage:** `./scripts/generate_tarballs_for_tag.sh <tag>`

**`get_sys_deps.sh`** - Extract system dependencies

- Analyzes and lists system dependencies
- Useful for documentation and packaging
- **Usage:** `./scripts/get_sys_deps.sh`

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
2. **Generate reports:** `python3 scripts/generate-qa-report.py`
3. **Full pipeline test:** `python3 scripts/test-qa-pipeline.py` (if Docker available)

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
- **pkgcheck missing:** Install dev-python/pkgcheck for full functionality
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
