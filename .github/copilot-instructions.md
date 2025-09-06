# Copilot Instructions for COSMIC Overlay

This is a Gentoo overlay repository for the COSMIC desktop environment. These instructions help GitHub Copilot understand the repository structure and assist with development tasks.

## Repository Context

### Purpose

- Unofficial Gentoo overlay for COSMIC desktop environment (by System76)
- Provides ebuilds for COSMIC DE packages and related components
- Includes custom eclass (`cosmic-de.eclass`) for common functionality
- Maintains both stable tagged releases and live git ebuilds

### Technology Stack

- **Language**: Bash (for ebuilds, eclass, and scripts)
- **Package Manager**: Portage (Gentoo)
- **Build System**: Cargo (Rust packages)
- **Version Control**: Git
- **Target**: Linux (Gentoo distribution)

## Repository Structure

```
cosmic-overlay/
├── cosmic-base/              # Main COSMIC DE packages (PRIMARY CATEGORY)
│   ├── cosmic-*/            # Individual COSMIC applications
│   ├── pop-*/               # System76 Pop!_OS components
│   └── */metadata.xml       # Package metadata
├── acct-group/cosmic-greeter/ # System groups
├── acct-user/cosmic-greeter/  # System users
├── eclass/cosmic-de.eclass   # CUSTOM ECLASS (important!)
├── scripts/                  # Automation scripts
├── metadata/layout.conf      # Overlay configuration
└── profiles/                 # Gentoo profiles
```

## Key Files and Their Purpose

### Ebuilds (`.ebuild` files)

- **Naming**: `package-version.ebuild` or `package-9999.ebuild` (live)
- **Structure**: Gentoo ebuild format using EAPI 8
- **Inheritance**: Most inherit from `cosmic-de.eclass`
- **Dependencies**: Rust packages, system libraries

### Eclass (`cosmic-de.eclass`)

- **Location**: `eclass/cosmic-de.eclass`
- **Purpose**: Common functionality for COSMIC packages
- **Features**: Rust version management, USE flags, build profiles
- **Important**: Must be updated carefully as it affects all packages

### Scripts (`scripts/`)

- **`bump_all_ebuilds.sh`**: Updates all package versions
- **`bump_all_tagged_ebuilds.sh`**: Updates only stable releases
- **`digests_and_cache.sh`**: Regenerates manifests and metadata
- **`generate_tarballs_for_tag.sh`**: Creates release archives

### Metadata

- **`metadata.xml`**: Package descriptions and metadata
- **`Manifest`**: File checksums and signatures
- **`layout.conf`**: Overlay configuration

## Important Conventions

### Package Categories

- **Current**: `cosmic-base/` (as of 05.2025)
- **Legacy**: `cosmic-de/` (deprecated, migrated via pkgmove)
- **Related**: `acct-group/`, `acct-user/`, `virtual/`, `x11-themes/`

### Version Schemes

- **Stable**: `1.0.0_alpha7-r10` (follows upstream tags)
- **Live**: `9999` (tracks git master branch)
- **Revisions**: `-r1`, `-r2` etc. for ebuild fixes

### USE Flags (from cosmic-de.eclass)

- `debug`: Debug build profile
- `debug-line-tables-only`: Minimal debug info
- `max-opt`: Maximum optimization profile
- Mutually exclusive: `debug` and `max-opt`

### File Naming

- Ebuilds: `${PN}-${PV}.ebuild`
- Live ebuilds: `${PN}-9999.ebuild`
- Patches: `files/${PN}-${PV}-patch-name.patch`

## Development Patterns

### When Adding New Packages

1. Create directory under `cosmic-base/`
2. Write ebuild inheriting `cosmic-de.eclass`
3. Create `metadata.xml` with proper description
4. Generate `Manifest` using `ebuild digest`
5. Test build and runtime functionality

### When Updating Existing Packages

