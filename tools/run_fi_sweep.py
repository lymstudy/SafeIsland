#!/usr/bin/env python3
"""
Run the ModelSim fault-injection testbench one fault at a time.

Rows without fault_kind use the fixed FAULT_INDEX dispatcher in
tb_safety_island_fault_injection.v. Rows with fault_kind and bit_index use the
bit-level dispatcher (+FAULT_KIND/+BIT_INDEX). The runner compiles the design
once, then runs one vsim process per row and merges the generated CSV rows into
one report.
"""

import argparse
import csv
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RTL_DIR = ROOT / "rtl"
TB_DIR = ROOT / "tb"
DEFAULT_VSIM = r"D:\software\modelism\MODELISM\win64\vsim.exe"
ARRAY_BIT_KINDS = {
    "cfg_base_addr_inv_q0",
    "cfg_offset_inv_q0",
    "cfg_mask_inv_q0",
    "cfg_expected_inv_q0",
    "top_rsp_data_inv_q0",
    "read_engine_slot_accum_inv_q0",
}


def run(cmd, cwd, timeout=120, quiet=False):
    if not quiet:
        print(" ".join(str(x) for x in cmd))
    result = subprocess.run(
        [str(x) for x in cmd],
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        encoding="utf-8",
        errors="replace",
    )
    if result.stdout and not quiet:
        print(result.stdout)
    if result.returncode != 0:
        if result.stdout and quiet:
            print(result.stdout)
        raise RuntimeError(f"command failed with {result.returncode}: {' '.join(map(str, cmd))}")
    return result.stdout or ""


def ms_path(path):
    return Path(path).as_posix()


def modelsim_tool(vsim, name):
    vsim_path = Path(vsim)
    candidate = vsim_path.with_name(f"{name}.exe")
    if candidate.exists():
        return candidate
    return name


def needs_array_bit_targets(faults):
    return any((row.get("fault_kind") or "").strip() in ARRAY_BIT_KINDS for row in faults)


def compile_design(vsim, sim_dir, work_dir, enable_array_bit_targets=False, quiet=False):
    if sim_dir.exists():
        shutil.rmtree(sim_dir)
    sim_dir.mkdir(parents=True)

    vlib = modelsim_tool(vsim, "vlib")
    vmap = modelsim_tool(vsim, "vmap")
    vlog = modelsim_tool(vsim, "vlog")
    run([vlib, ms_path(work_dir)], ROOT, quiet=quiet)
    run([vmap, "work", ms_path(work_dir)], ROOT, quiet=quiet)
    run([vlog, "-work", ms_path(work_dir), "-f", "safety_island_top.f"], RTL_DIR, quiet=quiet)
    tb_cmd = [vlog, "-work", ms_path(work_dir)]
    if enable_array_bit_targets:
        tb_cmd.append("+define+FI_ARRAY_BIT_TARGETS")
    tb_cmd.append(ms_path(TB_DIR / "tb_safety_island_fault_injection.v"))
    run(tb_cmd, ROOT, quiet=quiet)


def validate_sim_dir(sim_dir):
    sim_out = (ROOT / "sim" / "out").resolve()
    resolved = sim_dir.resolve()
    if resolved == sim_out or sim_out not in resolved.parents:
        raise SystemExit(f"unsafe output directory for sweep workspace: {sim_dir}")


