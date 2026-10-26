#!/usr/bin/env python3
## rig-hold.py <mode> <argument>... -- a stand-in process a test rig starts and later signals, each doing what its mode says and then holding for the seconds given:
##   ignore-term-pid <file> <seconds>    ignores TERM, writes its own pid to the file, holds
##   ignore-term-ready <file> <seconds>  ignores TERM, creates the file empty, holds
##   zombie-child <file> <seconds>       starts a child that ends at once and is never collected, writes the child's pid to the file, holds
##   late-child <seconds>                starts a child that ends after 2 seconds, prints its pid and closes standard output, holds
import os
import signal
import sys
import time

mode = sys.argv[1] if len(sys.argv) > 1 else ""
args = sys.argv[2:]

if mode == "ignore-term-pid" and len(args) == 2:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    with open(args[0], "w") as handle:
        handle.write("%d\n" % os.getpid())
    time.sleep(int(args[1]))
elif mode == "ignore-term-ready" and len(args) == 2:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    open(args[0], "w").close()
    time.sleep(int(args[1]))
elif mode == "zombie-child" and len(args) == 2:
    child = os.fork()
    if child == 0:
        os._exit(0)
    with open(args[0], "w") as handle:
        handle.write("%d\n" % child)
    time.sleep(int(args[1]))
elif mode == "late-child" and len(args) == 1:
    child = os.fork()
    if child == 0:
        time.sleep(2)
        os._exit(0)
    sys.stdout.write("%d\n" % child)
    sys.stdout.flush()
    sys.stdout.close()
    time.sleep(int(args[0]))
else:
    sys.stderr.write("rig-hold.py: unknown mode or wrong arguments: %s\n" % mode)
    sys.exit(2)
