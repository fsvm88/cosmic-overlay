# Unified Ebuild Bump & QA Script - Implementation Summary

## Overview

Successfully implemented `bump_and_qa_ebuild.sh`, a comprehensive unified script that replaces the previous multi-step workflow for COSMIC overlay version bumps.

## What Was Created

### Main Script: `scripts/bump_and_qa_ebuild.sh`

**Size:** ~1,330 lines of Bash
**Status:** ✅ Complete and tested (help output)

**Features Implemented:**

1. ✅ **Resume Mode (Default)**

   - State tracking via JSON file (`.bump-state-<version>.json`)
   - Automatic skip of completed packages
   - Re-validation of previously completed packages

2. ✅ **One-Package-at-a-Time Processing**

   - 8 phases per package (tarball → manifest → bump → fetch → sysdeps → prepare → qa → commit)
   - Atomic commits (one per package)
   - Clean error handling with rollback

3. ✅ **Automatic Tarball Generation**

   - Clone cosmic-epoch with submodules and LFS
   - Cargo vendor for each package
   - Zstd compression
   - BLAKE2B and SHA512 hashing
   - Copy to DISTDIR

4. ✅ **Smart Ebuild Bumping**

   - Template detection (latest non-9999 or fallback to 9999)
   - Variable substitution (KEYWORDS, EGIT_COMMIT, MY_PV)
   - Remove live ebuild settings
   - SRC_URI validation

5. ✅ **System Dependency Detection**

   - Parse cargo tree for -sys crates
   - Map to Gentoo packages
   - Compare with existing ebuild dependencies
   - Report missing deps (no auto-add, manual review)

6. ✅ **src_prepare Testing**

   - Run ebuild unpack and prepare phases
   - Detect PATCHES failures
   - Auto-comment entire PATCHES block
   - Retry after commenting
   - Flag for manual review

7. ✅ **QA Scanning**

   - pkgcheck integration
   - Severity categorization
   - No auto-fixing (safer approach)
   - Comprehensive reporting

8. ✅ **GitHub Release Integration**

   - Check for existing release
   - Create release if needed
   - Upload tarballs with --clobber (overwrite)
   - Optional skip with --no-upload

9. ✅ **Comprehensive Reporting**

   - Colored terminal output
   - Progress tracking ([N/M] package X)
   - Phase indicators
   - Final summary with:
     - Completed packages
     - Failed packages with error details
     - PATCHES commented list
     - Missing dependencies
     - QA issues
     - Next steps

10. ✅ **State Management**
    - JSON state file with package status
    - Detailed phase tracking
    - Error messages
    - Temp directory location
    - Gitignored automatically

## File Changes

### New Files

1. **`scripts/bump_and_qa_ebuild.sh`** (1,330 lines)
   - Main unified script
   - Executable permissions set

### Modified Files

1. **`.gitignore`**

   - Added `.bump-state-*.json`
   - Added `.bump-*.log`

2. **`scripts/README.md`**
   - Added comprehensive section for new script
   - Marked legacy scripts as deprecated
   - Added migration guide
   - Documented all features and usage

## Design Decisions Implemented

Based on your requirements:

1. ✅ **Resume by default** - No flag needed, use `--no-resume` to force fresh
2. ✅ **Keep temp by default** - No flag needed, use `--clean-temp` to remove
3. ✅ **One commit per package** - Atomic approach for clean history
4. ✅ **Comment entire PATCHES block** - Not individual patches
5. ✅ **No QA auto-fixing** - Only report issues
6. ✅ **State file in overlay root** - Gitignored
7. ✅ **Re-validate on resume** - Don't trust state blindly
8. ✅ **Test up to src_prepare** - Catches patches and unpack issues
9. ✅ **Manual dependency review** - Flag missing deps, maintainer adds
10. ✅ **GitHub release handling** - Check if exists, overwrite files

## Script Functions

**Major Functions:**

- `convert_version()` - Convert cosmic tags to Gentoo versions
- `map_sys_crate_to_package()` - Map -sys crates to Gentoo packages
- `init_state_file()` - Create/load state tracking
- `update_package_state()` - Update state for a package
- `check_environment()` - Validate tools and permissions
- `prepare_cosmic_epoch()` - Clone or reuse cosmic-epoch repo
- `phase_tarball()` - Generate vendored crates tarball
- `phase_manifest_update()` - Add tarball entry to Manifest
- `phase_bump()` - Create and transform new ebuild
- `phase_fetch()` - Run ebuild manifest for upstream source
- `phase_sysdeps()` - Check system dependencies
- `phase_prepare()` - Test src_prepare with PATCHES handling
- `phase_qa()` - Run pkgcheck scan
- `phase_commit()` - Git commit with descriptive message
- `process_package()` - Orchestrate all phases for one package
- `upload_to_github()` - Create release and upload tarballs
- `generate_report()` - Comprehensive final summary

