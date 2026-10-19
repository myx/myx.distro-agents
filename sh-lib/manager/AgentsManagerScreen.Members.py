##
## AgentsManagerScreen.Members.py -- the root Team Members: a member as a folder, its grants and its files, and to start one.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- a team member as a folder: its grants, its files, its sessions, its help ----

## The columns of the table of a member's grants, grouped by their kind, and what of a
## grant stands in each: what it covers by the rule of its location, its access, where it
## comes from, when it ends. The first is cut at that many cells; the grant selected
## shows whole in the left window.
GRANT_COLUMNS = (
    ("COVERS", lambda grant: grant["place"] or grant["target"], "key"),
    ("ACCESS", lambda grant: grant["access"], "enum"),
    ("FROM", lambda grant: grant["origin"], "text"),
    ("ENDS", lambda grant: grant["ends"], "text"),
)
GRANT_COVERS_CELLS = 40


## What the read of a member printed of its grants, as rows (grantRows).
def parseGrantRows(text):
    return grantRows(parseMemberRead(text)["grants"])


## A member's grants as rows: under a heading for each kind, in the order they come, its
## grants as one table, drawn by listTableLines, its first column cut at that many cells (None:
## at TABLE_CAP).
def grantRows(grants, coversCells=GRANT_COVERS_CELLS):
    kinds = []
    for grant in grants:
        if grant["kind"] not in kinds:
            kinds.append(grant["kind"])
    rows = []
    for index, grant in enumerate(grants):
        row = newRow(str(index), grant["place"] or grant["target"], "grant")
        row["grant"] = grant
        rows.append(row)
    words = [[column[1](row["grant"]) or "-" for column in GRANT_COLUMNS] for row in rows]
    table = {"heads": [column[0] for column in GRANT_COLUMNS], "kinds": [column[2] for column in GRANT_COLUMNS], "cut": coversCells or TABLE_CAP}
    for row, line in zip(rows, words):
        row["table"] = table
        row["cells"] = [""] + line
    groups = []
    for kind in kinds:
        head = newRow("kind:" + kind, "%s (%d)" % (kind, len([row for row in rows if row["grant"]["kind"] == kind])), "grant-kind")
        head["grantKind"] = kind
        groups.append((head, [row for row in rows if row["grant"]["kind"] == kind]))
    return groupedRows(groups)


## A member's grants for the left pane, lines of that many cells: the table `Permissions`
## holds, in its order and under its headings (grantRows), drawn by the table of the left
## pane (paneTable): what a grant covers, the key, has its room first.
def grantTableLines(grants, width, wrap=True, pane=None):
    head, blocks = paneTable([column[0] for column in GRANT_COLUMNS], [
        row["label"] if row["kind"] == "grant-kind" else [column[1](row["grant"]) or "-" for column in GRANT_COLUMNS]
        for row in grantRows(grants, None)], width, wrap=wrap, kinds=[column[2] for column in GRANT_COLUMNS], pane=pane)
    return head + [line for block in blocks for line in block]


## One grant, whole: its kind, its access, what it covers as a path and by the rule of its
## location, where it comes from and when it ends.
def grantLines(grant, width):
    return fieldLines([("kind", grant["kind"]), ("access", grant["access"]), ("covers", grant["target"]),
                       ("rule", grant["place"]), ("from", grant["origin"]), ("ends", grant["ends"])], width)


## The grants of one kind, a line each.
def grantKindLines(state, row, width):
    grants = [held["grant"] for held in state.rows.get(levelKey(state.path), ()) if held.get("grant") and held["grant"]["kind"] == row["grantKind"]]
    lines = ["%d %s grant%s:" % (len(grants), row["grantKind"], "" if len(grants) == 1 else "s")]
    for grant in grants:
        lines.extend(hangLines("%s %s, from %s" % (grant["access"], grant["place"] or grant["target"], grant["origin"] or "-"), width))
    return lines


