#!/bin/bash
# 注错仿真（基线 54 + 全量 bit 610）
# Usage: cd submission/scripts && bash run_fault.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AXI Safety Island — Fault Injection Simulation ==="
make clean-work clean-scripts-spill 2>/dev/null || true
make fault batch fi-summary
make summary
make finalize

echo ""
echo "Results (sim/ only):"
echo "  Logs:    ../sim/fault_injection/logs/"
echo "  Reports: ../sim/fault_injection/reports/"
