#!/usr/bin/env python3
"""
run_tests.py — AXI Safety Island 仿真测试自动化脚本
用法:
  python tools/run_tests.py --level module     # 模块级测试
  python tools/run_tests.py --level top         # 顶层集成测试
  python tools/run_tests.py --level fault       # 故障注入 campaign
  python tools/run_tests.py --level all         # 全部运行
"""

import subprocess
import sys
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
RTL_DIR = PROJECT_ROOT / "rtl"
TB_DIR = PROJECT_ROOT / "tb"
SIM_OUT = PROJECT_ROOT / "sim_output"

IVERILOG = "iverilog"
VVP = "vvp"
IVERILOG_FLAGS = ["-gsystem-verilog", f"-I{RTL_DIR}", f"-I{TB_DIR}"]

ALL_RTL = sorted(RTL_DIR.glob("*.v"))

TEST_SUITES = {
    "module": [
        {
            "name": "s_axi_config",
            "rtl": ["s_axi_config.v"],
            "tb": "tb_s_axi_config.v",
        },
        {
            "name": "config_checker",
            "rtl": ["config_checker.v"],
            "tb": "tb_config_checker.v",
        },
        {
            "name": "axi_master_channel",
            "rtl": ["axi_master_channel.v"],
            "tb": "tb_axi_master_channel.v",
        },
        {
            "name": "data_fault",
            "rtl": ["read_data_processor.v", "fault_detector.v", "fault_status_manager.v"],
            "tb": "tb_data_fault.v",
        },
    ],
    "top": [
        {
            "name": "top_integration",
            "rtl": [p.name for p in ALL_RTL],
            "tb": "tb_top.v",
        },
    ],
    "fault": [
        {
            "name": "fault_campaign",
            "rtl": [p.name for p in ALL_RTL],
            "tb": "tb_fault_campaign.v",
        },
    ],
}


def run_test(name, rtl_files, tb_file):
    """Compile and run a single test"""
    SIM_OUT.mkdir(exist_ok=True)
    vvp_path = SIM_OUT / f"{name}.vvp"

    rtl_paths = [str(RTL_DIR / f) for f in rtl_files]
    tb_path = str(TB_DIR / tb_file)

    # Compile
    cmd = [IVERILOG] + IVERILOG_FLAGS + ["-o", str(vvp_path)] + rtl_paths + [tb_path]
    print(f"  Compiling: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT),
                            encoding="utf-8", errors="replace")
    if result.returncode != 0:
        print(f"  [COMPILE ERROR] {name}")
        print(result.stderr)
        return False

    # Run
    cmd = [VVP, str(vvp_path)]
    print(f"  Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True,
                            cwd=str(PROJECT_ROOT), timeout=60,
                            encoding="utf-8", errors="replace")
    if result.stdout:
        print(result.stdout)
    if result.returncode != 0:
        print(f"  [SIM ERROR] {name}")
        if result.stderr:
            print(result.stderr)
        return False

    # Check for PASS/FAIL
    stdout_str = result.stdout or ""
    if "ALL TESTS PASSED" in stdout_str or "INTEGRATION TESTS PASSED" in stdout_str:
        print(f"  [{name}] PASS PASSED")
        return True
    elif "ERRORS" in result.stdout:
        print(f"  [{name}] FAIL FAILED")
        return False
    else:
        print(f"  [{name}] WARN  UNKNOWN (check output)")
        return None


def main():
    import argparse
    parser = argparse.ArgumentParser(description="AXI Safety Island Test Runner")
    parser.add_argument("--level", choices=["module", "top", "fault", "all"],
                        default="module", help="Test level to run")
    args = parser.parse_args()

    print("=" * 60)
    print(f"  AXI Safety Island — Test Runner (level={args.level})")
    print(f"  Simulator: {IVERILOG}")
    print("=" * 60)

    tests_to_run = []
    if args.level in ("module", "all"):
        tests_to_run.extend(TEST_SUITES["module"])
    if args.level in ("top", "all"):
        tests_to_run.extend(TEST_SUITES["top"])
    if args.level in ("fault", "all"):
        tests_to_run.extend(TEST_SUITES["fault"])

    passed = 0
    failed = 0
    for test in tests_to_run:
        print(f"\n--- {test['name']} ---")
        result = run_test(test["name"], test["rtl"], test["tb"])
        if result is True:
            passed += 1
        elif result is False:
            failed += 1

    print(f"\n{'=' * 60}")
    print(f"  Results: {passed} passed, {failed} failed, "
          f"{len(tests_to_run) - passed - failed} unknown")
    print(f"{'=' * 60}")
    if args.level in ("module", "all"):
        print("Verification mode: module tests are required gates for fusion work.")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
