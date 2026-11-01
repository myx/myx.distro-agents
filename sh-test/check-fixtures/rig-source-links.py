#!/usr/bin/env python3
## rig-source-links.py <file>... -- each `ln -s` in the files whose target is a path of the origin or of the installed
## packages, directly or through a variable the same file takes from one, as `<file>:<line>: <target>`. A link inside a
## rig is no finding: the harm is a rig that reaches the origin (sh-test/common/AgentsRigSourceLinkCheck.test.sh).
import re
import sys

LINK = re.compile(r"(?:^|[(&|;]\s*|\s)ln\s+(?:-[A-Za-z]+\s+)*(\"[^\"]*\"|'[^']*'|[^\s;&|)]+)")
ASSIGN = re.compile(r"^\s*(?:local|export|readonly|typeset)?\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
FORIN = re.compile(r"\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([^;\n]*)")
ROOT = re.compile(r"\$\{?MDLT_ORIGIN\}?|\$\{?MMDAPP\}?/\.local/myx(?:/|\b)")
MENTIONS = r"\$\{?\b%s\b"


def values(lines):
    given = {}
    for line in lines:
        if line.lstrip().startswith("#"):
            continue
        for match in ASSIGN.finditer(line):
            given.setdefault(match.group(1), []).append(match.group(2))
        for match in FORIN.finditer(line):
            given.setdefault(match.group(1), []).append(match.group(2))
    return given


def tainted(given):
    seen = set()
    changed = True
    while changed:
        changed = False
        for name, texts in given.items():
            if name in seen:
                continue
            for text in texts:
                if ROOT.search(text) or any(re.search(MENTIONS % other, text) for other in seen):
                    seen.add(name)
                    changed = True
                    break
    return seen


for name in sys.argv[1:]:
    try:
        handle = open(name, encoding="utf-8", errors="replace")
    except OSError:
        sys.exit(2)
    with handle:
        lines = handle.readlines()
    roots = tainted(values(lines))
    for number, line in enumerate(lines, 1):
        if line.lstrip().startswith("#"):
            continue
        for match in LINK.finditer(line):
            target = match.group(1)
            if ROOT.search(target) or any(re.search(MENTIONS % other, target) for other in roots):
                print("%s:%d: %s" % (name, number, target))
