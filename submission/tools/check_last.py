#!/usr/bin/env python3
import os, glob

work = os.path.expanduser("~/Desktop/submission/sim/work_full/logs")
files = sorted(glob.glob(os.path.join(work, "*.log")))
files.sort(key=lambda f: os.path.getmtime(f), reverse=True)
for f in files[:5]:
    print("=== {} ===".format(os.path.basename(f)))
    with open(f) as fh:
        lines = fh.readlines()
        for line in lines[-3:]:
            print(line.rstrip())
    print()
