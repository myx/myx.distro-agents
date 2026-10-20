##
## AgentsManagerScreen.Places.py -- the root Locations (Places): the places, their commands, and a path by the name of its location.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the commands of a workspace in `Locations (Places)` ----

## How a command of a workspace runs, as its declaration says, in words: in the facts of the
## left pane, and in the dialog that asks first.
PLACE_COMMAND_RUNS = {
    "output": ("unattended, in a window that follows what it writes",
               "It runs at once and unattended, in that workspace, in a window that follows what it writes. Run starts it; Cancel and Esc do nothing."),
    "terminal": ("with the whole terminal, as a console",
                 "It runs in that workspace with the whole terminal, as a console; the screen comes back when it ends. Run starts it; Cancel and Esc do nothing."),
}


## What `--manager-place-command-list` printed, as rows, in the order they come: `command`
## rows of TAB-separated fields, the name, its whitespace `_`, the package that declares it
## and how it runs. Each is an item that opens a dialog, by its name, its emoji part of it.
def parsePlaceCommandRows(text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] != "command" or len(fields) < 4:
            continue
        command = {"name": fields[1], "label": unspaced(fields[1]), "package": fields[2], "runs": fields[3]}
        row = newRow(fields[1], command["label"], "place-command", False, fields)
        row["placeCommand"] = command
        rows.append(row)
    return rows


## The selected command of a workspace, for the left pane: its name as its head, the package
## that declares it, and how it runs.
def placeCommandLines(command, width):
    return [looked(command["label"], BOLD)] + factLines([
        ("package", command["package"]),
        ("runs", PLACE_COMMAND_RUNS.get(command["runs"], (command["runs"],))[0]),
    ], width)


## Enter on a command of a workspace: asked first, by what will run, in which workspace and
## how; the screen writes no command of its own: the tooling runs the declared one.
def askPlaceCommand(state, row):
    command = row.get("placeCommand") if row else None
    if command is None:
        return ""
    openDialog(state, "placecommand", {"about": {"lines": [
        ("runs", command["label"]), ("workspace", state.path[-1]), ("package", command["package"]),
        PLACE_COMMAND_RUNS.get(command["runs"], ("", ""))[1]]}},
        about={"id": row["id"], "label": command["label"], "place": state.path[-1], "runs": command["runs"]},
        title="Run: %s" % command["label"])
    return ""


ACTION_HANDLERS["placecommand"] = askPlaceCommand
ACTION_FITS["placecommand"] = lambda state, row: bool(row and row.get("placeCommand"))


## Run: one that runs with the whole terminal is started so at the end of this turn of the
## screen (runChild), by the dispatcher, from this workspace; any other in the big output dialog.
def submitPlaceCommand(state, dialog, button):
    closeDialog(state)
    about = dialog["about"]
    words = ["--manager-place-command-run", about["place"], about["id"]]
    if about["runs"] == "terminal":
        state.answer = None
        state.child = {"label": about["label"], "said": "command", "words": words, "directory": state.workspace or None, "tools": True}
        return None
    runFollowed(state, about["label"], words)
    return None


DIALOG_HANDLERS["placecommand"] = submitPlaceCommand

## ---- the locations: `Locations (Places)`, and a path by the name of its location ----

## The columns of the table of the locations after the mark of the one the console runs
## in, and what of a location stands in each. Its key always shows; those after it show
## in this order while the pane has room.
PLACE_COLUMNS = (
    ("PLACE", lambda place: place["key"]),
    ("KIND", lambda place: place["kind"]),
    ("CEILING", lambda place: absent(place["ceiling"])),
    ("STATE", lambda place: place["state"]),
    ("SESSIONS", lambda place: absent(place["sessions"])),
)


