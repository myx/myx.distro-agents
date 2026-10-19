##
## AgentsManagerScreen.Consoles.py -- the root Consoles: what is started with the whole terminal.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- what is started with the whole terminal: `Consoles` ----

## What `--manager-console-list` printed, as rows, in the order they come, which is the
## order of a menu: group after group. A row of a sort STARTS names: its fields by their
## names there, then, exact as they are printed, the folder it is started in and its
## command, a field a word; a line that is none of them, and one too short to hold a
## command, is left out. A row shows by its label, with its group at the end of its line.
def parseStartRows(text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        form = STARTS.get(fields[0])
        if form is None or len(fields) < len(form["fields"]) + 3:
            continue
        start = dict(zip(form["fields"], fields[1:]))
        start.update(sort=fields[0], directory=fields[len(form["fields"]) + 1], words=fields[len(form["fields"]) + 2:])
        row = newRow(start["key"], unspaced(start["label"]) or start["key"], "record", False, fields)
        row["start"] = start
        row["tail"] = unspaced(start["group"])
        rows.append(row)
    return rows


## A command for the eye, word by word: a word that holds a blank, or anything a shell
## would read as more than a word, stands between quotes, so where each word ends shows.
## Only what is shown: a command is started from its words as they are, with no shell.
def commandText(words):
    return " ".join(shlex.quote(word) for word in words)


## The selected thing to start for the left pane, from its row: its label as its head, then
## as facts its key and its group, the folder it is started in, its command as it will be
## run, and whether it needs a terminal.
def startLines(start, width):
    form = STARTS[start["sort"]]
    return [looked(unspaced(start["label"]) or start["key"], BOLD)] + factLines([
        ("key", start["key"]),
        ("group", unspaced(start["group"])),
        ("directory", start["directory"]),
        ("command", commandText(start["words"])),
        ("terminal", "yes, on its input and its output" if start["terminal"] == form["terminal"] else "no"),
    ], width)


## What `Consoles` holds, for the left pane while the section itself or the row
## that goes up is selected: how many there are to start, group by group in the order of
## the operation, as its caption; then every one of them, in that order, as a table
## (tableSummaryLines): its label, its group and its command. None until its read has answered.
def startsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    starts = [held for held in rows if held.get("start")]
    if not starts:
        return [looked("Nothing to start here: the operation listed none.", BOLD)]
    return tableSummaryLines(state, ("CONSOLE", "GROUP", "COMMAND"), [
        [held["label"], held["tail"] or "-", commandText(held["start"]["words"])] for held in starts], ("key", "enum", "text"))


## Enter on a row of `Consoles`: what the row names is started with the whole
## terminal at the end of this turn of the screen (runChild), from its words as the
## operation printed them and in its folder.
def askRun(state, row):
    start = row.get("start") if row else None
    if start is None:
        return ""
    state.answer = None
    state.child = {"label": row["label"], "said": STARTS[start["sort"]]["said"],
                   "words": list(start["words"]), "directory": start["directory"]}
    return ""


ACTION_HANDLERS["run"] = askRun
ACTION_FITS["run"] = lambda state, row: bool(row and row.get("start"))


## How a child ended, for the status line, by its status as the system gives it: the
## status it ended with, or, below 0, the signal that ended it, by its number and its name.
def childSays(child, status):
    if status < 0:
        try:
            name = " (%s)" % signal.Signals(-status).name
        except ValueError:
            name = ""
        return "%s: ended by signal %d%s" % (child["label"], -status, name)
    return "%s: ended with status %d" % (child["label"], status)


## What was asked to be started with the whole terminal is started, and the screen waits
## for its end: the surface gives the terminal away and takes it back, however the child
## ended (its `child`). Then the status line says how it ended, and what is shown is read
## again, since it may be old by now. One that cannot be started says why in a box, whole.
def runChild(surface, state):
    child, state.child = state.child, None
    try:
        status = surface.child(child["words"], child["directory"])
    except OSError as failure:
        tell(state, "It did not start", [(child["said"], child["label"]), ("directory", child["directory"]),
                                         ("command", commandText(child["words"])), str(failure)])
        return
    state.noticeOf = None
    state.notice = childSays(child, status)
    readNow(state)


## ---- the plugin: `Consoles` ----

registerPlugin({
    "name": "consoles",
    "root": {"id": "consoles", "label": "Consoles", "go": "Co~n~soles", "group": "places"},
    "summaries": {
        "consoles": {"lines": "startsSummary"},
    },
    "reads": {
        ## What is started from here with the whole terminal, in the order of a menu: the consoles
        ## of the workspace, each with the folder it starts in and its command, a field a word (STARTS).
        "list:consoles": {"operation": ["--manager-console-list"], "rows": "starts"},
    },
    "commands": (
        {"name": "run", "keys": ("ENTER",), "menu": ("console", 1), "label": "~S~tart", "status": "Start", "window": "list",
         "views": ("consoles",), "for": "something to start", "on": ("consoles:record",), "only": True, "says": "start", "does": ("action", "run")},
    ),
})


## ---- what a key does ----

## One key, on the state alone. With a dialog open the key goes to that dialog, and with a
## menu open to that menu. Else Esc and then a key
## within META_SECONDS is Alt with that key. Otherwise Alt with the hot letter of a menu opens it, and any
## other key is the key of a command of COMMANDS, or of none.
