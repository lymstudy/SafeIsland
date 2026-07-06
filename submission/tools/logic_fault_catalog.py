"""
Post-TMR combinational logic fault catalog for bit-level Logic_fault_list.csv.

Derived from fault_campaign/legacy_logic_signal_list.csv (459 signal-level entries, pre-expansion)
with path fixes, post-TMR signal additions, and per-bit expansion.
"""

from typing import Dict, List, Set, Tuple

import csv
import re
from pathlib import Path

# Match safety_island_top.v parameters
NUM_MASTERS = 5
NUM_ENTRIES = 64
ADDR_W = 32
DATA_W = 64
MAX_OUTSTANDING = 4
ID_W = 4
CRC_W = 16
BURST_TYPE_W = 2
BURST_LEN_W = 8
STATE_W = 4
ERROR_CODE_W = 8
AR_PAYLOAD_W = ID_W + ADDR_W + 8 + 3 + BURST_TYPE_W  # id+addr+len+size+burst

ROOT = Path(__file__).resolve().parents[1]
LEGACY_LOGIC_CSV = ROOT / "fault_campaign" / "legacy_logic_signal_list.csv"

# fault_kind -> bit width for [*] / bus-style logic signals
WIDTH_BY_FAULT_KIND: Dict[str, int] = {
    "aggregate_safety_error_code": ERROR_CODE_W,
    "core_error_code": ERROR_CODE_W,
    "core_safety_error_code": ERROR_CODE_W,
    "cfg_error_code_comb": ERROR_CODE_W,
    "safety_error_code_comb": ERROR_CODE_W,
    "fault_or_result": DATA_W,
    "core_read_data_flat": DATA_W,
    "response_read_data_dec": DATA_W,
    "read_data_comb": DATA_W,
    "read_resp_comb": 2,
    "write_addr_comb": ADDR_W,
    "write_id_comb": ID_W,
    "write_len_comb": 8,
    "write_size_comb": 3,
    "write_burst_comb": BURST_TYPE_W,
    "write_data_comb": DATA_W,
    "write_strb_comb": DATA_W // 8,
    "mask_flat": DATA_W,
    "expected_flat": DATA_W,
    "burst_type_flat": BURST_TYPE_W,
    "burst_len_flat": BURST_LEN_W,
    "kat_addr_out": ADDR_W,
    "kat_expected_out": DATA_W,
    "kat_mask_out": DATA_W,
    "current_base_addr": ADDR_W,
    "current_offset": ADDR_W,
    "current_read_addr": ADDR_W,
    "current_mask": DATA_W,
    "current_expected": DATA_W,
    "current_burst_type": BURST_TYPE_W,
    "current_burst_len": BURST_LEN_W,
    "current_base_addr_dec": ADDR_W,
    "current_offset_dec": ADDR_W,
    "current_mask_dec": DATA_W,
    "current_expected_dec": DATA_W,
    "current_burst_type_dec": BURST_TYPE_W,
    "current_burst_len_dec": BURST_LEN_W,
    "response_master_idx": 32,
    "response_entry_idx": 32,
    "state": STATE_W,
    "state_next": STATE_W,
    "m_axi_awid_flat": ID_W,
    "m_axi_awaddr_flat": ADDR_W,
    "m_axi_awlen_flat": 8,
    "m_axi_awsize_flat": 3,
    "m_axi_awburst_flat": BURST_TYPE_W,
    "m_axi_awcache_flat": 4,
    "m_axi_awprot_flat": 3,
    "m_axi_awqos_flat": 4,
    "m_axi_wdata_flat": DATA_W,
    "m_axi_wstrb_flat": DATA_W // 8,
    "m_axi_arcache": 4,
    "m_axi_arprot": 3,
    "m_axi_arqos": 4,
    "ar_payload": AR_PAYLOAD_W,
    "ar_signature": CRC_W,
    "ar_signature_dup": CRC_W,
    "ar_signature_triple": CRC_W,
    "r_crc_expected": CRC_W,
    "r_crc_expected_dup": CRC_W,
    "r_crc_expected_triple": CRC_W,
    "r_accum_next": DATA_W,
    "rid_match_idx": 32,
    "resp_masked_data": DATA_W,
    "resp_masked_expected": DATA_W,
    "read_interval_voted": 64,
    "kat_addr_voted": ADDR_W,
    "kat_expected_voted": DATA_W,
    "kat_mask_voted": DATA_W,
    "fault_status_voted": 64,
    "error_code_voted": ERROR_CODE_W,
    "current_master_idx_voted": 32,
    "current_entry_idx_voted": 32,
    "wr_ptr_safe": 32,
    "rd_ptr_safe": 32,
    "outstanding_count_safe": 32,
    "state_voted": 3,
}

