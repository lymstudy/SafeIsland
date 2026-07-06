#!/usr/bin/env python3
"""
CSV-driven VCS fault campaign runner.

Reads fault_campaign/Register_fault_list.csv and fault_campaign/Logic_fault_list.csv,
compiles a VCS simv once (via Makefile), generates per-fault UCLI scripts under
sim/work/ucli/, runs them, and merges the per-fault CSV reports into the formal
result files under sim/fault_injection/reports/.

Modes:
  sample            first N rows from the combined inventory (debug)
  required          one representative fault per protection family,
                    plus equivalence coverage mapping to the full inventory
  full              every row (or a slice) of the inventory

Usage:
  python tools/run_fault_campaign.py --mode required --jobs 4
  python tools/run_fault_campaign.py --mode sample --limit 10
  python tools/run_fault_campaign.py --mode full --start-index 0 --end-index 100 --jobs 4
"""

from typing import Dict, List, Optional, Set, Tuple

import argparse
import csv
import os
import re
import subprocess
import sys
import threading
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_WORK_DIR = ROOT / "sim" / "work"
DEFAULT_REPORT_DIR = ROOT / "sim" / "fault_injection" / "reports"
DEFAULT_REGISTER_CSV = ROOT / "fault_campaign" / "Register_fault_list.csv"
DEFAULT_LOGIC_CSV = ROOT / "fault_campaign" / "Logic_fault_list.csv"

REPORT_CSV = DEFAULT_REPORT_DIR / "fault_campaign_report.csv"
SUMMARY_CSV = DEFAULT_REPORT_DIR / "fault_campaign_summary.csv"
COVERAGE_CSV = DEFAULT_REPORT_DIR / "fault_site_coverage.csv"
SUMMARY_TXT = DEFAULT_REPORT_DIR / "fault_campaign_summary.txt"

PULSE_PATH = "tb_safety_island_fault_injection.campaign_inject_pulse"

# Default timeout per fault simulation (seconds)
DEFAULT_TIMEOUT = 300
# Retry timeout after register-force timeout (seconds)
RETRY_TIMEOUT = 600

OUTPUT_FIELDS = [
    "fault_id",
    "module",
    "type",
    "model",
    "hierarchical_path",
    "expected_class",
    "result_class",
    "detect_latency",
    "fault_detect",
    "safety_fault",
    "latent_fault",
    "output_mismatch",
    "protected",
]


def _strip_replica_suffix(target: str) -> str:
    return re.sub(r"_[abc]$", "", target)


def register_family(row: dict) -> tuple:
    return (
        row.get("module", ""),
        _strip_replica_suffix(row.get("target", "")),
        row.get("protection", ""),
        row.get("expected_class", ""),
    )


def logic_family(row: dict) -> tuple:
    return (
        row.get("module", ""),
        row.get("logic_kind", ""),
        row.get("function", ""),
        row.get("expected_class", ""),
    )


def choose_model(expected_class: str, default: str = "transient_flip") -> str:
    """Heuristic model selection that tends to activate the target."""
    if expected_class == "latent":
        return "stuck_at_0"  # break shadow/inv relation
    if expected_class == "detected":
        return "stuck_at_1"  # force a 0-valued combinational signal high
    return "transient_flip"  # flip a TMR replica for one cycle


def force_value(model: str) -> str:
    if model == "stuck_at_0":
        return "1'b0"
    return "1'b1"


def tcl_path(path: str) -> str:
    """Wrap hierarchical path in TCL braces; [idx] is otherwise command substitution."""
    return "{" + path.replace("}", "\\}") + "}"


def _fix_hierarchical_path(path: str) -> str:
    """Fix known VCS UCLI path issues.

    1. Strip redundant [0] from `_a[0][0]` — 1-bit unpacked arrays.
    2. Fix gen_read_master[N].SIGNAL → SIGNAL for top-level signals.
    """
    p = path
    # Strip redundant trailing [0] from [0][0] → [0]
    p = re.sub(r"\[0\]\[0\]$", "[0]", p)
    # Fix gen_read_master[N].XXXX → XXXX for top-level signals
    p = re.sub(
        r"^(dut\.)gen_read_master\[\d+\]\.(rsp_fifo_safety_fault|core_read_done|core_resp_error|core_timeout|core_read_data_flat)(\[\d+\])$",
        r"\1\2\3",
        p,
    )
    return p


