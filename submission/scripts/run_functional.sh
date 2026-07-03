#!/bin/bash
# 功能仿真 + 代码行覆盖率
# Usage: cd submission/scripts && bash run_functional.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AXI Safety Island — Functional Simulation ==="
make clean-work clean-scripts-spill 2>/dev/null || true
make full
make cov-full || { echo "WARN: cov-full had errors (check urg); continuing..."; }
make summary
make finalize

echo ""
echo "Results (sim/ only):"
echo "  Logs:     ../sim/functional/logs/"
echo "  Coverage: ../sim/functional/coverage/"
