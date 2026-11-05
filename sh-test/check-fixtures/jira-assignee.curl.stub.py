#!/usr/bin/env python3
## The fake `curl` for AgentsJiraAssigneeCheck: one stand-in for a Jira site, on the command's own arguments, answering as
## `curl -w '\n%{http_code}'` does. It opens no socket, and it refuses any host that does not end `.invalid`, so a call that
## would leave the rig is answered as a fault rather than made. State it keeps under $RIG_STATE: calls (host, method, path,
## user, one a line) and posts.json (the fields of every issue created).
## The site knows two accounts: RIGME (the acting identity, from /myself) and RIGALICE, who answers the assignable search
## for alice@rig.invalid only. Any other address finds nobody, which is the case an assignee must not be guessed for.
import base64
import json
import os
import sys

state = os.environ["RIG_STATE"]
os.makedirs(state, exist_ok=True)
args = sys.argv[1:]
header = sys.stdin.read()
method, url, body_file = "GET", "", None
index = 0
while index < len(args):
    arg = args[index]
    if arg == "-X":
        method = args[index + 1]
        index += 2
        continue
    if arg == "--data-binary":
        body_file = args[index + 1][1:]
        index += 2
        continue
    if arg in ("-H", "-w", "--connect-timeout", "--max-time", "-F"):
        index += 2
        continue
    if arg.startswith("https://"):
        url = arg
    index += 1
user = "-"
if "Basic " in header:
    user = base64.b64decode(header.split("Basic ", 1)[1].strip()).decode("utf-8").split(":")[0]
rest = url.split("://", 1)[-1]
host, _, tail = rest.partition("/")
path, _, query = tail.partition("?")
path = "/" + path
with open(os.path.join(state, "calls"), "a") as handle:
    handle.write("%s %s %s %s %s\n" % (host, method, path, user, query))


def answer(status, payload):
    sys.stdout.write(json.dumps(payload) + "\n" + str(status))
    sys.exit(0)


if not host.endswith(".invalid"):
    answer(599, {"message": "rig: a call left the fake site"})

if method == "GET" and path == "/rest/api/3/myself":
    answer(200, {"accountId": "RIGME", "displayName": "Rig Identity"})

if method == "GET" and path == "/rest/api/3/user/assignable/search":
    if "alice%40rig.invalid" in query:
        answer(200, [{"accountId": "RIGALICE", "displayName": "Alice"}])
    answer(200, [])

if method == "POST" and path == "/rest/api/3/issue":
    sent = json.load(open(body_file))["fields"]
    posts_path = os.path.join(state, "posts.json")
    posts = json.load(open(posts_path)) if os.path.exists(posts_path) else []
    posts.append(sent)
    with open(posts_path, "w") as handle:
        json.dump(posts, handle)
    answer(201, {"id": "20001", "key": "RIG-%s" % (1 + len(posts))})

if method == "PUT" and path.startswith("/rest/api/3/issue/"):
    sent = json.load(open(body_file))
    posts_path = os.path.join(state, "posts.json")
    posts = json.load(open(posts_path)) if os.path.exists(posts_path) else []
    posts.append(sent)
    with open(posts_path, "w") as handle:
        json.dump(posts, handle)
    answer(204, {})

answer(404, {"message": "rig: unhandled %s %s" % (method, path)})