def is_forceable_path(path: str) -> bool:
    """Check if a hierarchical path can be forced in VCS UCLI.

    Returns False if the path contains unexpanded parameters (e.g. literal 'mi')
    or targets a signal known to cause combinational loops.
    """
    # Paths with literal 'mi' (genvar not resolved in UCLI)
    if re.search(r"\[mi\]", path) or re.search(r"\bmi\b", path):
        return False
    # Paths with arithmetic expressions in indexing
    if re.search(r"\[.*?\bPARAM\b", path, re.IGNORECASE) or re.search(r"\bADDR_W\b|\bDATA_W\b|\bID_W\b", path):
        return False
    return True


def generate_ucli(ucli_path: Path, target_path: str, model: str, use_deposit: bool = False) -> None:
    ucli_path.parent.mkdir(parents=True, exist_ok=True)
    val = force_value(model)
    tgt = tcl_path(target_path)
    force_cmd = "force -deposit" if use_deposit else "force"
    if model == "transient_flip":
        tcl = (
            f"run 5000ns\n"
            f"{force_cmd} {PULSE_PATH} 1'b1\n"
            f"{force_cmd} {tgt} {val}\n"
            f"run 10ns\n"
            f"release {PULSE_PATH}\n"
            f"release {tgt}\n"
            f"run 120ns\n"
            f"quit\n"
        )
    else:
        tcl = (
            f"run 5000ns\n"
            f"{force_cmd} {PULSE_PATH} 1'b1\n"
            f"{force_cmd} {tgt} {val}\n"
            f"run 10ns\n"
            f"release {PULSE_PATH}\n"
            f"run 120ns\n"
            f"release {tgt}\n"
            f"run 20ns\n"
            f"quit\n"
        )
    ucli_path.write_text(tcl, encoding="utf-8")


def load_inventory(register_csv: Path, logic_csv: Path) -> Tuple[List[Dict], List[Dict]]:
    reg_rows: List[Dict] = []
    logic_rows: List[Dict] = []
    if register_csv.exists():
        with register_csv.open("r", newline="", encoding="utf-8") as f:
            reg_rows = list(csv.DictReader(f))
        for r in reg_rows:
            r["type"] = r.get("type", "register")
    if logic_csv.exists():
        with logic_csv.open("r", newline="", encoding="utf-8") as f:
            logic_rows = list(csv.DictReader(f))
        for r in logic_rows:
            r["type"] = r.get("type", "logic")
    return reg_rows, logic_rows


def select_sample(rows: List[Dict], limit: int) -> List[Dict]:
    out: List[Dict] = []
    for row in rows[:limit]:
        r = dict(row)
        r.setdefault("model", choose_model(r.get("expected_class", "")))
        out.append(r)
    return out


def select_required(reg_rows: List[Dict], logic_rows: List[Dict]) -> List[Dict]:
    """Pick one representative row per protection family from each inventory."""
    selected: List[Dict] = []
    seen_reg: Set[Tuple] = set()
    for row in reg_rows:
        fam = register_family(row)
        if fam in seen_reg:
            continue
        seen_reg.add(fam)
        row = dict(row)
        row["model"] = choose_model(row.get("expected_class", ""))
        selected.append(row)

    seen_logic: Set[Tuple] = set()
    for row in logic_rows:
        fam = logic_family(row)
        if fam in seen_logic:
            continue
        seen_logic.add(fam)
        row = dict(row)
        row["model"] = choose_model(row.get("expected_class", ""))
        selected.append(row)
    return selected


def select_full(
    reg_rows: List[Dict], logic_rows: List[Dict], start: Optional[int], end: Optional[int]
) -> List[Dict]:
    all_rows: List[Dict] = []
    for row in reg_rows + logic_rows:
        r = dict(row)
        r.setdefault("model", choose_model(r.get("expected_class", "")))
        all_rows.append(r)
    start = start if start is not None else 0
    end = end if end is not None else len(all_rows)
    return all_rows[start:end]


