#!/usr/bin/env python3
import subprocess, csv, os, sys

SIMV = os.path.expanduser("~/Desktop/submission/sim/work_full/simv_campaign")
WORK = os.path.expanduser("~/Desktop/submission/sim/work_full")

faults = [
    ("R163201", "register", "transient_flip", "dut.u_cfg.entry_valid_q_a[0]", "corrected"),
    ("R205997", "register", "stuck_at_0",     "dut.u_cfg.mask_sig_q[0]", "latent"),
    ("R207709", "register", "transient_flip", "dut.gen_read_master[0].u_read_engine.slot_valid_q_a[0]", "corrected"),
    ("R213541", "register", "transient_flip", "dut.u_core.pending_valid_q_a[0]", "corrected"),
    ("L001923_000", "logic", "stuck_at_1", "dut.rsp_fifo_safety_fault[0]", "detected"),
    ("L001924_000", "logic", "stuck_at_1", "dut.core_read_done[0]", "detected"),
    ("L001925_000", "logic", "stuck_at_1", "dut.core_resp_error[0]", "detected"),
    ("L001926_000", "logic", "stuck_at_1", "dut.core_timeout[0]", "detected"),
    ("L001927_000", "logic", "stuck_at_1", "dut.core_read_data_flat[0]", "detected"),
]

for fid, ftype, model, hp, exp in faults:
    mod = "config_slave"
    if "R207" in fid: mod = "axi_read_engine"
    if "R213" in fid: mod = "core_logic"
    if "L00" in fid: mod = "top_rsp_fifo"

    res_file = os.path.join(WORK, "fault_results", "{}_{}.csv".format(fid, model))
    ucli_file = os.path.join(WORK, "ucli", "{}_{}.tcl".format(fid, model))
    log_file = os.path.join(WORK, "logs", "{}_{}.log".format(fid, model))

    val = "1'b0" if model == "stuck_at_0" else "1'b1"
    pulse = "tb_safety_island_fault_injection.campaign_inject_pulse"
    tcl_lines = [
        "run 5000ns",
        "force -deposit {} {}".format(pulse, val),
        "force -deposit {{{}}} {}".format(hp, val),
        "run 10ns",
        "release {}".format(pulse),
        "run 120ns",
        "release {{{}}}".format(hp),
        "run 20ns",
        "quit",
    ]
    with open(ucli_file, "w") as f:
        f.write("\n".join(tcl_lines) + "\n")

    cmd = [SIMV, "+UCLI_CAMPAIGN", "+FAULT_ID=" + fid,
           "+FAULT_TYPE=" + ftype, "+FAULT_MODEL=" + model,
           "+EXPECTED_CLASS=" + exp, "+FAULT_PATH=" + hp,
           "+CSV_FILE=" + res_file, "+MONITOR_CYCLES=10",
           "-ucli", "-do", ucli_file, "-l", log_file]
    try:
        subprocess.run(cmd, cwd=WORK, timeout=120)
    except subprocess.TimeoutExpired:
        print("{} timeout".format(fid))
        continue
    except Exception as e:
        print("{} error: {}".format(fid, e))
        continue

    result = "no_file"
    if os.path.exists(res_file):
        with open(res_file) as f:
            for row in csv.DictReader(f):
                result = row.get("result_class", "?")
    print("{} result={}".format(fid, result))
