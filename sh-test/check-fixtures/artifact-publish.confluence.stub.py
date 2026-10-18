#!/usr/bin/env python3
## Offline stand-in for the Confluence REST API behind the fake curl of
## AgentsArtifactPublishCheck.test.sh. Reads the curl arguments, answers as curl with
## -w '\n%{http_code}' does, and keeps its pages under $RIG_SCENARIO/conf. Opens no socket.
## Logs one line per call to conf/calls: method, path, the user half of the credential.
import base64
import json
import os
import sys
import urllib.parse

state = os.path.join(os.environ["RIG_SCENARIO"], "conf")
os.makedirs(state, exist_ok=True)
args = sys.argv[1:]
header = sys.stdin.read()
method, url, body_file, attach = "GET", "", None, None
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
    if arg == "-F":
        attach = args[index + 1].split("=@", 1)[1]
        index += 2
        continue
    if arg in ("-H", "-w", "--connect-timeout", "--max-time"):
        index += 2
        continue
    if arg.startswith("https://"):
        url = arg
    index += 1
user = "-"
if "Basic " in header:
    user = base64.b64decode(header.split("Basic ", 1)[1].strip()).decode("utf-8").split(":")[0]
parts = urllib.parse.urlsplit(url)
path, query = parts.path, urllib.parse.parse_qs(parts.query)
with open(os.path.join(state, "calls"), "a") as handle:
    handle.write("%s %s %s\n" % (method, path, user))
pages_path = os.path.join(state, "pages.json")
pages = json.load(open(pages_path)) if os.path.exists(pages_path) else []


def answer(status, payload):
    sys.stdout.write(json.dumps(payload) + "\n" + str(status))
    sys.exit(0)


def save():
    with open(pages_path, "w") as handle:
        json.dump(pages, handle)


def page_view(page):
    return {"id": page["id"], "title": page["title"], "version": {"number": page["version"]},
            "body": {"storage": {"value": page["body"]}}}


if not parts.netloc.endswith(".invalid"):
    answer(599, {"message": "rig: a call left the fake site"})
if method == "GET" and path == "/wiki/api/v2/spaces":
    answer(200, {"results": [{"id": "777", "key": "TEAM"}] if query.get("keys") == ["TEAM"] else []})
if method == "GET" and path == "/wiki/api/v2/pages":
    title = query.get("title", [""])[0]
    answer(200, {"results": [{"id": p["id"], "title": p["title"]} for p in pages if p["title"] == title]})
if method == "POST" and path == "/wiki/api/v2/pages":
    if os.path.exists(os.path.join(state, "fail-create")):
        answer(500, {"message": "rig: the site failed"})
    sent = json.load(open(body_file))
    if any(p["title"] == sent["title"] for p in pages):
        answer(400, {"message": "A page with this title already exists"})
    page = {"id": str(1001 + len(pages)), "title": sent["title"], "parent": sent.get("parentId", ""),
            "space": sent["spaceId"], "version": 1, "body": sent["body"]["value"]}
    pages.append(page)
    save()
    answer(200, {"id": page["id"], "title": page["title"],
                 "_links": {"base": "https://rig.atlassian.invalid/wiki", "webui": "/spaces/TEAM/pages/%s" % page["id"]}})
if method == "POST" and path.startswith("/wiki/rest/api/content/") and path.endswith("/child/attachment"):
    with open(os.path.join(state, "attachments"), "a") as handle:
        handle.write("%s\t%s\n" % (path.split("/")[5], os.path.basename(attach or "")))
    answer(200, {"results": [{"id": "att-1"}]})
if path.startswith("/wiki/api/v2/pages/"):
    found = [p for p in pages if p["id"] == path.rsplit("/", 1)[1]]
    if not found:
        answer(404, {"message": "no such page"})
    if method == "GET":
        answer(200, page_view(found[0]))
    if method == "PUT":
        sent = json.load(open(body_file))
        if sent["version"]["number"] != found[0]["version"] + 1:
            answer(409, {"message": "version conflict"})
        found[0].update({"version": sent["version"]["number"], "body": sent["body"]["value"], "title": sent["title"]})
        save()
        answer(200, page_view(found[0]))
answer(404, {"message": "rig: unhandled %s %s" % (method, path)})
