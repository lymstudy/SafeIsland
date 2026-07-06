#!/bin/bash
# Optional Test-Faultsim / TetraMAX logic stuck-at fault simulation helper.
# This script is intentionally non-blocking for the VCS-based submission flow.

set +e

REPORT_DIR="sim/fault_injection/reports"
WORK_DIR="sim/work/faultsim"

mkdir -p "$REPORT_DIR" "$WORK_DIR"

REPORT="$REPORT_DIR/logic_faultsim_report.txt"
SUMMARY="$REPORT_DIR/logic_faultsim_summary.csv"

echo "=== Optional Logic Gate Fault Simulation ===" > "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

# Probe tools first
bash tools/probe_faultsim_tool.sh >> "$REPORT" 2>&1

# If a runnable tmax/tmax_shell is available, the user can extend this section
# to run a real ATPG flow. For the submission package we only record the probe
# results so that the optional path is documented and does not break the VCS flow.

echo "" >> "$REPORT"
echo "No full gate-level ATPG flow was run in this submission environment." >> "$REPORT"
echo "The VCS RTL campaign is the primary reproducible fault-injection flow." >> "$REPORT"

# Minimal summary CSV
echo "Tool,Available,Note" > "$SUMMARY"
for cmd in tmax tmax_shell tetramax testmax; do
    if which $cmd >/dev/null 2>&1; then
        echo "$cmd,yes,found in PATH" >> "$SUMMARY"
    else
        echo "$cmd,no,not in PATH" >> "$SUMMARY"
    fi
done

echo "Optional logic faultsim report: $REPORT"
echo "Optional logic faultsim summary: $SUMMARY"