## The rows of the locations as one table, in the manner of the members' table and by its
## rule, drawn by listTableLines: under a header, the mark of the location the console runs
## in, in the place an icon has there, then the key of each and a word for each column, an
## absent one `-`.
def placeTable(rows):
    places = [row["place"] for row in rows]
    words = [[column[1](place) or "-" for column in PLACE_COLUMNS] for place in places]
    marks = [MARKS["on"] if place["here"] == PLACES["here"] else "" for place in places]
    table = {"heads": [column[0] for column in PLACE_COLUMNS], "kinds": None, "cut": TABLE_CAP}
    for row, mark, line in zip(rows, marks, words):
        row["table"] = table
        row["cells"] = [mark] + line


## What `--manager-place-list` printed, as rows: `place` rows of TAB-separated fields, in
## the order they come. They show as a table (placeTable), each by its key, which is what
## its read is asked by. The one the console runs in stands out; one that is not present
## shows plainer. A workspace that is there is a folder: its commands (parsePlaceCommandRows).
## A line of another name, and one too short, is left out.
def parsePlaceRows(text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] != "place" or len(fields) <= len(PLACES["fields"]):
            continue
        place = dict(zip(PLACES["fields"], fields[1:]))
        row = newRow(place["key"], place["key"], "record", place["kind"] == PLACES["workspace"] and place["state"] == PLACES["present"], fields)
        row["place"] = place
        if place["here"] == PLACES["here"]:
            row["look"] = BOLD
        if place["state"] != PLACES["present"]:
            row["look"] = DIM
        rows.append(row)
    placeTable(rows)
    return rows


## What `--manager-place-read` printed of one location, after its own row: `info` rows, a
## name and its value, `stands` rows, what stands in it, each with its name and its path,
## and, of a workspace, `member` rows, the members that belong to it (PLACES). A read of
## before prints no `member` row.
def parsePlaceRead(text):
    info = {"info": [], "stands": [], "members": []}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "info" and len(fields) >= 3:
            info["info"].append((fields[1], absent(fields[2])))
        elif fields[0] == "stands" and len(fields) >= 4:
            info["stands"].append((fields[1], absent(fields[2]), fields[3]))
        elif fields[0] == "member" and len(fields) > len(PLACES["member"]):
            info["members"].append(dict(zip(PLACES["member"], fields[1:])))
    return info


## A path as it stands under a folder: what follows that folder in it, `.` for the folder
## itself, or None where it does not lie under it.
def pathUnder(path, folder):
    folder = folder.rstrip("/")
    if not folder or folder == "-":
        return None
    if path.rstrip("/") == folder:
        return "."
    return path[len(folder) + 1:] if path.startswith(folder + "/") else None


## The selected location for the left pane, from its row: its label and its key as its
## head, with the mark of the one the console runs in; as facts its kind, its path as it
## is, its state in its colour, its ceiling, and how many sessions name it. Once the read
## of that one location has come (info): what declares it; what stands in it, as a table
## of what, its name and where, the path of each as it stands under the path of the
## location, which is said once, at the top, and a thing that does not lie under it by the
## rule of the locations where it lies in another one (placedLine), and else as it is; and the members that belong to it, as one table, those whose folder
## lies in the location first: the icon and the name of each, its kind, how it is set up,
## in the colour of what to look at for one that no registry names, and its folder, under
## the location's path where it lies there, by the rule of the locations where it lies in
## another one (placedLine), and else as it is. Each table is one of the left pane
## (paneTable). This is the summary of a location: no other path in it is shown by a
## location's name.
def placeLines(state, place, width, info=None):
    label = unspaced(place["label"]) or place["key"]
    lines = [looked(" ".join(word for word in (MARKS["on"] if place["here"] == PLACES["here"] else "", label,
                                                "(%s)" % place["key"] if label != place["key"] else "") if word), BOLD)]
    lines.extend(factLines([
        ("kind", place["kind"]),
        ("path", absent(place["path"])),
        ("state", place["state"], stateLook(place["state"]) or LEVEL_WARN),
        ("ceiling", absent(place["ceiling"])),
        ("sessions", "%s name it" % place["sessions"] if absent(place["sessions"]) else ""),
    ] + (list(info["info"]) if isinstance(info, dict) and "info" in info else []), width))
    if not isinstance(info, dict) or "stands" not in info:
        return lines
    if info["stands"]:
        head, blocks = paneTable(("WHAT", "NAME", "WHERE"), [
            [what, name or "-", pathUnder(path, place["path"]) or placedLine(state, path)[0]] for what, name, path in sorted(
                info["stands"], key=lambda stands: pathUnder(stands[2], place["path"]) is None)],
            max(10, width - 1), wrap=state.wrap, kinds=("enum", "text", "key"), indent="  ")
        lines.extend(headingLines("What stands in it") + head + [line for block in blocks for line in block])
    members = sorted(info.get("members") or [], key=lambda member: pathUnder(member["folder"], place["path"]) is None)
    if members:
        icons = dict((row["member"]["name"], row["member"]["icon"]) for row in pluginRows(state, "team") if row.get("member"))
        head, blocks = paneTable(("MEMBER", "KIND", "SETUP", "FOLDER"), [
            [member["name"], member["kind"] or "-", member["setup"] or "-", pathUnder(member["folder"], place["path"]) or placedLine(state, member["folder"])[0]]
            for member in members], max(10, width - 1), [icons.get(member["name"], "") for member in members], state.wrap,
            ("key", "enum", "enum", "text"), "  ", looks=[[None, None, stateLook(member["setup"]), None] for member in members])
        lines.extend(headingLines("Its members") + head + [line for block in blocks for line in block])
    return lines


