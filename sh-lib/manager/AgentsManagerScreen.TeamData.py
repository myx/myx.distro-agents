##
## AgentsManagerScreen.TeamData.py -- the root Team Data: its board, its audit and its vault, its figures and its cleanups.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the items of the team data: its board, its audit and its vault ----

## Where what a read of a store says of the store itself is kept, and the whole help of a
## member, beside the rows of their level: under the level, behind these words.
STORE_OF = "store:"
WHOLE_OF = "whole:"
## Where the chapters of the help are kept, by the level whose read gave them (parseHelpChapters).
CHAPTERS_OF = "chapters:"


## What `--manager-team-data-read <store>` printed: the rows of its folders, each a folder
## of its items with how many it holds, then the items in the store itself; and the store,
## whether it is there and how much it holds.
def parseStoreRows(text):
    rows = []
    store = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "store" and len(fields) >= 5:
            store = [{"state": fields[2], "folders": fields[3], "items": fields[4]}]
        elif fields[0] == "folder" and len(fields) >= 4:
            row = newRow(fields[2], fields[2], "folder", True, fields)
            row["tail"] = fields[3]
            row["folder"] = {"items": fields[3]}
            rows.append(row)
    return rows + parseItemRows(text), store


## The `item` rows of a read of the team data: each by its name, its size at the end of its line;
## and what the read gives of its front matter, its type, status, owner and date, where it does.
def parseItemRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "item" and len(fields) >= 6:
            row = newRow(fields[3], fields[3], "item", False, fields)
            row["item"] = {"name": fields[3], "bytes": fields[4], "stamp": fields[5]}
            row["item"].update((name, unspaced(value)) for name, value in zip(ITEM_FRONT, fields[6:10]))
            row["tail"] = shortBytes(fields[4])
            rows.append(row)
    return rows


## The summary of a store: whether it is there, its folders with how many items each holds,
## and how many items lie in it itself; plainly where it holds none.
def storeSummary(state, path, row, form):
    store = state.rows.get(STORE_OF + levelKey(path))
    rows = state.rows.get(levelKey(path))
    if not store or rows is None:
        return None
    store = store[0]
    if store["state"] != "present":
        return ["%s: there is none in this team data: it has no such folder." % row["label"]]
    folders = [held for held in rows if held["kind"] == "folder"]
    items = [held for held in rows if held["kind"] == "item"]
    if not folders and not items:
        return ["%s: empty. It holds no items." % row["label"]]
    return tableSummaryLines(state, ("FOLDER", "ITEMS"), [[held["label"], held["folder"]["items"]] for held in folders]
                             + [[held["label"], "-"] for held in items], ("key", "text"))


## What the read of a folder gives of each item's front matter, in its order after the stamp.
ITEM_FRONT = ("type", "status", "owner", "date")
## The columns of the table of a folder's items: its name, what its front matter gives, its
## date, or the stamp of its name where it gives none, and its size. A column no item of the
## table has a word for is left out; the others show in this order while the pane has room.
ITEM_COLUMNS = (
    ("NAME", lambda item: item["name"], "key"),
    ("TYPE", lambda item: item.get("type", ""), "enum"),
    ("DATE", lambda item: item.get("date", "")[:16] or stampText(item["stamp"]), "text"),
    ("OWNER", lambda item: item.get("owner", ""), "text"),
    ("STATUS", lambda item: item.get("status", ""), "enum"),
    ("SIZE", lambda item: shortBytes(item["bytes"]), "text"),
)
## The columns of the folders of a store where they are not those: the Board's leave the
## type out, which its names say (the owner: "Remove TASK column"), and the size, which its
## rows in the list show; its date is the front matter's alone, the stamp being its name's.
STORE_ITEM_COLUMNS = {"board": tuple(("DATE", lambda item: item.get("date", "")[:16], "text") if column[0] == "DATE" else column
                                     for column in ITEM_COLUMNS if column[0] not in ("TYPE", "SIZE"))}


