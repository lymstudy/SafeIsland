#!/usr/bin/env python3
import csv, os, glob, sys, re

root = os.path.expanduser("~/Desktop/submission")
reg_csv = os.path.join(root, "fault_campaign", "Register_fault_list.csv")
logic_csv = os.path.join(root, "fault_campaign", "Logic_fault_list.csv")
work = os.path.join(root, "sim", "work_full", "fault_results")

def choose_model(expected_class):
    if expected_class == "latent":
        return "stuck_at_0"
    if expected_class == "detected":
        return "stuck_at_1"
    return "transient_flip"

def fix_path(path):
    p = path
    p = re.sub(r"\[0\]\[0\]$", "[0]", p)
    p = re.sub(
        r"^(dut\.)gen_read_master\[\d+\]\.(rsp_fifo_safety_fault|core_read_done|core_resp_error|core_timeout|core_read_data_flat)(\[\d+\])$",
        r"\1\2\3", p)
    return p

existing = set()
for f in glob.glob(os.path.join(work, "*.csv")):
    base = os.path.basename(f).rsplit(".", 1)[0]
    existing.add(base)

missing = []
for csvf in [reg_csv, logic_csv]:
    if not os.path.exists(csvf):
        continue
    with open(csvf) as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            fid = row.get("fault_id", "")
            exp = row.get("expected_class", "")
            model = choose_model(exp)
            key = "{}_{}".format(fid, model)
            if key not in existing:
                path = fix_path(row.get("hierarchical_path", ""))
                missing.append((fid, model, exp, path))

print("Missing: {} faults".format(len(missing)))
for fid, model, exp, path in missing:
    print("  {} {} {} {}".format(fid, model, exp, path))