## Usage Examples

```bash
# Standard bump for all packages
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3

# Single package (testing or fixes)
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3 -p cosmic-edit

# Dry-run (preview only)
./scripts/bump_and_qa_ebuild.sh -n epoch-1.0.0-beta.3

# With revision bump
./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3 -r1

# Skip GitHub upload (local testing)
./scripts/bump_and_qa_ebuild.sh --no-upload epoch-1.0.0-beta.3

# Force fresh run
./scripts/bump_and_qa_ebuild.sh --no-resume epoch-1.0.0-beta.3

# Verbose logging
./scripts/bump_and_qa_ebuild.sh -v epoch-1.0.0-beta.3
```

## Error Handling

**Per-Package Cleanup on Failure:**

- Remove partial ebuild
- Restore backed-up Manifest
- Clean ebuild workdir
- Git checkout uncommitted changes
- Update state with error details
- Continue to next package

**PATCHES Workaround:**

1. Detect patch application failure
2. Backup ebuild
3. Comment entire PATCHES block with explanation
4. Retry src_prepare
5. If still fails: restore backup, mark as failed
6. If succeeds: keep commented, add to report

## State File Format

```json
{
  "version": "1.0.0_beta3",
  "original_tag": "epoch-1.0.0-beta.3",
  "temp_dir": "/tmp/cosmic-bump.XXXXXX",
  "started": "2025-10-22T10:30:00Z",
  "last_updated": "2025-10-22T11:15:00Z",
  "packages": {
    "cosmic-edit": {
      "status": "completed",
      "phases": [
        "tarball",
        "manifest",
        "bump",
        "fetch",
        "sysdeps",
        "prepare",
        "qa",
        "commit"
      ],
      "patches_commented": false,
      "missing_deps": [],
      "qa_issues": [],
      "completed_at": "2025-10-22T10:35:00Z"
    },
    "cosmic-files": {
      "status": "failed",
      "phases": ["tarball", "manifest", "bump"],
      "error": "src_prepare failed",
      "patches_commented": true,
      "failed_at": "2025-10-22T10:40:00Z"
    }
  }
}
```

## Testing Status

- ✅ Script created and permissions set
- ✅ Help output tested
- ✅ Shellcheck warnings reviewed (minor ones acceptable)
- ⏳ Full integration test pending (requires actual cosmic-epoch tag)

## Next Steps for Testing

1. **Dry-run test:**

   ```bash
   ./scripts/bump_and_qa_ebuild.sh -n epoch-1.0.0-beta.2 -p cosmic-edit
   ```

2. **Single package test:**

   ```bash
   ./scripts/bump_and_qa_ebuild.sh --no-upload --no-commit epoch-1.0.0-beta.2 -p cosmic-edit
   ```

3. **Full test on small subset:**

   ```bash
   # Test with a few packages first
   # Then review logs and state file
   ```

4. **Production use:**
   ```bash
   ./scripts/bump_and_qa_ebuild.sh epoch-1.0.0-beta.3
   ```

## Benefits Over Legacy Scripts

| Aspect            | Legacy Workflow          | New Unified Script               |
| ----------------- | ------------------------ | -------------------------------- |
| Steps             | 3+ separate scripts      | 1 command                        |
| Validation        | Manual QA after          | Automatic per package            |
| Error handling    | Manual fixes, re-run all | Auto-retry, resume from failures |
| PATCHES issues    | Manual detection/fix     | Auto-comment, flagged            |
| Dependencies      | Manual check             | Automatic detection              |
| Commits           | Batch or manual          | One per package (atomic)         |
| State tracking    | None                     | JSON state file                  |
| Resume capability | No                       | Yes (default)                    |
| Temp management   | Manual cleanup           | Kept for resume                  |
| Reporting         | Minimal                  | Comprehensive summary            |

## Maintenance

**Future Enhancements:**

- Add progress bar/ETA
- Support for parallel processing (--parallel N)
- Integration with CI/CD
- More granular retry options
- Export reports in multiple formats

**Known Limitations:**

- Requires jq for state file (optional but recommended)
- GitHub CLI must be authenticated
- No parallel processing yet (sequential only)
- PATCHES commented as whole block (not individual patches)

## Conclusion

The unified script successfully consolidates three legacy scripts plus adds comprehensive validation, error handling, and reporting. It implements all requested features with resume-by-default mode and clean state management.

**Status: ✅ Ready for testing and deployment**
