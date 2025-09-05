#!/usr/bin/env python3

"""
COSMIC Overlay QA Report Generator

Generates comprehensive QA reports in both Markdown and HTML formats
from pkgcheck/repoman scan results.
"""

import argparse
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class QAReportGenerator:
    """Generates QA reports for COSMIC overlay."""

    def __init__(self, overlay_root: str, reports_dir: str):
        self.overlay_root = Path(overlay_root).resolve()
        self.reports_dir = Path(reports_dir).resolve()
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Metadata for report
        self.report_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
        self.commit_sha = self._get_commit_sha()
        self.commit_sha_short = self.commit_sha[:8] if self.commit_sha else "unknown"
        self.github_workflow = os.environ.get("GITHUB_WORKFLOW", "Manual")

    def _get_commit_sha(self) -> str:
        """Get current git commit SHA."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=self.overlay_root,
                capture_output=True,
                text=True,
                check=True,
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return "unknown"

    def _log(self, message: str):
        """Simple logging function."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {message}")

    def get_qa_results(self) -> Tuple[int, int, int, int, int, str]:
        """Parse QA results and return counts."""
        total_issues = errors = warnings = info = style = 0
        qa_tool = "basic"

        # Try pkgcheck JSON first
        pkgcheck_json = self.reports_dir / "pkgcheck-scan.json"
        if pkgcheck_json.exists():
            try:
                with open(pkgcheck_json) as f:
                    content = f.read().strip()

                # Handle both line-delimited JSON and regular JSON array
                if content:
                    try:
                        # Try parsing as JSON array first
                        data = json.loads(content)
                        if isinstance(data, list):
                            for result in data:
                                level = result.get("level", "").lower()
                                if level == "error":
                                    errors += 1
                                elif level == "warning":
                                    warnings += 1
                                elif level == "info":
                                    info += 1
                                elif level == "style":
                                    style += 1
                    except json.JSONDecodeError:
                        # Try line-delimited JSON format (pkgcheck default)
                        for line_num, line in enumerate(content.splitlines(), 1):
                            if line.strip():
                                try:
                                    result = json.loads(line)
                                    # Navigate nested structure safely
                                    if isinstance(result, dict):
                                        for category_data in result.values():
                                            if isinstance(category_data, dict):
                                                for (
                                                    package_data
                                                ) in category_data.values():
                                                    if isinstance(package_data, dict):
                                                        for (
                                                            version_data
                                                        ) in package_data.values():
                                                            if isinstance(
                                                                version_data, dict
                                                            ):
                                                                for (
                                                                    level_key,
                                                                    checks,
                                                                ) in (
                                                                    version_data.items()
                                                                ):
                                                                    level = level_key.lstrip(
                                                                        "_"
                                                                    )  # Remove underscore prefix
                                                                    if level == "error":
                                                                        errors += (
                                                                            len(checks)
                                                                            if isinstance(
                                                                                checks,
                                                                                dict,
                                                                            )
                                                                            else 1
                                                                        )
                                                                    elif (
                                                                        level
                                                                        == "warning"
                                                                    ):
                                                                        warnings += (
                                                                            len(checks)
                                                                            if isinstance(
                                                                                checks,
                                                                                dict,
                                                                            )
                                                                            else 1
                                                                        )
                                                                    elif (
                                                                        level == "info"
                                                                    ):
                                                                        info += (
                                                                            len(checks)
                                                                            if isinstance(
                                                                                checks,
                                                                                dict,
                                                                            )
                                                                            else 1
                                                                        )
                                                                    elif (
                                                                        level == "style"
                                                                    ):
                                                                        style += (
                                                                            len(checks)
                                                                            if isinstance(
                                                                                checks,
                                                                                dict,
                                                                            )
                                                                            else 1
                                                                        )
                                except json.JSONDecodeError:
                                    continue
                                except Exception as e:
                                    self._log(
                                        f"Warning: Error parsing JSON line {line_num}: {e}"
                                    )
                                    continue

                total_issues = errors + warnings + info + style
                qa_tool = "pkgcheck"
                return total_issues, errors, warnings, info, style, qa_tool
            except IOError:
                pass

        # Try pkgcheck text output
        pkgcheck_txt = self.reports_dir / "pkgcheck-scan.txt"
        if pkgcheck_txt.exists():
            try:
                with open(pkgcheck_txt) as f:
                    content = f.read()

                errors = len(re.findall(r"\bERROR\b", content))
                warnings = len(re.findall(r"\bWARNING\b", content))
                info = len(re.findall(r"\bINFO\b", content))
                style = len(re.findall(r"\bSTYLE\b", content))
                total_issues = errors + warnings + info + style
                qa_tool = "pkgcheck"
                return total_issues, errors, warnings, info, style, qa_tool
            except IOError:
                pass

        # Try repoman output
        repoman_txt = self.reports_dir / "repoman-full.txt"
        if repoman_txt.exists():
            try:
                with open(repoman_txt) as f:
                    content = f.read()

                errors = len(re.findall(r"\bERROR\b", content))
                warnings = len(re.findall(r"\bWARN\b", content))
                total_issues = errors + warnings
                qa_tool = "repoman"
                return total_issues, errors, warnings, info, style, qa_tool
            except IOError:
                pass

        # Basic fallback
        basic_qa = self.reports_dir / "basic-qa.txt"
        if basic_qa.exists():
            try:
                with open(basic_qa) as f:
                    content = f.read()

                errors = len(re.findall(r"\bERROR\b", content))
                warnings = len(re.findall(r"\bWARN\b", content))
                total_issues = errors + warnings
                return total_issues, errors, warnings, info, style, qa_tool
            except IOError:
                pass

        return total_issues, errors, warnings, info, style, qa_tool

    def _get_package_issues(self) -> List[Dict]:
        """Extract per-package issues for table display."""
        issues = []

        # Try pkgcheck JSON first
        pkgcheck_json = self.reports_dir / "pkgcheck-scan.json"
        if pkgcheck_json.exists():
            try:
                with open(pkgcheck_json) as f:
                    content = f.read().strip()

                if content:
                    try:
                        # Try parsing as JSON array first (custom format)
                        data = json.loads(content)
                        if isinstance(data, list):
                            for result in data:
                                package = result.get("package", "")
                                version = result.get("version", "")
                                category = result.get("category", "")
                                level = result.get("level", "")
                                message = result.get("message", "")

                                # Build package name
                                if category and package:
                                    pkg_name = f"{category}/{package}"
                                    if version:
                                        pkg_name += f"-{version}"
                                else:
                                    pkg_name = package or "unknown"

                                issues.append(
                                    {
                                        "package": pkg_name,
                                        "level": level,
                                        "message": message,
                                        "tool": "pkgcheck",
                                    }
                                )
                            return issues
                    except json.JSONDecodeError:
                        pass

                    # Try line-delimited JSON format (pkgcheck default)
                    try:
                        for line_num, line in enumerate(content.splitlines(), 1):
                            if line.strip():
                                try:
                                    result = json.loads(line)
                                    # Navigate nested structure safely
                                    if isinstance(result, dict):
                                        for category, category_data in result.items():
                                            if isinstance(category_data, dict):
                                                for (
                                                    package,
                                                    package_data,
                                                ) in category_data.items():
                                                    if isinstance(package_data, dict):
                                                        for (
                                                            version,
                                                            version_data,
                                                        ) in package_data.items():
                                                            if isinstance(
                                                                version_data, dict
                                                            ):
                                                                for (
                                                                    level_key,
                                                                    checks,
                                                                ) in (
                                                                    version_data.items()
                                                                ):
                                                                    level = level_key.lstrip(
                                                                        "_"
                                                                    )  # Remove underscore prefix

                                                                    # Build package name
                                                                    pkg_name = f"{category}/{package}"
                                                                    if (
                                                                        version
                                                                        != "_info"
                                                                    ):  # Skip global info entries
                                                                        pkg_name += f"-{version}"

                                                                    # Process checks (can be dict or string)
                                                                    if isinstance(
                                                                        checks, dict
                                                                    ):
                                                                        for (
                                                                            check_name,
                                                                            check_message,
                                                                        ) in (
                                                                            checks.items()
                                                                        ):
                                                                            issues.append(
                                                                                {
                                                                                    "package": pkg_name,
                                                                                    "level": level,
                                                                                    "message": f"{check_name}: {check_message}",
                                                                                    "tool": "pkgcheck",
                                                                                }
                                                                            )
                                                                    else:
                                                                        issues.append(
                                                                            {
                                                                                "package": pkg_name,
                                                                                "level": level,
                                                                                "message": str(
                                                                                    checks
                                                                                ),
                                                                                "tool": "pkgcheck",
                                                                            }
                                                                        )
                                except json.JSONDecodeError:
                                    continue
                                except Exception as e:
                                    self._log(
                                        f"Warning: Error parsing JSON line {line_num}: {e}"
                                    )
                                    continue
                        return issues
                    except Exception as e:
                        self._log(f"Warning: Error parsing pkgcheck JSON: {e}")
            except IOError:
                pass

        # Try text-based parsing for pkgcheck/repoman
        for filename, tool in [
            ("pkgcheck-scan.txt", "pkgcheck"),
            ("repoman-full.txt", "repoman"),
        ]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                try:
                    with open(filepath) as f:
                        for line in f:
                            line = line.strip()
                            if not line:
                                continue

                            # Parse pkgcheck format: "category/package-version: LEVEL: message"
                            if tool == "pkgcheck":
                                match = re.match(
                                    r"^([^:]+):\s*(ERROR|WARNING|INFO|STYLE):\s*(.+)$",
                                    line,
                                )
                                if match:
                                    issues.append(
                                        {
                                            "package": match.group(1),
                                            "level": match.group(2).lower(),
                                            "message": match.group(3),
                                            "tool": tool,
                                        }
                                    )

                            # Parse repoman format
                            elif tool == "repoman":
                                match = re.match(
                                    r"^([^:]+):\s*(ERROR|WARN):\s*(.+)$", line
                                )
                                if match:
                                    issues.append(
                                        {
                                            "package": match.group(1),
                                            "level": match.group(2).lower(),
                                            "message": match.group(3),
                                            "tool": tool,
                                        }
                                    )

                    return issues
                except IOError:
                    continue

        return issues

    def generate_markdown_report(self, output_file: str):
        """Generate Markdown report."""
        output_path = self.reports_dir / output_file
        total_issues, errors, warnings, info, style, qa_tool = self.get_qa_results()

        # Determine status
        if errors > 0:
            status_text = "❌ FAILED"
            status_emoji = "❌"
        elif warnings > 0:
            status_text = "⚠️ WARNINGS"
            status_emoji = "⚠️"
        else:
            status_text = "✅ PASSED"
            status_emoji = "✅"

        content = f"""# 🚀 COSMIC Overlay QA Report

**Generated:** {self.report_date}  
**Commit:** `{self.commit_sha_short}`  
**Workflow:** {self.github_workflow}  
**QA Tool:** {qa_tool}

## {status_emoji} Status: {status_text}

### 📊 Summary

- **Total Issues:** {total_issues}
- **Errors:** {errors}
- **Warnings:** {warnings}"""

        if style > 0:
            content += f"""
- **Info:** {info}
- **Style:** {style}"""

        content += f"""

---

## 📋 Detailed Results

### QA Scan Output

```
"""

        # Add QA tool output
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

        content += "```\n\n"

        # Package checks
        content += "### Package Checks\n\n```\n"
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

        content += "\n```\n\n"

        # Package statistics
        content += "## 📊 Package Statistics\n\n"
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

        # Files checked
        content += "\n## 📄 Files Checked\n\n"
        ebuilds = sorted(self.overlay_root.glob("**/*.ebuild"))
        for ebuild in ebuilds:
            rel_path = ebuild.relative_to(self.overlay_root)
            content += f"- `{rel_path}`\n"

        with open(output_path, "w") as f:
            f.write(content)

        self._log(f"Markdown report generated: {output_path}")

    def generate_html_report(self, output_file: str):
        """Generate HTML report with improved table-based layout."""
        output_path = self.reports_dir / output_file
        total_issues, errors, warnings, info, style, qa_tool = self.get_qa_results()
        package_issues = self._get_package_issues()

        # Determine status
        if errors > 0:
            status_text = "FAILED"
            status_class = "status-error"
            status_icon = "❌"
        elif warnings > 0:
            status_text = "WARNINGS"
            status_class = "status-warning"
            status_icon = "⚠️"
        else:
            status_text = "PASSED"
            status_class = "status-success"
            status_icon = "✅"

        # Generate HTML
        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>COSMIC Overlay QA Report</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f8f9fa;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: white;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            min-height: 100vh;
        }}
        
        h1 {{
            color: #2c3e50;
            margin-bottom: 20px;
            text-align: center;
            font-size: 2.5em;
        }}
        
        h2 {{
            color: #34495e;
            margin: 30px 0 15px 0;
            padding-bottom: 8px;
            border-bottom: 2px solid #ecf0f1;
        }}
        
        h3 {{
            color: #34495e;
            margin: 20px 0 10px 0;
        }}
        
        .meta {{
            background: #ecf0f1;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 0.95em;
        }}
        
        .status {{
            text-align: center;
            padding: 20px;
            border-radius: 8px;
            font-weight: bold;
            font-size: 1.2em;
            margin: 20px 0;
        }}
        
        .status-success {{
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }}
        
        .status-warning {{
            background: #fff3cd;
            color: #856404;
            border: 1px solid #ffeaa7;
        }}
        
        .status-error {{
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }}
        
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }}
        
        .stat-card {{
            background: #fff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        
        .stat-number {{
            font-size: 2em;
            font-weight: bold;
            color: #2c3e50;
        }}
        
        .stat-label {{
            color: #7f8c8d;
            font-size: 0.9em;
            margin-top: 5px;
        }}
        
        .issues-table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        
        .issues-table th,
        .issues-table td {{
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #dee2e6;
        }}
        
        .issues-table th {{
            background: #f8f9fa;
            font-weight: 600;
            color: #495057;
            position: sticky;
            top: 0;
        }}
        
        .issues-table tbody tr:hover {{
            background: #f8f9fa;
        }}
        
        .level-error {{
            color: #dc3545;
            font-weight: bold;
        }}
        
        .level-warning {{
            color: #fd7e14;
            font-weight: bold;
        }}
        
        .level-info {{
            color: #17a2b8;
        }}
        
        .level-style {{
            color: #6f42c1;
        }}
        
        .package-name {{
            font-family: 'Consolas', 'Monaco', monospace;
            background: #f8f9fa;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.9em;
        }}
        
        .message {{
            max-width: 400px;
            word-wrap: break-word;
        }}
        
        .output-section {{
            background: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            overflow-x: auto;
        }}
        
        .output-content {{
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
            line-height: 1.4;
            white-space: pre-wrap;
        }}
        
        .error-text {{ color: #dc3545; font-weight: bold; }}
        .warning-text {{ color: #fd7e14; font-weight: bold; }}
        .info-text {{ color: #17a2b8; }}
        
        .file-list {{
            columns: 1;
            column-gap: 30px;
            list-style: none;
        }}
        
        .file-list li {{
            break-inside: avoid;
            margin: 5px 0;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
            background: #f8f9fa;
            padding: 4px 8px;
            border-radius: 4px;
        }}
        
        footer {{
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            text-align: center;
            color: #6c757d;
            font-size: 0.9em;
        }}
        
        footer a {{
            color: #007bff;
            text-decoration: none;
        }}
        
        footer a:hover {{
            text-decoration: underline;
        }}
        
        @media (max-width: 768px) {{
            .container {{
                padding: 10px;
            }}
            
            .stats {{
                grid-template-columns: repeat(2, 1fr);
            }}
            
            .file-list {{
                columns: 1;
            }}
            
            .issues-table {{
                font-size: 0.9em;
            }}
            
            .message {{
                max-width: 200px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 COSMIC Overlay QA Report</h1>
        
        <div class="meta">
            <strong>Generated:</strong> {self.report_date}<br>
            <strong>Commit:</strong> <code>{self.commit_sha_short}</code><br>
            <strong>Workflow:</strong> {self.github_workflow}<br>
            <strong>QA Tool:</strong> {qa_tool}
        </div>

        <div class="status {status_class}">
            {status_icon} {status_text}
        </div>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-number">{total_issues}</div>
                <div class="stat-label">Total Issues</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">{errors}</div>
                <div class="stat-label">Errors</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">{warnings}</div>
                <div class="stat-label">Warnings</div>
            </div>"""

        if style > 0:
            html_content += f"""
            <div class="stat-card">
                <div class="stat-number">{info}</div>
                <div class="stat-label">Info</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">{style}</div>
                <div class="stat-label">Style</div>
            </div>"""

        html_content += """
        </div>

        <h2>📋 Detailed Results</h2>"""

        # Add per-package issues table
        if package_issues:
            html_content += """
        <h3>Package Issues</h3>
        <table class="issues-table">
            <thead>
                <tr>
                    <th>Package</th>
                    <th>Level</th>
                    <th>Message</th>
                    <th>Tool</th>
                </tr>
            </thead>
            <tbody>"""

            for issue in package_issues:
                level_class = f"level-{issue['level']}"
                html_content += f"""
                <tr>
                    <td><span class="package-name">{self._escape_html(issue['package'])}</span></td>
                    <td><span class="{level_class}">{issue['level'].upper()}</span></td>
                    <td class="message">{self._escape_html(issue['message'])}</td>
                    <td>{issue['tool']}</td>
                </tr>"""

            html_content += """
            </tbody>
        </table>"""
        else:
            html_content += """
        <p>No package-specific issues found.</p>"""

        # Add QA tool output
        html_content += """
        <h3>QA Scan Output</h3>
        <div class="output-section">
            <div class="output-content">"""

        # Add appropriate QA tool output
        qa_output = ""
        for filename in ["pkgcheck-scan.txt", "repoman-full.txt", "basic-qa.txt"]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                try:
                    with open(filepath) as f:
                        qa_output = f.read()
                    break
                except IOError:
                    continue

        if not qa_output:
            ebuilds_count = len(list(self.overlay_root.glob("**/*.ebuild")))
            qa_output = f"=== Basic QA Check Results ===\nChecked {ebuilds_count} ebuilds in overlay\nFound {errors} ERROR(s) and {warnings} WARNING(s)"

        # Escape HTML and add syntax highlighting
        qa_output = self._escape_html(qa_output)
        qa_output = re.sub(
            r"\bERROR\b", '<span class="error-text">ERROR</span>', qa_output
        )
        qa_output = re.sub(
            r"\bWARNING\b", '<span class="warning-text">WARNING</span>', qa_output
        )
        qa_output = re.sub(
            r"\bWARN\b", '<span class="warning-text">WARN</span>', qa_output
        )
        qa_output = re.sub(
            r"\bINFO\b", '<span class="info-text">INFO</span>', qa_output
        )

        html_content += qa_output

        html_content += """
            </div>
        </div>"""

        # Package checks
        html_content += """
        <h3>Package Checks</h3>
        <div class="output-section">
            <div class="output-content">"""

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
            </div>
        </div>

        <h2>📊 Package Statistics</h2>
        <ul>"""

        # Count packages per category
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
                html_content += f"            <li><strong>{category}/:</strong> {pkg_count} packages</li>\n"

        html_content += """
        </ul>

        <h2>📄 Files Checked</h2>
        <ul class="file-list">"""

        # List all ebuild files
        ebuilds = sorted(self.overlay_root.glob("**/*.ebuild"))
        for ebuild in ebuilds:
            rel_path = ebuild.relative_to(self.overlay_root)
            html_content += f"            <li>{rel_path}</li>\n"

        html_content += f"""
        </ul>

        <footer>
            Generated by COSMIC Overlay QA Pipeline • 
            <a href="https://github.com/fsvm88/cosmic-overlay">View Repository</a>
        </footer>
    </div>
</body>
</html>"""

        with open(output_path, "w") as f:
            f.write(html_content)

        self._log(f"HTML report generated: {output_path}")

    def _escape_html(self, text: str) -> str:
        """Escape HTML characters."""
        return (
            text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
            .replace("'", "&#x27;")
        )

    def generate_all_reports(self):
        """Generate all report formats."""
        self._log("Starting QA report generation...")

        # Generate both report formats
        self.generate_markdown_report("report.md")
        self.generate_markdown_report("summary.md")  # Compatibility alias
        self.generate_html_report("index.html")

        # Create README for reports directory
        readme_content = f"""# QA Reports

This directory contains automatically generated QA reports for the COSMIC overlay.

## Files

- `index.html` - Main HTML report (open in browser)
- `report.md` - Detailed Markdown report
- `summary.md` - Same as report.md (compatibility alias)

## Generated

{self.report_date}
"""

        with open(self.reports_dir / "README.md", "w") as f:
            f.write(readme_content)

        self._log("All reports generated successfully!")

        # Print summary to stdout
        total_issues, errors, warnings, info, style, qa_tool = self.get_qa_results()

        print()
        print("📊 QA Report Summary:")
        print(f"   Tool: {qa_tool}")
        print(f"   Total Issues: {total_issues}")
        print(f"   Errors: {errors}")
        print(f"   Warnings: {warnings}")
        if style > 0:
            print(f"   Info: {info}")
            print(f"   Style: {style}")
        print(f"   Reports: {self.reports_dir}")
        print()


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Generate QA reports for COSMIC overlay"
    )
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

    args = parser.parse_args()

    generator = QAReportGenerator(args.overlay_root, args.reports_dir)
    os.chdir(generator.reports_dir)
    generator.generate_all_reports()


if __name__ == "__main__":
    main()
