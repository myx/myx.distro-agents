#!/usr/bin/env python3
## runner-pass-keeper.py -- the pass keeper of sh-test/AgentsRunTests.sh, the one maker of a key and the one reader of the record.
##   key <dir> <age seconds> <what the tests run under> <name>=<folder>... -- <test>...
##     prints for each test `<test> <key> <when>`: the key of the state it would run on now, and the time of the pass on record under it, where one younger
##     than the age is; `-` for a key that cannot be made (a file that cannot be read, or one gone mid-read: no key, so no pass is kept or found), and for no
##     pass. A root is every file below it, links followed and .git left out, by its path below the root, whether it may be run, and its content.
##   prune <dir> <age seconds>   removes every record older than the age, of every test.
import hashlib
import os
import re
import stat
import sys
import time

args = sys.argv[1:]
if len(args) < 3:
    sys.exit(2)
mode, directory, age = args[0], args[1], float(args[2])
args = args[3:]


def entries(folder):
    try:
        return [name for name in os.listdir(folder) if name not in (".", "..")]
    except OSError:
        return []


if mode == "prune":
    for test in entries(directory):
        base = os.path.join(directory, test)
        if not os.path.isdir(base):
            continue
        for name in entries(base):
            try:
                if time.time() - os.stat(os.path.join(base, name)).st_mtime >= age:
                    os.unlink(os.path.join(base, name))
            except OSError:
                pass
        try:
            os.rmdir(base)
        except OSError:
            pass
    sys.exit(0)


def digest(root):
    real = os.path.realpath(root)
    if not os.path.isdir(real):
        return "none"
    found = {}
    seen = set()
    base = os.fsencode(real)
    for here, folders, files in os.walk(base, followlinks=True):
        try:
            mark = os.stat(here)
            if (mark.st_dev, mark.st_ino) in seen:
                folders[:] = []
                continue
            seen.add((mark.st_dev, mark.st_ino))
        except OSError:
            folders[:] = []
            continue
        folders[:] = [name for name in folders if name != b".git"]
        for name in files:
            path = os.path.join(here, name)
            found[path[len(base) + 1:]] = path
    total = hashlib.sha256()
    for name in sorted(found):
        path = found[name]
        try:
            info = os.stat(path)
        except OSError:
            info = None
        if info is not None and stat.S_ISREG(info.st_mode):
            content = hashlib.sha256()
            with open(path, "rb") as handle:
                for block in iter(lambda: handle.read(1 << 20), b""):
                    content.update(block)
            content = content.hexdigest().encode()
        else:
            content = b"gone"
        executable = b"x" if info is not None and info.st_mode & 0o111 else b"-"
        total.update(name + b"\0" + executable + b"\0" + content + b"\n")
    return total.hexdigest()


with_text = args[0]
rest = args[1:]
roots, tests = [], []
while rest:
    word = rest.pop(0)
    if word == "--":
        tests = rest
        break
    roots.append(word)

try:
    state = "AgentsRunTests.sh pass v1\n"
    for root in sorted(roots):
        name, _, folder = root.partition("=")
        state += "%s %s\n" % (name, digest(folder))
    state += "with %s\n" % with_text
except Exception:
    state = None

for test in tests:
    key, when = "-", "-"
    if state is not None:
        key = hashlib.sha256((state + "test %s\n" % test).encode("utf-8", "surrogateescape")).hexdigest()
        record = os.path.join(directory, test, key)
        try:
            if time.time() - os.stat(record).st_mtime < age:
                with open(record, errors="replace") as handle:
                    for line in handle:
                        found_when = re.match(r"^passed=([0-9TZ:-]+)$", line)
                        if found_when:
                            when = found_when.group(1)
        except OSError:
            pass
    print("%s %s %s" % (test, key, when))