# post-TMR: TMR voted / safe-path outputs are corrected; detection paths stay detected/latent
CORRECTED_FAULT_KINDS = frozenset(
    {
        "enable_voted",
        "enable_tmr_mismatch",
        "cfg_locked_r",
        "cfg_locked_tmr_mismatch",
        "cfg_illegal_r",
        "cfg_illegal_tmr_mismatch",
        "read_interval_voted",
        "read_interval_tmr_mismatch",
        "scan_done_sticky_voted",
        "scan_done_sticky_tmr_mismatch",
        "kat_enable_voted",
        "kat_addr_voted",
        "kat_expected_voted",
        "kat_mask_voted",
        "kat_enable_tmr_mismatch",
        "kat_addr_tmr_mismatch",
        "kat_expected_tmr_mismatch",
        "kat_mask_tmr_mismatch",
        "entry_tmr_mismatch_scrub",
        "state",
        "state_tmr_mismatch",
        "current_master_idx_voted",
        "current_entry_idx_voted",
        "current_master_idx_tmr_mismatch",
        "current_entry_idx_tmr_mismatch",
        "safety_fault_q",
        "safety_fault_q_tmr_mismatch",
        "safety_error_code_q",
        "safety_error_code_tmr_mismatch",
        "cfg_fault_comb_a",
        "cfg_fault_comb_b",
        "cfg_fault_comb_c",
        "cfg_fault_comb_voted",
        "cfg_fault_comb_tmr_err",
        "safety_fault_comb_a",
        "safety_fault_comb_b",
        "safety_fault_comb_c",
        "safety_fault_comb_voted",
        "safety_fault_comb_tmr_err",
        "pending_valid_q_voted",
        "pending_valid_q_tmr_err",
        "fd_sticky_tmr_mismatch",
        "sifd_sticky_tmr_mismatch",
        "wr_ptr_safe",
        "rd_ptr_safe",
        "outstanding_count_safe",
        "slot_valid_q_voted",
        "slot_valid_q_tmr_err",
        "slot_meta_tmr_err",
        "slot_id_voted",
        "slot_len_voted",
        "slot_beat_voted",
        "slot_age_voted",
        "slot_accum_voted",
        "crc_calc_mismatch_voted",
        "crc_calc_mismatch_tmr_err",
        "state_voted",
        "m_axi_arlock",
        "m_axi_arcache",
        "m_axi_arprot",
        "m_axi_arqos",
    }
)

LATENT_FAULT_KINDS = frozenset(
    {
        "entry_parity_fault_scrub",
        "safety_island_latent_fault_detect",
    }
)

# TMR mismatch that propagates to fault_detect / safety_island_fault_detect (not silently repaired)
DETECTED_MISMATCH_KINDS = frozenset(
    {
        "fd_tmr_mismatch",
        "sifd_tmr_mismatch",
        "cfg_ctrl_tmr_mismatch",
        "cfg_shadow_error_tmr_err",
        "state_tmr_mismatch",
        "safety_fault_q_tmr_mismatch",
        "safety_error_code_tmr_mismatch",
        "current_master_idx_tmr_mismatch",
        "current_entry_idx_tmr_mismatch",
        "event_tmr_mismatch",
        "crc_calc_mismatch_a",
        "crc_calc_mismatch_b",
        "crc_calc_mismatch_c",
        "crc_calc_mismatch_comb",
        "crc_calc_mismatch_voted",
        "crc_calc_mismatch_tmr_err",
        "crc_tmr_mismatch",
        "crc_voter_self_fault",
        "crc_tmr_voter_self_fault",
        "enable_tmr_mismatch",
        "cfg_locked_tmr_mismatch",
        "cfg_illegal_tmr_mismatch",
        "read_interval_tmr_mismatch",
        "scan_done_sticky_tmr_mismatch",
        "kat_enable_tmr_mismatch",
        "kat_addr_tmr_mismatch",
        "kat_expected_tmr_mismatch",
        "kat_mask_tmr_mismatch",
        "state_tmr_mismatch",
        "shadow_error_comb_a",
        "shadow_error_comb_b",
        "shadow_error_comb_c",
    }
)

