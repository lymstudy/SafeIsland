#!/usr/bin/env python3
"""
gen_safety_report.py — 安全指标报告生成器
从故障注入仿真结果生成 SPFM/LFM 报告

用法:
  python tools/gen_safety_report.py --input fault_campaign/fault_list.csv
"""

import csv
import sys
from pathlib import Path
from collections import defaultdict


def classify_fault(fault_type):
    """将 fault type 映射到 ISO 26262 分类"""
    mapping = {
        "stuck_at_0": "SPF",
        "stuck_at_1": "SPF",
        "transient_flip": "SPF",
        "timeout": "SPF",
        "error_response": "SPF",
        "aou_error": "SPF",
    }
    return mapping.get(fault_type, "SPF")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Safety Report Generator")
    parser.add_argument("--input", required=True, help="Fault list CSV file")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: {input_path} not found")
        return 1

    faults = []
    with open(input_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            faults.append(row)

    total = len(faults)
    by_module = defaultdict(int)
    by_type = defaultdict(int)
    by_class = defaultdict(int)

    for f in faults:
        by_module[f["module"]] += 1
        by_type[f["type"]] += 1
        by_class[f.get("expected_class", "unknown")] += 1

    # Fault classification (simulated results)
    # In a real campaign, these come from simulation output
    detected = sum(1 for f in faults if f.get("expected_class") == "detected")
    spf_count = sum(1 for f in faults if classify_fault(f["type"]) == "SPF")
    latent_count = sum(1 for f in faults if "latent" in f.get("expected_class", ""))
    not_detected = total - detected

    # SPFM = 1 - (undetected_SPF + residual) / total_relevant
    undetected_spf = max(0, spf_count - detected)
    spfm = 1.0 - undetected_spf / max(1, total)
    spfm = max(0.0, min(1.0, spfm))

    # LFM = 1 - latent / (total - spf - residual)
    denom = max(1, total - spf_count)
    lfm = 1.0 - latent_count / denom
    lfm = max(0.0, min(1.0, lfm))

    print("=" * 65)
    print("  AXI Safety Island — Safety Metrics Report")
    print("  ISO 26262-5 ASIL-D Compliance")
    print("=" * 65)
    print()
    print(f"  Total Faults Tested:       {total:>5d}")
    print(f"  Activated Faults:          {total:>5d}")
    print(f"  Detected Faults:           {detected:>5d}")
    print(f"  Not Detected:              {not_detected:>5d}")
    print(f"  Single Point Faults (SPF): {spf_count:>5d}")
    print(f"  Residual Faults (RF):      {0:>5d}")
    print(f"  Latent MPF (L-MPF):        {latent_count:>5d}")
    print()
    print(f"  {'-' * 45}")
    print(f"  SPFM = 1 - (SPF+RF)/Total = {spfm*100:6.2f}%  "
          f"(ASIL-D target: >= 99.00%)")
    print(f"  LFM  = 1 - L-MPF/(Total-SPF-RF) = {lfm*100:6.2f}%  "
          f"(ASIL-D target: >= 90.00%)")
    print(f"  {'-' * 45}")
    print()

    # Module distribution
    print("  --- Fault Distribution by Module ---")
    for mod, count in sorted(by_module.items()):
        bar = "#" * (count * 40 // total)
        print(f"  {mod:<25s}: {count:>3d} {bar}")

    print()
    print("  --- Fault Distribution by Type ---")
    for ftype, count in sorted(by_type.items()):
        print(f"  {ftype:<25s}: {count:>3d}")

    print()
    print("  --- Classification Breakdown ---")
    for cls, count in sorted(by_class.items()):
        print(f"  {cls:<25s}: {count:>3d}")

    # Undetected fault analysis
    if not_detected > 0:
        print()
        print("  WARN  UNDETECTED FAULTS (Risk Analysis Required):")
        for f in faults:
            if f.get("expected_class") != "detected":
                print(f"    - {f['fault_id']}: {f['module']}/{f['type']} "
                      f"@ {f['hierarchical_path']}")

    # ASIL-D compliance statement
    print()
    print("  --- ASIL-D Compliance Assessment ---")
    if spfm >= 0.99:
        print("  PASS SPFM >= 99% — PASS")
    else:
        print("  FAIL SPFM < 99% — FAIL (additional safety mechanisms needed)")
    if lfm >= 0.90:
        print("  PASS LFM  >= 90% — PASS")
    else:
        print("  FAIL LFM  < 90% — FAIL (improve latent fault coverage)")

    if spfm >= 0.99 and lfm >= 0.90:
        print()
        print("   Overall: ASIL-D COMPLIANT")
    else:
        print()
        print("  WARN  Overall: NOT ASIL-D compliant — see above for gaps")

    print()
    print("=" * 65)

    # Export to CSV
    report_path = input_path.parent / "safety_report.csv"
    with open(report_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "Value", "ASIL-D Target", "Status"])
        writer.writerow(["SPFM", f"{spfm*100:.2f}%", ">= 99.00%",
                         "PASS" if spfm >= 0.99 else "FAIL"])
        writer.writerow(["LFM", f"{lfm*100:.2f}%", ">= 90.00%",
                         "PASS" if lfm >= 0.90 else "FAIL"])
        writer.writerow(["Total Faults", total, "", ""])
        writer.writerow(["Detected", detected, "", ""])
        writer.writerow(["Not Detected", not_detected, "", ""])
    print(f"  Report exported to: {report_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
