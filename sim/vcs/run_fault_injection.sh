#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$ROOT_DIR/sim/out/vcs_fault_injection"
SUMMARY_FILE="$OUT_DIR/fault_injection_summary.txt"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

: "${VCS_HOME:=}"
: "${VERDI_HOME:=}"

vcs -full64 -sverilog +v2k -timescale=1ns/1ps \
    -debug_access+all \
    -f "$SCRIPT_DIR/filelist.f" \
    "$ROOT_DIR/tb/tb_safety_island_fault_injection.v" \
    -l compile.log \
    -o simv_fault_injection

./simv_fault_injection +vcs+vcdpluson +SUMMARY_FILE="$SUMMARY_FILE" -l sim.log

cat <<'EOF'
Fault injection simulation finished.
Check sim.log for FI_CASE/FI_SUMMARY lines and fault_injection_summary.txt for the extracted campaign summary.
Open waves in Verdi from this directory with a command such as:
  verdi -f ../../vcs/filelist.f ../../tb/tb_safety_island_fault_injection.v -ssf vcdplus.vpd
EOF
