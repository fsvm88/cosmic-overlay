#!/usr/bin/env python3

"""
Simple Local QA Runner - pkgcheck-based overlay validation

This script provides comprehensive QA checks using modern Gentoo tools
and generates reports in the qa-reports directory.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple


class SimpleQAChecker:
    """Simple QA checker for COSMIC overlay."""

    def __init__(
        self, overlay_root: str, reports_dir: str, config_file: Optional[str] = None
    ):
        self.overlay_root = Path(overlay_root).resolve()
        self.reports_dir = Path(reports_dir).resolve()
        self.config_file = (
            config_file or self.overlay_root / "scripts" / "pkgcheck.conf"
        )

        # Create reports directory
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Track what tools are available
        self.has_pkgcheck = shutil.which("pkgcheck") is not None
        self.has_pkgdev = shutil.which("pkgdev") is not None
        self.has_portage = shutil.which("emerge") is not None

    def _log(self, message: str):
        """Simple logging function."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {message}")

    def _success(self, message: str):
        """Log success message."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] ✅ {message}")

    def _warn(self, message: str):
        """Log warning message."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] WARN: {message}")

    def _error(self, message: str):
        """Log error message."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] ERROR: {message}", file=sys.stderr)

    def check_requirements(self) -> bool:
        """Check if required tools are available."""
        self._log("Checking requirements...")

        # Check basic tools
        basic_tools = ["find", "grep", "awk", "sed"]
        for tool in basic_tools:
            if not shutil.which(tool):
                self._error(f"Missing required tool: {tool}")
                return False

        # Check Portage tools
        if self.has_portage:
            self._success("Portage tools available")
        else:
            self._warn("Portage tools not available - some checks may be limited")

        # Check pkgcheck
        if self.has_pkgcheck:
            self._success("pkgcheck available")
            return True

        # Check pkgdev
        if self.has_pkgdev:
            self._success("pkgdev available")
            return True

        self._warn("pkgcheck/pkgdev not available - using basic validation only")
        self._success("Basic requirements satisfied")
        return False

    def check_overlay_structure(self) -> bool:
        """Validate basic overlay structure."""
        self._log("Checking overlay structure...")

        # Check for essential files
        essential_files = ["metadata/layout.conf", "profiles/repo_name"]

        missing_files = []
        for file_path in essential_files:
            if not (self.overlay_root / file_path).exists():
                missing_files.append(file_path)

        if missing_files:
            self._error(f"Missing essential overlay files: {', '.join(missing_files)}")
            return False

        # Check for ebuilds
        ebuilds = list(self.overlay_root.glob("**/*.ebuild"))
        if not ebuilds:
            self._error("No ebuilds found in overlay")
            return False

        self._success(f"Found {len(ebuilds)} ebuilds in overlay")

        # Check for categories
        categories = [
            d.name
            for d in self.overlay_root.iterdir()
            if d.is_dir()
            and not d.name.startswith(".")
            and d.name not in ["metadata", "profiles", "scripts", "files"]
        ]

        if not categories:
            self._error("No package categories found")
            return False

        self._success(f"Found categories: {', '.join(sorted(categories))}")
        return True

    def run_pkgcheck_scan(self) -> Tuple[bool, int, int]:
        """Run pkgcheck scan and return results."""
        self._log("Running pkgcheck scan...")

        if not self.has_pkgcheck:
            self._error("pkgcheck not available")
            return False, 0, 0

        # Prepare command
        cmd = [
            "pkgcheck",
            "scan",
            "--config",
            str(self.config_file),
            "--reporter",
            "JsonReporter",
            str(self.overlay_root),
        ]

        # Run pkgcheck with JSON output
        json_output_file = self.reports_dir / "pkgcheck-scan.json"
        txt_output_file = self.reports_dir / "pkgcheck-scan.txt"

        try:
            # Run with JSON output
            self._log(f"Running: {' '.join(cmd)}")
            result = subprocess.run(
                cmd, capture_output=True, text=True, cwd=self.overlay_root
            )

            # Save JSON output
            with open(json_output_file, "w") as f:
                f.write(result.stdout)

            # Also run with text output for readability
            cmd_txt = cmd[:-1] + ["--reporter", "StrReporter", str(self.overlay_root)]
            result_txt = subprocess.run(
                cmd_txt, capture_output=True, text=True, cwd=self.overlay_root
            )

            with open(txt_output_file, "w") as f:
                f.write(result_txt.stdout)

            # Parse results
            errors = warnings = 0
            try:
                if result.stdout.strip():
                    data = json.loads(result.stdout)
                    for item in data:
                        level = item.get("level", "").lower()
                        if level == "error":
                            errors += 1
                        elif level == "warning":
                            warnings += 1
            except json.JSONDecodeError:
                # Fallback to text parsing
                error_count = result_txt.stdout.count("ERROR")
                warning_count = result_txt.stdout.count("WARNING")
                errors = max(errors, error_count)
                warnings = max(warnings, warning_count)

            success = result.returncode == 0
            if success:
                self._success(
                    f"pkgcheck completed: {errors} errors, {warnings} warnings"
                )
            else:
                self._warn(
                    f"pkgcheck completed with issues: {errors} errors, {warnings} warnings"
                )

            return success, errors, warnings

        except subprocess.CalledProcessError as e:
            self._error(f"pkgcheck failed: {e}")
            return False, 0, 0
        except Exception as e:
            self._error(f"Unexpected error running pkgcheck: {e}")
            return False, 0, 0

    def run_pkgdev_manifest(self) -> bool:
        """Run pkgdev manifest to check manifest integrity."""
        self._log("Checking manifest integrity...")

        if not self.has_pkgdev:
            self._warn("pkgdev not available - skipping manifest check")
            return True

        try:
            # pkgdev manifest validates manifests by default when run without --update
            cmd = ["pkgdev", "manifest", str(self.overlay_root)]
            self._log(f"Running: {' '.join(cmd)}")

            result = subprocess.run(
                cmd, capture_output=True, text=True, cwd=self.overlay_root
            )

            # Save output
            manifest_output_file = self.reports_dir / "manifest-check.txt"
            with open(manifest_output_file, "w") as f:
                if result.stdout:
                    f.write(result.stdout)
                if result.stderr:
                    f.write("\n=== STDERR ===\n")
                    f.write(result.stderr)
                if not result.stdout and not result.stderr:
                    f.write("No manifest issues found\n")

            if result.returncode == 0:
                self._success("Manifest check passed")
                return True
            else:
                self._warn(
                    f"Manifest check found issues (exit code: {result.returncode})"
                )
                return False

        except subprocess.CalledProcessError as e:
            self._error(f"pkgdev manifest failed: {e}")
            return False
        except Exception as e:
            self._error(f"Unexpected error running pkgdev manifest: {e}")
            return False

    def run_basic_checks(self) -> Tuple[bool, int, int]:
        """Run basic validation checks when modern tools aren't available."""
        self._log("Running basic validation checks...")

        issues = []
        errors = warnings = 0

        # Check for missing Manifest files
        self._log("Checking for missing Manifest files...")
        categories = [
            d
            for d in self.overlay_root.iterdir()
            if d.is_dir()
            and not d.name.startswith(".")
            and d.name not in ["metadata", "profiles", "scripts", "files"]
        ]

        for category in categories:
            for package_dir in category.iterdir():
                if package_dir.is_dir():
                    manifest_file = package_dir / "Manifest"
                    if not manifest_file.exists():
                        issues.append(
                            f"ERROR: {package_dir.relative_to(self.overlay_root)}: Missing Manifest"
                        )
                        errors += 1

        # Check for missing metadata.xml files
        self._log("Checking for missing metadata.xml files...")
        for category in categories:
            for package_dir in category.iterdir():
                if package_dir.is_dir():
                    metadata_file = package_dir / "metadata.xml"
                    if not metadata_file.exists():
                        issues.append(
                            f"WARN: {package_dir.relative_to(self.overlay_root)}: Missing metadata.xml"
                        )
                        warnings += 1

        # Check for .ebuild files with basic validation
        self._log("Checking ebuild files...")
        ebuilds = list(self.overlay_root.glob("**/*.ebuild"))

        for ebuild in ebuilds:
            try:
                with open(ebuild, "r") as f:
                    content = f.read()

                # Basic checks
                if not content.strip():
                    issues.append(
                        f"ERROR: {ebuild.relative_to(self.overlay_root)}: Empty ebuild"
                    )
                    errors += 1
                elif "EAPI=" not in content and 'EAPI"=' not in content:
                    issues.append(
                        f"WARN: {ebuild.relative_to(self.overlay_root)}: No EAPI specified"
                    )
                    warnings += 1

            except Exception as e:
                issues.append(
                    f"ERROR: {ebuild.relative_to(self.overlay_root)}: Failed to read - {e}"
                )
                errors += 1

        # Save results
        basic_output_file = self.reports_dir / "basic-qa.txt"
        with open(basic_output_file, "w") as f:
            f.write("=== Basic QA Check Results ===\n")
            f.write(f"Checked {len(ebuilds)} ebuilds in overlay\n")
            f.write(f"Found {errors} ERROR(s) and {warnings} WARNING(s)\n\n")

            if issues:
                f.write("Issues found:\n")
                for issue in issues:
                    f.write(f"{issue}\n")
            else:
                f.write("No issues found!\n")

        success = errors == 0
        if success:
            self._success(
                f"Basic checks completed: {errors} errors, {warnings} warnings"
            )
        else:
            self._warn(
                f"Basic checks found issues: {errors} errors, {warnings} warnings"
            )

        return success, errors, warnings

    def run_full_qa_check(self) -> bool:
        """Run complete QA check suite."""
        self._log("=== Starting COSMIC Overlay QA Check ===")

        # Check requirements
        has_modern_tools = self.check_requirements()

        # Check overlay structure
        if not self.check_overlay_structure():
            self._error("Overlay structure validation failed")
            return False

        overall_success = True
        total_errors = total_warnings = 0

        # Run appropriate QA checks
        if has_modern_tools:
            # Run pkgcheck
            pkgcheck_success, errors, warnings = self.run_pkgcheck_scan()
            total_errors += errors
            total_warnings += warnings
            overall_success = overall_success and pkgcheck_success

            # Run manifest check
            manifest_success = self.run_pkgdev_manifest()
            overall_success = overall_success and manifest_success
        else:
            # Run basic checks
            basic_success, errors, warnings = self.run_basic_checks()
            total_errors += errors
            total_warnings += warnings
            overall_success = overall_success and basic_success

        # Generate reports
        self._log("Generating reports...")
        try:
            # Try running the report generator as subprocess
            report_script = self.overlay_root / "scripts" / "generate-qa-report.py"
            if report_script.exists():
                subprocess.run(
                    [
                        sys.executable,
                        str(report_script),
                        "--overlay-root",
                        str(self.overlay_root),
                        "--reports-dir",
                        str(self.reports_dir),
                    ],
                    check=True,
                )
                self._success("Reports generated successfully")
            else:
                self._warn("Report generator not found - skipping report generation")
        except subprocess.CalledProcessError:
            self._warn("Failed to generate reports")
        except Exception as e:
            self._warn(f"Error generating reports: {e}")

        # Summary
        self._log("=== QA Check Summary ===")
        if overall_success:
            self._success(f"QA check completed successfully")
        else:
            self._warn(f"QA check completed with issues")

        self._log(f"Total errors: {total_errors}")
        self._log(f"Total warnings: {total_warnings}")
        self._log(f"Reports saved to: {self.reports_dir}")

        return overall_success


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="Simple QA checker for COSMIC overlay")
    parser.add_argument(
        "--overlay-root",
        default=Path(__file__).parent.parent,
        help="Path to overlay root directory",
    )
    parser.add_argument(
        "--reports-dir",
        default=Path(__file__).parent.parent / "qa-reports",
        help="Directory to store generated reports",
    )
    parser.add_argument("--config", help="Path to pkgcheck configuration file")
    parser.add_argument(
        "--quiet", "-q", action="store_true", help="Suppress non-error output"
    )

    args = parser.parse_args()

    # Redirect stdout if quiet mode
    if args.quiet:
        import io

        original_stdout = sys.stdout
        sys.stdout = io.StringIO()

    try:
        checker = SimpleQAChecker(args.overlay_root, args.reports_dir, args.config)
        success = checker.run_full_qa_check()

        # Restore stdout and print final result
        if args.quiet:
            sys.stdout = original_stdout
            if success:
                print("✅ QA check passed")
            else:
                print("❌ QA check failed")

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        if args.quiet:
            sys.stdout = original_stdout
        print("\n⚠️  QA check interrupted by user")
        sys.exit(130)
    except Exception as e:
        if args.quiet:
            sys.stdout = original_stdout
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
