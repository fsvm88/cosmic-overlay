#!/usr/bin/env python3

"""
Simple Local QA Runner - pkgcheck-based overlay validation

This script provides comprehensive QA checks using modern Gentoo tools
and generates reports in the qa-reports directory.
"""

import json
import os
import shutil
import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
import subprocess
from datetime import datetime
import io
import fnmatch


class SimpleQAChecker:
    def _escape_html(self, text: str) -> str:
        import html

        return html.escape(text)

    def _get_commit_sha(self) -> Optional[str]:
        try:
            result = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                cwd=self.overlay_root,
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return None

    def _msg(self, message: str, prefix: str = "QA") -> None:
        print(f"[{prefix}] {message}")

    def _log(self, message: str) -> None:
        self._msg(message, "QA")

    def _error(self, message: str) -> None:
        self._msg(message, "ERROR")

    def _success(self, message: str) -> None:
        self._msg(message, "SUCCESS")

    def __init__(
        self, overlay_root: str, reports_dir: str, config: Optional[str] = None
    ) -> None:
        self.overlay_root: Path = Path(overlay_root)
        # Always use qa-reports subfolder from current working directory
        self.reports_dir: Path = Path.cwd() / "qa-reports"
        # Search for pkgcheck.conf in order: script folder, parent folder, cwd, system default
        self.config: Optional[Path] = self._find_config(config)
        self.has_portage: bool = self._which("emerge")
        self.has_pkgcheck: bool = self._which("pkgcheck")
        self.has_pkgdev: bool = self._which("pkgdev")

    def _find_config(self, config: Optional[str]) -> Optional[Path]:
        if config:
            return Path(config)
        search_paths: List[Path] = [
            Path(__file__).parent / "pkgcheck.conf",
            Path(__file__).parent.parent / "pkgcheck.conf",
            Path.cwd() / "pkgcheck.conf",
            Path("/etc/pkgcheck.conf"),
        ]
        for conf_path in search_paths:
            if conf_path.exists():
                return conf_path
        return None

    def _which(self, tool: str) -> bool:
        for path in os.environ.get("PATH", "").split(os.pathsep):
            if os.access(os.path.join(path, tool), os.X_OK):
                return True
        return False

    def parse_qaignore(self, ignore_path: Path) -> List[Dict[str, Optional[str]]]:
        rules: List[Dict[str, Optional[str]]] = []
        if not ignore_path.exists():
            return rules
        with open(ignore_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts: List[str] = line.split()
                if len(parts) < 2:
                    continue
                atom_ver, check = parts[0], parts[1]
                atom, ver = (
                    (atom_ver.split(":", 1) + [None])[:2]
                    if ":" in atom_ver
                    else (atom_ver, None)
                )
                rules.append({"atom": atom, "ver": ver, "check": check})
        return rules

    def should_ignore(
        self,
        atom: str,
        ver: Optional[str],
        check: str,
        rules: List[Dict[str, Optional[str]]],
    ) -> bool:
        for rule in rules:
            if not self._fnmatch(atom, rule["atom"]):
                continue
            if rule["ver"] and rule["ver"] != ver:
                continue
            if rule["check"] != "*" and rule["check"] != check:
                continue
            return True
        return False

    def _fnmatch(self, value: str, pattern: Optional[str]) -> bool:
        if pattern is None:
            return False
        if pattern == "*":
            return True
        if pattern.endswith("*"):
            return value.startswith(pattern[:-1])
        return value == pattern

    def parse_qatolerate(self, tolerate_path: Path) -> List[Dict[str, Optional[str]]]:
        rules: List[Dict[str, Optional[str]]] = []
        if not tolerate_path.exists():
            return rules
        with open(tolerate_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts: List[str] = line.split()
                if len(parts) < 2:
                    continue
                atom_ver, check = parts[0], parts[1]
                atom, ver = (
                    (atom_ver.split(":", 1) + [None])[:2]
                    if ":" in atom_ver
                    else (atom_ver, None)
                )
                rules.append({"atom": atom, "ver": ver, "check": check})
        return rules

    def should_tolerate(
        self,
        atom: str,
        ver: Optional[str],
        check: str,
        rules: List[Dict[str, Optional[str]]],
    ) -> bool:
        for rule in rules:
            if not self._fnmatch(atom, rule["atom"]):
                continue
            if rule["ver"] and rule["ver"] != ver:
                continue
            if rule["check"] != "*" and rule["check"] != check:
                continue
            return True
        return False

    def filter_issues_with_qaignore_and_qatolerate(
        self, issues: List[Dict[str, Any]]
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        ignore_path: Path = Path.cwd() / ".qaignore"
        tolerate_path: Path = Path.cwd() / ".qatolerate"
        ignore_rules: List[Dict[str, Optional[str]]] = self.parse_qaignore(ignore_path)
        tolerate_rules: List[Dict[str, Optional[str]]] = self.parse_qatolerate(
            tolerate_path
        )
        filtered: List[Dict[str, Any]] = []
        tolerated: List[Dict[str, Any]] = []
        for issue in issues:
            atom: str = issue.get("atom", "")
            ver: Optional[str] = issue.get("version")
            check: str = issue.get("check", "")
            if self.should_ignore(atom, ver, check, ignore_rules):
                continue
            if self.should_tolerate(atom, ver, check, tolerate_rules):
                tolerated.append(issue)
            else:
                filtered.append(issue)
        return filtered, tolerated

    def _get_package_issues(self) -> List[Dict[str, str]]:
        """Parse package issues from QA output files and filter with .qaignore."""
        issues: List[Dict[str, str]] = []
        # Only parse pkgcheck-scan.txt for package issues
        filename = "pkgcheck-scan.txt"
        filepath = self.reports_dir / filename
        if filepath.exists():
            try:
                with open(filepath) as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        match = re.match(
                            r"^([^:]+):\s*(ERROR|WARNING|INFO|STYLE):\s*(.+)$",
                            line,
                        )
                        if match:
                            # Try to extract check name from message
                            msg = match.group(3)
                            check_match = re.match(r"([A-Za-z0-9_]+):", msg)
                            check = check_match.group(1) if check_match else ""
                            issues.append(
                                {
                                    "package": match.group(1),
                                    "level": match.group(2).lower(),
                                    "message": msg,
                                    "tool": "pkgcheck",
                                    "check": check,
                                    "atom": match.group(1),
                                    "version": None,
                                }
                            )
                filtered, tolerated = self.filter_issues_with_qaignore_and_qatolerate(
                    issues
                )
                # Return both, but mark tolerated issues
                for issue in tolerated:
                    issue["tolerated"] = True
                for issue in filtered:
                    issue["tolerated"] = False
                return filtered + tolerated
            except IOError:
                pass
        return issues

    def check_requirements(self) -> bool:
        """Check if required tools are available."""
        self._log("Checking requirements...")

        # Check basic tools
        basic_tools = ["find", "grep", "awk", "sed"]
        for tool in basic_tools:
            if not self._which(tool):
                self._error(f"Missing required tool: {tool}")
                return False

        # Check Portage tools
        if self.has_portage:
            self._success("Portage tools available")
        else:
            self._log("Portage tools not available - some checks may be limited")

        # Check pkgcheck and pkgdev
        if self.has_pkgcheck and self.has_pkgdev:
            self._success("pkgcheck and pkgdev available")
        else:
            self._log("pkgcheck/pkgdev not available - using basic validation only")

        # All checks passed
        return True

    def generate_markdown_report(self) -> None:
        output_path = self.reports_dir / "report.md"
        commit_sha = self._get_commit_sha()
        commit_sha_short = commit_sha[:8] if commit_sha else "unknown"
        workflow = os.environ.get("GITHUB_WORKFLOW", "Manual")
        report_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
        (
            total_issues,
            errors,
            warnings,
            info,
            style,
            qa_tool,
            ignored_errors,
            ignored_warnings,
            ignored_info,
            ignored_style,
            ignored_total,
            tolerated_errors,
            tolerated_warnings,
            tolerated_info,
            tolerated_style,
            tolerated_total,
        ) = self.get_qa_results()
        content = f"""# 🚀 COSMIC Overlay QA Report

**Generated:** {report_date}  
**Commit:** `{commit_sha_short}`  
**Workflow:** {workflow}  
**QA Tool:** {qa_tool}

## Status: {'❌ FAILED' if errors > 0 else '⚠️ WARNINGS' if warnings > 0 else '✅ PASSED'}

### 📊 Summary

- **Total Issues:** {total_issues} [{ignored_total} ignored, {tolerated_total} tolerated]
- **Errors:** {errors} [{ignored_errors} ignored, {tolerated_errors} tolerated]
- **Warnings:** {warnings} [{ignored_warnings} ignored, {tolerated_warnings} tolerated]"""
        if (
            style > 0
            or ignored_info > 0
            or ignored_style > 0
            or tolerated_info > 0
            or tolerated_style > 0
        ):
            content += f"\n- **Info:** {info} [{ignored_info} ignored, {tolerated_info} tolerated]\n- **Style:** {style} [{ignored_style} ignored, {tolerated_style} tolerated]"
        content += """

---

## 📋 Detailed Results

### QA Scan Output

```
"""
        for filename in ["pkgcheck-scan.txt", "repoman-full.txt", "basic-qa.txt"]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                try:
                    with open(filepath) as f:
                        content += f.read()
                    break
                except IOError:
                    continue
        else:
            content += f"No detailed QA output available\nChecked {len(list(self.overlay_root.glob('**/*.ebuild')))} ebuilds in overlay\n"
        content += """
```

### Package Checks

```
"""
        for filename in ["package-checks.txt", "category-checks.txt"]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                try:
                    with open(filepath) as f:
                        content += f.read()
                    break
                except IOError:
                    continue
        else:
            content += "No package checks output available"
        content += """
```

## 📊 Package Statistics

"""
        for category in [
            "cosmic-base",
            "acct-group",
            "acct-user",
            "dev-util",
            "virtual",
            "x11-themes",
        ]:
            category_path = self.overlay_root / category
            if category_path.is_dir():
                pkg_count = len([d for d in category_path.iterdir() if d.is_dir()])
                content += f"- **{category}/:** {pkg_count} packages\n"
        content += """

## 📄 Files Checked

"""
        ebuilds = sorted(self.overlay_root.glob("**/*.ebuild"))
        for ebuild in ebuilds:
            rel_path = ebuild.relative_to(self.overlay_root)
            content += f"- `{rel_path}`\n"
        with open(output_path, "w") as f:
            f.write(content)
        self._log(f"Markdown report generated: {output_path}")

    def generate_html_report(self) -> None:
        output_path = self.reports_dir / "index.html"
        commit_sha = self._get_commit_sha()
        commit_sha_short = commit_sha[:8] if commit_sha else "unknown"
        workflow = os.environ.get("GITHUB_WORKFLOW", "Manual")
        report_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
        (
            total_issues,
            errors,
            warnings,
            info,
            style,
            qa_tool,
            ignored_errors,
            ignored_warnings,
            ignored_info,
            ignored_style,
            ignored_total,
            tolerated_errors,
            tolerated_warnings,
            tolerated_info,
            tolerated_style,
            tolerated_total,
        ) = self.get_qa_results()
        package_issues = self._get_package_issues()
        status_text = (
            "FAILED" if errors > 0 else "WARNINGS" if warnings > 0 else "PASSED"
        )
        status_class = (
            "status-error"
            if errors > 0
            else "status-warning" if warnings > 0 else "status-success"
        )
        status_icon = "❌" if errors > 0 else "⚠️" if warnings > 0 else "✅"
        html_content = f"""<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>COSMIC Overlay QA Report</title>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; margin: 2em; background: #f8f9fa; }}
        h1, h2, h3 {{ color: #2d3748; }}
        pre {{ background: #eee; padding: 1em; border-radius: 6px; }}
        code {{ background: #e2e8f0; padding: 2px 4px; border-radius: 4px; }}
        .status {{ font-size: 1.2em; margin-bottom: 1em; }}
        .summary {{ background: #e6fffa; border-left: 4px solid #38b2ac; padding: 1em; margin-bottom: 2em; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; background: white; box-shadow: 0 0 10px rgba(0,0,0,0.1); min-height: 100vh; }}
        .stat-card {{ background: #fff; border: 1px solid #dee2e6; border-radius: 8px; padding: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .stat-number {{ font-size: 2em; font-weight: bold; color: #2c3e50; }}
        .stat-label {{ color: #7f8c8d; font-size: 0.9em; margin-top: 5px; }}
        .issues-table {{ width: 100%; border-collapse: collapse; margin: 20px 0; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .issues-table th, .issues-table td {{ padding: 12px 15px; text-align: left; border-bottom: 1px solid #dee2e6; }}
        .issues-table th {{ background: #f8f9fa; font-weight: 600; color: #495057; position: sticky; top: 0; }}
        .issues-table tbody tr:hover {{ background: #f8f9fa; }}
        .level-error {{ color: #dc3545; font-weight: bold; }}
        .level-warning {{ color: #fd7e14; font-weight: bold; }}
        .level-info {{ color: #17a2b8; }}
        .level-style {{ color: #6f42c1; }}
        .package-name {{ font-family: 'Consolas', 'Monaco', monospace; background: #f8f9fa; padding: 4px 8px; border-radius: 4px; font-size: 0.9em; }}
        .message {{ max-width: 400px; word-wrap: break-word; }}
        .output-section {{ background: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; margin: 20px 0; overflow-x: auto; }}
        .output-content {{ font-family: 'Consolas', 'Monaco', monospace; font-size: 0.9em; line-height: 1.4; white-space: pre-wrap; }}
        .error-text {{ color: #dc3545; font-weight: bold; }}
        .warning-text {{ color: #fd7e14; font-weight: bold; }}
        .info-text {{ color: #17a2b8; }}
        .file-list {{ columns: 1; column-gap: 30px; list-style: none; }}
        .file-list li {{ break-inside: avoid; margin: 5px 0; font-family: 'Consolas', 'Monaco', monospace; font-size: 0.9em; background: #f8f9fa; padding: 4px 8px; border-radius: 4px; }}
        footer {{ margin-top: 40px; padding-top: 20px; border-top: 1px solid #dee2e6; text-align: center; color: #6c757d; font-size: 0.9em; }}
        footer a {{ color: #007bff; text-decoration: none; }}
        footer a:hover {{ text-decoration: underline; }}
    </style>
</head>
<body>
    <div class='container'>
        <h1>🚀 COSMIC Overlay QA Report</h1>
        <div class='meta'>
            <strong>Generated:</strong> {report_date}<br>
            <strong>Commit:</strong> <code>{commit_sha_short}</code><br>
            <strong>Workflow:</strong> {workflow}<br>
            <strong>QA Tool:</strong> {qa_tool}
        </div>
        <div class='status {status_class}'>
            {status_icon} {status_text}
        </div>
        <div class='stats-row' style='margin: 1em 0; font-size: 1.1em;'>
            <strong>Total Issues:</strong> {total_issues} &nbsp;|
            <strong>Errors:</strong> {errors} &nbsp;|
            <strong>Warnings:</strong> {warnings}
            {f'| <strong>Info:</strong> {info} | <strong>Style:</strong> {style}' if style > 0 else ''}
            <br><span style='font-size:0.9em;'>[{ignored_total} ignored, {tolerated_total} tolerated]</span>
        </div>
        <h2>📋 Detailed Results</h2>"""
        if package_issues:
            html_content += """
        <h3>Package Issues</h3>
        <table class='issues-table'>
            <thead><tr><th>Package</th><th>Level</th><th>Message</th><th>Tool</th></tr></thead><tbody>"""
            for issue in package_issues:
                level_class = f"level-{issue['level']}"
                html_content += f"<tr><td><span class='package-name'>{self._escape_html(issue['package'])}</span></td><td><span class='{level_class}'>{issue['level'].upper()}</span></td><td class='message'>{self._escape_html(issue['message'])}</td><td>{issue['tool']}</td></tr>"
            html_content += """
            </tbody></table>"""
        html_content += """
        <h3>QA Scan Output</h3>
        <div class='output-section'>"""
        scan_json_path = self.reports_dir / "pkgcheck-scan.json"
        rows: List[Tuple[str, str, str, str, str, str]] = []
        if scan_json_path.exists():
            with open(scan_json_path) as f:
                scan_lines = f.readlines()
            for line in scan_lines:
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                if not isinstance(entry, dict):
                    continue
                for cat, pkgs in entry.items():
                    if not isinstance(pkgs, dict):
                        continue
                    for pkg, vers in pkgs.items():
                        if not isinstance(vers, dict):
                            continue
                        for ver, issues in vers.items():
                            if not isinstance(issues, dict):
                                continue
                            for level, checks in issues.items():
                                if not isinstance(checks, dict):
                                    continue
                                for check, msg in checks.items():
                                    rows.append((cat, pkg, ver, level[1:], check, msg))
        # Filter rows using .qaignore rules
        ignore_path = Path.cwd() / ".qaignore"
        rules = self.parse_qaignore(ignore_path)
        filtered_rows: List[Tuple[str, str, str, str, str, str]] = []
        for cat, pkg, ver, level, check, msg in rows:
            atom = f"{cat}/{pkg}"
            if not self.should_ignore(atom, ver, check, rules):
                filtered_rows.append((cat, pkg, ver, level, check, msg))
        if filtered_rows:
            html_content += "<table class='issues-table'><thead><tr><th>Category</th><th>Package</th><th>Version</th><th>Level</th><th>Check</th><th>Message</th></tr></thead><tbody>"
            for cat, pkg, ver, level, check, msg in filtered_rows:
                html_content += f"<tr><td>{self._escape_html(cat)}</td><td>{self._escape_html(pkg)}</td><td>{self._escape_html(ver)}</td><td class='level-{level}'>{level.capitalize()}</td><td>{self._escape_html(check)}</td><td class='message'>{self._escape_html(msg)}</td></tr>"
            html_content += "</tbody></table>"
        else:
            html_content += (
                "<div class='output-content'>No detailed QA scan output available</div>"
            )
        html_content += """
        </div>"""
        html_content += """
        <h3>Package Checks</h3>
        <div class='output-section'><div class='output-content'>"""
        package_output = ""
        for filename in ["package-checks.txt", "category-checks.txt"]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                try:
                    with open(filepath) as f:
                        package_output = f.read()
                    break
                except IOError:
                    continue
        if not package_output:
            package_output = "No package checks output available"
        html_content += self._escape_html(package_output)
        html_content += """
            </div></div>
        <h2>📊 Package Statistics</h2><ul>"""
        for category in [
            "cosmic-base",
            "acct-group",
            "acct-user",
            "dev-util",
            "virtual",
            "x11-themes",
        ]:
            category_path = self.overlay_root / category
            if category_path.is_dir():
                pkg_count = len([d for d in category_path.iterdir() if d.is_dir()])
                html_content += (
                    f"<li><strong>{category}/:</strong> {pkg_count} packages</li>\n"
                )
        html_content += """
        </ul>
        <h2>📄 Files Checked</h2><ul class='file-list'>"""
        ebuilds = sorted(self.overlay_root.glob("**/*.ebuild"))
        for ebuild in ebuilds:
            rel_path = ebuild.relative_to(self.overlay_root)
            html_content += f"<li>{rel_path}</li>\n"
        html_content += f"""
        </ul>
        <footer>
            Generated by COSMIC Overlay QA Pipeline • 
            <a href='https://github.com/fsvm88/cosmic-overlay'>View Repository</a>
        </footer>
    </div>
</body>
</html>"""
        with open(output_path, "w") as f:
            f.write(html_content)
        self._log(f"HTML report generated: {output_path}")

    def generate_reports_readme(self) -> None:
        report_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
        readme_content = f"""# QA Reports

This directory contains automatically generated QA reports for the COSMIC overlay.

## Files

- `index.html` - Main HTML report (open in browser)
- `report.md` - Detailed Markdown report

## Generated

{report_date}
"""
        with open(self.reports_dir / "README.md", "w") as f:
            f.write(readme_content)
        self._log("Reports README generated")

    def check_overlay_structure(self) -> bool:
        """Validate basic overlay structure."""
        self._log("Checking overlay structure...")
        # Check for essential files
        essential_files: List[str] = ["metadata/layout.conf", "profiles/repo_name"]
        missing_files: List[str] = [
            f for f in essential_files if not (self.overlay_root / f).exists()
        ]
        if missing_files:
            self._error(f"Missing essential overlay files: {', '.join(missing_files)}")
            return False
        # Check for ebuilds
        ebuilds: List[Path] = list(self.overlay_root.glob("**/*.ebuild"))
        if not ebuilds:
            self._error("No ebuilds found in overlay")
            return False
        self._success(f"Found {len(ebuilds)} ebuilds in overlay")
        # Check for categories
        categories: List[str] = [
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
        cmd = [
            "pkgcheck",
            "scan",
            "--config",
            str(self.config) if self.config else "",
            "--reporter",
            "JsonReporter",
            str(self.overlay_root),
        ]
        json_output_file = self.reports_dir / "pkgcheck-scan.json"
        try:
            self._log(f"Running: {' '.join(cmd)}")
            result = subprocess.run(
                cmd, capture_output=True, text=True, cwd=self.overlay_root
            )
            with open(json_output_file, "w") as f:
                f.write(result.stdout)
            # Also run with text output for readability
            cmd_txt = cmd[:-1] + ["--reporter", "StrReporter", str(self.overlay_root)]
            result_txt = subprocess.run(
                cmd_txt, capture_output=True, text=True, cwd=self.overlay_root
            )
            txt_output_file = self.reports_dir / "pkgcheck-scan.txt"
            with open(txt_output_file, "w") as f:
                f.write(result_txt.stdout)
            # Save raw pkgcheck output for debugging config usage
            debug_output_file = self.reports_dir / "pkgcheck-debug.txt"
            with open(debug_output_file, "w") as f:
                f.write(result.stdout)
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
                self._log(
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
            self._log("pkgdev not available - skipping manifest check")
            return True
        try:
            cmd = ["pkgdev", "manifest", str(self.overlay_root)]
            self._log(f"Running: {' '.join(cmd)}")
            result = subprocess.run(
                cmd, capture_output=True, text=True, cwd=self.overlay_root
            )
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
                self._log(
                    f"Manifest check found issues (exit code: {result.returncode})"
                )
                return False
        except subprocess.CalledProcessError as e:
            self._error(f"pkgdev manifest failed: {e}")
            return False
        except Exception as e:
            self._error(f"Unexpected error running pkgdev manifest: {e}")
            return False

    def get_qa_results(
        self,
    ) -> Tuple[int, int, int, int, int, str, int, int, int, int, int]:
        """Parse QA results and return counts, including ignored counts."""
        total_issues: int = 0
        errors: int = 0
        warnings: int = 0
        info: int = 0
        style: int = 0
        ignored_errors: int = 0
        ignored_warnings: int = 0
        ignored_info: int = 0
        ignored_style: int = 0
        tolerated_errors: int = 0
        tolerated_warnings: int = 0
        tolerated_info: int = 0
        tolerated_style: int = 0
        qa_tool: str = "basic"
        pkgcheck_json: Path = self.reports_dir / "pkgcheck-scan.json"
        all_results: List[Dict[str, Any]] = []
        if pkgcheck_json.exists():
            with open(pkgcheck_json) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry: Dict[str, Any] = eval(line, {}, {})
                    except Exception:
                        continue
                    for cat, pkgs in entry.items():
                        if not isinstance(pkgs, dict):
                            continue
                        for pkg, vers in pkgs.items():
                            if not isinstance(vers, dict):
                                continue
                            for ver, levels in vers.items():
                                if not isinstance(levels, dict):
                                    continue
                                for level_key, checks in levels.items():
                                    level: str = level_key.lstrip("_")
                                    if not isinstance(checks, dict):
                                        continue
                                    for check, msg in checks.items():
                                        all_results.append(
                                            {
                                                "atom": f"{cat}/{pkg}",
                                                "version": ver,
                                                "check": check,
                                                "level": level,
                                                "message": msg,
                                            }
                                        )
        ignore_path: Path = Path.cwd() / ".qaignore"
        tolerate_path: Path = Path.cwd() / ".qatolerate"
        ignore_rules: List[Dict[str, Optional[str]]] = self.parse_qaignore(ignore_path)
        tolerate_rules: List[Dict[str, Optional[str]]] = self.parse_qatolerate(
            tolerate_path
        )
        for result in all_results:
            atom, ver, check, level = (
                result["atom"],
                result["version"],
                result["check"],
                result["level"].lower(),
            )
            ignored: bool = self.should_ignore(atom, ver, check, ignore_rules)
            tolerated: bool = self.should_tolerate(atom, ver, check, tolerate_rules)
            if level == "error":
                if ignored:
                    ignored_errors += 1
                elif tolerated:
                    tolerated_errors += 1
                else:
                    errors += 1
            elif level == "warning":
                if ignored:
                    ignored_warnings += 1
                elif tolerated:
                    tolerated_warnings += 1
                else:
                    warnings += 1
            elif level == "info":
                if ignored:
                    ignored_info += 1
                elif tolerated:
                    tolerated_info += 1
                else:
                    info += 1
            elif level == "style":
                if ignored:
                    ignored_style += 1
                elif tolerated:
                    tolerated_style += 1
                else:
                    style += 1
        total_issues = errors + warnings + info + style
        ignored_total = ignored_errors + ignored_warnings + ignored_info + ignored_style
        tolerated_total = (
            tolerated_errors + tolerated_warnings + tolerated_info + tolerated_style
        )
        # Only errors/warnings not ignored/tolerated cause failure
        return (
            total_issues,
            errors,
            warnings,
            info,
            style,
            qa_tool,
            ignored_errors,
            ignored_warnings,
            ignored_info,
            ignored_style,
            ignored_total,
            tolerated_errors,
            tolerated_warnings,
            tolerated_info,
            tolerated_style,
            tolerated_total,
        )

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

        # Directly generate reports
        self._log("Generating reports...")
        self.generate_markdown_report()
        self.generate_html_report()
        self.generate_reports_readme()
        self._success("Reports generated successfully")
        # Print summary to stdout
        (
            total_issues,
            errors,
            warnings,
            info,
            style,
            qa_tool,
            ignored_errors,
            ignored_warnings,
            ignored_info,
            ignored_style,
            ignored_total,
            tolerated_errors,
            tolerated_warnings,
            tolerated_info,
            tolerated_style,
            tolerated_total,
        ) = self.get_qa_results()
        print()
        print("📊 QA Report Summary:")
        print(f"   Tool: {qa_tool}")
        print(
            f"   Total Issues: {total_issues} [{ignored_total} ignored, {tolerated_total} tolerated]"
        )
        print(
            f"   Errors: {errors} [{ignored_errors} ignored, {tolerated_errors} tolerated]"
        )
        print(
            f"   Warnings: {warnings} [{ignored_warnings} ignored, {tolerated_warnings} tolerated]"
        )
        if (
            style > 0
            or ignored_info > 0
            or ignored_style > 0
            or tolerated_info > 0
            or tolerated_style > 0
        ):
            print(
                f"   Info: {info} [{ignored_info} ignored, {tolerated_info} tolerated]"
            )
            print(
                f"   Style: {style} [{ignored_style} ignored, {tolerated_style} tolerated]"
            )
        print(f"   Reports: {self.reports_dir}")
        print()
        # Only fail if errors/warnings not ignored/tolerated
        return errors == 0 and warnings == 0

    def run_basic_checks(self) -> Tuple[bool, int, int]:
        """Run basic QA checks (find, grep, awk, sed) and return results."""
        self._log("Running basic checks...")
        errors = warnings = 0
        # Example basic check: find ebuilds with missing SRC_URI
        try:
            for ebuild in self.overlay_root.glob("**/*.ebuild"):
                with open(ebuild) as f:
                    content = f.read()
                if "SRC_URI=" not in content:
                    errors += 1
                    self._error(f"Missing SRC_URI in {ebuild}")
        except Exception as e:
            self._error(f"Error running basic checks: {e}")
            return False, 0, 0
        return True, errors, warnings


def ensure_reports_dir(reports_dir: str) -> None:
    if not os.path.exists(reports_dir):
        os.makedirs(reports_dir)


def main() -> None:
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

    reports_dir: str = str(args.reports_dir)
    ensure_reports_dir(reports_dir)

    # Redirect stdout if quiet mode
    if args.quiet:
        import io

        original_stdout = sys.stdout
        sys.stdout = io.StringIO()

    try:
        checker: SimpleQAChecker = SimpleQAChecker(
            str(args.overlay_root), reports_dir, args.config
        )
        success: bool = checker.run_full_qa_check()

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