## The stamp of an item's name, `<YYYYMMDD>T<HHMM>`, as a date: `2026-10-01 09:00`.
def stampText(stamp):
    if len(stamp) != 13 or not (stamp[:8] + stamp[9:]).isdigit():
        return ""
    return "%s-%s-%s %s:%s" % (stamp[:4], stamp[4:6], stamp[6:8], stamp[9:11], stamp[11:])


## The summary of a folder of a store: its items as a table (tableSummaryLines), the newest
## first where their names are dated, every one of them. The columns are the store's own
## where it has its own (STORE_ITEM_COLUMNS).
def itemsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    items = [held for held in rows if held.get("item")]
    if not items:
        return ["%s: empty. It holds no items." % row["label"]]
    columns = [column for column in STORE_ITEM_COLUMNS.get(form.get("store"), ITEM_COLUMNS) if any(column[1](held["item"]) for held in items)]
    return tableSummaryLines(state, [column[0] for column in columns], [[column[1](held["item"]) or "-" for column in columns] for held in items],
                             [column[2] for column in columns])


## ---- the team data: `Team Data`, its cleanup, and the big output dialog ----

## Whether a root stands in the list now (SECTIONS_WHEN).
def sectionShown(state, sectionId):
    when = SECTIONS_WHEN.get(sectionId)
    return when is None or bool(globals()[when["shown"]](state))


## Which roots stand in the list now, for the number keys (SECTIONS_NOW, goKeys): at every turn.
def noteRoots(state):
    SECTIONS_NOW[:] = [sectionId for sectionId, sectionLabel in SECTIONS if sectionShown(state, sectionId)]


## The figures of a block of `Team Data` by their keys, as the dashboard last gave them.
def teamDataFigures(state, blockId):
    for row in state.rows.get(TEAM_DATA["level"], ()):
        if row["id"] == blockId and row.get("block"):
            return [(figure["key"], figure) for figure in row["block"]["figures"]]
    return None


## Team data is configured for this workspace: its root is set and is there, as the read
## of the dashboard says.
def teamDataHere(state):
    blockId, figureKey, value = TEAM_DATA["present"]
    return any(key == figureKey and figure["value"] == value for key, figure in teamDataFigures(state, blockId) or ())


## A line of the digest of the settings, as it was last read: by its subject, its group
## (None: any) and its key. None where it was not read, or holds no such line.
def digestLineOf(state, subject, group, key):
    for root in ("configuration", "settings"):
        for row in state.rows.get(root + "/" + subject, ()):
            line = row.get("line")
            if line and line["key"] == key and group in (None, line["group"]):
                return line
    return None


## The mode of the workspace, as what it shows as and where it comes from; None where the
## digest was not read.
def modeShown(state):
    line = digestLineOf(state, *TEAM_DATA["mode"])
    if line is None:
        return None
    label = dict(line["choices"]).get(line["value"]) or line["value"]
    return label, SOURCE_WORDS.get(line["source"], line["source"])


## A figure for the eye: its value short by its unit, and the level of a figure that has
## one beyond the first, in words.
def figureShown(figure):
    order = [name for name, level in DASHBOARD["levels"]]
    worse = figure["level"] in order and order.index(figure["level"]) > 0
    return figureValue(figure) + ("  (%s)" % figure["level"] if worse else "")


## The look of a figure by its level, as the dashboard draws it, or None where it has none.
def figureLook(figure):
    return dict(DASHBOARD["levels"]).get(figure["level"], {}).get("look")


