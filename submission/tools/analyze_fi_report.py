#!/usr/bin/env python3
"""
Analyze ModelSim fault-injection CSV reports.

Usage:
  python tools/analyze_fi_report.py \
      --input sim/out/safety_island_fault_injection/fault_injection_report.csv \
      --output fault_campaign/safety_report.csv

  python tools/analyze_fi_report.py \
      --input sim/out/safety_island_fault_sweep/fault_sweep_report.csv \
      --output fault_campaign/safety_sweep_report.csv
"""

import argparse
import csv
from collections import Counter
from pathlib import Path


PASS_RESULTS = {"corrected", "detected", "safe"}


def normalize_case(row):
    result = (row.get("result") or "").strip()
    name = (row.get("name") or "").strip()
    if not name or name == "SUMMARY":
        return None

    fault_type = (row.get("type") or row.get("result_type") or row.get("campaign_type") or "unknown").strip()
    campaign_type = (row.get("campaign_type") or row.get("type") or "").strip()
    return {
        "fault_id": (row.get("fault_id") or "").strip(),
        "module": (row.get("module") or "").strip(),
        "name": name,
        "type": fault_type or "unknown",
        "campaign_type": campaign_type or fault_type or "unknown",
        "result": result or "unknown",
    }


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
        default="fault_campaign/safety_report.csv",
        help="summary CSV path",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.exists():
        raise SystemExit(f"input not found: {input_path}")

    cases = read_cases(input_path)
    total = len(cases)
    passed = sum(1 for row in cases if row["result"] in PASS_RESULTS)
    detected = sum(1 for row in cases if row["result"] == "detected")
    corrected = sum(1 for row in cases if row["result"] == "corrected")
    safe = sum(1 for row in cases if row["result"] == "safe")
    undetected = total - passed
    by_type = Counter(row["type"] for row in cases)
    by_campaign_type = Counter(row["campaign_type"] for row in cases)
    by_module = Counter(row["module"] for row in cases if row["module"])
    by_result = Counter(row["result"] for row in cases)
    diagnostic_coverage = pct(passed, total)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "Value", "ASIL-D Target", "Status"])
        writer.writerow(["Total Faults", total, "", ""])
        writer.writerow(["Detected", detected, "", ""])
        writer.writerow(["Corrected", corrected, "", ""])
        writer.writerow(["Safe / No effect", safe, "", ""])
        writer.writerow(["Undetected", undetected, "", ""])
        writer.writerow(
            [
                "Campaign Diagnostic Coverage",
                f"{diagnostic_coverage:.2f}%",
                "",
                "PASS" if undetected == 0 else "FAIL",
            ]
        )
        writer.writerow(["SPFM formal calculation", "Not derived from campaign alone", ">= 99.00%", "N/A"])
        writer.writerow(["LFM formal calculation", "Not derived from campaign alone", ">= 90.00%", "N/A"])
        writer.writerow([])
        writer.writerow(["Result", "Count"])
        for result, count in sorted(by_result.items()):
            writer.writerow([result, count])
        writer.writerow([])
        writer.writerow(["Type", "Count"])
        for fault_type, count in sorted(by_type.items()):
            writer.writerow([fault_type, count])
        if by_campaign_type and by_campaign_type != by_type:
            writer.writerow([])
            writer.writerow(["Campaign Type", "Count"])
            for fault_type, count in sorted(by_campaign_type.items()):
                writer.writerow([fault_type, count])
        if by_module:
            writer.writerow([])
            writer.writerow(["Module", "Count"])
            for module, count in sorted(by_module.items()):
                writer.writerow([module, count])

    print(f"FI cases: {total}")
    print(f"Detected: {detected}, corrected: {corrected}, safe: {safe}, undetected: {undetected}")
    print(f"Campaign diagnostic coverage: {diagnostic_coverage:.2f}%")
    print("By result:")
    for result, count in sorted(by_result.items()):
        print(f"  {result}: {count}")
    print("By type:")
    for fault_type, count in sorted(by_type.items()):
        print(f"  {fault_type}: {count}")
    if by_campaign_type and by_campaign_type != by_type:
        print("By campaign type:")
        for fault_type, count in sorted(by_campaign_type.items()):
            print(f"  {fault_type}: {count}")
    if by_module:
        print("By module:")
        for module, count in sorted(by_module.items()):
            print(f"  {module}: {count}")
    print(f"Report written: {output_path}")


if __name__ == "__main__":
    main()
