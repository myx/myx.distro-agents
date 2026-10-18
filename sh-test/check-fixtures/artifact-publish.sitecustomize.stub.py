## Offline stand-in for the Google APIs, copied as sitecustomize.py onto PYTHONPATH by
## AgentsArtifactPublishCheck.test.sh: urllib.request.urlopen answers from state under
## $RIG_SCENARIO/google, and any other host is refused. Opens no socket.
## google/folders.json: the folders, [{"id","name","parent"}], seeded by the check.
## google/uploads: one JSON line per upload -- name, mimeType, parents, the media type and file.
## google/trashed: one line per files.update, the id and the fields sent. google/requests logs
## every method, so a DELETE would show there. google/permissions: one line per
## permissions.create, the id, the body and the query; google/fail-share refuses them all.
## google/email: the account about.get answers for (default magic-tester@rig-org.example).
import io
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

_state = os.path.join(os.environ.get("RIG_SCENARIO", "/nonexistent"), "google")


class _Answer(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_ignored):
        self.close()


def _json(payload):
    return _Answer(json.dumps(payload).encode("utf-8"))


def _load(name):
    path = os.path.join(_state, name)
    return json.load(open(path)) if os.path.exists(path) else []


def _fake_urlopen(request, data=None, timeout=None, **_ignored):
    url = request.full_url if hasattr(request, "full_url") else request
    method = request.get_method()
    body = request.data or b""
    os.makedirs(_state, exist_ok=True)
    with open(os.path.join(_state, "requests"), "a") as handle:
        handle.write("%s %s\n" % (method, url.split("?")[0]))
    parts = urllib.parse.urlsplit(url)
    if url.startswith("https://oauth2.googleapis.com/token"):
        return _json({"access_token": "rig-access"})
    if parts.netloc != "www.googleapis.com":
        raise urllib.error.URLError("rig: no network beyond the stand-in")
    folders = _load("folders.json")
    if parts.path == "/drive/v3/files" and method == "GET":
        query = urllib.parse.parse_qs(parts.query)["q"][0]
        name = re.search(r"name = '((?:[^'\\]|\\.)*)'", query).group(1).replace("\\'", "'").replace("\\\\", "\\")
        parent = re.search(r"'([A-Za-z0-9_-]+)' in parents", query)
        found = [f for f in folders if f["name"] == name and (not parent or f["parent"] == parent.group(1))]
        return _json({"files": [{"id": f["id"], "name": f["name"], "webViewLink": "https://drive.rig.invalid/%s" % f["id"]} for f in found]})
    if parts.path == "/drive/v3/files" and method == "POST":
        sent = json.loads(body)
        folder = {"id": "folder-%d" % (len(folders) + 1), "name": sent["name"], "parent": sent["parents"][0]}
        folders.append(folder)
        with open(os.path.join(_state, "folders.json"), "w") as handle:
            json.dump(folders, handle)
        return _json({"id": folder["id"], "webViewLink": "https://drive.rig.invalid/%s" % folder["id"]})
    if parts.path == "/upload/drive/v3/files" and method == "POST":
        boundary = request.get_header("Content-type").split("boundary=", 1)[1]
        pieces = body.split(("--%s" % boundary).encode("ascii"))
        meta = json.loads(pieces[1].split(b"\r\n\r\n", 1)[1].rstrip(b"\r\n"))
        media_head, media = pieces[2].split(b"\r\n\r\n", 1)
        number = len(open(os.path.join(_state, "uploads")).readlines()) + 1 if os.path.exists(os.path.join(_state, "uploads")) else 1
        media_file = os.path.join(_state, "upload-%d.bin" % number)
        with open(media_file, "wb") as handle:
            handle.write(media[:-2] if media.endswith(b"\r\n") else media)
        with open(os.path.join(_state, "uploads"), "a") as handle:
            handle.write(json.dumps({"name": meta.get("name"), "mimeType": meta.get("mimeType", ""), "parents": meta.get("parents"),
                                     "mediaType": media_head.decode("ascii").split("Content-Type: ", 1)[1], "file": media_file}) + "\n")
        return _json({"id": "file-%d" % number, "webViewLink": "https://docs.rig.invalid/file-%d" % number})
    if parts.path == "/drive/v3/about" and method == "GET":
        email_path = os.path.join(_state, "email")
        email = open(email_path).read().strip() if os.path.exists(email_path) else "magic-tester@rig-org.example"
        return _json({"user": {"emailAddress": email, "displayName": "rig", "permissionId": "rig"}})
    if parts.path.startswith("/drive/v3/files/") and parts.path.endswith("/permissions") and method == "POST":
        sent = json.loads(body)
        file_id = parts.path.split("/")[4]
        with open(os.path.join(_state, "permissions"), "a") as handle:
            handle.write("%s %s %s\n" % (file_id, json.dumps(sent, sort_keys=True), parts.query))
        if os.path.exists(os.path.join(_state, "fail-share")):
            raise urllib.error.HTTPError(url, 403, "rig: sharing refused", {}, io.BytesIO(b'{"error":"rig sharing refused"}'))
        return _json({"id": "perm-%s" % file_id, "type": sent.get("type"), "role": sent.get("role"), "domain": sent.get("domain")})
    if parts.path.startswith("/drive/v3/files/") and method == "PATCH":
        sent = json.loads(body)
        file_id = parts.path.rsplit("/", 1)[1]
        with open(os.path.join(_state, "trashed"), "a") as handle:
            handle.write("%s %s\n" % (file_id, json.dumps(sent, sort_keys=True)))
        return _json({"id": file_id, "trashed": bool(sent.get("trashed"))})
    raise urllib.error.HTTPError(url, 404, "rig: unhandled", {}, io.BytesIO(b'{"error":"rig unhandled"}'))


urllib.request.urlopen = _fake_urlopen
