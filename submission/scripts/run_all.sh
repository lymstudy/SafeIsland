#!/bin/bash
# 功能仿真 + 注错仿真 + 覆盖率（评分全套）
# Usage: cd submission/scripts && bash run_all.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AXI Safety Island — Full Submission Regression ==="
make clean 2>/dev/null || true
make all

echo ""
echo "All results:"
echo "  Functional:      ../sim/functional/"
echo "  Fault injection: ../sim/fault_injection/"
