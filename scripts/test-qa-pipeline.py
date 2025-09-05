#!/usr/bin/env python3

"""
Test QA Pipeline Locally using Docker

This script mirrors the GitHub Actions workflow for local testing,
providing a containerized environment for QA checks.
"""

import argparse
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


class Colors:
    """ANSI color codes for terminal output."""

    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"  # No Color


class DockerQATester:
    """Docker-based QA pipeline tester."""

    def __init__(self, overlay_root: str, reports_dir: str):
        self.overlay_root = Path(overlay_root).resolve()
        self.reports_dir = Path(reports_dir).resolve()

        # Docker configuration
        self.docker_image = "gentoo/stage3"
        self.container_name = (
            f"cosmic-overlay-qa-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        )

        # Create reports directory
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    def _log(self, message: str):
        """Log with blue color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"{Colors.BLUE}[{timestamp}]{Colors.NC} {message}")

    def _success(self, message: str):
        """Log success with green color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"{Colors.GREEN}[{timestamp}]{Colors.NC} ✅ {message}")

    def _warn(self, message: str):
        """Log warning with yellow color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"{Colors.YELLOW}[{timestamp}]{Colors.NC} ⚠️  {message}")

    def _error(self, message: str):
        """Log error with red color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"{Colors.RED}[{timestamp}]{Colors.NC} ❌ {message}")

    def check_docker(self) -> bool:
        """Check if Docker is available and running."""
        if not shutil.which("docker"):
            self._error("Docker is not installed or not in PATH")
            print("Please install Docker to use this script")
            print("Alternatively, use: ./scripts/simple-qa-check.py")
            return False

        try:
            subprocess.run(["docker", "info"], capture_output=True, check=True)
            self._success("Docker is available")
            return True
        except subprocess.CalledProcessError:
            self._error("Docker daemon is not running")
            print("Please start Docker daemon")
            return False

    def prepare_docker_setup(self) -> str:
        """Prepare Docker setup script."""
        setup_script = f"""#!/bin/bash
set -euo pipefail

echo "=== Setting up Gentoo environment for QA testing ==="

# Update package database
echo "Updating package database..."
emerge-webrsync --quiet

# Install required packages
echo "Installing QA tools..."
emerge -q pkgcheck pkgdev

# Verify installations
echo "Verifying tool installations..."
pkgcheck --version
pkgdev --version

echo "=== Environment setup complete ==="
"""

        setup_file = self.reports_dir / "docker-setup.sh"
        with open(setup_file, "w") as f:
            f.write(setup_script)

        # Make executable
        setup_file.chmod(0o755)
        return str(setup_file)

    def prepare_qa_script(self) -> str:
        """Prepare QA testing script for Docker."""
        qa_script = f"""#!/bin/bash
set -euo pipefail

OVERLAY_ROOT="/overlay"
REPORTS_DIR="/overlay/qa-reports"

echo "=== Starting COSMIC Overlay QA Pipeline Test ==="
echo "Overlay root: $OVERLAY_ROOT"
echo "Reports dir: $REPORTS_DIR"

cd "$OVERLAY_ROOT"

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Run pkgcheck scan
echo "Running pkgcheck scan..."
if pkgcheck scan --config scripts/pkgcheck.conf --reporter JsonReporter "$OVERLAY_ROOT" > "$REPORTS_DIR/pkgcheck-scan.json" 2>&1; then
    echo "✅ pkgcheck JSON scan completed"
else
    echo "⚠️  pkgcheck JSON scan completed with issues"
fi

# Run pkgcheck with text output for readability
echo "Running pkgcheck text scan..."
if pkgcheck scan --config scripts/pkgcheck.conf --reporter StrReporter "$OVERLAY_ROOT" > "$REPORTS_DIR/pkgcheck-scan.txt" 2>&1; then
    echo "✅ pkgcheck text scan completed"
else
    echo "⚠️  pkgcheck text scan completed with issues"
fi

# Run manifest check
echo "Running manifest integrity check..."
if pkgdev manifest "$OVERLAY_ROOT" > "$REPORTS_DIR/manifest-check.txt" 2>&1; then
    echo "✅ Manifest check passed"
else
    echo "⚠️  Manifest check found issues"
fi

# Generate reports using Python script
echo "Generating reports..."
if python3 scripts/generate-qa-report.py --overlay-root "$OVERLAY_ROOT" --reports-dir "$REPORTS_DIR"; then
    echo "✅ Reports generated successfully"
else
    echo "⚠️  Report generation had issues"
fi

# Summary
echo ""
echo "=== QA Pipeline Test Summary ==="
echo "Results saved to: $REPORTS_DIR"

# Count issues
if [ -f "$REPORTS_DIR/pkgcheck-scan.json" ]; then
    ERRORS=$(python3 -c "
import json, sys
try:
    with open('$REPORTS_DIR/pkgcheck-scan.json') as f:
        data = json.load(f)
    errors = sum(1 for item in data if item.get('level') == 'error')
    warnings = sum(1 for item in data if item.get('level') == 'warning')
    print(f'Errors: {{errors}}, Warnings: {{warnings}}')
except:
    print('Could not parse results')
" 2>/dev/null || echo "Could not parse JSON results")
else
    echo "No JSON results available"
fi

echo "=== Pipeline test complete ==="
"""

        qa_file = self.reports_dir / "docker-qa-test.sh"
        with open(qa_file, "w") as f:
            f.write(qa_script)

        # Make executable
        qa_file.chmod(0o755)
        return str(qa_file)

    def run_docker_container(
        self, setup_script: str, qa_script: str, interactive: bool = False
    ) -> bool:
        """Run the Docker container with QA testing."""
        self._log(f"Starting Docker container: {self.container_name}")

        # Prepare Docker run command
        docker_cmd = [
            "docker",
            "run",
            "--name",
            self.container_name,
            "--rm",  # Remove container when done
            "-v",
            f"{self.overlay_root}:/overlay:ro",  # Mount overlay as read-only
            "-v",
            f"{self.reports_dir}:/overlay/qa-reports:rw",  # Mount reports dir as writable
            "-w",
            "/overlay",
        ]

        if interactive:
            docker_cmd.extend(["-it"])

        docker_cmd.append(self.docker_image)

        try:
            # Start container and run setup
            self._log("Pulling Docker image...")
            subprocess.run(["docker", "pull", self.docker_image], check=True)

            # Run setup in container
            self._log("Setting up environment in container...")
            setup_cmd = docker_cmd + ["bash", "-c", f"cat {setup_script} | bash"]
            result = subprocess.run(setup_cmd, capture_output=not interactive)

            if result.returncode != 0:
                self._error("Environment setup failed")
                return False

            # Run QA tests
            self._log("Running QA tests in container...")
            qa_cmd = docker_cmd + ["bash", qa_script]
            result = subprocess.run(qa_cmd, capture_output=not interactive)

            success = result.returncode == 0
            if success:
                self._success("QA pipeline test completed successfully")
            else:
                self._warn("QA pipeline test completed with issues")

            return success

        except subprocess.CalledProcessError as e:
            self._error(f"Docker command failed: {e}")
            return False
        except KeyboardInterrupt:
            self._warn("Test interrupted by user")
            # Try to clean up container
            try:
                subprocess.run(
                    ["docker", "stop", self.container_name], capture_output=True
                )
            except:
                pass
            return False

    def cleanup_docker_files(self):
        """Clean up temporary Docker files."""
        for filename in ["docker-setup.sh", "docker-qa-test.sh"]:
            filepath = self.reports_dir / filename
            if filepath.exists():
                filepath.unlink()

    def run_full_test(self, interactive: bool = False, cleanup: bool = True) -> bool:
        """Run the complete Docker-based QA test."""
        self._log("=== Starting Docker QA Pipeline Test ===")

        # Check Docker
        if not self.check_docker():
            return False

        # Check overlay structure
        if not (self.overlay_root / "scripts" / "pkgcheck.conf").exists():
            self._error("pkgcheck.conf not found in scripts directory")
            return False

        if not (self.overlay_root / "scripts" / "generate-qa-report.py").exists():
            self._error("generate-qa-report.py not found in scripts directory")
            return False

        try:
            # Prepare Docker scripts
            self._log("Preparing Docker environment...")
            setup_script = self.prepare_docker_setup()
            qa_script = self.prepare_qa_script()

            # Run tests
            success = self.run_docker_container(setup_script, qa_script, interactive)

            # Show results
            if success:
                self._success("Docker QA test completed successfully")
                self._log(f"Results available in: {self.reports_dir}")

                # Show HTML report location
                html_report = self.reports_dir / "index.html"
                if html_report.exists():
                    self._log(f"HTML report: file://{html_report}")
            else:
                self._warn("Docker QA test completed with issues")

            return success

                try:
                    self.cleanup_docker_files()
                except Exception as e:
                    self._warn(f"Cleanup failed: {e}")


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Test QA pipeline locally using Docker"
    )
    parser.add_argument(
        "--overlay-root",
        default=Path(__file__).parent.parent,
        help="Path to overlay root directory",
    )
    parser.add_argument(
        "--reports-dir",
        default=Path(__file__).parent.parent / "qa-reports",
        help="Directory to store test reports",
    )
    parser.add_argument(
        "--interactive",
        "-i",
        action="store_true",
        help="Run Docker container in interactive mode",
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Do not clean up temporary Docker files",
    )
    parser.add_argument(
        "--fallback",
        action="store_true",
        help="Fall back to simple QA check if Docker is not available",
    )

    args = parser.parse_args()

    try:
        tester = DockerQATester(args.overlay_root, args.reports_dir)
        success = tester.run_full_test(
            interactive=args.interactive, cleanup=not args.no_cleanup
        )

        if not success and args.fallback:
            print("\n" + "=" * 50)
            print("Docker test failed, falling back to simple QA check...")
            print("=" * 50)

            # Try to run simple QA check
            simple_qa_script = (
                Path(args.overlay_root) / "scripts" / "simple-qa-check.py"
            )
            if simple_qa_script.exists():
                subprocess.run(
                    [
                        sys.executable,
                        str(simple_qa_script),
                        "--overlay-root",
                        str(args.overlay_root),
                        "--reports-dir",
                        str(args.reports_dir),
                    ]
                )
            else:
                print("Simple QA check script not found")

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
