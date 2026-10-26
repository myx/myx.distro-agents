#!/usr/bin/env python3
## runner-stall-keeper.py <run folder> -- what the run folder of sh-test/AgentsRunTests.sh holds now, on one line: the time of its newest entry, how many entries it
## has, and how many of them are receipts. The watch compares two of these lines and nothing else. Ends 1 where the folder cannot be read.
import os
import sys

folder = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    names = os.listdir(folder)
except OSError:
    sys.exit(1)
newest = entries = receipts = 0
for name in names:
    try:
        modified = os.stat(os.path.join(folder, name)).st_mtime
    except OSError:
        continue
    entries += 1
    if name.endswith(".receipt"):
        receipts += 1
    newest = max(newest, int(modified))
print("%d %d %d" % (newest, entries, receipts))
