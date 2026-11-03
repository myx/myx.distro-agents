#!/usr/bin/env python3
## The fake `curl` for AgentsInvestigatePublishCheck: one stand-in for the Atlassian site, on the command's own
## arguments, answering as `curl -w '\n%{http_code}'` does. It opens no socket, and it refuses any host that does
## not end `.invalid`, so a call that would leave the rig is answered as a fault rather than made.
## It logs one line per call to $RIG_STATE/calls -- host, method, path, and the user half of the credential -- so a
## check can say which identity reached which product. State it keeps under $RIG_STATE: pages.json, issues.json,
## links.json. A remote link with a globalId the issue already holds replaces that link, as the real site does.
## GET of an issue's remote links answers them as the bare array the real site sends, each with its own id.
## The seeded issue RIG-9 is the task the report was already filed as, for the branch that finds it and links it.
import base64
import json
import os
import sys
import urllib.parse

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
parts = urllib.parse.urlsplit(url)
path, query = parts.path, urllib.parse.parse_qs(parts.query)
with open(os.path.join(state, "calls"), "a") as handle:
    handle.write("%s %s %s %s\n" % (parts.hostname, method, path, user))

seeded = {"key": "RIG-9", "summary": "The task this report was already filed as",
          "issuetype": "Task", "status": "In Progress"}
issues_path = os.path.join(state, "issues.json")
pages_path = os.path.join(state, "pages.json")
issues = json.load(open(issues_path)) if os.path.exists(issues_path) else [seeded]
pages = json.load(open(pages_path)) if os.path.exists(pages_path) else []


def answer(status, payload):
    sys.stdout.write(json.dumps(payload) + "\n" + str(status))
    sys.exit(0)


def keep(path, value):
    with open(path, "w") as handle:
        json.dump(value, handle)


def issue_view(issue):
    return {"key": issue["key"],
            "fields": {"summary": issue["summary"],
                       "issuetype": {"name": issue["issuetype"]},
                       "status": {"name": issue["status"]},
                       "updated": "2026-11-03T07:00:00Z"}}


if not parts.hostname.endswith(".invalid"):
    answer(599, {"message": "rig: a call left the fake site"})

if parts.hostname.startswith("confluence-"):
    if method == "GET" and path == "/wiki/api/v2/spaces":
        answer(200, {"results": [{"id": "777", "key": "TEAM"}] if query.get("keys") == ["TEAM"] else []})
    if method == "POST" and path == "/wiki/api/v2/pages":
        sent = json.load(open(body_file))
        page = {"id": str(1001 + len(pages)), "title": sent["title"], "spaceId": sent["spaceId"],
                "body": sent["body"]["value"], "version": 1}
        pages.append(page)
        keep(pages_path, pages)
        answer(200, {"id": page["id"], "title": page["title"]})
    if method == "GET" and path.startswith("/wiki/api/v2/pages/"):
        found = [p for p in pages if p["id"] == path.rsplit("/", 1)[1]]
        if not found:
            answer(404, {"message": "rig: no such page"})
        answer(200, {"id": found[0]["id"], "title": found[0]["title"], "spaceId": found[0]["spaceId"],
                     "version": {"number": found[0]["version"]},
                     "body": {"storage": {"value": found[0]["body"]}}})
    answer(404, {"message": "rig: unhandled %s %s" % (method, path)})

if parts.hostname.startswith("jira-"):
    if method == "POST" and path == "/rest/api/3/issue":
        sent = json.load(open(body_file))["fields"]
        issue = {"key": "RIG-%s" % (1 + len(issues)), "summary": sent["summary"],
                 "issuetype": sent["issuetype"]["name"], "status": "To Do"}
        issues.append(issue)
        keep(issues_path, issues)
        answer(201, {"id": "20001", "key": issue["key"],
                     "self": "https://jira-rig.invalid/rest/api/3/issue/20001"})
    if method == "POST" and path.startswith("/rest/api/3/issue/") and path.endswith("/remotelink"):
        wanted = path.split("/")[-2]
        if not [issue for issue in issues if issue["key"] == wanted]:
            answer(404, {"message": "rig: no such issue"})
        sent = json.load(open(body_file))
        links_path = os.path.join(state, "links.json")
        links = json.load(open(links_path)) if os.path.exists(links_path) else []
        links = [link for link in links if not (link["issue"] == wanted and link["globalId"] == sent.get("globalId"))]
        links.append({"issue": wanted, "id": len(links) + 1, "globalId": sent.get("globalId"),
                      "url": sent["object"]["url"], "title": sent["object"]["title"]})
        keep(links_path, links)
        answer(201, {"id": len(links), "self": "https://jira-rig.invalid%s/%s" % (path, len(links))})
    if method == "GET" and path.startswith("/rest/api/3/issue/") and path.endswith("/remotelink"):
        wanted = path.split("/")[-2]
        if wanted == "RIG-ODD":
            ## The one answer that is no array of links: a real shape a site can send when the
            ## request is misread, and the case a reader must report UNKNOWN rather than empty.
            answer(200, {"message": "rig: this answer is an object, not the array of links"})
        if not [issue for issue in issues if issue["key"] == wanted]:
            answer(404, {"message": "rig: no such issue"})
        links_path = os.path.join(state, "links.json")
        links = json.load(open(links_path)) if os.path.exists(links_path) else []
        answer(200, [{"id": link["id"], "globalId": link["globalId"],
                      "object": {"url": link["url"], "title": link["title"]}} for link in links if link["issue"] == wanted])
    if method == "GET" and path == "/rest/api/3/search/jql":
        answer(200, {"issues": [issue_view(issue) for issue in issues if issue["key"] == seeded["key"]],
                     "isLast": True})
    if method == "GET" and path.startswith("/rest/api/3/issue/"):
        wanted = path.rsplit("/", 1)[1]
        found = [issue for issue in issues if issue["key"] == wanted]
        if not found:
            answer(404, {"message": "rig: no such issue"})
        answer(200, issue_view(found[0]))
    answer(404, {"message": "rig: unhandled %s %s" % (method, path)})

answer(404, {"message": "rig: unknown host %s" % parts.hostname})
