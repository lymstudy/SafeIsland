#!/bin/bash
# Wait for required + fault/batch to finish, then run full campaign in isolated work dir.
# Usage: cd submission/scripts && make wait-and-run-full
#   or:  nohup bash tools/wait_and_run_full.sh > /tmp/wait_and_run_full.log 2>&1 &

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${ROOT}/sim/fault_injection/reports/full/overnight.log"
PROGRESS="${ROOT}/sim/work_full/campaign_progress.txt"
REPORT_DIR="${ROOT}/sim/fault_injection/reports/full"

mkdir -p "$REPORT_DIR" "${ROOT}/sim/work_full"

exec > >(tee -a "$LOG") 2>&1

echo "=== wait_and_run_full started $(date) ==="

wait_for() {
    local label="$1"
    shift
    while "$@"; do
        echo "[wait] $label still running $(date)"
        sleep 60
    done
}

wait_for "campaign-required" pgrep -f "run_fault_campaign.py --mode required"
wait_for "fault/batch make" pgrep -f "make fault batch"
wait_for "simv_fault baseline" pgrep -f "simv_fault.*CSV_FILE"
wait_for "simv_batch" pgrep -f "simv_batch.*BATCH_ALL"

echo "=== prerequisite runs finished $(date) ==="

cd "${ROOT}/scripts"
make campaign-report fi-summary || true

REQ_REPORT="${ROOT}/sim/fault_injection/reports/fault_campaign_report.csv"
if [ -f "$REQ_REPORT" ]; then
    TOTAL=$(($(wc -l < "$REQ_REPORT") - 1))
    ERRORS=$(grep -c ',error,' "$REQ_REPORT" || true)
    echo "[check] required campaign: total=$TOTAL errors=$ERRORS"
    if [ "$TOTAL" -gt 0 ] && [ "$ERRORS" -eq "$TOTAL" ]; then
        echo "[warn] all required faults are error — check UCLI/logs before full run"
    fi
fi

echo "=== starting campaign-full-isolated $(date) ==="
echo "progress file: $PROGRESS"
echo "reports dir:   $REPORT_DIR"

make campaign-full-isolated
make campaign-report-full || true

echo "=== campaign-full-isolated finished $(date) ==="
if [ -f "${REPORT_DIR}/fault_campaign_summary.txt" ]; then
    cat "${REPORT_DIR}/fault_campaign_summary.txt"
fi
