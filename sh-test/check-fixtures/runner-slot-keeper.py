#!/usr/bin/env python3
## runner-slot-keeper.py -- the slot keeper of sh-test/AgentsRunTests.sh, one small program for both ends of a slot: every change to the one state file
## ($dir/state: `H <pid>` a slot held, `W <pid>` one asked for, in arrival order) is made under an exclusive lock on $dir/lock, which the system gives back by
## itself when its holder dies, and an entry whose process no longer exists is dropped at every read.
##   take <dir> <default budget> <fd to say it on> <said marker> <started file> <hand lock> <own folder> <timeout> <command...>
##     asks for a slot as this very process, waits its place in the line, and while another session holds the hand lock, then lowers its priority,
##     sets the test's own time limit and becomes the command: the slot is held by the test's own pid from before it starts until that process is gone.
##   give <dir> <pid>   gives that process's slot back at once, where the runner saw it end.
import errno
import fcntl
import glob
import os
import re
import signal
import sys
import time


def die(text):
    sys.stderr.write("AgentsRunTests.sh: %s\n" % text)
    sys.exit(255)


args = sys.argv[1:]
if len(args) < 2:
    die("the slot keeper takes a mode and a folder")
mode, state_dir = args[0], args[1]
args = args[2:]


def locked(code):
    try:
        lock = open(os.path.join(state_dir, "lock"), "a")
    except OSError as error:
        die("cannot open %s/lock: %s" % (state_dir, error.strerror))
    try:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return code()
    finally:
        lock.close()


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError as error:
        return error.errno == errno.EPERM


def load():
    held, asked = [], []
    try:
        with open(os.path.join(state_dir, "state")) as handle:
            for line in handle:
                found = re.match(r"^H ([0-9]+)$", line)
                if found:
                    held.append(int(found.group(1)))
                found = re.match(r"^W ([0-9]+)$", line)
                if found:
                    asked.append(int(found.group(1)))
    except OSError:
        pass
    return [pid for pid in held if alive(pid)], [pid for pid in asked if alive(pid)]


def save(held, asked):
    temporary = os.path.join(state_dir, "state.%d" % os.getpid())
    try:
        with open(temporary, "w") as out:
            out.write("".join("H %d\n" % pid for pid in held) + "".join("W %d\n" % pid for pid in asked))
        os.rename(temporary, os.path.join(state_dir, "state"))
    except OSError as error:
        die("cannot write %s: %s" % (temporary, error.strerror))


if mode == "give":
    give_pid = int(args[0])

    def give():
        held, asked = load()
        save([pid for pid in held if pid != give_pid], [pid for pid in asked if pid != give_pid])

    locked(give)
    sys.exit(0)

if mode != "take" or len(args) < 8:
    die("the slot keeper takes `take` with its arguments, or `give`")
default, say, said, started, hand, own, timeout = args[0], int(args[1]), args[2], args[3], args[4], args[5], int(args[6])
command = args[7:]
me = os.getpid()


def held_by_another():
    """The hand lock, where another session holds it: what that session wrote in it, on one line. Empty where no other holds it."""
    if own == "" or not os.path.isdir(hand):
        return ""
    note = ""
    for name in sorted(glob.glob(os.path.join(hand, "*"))):
        try:
            with open(name, errors="replace") as handle:
                note += " " + handle.read()
        except OSError:
            pass
    note = re.sub(r"\s+", " ", note)
    note = re.sub(r"^ | $", "", note)
    if own in re.split(r"[^A-Za-z0-9._-]+", note):
        return ""
    return "(no owner written in it)" if note == "" else note[:200]


def ask():
    held, asked = load()
    budget = int(default)
    try:
        with open(os.path.join(state_dir, "budget")) as handle:
            text = handle.readline().rstrip()
            if re.match(r"^[1-9][0-9]*$", text):
                budget = int(text)
    except OSError:
        pass
    if me not in asked:
        asked.append(me)
    place = asked.index(me)
    got, tell = 0, 0
    other = held_by_another()
    if other == "" and place < budget - len(held):
        asked.pop(place)
        held.append(me)
        got = 1
    else:
        # said once a minute at most for a whole run, whichever of its tests waits
        try:
            quiet = time.time() - os.stat(said).st_mtime < 60
        except OSError:
            quiet = False
        if not quiet:
            try:
                open(said, "w").close()
            except OSError:
                pass
            tell = 1
    save(held, asked)
    return got, len(held), budget, tell, other


while True:
    got, used, budget, tell, other = locked(ask)
    if got:
        break
    if tell:
        try:
            out = os.fdopen(os.dup(say), "w")
            if other != "":
                out.write("# AgentsRunTests.sh: a test waits: another session holds %s by hand (%s), and no test starts beside a run that holds it\n" % (hand, other))
            else:
                out.write("# AgentsRunTests.sh: a test waits for a worker slot: %d of %d in use on this machine, the one budget every runner shares (%s)\n" % (used, budget, state_dir))
            out.close()
        except OSError:
            pass
    time.sleep(0.2)

try:
    with open(started, "w") as out:
        out.write("%d\n" % int(time.time()))
except OSError:
    pass
try:
    os.close(say)
except OSError:
    pass
try:
    if os.getpriority(os.PRIO_PROCESS, 0) < 10:
        os.setpriority(os.PRIO_PROCESS, 0, 10)
except OSError:
    pass
signal.alarm(timeout)
try:
    os.execvp(command[0], command)
except OSError as error:
    die("cannot start %s: %s" % (" ".join(command), error.strerror))