## The summary of `Team Data`: as its caption whether it is there and its size; as facts
## where its root is, the mode of the workspace and whether it is a full team rig, the
## remote of the team data and its branch; its other figures, the items of its stores, as
## a table, each in the look of its level; its git state (gitLines); its board, the items
## by state, as a table; and the main
## loop, where the workspace has one, figure by figure as a table, in the looks of their
## levels on a full team rig, plain elsewhere, where they are not judged. From the blocks
## the dashboard gave and the digest of the settings, each where it was read.
def teamDataSummary(state, path, row, form):
    data = teamDataFigures(state, TEAM_DATA["data"])
    if data is None:
        return None
    figures = dict(data)
    root = figures.get(TEAM_DATA["root"])
    size = [figureValue(figure) for key, figure in data if figure["unit"] == "bytes"]
    lines = [looked("Team data: %s%s." % ("there" if teamDataHere(state) else "not there", ", " + size[0] if size else ""), BOLD)]
    mode = modeShown(state)
    full = digestLineOf(state, *TEAM_DATA["full"])
    full = full is not None and full["state"] == "set"
    remote = digestLineOf(state, *TEAM_DATA["remote"])
    branch = digestLineOf(state, *TEAM_DATA["branch"])
    ## the root by the rule of the locations where the view takes it, so it is broken to the pane as it shows
    pairs = [("root", (placedLine(state, root["value"])[0] if placedShown(state) else root["value"]) if root else "none is configured",
              None if root else LEVEL_WARN)]
    if mode is None:
        pairs.append(("mode", "being read", DIM))
    else:
        pairs.extend([
            ("mode", "%s, %s%s" % (mode[0], mode[1], "; a full team rig" if full else "")),
            ("remote", remote["value"] if remote and remote["state"] == "set" else "none: no shared persistence is set"),
            ("branch", branch["value"] if branch and branch["state"] == "set" else "not set: the tooling's own")])
    lines.extend(factLines(pairs, state.viewWidth))
    other = [figure for key, figure in data if key not in (TEAM_DATA["root"], TEAM_DATA["present"][1])
             and figure["unit"] != "bytes" and not key.startswith(TEAM_DATA["board"])]
    if other:
        head, blocks = paneTable(("FIGURE", "VALUE"), [[unspaced(figure["label"]), figureShown(figure)] for figure in other],
                                 max(10, state.viewWidth - 1), wrap=state.wrap, indent="  ", looks=[[None, figureLook(figure)] for figure in other])
        lines.extend(headingLines("Items") + head + [line for block in blocks for line in block])
    git = teamDataFigures(state, TEAM_DATA["git"])
    if git:
        lines.extend(headingLines("Git") + gitLines(dict(git), state.viewWidth))
    board = [(key[len(TEAM_DATA["board"]):], figure) for key, figure in data if key.startswith(TEAM_DATA["board"])]
    if board:
        lines.extend(headingLines("Board") + summaryTable(("STATE", "ITEMS"), [[name, figureValue(figure)] for name, figure in board], state.viewWidth))
    loop = teamDataFigures(state, TEAM_DATA["loop"])
    if loop:
        lines.extend(headingLines("Main loop and heartbeat" + ("" if full else " (not judged here: a full team rig alone is)")))
        head, blocks = paneTable(("FIGURE", "VALUE"), [[unspaced(figure["label"]), figureShown(figure)] for key, figure in loop],
                                 max(10, state.viewWidth - 1), wrap=state.wrap, indent="  ",
                                 looks=[[None, figureLook(figure) if full else None] for key, figure in loop])
        lines.extend(head + [line for block in blocks for line in block])
    else:
        lines.extend(["", looked("No main loop here: a workspace has one in the mode %s alone." % TEAM_DATA["teamRig"], DIM)])
    return lines


## The git state of the team data, as its block gives it (figures by their keys), as facts
## for the summary: its branch and what it tracks, ahead and behind as of its last fetch,
## what is not committed, each in the look of its level, and its last commit.
def gitLines(git, width):
    def value(key):
        return unspaced(git[key]["value"]) if key in git else ""
    if value("repository") != "yes":
        return factLines([("repository", "none: the team data is no repository")], width)
    return factLines([
        ("branch", "%s, %s" % (value("branch") or "no branch", ("tracking " + value("upstream")) if value("upstream") else "tracking nothing")),
        ("ahead", value("ahead"), figureLook(git["ahead"]) if "ahead" in git else None),
        ("behind", value("behind"), figureLook(git["behind"]) if "behind" in git else None),
        ("uncommitted", value("uncommitted"), figureLook(git["uncommitted"]) if "uncommitted" in git else None),
        ("last commit", "%s ago%s" % (figureValue(git["last-commit"]), (": " + value("last-subject")) if value("last-subject") else "") if "last-commit" in git else ""),
    ], width)


