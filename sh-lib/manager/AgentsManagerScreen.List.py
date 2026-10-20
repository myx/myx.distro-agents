##
## AgentsManagerScreen.List.py -- the list of the right window: its levels, its rows, its selection.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the list: its levels, its rows, its selection ----

def levelKey(path):
    return "/".join(path)


## The name of a level in READS and FIXED_ROWS: a step that is no section and no fixed row
## is the id of a record, and stands as `*`.
def levelPattern(path):
    words = []
    for word in path:
        if words:
            known = [fixed[0] for fixed in FIXED_ROWS.get("/".join(words), ())]
        else:
            known = [section[0] for section in SECTIONS]
        words.append(word if word in known else "*")
    return "/".join(words)


## The rows of a list that is set out in groups, the one drawing every such list has: for
## each group its heading row, which stands out, and under it the rows of the group, each
## set in by two cells. Given as pairs of a heading row and its rows, in their order.
def groupedRows(groups):
    rows = []
    for head, members in groups:
        head["look"] = BOLD
        rows.append(head)
        for row in members:
            row["indent"] = 2
            rows.append(row)
    return rows


def newRow(rowId, label, kind, dive=False, fields=None):
    return {"id": rowId, "label": label, "kind": kind, "dive": dive, "fields": fields or []}


## What a selection is kept by: the kind of the row and its id.
def rowKey(row):
    return row["kind"] + ":" + row["id"]


## The row with the number its level is counted by (COUNTED) where that is known: the list draws it after the label, `Pending Questions [2]`.
def countedRow(state, path, row):
    function = COUNTED.get(levelKey(list(path) + [row["id"]]))
    count = globals()[function](state) if function else None
    if count is not None:
        row["count"] = count
    return row


## What the list draws after the label of a row: the number its level is counted by, or nothing.
def countedText(row):
    return " [%d]" % row["count"] if "count" in row else ""


## The rows of a level: the root holds the sections; below it the first row goes up, then
## come the rows the level always holds, then the rows its operation gave.
def levelRowsAt(state, path):
    if not path:
        return [countedRow(state, path, newRow(sectionId, sectionLabel, "section", True)) for sectionId, sectionLabel in SECTIONS if sectionShown(state, sectionId)]
    rows = [newRow(ROW_UP, ROW_UP, "up")]
    for rowId, label, kind, dive in fixedRowsShown(state, path):
        rows.append(countedRow(state, path, newRow(rowId, label, kind, dive)))
    listed = listedRows(state, path) or ()
    if state.activeOnly and levelKey(path) in state.activeOf:
        ## the filter shows what the operation gave when it was last asked for the active
        ## ones, also of an answer read without it: which are active is the operation's to say
        listed = [row for row in listed if row["id"] in state.activeOf[levelKey(path)]]
    rows.extend(orderedRows(state, path, listed))
    return rows


def levelRows(state):
    return levelRowsAt(state, state.path)


## The rows of a level that the read of its operation gave, or that the function its plugin derives them with makes of what other reads
## hold (the "derived" of a plugin, DERIVED); not the rows it always holds. None until they were read.
def listedRows(state, path):
    derived = DERIVED.get(levelPattern(path))
    return globals()[derived](state, path) if derived else state.rows.get(levelKey(path))


## The rows a level always holds, but a root that stands only where what it shows is there and is not there now.
def fixedRowsShown(state, path):
    return [fixed for fixed in FIXED_ROWS.get(levelPattern(path), ()) if not pathHidden(state, list(path) + [fixed[0]])]


## The listed rows of a level in the order the user chose: by name where the level is one of ALPHABETICAL
## and the choice is on, else as the operation gave them.
def orderedRows(state, path, rows):
    if state.alphabetical and levelPattern(path) in ALPHABETICAL:
        return sorted(rows, key=lambda row: row["label"].lower())
    return rows


## THE SPACERS of the list. A spacer is one blank line between two groups of the rows of the
## level shown: drawn, and no row, so the selection, the number keys and every count of rows
## pass it by. At the root one stands between two groups of SECTION_GROUPS; inside a folder,
## as one rule, between the rows it always holds ahead of its listed ones (FIXED_ROWS, its
## commands) and the rows its operation gave (its children), so a folder with only one of
## the two has none. None is drawn above the first row shown. Gives the places among the
## rows that have a spacer above them: none where the console user turned the spacers off.
def spacersAt(state, rows):
    if os.environ.get(SPACERS_VARIABLE, "") == "disable":
        return frozenset()
    if not state.path:
        groupOf = dict((sectionId, number) for number, group in enumerate(SECTION_GROUPS) for sectionId in group)
        return frozenset(position for position in range(1, len(rows))
                         if groupOf.get(rows[position]["id"]) != groupOf.get(rows[position - 1]["id"]))
    fixed = len(fixedRowsShown(state, state.path))
    return frozenset((1 + fixed,)) if fixed and len(rows) > 1 + fixed else frozenset()


## How many lines the rows from one place to another take, both shown, the spacers between
## them with them.
def rowLinesBetween(spacers, first, last):
    return last - first + 1 + sum(1 for position in spacers if first < position <= last)


