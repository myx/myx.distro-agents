##
## AgentsManagerScreen.Routines.py -- `Routines` under `Magic-Team (Agents)` (F11.11): the standing picture of the routines the members carry, each with its executors, the kind of
## its session, its state, when it last ran, what its autorun declares, and whether it is valid. Stage one gave what the listing gives and what
## the Dispatcher's runs give; stage two (F7.5, F6.1) gives the autorun (`auto`, `runs-at`, `runs-after`) and the verdict of the validator (`valid`).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## IT RENDERS AND DOES NOT COMPUTE. `--manager-routine-list` prints the rows (AgentsTools.ManagerRoutine.include), the state and the last run of which are the Dispatcher's own (`--routine-stats`),
## the autorun the routine's own keys, and the two verdicts those of the validator and of the evaluator; this part reads no routine file, no run and no setting, and decides nothing: a verdict it
## has not been given reads `-`. It is not `Launchpad`, which shows the routines for starting one; the two stay separate.
##

## What a verdict of the listing reads as: `yes`, or `no` with its reason after a colon. A field the listing did not print (an older tooling) reads `-`: none is guessed.
def routineVerdict(field):
    word, colon, why = field.partition(":")
    return (word, unspaced(why)) if word in ("yes", "no") else ("-", "")


## What `--manager-routine-list` printed, as the rows of `Routines`: the rows `Launchpad` makes of it (parseRoutineRows), each with its state and its last run, which it shows
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


## What `--manager-routine-frontmatter` printed of a routine, its `---` block as `fm<TAB>key<TAB>value` rows: the pairs, in
## their order. It reads nothing itself: the rows come from the operation.
def parseRoutineFrontmatter(text):
    front = []
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "fm" and len(fields) >= 3:
            front.append((fields[1], fields[2] or "-"))
    return front


## The routines of a level as one table, whole in the left window: the name, the executors, the kind of
## its session, its state in its colour, when it last ran, and whether it runs by itself.
def routinesStateSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    routines = [held["routine"] for held in rows if held.get("routine")]
    if not routines:
        return [looked("No routine is carried here.", BOLD)]
    ## THE COLUMN IS GONE, as the sketch says: "remove WOULD START column from table it is
    ## pointless and misleading". The verdict is still the routine's own fact (`startable` in
    ## its summary) and still what a start is asked on; it is no longer a table column.
    ## R2 (settled): the list prints what the FRONTMATTER gives, so this table carries no VALID
    ## column; the verdict is read with the routine, in its summary, where an operator reads it.
    return tableSummaryLines(state, ("ROUTINE", "EXECUTORS", "KIND", "STATE", "LAST RUN", "AUTO"),
                             [[routine["label"], routine["executors"] or "-", routine["session"] or "-", routine["state"], routine["last"], routine["auto"]]
                              for routine in routines],
                             ("key", "text", "enum", "enum", "text", "enum"),
                             looks=[[None, None, None, stateLook(routine["state"]), None, None] for routine in routines])


## The verdicts the routine's own read carried beside its text (R15), or None.
def routineVerdictOf(state, routine):
    if not routine:
        return None
    text = state.view.get("text") or ""
    at = text.find(ROUTINE_VERDICT_MARK)
    if at < 0:
        return None
    facts = {}
    for line in text[at + len(ROUTINE_VERDICT_MARK):].splitlines():
        fields = line.split("\t")
        if len(fields) >= 2:
            facts[fields[0]] = "\t".join(fields[1:])
    return facts or None


## The command that launches a routine: the spawner's start path with this routine's own selector,
## the one `Launchpad` runs (`AgentsManagerScreen.Roots.py`: "launch": --spawn-session --routine <id>).
def routineLaunch(routine):
    return "DistroAgentsDispatcher.fn.sh --spawn-session --routine %s" % routine["selector"]


## What `--routine-stats` printed, as the rows of the runs the routines have: a dict by a routine's selector, each its one `routine` row, TAB-separated
## (runs, succeeded, failed, running, when it last ran, how that ended, when it last succeeded, its tokens and its members). The `run history` action
## reads every routine's rows (the manager's `--manager-stats-routines`, the Dispatcher's `--routine-stats` with no name, which never fails) and shows
## the one row of the routine selected, so a routine with no run reads the same `no run` line as one that has, and no read fails for it.
def parseRoutineHistory(text):
    held = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "routine" and len(fields) > 1:
            held[fields[1]] = fields
    return held