## The operation a row of `Operations` is, or None.
def cleanupOf(row):
    return dict(CLEANUPS).get(row["id"]) if row is not None and row["kind"] == "operation" else None


## Why a cleanup is not offered here, or nothing: one that needs a rig, in any mode of
## the workspace but a team rig, by the label of that mode; and while the mode is read.
def cleanupRefusal(state, row):
    cleanup = cleanupOf(row)
    if cleanup is not None and cleanup["needs"] == "remote":
        remote = digestLineOf(state, *TEAM_DATA["remote"])
        if digestLineOf(state, *TEAM_DATA["mode"]) is None:
            return "whether a git remote of the team data is set is still being read"
        return "" if remote is not None and remote["state"] == "set" else "no git remote of the team data is set"
    if cleanup is None or cleanup["needs"] != "rig":
        return ""
    line = digestLineOf(state, *TEAM_DATA["mode"])
    if line is None:
        return "whether this workspace is a team rig is still being read"
    if line["value"] != TEAM_DATA["teamRig"]:
        return "for a team rig alone: this workspace is %s" % modeShown(state)[0]
    return ""


## What the left window shows of a cleanup: what it does, the operation it runs, what it
## needs, and whether it is offered here, in the look of what is well or what to look at.
def cleanupLines(state, row):
    cleanup = cleanupOf(row)
    refusal = cleanupRefusal(state, row)
    lines = wrapToCells(cleanup["does"], max(10, state.viewWidth - 1)) + [""]
    lines.extend(factLines([("runs", commandText(cleanup["operation"])),
                            ("needs", {"rig": "a team rig", "remote": "a git remote of the team data"}.get(cleanup["needs"], "nothing more")),
                            ("here", ("not offered: " + refusal) if refusal else "offered", LEVEL_WARN if refusal else LEVEL_OK)], state.viewWidth))
    return lines


## The summary of `Operations`: how many there are and how many run here as its caption,
## then each as a row of a table: whether it runs here, in its look, and why not.
def cleanupsSummary(state, path, row, form):
    rows = [newRow(cleanupId, cleanup["label"], "operation") for cleanupId, cleanup in CLEANUPS]
    refusals = [cleanupRefusal(state, held) for held in rows]
    tableCount(state, rows)
    head, blocks = paneTable(("OPERATION", "HERE", "WHY NOT"), [
        [held["label"], "not here" if refusal else "runs here", refusal or "-"] for held, refusal in zip(rows, refusals)],
        max(10, state.viewWidth - 1), wrap=state.wrap, kinds=("key", "enum", "text"), indent="  ",
        looks=[[None, LEVEL_WARN if refusal else LEVEL_OK, None] for refusal in refusals])
    return head + [line for block in blocks for line in block]


def askCleanup(state, row):
    cleanup = cleanupOf(row)
    if cleanup is None:
        return ""
    openDialog(state, "cleanup", {"about": {"lines": [
        ("runs", row["label"]), ("operation", commandText(cleanup["operation"])), cleanup["does"],
        "It runs at once and unattended, in a window that follows what it writes. Run starts it; Cancel and Esc do nothing."]}},
        about={"id": row["id"], "label": row["label"]}, title="Run: %s" % row["label"])
    return ""


ACTION_HANDLERS["cleanup"] = askCleanup
ACTION_FITS["cleanup"] = lambda state, row: cleanupOf(row) is not None and not cleanupRefusal(state, row)
ACTION_REFUSALS["cleanup"] = cleanupRefusal


def submitCleanup(state, dialog, button):
    closeDialog(state)
    runFollowed(state, dialog["about"]["label"], dict(CLEANUPS)[dialog["about"]["id"]]["operation"])
    return None


DIALOG_HANDLERS["cleanup"] = submitCleanup