## The one place where what a list operation printed becomes rows, by level: the entry of
## the read names the form under "rows". "sessions": the sessions, each with its runs, kept
## where the lists of `Activity` are made from them (SESSIONS_OF). "pending": the asks. "routines": the routines to start by hand.
## "members": the team members. "digest": the subjects of the settings and of the
## configuration, and a level for each with its lines. "starts": what is started with the
## whole terminal. "blocks": the blocks of the dashboard. "places": the
## locations. No name: the stand-in below.
def parseLevels(readKey, form, text):
    if form == "sessions":
        return parseSessionLevels(text)
    level = readKey[len("list:"):]
    if form == "pending":
        return {level: parsePendingRows(text)}
    if form == "routines":
        return {level: parseRoutineRows(text)}
    if form == "members":
        return {level: parseMemberRows(text)}
    if form == "digest":
        return parseDigestLevels(readKey, text)
    if form == "starts":
        return {level: parseStartRows(text)}
    if form == "checks":
        return {level: parseCheckRows(text)}
    if form == "keys":
        return {level: parseKeyRows(text)}
    if form == "commands":
        return {level: parseCommandRows(text)}
    if form == "blocks":
        ## the blocks the root `Team Data` holds come with the same read (TEAM_DATA)
        rows = parseBlockRows(text)
        levels = {level: rows}
        if level != pluginLevel("teamdata"):
            levels[pluginLevel("teamdata")] = [dict(row) for row in rows if row["id"] in TEAM_DATA["blocks"]]
        return levels
    if form == "places":
        return {level: parsePlaceRows(text)}
    if form == "place-commands":
        return {level: parsePlaceCommandRows(text)}
    if form == "data-store":
        rows, store = parseStoreRows(text)
        return {level: rows, STORE_OF + level: store}
    if form == "data-items":
        return {level: parseItemRows(text)}
    if form == "member-grants":
        ## the rows of `Permissions` are made of the grants as they are drawn (memberGrantRows)
        return {GRANTS_OF + level: parseGrants(text)}
    if form == "session-grants":
        ## the grants that apply to a participant in its session, as the list of permissions prints them
        return {GRANTS_OF + level: parsePermissionList(text)}
    if form == "member-files":
        return {level: parseFileRows(text)}
    if form == "member-sessions":
        ## a session of the member opens in the tree of the member, as it is: its agents, then the folder of each
        return {level: parseSessionRows(text)}
    if form == "member-help":
        rows, whole = parseHelpRows(text)
        return {level: rows, WHOLE_OF + level: whole}
    if form == "chapters":
        ## the chapters of the help, rows of their own, kept for a member's `Member Help`
        text, chapters = parseHelpChapters(text)
        return {level: [], CHAPTERS_OF + level: chapters}
    if form == "manuals":
        return {level: parseManualRows(text)}
    return {level: parseRows(readKey, text)}


## The stand-in for a list whose task has not said what its operation prints. A line is a
## record and its fields stand between TABs: the first is taken as its id, and the fields
## are what is shown.
def parseRows(readKey, text):
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        rows.append(newRow(fields[0], "  ".join(fields), "record", False, fields))
    return rows


## The selection of the level shown, brought in line with its rows as they are now. It
## stays on the same item, found by its key; where that item is gone it takes the row at
## the same place. The rows in view follow it, in the lines they take with their spacers.
def cursorOf(state, rows, height):
    cursor = state.cursors.setdefault(levelKey(state.path), {"key": None, "index": 0, "top": 0})
    index = cursor["index"]
    for position, row in enumerate(rows):
        if rowKey(row) == cursor["key"]:
            index = position
            break
    index = max(0, min(index, len(rows) - 1))
    cursor["index"] = index
    cursor["key"] = rowKey(rows[index]) if rows else None
    top = cursor["top"]
    if index < top:
        top = index
    spacers = spacersAt(state, rows)
    if height > 0 and rowLinesBetween(spacers, top, index) > height:
        top = max(top, index - height + 1)
        while top < index and rowLinesBetween(spacers, top, index) > height:
            top += 1
    ## the first row shown is never lower than the one that fills the window to the last row
    fit = max(height, 1)
    least = max(0, len(rows) - fit)
    while least < len(rows) - 1 and rowLinesBetween(spacers, least, len(rows) - 1) > fit:
        least += 1
    cursor["top"] = max(0, min(top, least))
    return cursor


def selectedRow(state):
    rows = levelRows(state)
    if not rows:
        return None
    return rows[cursorOf(state, rows, 0)["index"]]


## The selection moves by rows, or by pages of the pane. It stops at the first and at the
## last row: it never wraps.
def moveSelection(state, height, step, pages=0):
    rows = levelRows(state)
    if not rows:
        return
    cursor = cursorOf(state, rows, height)
    index = max(0, min(cursor["index"] + step + pages * height, len(rows) - 1))
    cursor["index"] = index
    cursor["key"] = rowKey(rows[index])
    cursor["top"] = cursor["top"] + pages * height
    cursorOf(state, rows, height)


def diveIn(state, height):
    rows = levelRows(state)
    if not rows:
        return
    row = rows[cursorOf(state, rows, height)["index"]]
    if row["kind"] == "up":
        goUp(state)
    elif row["dive"]:
        state.path = state.path + [row["id"]]


## Up one level, onto the row that was dived into.
def goUp(state):
    if not state.path:
        return
    left = state.path[-1]
    state.path = state.path[:-1]
    cursor = state.cursors.setdefault(levelKey(state.path), {"key": None, "index": 0, "top": 0})
    for position, row in enumerate(levelRows(state)):
        if row["id"] == left and row["kind"] != "up":
            cursor["key"] = rowKey(row)
            cursor["index"] = position
            break


## ---- the plugin: the list ----

## What the list offers the others to put in (Plugins.py): `alphabetical`, the levels whose listed rows the user may have by name
## instead of in the order the operation gave them, by the key of the command "alphabetical" (orderedRows).
registerPlugin({"name": "list", "registries": {"alphabetical": "level", "unfiltered": "level"}})