## The summary of `Permissions`: how many grants, by kind, as the caption of the table of
## them, fitted to the pane (grantTableLines).
def grantsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    grants = [held["grant"] for held in rows if held.get("grant")]
    if not grants:
        return ["No grants."]
    tableCount(state, grants)
    return grantTableLines(grants, state.viewWidth - 1, state.wrap, fullPane(state))


## What `--manager-team-member-files` printed: a file a row, by its path in the member's
## skillset folder, its size at the end of its line; one that is no text is dimmed and not read.
def parseFileRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "file" and len(fields) >= 4:
            row = newRow(fields[1], fields[1], "file", False, fields)
            row["file"] = {"bytes": fields[2]}
            row["text"] = fields[3] == "yes"
            row["tail"] = shortBytes(fields[2])
            if not row["text"]:
                row["look"] = DIM
            rows.append(row)
    return rows


## The summary of `Skillset Files`: how many files and how much, then the files as a table
## (paneTable): each by its path in the folder, its size and whether it is text, as many as
## the pane shows, or every row while `e` shows them all.
def filesSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    files = [held for held in rows if held.get("file")]
    if not files:
        return ["No files."]
    return tableSummaryLines(state, ("NAME", "SIZE", "CONTENT"),
                             [[held["label"], shortBytes(held["file"]["bytes"]), "text" if held["text"] else "binary"] for held in files], ("key", "text", "enum"))


## ---- the team members: `Team Members` ----

## The status of a member that is started from here, as its row of the list gives it. Any
## other word there, whatever it is, says that nobody is started as that member.
MEMBER_STARTS = "active"
## What a status shows as in the column of the members' table, where the word is longer
## than the column should be. The left window shows the word whole.
MEMBER_STATUS_SHORT = {"reference-only": "ref-only"}


## Why a member is not started from here, in words, or nothing where it can be: one whose
## status is not the one of a member that is started, and one whose workspace cannot be reached.
def memberRefusal(member):
    if member["setUp"] == "not-present":
        return "its workspace cannot be reached from this machine"
    if member["status"] != MEMBER_STARTS:
        return "its status is %s: nobody is started as this member" % (member["status"] or "not given")
    return ""


## The columns of the members' table after the icon, named in the installer's manner, and
## what of a member stands in each. The name always shows. Those after it show in this
## order while the pane has room, so whether a member runs is the last of them to be lost.
## WHERE is the project its skillset lies in (projectPlace), from its own folder: the
## folder above its `skillset/`, or the folder itself where it lies in none.
MEMBER_COLUMNS = (
    ("MEMBER", lambda state, member: member["name"], "key"),
    ("RUN", lambda state, member: "running" if member["live"] == "running" else "", "enum"),
    ("STATUS", lambda state, member: MEMBER_STATUS_SHORT.get(member["status"], member["status"]), "enum"),
    ("KIND", lambda state, member: member["kind"], "enum"),
    ("WHERE", lambda state, member: projectPlace(state, member["folder"].rpartition("/skillset/")[0] or member["folder"] or "-",
                                                 placedShown(state)), "text"),
)


## The members as one table, like the member table of the installer, for the left pane, in
## lines of that many cells: under a header, each member's icon, its name, whether it runs
## now, its status, its kind and the project its skillset lies in, in columns as wide as
## their widest word, an absent one `-`. The icon is the one the operation gave, and no icon is named
## here. It is measured in cells as every text of the screen is, so a wide one, and one an
## emoji selector makes wide, take two; a member with none keeps that place empty.
def memberTableLines(state, members, width, wrap=True):
    head, blocks = paneTable([column[0] for column in MEMBER_COLUMNS], [[column[1](state, member) or "-" for column in MEMBER_COLUMNS] for member in members],
                             width, [member["icon"] for member in members], wrap, [column[2] for column in MEMBER_COLUMNS], numbered=True, pane=fullPane(state))
    return head + [line for block in blocks for line in block]


## The rows of the members as a list, as every list is: each member's icon ahead of its
## name, the icons in a place as wide as the widest of them, so that every name starts at
## the same cell; a member with none keeps that place empty.
def memberLeads(rows):
    iconWidth = max([textWidth(row["member"]["icon"]) for row in rows] + [0])
    for row in rows:
        row["lead"] = cutToCells(row["member"]["icon"], iconWidth) + " " if iconWidth else ""