def read_faults(path, limit=None):
    with path.open("r", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if limit is not None:
        rows = rows[:limit]
    return rows


def case_name(row, index):
    raw = f"{index:04d}_{row.get('fault_id', 'fault')}"
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", raw)


def run_fault(vsim, row, index, sim_dir, work_dir, quiet=False):
    case_dir = sim_dir / case_name(row, index)
    case_dir.mkdir(parents=True, exist_ok=True)
    summary = case_dir / "summary.txt"
    report = case_dir / "report.csv"
    wlf = case_dir / "wave.wlf"
    fault_kind = (row.get("fault_kind") or "").strip()
    bit_index = (row.get("bit_index") or "").strip()
    fault_args = []
    if fault_kind:
        fault_args.extend([f"+FAULT_KIND={fault_kind}", f"+BIT_INDEX={bit_index or 0}"])
    else:
        fault_args.append(f"+FAULT_INDEX={index}")
    stdout = run(
        [
            vsim,
            "-c",
            "-lib",
            ms_path(work_dir),
            "-voptargs=+acc",
            "-wlf",
            ms_path(wlf),
            "tb_safety_island_fault_injection",
            *fault_args,
            f"+SUMMARY_FILE={ms_path(summary)}",
            f"+CSV_FILE={ms_path(report)}",
            "-do",
            "run -all; quit -f",
        ],
        ROOT,
        timeout=120,
        quiet=quiet,
    )
    passed = "PASS: safety_island fault injection campaign completed" in stdout
    return passed, report


def merge_reports(faults, reports, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "fault_id",
            "module",
            "hierarchical_path",
            "campaign_type",
            "fault_kind",
            "bit_index",
            "name",
            "result_type",
            "result",
            "cycles",
            "error_code",
            "fault_detect",
            "safety_fault",
            "latent_fault",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row, report in zip(faults, reports):
            with report.open("r", newline="", encoding="utf-8") as rf:
                reader = csv.DictReader(rf)
                case_rows = [r for r in reader if r.get("name") and r.get("name") != "SUMMARY"]
            if not case_rows:
                writer.writerow(
                    {
                        "fault_id": row["fault_id"],
                        "module": row["module"],
                        "hierarchical_path": row["hierarchical_path"],
                        "campaign_type": row["type"],
                        "fault_kind": row.get("fault_kind", ""),
                        "bit_index": row.get("bit_index", ""),
                        "name": "",
                        "result_type": "",
                        "result": "runner_error",
                        "cycles": -1,
                        "error_code": "",
                        "fault_detect": "",
                        "safety_fault": "",
                        "latent_fault": "",
                    }
                )
                continue
            case = case_rows[0]
            writer.writerow(
                {
                    "fault_id": row["fault_id"],
                    "module": row["module"],
                    "hierarchical_path": row["hierarchical_path"],
                    "campaign_type": row["type"],
                    "fault_kind": row.get("fault_kind", ""),
                    "bit_index": row.get("bit_index", ""),
                    "name": case["name"],
                    "result_type": case["type"],
                    "result": case["result"],
                    "cycles": case["cycles"],
                    "error_code": case["error_code"],
                    "fault_detect": case["fault_detect"],
                    "safety_fault": case["safety_fault"],
                    "latent_fault": case["latent_fault"],
                }
            )


def main():
    parser = argparse.ArgumentParser(description="Run FI sweep")
    parser.add_argument("--fault-list", default="fault_campaign/fault_list.csv")
    parser.add_argument("--output", default="sim/out/safety_island_fault_sweep/fault_sweep_report.csv")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--vsim", default=DEFAULT_VSIM)
    parser.add_argument("--quiet", action="store_true", help="suppress passing simulator stdout")
    args = parser.parse_args()

    fault_list = ROOT / args.fault_list
    faults = read_faults(fault_list, args.limit)
    output = ROOT / args.output
    sim_dir = output.parent
    work_dir = sim_dir / "work"
    validate_sim_dir(sim_dir)
    compile_design(args.vsim, sim_dir, work_dir, needs_array_bit_targets(faults), args.quiet)

    reports = []
    failed = 0
    for index, row in enumerate(faults, start=1):
        print(f"=== FI {index}/{len(faults)} {row['fault_id']} {row['module']} ===")
        passed, report = run_fault(args.vsim, row, index, sim_dir, work_dir, args.quiet)
        reports.append(report)
        if not passed:
            failed += 1

    merge_reports(faults, reports, output)

    print(f"Sweep cases: {len(faults)}")
    print(f"Runner failures: {failed}")
    print(f"Merged report: {output}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