## The run history of the routine selected, as facts: what the Dispatcher says of its runs. A routine that has no run says so, in its place.
def routineHistoryLines(state, row):
    routine = row.get("routine")
    if not routine:
        return None
    fields = (state.view.get("info") or {}).get(routine["selector"])
    if not fields:
        return factLines([("run history", "no run of this routine is recorded")], state.viewWidth)
    def field(at):
        return unspaced(fields[at]) if len(fields) > at else "-"
    lastRun = field(6)
    return factLines([
        ("runs", field(2)),
        ("succeeded", field(3)),
        ("failed", field(4)),
        ("running", field(5)),
        ("last run", (lastRun + " (" + field(7) + ")") if lastRun != "-" else "-"),
        ("last succeeded", field(8)),
        ("tokens in", field(9)),
        ("tokens out", field(12)),
        ("members", field(13)),
    ], state.viewWidth)


## The routine's own text, as the `text` action reads it (`--manager-routine-text`): the file whole, broken to the pane. While it is being read, one line says so.
ROUTINE_VERDICT_MARK = "# --- verdicts of the routine ---"


## The routine's own text, without the verdict block the read appends after the marker.
def routineTextOnly(text):
    if text is None:
        return None
    at = text.find(ROUTINE_VERDICT_MARK)
    return text if at < 0 else text[:at].rstrip("\n")


def routineTextLines(state, row):
    text = routineTextOnly(state.view.get("text"))
    if text is None:
        return factLines([("text", "the routine's own text is being read")], state.viewWidth)
    return rawLines(text.splitlines(), state.viewWidth)


## The frontmatter of the routine selected, as facts under a heading of its own: the rows `--manager-routine-frontmatter` printed for it (the `fact` part of its read, parseRoutineFrontmatter);
## the screen reads no file and parses no text. While that read has not answered, one line says so; a routine whose file has no frontmatter shows none.
def routineFrontmatterLines(state):
    pairs = state.view.get("front")
    if pairs is None:
        return headingLines("frontmatter") + factLines([("frontmatter", "the routine's frontmatter is being read")], state.viewWidth)
    if not pairs:
        return []
    return headingLines("frontmatter") + factLines(pairs, state.viewWidth)


## The routine itself, rendered as the Markdown it is (catMarkdown, through markdownLines), under a heading of its own, after its facts and its frontmatter: its text as the read of the
## routine gave it, without the verdicts the same read carries. While that read has not answered, nothing is added (the frontmatter says it is being read).
def routineRenderedLines(state):
    text = routineTextOnly(state.view.get("text"))
    if text is None or not text.strip():
        return []
    lines, spans = markdownLines(text, state.viewWidth)
    return headingLines("The routine") + [lookedAt(line, spans.get(number)) for number, line in enumerate(lines)]


## ... of a routine selected: its title, then as facts what the listing says of it, what the Dispatcher says of its runs, what its autorun declares and the verdict with its reason,
## and the frontmatter of its file; or, where the `text` or the `run history` action was pressed, the routine's own text or its run history in their place.
def routinesStateFocus(state, row):
    routine = row.get("routine")
    if not routine:
        return None
    show = state.view.get("routineShow")
    if show == "text":
        return routineTextLines(state, row)
    if show == "history":
        return routineHistoryLines(state, row)
    verdict = routineVerdictOf(state, routine)
    lines = ([looked(routine["title"], BOLD)] if routine["title"] else []) + factLines([
        ("routine", routine["selector"]),
        ("owner", routine["owner"]),
        ("executors", routine["executors"]),
        ("kind", "coworking: members working together in one session" if routine["session"] == "coworking" else routine["session"]),
        ("state", routine["state"], stateLook(routine["state"])),
        ("last run", routine["last"]),
        ("runs by itself", routine["auto"] if routine["auto"] != "-" else ""),
        ("runs at", routine["runsAt"] if routine["auto"] == "yes" else ""),
        ("runs after", routine["runsAfter"] if routine["runsAfter"] not in ("", "-") else ""),
        ## R15: the verdicts come from the ONE routine's own read, not from the list (which is the
        ## frontmatter alone), and they are shown where the operator reads them.
        ("valid", (verdict or {}).get("valid", routine["valid"] if routine["valid"] != "-" else ""), routineVerdictLook((verdict or {}).get("valid", routine["valid"]))),
        ("not valid because", verdict.get("reason", routine["invalid"]) if verdict else routine["invalid"], LEVEL_BAD),
        ## The COMMAND an operator can copy to launch this very routine: the spawner's own start
        ## path (`--spawn-session --routine <selector>`, the same one `Launchpad` runs).
        ("launch", routineLaunch(routine), None),
        ("startable", routine["would"] if routine["would"] != "-" else "", routineVerdictLook(routine["would"])),
        ("would not because", routine["wouldNot"], LEVEL_BAD),
        ("start", routineStart(routine), stateLook(routineStart(routine))),
        ("why", "" if routine["start"] == "startable" else routine["reason"]),
    ], state.viewWidth)
    lines.extend(routineFrontmatterLines(state))
    lines.extend(routineRenderedLines(state))
    return lines