## What `--manager-team-member-list` printed, as rows: `member` rows of TAB-separated
## fields, in the order they come, this workspace's own members first. The members show
## as a list, each by its icon and its name (memberLeads), and as a table in the left pane
## (memberTableLines). One with a live run stands out. One that is not started from
## here, whose status is `reference-only` or whose workspace is `not-present`, shows
## plainer: dimmed. The last two fields are the member's icon and its own folder: a row
## without them, as the operation printed a row before it gave them, is a member with no
## icon and no folder.
def parseMemberRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "member" or len(fields) < 11:
            continue
        member = {"name": fields[1], "mark": unspaced(fields[2]), "first": unspaced(fields[3]),
                  "family": unspaced(fields[4]), "alias": unspaced(fields[5]), "kind": absent(fields[6]),
                  "workspace": absent(fields[7]), "setUp": fields[8], "status": absent(fields[9]), "live": fields[10],
                  "icon": absent(fields[11]) if len(fields) > 11 else "", "folder": absent(fields[12]) if len(fields) > 12 else ""}
        ## a member is a folder of its own, but one whose workspace cannot be reached, whose
        ## nothing is read, and the row of the team itself, which is no member
        row = newRow(fields[1], fields[1], "record", member["setUp"] != "not-present" and member["kind"] != MEMBER_TEAM_KIND, fields)
        row["member"] = member
        if member["live"] == "running":
            row["look"] = BOLD
        if memberRefusal(member):
            row["look"] = DIM
        rows.append(row)
    memberLeads(rows)
    return rows


## What `--manager-team-member-read` printed of one member: its own `member` row, `info`
## rows, the `bullet` rows of its basic.md, each `session` row with the member's own `run`
## rows in it, `grant` rows and `setting` rows.
def parseMemberRead(text):
    info = {"name": "", "info": [], "bullets": [], "sessions": [], "grants": [], "settings": []}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "member" and len(fields) >= 11:
            info["name"] = fields[1]
        elif fields[0] == "info" and len(fields) >= 3:
            ## its description is prose; a path and a name stand as they are written
            info["info"].append((fields[1], unspaced(fields[2]) if fields[1] == "description" else absent(fields[2])))
        elif fields[0] == "bullet" and len(fields) >= 3:
            info["bullets"].append((unspaced(fields[1]), unspaced(fields[2])))
        elif fields[0] == "session" and len(fields) >= 8:
            info["sessions"].append({"id": fields[1], "name": unspaced(fields[2]), "state": fields[3], "started": fields[4],
                                     "stateAt": fields[5], "count": fields[6], "tally": fields[7], "runs": []})
        elif fields[0] == "run" and len(fields) >= 12 and info["sessions"]:
            info["sessions"][-1]["runs"].append({"session": fields[1], "spawn": fields[2], "member": fields[3],
                                                 "status": fields[4], "live": fields[5], "state": fields[6],
                                                 "started": fields[7], "resolved": fields[8], "host": fields[9],
                                                 "workspace": fields[10], "activity": fields[11]})
        elif fields[0] == "grant" and len(fields) >= 7:
            info["grants"].append({"kind": fields[1], "access": absent(fields[2]), "target": absent(fields[3]),
                                   "place": absent(fields[4]), "origin": absent(fields[5]).replace("_by_", " by "),
                                   "ends": unspaced(fields[6])})
        elif fields[0] == "setting" and len(fields) >= 5:
            info["settings"].append({"key": fields[1], "state": fields[2], "value": absent(fields[3]),
                                     "workspace": absent(fields[4])})
    return info


## One line of a list in the left pane, set in by two cells, as it is where it fits; where
## it is longer than the pane it is broken between its words and goes on under itself, set
## in further.
def hangLines(text, width):
    if textWidth(text) <= width - 3:
        return ["  " + text]
    parts = wrapToCells(text, max(10, width - 7))
    return ["  " + parts[0]] + ["      " + part for part in parts[1:]]


