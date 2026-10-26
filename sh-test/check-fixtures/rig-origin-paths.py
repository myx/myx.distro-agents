#!/usr/bin/env python3
## rig-origin-paths.py <file>... -- every whole path spelled after $MDLT_ORIGIN (or ${MDLT_ORIGIN}) in the files, as `<file>|<path below the origin>`, one a line
## (sh-test/common/AgentsOriginPathsExistCheck.test.sh). A path that goes on into a glob, a variable or a command word is no whole path, one that ends in `-` or `/` is a prefix.
import re
import sys

PATH = re.compile(r"\$\{?MDLT_ORIGIN\}?/(myx/[A-Za-z0-9._/-]+)(?![A-Za-z0-9._/${*?\[(-])(?![\"'][*${])")

for name in sys.argv[1:]:
    try:
        handle = open(name, encoding="utf-8", errors="replace")
    except OSError:
        sys.exit(2)
    with handle:
        for line in handle:
            for match in PATH.finditer(line):
                path = match.group(1).rstrip(".")
                if path.endswith("-") or path.endswith("/"):
                    continue
                print("%s|%s" % (name, path))
