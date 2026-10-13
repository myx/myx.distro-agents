#!/usr/bin/env python3
## Reads shrunk users.list rows from stdin -- one member per line, tab-separated
## id/name/display_name/real_name, as AgentsHarnessJsonField.awk's own records mode
## projects them (sh-lib/AgentsTools.MagicComms.include, AgentsToolsCommsSlackResolveIds).
## Never the full users.list JSON: that stayed in the shell, shrunk before this ran.
import os
import sys

hint = os.environ.get("HINT", "").strip().lower()
if not hint:
    raise SystemExit(0)

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    cols = line.split("\t")
    cols += [""] * (4 - len(cols))
    member_id, name, display_name, real_name = cols[:4]
    if hint in (name.lower(), display_name.lower(), real_name.lower()):
        print(member_id)
        break