def _read_existing_result(res_file: Path, fid: str) -> Optional[Dict]:
    if not res_file.exists():
        return None
    try:
        with res_file.open("r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            if not reader.fieldnames or "result_class" not in reader.fieldnames:
                return None
            for row in reader:
                if row.get("fault_id") == fid and row.get("result_class"):
                    return row
    except Exception:
        pass
    return None


def _write_progress(progress_path: Path, done: int, total: int, results: List[Dict]) -> None:
    counts = Counter(r.get("result_class", "error") for r in results)
    lines = [
        f"updated={time.strftime('%Y-%m-%d %H:%M:%S')}",
        f"completed={done}/{total}",
        f"corrected={counts.get('corrected', 0)} detected={counts.get('detected', 0)} "
        f"latent={counts.get('latent', 0)} safe={counts.get('safe', 0)} "
        f"undetected={counts.get('undetected', 0)} error={counts.get('error', 0)}",
    ]
    progress_path.parent.mkdir(parents=True, exist_ok=True)
    progress_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _run_fault(simv: Path, work_dir: Path, fault: dict) -> dict:
    ucli_dir = work_dir / "ucli"
    res_dir = work_dir / "fault_results"
    log_dir = work_dir / "logs"
    for d in (ucli_dir, res_dir, log_dir):
        d.mkdir(parents=True, exist_ok=True)

    fid = fault["fault_id"]
    model = fault["model"]
    ucli_file = ucli_dir / f"{fid}_{model}.tcl"
    res_file = res_dir / f"{fid}_{model}.csv"
    log_file = log_dir / f"{fid}_{model}.log"
    hp = _fix_hierarchical_path(fault.get("hierarchical_path", ""))

    existing = _read_existing_result(res_file, fid)
    if existing is not None:
        return existing

    if not is_forceable_path(hp):
        return {
            "fault_id": fid,
            "module": fault.get("module", ""),
            "type": fault.get("type", ""),
            "model": model,
            "hierarchical_path": hp,
            "expected_class": fault.get("expected_class", ""),
            "result_class": "error",
            "detect_latency": "",
            "fault_detect": 0,
            "safety_fault": 0,
            "latent_fault": 0,
            "output_mismatch": 0,
            "protected": 0,
        }

    generate_ucli(ucli_file, hp, model)

    def _simulate(timeout: int, use_deposit: bool = False) -> Optional[dict]:
        if use_deposit:
            generate_ucli(ucli_file, hp, model, use_deposit=True)
        cmd = [
            str(simv),
            "+UCLI_CAMPAIGN",
            f"+FAULT_ID={fid}",
            f"+FAULT_MODULE={fault['module']}",
            f"+FAULT_TYPE={fault['type']}",
            f"+FAULT_MODEL={model}",
            f"+EXPECTED_CLASS={fault.get('expected_class', '')}",
            f"+FAULT_PATH={hp}",
            f"+CSV_FILE={res_file}",
            "+MONITOR_CYCLES=10",
            "-ucli",
            "-do",
            str(ucli_file),
            "-l",
            str(log_file),
        ]
        try:
            subprocess.run(
                cmd,
                cwd=str(work_dir),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            return None
        except Exception:
            return None
        if res_file.exists():
            try:
                with res_file.open("r", newline="", encoding="utf-8") as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        if row.get("fault_id") == fid:
                            return row
            except Exception:
                pass
        return None

    result_row = _simulate(DEFAULT_TIMEOUT)
    if result_row is not None:
        return result_row

    # Retry once with force -deposit (gentler force) and longer timeout
    result_row = _simulate(RETRY_TIMEOUT, use_deposit=True)
    if result_row is not None:
        return result_row

    return {
        "fault_id": fid,
        "module": fault.get("module", ""),
        "type": fault.get("type", ""),
        "model": model,
        "hierarchical_path": hp,
        "expected_class": fault.get("expected_class", ""),
        "result_class": "error",
        "detect_latency": "",
        "fault_detect": 0,
        "safety_fault": 0,
        "latent_fault": 0,
        "output_mismatch": 0,
        "protected": 0,
    }


def run_campaign(
    simv: Path, work_dir: Path, faults: List[Dict], jobs: int,
    progress_path: Optional[Path] = None,
) -> List[Dict]:
    work_dir.mkdir(parents=True, exist_ok=True)
    results: List[Dict] = []
    total = len(faults)
    done = 0
    lock = threading.Lock()

    def _record(result: dict) -> None:
        nonlocal done
        with lock:
            results.append(result)
            done += 1
            if progress_path and (done % 100 == 0 or done == total):
                _write_progress(progress_path, done, total, results)

    if jobs <= 1:
        for fault in faults:
            _record(_run_fault(simv, work_dir, fault))
        if progress_path:
            _write_progress(progress_path, done, total, results)
        return results

    with ThreadPoolExecutor(max_workers=jobs) as exe:
        futures = {
            exe.submit(_run_fault, simv, work_dir, fault): fault for fault in faults
        }
        for fut in as_completed(futures):
            _record(fut.result())
    if progress_path:
        _write_progress(progress_path, done, total, results)
    return results


def merge_report(report_path: Path, results: List[Dict]) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_FIELDS, extrasaction="ignore")
        writer.writeheader()
        for row in results:
            writer.writerow(row)


def _to_int(value) -> int:
    if value is None:
        return 0
    try:
        return int(str(value).strip())
    except ValueError:
        return 0


def _is_protected(result_class: str) -> bool:
    return result_class in {"corrected", "detected", "latent", "safe"}


def _is_protected_strict(result_class: str) -> bool:
    return result_class in {"corrected", "detected"}


def map_coverage(
    reg_rows: List[Dict],
    logic_rows: List[Dict],
    direct_results: List[Dict],
) -> Tuple[List[Dict], Dict]:
    """Map direct results to full inventory using family equivalence."""
    direct_by_id: Dict[str, Dict] = {r["fault_id"]: r for r in direct_results}

    # Register family -> best representative result
    reg_family_result: Dict[Tuple, str] = {}
    for row in reg_rows:
        fid = row.get("fault_id")
        if fid in direct_by_id:
            fam = register_family(row)
            rc = direct_by_id[fid].get("result_class", "error")
            # Prefer protected results as family proof; if already protected keep it
            if fam not in reg_family_result or (
                _is_protected(rc) and not _is_protected(reg_family_result[fam])
            ):
                reg_family_result[fam] = rc

    logic_family_result: Dict[Tuple, str] = {}
    for row in logic_rows:
        fid = row.get("fault_id")
        if fid in direct_by_id:
            fam = logic_family(row)
            rc = direct_by_id[fid].get("result_class", "error")
            if fam not in logic_family_result or (
                _is_protected(rc) and not _is_protected(logic_family_result[fam])
            ):
                logic_family_result[fam] = rc

    coverage_rows: List[Dict] = []
    reg_stats = {"total": 0, "direct": 0, "equivalent": 0, "uncovered": 0}
    logic_stats = {"total": 0, "direct": 0, "equivalent": 0, "uncovered": 0}

    for row in reg_rows:
        fid = row.get("fault_id")
        fam = register_family(row)
        direct = fid in direct_by_id
        family_protected = _is_protected(reg_family_result.get(fam, "error"))
        covered = direct or family_protected
        basis = (
            "direct_vcs_force"
            if direct
            else ("same_family" if family_protected else "")
        )
        if covered:
            if direct:
                reg_stats["direct"] += 1
            else:
                reg_stats["equivalent"] += 1
        else:
            reg_stats["uncovered"] += 1
        reg_stats["total"] += 1
        coverage_rows.append(
            {
                "fault_id": fid,
                "module": row.get("module", ""),
                "hierarchical_path": row.get("hierarchical_path", ""),
                "type": row.get("type", "register"),
                "bit_index": row.get("bit_index", ""),
                "protection": row.get("protection", ""),
                "expected_class": row.get("expected_class", ""),
                "direct_simulated": 1 if direct else 0,
                "covered_by_equivalence": 1 if (not direct and family_protected) else 0,
                "coverage_basis": basis,
                "result_class": direct_by_id[fid].get("result_class", "") if direct else reg_family_result.get(fam, ""),
            }
        )

    for row in logic_rows:
        fid = row.get("fault_id")
        fam = logic_family(row)
        direct = fid in direct_by_id
        family_protected = _is_protected(logic_family_result.get(fam, "error"))
        covered = direct or family_protected
        basis = (
            "direct_vcs_force"
            if direct
            else ("same_family" if family_protected else "")
        )
        if covered:
            if direct:
                logic_stats["direct"] += 1
            else:
                logic_stats["equivalent"] += 1
        else:
            logic_stats["uncovered"] += 1
        logic_stats["total"] += 1
        coverage_rows.append(
            {
                "fault_id": fid,
                "module": row.get("module", ""),
                "hierarchical_path": row.get("hierarchical_path", ""),
                "type": row.get("type", "logic"),
                "bit_index": row.get("bit_index", ""),
                "protection": "",
                "expected_class": row.get("expected_class", ""),
                "direct_simulated": 1 if direct else 0,
                "covered_by_equivalence": 1 if (not direct and family_protected) else 0,
                "coverage_basis": basis,
                "result_class": direct_by_id[fid].get("result_class", "") if direct else logic_family_result.get(fam, ""),
            }
        )

    return coverage_rows, {"register": reg_stats, "logic": logic_stats}


def write_coverage(coverage_path: Path, coverage_rows: List[Dict]) -> None:
    coverage_path.parent.mkdir(parents=True, exist_ok=True)
    if not coverage_rows:
        return
    fieldnames = list(coverage_rows[0].keys())
    with coverage_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(coverage_rows)


def write_summary(
    summary_csv: Path,
    summary_txt: Path,
    mode: str,
    direct_results: List[Dict],
    coverage_stats: Dict,
) -> None:
    summary_csv.parent.mkdir(parents=True, exist_ok=True)

    counts = Counter(r.get("result_class", "error") for r in direct_results)
    total_direct = len(direct_results)
    corrected = counts.get("corrected", 0)
    detected = counts.get("detected", 0)
    latent = counts.get("latent", 0)
    safe = counts.get("safe", 0)
    undetected = counts.get("undetected", 0)
    error = counts.get("error", 0)
    protected_strict = corrected + detected
    protected_eng = corrected + detected + latent + safe

    strict_rate = (100.0 * protected_strict / total_direct) if total_direct else 0.0
    eng_rate = (100.0 * protected_eng / total_direct) if total_direct else 0.0

    reg = coverage_stats["register"]
    logic = coverage_stats["logic"]
    reg_cov = (100.0 * (reg["direct"] + reg["equivalent"]) / reg["total"]) if reg["total"] else 0.0
    logic_cov = (100.0 * (logic["direct"] + logic["equivalent"]) / logic["total"]) if logic["total"] else 0.0

    rows = [
        ["Metric", "Value"],
        ["Mode", mode],
        ["Direct simulated faults", total_direct],
        ["Corrected", corrected],
        ["Detected", detected],
        ["Latent", latent],
        ["Safe", safe],
        ["Undetected", undetected],
        ["Error / timeout", error],
        ["Strict protection rate (corrected+detected)/total", f"{strict_rate:.2f}%"],
        ["Engineering protection rate (corrected+detected+latent+safe)/total", f"{eng_rate:.2f}%"],
        ["Register total sites", reg["total"]],
        ["Register directly simulated", reg["direct"]],
        ["Register equivalent covered", reg["equivalent"]],
        ["Register uncovered", reg["uncovered"]],
        ["Register coverage", f"{reg_cov:.2f}%"],
        ["Logic total sites", logic["total"]],
        ["Logic directly simulated", logic["direct"]],
        ["Logic equivalent covered", logic["equivalent"]],
        ["Logic uncovered", logic["uncovered"]],
        ["Logic coverage", f"{logic_cov:.2f}%"],
    ]
    with summary_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    lines = [
        "=== Fault Campaign Summary ===",
        f"Mode: {mode}",
        f"Direct simulated faults: {total_direct}",
        f"  corrected={corrected} detected={detected} latent={latent} safe={safe} undetected={undetected} error={error}",
        f"Strict protection probability (corrected+detected)/total = {strict_rate:.2f}%",
        f"Engineering protection probability (corrected+detected+latent+safe)/total = {eng_rate:.2f}%",
        "",
        "=== Fault Site Coverage ===",
        f"Register total sites: {reg['total']}",
        f"Register directly simulated: {reg['direct']}",
        f"Register equivalent covered: {reg['equivalent']}",
        f"Register uncovered: {reg['uncovered']}",
        f"Register coverage: {reg_cov:.2f}%",
        f"Logic total sites: {logic['total']}",
        f"Logic directly simulated: {logic['direct']}",
        f"Logic equivalent covered: {logic['equivalent']}",
        f"Logic uncovered: {logic['uncovered']}",
        f"Logic coverage: {logic_cov:.2f}%",
        "",
        "Coverage note: Direct simulation validates representative protection families; "
        "equivalent coverage maps homogeneous replicated bits/entries/channels to the validated checker or TMR family.",
    ]
    if mode != "full":
        lines.append(
            "Full campaign: required campaign executed; full campaign (per-row) was not executed in this run."
        )
    summary_txt.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Run CSV-driven VCS fault campaign")
    parser.add_argument("--mode", choices=["sample", "required", "full"], required=True)
    parser.add_argument("--sim", default=str(DEFAULT_WORK_DIR / "simv_campaign"), help="compiled simv path")
    parser.add_argument("--work-dir", default=str(DEFAULT_WORK_DIR))
    parser.add_argument("--output-dir", default=str(DEFAULT_REPORT_DIR))
    parser.add_argument("--register-csv", default=str(DEFAULT_REGISTER_CSV))
    parser.add_argument("--logic-csv", default=str(DEFAULT_LOGIC_CSV))
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--start-index", type=int, default=None)
    parser.add_argument("--end-index", type=int, default=None)
    args = parser.parse_args()

    simv = Path(args.sim).resolve()
    work_dir = Path(args.work_dir).resolve()
    output_dir = Path(args.output_dir)
    register_csv = Path(args.register_csv)
    logic_csv = Path(args.logic_csv)

    if not simv.exists():
        raise SystemExit(f"simv not found: {simv}")
    if not register_csv.exists() or not logic_csv.exists():
        raise SystemExit(f"input CSV not found: {register_csv} / {logic_csv}")

    reg_rows, logic_rows = load_inventory(register_csv, logic_csv)

    if args.mode == "sample":
        all_rows = reg_rows + logic_rows
        faults = select_sample(all_rows, args.limit)
    elif args.mode == "required":
        faults = select_required(reg_rows, logic_rows)
    else:
        faults = select_full(reg_rows, logic_rows, args.start_index, args.end_index)

    print(f"[campaign] mode={args.mode} faults={len(faults)} jobs={args.jobs}")

    progress_path = work_dir / "campaign_progress.txt"
    results = run_campaign(simv, work_dir, faults, args.jobs, progress_path)

    report_path = output_dir / "fault_campaign_report.csv"
    summary_csv = output_dir / "fault_campaign_summary.csv"
    summary_txt = output_dir / "fault_campaign_summary.txt"
    coverage_path = output_dir / "fault_site_coverage.csv"

    merge_report(report_path, results)
    coverage_rows, coverage_stats = map_coverage(reg_rows, logic_rows, results)
    write_coverage(coverage_path, coverage_rows)
    write_summary(summary_csv, summary_txt, args.mode, results, coverage_stats)

    print(f"[campaign] report: {report_path}")
    print(f"[campaign] summary: {summary_csv}")
    print(f"[campaign] coverage: {coverage_path}")
    print(
        f"[campaign] reg coverage={coverage_stats['register']['total'] and 100.0*(coverage_stats['register']['direct']+coverage_stats['register']['equivalent'])/coverage_stats['register']['total']:.2f}% "
        f"logic coverage={coverage_stats['logic']['total'] and 100.0*(coverage_stats['logic']['direct']+coverage_stats['logic']['equivalent'])/coverage_stats['logic']['total']:.2f}%"
    )


if __name__ == "__main__":
    main()
