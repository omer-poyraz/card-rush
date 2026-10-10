#!/usr/bin/env bash
# Full automated test suite (headless). Report: tests/reports/test_report.md
# Usage: tools/run_tests.sh [--only <substring>]
set -euo pipefail
cd "$(dirname "$0")/.."
G="$(tools/godot_path.sh)"
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . res://tests/run_tests.tscn -- "$@"
