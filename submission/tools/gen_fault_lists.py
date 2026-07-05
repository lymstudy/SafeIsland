#!/usr/bin/env python3
"""
Generate Register_fault_list.csv and Logic_fault_list.csv from RTL TMR inventory.

After RTL adds TMR replicas, register bit counts change; re-run this script before
SPFM/LFM or fault-campaign denominator updates.

Usage:
  python tools/gen_fault_lists.py
  python tools/gen_fault_lists.py --output-dir fault_campaign
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from logic_fault_catalog import expand_logic_sites_to_bit_rows, load_all_signal_sites

# Default IP parameters (match safety_island_top.v)
NUM_MASTERS = 5
NUM_ENTRIES = 64
ADDR_W = 32
DATA_W = 64
MAX_OUTSTANDING = 4
ID_W = 4
CRC_W = 16
TOTAL_ENTRIES = NUM_MASTERS * NUM_ENTRIES


def add_reg_rows(rows, module, base_path, width, count, replica, mechanism, expected):
    for idx in range(count):
        for bit in range(width):
            rows.append(
                {
                    "fault_id": f"R{len(rows)+1:06d}",
                    "module": module,
                    "hierarchical_path": f"{base_path}[{idx}][{bit}]"
                    if count > 1
                    else f"{base_path}[{bit}]",
                    "target": base_path.split(".")[-1],
                    "type": "register",
                    "replica": replica,
                    "bit_width": width,
                    "bit_index": bit,
                    "protection": mechanism,
                    "expected_class": expected,
                }
            )


def build_register_inventory():
    rows = []

    def triplet(module, path, width, count, mechanism, expected="corrected"):
        for rep in ("a", "b", "c"):
            add_reg_rows(rows, module, f"{path}_{rep}", width, count, rep, mechanism, expected)

    # --- config_slave (highest weight) ---
    triplet("config_slave", "dut.u_cfg.expected_q", DATA_W, TOTAL_ENTRIES, "TMR+scrub+parity")
    triplet("config_slave", "dut.u_cfg.mask_q", DATA_W, TOTAL_ENTRIES, "TMR+scrub+parity")
    triplet("config_slave", "dut.u_cfg.offset_q", ADDR_W, TOTAL_ENTRIES, "TMR+scrub+parity")
    triplet("config_slave", "dut.u_cfg.burst_len_q", 8, TOTAL_ENTRIES, "TMR+scrub")
    triplet("config_slave", "dut.u_cfg.burst_type_q", 2, TOTAL_ENTRIES, "TMR+scrub")
    triplet("config_slave", "dut.u_cfg.entry_valid_q", 1, TOTAL_ENTRIES, "TMR+scrub")
    triplet("config_slave", "dut.u_cfg.base_addr_q", ADDR_W, NUM_MASTERS, "TMR+parity")
    triplet("config_slave", "dut.u_cfg.read_interval", 64, 1, "TMR+parity")

    for rep in ("a", "b", "c"):
        add_reg_rows(rows, "config_slave", f"dut.u_cfg.enable_{rep}", 1, 1, rep, "TMR+repair", "corrected")
        add_reg_rows(rows, "config_slave", f"dut.u_cfg.cfg_locked_r_{rep}", 1, 1, rep, "TMR+repair", "corrected")
        add_reg_rows(rows, "config_slave", f"dut.u_cfg.cfg_illegal_r_{rep}", 1, 1, rep, "TMR+repair", "corrected")
        add_reg_rows(rows, "config_slave", f"dut.u_cfg.kat_enable_{rep}", 1, 1, rep, "TMR+repair", "corrected")
        add_reg_rows(
            rows, "config_slave", f"dut.u_cfg.kat_expected_{rep}", DATA_W, 1, rep, "TMR+repair", "corrected"
        )

    # Shadow / signature (detection auxiliary → latent)
    add_reg_rows(rows, "config_slave", "dut.u_cfg.mask_inv_q", DATA_W, TOTAL_ENTRIES, "-", "shadow", "latent")
    add_reg_rows(rows, "config_slave", "dut.u_cfg.expected_inv_q", DATA_W, TOTAL_ENTRIES, "-", "shadow", "latent")
    add_reg_rows(rows, "config_slave", "dut.u_cfg.mask_sig_q", 1, TOTAL_ENTRIES, "-", "parity", "latent")

    # --- read_engine ---
    for slot in range(MAX_OUTSTANDING):
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_accum_q", DATA_W, 1, "TMR+repair")
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_id_q", ID_W, 1, "TMR+repair")
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_len_q", 8, 1, "TMR+repair")
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_beat_q", 8, 1, "TMR+repair")
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_age_q", 32, 1, "TMR+repair")
        triplet("axi_read_engine", f"dut.u_read_engine[{slot}].slot_valid_q", 1, 1, "TMR+repair")

    # --- core_logic ---
    triplet("core_logic", "dut.u_core.state", 4, 1, "TMR+repair+illegal_fsm")
    triplet("core_logic", "dut.u_core.current_master_idx", 32, 1, "TMR+range")
    triplet("core_logic", "dut.u_core.current_entry_idx", 32, 1, "TMR+range")
    for slot in range(MAX_OUTSTANDING):
        triplet("core_logic", f"dut.u_core.pending_valid_q", 1, 1, "TMR+repair")

    # --- fault_detector ---
    for evt in (
        "external_fault_event",
        "bus_fault_event",
        "cfg_fault_event",
        "safety_island_fault_event",
        "safety_island_latent_fault_event",
    ):
        triplet("fault_detector", f"dut.u_fault_detector.{evt}", 1, 1, "TMR+repair", "detected")
    triplet("fault_detector", "dut.u_fault_detector.fault_status", 64, 1, "TMR+repair", "detected")
    triplet("fault_detector", "dut.u_fault_detector.error_code", 8, 1, "TMR+repair", "detected")

    # --- top sticky outputs ---
    for name in ("fd_a", "fd_b", "fd_c", "sifd_a", "sifd_b", "sifd_c"):
        add_reg_rows(rows, "top", f"dut.{name}", 1, 1, "-", "sticky+protected_voter", "detected")

    # --- heartbeat ---
    triplet("heartbeat", "dut.u_heartbeat.state", 3, 1, "TMR+repair")

    return rows


def build_logic_inventory():
    """Bit-level logic fault list from post-TMR catalog (legacy 459 + TMR additions)."""
    return expand_logic_sites_to_bit_rows(load_all_signal_sites())


def summarize_logic_rows(rows):
    by_module = defaultdict(int)
    by_kind = defaultdict(int)
    by_expected = defaultdict(int)
    signal_sites = set()
    for row in rows:
        by_module[row["module"]] += 1
        by_kind[row["logic_kind"]] += 1
        by_expected[row["expected_class"]] += 1
        signal_sites.add((row["module"], row["function"], row.get("target_ch", 0)))
    return by_module, by_kind, by_expected, len(signal_sites)


def build_smoke_list():
    """Minimal smoke targets (plan §H2) for post-FI-upgrade campaign."""
    smoke = [
        ("SM001", "config_slave", "dut.u_cfg.expected_q_a[0][0]", "transient_flip", "corrected"),
        ("SM002", "config_slave", "dut.u_cfg.mask_q_b[0][3]", "stuck_at_1", "corrected"),
        ("SM003", "config_slave", "dut.u_cfg.expected_inv_q[0][0]", "stuck_at_0", "latent"),
        ("SM004", "config_slave", "dut.u_cfg.entry_valid_q_c[0]", "transient_flip", "corrected"),
        ("SM005", "config_slave", "dut.u_cfg.read_interval_b[10]", "transient_flip", "corrected"),
        ("SM006", "axi_read_engine", "dut.u_read_engine[0].slot_accum_q_a[0][0]", "transient_flip", "corrected"),
        ("SM007", "axi_read_engine", "dut.u_read_engine[0].slot_id_q_b[0]", "stuck_at_1", "corrected"),
        ("SM008", "core_logic", "dut.u_core.state_b[0]", "transient_flip", "corrected"),
        ("SM009", "core_logic", "dut.u_core.current_master_idx_a[0]", "stuck_at_1", "corrected"),
        ("SM010", "core_logic", "dut.u_core.pending_valid_q_b[0]", "transient_flip", "corrected"),
        ("SM011", "fault_detector", "dut.u_fault_detector.external_fault_event_a", "stuck_at_1", "detected"),
        ("SM012", "fault_detector", "dut.u_fault_detector.fault_status_a[0]", "transient_flip", "detected"),
        ("SM013", "top", "dut.fd_b", "stuck_at_1", "detected"),
        ("SM014", "top", "dut.u_fd_out_tmr.voter_self_fault", "force", "detected"),
    ]
    return [
        {
            "fault_id": fid,
            "module": mod,
            "hierarchical_path": path,
            "type": ftype,
            "expected_class": exp,
            "campaign": "smoke_tmr",
        }
        for fid, mod, path, ftype, exp in smoke
    ]


def summarize_register_rows(rows):
    by_module = defaultdict(int)
    by_mechanism = defaultdict(int)
    by_expected = defaultdict(int)
    for row in rows:
        by_module[row["module"]] += 1
        by_mechanism[row["protection"]] += 1
        by_expected[row["expected_class"]] += 1
    return by_module, by_mechanism, by_expected


def write_csv(path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def write_summary(path, title, total, by_module, extra_lines=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(f"{title}\n")
        f.write(f"total_rows={total}\n\n")
        f.write("By module:\n")
        for mod, cnt in sorted(by_module.items(), key=lambda x: (-x[1], x[0])):
            f.write(f"  {mod}: {cnt}\n")
        if extra_lines:
            f.write("\n")
            for line in extra_lines:
                f.write(line + "\n")


def main():
    parser = argparse.ArgumentParser(description="Generate fault inventory CSVs")
    parser.add_argument(
        "--output-dir",
        default="fault_campaign",
        help="output directory relative to submission/",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    out = root / args.output_dir

    reg_rows = build_register_inventory()
    logic_rows = build_logic_inventory()
    smoke_rows = build_smoke_list()

    reg_fields = [
        "fault_id",
        "module",
        "hierarchical_path",
        "target",
        "type",
        "replica",
        "bit_width",
        "bit_index",
        "protection",
        "expected_class",
    ]
    logic_fields = [
        "fault_id",
        "module",
        "hierarchical_path",
        "type",
        "logic_kind",
        "function",
        "expected_class",
        "bit_width",
        "bit_index",
        "inject_cycle",
        "duration",
        "target_ch",
        "fault_kind",
    ]
    smoke_fields = ["fault_id", "module", "hierarchical_path", "type", "expected_class", "campaign"]

    write_csv(out / "Register_fault_list.csv", reg_rows, reg_fields)
    write_csv(out / "Logic_fault_list.csv", logic_rows, logic_fields)
    write_csv(out / "fault_smoke_tmr.csv", smoke_rows, smoke_fields)

    by_mod, by_mech, by_exp = summarize_register_rows(reg_rows)
    write_summary(
        out / "Register_fault_summary.txt",
        "Register fault inventory (post-TMR RTL)",
        len(reg_rows),
        by_mod,
        [
            "By protection mechanism:",
            *[f"  {k}: {v}" for k, v in sorted(by_mech.items(), key=lambda x: (-x[1], x[0]))],
            "",
            "By expected_class:",
            *[f"  {k}: {v}" for k, v in sorted(by_exp.items(), key=lambda x: (-x[1], x[0]))],
        ],
    )

    logic_by_mod, logic_by_kind, logic_by_exp, logic_signal_sites = summarize_logic_rows(logic_rows)
    write_summary(
        out / "Logic_fault_summary.txt",
        "Logic fault inventory (post-TMR RTL, bit-level)",
        len(logic_rows),
        logic_by_mod,
        [
            f"signal_sites={logic_signal_sites}",
            "",
            "By logic_kind:",
            *[f"  {k}: {v}" for k, v in sorted(logic_by_kind.items(), key=lambda x: (-x[1], x[0]))],
            "",
            "By expected_class:",
            *[f"  {k}: {v}" for k, v in sorted(logic_by_exp.items(), key=lambda x: (-x[1], x[0]))],
        ],
    )

    print(f"Register faults: {len(reg_rows)} rows -> {out / 'Register_fault_list.csv'}")
    print(f"Logic faults:    {len(logic_rows)} rows ({logic_signal_sites} signal sites) -> {out / 'Logic_fault_list.csv'}")
    print(f"Smoke TMR cases: {len(smoke_rows)} rows -> {out / 'fault_smoke_tmr.csv'}")
    print("Top register modules:")
    for mod, cnt in sorted(by_mod.items(), key=lambda x: -x[1])[:6]:
        print(f"  {mod}: {cnt}")


if __name__ == "__main__":
    main()