## ---- the actions: start, text, run history ----

## `start` is the same action as `Launchpad` (ACTION_HANDLERS "launch"): the spawner's own start path, `--spawn-session --routine <selector>`,
## with its own answer to what a start needs -- the name dialog for a routine it would start by itself, the members dialog for one whose executors are
## any member, and the refusal with its reason for every other. Its handler, its fits and its refusal are Launch's, shared; its command names it below.
## `text` shows the routine's own text in the focus pane, in place of the facts and the frontmatter (routinesStateFocus); its read is the routine's own,
## made when the routine is selected, for the frontmatter of the summary. `run history` marks the row it was asked on, which is what makes the read of
## that one thing due (its "needs"), and the focus pane then shows it in place of the facts. The screen itself reads no file and no run: the tooling is
## asked, as every read is.

def askRoutineText(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    state.view["routineShow"] = "text"
    return "the routine's own text is read"


def askRoutineHistory(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    state.view["routineShow"] = "history"
    row["historyShown"] = True
    return "the routine's run history is read"


ACTION_HANDLERS["routinetext"] = askRoutineText
ACTION_HANDLERS["routinehistory"] = askRoutineHistory


registerPlugin({
    "name": "routines",
    "mount": "magic-team",
    "root": {"id": "routines", "label": "Routines", "go": "~R~outines", "group": "team"},
    "focus": {"routines": "routinesStateFocus"},
    "summaries": {"routines": {"lines": "routinesStateSummary"}},
    "reads": {
        ## the routines the members carry, with the kind of their session, the state and the last run of each and its autorun, as the tooling gives them
        "list:routines": {"operation": ["--manager-routine-list", "--facts-only"], "rows": "routines-state"},
        ## the routine's own text, its frontmatter beside it (`--with-verdict` adds the verdicts of the one
        ## routine selected), read on selection and for the `text` action.
        "view:routines:record": {"operation": ["--manager-routine-text", "{routine}", "--with-verdict"]},
        ## the routine's frontmatter, as the tooling prints it (`fm<TAB>key<TAB>value`), read for the routine selected by its id: the facts of the routine come from the
        ## tooling, and the screen parses no text of the routine's file
        "fact:routines:record": {"operation": ["--manager-routine-frontmatter", "{id}"], "rows": "routine-frontmatter"},
        ## `acts:` is the part beside `view:` (VIEW_PARTS), read on its action alone: the run history of the
        ## routine selected, read where the `run history` action marks the row. The verdicts are the ONE
        ## routine's own and are asked for it alone (--manager-routine-verdict, R15), never for the 55 of the
        ## list, so this part carries the history and no second read of the same key.
        "acts:routines:record": {"operation": ["--manager-stats-routines"], "rows": "routine-history", "needs": "historyShown"},
    },
    "commands": (
        {"name": "routine-start", "keys": ("ENTER", "s"), "menu": ("session", 2), "label": "Start the ro~u~tine", "status": "Start",
         "views": ("routines",), "for": "a routine", "on": ("routines:record",), "only": True, "does": ("action", "launch"), "calls": ("launch",)},
        {"name": "routine-text", "keys": ("x",), "menu": ("view", 2), "label": "Show the te~x~t", "status": "Text",
         "views": ("routines",), "for": "a routine", "on": ("routines:record",), "only": True, "does": ("action", "routinetext")},
        {"name": "routine-history", "keys": ("h",), "menu": ("view", 2), "label": "Run ~h~istory", "status": "History",
         "views": ("routines",), "for": "a routine", "on": ("routines:record",), "only": True, "does": ("action", "routinehistory")},
    ),
})
