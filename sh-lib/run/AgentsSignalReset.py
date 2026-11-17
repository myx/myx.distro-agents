#!/usr/bin/env python3
## AgentsSignalReset.py <command> [argument...] -- every signal a shell may have inherited as ignored goes back to its default, then the command is
## exec'd in this same process. Python itself ignores SIGPIPE and SIGXFSZ at start, so those are given back too. Ends 127 where it cannot exec.
import os
import signal
import sys

for name in ("SIGHUP", "SIGINT", "SIGQUIT", "SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGALRM", "SIGVTALRM", "SIGPROF", "SIGPIPE", "SIGUSR1", "SIGUSR2", "SIGTERM", "SIGXFSZ"):
    number = getattr(signal, name, None)
    if number is not None:
        signal.signal(number, signal.SIG_DFL)

if len(sys.argv) < 2:
    sys.exit(127)
try:
    os.execvp(sys.argv[1], sys.argv[1:])
except OSError:
    sys.exit(127)