1. Copy existing ebuild to new version
2. Update dependencies if needed
3. Test build with new version
4. Update `Manifest` with `ebuild digest`
5. Remove old versions if stable

### When Modifying Eclass

1. **CRITICAL**: Test with multiple packages
2. Update version requirements carefully
3. Maintain backward compatibility
4. Document changes in commit message
5. Coordinate with package updates

## Build and Test Commands

### Common Portage Commands

```bash
# Test build without installing
ebuild package-version.ebuild clean compile

# Generate manifest
ebuild package-version.ebuild digest

# Install for testing
emerge package-name

# Check for QA issues (modern)
pkgcheck scan

# Update manifests (modern)
pkgdev manifest

# Legacy QA checking
repoman full
```

### Overlay-Specific Scripts

```bash
# Update all packages
./scripts/bump_all_ebuilds.sh

# Update stable packages only
./scripts/bump_all_tagged_ebuilds.sh

# Regenerate manifests
./scripts/digests_and_cache.sh
```

## Common Issues and Solutions

### Rust-Related

- **Minimum Version**: Rust 1.85.1+ required
- **Cargo Dependencies**: Usually bundled (no unbundling)
- **Build Profiles**: Handled by eclass

### Ebuild Issues

- **EAPI**: Always use EAPI 8
- **Dependencies**: Check both DEPEND and BDEPEND
- **USE Flags**: Follow eclass conventions

### Manifest Problems

- **Missing Digests**: Run `ebuild digest`
- **Stale Entries**: Remove old entries manually
- **Network Issues**: May need to retry downloads

## Quality Assurance

### Before Committing

1. Run `pkgcheck scan` to check QA issues
2. Test build on clean system
3. Verify runtime functionality
4. Check for missing dependencies
5. Update documentation if needed

### Testing Strategy

- Test both stable and live ebuilds
- Test different USE flag combinations
- Verify on minimal Gentoo system
- Check integration with full COSMIC DE

## Automation and CI

### Current Status

- **GitHub Actions**: Automated QA pipeline using pkgcheck/pkgdev
- **Weekly Schedule**: Runs every Sunday at 06:00 UTC
- **PR Integration**: Comments with QA results on pull requests
- **Reports**: Generated in HTML and Markdown formats
- **GitHub Pages**: Public QA reports at `https://fsvm88.github.io/cosmic-overlay/qa-reports/`

### QA Pipeline Features

- Docker-based Gentoo environment
- Full pkgcheck validation with multiple severity levels
- pkgdev manifest integrity checks
- Category-specific validation
- Automated issue creation on failures
- Artifact retention (30 days)

### Workflows

- **`qa-check.yml`**: Main QA validation pipeline
- **`deploy-pages.yml`**: Deploy reports to GitHub Pages

### Future Improvements

- Package build testing
- Dependency graph validation
- Performance metrics
- Integration with overlay sync tools

## Special Considerations

### Migration Notes

- Packages moved from `cosmic-de/` to `cosmic-base/` in 05.2025
- Users need to update package.accept_keywords
- pkgmove handles automatic migration

### Upstream Coordination

- COSMIC DE is in active development
- Frequent API changes in alpha stage
- Live ebuilds may break with upstream changes
- Tag-based releases more stable

## File Update Rules

### Auto-Update Triggers

This instructions file should be updated when:

1. **Repository structure changes** (new categories, major reorganization)
2. **Eclass modifications** that affect usage patterns
3. **New automation scripts** are added
4. **Build procedures change** significantly
5. **QA requirements evolve**
6. **Upstream COSMIC changes** affect overlay structure

### Manual Update Scenarios

- New package categories added
- Eclass API changes
- Script functionality changes
- Testing procedures updated
- Documentation standards modified

---

**Purpose**: GitHub Copilot instructions for COSMIC overlay development
**Last Updated**: Auto-generated based on repository analysis
**Repository**: https://github.com/fsvm88/cosmic-overlay
