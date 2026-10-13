#!/usr/bin/env python3
## Reads shrunk users.list rows from stdin -- one member per line, tab-separated
## id/name/display_name/real_name, as AgentsHarnessJsonField.awk's own records mode
## projects them (sh-lib/AgentsTools.MagicComms.include, AgentsToolsCommsSlackResolveIds).
## Never the full users.list JSON: that stayed in the shell, shrunk before this ran.
## Capped at MATCH_MAX matches total, across every named query together -- a
## fixed bound, not a setting: one bounded, un-paginated fetch already limits the
## rows this sees, and this is the second, independent limit on what is returned.
## A capped result and a total miss each end with one SEARCH_HINT line: how many
## users this one page held, that repeating the same call changes nothing, and
## to narrow the term or give a known id instead.
import os
import sys

MATCH_MAX = 10

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

rows_searched = len(rows)
emitted = 0
capped = False
for query in names:
    ql = query.lower()
    for member_id, name, display_name, real_name in rows:
        if ql in (name.lower(), display_name.lower(), real_name.lower()):
            print(
                "USER_MATCH|%s|%s|%s|%s"
                % (query, member_id, name, display_name)
            )
            emitted += 1
            if emitted >= MATCH_MAX:
                capped = True
                break
    if capped:
        break

if capped or emitted == 0:
    print(
        "SEARCH_HINT|searched=%d|note=repeating this same call changes nothing -- narrow the term, or give a known id"
        % rows_searched
    )
