#!/usr/bin/env python3
import json
import os

resp = json.loads(os.environ.get("USERS_JSON", "{}"))
names = [x.strip() for x in os.environ.get("USER_NAMES_CSV", "").split(",") if x.strip()]
members = resp.get("members") or []

for query in names:
    ql = query.lower()
    for member in members:
        profile = member.get("profile") or {}
        candidates = [
            member.get("name", ""),
            profile.get("display_name", ""),
            profile.get("real_name", ""),
        ]
        if any(ql == candidate.lower() for candidate in candidates if candidate):
            print(
                "USER_MATCH|%s|%s|%s|%s"
                % (
                    query,
                    member.get("id", ""),
                    member.get("name", ""),
                    profile.get("display_name", ""),
                )
            )
