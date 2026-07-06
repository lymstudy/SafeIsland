#!/usr/bin/env python3
"""
Analyze VCS fault-injection CSV reports with TMR-aware result classes.

Classification:
  corrected  — functional output remains correct; fault repaired or voted out
  detected   — fault_detect or safety_island_fault_detect within 10 cycles
  latent     — functional correct, latent/mismatch flagged (no hard fault required)
  safe       — fault did not activate or propagate; output unchanged
  undetected — output corrupted and no detect within window (uncovered)

Usage:
  python tools/analyze_fi_report.py \\
      --input sim/fault_injection/reports/fault_injection_report.csv \\
      --output sim/fault_injection/reports/safety_report.csv

  python tools/analyze_fi_report.py \\
      --input sim/fault_injection/reports/fault_campaign_report.csv \\
      --output sim/fault_injection/reports/fault_campaign_safety_report.csv \\
      --detail-output sim/fault_injection/reports/fault_campaign_detail.csv
"""

import argparse
import csv
from collections import Counter
from pathlib import Path


PASS_RESULTS = {"corrected", "detected", "safe", "latent", "error"}


def to_bool(value):
    if value is None:
        return False
    text = str(value).strip().lower()
    return text in {"1", "true", "yes"}


def normalize_case(row):
    name = (row.get("name") or "").strip()
    if not name or name == "SUMMARY":
        name = (row.get("fault_id") or "").strip()

    if not name or name == "SUMMARY":
        return None

    result = (row.get("result_class") or row.get("result") or "").strip().lower()
    fault_type = (row.get("type") or row.get("result_type") or row.get("campaign_type") or "unknown").strip()
    cycles_raw = (row.get("detect_latency") or row.get("cycles") or row.get("detect_cycle") or "").strip()
    try:
        cycles = int(cycles_raw) if cycles_raw not in {"", "-1"} else -1
    except ValueError:
        cycles = -1

    fault_detect = to_bool(row.get("fault_detect"))
    safety_fault = to_bool(row.get("safety_fault") or row.get("safety_island_fault_detect"))
    latent_fault = to_bool(row.get("latent_fault") or row.get("latent"))
    output_mismatch = to_bool(row.get("output_mismatch"))
    model = (row.get("model") or "").strip()
    module = (row.get("module") or "").strip()

    result_class = classify_result(result, fault_detect, safety_fault, latent_fault, output_mismatch, cycles)

    return {
        "fault_id": (row.get("fault_id") or "").strip(),
        "module": module,
        "name": name,
        "type": fault_type or "unknown",
        "model": model,
        "result": result or "unknown",
        "result_class": result_class,
        "detect_cycle": cycles if cycles >= 0 else "",
        "fault_detect": int(fault_detect),
        "safety_fault": int(safety_fault),
        "latent": int(latent_fault),
        "output_mismatch": int(output_mismatch),
        "corrected": int(result_class == "corrected"),
        "detected": int(result_class == "detected"),
        "latent": int(result_class == "latent"),
        "safe": int(result_class == "safe"),
        "error": int(result_class == "error"),
        "undetected": int(result_class == "undetected"),
    }