## What `Locations (Places)` holds, for the left pane while the section itself or the row
## that goes up is selected: as its caption how many there are, kind by kind as the
## operation names the kinds, which one the console runs in, and how many are not present;
## then every location of the list, in its order, as a table (tableSummaryLines): the mark
## of the one the console runs in, its key, kind, its state in its colour, its path, how
## many sessions name it, and its ceiling. None until its read has answered.
def placesSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    places = [held["place"] for held in rows if held.get("place")]
    if not places:
        return [looked("No location is known here: the operation listed none.", BOLD)]
    return tableSummaryLines(state, ("PLACE", "KIND", "STATE", "PATH", "SESSIONS", "CEILING"),
                             [[place["key"], place["kind"] or "-", place["state"] or "-", absent(place["path"]) or "-",
                               absent(place["sessions"]) or "-", absent(place["ceiling"]) or "-"] for place in places],
                             ("key", "enum", "enum", "key", "text", "enum"),
                             icons=[MARKS["on"] if place["here"] == PLACES["here"] else "" for place in places],
                             looks=[[None, None, stateLook(place["state"]) or LEVEL_WARN, None, None, None] for place in places])


## The locations that have a path, for the rule of the locations: the key of each by its
## path, and the pattern that finds the path of one in a text, the longest first, where
## it is a path of its own there: nothing of a longer name stands ahead of it or after
## it. Taken from the rows of the locations when those have changed. Where two share a
## path the first in the list has it.
def placesKnown(state):
    rows = state.rows.get(pluginLevel("places"))
    if state.placed is None or state.placed[0] is not rows:
        paths = {}
        for row in rows or ():
            path = row["place"]["path"].rstrip("/") if row.get("place") else ""
            if path.startswith("/") and len(path) > 1:
                paths.setdefault(path, row["place"]["key"])
        pattern = None
        if paths:
            pattern = re.compile("(?<![\\w./~+@-])(?:%s)(?=/|$|[^\\w.~+@-])" % "|".join(
                re.escape(path) for path in sorted(paths, key=len, reverse=True)))
        state.placed = (rows, paths, pattern)
    return state.placed[1], state.placed[2]


