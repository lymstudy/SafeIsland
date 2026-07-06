#!/usr/bin/env python3
import csv, os, glob

work = os.path.expanduser("~/Desktop/submission/sim/work_full/fault_results")
files = sorted(glob.glob(os.path.join(work, "*.csv")))
errors = []
for f in files:
    with open(f) as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if row.get("result_class") == "error":
                errors.append(row)
                print("ERROR: {} path={} expected={}".format(
                    row["fault_id"], row.get("hierarchical_path",""), row.get("expected_class","")))
if not errors:
    print("NO ERRORS FOUND in {} files".format(len(files)))
print("Total files: {}".format(len(files)))