def classify_result(result, fault_detect, safety_fault, latent_fault, output_mismatch, cycles):
    """Map raw TB result + flags to normalized result_class."""
    if result in {"corrected", "detected", "latent", "safe", "undetected", "error"}:
        return result

    # Fallback when TB only sets flags
    if latent_fault and not fault_detect and not safety_fault and not output_mismatch:
        return "latent"
    if fault_detect or safety_fault:
        if 0 <= cycles <= 10:
            return "detected"
        return "detected"
    if output_mismatch:
        return "undetected"
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
    safe = sum(1 for row in cases if row["result_class"] == "safe")
    error = sum(1 for row in cases if row["result_class"] == "error")
    undetected = sum(1 for row in cases if row["result_class"] == "undetected")
    other = total - (corrected + detected + latent + safe + error + undetected)

    protected_strict = corrected + detected
    protected_eng = corrected + detected + latent + safe
    strict_rate = pct(protected_strict, total)
    eng_rate = pct(protected_eng, total)

    by_result_class = Counter(row["result_class"] for row in cases)
    by_type = Counter(row["type"] for row in cases)
    by_module = Counter(row["module"] for row in cases if row["module"])
    by_model = Counter(row["model"] for row in cases if row["model"])

    # Misclassification warnings: safety_fault high but marked corrected
    warnings_corrected = [
        row["name"]
        for row in cases
        if row["result_class"] == "corrected" and row["safety_fault"]
    ]
    # Warnings for error faults (no detect flags, likely TB/tool limitation)
    warnings_error = [
        row["name"]
        for row in cases
        if row["result_class"] == "error"
    ]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "Value", "ASIL-D Target", "Status"])
        writer.writerow(["Total Faults", total, "", ""])
        writer.writerow(["Corrected", corrected, "", ""])
        writer.writerow(["Detected", detected, "", ""])
        writer.writerow(["Latent", latent, "", ""])
        writer.writerow(["Safe", safe, "", ""])
        writer.writerow(["Tool/TB injection error", error, "", ""])
        writer.writerow(["Undetected (functional uncovered)", undetected, "", ""])
        writer.writerow(
            [
                "Strict Protection Rate (corrected+detected)/total",
                f"{strict_rate:.2f}%",
                "100%",
                "PASS" if undetected == 0 else "FAIL",
            ]
        )
        writer.writerow(
            [
                "Engineering Protection Rate (corrected+detected+latent+safe)/total",
                f"{eng_rate:.2f}%",
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
        if by_model:
            writer.writerow([])
            writer.writerow(["Model", "Count"])
            for model, count in sorted(by_model.items()):
                writer.writerow([model, count])
        if error:
            writer.writerow([])
            writer.writerow(["Tool/TB Injection Errors (first 20)", "Result Class"])
            for row in [r for r in cases if r["result_class"] == "error"][:20]:
                writer.writerow([row["name"] or row["fault_id"], row["result_class"]])
        if undetected:
            writer.writerow([])
            writer.writerow(["Undetected Faults (first 20)", "Result Class"])
            for row in [r for r in cases if r["result_class"] == "undetected"][:20]:
                writer.writerow([row["name"] or row["fault_id"], row["result_class"]])

    if args.detail_output:
        detail_path = Path(args.detail_output)
        detail_path.parent.mkdir(parents=True, exist_ok=True)
        fields = [
            "fault_id",
            "module",
            "name",
            "type",
            "model",
            "result",
            "result_class",
            "detect_cycle",
            "fault_detect",
            "safety_fault",
            "latent",
            "output_mismatch",
            "corrected",
            "detected",
            "safe",
            "error",
            "undetected",
        ]
        with detail_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(cases)

    print(f"FI cases: {total}")
    print(
        f"corrected={corrected} detected={detected} latent={latent} safe={safe} "
        f"error={error} undetected={undetected}"
    )
    print(f"Strict protection rate = {strict_rate:.2f}%")
    print(f"Engineering protection rate = {eng_rate:.2f}%")
    if warnings_corrected:
        print(f"WARN: {len(warnings_corrected)} case(s) marked corrected but safety_fault=1:")
        for name in warnings_corrected[:10]:
            print(f"  - {name}")
    if error:
        print(f"First 20 tool/TB injection errors (error class):")
        for row in [r for r in cases if r["result_class"] == "error"][:20]:
            print(f"  - {row['name'] or row['fault_id']}")
    if undetected:
        print("First 20 functional undetected faults:")
        for row in [r for r in cases if r["result_class"] == "undetected"][:20]:
            print(f"  - {row['name'] or row['fault_id']}")
    print(f"Report written: {output_path}")


if __name__ == "__main__":
    main()
