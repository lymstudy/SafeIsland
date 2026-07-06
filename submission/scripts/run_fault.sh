#!/bin/bash
# AXI Safety Island 注错仿真（VCS 主路径）
# Usage: cd submission/scripts && bash run_fault.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AXI Safety Island — Fault Injection Simulation ==="
make clean-work clean-scripts-spill 2>/dev/null || true
make fault batch campaign-required campaign-report fi-summary
make summary
make finalize

echo ""
echo "=== Results (sim/ only) ==="
echo "  Baseline: ../sim/fault_injection/reports/fault_injection_report.csv"
echo "  Batch:    ../sim/fault_injection/reports/fault_batch_report.csv"
echo "  Campaign: ../sim/fault_injection/reports/fault_campaign_report.csv"
echo "  Summary:  ../sim/fault_injection/diagnostic_coverage_summary.txt"
echo ""
echo "Done."