SKIP_FAULT_KINDS = frozenset({"fault_i", "scan_i"})

SKIP_PATH_SUBSTR = (
    ".datapath_safety_fault",
    "dut.u_fault_detector.fault_detect",  # forcing creates combinational loop
)

# Post-TMR signals not present in legacy 459-row list
POST_TMR_ADDITIONS: List[Dict] = [
    # top
    {"module": "top", "path": "dut.fd_comb_raw", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "fd_comb_raw", "expected_class": "detected", "inject_cycle": "runtime", "target_ch": 0},
    {"module": "top", "path": "dut.sifd_comb_raw", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "sifd_comb_raw", "expected_class": "detected", "inject_cycle": "runtime", "target_ch": 0},
    {"module": "top", "path": "dut.fd_voter_self_fault", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "fd_voter_self_fault", "expected_class": "detected", "inject_cycle": "runtime", "target_ch": 0},
    {"module": "top", "path": "dut.sifd_voter_self_fault", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "sifd_voter_self_fault", "expected_class": "detected", "inject_cycle": "runtime", "target_ch": 0},
    {"module": "top", "path": "dut.fd_sticky_tmr_mismatch", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "fd_sticky_tmr_mismatch", "expected_class": "corrected", "inject_cycle": "runtime", "target_ch": 0},
    {"module": "top", "path": "dut.sifd_sticky_tmr_mismatch", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "sifd_sticky_tmr_mismatch", "expected_class": "corrected", "inject_cycle": "runtime", "target_ch": 0},
    # config TMR voted chain
    {"module": "config_slave", "path": "dut.u_cfg.enable_voted", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "enable_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.read_interval_voted", "width": 64, "logic_kind": "tmr_voter_logic",
     "function": "read_interval_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.cfg_ctrl_tmr_mismatch", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "cfg_ctrl_tmr_mismatch", "expected_class": "detected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.cfg_shadow_error_voted", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "cfg_shadow_error_voted", "expected_class": "detected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.cfg_shadow_error_tmr_err", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "cfg_shadow_error_tmr_err", "expected_class": "detected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.entry_tmr_mismatch_scrub", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "entry_tmr_mismatch_scrub", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.entry_parity_fault_scrub", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "entry_parity_fault_scrub", "expected_class": "latent", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.kat_enable_voted", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "kat_enable_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.kat_addr_voted", "width": ADDR_W, "logic_kind": "tmr_voter_logic",
     "function": "kat_addr_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.kat_expected_voted", "width": DATA_W, "logic_kind": "tmr_voter_logic",
     "function": "kat_expected_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    {"module": "config_slave", "path": "dut.u_cfg.kat_mask_voted", "width": DATA_W, "logic_kind": "tmr_voter_logic",
     "function": "kat_mask_voted", "expected_class": "corrected", "inject_cycle": "post_config", "target_ch": 0},
    # core TMR
    {"module": "core_logic", "path": "dut.u_core.current_master_idx_voted", "width": 32, "logic_kind": "tmr_voter_logic",
     "function": "current_master_idx_voted", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.current_entry_idx_voted", "width": 32, "logic_kind": "tmr_voter_logic",
     "function": "current_entry_idx_voted", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.cfg_fault_comb_voted", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "cfg_fault_comb_voted", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.cfg_fault_comb_tmr_err", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "cfg_fault_comb_tmr_err", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.safety_fault_comb_voted", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "safety_fault_comb_voted", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.safety_fault_comb_tmr_err", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "safety_fault_comb_tmr_err", "expected_class": "corrected", "inject_cycle": "scan_active", "target_ch": 0},
    {"module": "core_logic", "path": "dut.u_core.pending_count_fault_comb", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "pending_count_fault_comb", "expected_class": "detected", "inject_cycle": "scan_active", "target_ch": 0},
    # fault_detector TMR
    {"module": "fault_detector", "path": "dut.u_fault_detector.resp_cmp0", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "resp_cmp0", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    {"module": "fault_detector", "path": "dut.u_fault_detector.resp_cmp1", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "resp_cmp1", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    {"module": "fault_detector", "path": "dut.u_fault_detector.resp_cmp2", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "resp_cmp2", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    {"module": "fault_detector", "path": "dut.u_fault_detector.event_tmr_mismatch", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "event_tmr_mismatch", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    {"module": "fault_detector", "path": "dut.u_fault_detector.fault_status_voted", "width": 64, "logic_kind": "tmr_voter_logic",
     "function": "fault_status_voted", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    {"module": "fault_detector", "path": "dut.u_fault_detector.error_code_voted", "width": 8, "logic_kind": "tmr_voter_logic",
     "function": "error_code_voted", "expected_class": "detected", "inject_cycle": "fault_check", "target_ch": 0},
    # heartbeat
    {"module": "heartbeat", "path": "dut.u_heartbeat.state_voted", "width": 3, "logic_kind": "tmr_voter_logic",
     "function": "state_voted", "expected_class": "corrected", "inject_cycle": "heartbeat_check", "target_ch": 0},
    {"module": "heartbeat", "path": "dut.u_heartbeat.state_tmr_mismatch", "width": 1, "logic_kind": "tmr_voter_logic",
     "function": "state_tmr_mismatch", "expected_class": "detected", "inject_cycle": "heartbeat_check", "target_ch": 0},
    {"module": "heartbeat", "path": "dut.u_heartbeat.heartbeat_internal_fault", "width": 1, "logic_kind": "fault_detect_logic",
     "function": "heartbeat_internal_fault", "expected_class": "detected", "inject_cycle": "heartbeat_check", "target_ch": 0},
]

# Per-master read_engine additions (slot TMR + safe pointers + protected CRC voter)
def read_engine_additions(mi: int) -> List[Dict]:
    base = f"dut.gen_read_master[{mi}].u_read_engine"
    ch = mi
    ic = "read_active"
    out = [
        {"module": "axi_read_engine", "path": f"{base}.wr_ptr_safe", "width": 32,
         "logic_kind": "comb_logic", "function": "wr_ptr_safe", "expected_class": "corrected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.rd_ptr_safe", "width": 32,
         "logic_kind": "comb_logic", "function": "rd_ptr_safe", "expected_class": "corrected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.outstanding_count_safe", "width": 32,
         "logic_kind": "comb_logic", "function": "outstanding_count_safe", "expected_class": "corrected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.crc_calc_mismatch_voted", "width": 1,
         "logic_kind": "tmr_voter_logic", "function": "crc_calc_mismatch_voted", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.crc_calc_mismatch_tmr_err", "width": 1,
         "logic_kind": "tmr_voter_logic", "function": "crc_calc_mismatch_tmr_err", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.crc_voter_self_fault", "width": 1,
         "logic_kind": "tmr_voter_protected", "function": "crc_voter_self_fault", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.u_crc_tmr.voted", "width": 1,
         "logic_kind": "tmr_voter_protected", "function": "crc_tmr_voted", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.u_crc_tmr.mismatch", "width": 1,
         "logic_kind": "tmr_voter_protected", "function": "crc_tmr_mismatch", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
        {"module": "axi_read_engine", "path": f"{base}.u_crc_tmr.voter_self_fault", "width": 1,
         "logic_kind": "tmr_voter_protected", "function": "crc_tmr_voter_self_fault", "expected_class": "detected",
         "inject_cycle": ic, "target_ch": ch},
    ]
    for slot in range(MAX_OUTSTANDING):
        out.extend(
            [
                {"module": "axi_read_engine", "path": f"{base}.slot_valid_q_voted[{slot}]", "width": 1,
                 "logic_kind": "tmr_voter_logic", "function": "slot_valid_q_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_valid_q_tmr_err[{slot}]", "width": 1,
                 "logic_kind": "tmr_voter_logic", "function": "slot_valid_q_tmr_err", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_meta_tmr_err[{slot}]", "width": 1,
                 "logic_kind": "tmr_voter_logic", "function": "slot_meta_tmr_err", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
            ]
        )
    for slot in range(MAX_OUTSTANDING):
        out.extend(
            [
                {"module": "axi_read_engine", "path": f"{base}.slot_id_voted[{slot}]", "width": ID_W,
                 "logic_kind": "tmr_voter_logic", "function": "slot_id_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_len_voted[{slot}]", "width": BURST_LEN_W,
                 "logic_kind": "tmr_voter_logic", "function": "slot_len_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_beat_voted[{slot}]", "width": 8,
                 "logic_kind": "tmr_voter_logic", "function": "slot_beat_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_age_voted[{slot}]", "width": 32,
                 "logic_kind": "tmr_voter_logic", "function": "slot_age_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
                {"module": "axi_read_engine", "path": f"{base}.slot_accum_voted[{slot}]", "width": DATA_W,
                 "logic_kind": "tmr_voter_logic", "function": "slot_accum_voted", "expected_class": "corrected",
                 "inject_cycle": ic, "target_ch": ch},
            ]
        )
    return out


def _normalize_legacy_path(path: str) -> str:
    """Strip [*] suffix; keep explicit [mi] indices from legacy rows."""
    if path.endswith("[*]"):
        return path[:-3]
    return path.replace("[*]", "")


def _resolve_mi_parameters(path: str) -> str:
    """Resolve [mi] genvar and [mi*EXPR +: EXPR] part-select in legacy paths.

    These patterns contain the literal string 'mi' (a genvar/parameter) that VCS
    UCLI cannot resolve.  Since we only need one representative bit (bit 0 of
    master 0), replace:
      - '[mi]'          -> '[0]'
      - '[mi*EXPR +: EXPR]' -> ''  (the bit index is appended by
                                    expand_logic_sites_to_bit_rows)
    """
    path = re.sub(r"\[mi\]", "[0]", path)
    path = re.sub(r"\[mi\*[^\]]*\+:\s*[^\]]*\]", "", path)
    return path


def _infer_width(fault_kind: str, path: str, logic_kind: str) -> int:
    if fault_kind in WIDTH_BY_FAULT_KIND:
        return WIDTH_BY_FAULT_KIND[fault_kind]
    if "[*]" in path or path.endswith("[*]"):
        base = path.split("[")[0].split(".")[-1]
        if base in WIDTH_BY_FAULT_KIND:
            return WIDTH_BY_FAULT_KIND[base]
    if "flat[mi*" in path or "+:" in path:
        if "DATA_W" in path or "64" in path:
            return DATA_W
        if "ADDR_W" in path or "32" in path:
            return ADDR_W
        if "ID_W" in path:
            return ID_W
    return 1


def _post_tmr_expected(fault_kind: str, legacy_expected: str) -> str:
    if fault_kind in LATENT_FAULT_KINDS:
        return "latent"
    if fault_kind in DETECTED_MISMATCH_KINDS:
        return "detected"
    if fault_kind in CORRECTED_FAULT_KINDS:
        return "corrected"
    if fault_kind.endswith("_voted") or fault_kind.endswith("_safe"):
        return "corrected"
    if fault_kind.endswith("_tmr_err"):
        return "corrected"
    if fault_kind.endswith("_tmr_mismatch"):
        # scrub-repairable entry mismatch; ctrl/output mismatches listed above
        if "scrub" in fault_kind or "sticky" in fault_kind:
            return "corrected"
        return "detected"
    return legacy_expected if legacy_expected else "detected"


def load_legacy_signal_sites() -> List[Dict]:
    """Load deduplicated signal-level sites from legacy CSV."""
    if not LEGACY_LOGIC_CSV.exists():
        return []

    seen: Set[Tuple] = set()
    sites: List[Dict] = []

    with LEGACY_LOGIC_CSV.open("r", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            fault_kind = row["fault_kind"].strip()
            if fault_kind in SKIP_FAULT_KINDS:
                continue

            path_raw = row["hierarchical_path"].strip()
            if any(s in path_raw for s in SKIP_PATH_SUBSTR):
                continue

            path = _normalize_legacy_path(path_raw)
            path = _resolve_mi_parameters(path)
            module = row["module"].strip()
            logic_kind = row["type"].strip()
            inject_cycle = row["inject_cycle"].strip()
            try:
                target_ch = int(row["target_ch"])
            except (ValueError, KeyError):
                target_ch = 0

            key = (module, path, logic_kind, fault_kind, inject_cycle, target_ch)
            if key in seen:
                continue
            seen.add(key)

            width = _infer_width(fault_kind, path_raw, logic_kind)
            expected = _post_tmr_expected(fault_kind, row.get("expected_class", "detected"))

            sites.append(
                {
                    "module": module,
                    "path": path,
                    "width": width,
                    "logic_kind": logic_kind,
                    "function": fault_kind,
                    "expected_class": expected,
                    "inject_cycle": inject_cycle,
                    "target_ch": target_ch,
                }
            )
    return sites


def load_all_signal_sites() -> List[Dict]:
    sites = load_legacy_signal_sites()
    seen = {(s["module"], s["path"], s["function"], s.get("target_ch", 0)) for s in sites}

    for add in POST_TMR_ADDITIONS:
        key = (add["module"], add["path"], add["function"], add.get("target_ch", 0))
        if key not in seen:
            sites.append(add)
            seen.add(key)

    for mi in range(NUM_MASTERS):
        for add in read_engine_additions(mi):
            key = (add["module"], add["path"], add["function"], add.get("target_ch", 0))
            if key not in seen:
                sites.append(add)
                seen.add(key)

    # core pending_valid TMR voters
    for slot in range(MAX_OUTSTANDING):
        path_v = f"dut.u_core.pending_valid_q_voted[{slot}]"
        path_e = f"dut.u_core.pending_valid_q_tmr_err[{slot}]"
        for path, fn in ((path_v, "pending_valid_q_voted"), (path_e, "pending_valid_q_tmr_err")):
            key = ("core_logic", path, fn, 0)
            if key not in seen:
                sites.append(
                    {
                        "module": "core_logic",
                        "path": path,
                        "width": 1,
                        "logic_kind": "tmr_voter_logic",
                        "function": fn,
                        "expected_class": "corrected",
                        "inject_cycle": "scan_active",
                        "target_ch": 0,
                    }
                )
                seen.add(key)

    # fault_detector event voted outputs
    for evt in (
        "external_fault_event_voted",
        "bus_fault_event_voted",
        "cfg_fault_event_voted",
        "safety_island_fault_event_voted",
        "safety_island_latent_fault_event_voted",
    ):
        path = f"dut.u_fault_detector.{evt}"
        key = ("fault_detector", path, evt, 0)
        if key not in seen:
            sites.append(
                {
                    "module": "fault_detector",
                    "path": path,
                    "width": 1,
                    "logic_kind": "tmr_voter_logic",
                    "function": evt,
                    "expected_class": "detected",
                    "inject_cycle": "fault_check",
                    "target_ch": 0,
                }
            )
            seen.add(key)

    return sites


def expand_logic_sites_to_bit_rows(sites: List[Dict]) -> List[Dict]:
    rows: List[Dict] = []
    for site in sites:
        width = max(1, int(site["width"]))
        base_path = site["path"]
        for bit in range(width):
            if width == 1:
                hier_path = base_path
            else:
                hier_path = f"{base_path}[{bit}]"
            rows.append(
                {
                    "module": site["module"],
                    "hierarchical_path": hier_path,
                    "type": "logic",
                    "logic_kind": site["logic_kind"],
                    "function": site["function"],
                    "expected_class": site["expected_class"],
                    "bit_width": width,
                    "bit_index": bit,
                    "inject_cycle": site.get("inject_cycle", "runtime"),
                    "duration": site.get("duration", "until_detected"),
                    "target_ch": site.get("target_ch", 0),
                    "fault_kind": site["function"],
                }
            )

    for idx, row in enumerate(rows, start=1):
        row["fault_id"] = f"L{idx:06d}_{row['bit_index']:03d}"
    return rows
