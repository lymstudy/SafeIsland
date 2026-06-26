#!/usr/bin/env python3
"""
Generate a bit-level fault manifest for the ModelSim FI runner.

Default mode emits a small smoke list. Use --full to enumerate every bit in the
currently supported +FAULT_KIND targets.
"""

import argparse
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

TARGETS = [
    ("B0001", "config_slave", "dut.u_cfg.read_interval_inv", "cfg_read_interval_inv", 64, "config_bit", False),
    ("B0002", "config_slave", "dut.u_cfg.base_addr_inv_q[0]", "cfg_base_addr_inv_q0", 32, "config_bit", True),
    ("B0003", "config_slave", "dut.u_cfg.offset_inv_q[0]", "cfg_offset_inv_q0", 32, "config_bit", True),
    ("B0004", "config_slave", "dut.u_cfg.mask_inv_q[0]", "cfg_mask_inv_q0", 64, "config_bit", True),
    ("B0005", "config_slave", "dut.u_cfg.expected_inv_q[0]", "cfg_expected_inv_q0", 64, "config_bit", True),
    ("B0006", "core_logic", "dut.u_core.state_inv", "core_state_inv", 4, "core_bit", False),
    ("B0007", "core_logic", "dut.u_core.fault_or_accum_inv", "core_fault_or_accum_inv", 64, "core_bit", False),
    ("B0008", "fault_detector", "dut.u_fault_detector.fault_status_inv", "fd_fault_status_inv", 64, "fault_detector_bit", False),
    ("B0009", "fault_detector", "dut.u_fault_detector.error_code_inv", "fd_error_code_inv", 8, "fault_detector_bit", False),
    ("B0010", "heartbeat", "dut.u_heartbeat.counter_inv", "heartbeat_counter_inv", 32, "heartbeat_bit", False),
    ("B0011", "top", "dut.gen_read_master[0].rsp_data_inv_q[0]", "top_rsp_data_inv_q0", 64, "top_rsp_bit", True),
    (
        "B0012",
        "axi_read_engine",
        "dut.gen_read_master[0].u_read_engine.slot_accum_inv_q[0]",
        "read_engine_slot_accum_inv_q0",
        64,
        "read_engine_bit",
        True,
    ),
]


def smoke_bits(width):
    if width <= 1:
        return [0]
    mid = width // 2
    bits = [0, mid, width - 1]
    return sorted(set(bits))


def iter_rows(full, include_arrays):
    for target_id, module, path, kind, width, fault_type, is_array in TARGETS:
        if is_array and not (full or include_arrays):
            continue
        bits = range(width) if full else smoke_bits(width)
        for bit in bits:
            yield {
                "fault_id": f"{target_id}_{bit:03d}",
                "module": module,
                "hierarchical_path": f"{path}[{bit}]",
                "type": fault_type,
                "inject_cycle": "post_config",
                "duration": "until_detected",
                "target_ch": 0,
                "expected_class": "detected",
                "fault_kind": kind,
                "bit_index": bit,
            }


def main():
    parser = argparse.ArgumentParser(description="Generate FI bit-level fault list")
    parser.add_argument(
        "--output",
        default="fault_campaign/fault_bit_smoke_list.csv",
        help="CSV manifest path",
    )
    parser.add_argument("--full", action="store_true", help="enumerate every supported bit")
    parser.add_argument(
        "--include-arrays",
        action="store_true",
        help="include unpacked-array targets in smoke mode",
    )
    args = parser.parse_args()

    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = list(iter_rows(args.full, args.include_arrays))
    with output.open("w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "fault_id",
            "module",
            "hierarchical_path",
            "type",
            "inject_cycle",
            "duration",
            "target_ch",
            "expected_class",
            "fault_kind",
            "bit_index",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} bit-level faults: {output}")


if __name__ == "__main__":
    main()
