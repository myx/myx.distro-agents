#!/usr/bin/env python3
## rig-origin-forms.py <file>... -- the includes (`. <target>` or `source <target>`, outside a comment) of the files that name a file of a package's sh-lib in any form but the one,
## `myx/<package>/sh-lib/<file>` after $MDLT_ORIGIN or its default, as `<file>:<line>: <target>`. RIG_SHLIB_NAMES names the file that lists the names of the sh-lib files, one a line.
## (sh-test/common/AgentsOriginPathsExistCheck.test.sh)
import os
import re
import sys

FORM = re.compile(r"""(?:^|[;&|({]|\bthen|\bdo|\belse)\s*(?:\.|source)\s+("[^"]*"|'[^']*'|[^\s;&|)]+)""")
THE_ONE = re.compile(r"^(?:\$MDLT_ORIGIN|\$\{MDLT_ORIGIN(?::[-=][^}]*)?\})/myx/[A-Za-z0-9._-]+/sh-lib/[A-Za-z0-9._/-]+$")
NAME = re.compile(r"^[A-Za-z0-9._-]+$")

with open(os.environ["RIG_SHLIB_NAMES"], encoding="utf-8") as names:
    shlib = set(line.rstrip("\n") for line in names)

for name in sys.argv[1:]:
    try:
        handle = open(name, encoding="utf-8", errors="replace")
    except OSError:
        sys.exit(2)
    with handle:
        for number, line in enumerate(handle, 1):
            if re.match(r"^\s*#", line):
                continue
            for match in FORM.finditer(line):
                target = match.group(1)
                bare = re.sub(r"""^["']|["']$""", "", target)
                if THE_ONE.match(bare):
                    continue
                base = re.sub(r"^.*/", "", bare)
                if NAME.match(base) and base in shlib:
                    print("%s:%d: %s" % (name, number, target))
