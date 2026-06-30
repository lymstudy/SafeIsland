#!/bin/bash
# run_coverage.sh — VCS 代码覆盖率一键脚本
# Usage: cd sim/vcs && bash run_coverage.sh

set -e

echo "=== AXI Safety Island VCS Code Coverage ==="
echo "  Coverage types: Line + Toggle + Condition + FSM"
echo "  Test stimulus:  tb_safety_island_top_full (34 scenarios)"
echo ""

# Paths
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RTL_F="$ROOT/rtl/safety_island_top.f"
TB_FULL="$ROOT/tb/tb_safety_island_top_full.v"
COV_DIR="coverage"
COV_BUILD="$COV_DIR/build"
COV_REPORT="$COV_DIR/report"
LOG_DIR="logs"

mkdir -p "$COV_BUILD" "$LOG_DIR"

echo "[1/3] Compiling design with coverage..."
vcs -full64 -sverilog -debug_access+all -kdb +define+FSDB \
    -cm line+tgl+cond+fsm \
    -cm_dir "$COV_BUILD" \
    -cm_name full \
    -timescale=1ns/1ps \
    -F "$RTL_F" \
    "$TB_FULL" \
    -top tb_safety_island_top_full \
    -o "$COV_BUILD/simv_cov" \
    -l "$LOG_DIR/cov_compile.log"

echo "[2/3] Running simulation with coverage..."
"$COV_BUILD/simv_cov" -l "$LOG_DIR/cov_run.log"

echo "[3/3] Generating coverage report (urg)..."
urg -dir "$COV_BUILD"/*.vdb -report "$COV_REPORT"

echo ""
echo "=== Coverage report ready ==="
echo "  HTML: $COV_REPORT/urgReport/index.html"
echo "  Text: $COV_REPORT/dashboard.txt"
echo ""
echo "Quick summary:"
head -30 "$COV_REPORT/dashboard.txt" 2>/dev/null || echo "  (dashboard.txt not found — check HTML report)"
