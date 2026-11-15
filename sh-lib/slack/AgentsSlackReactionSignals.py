#!/usr/bin/env python3
##
## AgentsSlackReactionSignals.py -- the reactions people put on the team's own posts, read from one Slack response.
## Python because the response is JSON with nested reaction lists, which no line tool reads soundly.
##
## stdin: a Slack API response (conversations.history, conversations.replies, or any that carries `messages`).
## argv[1]: the team's own account ids, space-separated (the mention cache's); argv[2]: the conversation id, may be "-".
## stdout: one line per reaction on a message the team posted, by anyone but the message's own author, tab-separated:
##   <conversation> <message ts> <emoji name> <reacting account> <addressees>
## <addressees> are the accounts the message's header names (<@U...> on its first line), space-separated, or "-".
## A message is the team's own where its user is one of those accounts or it carries a bot_id.
import re
import json
import sys


def main():
    own = set((sys.argv[1] if len(sys.argv) > 1 else "").split())
    conversation = sys.argv[2] if len(sys.argv) > 2 else "-"
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    messages = data.get("messages") or ([data.get("message")] if isinstance(data.get("message"), dict) else [])
    for message in messages:
        if not isinstance(message, dict):
            continue
        author = message.get("user", "")
        if author not in own and not message.get("bot_id"):
            continue
        first = str(message.get("text", "")).split("\n", 1)[0]
        addressees = " ".join(dict.fromkeys(re.findall(r"<@(U[A-Z0-9]+)>", first))) or "-"
        for reaction in message.get("reactions") or []:
            for user in reaction.get("users") or []:
                if user == author:
                    continue
                print("\t".join((conversation, str(message.get("ts", "")), str(reaction.get("name", "")), user, addressees)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
