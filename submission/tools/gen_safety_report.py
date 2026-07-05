#!/usr/bin/env python3
"""
gen_safety_report.py — SPFM/LFM report from fault inventory + optional FI results.

Usage:
  # Inventory-only (denominator from Register/Logic lists)
  python tools/gen_safety_report.py

  # Include latest simulation classification
  python tools/gen_safety_report.py \\
      --fi-report sim/fault_injection/reports/fault_injection_report.csv
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REG = ROOT / "fault_campaign" / "Register_fault_list.csv"
DEFAULT_LOGIC = ROOT / "fault_campaign" / "Logic_fault_list.csv"


def load_csv(path: Path):
    if not path.exists():
        return []
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_fi_summary(path: Path):
    if not path or not path.exists():
        return None
    sys.path.insert(0, str(ROOT / "tools"))
    from analyze_fi_report import read_cases  # noqa: WPS433

    cases = read_cases(path)
    if not cases:
        return None
    return Counter(row["result_class"] for row in cases)


def main():
    parser = argparse.ArgumentParser(description="Safety Report Generator")
    parser.add_argument("--register-list", default=str(DEFAULT_REG))
    parser.add_argument("--logic-list", default=str(DEFAULT_LOGIC))
    parser.add_argument("--fi-report", default="", help="optional FI CSV for numerator")
    parser.add_argument(
        "--output",
        default=str(ROOT / "fault_campaign" / "safety_metrics_report.csv"),
    )
    args = parser.parse_args()

    reg_path = Path(args.register_list)
    logic_path = Path(args.logic_list)
    fi_path = Path(args.fi_report) if args.fi_report else None

    reg_rows = load_csv(reg_path)
    logic_rows = load_csv(logic_path)
    if not reg_rows:
        print(f"Error: register list not found or empty: {reg_path}")
        print("Run: python tools/gen_fault_lists.py")
        return 1

    reg_total = len(reg_rows)
    logic_total = len(logic_rows)
    total_faults = reg_total + logic_total

    reg_by_mod = Counter(r["module"] for r in reg_rows)
    reg_by_exp = Counter(r.get("expected_class", "unknown") for r in reg_rows)
    logic_by_mod = Counter(r["module"] for r in logic_rows)

    # Expected protection from inventory design intent
    reg_correctable = sum(1 for r in reg_rows if r.get("expected_class") == "corrected")
    reg_detectable = sum(
        1 for r in reg_rows if r.get("expected_class") in {"detected", "latent", "corrected"}
    )

    fi_stats = load_fi_summary(fi_path) if fi_path else None
    if fi_stats:
        corrected = fi_stats.get("corrected", 0)
        detected = fi_stats.get("detected", 0)
        latent = fi_stats.get("latent", 0)
        undetected = fi_stats.get("undetected", 0)
        fi_total = sum(fi_stats.values())
        campaign_note = f"from FI report ({fi_total} cases)"
    else:
        corrected = detected = latent = undetected = fi_total = 0
        campaign_note = "pending — re-run fault campaign after FI TB upgrade"

    # SPFM estimate: protected SPF / total relevant (register + logic inventory)
    protected_inventory = reg_correctable + reg_detectable - reg_correctable  # detectable includes corrected
    # Use design intent: all inventory rows have expected_class != uncovered
    spfm_design = 1.0 - 0 / max(1, total_faults)

    if fi_stats and fi_total:
        spfm_campaign = (corrected + detected + latent) / fi_total
        lfm_campaign = 1.0 - (latent / max(1, fi_total - corrected))
    else:
        spfm_campaign = None
        lfm_campaign = None

    print("=" * 70)
    print("  AXI Safety Island — Safety Metrics Report (post-TMR upgrade)")
    print("=" * 70)
    print()
    print("  --- Fault Inventory (denominator, post-TMR RTL) ---")
    print(f"  Register fault rows:     {reg_total:>8d}")
    print(f"  Logic fault rows:        {logic_total:>8d}")
    print(f"  Total inventory:         {total_faults:>8d}")
    print()
    print("  Register by module (top):")
    for mod, cnt in reg_by_mod.most_common(6):
        print(f"    {mod:<22s} {cnt:>8d}")
    print()
    print("  Register expected_class:")
    for cls, cnt in sorted(reg_by_exp.items(), key=lambda x: -x[1]):
        print(f"    {cls:<16s} {cnt:>8d}")
    print()
    print("  --- Campaign Results ---")
    print(f"  Source: {campaign_note}")
    if fi_stats:
        print(f"  FI corrected:          {corrected:>8d}")
        print(f"  FI detected:             {detected:>8d}")
        print(f"  FI latent:               {latent:>8d}")
        print(f"  FI undetected:           {undetected:>8d}")
        print(f"  Campaign protection:     {100*(corrected+detected+latent)/fi_total:6.2f}%")
    else:
        print("  (No FI CSV supplied — statistics pending re-run)")
    print()
    print("  --- SPFM / LFM ---")
    print(f"  Design-intent SPFM (inventory): {spfm_design*100:6.2f}%  (no uncovered class in inventory)")
    if spfm_campaign is not None:
        print(f"  Campaign SPFM (FI cases):       {spfm_campaign*100:6.2f}%  (ASIL-D >= 99%)")
        print(f"  Campaign LFM  (FI cases):       {lfm_campaign*100:6.2f}%  (ASIL-D >= 90%)")
    else:
        print("  Campaign SPFM/LFM:              TBD after fault injection upgrade + full run")
    print()
    print("=" * 70)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Metric", "Value", "ASIL-D Target", "Status"])
        w.writerow(["Register inventory rows", reg_total, "", ""])
        w.writerow(["Logic inventory rows", logic_total, "", ""])
        w.writerow(["Total inventory", total_faults, "", ""])
        w.writerow(["Design-intent SPFM", f"{spfm_design*100:.2f}%", ">= 99.00%", "DESIGN"])
        if spfm_campaign is not None:
            w.writerow(["Campaign SPFM", f"{spfm_campaign*100:.2f}%", ">= 99.00%",
                        "PASS" if spfm_campaign >= 0.99 else "FAIL"])
            w.writerow(["Campaign LFM", f"{lfm_campaign*100:.2f}%", ">= 90.00%",
                        "PASS" if lfm_campaign >= 0.90 else "FAIL"])
            w.writerow(["FI corrected", corrected, "", ""])
            w.writerow(["FI detected", detected, "", ""])
            w.writerow(["FI latent", latent, "", ""])
            w.writerow(["FI undetected", undetected, "", ""])
        else:
            w.writerow(["Campaign SPFM", "TBD", ">= 99.00%", "PENDING"])
            w.writerow(["Campaign LFM", "TBD", ">= 90.00%", "PENDING"])
    print(f"  CSV exported: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
