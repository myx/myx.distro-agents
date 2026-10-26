#!/usr/bin/env python3
## rig-mktemp-sites.py <word> <file>... -- each call of <word> (the name of the temp-file command) in the place of a command in the files, as `<file>:<line>: [<why>] <line>` where it
## takes the option t, has no template, or has a template that holds no `/` and starts at no variable (sh-test/AgentsTempNamesCheck.test.sh, rule 2).
## A comment line is prose and is not read. A line is read call by call, to the end of each command.
import re
import sys

word = sys.argv[1]
call_pattern = re.compile(r"(?:^\s*|[$(`;|&=]\s*|\bthen\s+|\bdo\s+|\bexec\s+)" + re.escape(word) + r"\b([^)|;&`]*)(.*)$")

for name in sys.argv[2:]:
    try:
        handle = open(name, encoding="utf-8", errors="replace")
    except OSError:
        continue
    with handle:
        for number, raw in enumerate(handle, 1):
            line = raw.rstrip("\n")
            if re.match(r"^\s*#", line):
                continue
            rest = line
            while True:
                match = call_pattern.search(rest)
                if not match:
                    break
                call, rest = match.group(1), match.group(2)
                bad = ""
                template = None
                for one in call.split():
                    if template is None and one.startswith("-"):
                        if re.match(r"^-[A-Za-z]*t", one):
                            bad = "it takes -t"
                        continue
                    if template is None:
                        template = one
                if not bad:
                    if template is None:
                        bad = "it has no template"
                    else:
                        plain = re.sub(r"""^["']""", "", template)
                        if "/" not in plain and not plain.startswith("$"):
                            bad = "its template is a bare name"
                if bad:
                    print("%s:%d: [%s] %s" % (name, number, bad, line))
