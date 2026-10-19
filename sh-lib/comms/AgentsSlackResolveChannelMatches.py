#!/usr/bin/env python3
import json
import os

resp = json.loads(os.environ.get("CHANNELS_JSON", "{}"))
queries = [x.strip() for x in os.environ.get("CHANNEL_NAMES_CSV", "").split(",") if x.strip()]
channels = resp.get("channels") or []

for query in queries:
    ql = query.lower()
    for channel in channels:
        name = channel.get("name") or ""
        if name.lower() == ql:
            print(
                "CHANNEL_MATCH|%s|%s|%s|is_member=%s|is_private=%s|is_im=%s"
                % (
                    query,
                    channel.get("id", ""),
                    name,
                    str(channel.get("is_member", False)).lower(),
                    str(channel.get("is_private", False)).lower(),
                    str(channel.get("is_im", False)).lower(),
                )
            )
