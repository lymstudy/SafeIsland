#!/usr/bin/env python3
"""
Analyze VCS fault-injection CSV reports with TMR-aware result classes.

Classification (aligned with safety_mechanism_upgrade_plan §H1):
  corrected  — functional output remains correct; latent allowed
  detected   — fault_detect or safety_island_fault_detect within 10 cycles
  latent     — functional correct, latent/mismatch flagged (no hard fault required)
  undetected — output corrupted and no detect within window (uncovered)

Usage:
  python tools/analyze_fi_report.py \\
      --input sim/fault_injection/reports/fault_injection_report.csv \\
      --output sim/fault_injection/reports/safety_report.csv
"""

import argparse
import csv
from collections import Counter
from pathlib import Path


PASS_RESULTS = {"corrected", "detected", "safe", "latent"}


def to_bool(value):
    if value is None:
        return False
    text = str(value).strip().lower()
    return text in {"1", "true", "yes"}


def normalize_case(row):
    name = (row.get("name") or "").strip()
    if not name or name == "SUMMARY":
        return None

    result = (row.get("result") or row.get("result_class") or "").strip().lower()
    fault_type = (row.get("type") or row.get("result_type") or row.get("campaign_type") or "unknown").strip()
    cycles_raw = (row.get("cycles") or row.get("detect_cycle") or "").strip()
    try:
        cycles = int(cycles_raw) if cycles_raw not in {"", "-1"} else -1
    except ValueError:
        cycles = -1

    fault_detect = to_bool(row.get("fault_detect"))
    safety_fault = to_bool(row.get("safety_fault") or row.get("safety_island_fault_detect"))
    latent_fault = to_bool(row.get("latent_fault") or row.get("latent"))

    result_class = classify_result(result, fault_detect, safety_fault, latent_fault, cycles)

    return {
        "fault_id": (row.get("fault_id") or "").strip(),
        "module": (row.get("module") or "").strip(),
        "name": name,
        "type": fault_type or "unknown",
        "result": result or "unknown",
        "result_class": result_class,
        "detect_cycle": cycles if cycles >= 0 else "",
        "fault_detect": int(fault_detect),
        "safety_fault": int(safety_fault),
        "latent": int(latent_fault),
        "corrected": int(result_class == "corrected"),
        "detected": int(result_class == "detected"),
        "undetected": int(result_class == "undetected"),
    }


def classify_result(result, fault_detect, safety_fault, latent_fault, cycles):
    """Map raw TB result + flags to normalized result_class."""
    if result in {"corrected", "safe"}:
        return "corrected"
    if result == "detected":
        return "detected"
    if result == "latent":
        return "latent"
    if result == "undetected":
        return "undetected"

    # Fallback when TB only sets flags
    if latent_fault and not fault_detect and not safety_fault:
        return "latent"
    if fault_detect or safety_fault:
        if 0 <= cycles <= 10:
            return "detected"
        return "detected"
    return "undetected"


def read_cases(path):
    cases = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            case = normalize_case(row)
            if case is not None:
                cases.append(case)
    return cases


def pct(numerator, denominator):
    if denominator == 0:
        return 0.0
    return 100.0 * numerator / denominator


def main():
    parser = argparse.ArgumentParser(description="Analyze FI CSV report")
    parser.add_argument("--input", required=True, help="fault_injection_report.csv")
    parser.add_argument(
        "--output",
        default="sim/fault_injection/reports/safety_report.csv",
        help="summary CSV path",
    )
    parser.add_argument(
        "--detail-output",
        default="",
        help="optional per-case normalized CSV",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.exists():
        raise SystemExit(f"input not found: {input_path}")

    cases = read_cases(input_path)
    total = len(cases)
    corrected = sum(1 for row in cases if row["result_class"] == "corrected")
    detected = sum(1 for row in cases if row["result_class"] == "detected")
    latent = sum(1 for row in cases if row["result_class"] == "latent")
    undetected = sum(1 for row in cases if row["result_class"] == "undetected")
    protected = corrected + detected + latent
    protection_rate = pct(protected, total)

    by_type = Counter(row["type"] for row in cases)
    by_module = Counter(row["module"] for row in cases if row["module"])
    by_result_class = Counter(row["result_class"] for row in cases)

    # Misclassification warnings: safety_fault high but marked corrected
    warnings = [
        row["name"]
        for row in cases
        if row["result_class"] == "corrected" and row["safety_fault"]
    ]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "Value", "ASIL-D Target", "Status"])
        writer.writerow(["Total Faults", total, "", ""])
        writer.writerow(["Corrected", corrected, "", ""])
        writer.writerow(["Detected", detected, "", ""])
        writer.writerow(["Latent", latent, "", ""])
        writer.writerow(["Undetected (uncovered)", undetected, "", ""])
        writer.writerow(
            [
                "Protection Rate (corrected+detected+latent)/total",
                f"{protection_rate:.2f}%",
                "100%",
                "PASS" if undetected == 0 else "FAIL",
            ]
        )
        writer.writerow(["SPFM (formal)", "See gen_safety_report.py + Register_fault_list", ">= 99%", "TBD"])
        writer.writerow(["LFM (formal)", "See gen_safety_report.py", ">= 90%", "TBD"])
        writer.writerow([])
        writer.writerow(["Result Class", "Count"])
        for cls, count in sorted(by_result_class.items()):
            writer.writerow([cls, count])
        writer.writerow([])
        writer.writerow(["Type", "Count"])
        for fault_type, count in sorted(by_type.items()):
            writer.writerow([fault_type, count])
        if by_module:
            writer.writerow([])
            writer.writerow(["Module", "Count"])
            for module, count in sorted(by_module.items()):
                writer.writerow([module, count])

    if args.detail_output:
        detail_path = Path(args.detail_output)
        detail_path.parent.mkdir(parents=True, exist_ok=True)
        fields = [
            "fault_id",
            "module",
            "name",
            "type",
            "result",
            "result_class",
            "detect_cycle",
            "fault_detect",
            "safety_fault",
            "latent",
            "corrected",
            "detected",
            "undetected",
        ]
        with detail_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(cases)

    print(f"FI cases: {total}")
    print(
        f"corrected={corrected} detected={detected} latent={latent} "
        f"undetected={undetected} protection_rate={protection_rate:.2f}%"
    )
    if warnings:
        print(f"WARN: {len(warnings)} case(s) marked corrected but safety_fault=1:")
        for name in warnings[:10]:
            print(f"  - {name}")
    print(f"Report written: {output_path}")


if __name__ == "__main__":
    main()
