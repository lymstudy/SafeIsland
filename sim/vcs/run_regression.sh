#!/bin/bash
# =============================================================================
# AXI Safety Island — VCS 赛题回归一键脚本
# =============================================================================
# 用法: cd sim/vcs && bash run_regression.sh [--full|--score|--quick]
#
#   --full  : 全部测试 (full + fault + batch + fdet + coverage)  默认
#   --score : 赛题评分核心 (full + fault + batch)               评分4项
#   --quick : 快速检查 (full + fault)                           日常开发
#
# 赛题测试分类:
#   一、VCS功能仿真: make full (34 case)
#   二、注错仿真:
#       - 基线注错:  make fault (54 targeted fault sites)
#       - 全量bit扫描: make batch (594 bit-level sweep)
#   三、辅助: make fdet (18 FD unit tests)
# =============================================================================

set -e

MODE="${1:---full}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUT_DIR="regression_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

# ── Header ──
echo "======================================================================"
echo "  AXI Safety Island — VCS Regression Runner"
echo "  Mode: $MODE"
echo "  Start: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Output: $OUT_DIR/"
echo "======================================================================"

# ── Run a target and tee log ──
run_target() {
    local target="$1"
    local desc="$2"
    local out_file="$OUT_DIR/${target}.log"
    echo ""
    echo "── [$target] $desc ──"
    echo "  Log: $out_file"
    make "$target" 2>&1 | tee "$out_file" || true
    echo "  Done: $target"
}

# ── Quick result from log ──
quick_result() {
    local log="$1"
    if [ -f "$log" ]; then
        if grep -q "cases=34" "$log" 2>/dev/null; then
            echo "  ✅ PASS: 34/34 functional tests"
        fi
        if grep -q "FI_SUMMARY" "$log" 2>/dev/null; then
            grep "FI_SUMMARY" "$log" | tail -1
            grep "PASS\|FAIL" "$log" | tail -1
        fi
        if grep -q "failures=" "$log" 2>/dev/null; then
            grep "failures=" "$log"
        fi
    fi
}

# ── Main ──
echo ""
echo "  Test Plan:"
case "$MODE" in
    --full)
        echo "    [1/5] full   — 功能仿真                  (34 case)"
        echo "    [2/5] fault  — 注错仿真-基线              (54 case)"
        echo "    [3/5] batch  — 注错仿真-全量bit扫描       (594 case)"
        echo "    [4/5] fdet   — FD单元测试                 (18 case)"
        echo "    [5/5] cov    — 代码行覆盖率                (urg)"
        ;;
    --score)
        echo "    [1/3] full   — 功能仿真                  (34 case)"
        echo "    [2/3] fault  — 注错仿真-基线              (54 case)"
        echo "    [3/3] batch  — 注错仿真-全量bit扫描       (594 case)"
        ;;
    --quick)
        echo "    [1/2] full   — 功能仿真                  (34 case)"
        echo "    [2/2] fault  — 注错仿真-基线              (54 case)"
        ;;
esac
echo ""

T_START=$(date +%s)

# ── Clean first ──
echo "── Clean old build artifacts ──"
make clean 2>&1 | tee "$OUT_DIR/clean.log" || true

# ── Run tests ──
case "$MODE" in
    --full|--score|--quick)
        run_target "full" "功能仿真"
        quick_result "$OUT_DIR/full.log"
        run_target "fault" "注错仿真-基线"
        quick_result "$OUT_DIR/fault.log"
        ;;
esac

case "$MODE" in
    --full|--score)
        run_target "batch" "注错仿真-全量bit扫描"
        quick_result "$OUT_DIR/batch.log"
        ;;
esac

case "$MODE" in
    --full)
        run_target "fdet" "FD单元测试"
        quick_result "$OUT_DIR/fdet.log"
        run_target "cov-full" "代码行覆盖率"
        ;;
esac

T_END=$(date +%s)
DURATION=$((T_END - T_START))

# ── Collect summary ──
SUMMARY="$OUT_DIR/SUMMARY.txt"
{
    echo "======================================================================"
    echo "  AXI Safety Island — VCS Regression Summary"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Mode: $MODE"
    echo "  Duration: ${DURATION}s"
    echo "======================================================================"
    echo ""
    echo "── 一、VCS功能仿真 ──"
    echo "  套件: full (tb_safety_island_top_full)"
    echo "  用例: 34"
    if [ -f "$OUT_DIR/full.log" ]; then
        grep "cases=34" "$OUT_DIR/full.log" 2>/dev/null || echo "  (check full.log)"
        grep -c "PASS:" "$OUT_DIR/full.log" 2>/dev/null | xargs -I{} echo "  PASS: {}/34"
    fi
    echo ""
    echo "── 二、注错仿真 — 基线 ──"
    echo "  套件: fault (tb_safety_island_fault_injection, targeted fault sites)"
    echo "  用例: 54"
    if [ -f "$OUT_DIR/fault.log" ]; then
        grep "FI_SUMMARY" "$OUT_DIR/fault.log" 2>/dev/null || echo "  (check fault.log)"
        grep "PASS\|FAIL" "$OUT_DIR/fault.log" 2>/dev/null | tail -3
    fi
    echo ""
    echo "── 三、注错仿真 — 全量bit扫描 ──"
    echo "  套件: batch (tb_safety_island_fault_injection, +BATCH_ALL)"
    echo "  用例: 594 (全寄存器 bit 级扫描)"
    if [ -f "$OUT_DIR/batch.log" ]; then
        grep "FI_SUMMARY" "$OUT_DIR/batch.log" 2>/dev/null || echo "  (check batch.log)"
    fi
    echo ""
    echo "── 四、FD单元测试 (辅助) ──"
    echo "  套件: fdet"
    echo "  用例: 18"
    if [ -f "$OUT_DIR/fdet.log" ]; then
        grep "failures=" "$OUT_DIR/fdet.log" 2>/dev/null || echo "  (check fdet.log)"
    fi
    echo ""
    echo "======================================================================"
    echo "  All logs: $OUT_DIR/"
    echo "  Waveforms: waves/"
    echo "  Coverage: coverage/report/urgReport/index.html"
    echo "======================================================================"
} > "$SUMMARY"

echo ""
cat "$SUMMARY"
echo ""
echo "  Summary saved to: $OUT_DIR/SUMMARY.txt"
echo "  All done in ${DURATION}s"