#!/usr/bin/env python3
## runner-stall-keeper.py <run folder> -- what the run folder of sh-test/AgentsRunTests.sh holds now, on one line:
## the time of its newest entry, how many entries it has, how many of them are receipts, and how many tests have
## started and have no receipt yet. The watch compares two of these lines and nothing else. Ends 1 where the folder
## cannot be read.
##
## tests.list IS NOT COUNTED: the yield touches it as it waits, to keep the watch quiet, so a run wedged for 21 h 50 m
## still looked alive. runner.log IS NOT COUNTED either: a detached run writes its own stderr there, so it would pass
## for a test that started and never ended. A test at work moves its own.log, and a test that ends writes its receipt.
import os
import sys

folder = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    names = os.listdir(folder)
except OSError:
    sys.exit(1)
newest = entries = receipts = started = 0
for name in names:
    if name in ("tests.list", "runner.log"):
        continue
    if name.endswith(".log") and not os.path.exists(os.path.join(folder, name[: -len(".log")] + ".receipt")):
        started += 1
    try:
        modified = os.stat(os.path.join(folder, name)).st_mtime
    except OSError:
        continue
    entries += 1
    if name.endswith(".receipt"):
        receipts += 1
    newest = max(newest, int(modified))
print("%d %d %d %d" % (newest, entries, receipts, started))
