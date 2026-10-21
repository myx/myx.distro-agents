##
## AgentsManagerScreen.Routines.py -- `Routines` under `Magic-Team (Agents)` (F11.11): the standing picture of the routines the members carry, each with its executors, the kind of
## its session, its state and when it last ran. Stage one of the two the epic names: what the listing gives and what the Dispatcher's runs give; the declared columns (auto-runnable,
## times, valid, would start now) follow their declarations (F7.5, F6.1).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## IT RENDERS AND DOES NOT COMPUTE. `--manager-routine-list` prints the rows (AgentsTools.ManagerRoutine.include), the last two fields of which, the state and the last run, are the
## Dispatcher's own (`--routine-stats`); this part reads no routine file and no run. It is not `Launch (Start)`, which shows the routines for starting one; the two stay separate.
##

## What `--manager-routine-list` printed, as the rows of `Routines`: the rows `Launch (Start)` makes of it (parseRoutineRows), each with its state and its last run, which it shows
## in place of what Launch shows at the end of a row. A row too short to carry them reads a state it does not know: `-`.
def parseRoutineStateRows(readKey, level, text):
    rows = parseRoutineRows(text)
    for row in rows:
        fields = row["fields"]
        row["routine"]["state"] = fields[10] if len(fields) > 10 else "-"
        row["routine"]["last"] = unspaced(fields[11]) if len(fields) > 11 else "-"
        row["tail"] = row["routine"]["state"]
    return {level: rows}


ROW_FORMS["routines-state"] = parseRoutineStateRows


## The routines of a level as one table, whole in the left window: the name, the executors, the kind of its session, its state in its colour, and when it last ran.
def routinesStateSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    routines = [held["routine"] for held in rows if held.get("routine")]
    if not routines:
        return [looked("No routine is carried here.", BOLD)]
    return tableSummaryLines(state, ("ROUTINE", "EXECUTORS", "KIND", "STATE", "LAST RUN"),
                             [[routine["label"], routine["executors"] or "-", routine["session"] or "-", routine["state"], routine["last"]] for routine in routines],
                             ("key", "text", "enum", "enum", "text"),
                             looks=[[None, None, None, stateLook(routine["state"]), None] for routine in routines])


## ... of a routine selected: its title, then as facts what the listing says of it and what the Dispatcher says of its runs.
def routinesStateFocus(state, row):
    routine = row.get("routine")
    if not routine:
        return None
    return ([looked(routine["title"], BOLD)] if routine["title"] else []) + factLines([
        ("routine", routine["selector"]),
        ("owner", routine["owner"]),
        ("executors", routine["executors"]),
        ("kind", "coworking: members working together in one session" if routine["session"] == "coworking" else routine["session"]),
        ("state", routine["state"], stateLook(routine["state"])),
        ("last run", routine["last"]),
        ("start", routineStart(routine), stateLook(routineStart(routine))),
        ("why", "" if routine["start"] == "startable" else routine["reason"]),
    ], state.viewWidth)


registerPlugin({
    "name": "routines",
    "mount": "magic-team",
    "root": {"id": "routines", "label": "Routines", "go": "~R~outines", "group": "team"},
    "focus": {"routines": "routinesStateFocus"},
    "summaries": {"routines": {"lines": "routinesStateSummary"}},
    "reads": {
        ## the routines the members carry, with the state and the last run of each, as the tooling gives them
        "list:routines": {"operation": ["--manager-routine-list"], "rows": "routines-state"},
    },
})
