#!/usr/bin/env python3
## rig-origin-paths.py <file>... -- every whole path spelled after $MDLT_ORIGIN (or ${MDLT_ORIGIN}) in the files, as `<file>|<path below the origin>`, one a line
## (sh-test/common/AgentsOriginPathsExistCheck.test.sh). A path that goes on into a glob, a variable, a command word or a backslash is no whole path, one that ends in `-` or `/` is a prefix.
## A body of a QUOTED here-doc (`<<'WORD'`, `<<"WORD"`, `<<-'WORD'`) is fixture text a check writes for its rig and never a load of this
## package: the body is left out, and the line that opens the here-doc is read as every other line is.
import re
import sys

PATH = re.compile(r"\$\{?MDLT_ORIGIN\}?/(myx/[A-Za-z0-9._/-]+)(?![A-Za-z0-9._/${*?\[(\\-])(?![\"'][*${])")
HEREDOC = re.compile(r"<<-?[ \t]*(?:'([A-Za-z_][A-Za-z0-9_]*)'|\"([A-Za-z_][A-Za-z0-9_]*)\")")

for name in sys.argv[1:]:
    try:
        handle = open(name, encoding="utf-8", errors="replace")
    except OSError:
        sys.exit(2)
    with handle:
        body = None
        for line in handle:
            if body is not None:
                if line.strip() == body:
                    body = None
                continue
            opened = HEREDOC.search(line)
            for match in PATH.finditer(line):
                path = match.group(1).rstrip(".")
                if path.endswith("-") or path.endswith("/"):
                    continue
                print("%s|%s" % (name, path))
            if opened:
                body = opened.group(1) or opened.group(2)