## A text by the rule of the locations: each path in it that lies in a location stands as
## the key of that location, a colon and what follows it there, and the location itself as
## its key alone. Gives the text, and where each key stands in it: the cell it starts at,
## how many cells it takes, and the look of a folder.
def placedLine(state, text):
    paths, pattern = placesKnown(state)
    if pattern is None or "/" not in text:
        return text, []
    parts = []
    spans = []
    at = 0
    width = 0
    for match in pattern.finditer(text):
        key = paths[match.group(0)]
        width += textWidth(text[at:match.start()])
        spans.append((width, textWidth(key), FOLDER))
        width += textWidth(key)
        parts.append(text[at:match.start()] + key)
        at = match.end()
        if text[at:at + 1] == "/":
            ## what follows the location's path in it stands after a colon, in the place of its slash
            parts.append(":")
            width += 1
            at += 1
    return ("".join(parts) + text[at:], spans) if spans else (text, [])


## Whether what the left window shows now takes the rule of the locations: not a view of
## real paths (PLACED), and not the raw mode of a log.
@onShownLevel
def placedShown(state):
    row = selectedRow(state)
    if row is None or (logShown(state, row) and rawShown(state)) or (markdownShown(state, row) and textRawShown(state)):
        return False
    root, below = pluginAt(state.path if state.path else [row["id"]] if row["kind"] == "section" else [])
    if root in PLACED["real"]:
        under = PLACED["real"][root]
        if under is None or any(word in under for word in below + [row["id"]]):
            return False
    return True


## The paragraphs of a text of a dialog by the rule of the locations: a paragraph that
## holds a path inside a location shows that path by the key of the location, and each
## such path stands under it as it is, whole, as a line of its own.
def placedParagraphs(state, paragraphs):
    paths, pattern = placesKnown(state)
    if pattern is None:
        return list(paragraphs)
    shown = []
    for paragraph in paragraphs:
        paired = isinstance(paragraph, tuple)
        text = paragraph[1] if paired else paragraph
        real = []
        for match in pattern.finditer(text):
            end = match.end()
            while end < len(text) and not text[end].isspace():
                end += 1
            path = text[match.start():end].rstrip(".,;:!?)]}'\"")
            if path not in real:
                real.append(path)
        if not real:
            shown.append(paragraph)
            continue
        placed = placedLine(state, text)[0]
        shown.append((paragraph[0], placed) if paired else placed)
        shown.extend(("", path) if paired else "  " + path for path in real)
    return shown


## What the left pane shows of the location selected, and of a command of a workspace.
def placesFocus(state, row):
    return placeLines(state, row["place"], state.viewWidth, state.view["info"]) if row.get("place") else None


def placeCommandsFocus(state, row):
    return placeCommandLines(row["placeCommand"], state.viewWidth) if row.get("placeCommand") else None


## ---- the plugin: `Locations (Places)` ----

registerPlugin({
    "name": "places",
    "root": {"id": "places", "label": "Locations (Places)", "go": "Loc~a~tions (Places)", "group": "places"},
    "focus": {"places": "placesFocus", "places/*": "placeCommandsFocus"},
    "summaries": {
        "places": {"lines": "placesSummary"},
    },
    "reads": {
        ## The locations the tooling knows by a name, one row each. Read whatever is shown, as a
        ## kind of its own, since a path inside one of them stands by its name in the other
        ## views (PLACED): once when the screen starts; again, on the period and when a read is
        ## asked for, only while `Locations (Places)` is the list shown.
        "list:places": {"operation": ["--manager-place-list"], "rows": "places", "kind": "places", "always": True, "seldom": True},
        ## One location, whole: its row, what declares it, and what stands in it.
        "view:places:record": {"operation": ["--manager-place-read", "{id}"], "rows": "place-read", "needs": "place"},
        ## The commands of a workspace among them, those its editor's palette gets, as the declarations of this
        ## console's packages give them. Read on entering it and when it is asked for, not on the period.
        "list:places/*": {"operation": ["--manager-place-command-list", "{level}"], "rows": "place-commands", "once": True},
    },
    "commands": (
        {"name": "placecommand", "keys": ("ENTER",), "menu": ("view", 3), "label": "R~u~n the command", "status": "Run",
         "views": ("places/*",), "for": "a command of a workspace", "on": ("places/*:place-command",), "only": True, "enters": True, "says": "run", "does": ("action", "placecommand")},
    ),
})
