##
## AgentsManagerScreen.Routines.py -- `Routines` under `Magic-Team (Agents)` (F11.11): the standing picture of the routines the members carry, each with its executors, the kind of
## its session, its state, when it last ran, what its autorun declares, whether it is valid, and whether a start now would be accepted. Stage one gave what the listing gives and what
## the Dispatcher's runs give; stage two (F7.5, F6.1) gives the autorun (`auto`, `runs-at`, `runs-after`) and the verdicts of the validator (`valid`) and of the evaluator against a fresh
## spawn, with the window of the autorun (`would`).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## IT RENDERS AND DOES NOT COMPUTE. `--manager-routine-list` prints the rows (AgentsTools.ManagerRoutine.include), the state and the last run of which are the Dispatcher's own (`--routine-stats`),
## the autorun the routine's own keys, and the two verdicts those of the validator and of the evaluator; this part reads no routine file, no run and no setting, and decides nothing: a verdict it
## has not been given reads `-`. It is not `Launch (Start)`, which shows the routines for starting one; the two stay separate.
##

## What a verdict of the listing reads as: `yes`, or `no` with its reason after a colon. A field the listing did not print (an older tooling) reads `-`: none is guessed.
def routineVerdict(field):
    word, colon, why = field.partition(":")
    return (word, unspaced(why)) if word in ("yes", "no") else ("-", "")


## What `--manager-routine-list` printed, as the rows of `Routines`: the rows `Launch (Start)` makes of it (parseRoutineRows), each with its state and its last run, which it shows
## in place of what Launch shows at the end of a row, and its autorun and verdicts. A row too short to carry a field reads `-` for it.
def parseRoutineStateRows(readKey, level, text):
    rows = parseRoutineRows(text)
    for row in rows:
        fields = row["fields"]
        routine = row["routine"]
        routine["state"] = fields[10] if len(fields) > 10 else "-"
        routine["last"] = unspaced(fields[11]) if len(fields) > 11 else "-"
        routine["auto"] = fields[12] if len(fields) > 12 else "-"
        routine["runsAt"] = unspaced(fields[13]) if len(fields) > 13 else "-"
        routine["runsAfter"] = absent(fields[14]) if len(fields) > 14 else "-"
        routine["valid"], routine["invalid"] = routineVerdict(fields[15]) if len(fields) > 15 else ("-", "")
        routine["would"], routine["wouldNot"] = routineVerdict(fields[16]) if len(fields) > 16 else ("-", "")
        row["tail"] = routine["state"]
    return {level: rows}


ROW_FORMS["routines-state"] = parseRoutineStateRows


## The times of a routine in the table: its autorun as it declares it, `daily 09:00`, with `after <routine>` where it follows one; `-` where it declares none.
def routineTimes(routine):
    if routine["auto"] != "yes" and routine["runsAfter"] in ("", "-"):
        return "-"
    return " ".join(word for word in (routine["runsAt"] if routine["auto"] == "yes" else "", "after " + routine["runsAfter"] if routine["runsAfter"] not in ("", "-") else "") if word)


## A verdict in the table and its look: `yes` in the colour of what is well, `no` in the colour of what is not; `-` plain.
def routineVerdictLook(word):
    return LEVEL_OK if word == "yes" else LEVEL_BAD if word == "no" else None


## The routines of a level as one table, whole in the left window: the name, the executors, the kind of its session, its state in its colour, when it last ran, whether it runs by
## itself, whether it is valid, whether a start now would be accepted, and its times last, the widest, which a narrow pane leaves out before the verdicts.
def routinesStateSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    routines = [held["routine"] for held in rows if held.get("routine")]
    if not routines:
        return [looked("No routine is carried here.", BOLD)]
    return tableSummaryLines(state, ("ROUTINE", "EXECUTORS", "KIND", "STATE", "LAST RUN", "AUTO", "VALID", "WOULD START", "TIMES"),
                             [[routine["label"], routine["executors"] or "-", routine["session"] or "-", routine["state"], routine["last"], routine["auto"], routine["valid"],
                               routine["would"], routineTimes(routine)] for routine in routines],
                             ("key", "text", "enum", "enum", "text", "enum", "enum", "enum", "text"),
                             looks=[[None, None, None, stateLook(routine["state"]), None, None, routineVerdictLook(routine["valid"]), routineVerdictLook(routine["would"]), None] for routine in routines])


## ... of a routine selected: its title, then as facts what the listing says of it, what the Dispatcher says of its runs, what its autorun declares and the two verdicts with their reasons.
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
        ("runs by itself", routine["auto"] if routine["auto"] != "-" else ""),
        ("runs at", routine["runsAt"] if routine["auto"] == "yes" else ""),
        ("runs after", routine["runsAfter"] if routine["runsAfter"] not in ("", "-") else ""),
        ("valid", routine["valid"] if routine["valid"] != "-" else "", routineVerdictLook(routine["valid"])),
        ("not valid because", routine["invalid"], LEVEL_BAD),
        ("would start now", routine["would"] if routine["would"] != "-" else "", routineVerdictLook(routine["would"])),
        ("would not because", routine["wouldNot"], LEVEL_BAD),
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
        ## the routines the members carry, with the state and the last run of each, its autorun and its two verdicts, as the tooling gives them
        "list:routines": {"operation": ["--manager-routine-list"], "rows": "routines-state"},
    },
})
