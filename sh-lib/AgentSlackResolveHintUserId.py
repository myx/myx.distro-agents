#!/usr/bin/env python3
import json
import os

resp = json.loads(os.environ.get("USERS_JSON", "{}"))
hint = os.environ.get("HINT", "").strip().lower()
if not hint:
    raise SystemExit(0)

members = resp.get("members") or []
for member in members:
    profile = member.get("profile") or {}
    candidates = [
        member.get("name", ""),
        profile.get("display_name", ""),
        profile.get("real_name", ""),
    ]
    if any(hint == (candidate or "").lower() for candidate in candidates):
        print(member.get("id", ""))
        break
