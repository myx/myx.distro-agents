#!/usr/bin/env python3
## rig-exec.py [--alarm <seconds>] [--default-signals <HUP,INT,...>] [--chdir <folder>|--chdir-env <variable>] [--setpgrp] -- <command> [argument...]
## What a test rig runs a command through: a bound in seconds (SIGALRM, whose default ends the process), signals given back their defaults, a working
## folder, a process group of its own; then the command is exec'd in this same process. Ends 127 where it cannot exec, 98 where the folder is not there.
import os
import signal
import sys

args = sys.argv[1:]
alarm = 0
names = []
folder = ""
own_group = False
while args and args[0] != "--":
    option = args.pop(0)
    if option == "--alarm":
        alarm = int(args.pop(0))
    elif option == "--default-signals":
        names = [name for name in args.pop(0).split(",") if name]
    elif option == "--chdir":
        folder = args.pop(0)
    elif option == "--chdir-env":
        folder = os.environ.get(args.pop(0), "") or "/nonexistent-rig-folder"
    elif option == "--setpgrp":
        own_group = True
    else:
        sys.stderr.write("rig-exec.py: unknown option: %s\n" % option)
        sys.exit(2)
if args and args[0] == "--":
    args.pop(0)
if not args:
    sys.exit(127)

for name in names:
    signal.signal(getattr(signal, "SIG" + name), signal.SIG_DFL)
if folder:
    try:
        os.chdir(folder)
    except OSError:
        sys.exit(98)
if own_group:
    os.setpgid(0, 0)
if alarm:
    signal.alarm(alarm)
try:
    os.execvp(args[0], args)
except OSError:
    sys.exit(127)
