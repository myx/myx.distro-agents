#!/usr/bin/env python3
## Reads shrunk users.list rows from stdin -- one member per line, tab-separated
## id/name/display_name/real_name, as AgentsHarnessJsonField.awk's own records mode
## projects them (sh-lib/AgentsTools.MagicComms.include, AgentsToolsCommsSlackResolveIds).
## Never the full users.list JSON: that stayed in the shell, shrunk before this ran.
import os
import sys

names = [x.strip() for x in os.environ.get("USER_NAMES_CSV", "").split(",") if x.strip()]
if not names:
    raise SystemExit(0)

rows = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    cols = line.split("\t")
    cols += [""] * (4 - len(cols))
    rows.append(cols[:4])

for query in names:
    ql = query.lower()
    for member_id, name, display_name, real_name in rows:
        if ql in (name.lower(), display_name.lower(), real_name.lower()):
            print(
                "USER_MATCH|%s|%s|%s|%s"
                % (query, member_id, name, display_name)
            )