## What a setting reads as: its value where it is set and no secret, and for a secret only
## whether it is configured, never anything of its value. The mark of one that is missing.
MARK_MISSING = "!"


def settingWords(settingState, value):
    if settingState == "secret-set":
        return "configured"
    if settingState == "secret-missing":
        return "not configured"
    if settingState == "missing":
        return "missing" if not value else "%s (missing)" % value
    if settingState == "set":
        return value or "set"
    return settingState + (" " + value if value else "")


## The selected member for the left pane, its basic information alone. From its row of the
## list: its mark and names, its kind, its status, whether a run of it is alive, the
## workspace it is set up in, and whether `n` starts it, or why not. Once the read of that
## one member has come (info): what it is for, and its information, the bullets of its
## basic.md. Its sessions, its grants and its skillset are folders of its own (MEMBER_FOLDERS).
def memberLines(member, width, info=None):
    names = " ".join(word for word in (member["first"], member["family"]) if word)
    refusal = memberRefusal(member)
    where = {"here": "set up here", "elsewhere": "set up in another workspace of this machine",
             "not-present": "its workspace cannot be reached"}.get(member["setUp"], member["setUp"])
    facts = dict(info["info"]) if info else {}
    lines = [" ".join(word for word in (member["mark"], names or member["name"]) if word)
             + (", alias " + member["alias"] if member["alias"] else ""), ""]
    lines.extend(fieldLines([
        ("kind", member["kind"]),
        ("status", member["status"]),
        ("process", "a run of it is alive" if member["live"] == "running" else "no run of it is alive"),
        ("workspace", ", ".join(word for word in (member["workspace"], where) if word)),
        ("start", "not started from here: " + refusal if refusal else "n starts it with a prompt, in a session of its own"),
        ("for", facts.get("description", "")),
    ], width))
    if info is None:
        if member["setUp"] == "not-present":
            return lines + ["", "nothing more is read of it: its workspace cannot be reached from this machine"]
        return lines + ["", "Team-member information: not read yet"]
    if info["bullets"]:
        lines.extend(["", "Team-member information:"])
        for name, text in info["bullets"]:
            lines.extend(hangLines("%s: %s" % (name, text), width))
    return lines


## What `Team Members` holds, for the left pane while the section itself or the row that
## goes up is selected: the members as a table, numbered (memberTableLines), and nothing
## else. None until its read has answered.
def membersSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    members = [held["member"] for held in rows if held.get("member")]
    if not members:
        return ["No members."]
    tableCount(state, members)
    return memberTableLines(state, members, state.viewWidth - 1, state.wrap)


## Whether `n` starts the member of that row: one the operation would start.
def memberFits(state, row):
    return bool(row and row.get("member") and not memberRefusal(row["member"]))


## `n`: starts the selected team member with a prompt: the dialog of a prompt opens, its
## list on that member. On a row that is no member, and on a member that is not started,
## the key says its line in the status line and this is not reached.
def askStart(state, row):
    member = row.get("member") if row else None
    if member is None or memberRefusal(member):
        return ""
    return openPrompt(state, member["name"], "Start the member %s" % member["name"])


## What `--manager-spawn-member` printed: one `spawn` row, with the id of the new session,
## the member, the name of the session as its record keeps it, and the dispatch item the
## start made. Given back: the lines for the left pane, and one line for the bottom line.
def spawnAnswer(text, width):
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "spawn" and len(fields) >= 5:
            lines = fieldLines([
                ("session", fields[1]),
                ("member", fields[2]),
                ("name", unspaced(fields[3]) or "none: it shows by its id"),
                ("item", unspaced(fields[4])),
            ], width)
            return lines, "started: %s, session %s" % (fields[2], fields[1])
    return [], "the start answered no session id"


ACTION_HANDLERS["start"] = askStart
ACTION_FITS["start"] = memberFits
ACTION_REFUSALS["start"] = lambda state, row: "%s is not started: %s" % (row["member"]["name"], memberRefusal(row["member"])) if row and row.get("member") else ""

