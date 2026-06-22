#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$ROOT_DIR/sim/out/vcs_top_full"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

: "${VCS_HOME:=}"
: "${VERDI_HOME:=}"

vcs -full64 -sverilog +v2k -timescale=1ns/1ps \
    -debug_access+all \
    -f "$SCRIPT_DIR/filelist.f" \
    "$ROOT_DIR/tb/tb_safety_island_top_full.v" \
    -l compile.log \
    -o simv_top_full

./simv_top_full +vcs+vcdpluson -l sim.log

cat <<'EOF'
Top full simulation finished.
Open waves in Verdi from this directory with a command such as:
  verdi -f ../../vcs/filelist.f ../../tb/tb_safety_island_top_full.v -ssf vcdplus.vpd
EOF
