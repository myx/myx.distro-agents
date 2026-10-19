##
## AgentsManagerScreen.Sessions.py -- the root Sessions (Activity): the sessions, their agents, Launch (Start), and the kill, the control and the start.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the sessions and their agents ----

## A value as the registry holds it, back as it was: its whitespace was written as `_`,
## and an absent one as `-`.
def unspaced(value):
    return "" if value == "-" else value.replace("_", " ")


## A value that is a name, a key or a path, as it is written: its own `_` stays, since
## nothing tells it from one that stands for a space. An absent one, `-`, is empty.
def absent(value):
    return "" if value == "-" else value


## A date as the registry holds it (2026-10-12_16:57_+0300), in seconds, or None.
def registryEpoch(value):
    try:
        return datetime.datetime.strptime(value, "%Y-%m-%d_%H:%M_%z").timestamp()
    except ValueError:
        return None


## A date of the registry for the left pane, with how long ago it was.
def registryDate(value):
    age = ageText(registryEpoch(value), nowEpoch())
    return unspaced(value) + (" (%s ago)" % age if age else "")


## What `--manager-session-list` printed, as rows by level: rows of TAB-separated fields,
## the first naming the row. A `session` row is followed by its `run` rows, and the one
## `counters` row is the last line (readCounters). The sessions keep the order they come
## in, the newest first; each is a level of its own that holds its runs, the agents.
## A session shows by its name, or by its id where it has none, and an agent by its
## member, each with its state at the end of its row, and for a live agent its activity.
## A session that is one lone run with no name is no work session to look at: it shows
## plainer, dimmed, by the member that ran and the head of its id.
## After its eight fields a `session` row says of the control thread of the session, the
## tooling's own process that watches its runs: the state that thread stored, when, and
## whether it is `alive`, `gone` or `none`. A session whose thread is gone carries the mark
## of a process that is gone (MARK_GONE) ahead of its state; one whose thread lives, or that
## has none, carries no mark. A row of the eight fields alone says nothing of it: `-`.
def parseSessionLevels(text):
    level = pluginLevel("sessions")
    levels = {level: []}
    sessions = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "session" and len(fields) >= 8:
            session = {"id": fields[1], "name": unspaced(fields[2]), "state": fields[3], "started": fields[4],
                       "stateAt": fields[5], "count": fields[6], "tally": fields[7], "runs": [], "lone": False}
            session["stored"], session["storedAt"], session["control"] = fields[8:11] if len(fields) >= 11 else ("-", "-", "-")
            row = newRow(fields[1], session["name"] or fields[1], "record", True, fields)
            row["session"] = session
            row["tail"] = (MARK_GONE + " " if session["control"] == "gone" else "") + session["state"]
            row["look"] = BOLD if session["state"] == "running" else PLAIN
            if len(fields) >= 12:
                ## the total of its tokens, the last field of its row: the narrow column of the list
                session["tokens"] = fields[11]
                row["wide"] = tokensShort(fields[11])
            sessions[fields[1]] = row
            levels[level].append(row)
            levels[level + "/" + fields[1]] = []
        elif fields[0] == "run" and len(fields) >= 12 and fields[1] in sessions:
            runs = levels[level + "/" + fields[1]]
            run = {"session": fields[1], "spawn": fields[2], "member": fields[3], "status": fields[4],
                   "live": fields[5], "state": fields[6], "started": fields[7], "resolved": fields[8],
                   "host": fields[9], "workspace": fields[10], "activity": fields[11]}
            row = newRow(fields[2] if fields[2] != "-" else "-%d" % len(runs), fields[3], "record", False, fields)
            row["run"] = run
            row["tail"] = runStateText(run)
            row["look"] = BOLD if run["live"] == "running" else PLAIN
            sessions[fields[1]]["session"]["runs"].append(run)
            runs.append(row)
    for row in levels[level]:
        session = row["session"]
        if not session["name"] and len(session["runs"]) == 1:
            session["lone"] = True
            row["label"] = "%s %s" % (session["runs"][0]["member"], session["id"][:8])
            if row["look"] == PLAIN:
                row["look"] = DIM
    return levels


## The total of the tokens of a session as its list row gives it, short: the number as
## shortCount gives it, with the `+` the row ends it by where some of its runs are not
## counted in, and what is no number as it is.
def tokensShort(value):
    more = "+" if value.endswith("+") else ""
    return shortCount(value[:len(value) - len(more)]) + more


## The state of an agent, and its activity where it is alive: `running working`.
def runStateText(run):
    return run["state"] + (" " + run["activity"] if run["activity"] != "-" else "")


## Lines `<name> <value>` for the left pane, a value broken to the width of the pane; an
## empty value is left out.
def fieldLines(pairs, width):
    lines = []
    for name, value in pairs:
        if value:
            parts = wrapToCells(value, max(10, width - 11))
            lines.append("%-9s %s" % (name, parts[0]))
            lines.extend(" " * 10 + part for part in parts[1:])
    return lines


## The line `control` of the left pane of a session: whether its control thread lives, with
## its pid once the read of that one session has given it, and the state that thread stored
## for the session with when it was set. It stands under the state the list derives, and
## each of the two is shown as it is, also where they differ. From the read of the session
## where it has come, which reads the stored state at every call, else from the row of the
## list. `-` where neither says anything of it: a row and a read of before.
def controlText(session, info=None):
    told = (info or {}).get("control") or {"stored": session.get("stored", "-"), "storedAt": session.get("storedAt", "-"),
                                           "control": session.get("control", "-"), "pid": "-"}
    if told["control"] == "-" and told["stored"] == "-":
        return "-"
    thread = told["control"] + (", pid " + told["pid"] if told["control"] == "alive" and told["pid"] != "-" else "")
    stored = "stored " + told["stored"]
    if told["stored"] != "-" and told["storedAt"] != "-":
        stored += ", set " + registryDate(told["storedAt"])
    return thread + "; " + stored


## The selected session for the left pane, from its row and the rows of its runs: its
## name, or that it is one lone run with no name, then its facts, its state and that of its
## control thread in their colours, when it started and ended; its agents as a table, each
## with its state and since when it runs, or until when it ran. Once the read of that one
## session has come (info), also its tokens, by whom and for what it was founded, and the
## text of its dispatch, and its agents as that read has them. Its id stands last.
def sessionLines(session, width, info=None, limit=0, wrap=True):
    control = controlText(session, info)
    lines = [looked(session["name"] or ("one lone run with no name" if session["lone"] else session["id"]), BOLD)]
    pairs = [
        ("state", session["state"], stateLook(session["state"])),
        ("control", control, stateLook(control.partition(";")[0])),
        ("started", registryDate(session["started"])),
        ("ended", registryDate(session["stateAt"])),
        ("tokens", tokensText(info["tokens"]) if info and info.get("tokens") else ""),
    ]
    dispatch = info["dispatch"] if info else None
    if dispatch:
        if dispatch["founder"] == "no-record":
            pairs.append(("founded", "by a client, whose founder left no record"))
        else:
            pairs.append(("founded", ", ".join(word for word in (
                "by " + dispatch["member"] if dispatch["member"] else "",
                "routine " + dispatch["routine"] if dispatch["routine"] else "",
                "item " + dispatch["item"] if dispatch["item"] else "") if word)))
    runs = info["runs"] if info and info["runs"] else session["runs"]
    lines.extend(factLines(pairs, width))
    if runs:
        lines.extend(headingLines("Agents") + agentsTable(runs, width, wrap))
    lines.extend(dispatchLines(dispatch, width))
    lines.extend([""] + factLines([("session", session["id"])], width))
    return lines


## The total of the tokens of a session, from the `tokens` row of its read: the four
## figures in the short form the line of an agent uses, then whether that is the total of
## a finished session or what was eaten so far, and how many runs are not counted in it.
TOKEN_TOTALS = {"final": "total", "so-far": "so far"}


def tokensText(tokens):
    left = ", %s run%s not counted" % (tokens["unknown"], "" if tokens["unknown"] == "1" else "s") if tokens["unknown"] not in ("", "0", "-") else ""
    if tokens["summed"] in ("", "0", "-"):
        return "not known" + left
    return "in %s, cache read %s, cache write %s, out %s, %s%s" % (
        shortCount(tokens["in"]), shortCount(tokens["cacheRead"]), shortCount(tokens["cacheWrite"]), shortCount(tokens["out"]),
        TOKEN_TOTALS.get(tokens["total"], tokens["total"]), left)


## The columns of the table of the agents of a session, what of a run stands in each, and
## the kind of each (paneTable). A column no agent has a word for is left out.
AGENT_COLUMNS = (
    ("MEMBER", lambda run, store: run["member"], "key"),
    ("STATE", lambda run, store: runStateText(run), "enum"),
    ("SINCE", lambda run, store: unspaced(run["started"]) if run["resolved"] == "-" else "until " + unspaced(run["resolved"]), "text"),
    ("TOKENS", lambda run, store: shortCount(str(sum(int(store[name]) for name in ("in", "cacheRead", "cacheWrite", "out"))))
     if all(store.get(name, "").isdigit() for name in ("in", "cacheRead", "cacheWrite", "out")) else "", "text"),
    ("CLI", lambda run, store: (run.get("headers") or {}).get("cli", ""), "enum"),
    ("MODEL", lambda run, store: unspaced(store.get("model", "-")), "text"),
)


## The agents of a session as a table of the left pane (paneTable), each state in its colour.
def agentsTable(runs, width, wrap=True):
    words = [[column[1](run, run.get("store") or {}) for column in AGENT_COLUMNS] for run in runs]
    shown = [index for index, column in enumerate(AGENT_COLUMNS) if any(line[index] for line in words)]
    head, blocks = paneTable([AGENT_COLUMNS[index][0] for index in shown], [[line[index] or "-" for index in shown] for line in words],
                             max(10, width - 1), wrap=wrap, kinds=[AGENT_COLUMNS[index][2] for index in shown],
                             looks=[[stateLook(line[index]) if AGENT_COLUMNS[index][0] == "STATE" else None for index in shown] for line in words])
    return head + [line for block in blocks for line in block]


## What a session was started with, as far as its read gives it, under a heading of its
## own: the text of its dispatch, whole, broken to the window.
def dispatchLines(dispatch, width):
    if not dispatch or dispatch["founder"] == "no-record" or not dispatch["description"].strip():
        return []
    lines = headingLines("Dispatch")
    for paragraph in dispatch["description"].split("\n"):
        lines.extend(wrapToCells(paragraph, max(10, width - 1)) if paragraph.strip() else [""])
    return lines


## The selected agent of a session for the left pane, from its row, as facts, its state
## and its process in their colours; once the read of that one run has come (info), also
## what it waits on while it is alive, and while it sits in a Wait for how long, its open
## asks, its model and its token counts, its last milestone and its marks. A run in a Wait
## (its activity `waiting`) has that Wait's start as its last milestone, `wait going idle`,
## which every Wait stores as it starts: its wait is counted from there, in the form of an
## age. Its session is the folder it stands in, and not said again. Within a limit of lines
## the last ones go.
def runLines(run, width, info=None, limit=0):
    told = info["bySpawn"].get(run["spawn"]) if info else None
    store = told["store"] if told and told["store"] else {}
    headers = told["headers"] if told else {}
    run = told or run
    asks = [one for one in store.get("asks", "-").split(",") if one and one != "-"]
    milestoneAge = ageText(isoEpoch(store.get("milestoneAt", "")), nowEpoch())
    waits = store.get("waits", "") if run["live"] == "running" else ""
    if waits and run.get("activity") == "waiting" and milestoneAge:
        waits += " for " + milestoneAge
    lines = factLines([
        ("state", runStateText(run), stateLook(runStateText(run))),
        ("status", unspaced(run["status"])),
        ("process", unspaced(run["live"])),
        ("started", registryDate(run["started"])),
        ("ended", registryDate(run["resolved"])),
        ("waits on", waits),
        ("asks", "%d open: %s" % (len(asks), ", ".join(asks)) if asks else ""),
        ("model", ", ".join(word for word in (unspaced(store.get("model", "-")), "cli " + headers["cli"] if headers.get("cli") else "") if word)),
        ("tokens", "in %s, cache read %s, cache write %s, out %s" % tuple(
            shortCount(store[name]) for name in ("in", "cacheRead", "cacheWrite", "out")) if store.get("store") == "store" else ""),
        ("last", store.get("milestone", "") + (", %s ago" % milestoneAge if store.get("milestone") and milestoneAge else "")),
        ("marks", unspaced(store.get("marks", "-")).replace(",", ", ") + (
            " (dismissed by %s)" % store["dismissedBy"] if store.get("dismissedBy") else "")),
        ("host", unspaced(run["host"])),
        ("workspace", unspaced(run["workspace"])),
        ("run", unspaced(run["spawn"])),
    ], width)
    lines.extend(dispatchLines(info.get("dispatch") if info else None, width))
    return lines[:limit] if limit else lines


## The agents of a session in a few words, from its row: how many, and how many of each
## state, as the row tallies them.
def agentsText(session):
    tally = ", ".join("%s %s" % (part.partition("=")[2], part.partition("=")[0])
                      for part in session["tally"].split(",") if "=" in part)
    return "%s: %s" % (session["count"], tally) if tally else session["count"]


## The members that run in a session, each once, in the order of its runs.
def membersText(session):
    names = []
    for run in session["runs"]:
        if run["member"] not in names:
            names.append(run["member"])
    return ", ".join(names)


## What `Sessions (Activity)` holds, for the left pane while the section itself or the row
## that goes up is selected: as its caption how many sessions, by the states the rows hold,
## those its declaration counts first (SUMMARIES) ahead of the others, and the agents of the
## workspace working and waiting; then every session of the list, in its order, as a table
## (tableSummaryLines): its state in its colour, with the mark of a control thread that is
## gone, how long ago it started, how many agents, its tokens and the members that run in
## it. None until its read has answered.
def sessionsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    held = [one for one in rows if one.get("session")]
    if not held:
        return ["No %ssessions." % ("active " if state.activeOnly else "")]
    now = nowEpoch()
    return tableSummaryLines(state, ("SESSION", "STATE", "AGE", "AGENTS", "TOKENS", "MEMBERS"), [
        [one["label"], one["tail"], ageText(registryEpoch(one["session"]["started"]), now) or "-", one["session"]["count"],
         tokensShort(one["session"]["tokens"]) if one["session"].get("tokens") else "-", membersText(one["session"]) or "-"] for one in held],
        ("key", "enum", "text", "text", "text", "text"), looks=[[None, stateLook(one["tail"])] + [None] * 4 for one in held])


## ---- the routines to start by hand: `Launch (Start)` ----

ROUTINE_SUFFIX = ".routine.md"


## The name a session takes from its routine where no other is given: the selector without
## the member that owns the routine and without `.routine.md`.
def routineName(selector, owner):
    name = selector[:-len(ROUTINE_SUFFIX)] if selector.endswith(ROUTINE_SUFFIX) else selector
    if owner and name.startswith(owner + ".") and len(name) > len(owner) + 1:
        name = name[len(owner) + 1:]
    return name


## Whether a routine is started only with members named: the list says so in the last
## field of its row, of a routine that is not startable for that cause alone, its
## executors being any member.
def routineAsksMembers(routine):
    return routine["start"] == "not-startable" and routine.get("needs") == "members"


## What `--manager-routine-list` printed, as rows: `routine` rows of TAB-separated fields,
## in the order they come, by owner and then by selector. A routine shows by its selector
## without `.routine.md`. One the session spawner would not start with no member named
## shows plainer: dimmed, with what the operation says of it, `not-startable` or `broken`,
## at the end of its row. Why stands in the left pane, and Enter does not start it. One
## that is started only with members named shows `members` there, and Enter asks for them. The id
## of a row is the owner and the selector, since two folders may hold a file of one name.
def parseRoutineRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "routine" or len(fields) < 9:
            continue
        routine = {"selector": fields[1], "owner": fields[2], "start": fields[3], "executors": unspaced(fields[4]),
                   "session": unspaced(fields[5]), "title": unspaced(fields[7]), "reason": unspaced(fields[8]),
                   "name": routineName(fields[1], fields[2])}
        label = fields[1][:-len(ROUTINE_SUFFIX)] if fields[1].endswith(ROUTINE_SUFFIX) else fields[1]
        routine["label"] = label
        routine["needs"] = fields[9] if len(fields) > 9 else "-"
        row = newRow(fields[2] + "/" + fields[1], label, "record", False, fields)
        row["routine"] = routine
        if routineAsksMembers(routine):
            row["tail"] = "members"
        elif routine["start"] != "startable":
            row["tail"] = routine["start"]
            row["look"] = DIM
        rows.append(row)
    return rows


## The word of a routine's start: the one the list prints of it, or `members` for one that
## is started with members named.
def routineStart(routine):
    return "members" if routineAsksMembers(routine) else routine["start"]


## The selected routine for the left pane, from its row: its title, then as facts its file,
## the member that owns it, who runs it, the kind of its session, and whether it is started
## here, in its colour: under which name, or why not.
def routineLines(routine, width):
    startable = routine["start"] == "startable"
    return ([looked(routine["title"], BOLD)] if routine["title"] else []) + factLines([
        ("routine", routine["selector"]),
        ("owner", routine["owner"]),
        ("executors", routine["executors"]),
        ("session", "coworking: members working together in one session" if routine["session"] == "coworking" else routine["session"]),
        ("start", routineStart(routine) + (": its members are asked for" if routineAsksMembers(routine) else ""), stateLook(routineStart(routine))),
        ("name", "%s, unless another is typed" % routine["name"] if startable else ""),
        ("why", "" if startable else routine["reason"]),
    ], width)


## The free prompt for the left pane: what a prompt typed there starts.
def freePromptLines(width):
    lines = []
    for text in ("A prompt typed here starts a new coworking session, opened by the coordinator, with that prompt as its brief.",
                 "Enter opens its dialog: who runs it, the prompt, the name of the session. An empty prompt starts nothing."):
        lines.extend(wrapToCells(text, max(10, width - 1)))
    return lines


## What `Launch (Start)` holds, for the left pane while the row that goes up is selected
## there, or its own row in the list of the sessions: as its caption how many routines, how
## many of them are started here, how many once members are named, and how many are not;
## then every routine of the list, in its order, as a table (tableSummaryLines): its name,
## the name its session takes, its start in its colour, its owner, its title, and the kind of
## its session where any routine names one. None until its read has answered.
def routinesSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    routines = [held["routine"] for held in rows if held.get("routine")]
    if not routines:
        return ["No routines."]
    sessions = any(routine["session"] for routine in routines)
    return tableSummaryLines(state, ("ROUTINE", "START", "OWNER", "TITLE") + (("SESSION",) if sessions else ()), [
        [routine["name"], routineStart(routine), routine["owner"] or "-", routine["title"] or "-"] + ([routine["session"] or "-"] if sessions else [])
        for routine in routines], ("key", "enum", "text", "text", "enum"),
        looks=[[None, stateLook(routineStart(routine)), None, None, None] for routine in routines])


## The row of a session in the list of the sessions, by its id, or None.
def sessionRowOf(state, sessionId):
    for row in pluginRows(state, "sessions"):
        if row["id"] == sessionId and row.get("session"):
            return row
    return None


## What `k` acts on at that row, or None where the row is no session and no agent: its
## kind, the id the operation is given, what it shows as, and under "runs" its runs that
## are alive, which are what the operation ends. A session: every live run of it. An
## agent: that agent alone, by its own id.
def killTargetOf(state, row):
    if row is None:
        return None
    level = levelPattern(state.path)
    if level == pluginLevel("sessions") and row.get("session") and row["session"]["id"] not in ("", "-"):
        session = row["session"]
        return {"kind": "session", "id": session["id"], "label": row["label"], "session": session,
                "runs": [run for run in session["runs"] if run["live"] == "running"]}
    if level == pluginLevel("sessions", "*") and row.get("run"):
        run = row["run"]
        sessionRow = sessionRowOf(state, run["session"])
        return {"kind": "run", "id": run["spawn"], "label": run["member"], "run": run,
                "sessionLabel": sessionRow["label"] if sessionRow else run["session"],
                "runs": [run] if run["live"] == "running" and run["spawn"] not in ("", "-") else []}
    return None


## Whether `k` acts on that row: a session that is not finished, whatever lives of it,
## since its kill finishes it; and an agent with a live run.
def killFits(state, row):
    target = killTargetOf(state, row)
    if target is None:
        return False
    if target["kind"] == "session":
        return target["session"]["state"] != SESSION_FINISHED
    return bool(target["runs"])


## Why `k` does nothing at a row it is for: the session is finished, the agent is not alive.
def killRefusal(state, row):
    target = killTargetOf(state, row)
    if target is None:
        return ""
    return "this session is finished" if target["kind"] == "session" else "this agent is not alive"


## The rows `--manager-session-kill` prints, a kill and the plan of one alike, each by its
## name with the names of its fields after the first: a `kill` row for each run the id
## names; a `dismiss` row for each question of it that waited; a `close` row for each
## record of it that was left open; and last, for a whole session, the one `finish` row
## that sums them: how many were ended, dismissed and closed, and the state it reads.
KILL_ROWS = {
    "kill": ("session", "spawn", "member", "outcome", "status", "pids", "item"),
    "dismiss": ("session", "question", "asker", "outcome"),
    "close": ("session", "spawn", "member", "outcome", "item"),
    "finish": ("session", "ended", "dismissed", "closed", "state"),
}
## What each <outcome> of a `kill` row means, in words, and the words it is counted under
## in the bottom line. An outcome that is not listed here shows as it is printed.
KILL_OUTCOMES = {
    "ended": ("ended", "ended"),
    "killed": ("killed: it took KILL", "killed"),
    "not-ended": ("not ended: a process is still there after TERM and KILL", "not ended"),
    "no-process": ("was not running", "was not running"),
    "other-host": ("not signalled: it runs on another host", "not signalled"),
    "no-spawn-id": ("not signalled: it has no id of its own", "not signalled"),
    "host-unrecorded": ("not signalled: its record names no host", "not signalled"),
    "would-end": ("would be ended", "would be ended"),
}
## The same of a `dismiss` row, and of a `close` row.
DISMISS_OUTCOMES = {
    "dismissed": ("dismissed", "dismissed"),
    "not-dismissed": ("not dismissed: it waits still", "not dismissed"),
    "would-dismiss": ("would be dismissed", "would be dismissed"),
}
CLOSE_OUTCOMES = {
    "closed": ("closed", "closed"),
    "not-closed": ("not closed: it is open still", "not closed"),
    "left": ("left to its supervising shell, which lives and closes it", "left open"),
    "would-close": ("would be closed", "would be closed"),
}
## The outcomes of a `kill` row of a plan that say the run lives, and would be ended.
KILL_LIVES = ("would-end",)
## How many rows of one sort the confirmation of a kill sets out, before it counts the rest.
KILL_SHOWN = 6


## What `--manager-session-kill` printed, as its rows by their names (KILL_ROWS), each row
## by the names of its fields. A line that is none of them, and one too short, is left out.
def parseKillRows(text):
    rows = dict((name, []) for name in KILL_ROWS)
    for line in text.splitlines():
        fields = line.split("\t")
        names = KILL_ROWS.get(fields[0])
        if names and len(fields) > len(names):
            rows[fields[0]].append(dict(zip(names, fields[1:])))
    return rows


## A count as the operation gives it, with its word, in the plural where it is not one.
def countWords(count, word):
    return "%s %s" % (count, word if str(count) == "1" else word + "s")


## The read of what the kill of that target would do: its key in READS and its words, or
## the key and None where no operation gives it.
def killPlanRead(state, target):
    key = "plan:kill:" + target["kind"]
    return key, readWords(READS[key], state, {"id": target["id"]}, False) if READS.get(key) else None


## What the kill of that target would do, as its plan was read: its rows by their names,
## and "". Or None, and the line the confirmation says in their place: while the plan is
## being read, where its read failed, and where it printed no row of a kill.
def killPlanOf(state, target):
    key, words = killPlanRead(state, target)
    plan = state.plans.get(key)
    if words is None or plan is None or plan["words"] != words:
        return None, "What it does besides, the questions it dismisses and the records it closes, is being read."
    if plan["error"]:
        return None, "What it does besides could not be read: %s" % plan["error"]
    if not any(plan["rows"].values()):
        return None, "What it does besides is not known: its plan printed no row."
    return plan["rows"], ""


## Whether something of that target lives, and so is killed, not only closed: by the plan
## where it was read, how many it would end; until then by the live runs the list gave. An
## agent is killed only while it lives.
def killLives(target, rows):
    if target["kind"] != "session":
        return True
    if rows is None:
        return bool(target["runs"])
    if rows["finish"]:
        return rows["finish"][-1]["ended"] != "0"
    return any(kill["outcome"] in KILL_LIVES for kill in rows["kill"])


## The lines of a plan for the confirmation: what would be dismissed, and for a whole
## session, ahead of it, what would be ended, and after it what would be closed and the
## state the session reads now. Each with its count, from the row that sums them where
## there is one, and under it its rows, no more than KILL_SHOWN of a sort.
def killPlanLines(target, rows):
    whole = target["kind"] == "session"
    members = dict((kill["spawn"], kill["member"]) for kill in rows["kill"])
    ending = [kill for kill in rows["kill"] if kill["outcome"] in KILL_LIVES]
    finish = rows["finish"][-1] if rows["finish"] else {}
    lines = []

    def part(count, said, none, shown):
        lines.append(said if str(count) != "0" else none)
        lines.extend(shown[:KILL_SHOWN])
        if len(shown) > KILL_SHOWN:
            lines.append("  and %d more" % (len(shown) - KILL_SHOWN))

    if whole:
        count = finish.get("ended", len(ending))
        part(count, "It ends " + countWords(count, "agent") + " the hard way: no closure runs, none is asked anything.",
             "No agent of it is alive: nothing is ended.",
             ["  %-18s pid %s  %s" % (kill["member"], kill["pids"], unspaced(kill["spawn"])) for kill in ending])
    count = finish.get("dismissed", len(rows["dismiss"]))
    part(count, "It dismisses " + countWords(count, "question") + (" of it that waits:" if str(count) == "1" else " of it that wait:"),
         "No question of it waits: nothing is dismissed.",
         ["  %s  asked by %s" % (dismiss["question"], members.get(dismiss["asker"], dismiss["asker"])) for dismiss in rows["dismiss"]])
    if whole:
        count = finish.get("closed", len(rows["close"]))
        part(count, "It closes " + countWords(count, "record") + " of it left open:",
             "No record of it is left open: nothing is closed.",
             ["  %-18s %s" % (close["member"], unspaced(close["item"])) for close in rows["close"]])
        if finish:
            lines.append("The session reads %s now." % unspaced(finish["state"]))
    return lines


## What the confirmation of a kill says, exactly: what is ended, by which id, and how, and
## from the plan of the kill (`rows`, killPlanOf) what is dismissed and closed with it.
## Until the plan was read: what the list gave of it, and `note`, the line that says the
## plan is being read or why there is none.
def killSays(target, rows=None, note=""):
    lives = killLives(target, rows)
    if target["kind"] == "session":
        lines = ["%s the session %s" % ("KILL" if lives else "CLOSE", target["label"]),
                 "session %s" % target["id"]]
        if rows is not None:
            lines.extend(killPlanLines(target, rows))
        else:
            alive = target["runs"]
            if alive:
                lines.append("%s the hard way: no closure runs, none is asked anything." % (
                    "Its 1 live agent ends" if len(alive) == 1 else "Its %d live agents end" % len(alive)))
            else:
                lines.append("No agent of it is alive: nothing is ended.")
            lines.extend("  %-18s %-16s %s" % (run["member"], runStateText(run), unspaced(run["spawn"])) for run in alive[:KILL_SHOWN])
            if len(alive) > KILL_SHOWN:
                lines.append("  and %d more" % (len(alive) - KILL_SHOWN))
            lines.append(note)
    else:
        run = target["run"]
        lines = ["KILL the agent %s alone" % target["label"],
                 "run %s, %s" % (target["id"], runStateText(run)),
                 "of the session %s" % target["sessionLabel"]
                 + (" (%s)" % run["session"] if target["sessionLabel"] != run["session"] else ""),
                 "It ends the hard way: no closure runs, it is asked nothing. The others run on."]
        if run["spawn"] == run["session"]:
            lines.append("It is the founder: its id is its session's. It alone is ended, not the session.")
        lines.extend(killPlanLines(target, rows) if rows is not None else [note])
    if lives:
        lines.append("The word %s, typed whole, and Kill or Enter: that kills. Cancel and Esc kill nothing." % KILL_WORD)
    else:
        lines.append("The word %s, typed whole, and Close or Enter: that finishes the session. Cancel and Esc do nothing." % KILL_WORD)
    return lines


## What a plan is known by, where the one a confirmation showed is held against the one
## read when it was confirmed: its rows, and whether its read failed.
def killPlanSeen(plan):
    return (plan["rows"], bool(plan["error"]))


## A confirmation whose button was pressed, at a turn of the screen: its plan is read once
## more, and until that has answered the dialog stands as it was confirmed, and nothing
## fills it (False). When it has answered: where the plan is the one the dialog showed, and
## the word stands, the kill is asked of the tooling and the dialog closes (False). Where
## the plan has changed nothing is done: the word is taken out, the dialog says so and
## shows the plan as it is now (True), and it is confirmed again or left.
def killChecked(state, dialog):
    key, words = killPlanRead(state, dialog["about"]["target"])
    plan = state.plans.get(key)
    if plan is None or plan["words"] != words:
        return False
    seen, dialog["about"]["pressed"] = dialog["about"]["pressed"], None
    if dialogMissing(dialog) is not None:
        ## the word was changed meanwhile: what was pressed is no longer confirmed
        dialog["says"] = ""
        return True
    if killPlanSeen(plan) == seen:
        killAsked(state, dialog)
        if state.dialog is dialog:
            closeDialog(state)
        return False
    word = dialogControl(dialog, "word")
    word["value"] = ""
    dialog["focus"] = dialogStops(dialog).index(("control", dialog["controls"].index(word)))
    dialog["says"] = KILL_SAYS["changed"]
    return True


## The confirmation of a kill as it stands now, at every turn while it is open: what it
## says, from the plan once that was read; and where nothing of the session lives, the
## title, the button and the word of a close (the dialog "close") in place of a kill's.
## The plan is read when the dialog opens and not again while it stands, so its text does
## not change under the word; after its button was pressed, see killChecked. A kill whose
## plan could not be read is not asked for: its dialog says that, and has Cancel alone.
def fillKill(state, dialog):
    target = dialog["about"]["target"]
    if dialog["about"].get("pressed") is not None and not killChecked(state, dialog):
        return
    rows, note = killPlanOf(state, target)
    key, words = killPlanRead(state, target)
    plan = state.plans.get(key)
    if words is not None and plan is not None and plan["words"] == words and plan["error"]:
        ## its plan could not be read: the kill is not asked for. The dialog says so, takes
        ## no word, and offers nothing but to leave it
        dialog["buttons"] = [button for button in DIALOGS[dialog["name"]]["buttons"] if button[0] == "cancel"]
        dialog["controls"] = [control for control in dialog["controls"] if control["name"] == "about"]
        dialog["focus"] = 0
        dialogControl(dialog, "about")["lines"] = [
            "The %s %s" % ("session" if target["kind"] == "session" else "agent", target["label"]),
            "%s %s" % ("session" if target["kind"] == "session" else "run", target["id"]),
            "What its kill would do could not be read: %s" % plan["error"], KILL_SAYS["unreadable"]]
        return
    declared = DIALOGS["kill" if killLives(target, rows) else "close"]
    dialog["name"] = "kill" if killLives(target, rows) else "close"
    dialog["buttons"] = list(declared["buttons"])
    for held, control in zip(dialog["controls"], declared["controls"]):
        held.update((field, control[field]) for field in ("label", "required") if field in control)
    dialog["title"] = "%s the session" % declared["title"] if target["kind"] == "session" else "%s the agent %s" % (declared["title"], target["label"])
    dialogControl(dialog, "about")["lines"] = killSays(target, rows, note)


## `k`: asks for the confirmation of the kill of the selected session or agent, in a
## dialog that says exactly what will be killed, dismissed and closed: the plan of that
## kill is read anew for it. On a row that is no session and no agent, on a session
## that is finished and on an agent that is not alive the key says its line in the status
## line (killRefusal) and this is not reached.
def askKill(state, row):
    target = killTargetOf(state, row)
    if target is None or not killFits(state, row):
        return ""
    state.answer = None
    ## the answer belongs to the item the key was pressed on, whatever is selected when it comes
    target["viewKey"] = viewKeyOf(state)
    key, words = killPlanRead(state, target)
    state.plans.pop(key, None)
    state.forced.add(key)
    fillKill(state, openDialog(state, "kill", None, {"target": target}))
    return ""


## Kill, or Close, in the dialog of a kill. Exactly the word does it, and any other word
## is refused there. Nothing is done at once: the plan of the kill is read once more, and
## the dialog stays as it is and says so. When that has answered (killChecked), the kill
## is asked for where the plan is still the one the dialog showed. A press while the first
## read of the plan has not answered does nothing, and says so. Where no operation gives
## a plan there is none to hold against, and the kill is asked for at once.
def submitKill(state, dialog, button):
    key, words = killPlanRead(state, dialog["about"]["target"])
    if words is None:
        killAsked(state, dialog)
        return None
    if dialog["about"].get("pressed") is not None:
        return KILL_SAYS["checking"]
    plan = state.plans.get(key)
    if plan is None or plan["words"] != words:
        return KILL_SAYS["unread"]
    dialog["about"]["pressed"] = killPlanSeen(plan)
    state.plans.pop(key, None)
    state.forced.add(key)
    return KILL_SAYS["checking"]


## The kill a confirmation named is asked of the tooling: the operation is called once,
## with the id of what the dialog named.
def killAsked(state, dialog):
    target = dialog["about"]["target"]
    askCall(state, "kill", target["id"], callWords("kill:" + target["kind"], target["id"]), None,
            {"viewKey": target["viewKey"]})
    said = "kill asked of the tooling: the %s %s" if dialog["name"] == "kill" else "close asked of the tooling: the %s %s"
    state.notice = said % ("session" if target["kind"] == "session" else "agent", target["label"])
    state.noticeOf = None


DIALOG_HANDLERS["kill"] = submitKill
DIALOG_HANDLERS["close"] = submitKill
DIALOG_FILLS["kill"] = fillKill
DIALOG_FILLS["close"] = fillKill


## What `--manager-session-kill` printed: a `kill` row for each run the id names, with
## what happened to it, then a `dismiss` row for each question and a `close` row for each
## record, and for a whole session the `finish` row that sums them. Given back: a line
## for each row, for the left pane, and for the bottom line the summing row, or, where
## the operation printed none, how many rows had each outcome.
def killAnswer(text):
    rows = parseKillRows(text)
    members = dict((kill["spawn"], kill["member"]) for kill in rows["kill"])
    lines = []
    counts = []

    def said(outcomes, outcome):
        words, counted = outcomes.get(outcome, (outcome, outcome))
        for count in counts:
            if count[0] == counted:
                count[1] += 1
                break
        else:
            counts.append([counted, 1])
        return words

    for kill in rows["kill"]:
        lines.append("  %-18s %s" % (kill["member"], said(KILL_OUTCOMES, kill["outcome"])))
    for dismiss in rows["dismiss"]:
        lines.append("  question %s of %s: %s" % (dismiss["question"], members.get(dismiss["asker"], dismiss["asker"]),
                                                  said(DISMISS_OUTCOMES, dismiss["outcome"])))
    for close in rows["close"]:
        lines.append("  record of %s: %s" % (close["member"], said(CLOSE_OUTCOMES, close["outcome"])))
    if rows["finish"]:
        finish = rows["finish"][-1]
        lines.append("  the session reads %s" % unspaced(finish["state"]))
        return lines, "%s ended, %s dismissed, %s closed: the session reads %s" % (
            finish["ended"], finish["dismissed"], finish["closed"], unspaced(finish["state"]))
    return lines, ", ".join("%d %s" % (count, counted) for counted, count in counts)


## The session `c` acts on at that row, or None where the row is no session: the control
## thread is a session's, so an agent of one, a section and `Launch (Start)` have none.
def controlTargetOf(state, row):
    if row is None or levelPattern(state.path) != pluginLevel("sessions") or not row.get("session"):
        return None
    return row["session"] if row["session"]["id"] not in ("", "-") else None


## Whether the left pane names `c` under that row: a session that is not finished and whose
## control thread does not live, by what the list said of both. The key itself is taken on
## every session: whether a thread is started is the operation's to say.
def controlFits(state, row):
    session = controlTargetOf(state, row)
    return session is not None and session.get("control") in ("gone", "none") and session["state"] != "finished"


## `c`: asks the tooling to start the control thread of the selected session again. No
## confirmation is asked: the operation ends nothing, and starts nothing where a thread
## lives or none is needed. A row that is no session says in a box that there is nothing to
## control there. A start that was asked for and is not answered yet is not asked for a
## second time, and a box says so.
def askControl(state, row):
    session = controlTargetOf(state, row)
    if session is None:
        return tell(state, "Control thread", "c: nothing to control here: c starts the control thread of a session")
    if "action:control:" + session["id"] in state.asked:
        return tell(state, "Control thread", "c: the control thread of this session is asked for already, and its answer has not come")
    askCall(state, "control", session["id"], callWords("control", session["id"]), None)
    return "control thread asked of the tooling: the session %s" % row["label"]


## What each <outcome> of a `control` row means, in words. An outcome that is not listed
## here shows as it is printed.
CONTROL_OUTCOMES = {
    "started": "started",
    "alive": "alive already",
    "not-needed": "not needed",
    "not-started": "not started",
}


## What `--manager-session-control-start` printed: one `control` row for the session, with
## what became of the start. Given back: its words broken to the pane, for the left pane,
## and the same words in one line, for the bottom line: the outcome, the pid of the thread
## that was started or lives already, and the reason the row gives, a TAB of it as a space.
def controlAnswer(text, width):
    lines = []
    said = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "control" or len(fields) < 5:
            continue
        words = CONTROL_OUTCOMES.get(fields[2], fields[2])
        if fields[3] != "-":
            words += ", pid " + fields[3]
        reason = unescaped(fields[4])
        if reason:
            words += ": " + reason
        said.append(" ".join(words.split()))
        lines.extend("  " + part for part in wrapToCells(words, max(10, width - 3)))
    return lines, "control: " + ("; ".join(said) if said else "the operation named no session")


## Enter on a routine of `Launch (Start)`. One the session spawner would not start gets
## the information box: the routine, who executes it, and why it is not started; nothing
## is asked. One that is started only with members named gets the dialog of its members.
## For another its dialog opens: what the session is to work on, and the name the session
## takes from its routine, to be typed over. Start there starts the routine, Cancel and
## Esc start nothing.
def askLaunch(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    if routineAsksMembers(routine):
        state.answer = None
        openDialog(state, "members", {"about": {"lines": [
            ("routine", routine["selector"]),
            ("executors", "any member: the ones checked below start it, in one session"),
            ("session", "coworking: members working together in one session" if routine["session"] == "coworking" else routine["session"]),
        ]}}, {"routine": routine, "viewKey": viewKeyOf(state)})
        return ""
    if routine["start"] != "startable":
        return ""
    state.answer = None
    openDialog(state, "routine", {
        "about": {"lines": [
            ("routine", routine["selector"]),
            ("executors", "%s: it runs as its executors, whoever is at the console" % routine["executors"]),
            "With no name the session shows by its id.",
        ]},
        "name": {"value": routine["name"]},
    }, {"routine": routine, "viewKey": viewKeyOf(state)})
    return ""


## Whether Enter starts the routine of that row: one the session spawner would start, with
## no member named or with the members its dialog asks for.
def launchFits(state, row):
    return bool(row and row.get("routine") and (row["routine"]["start"] == "startable" or routineAsksMembers(row["routine"])))


## Why Enter starts no routine at that row: what the operation says of its start.
def launchRefusal(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    return "%s is not started from here: %s" % (routine["label"], routine["reason"] or routine["start"])


## Whether the routine of that row cannot be started from here: one the session spawner
## would not start, and that is not one its members alone are to be named for.
def unstartedFits(state, row):
    return bool(row and row.get("routine")) and not launchFits(state, row)


## Enter and Right, and a click that opens, on a routine that cannot be started: the
## information dialog, with the routine, who executes it, and why, the reason as the
## operation gives it. Nothing is started and no operation is called.
def askUnstarted(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    return tell(state, "The routine is not started", [
        "%s cannot be started from here." % routine["label"],
        ("routine", routine["selector"]),
        ("owner", routine["owner"]),
        ("executors", routine["executors"] or "none are named"),
        ("start", routine["start"]),
        ("why", routine["reason"] or "the operation says no more"),
    ], "information")


## The members that can be started from here, as the options of a dialog that offers them:
## those of the list of the team that are not refused (memberRefusal), in its order. None
## until that list was read.
def memberOptions(state):
    if pluginLevel("team") not in state.rows:
        return None
    return [(row["member"]["name"], row["member"]["name"]) for row in state.rows[pluginLevel("team")]
            if row.get("member") and not memberRefusal(row["member"])]


## The dialog of a routine's members gets its boxes once the list of the team was read:
## one for each member that can be started from here.
def fillMembers(state, dialog):
    control = dialogControl(dialog, "members")
    options = memberOptions(state)
    if control["options"] or options is None:
        return
    control["options"] = options
    if not options:
        control["empty"] = "no member can be started from here"


## OK in the dialog of a routine's members. With no member checked it is refused there.
## Else the routine is started through the operation, once: ONE session with all the
## members checked, in the order of the list, named after the routine by the operation,
## and what was typed as what the session is to work on goes on its standard input.
def submitMembers(state, dialog, button):
    control = dialogControl(dialog, "members")
    members = [name for name, label in control["options"] if name in control["value"]]
    routine = dialog["about"]["routine"]
    task = dialogValue(dialog, "task").strip()
    askCall(state, "launch", routine["selector"], callWords("launch", routine["selector"]) + members,
            task + "\n" if task else None, {"name": "", "viewKey": dialog["about"]["viewKey"]})
    state.notice = "start asked of the tooling: %s, with %s" % (routine["selector"], ", ".join(members))
    state.noticeOf = None
    return None


DIALOG_FILLS["members"] = fillMembers
DIALOG_HANDLERS["members"] = submitMembers


## Start in the dialog of a routine: the routine is started through the operation, once,
## by its selector, under the name that was left or typed, or under none where it was
## emptied; what was typed as what the session is to work on goes on its standard input,
## and nothing goes there where nothing was typed.
def submitRoutine(state, dialog, button):
    routine = dialog["about"]["routine"]
    name = dialogValue(dialog, "name").strip()
    task = dialogValue(dialog, "task").strip()
    askCall(state, "launch", routine["selector"], callWords("launch", routine["selector"], name),
            task + "\n" if task else None, {"name": name, "viewKey": dialog["about"]["viewKey"]})
    state.notice = "start asked of the tooling: %s, %s" % (routine["selector"], "named " + name if name else "with no name")
    state.noticeOf = None
    return None


## Who a prompt is run by, as the list of its dialog offers it: first what the free prompt
## starts where nobody is named, a new coworking session the coordinator opens by the
## default routine, and after it each member that can be started from here, which is then
## started alone with the prompt, in a session of its own.
PROMPT_DEFAULT = ("", "magic-coordinator: a new coworking session, by the default routine")


## Opens the dialog of a prompt, its list on that member, or on the default where none is
## named, under that title.
def openPrompt(state, who, title):
    state.answer = None
    openDialog(state, "prompt", {
        "about": {"lines": [
            "The prompt is the brief of a new session. It goes to the operation on its standard input.",
            "No secret belongs in it: a brief shows on the command line of the CLI.",
        ]},
        "who": {"options": [PROMPT_DEFAULT] + (memberOptions(state) or []), "value": who},
    }, {"viewKey": viewKeyOf(state), "filled": memberOptions(state) is not None}, title)
    return ""


## The dialog of a prompt gets the members of its list once the list of the team was read.
def fillPrompt(state, dialog):
    options = memberOptions(state)
    if dialog["about"]["filled"] or options is None:
        return
    dialog["about"]["filled"] = True
    dialogControl(dialog, "who")["options"].extend(options)


## Enter on the free prompt of `Launch (Start)`: its dialog opens, who runs it, the prompt,
## and the name of the session.
def askPrompt(state, row):
    return openPrompt(state, "", "Free prompt")


## Start in the dialog of a prompt. An empty prompt never comes here: the prompt is declared
## required, since the operation would start a session on its brief block alone, and the
## engine of the dialogs holds that. The session is started through
## the operation, once, with the prompt on its standard input and no word of it among its
## arguments: by the default routine where the list stands on its first row, as the free
## prompt always was; or the member the list stands on, alone, as `n` starts one.
def submitPrompt(state, dialog, button):
    prompt = dialogValue(dialog, "prompt").rstrip("\n")
    who = dialogValue(dialog, "who")
    name = dialogValue(dialog, "name").strip()
    named = "named " + name if name else "with no name"
    if who:
        askCall(state, "start", who, callWords("start", who, name), prompt + "\n", {"viewKey": dialog["about"]["viewKey"]})
        state.notice = "start asked of the tooling: the member %s, %s" % (who, named)
    else:
        askCall(state, "prompt", "free", callWords("prompt", "", name), prompt + "\n",
                {"name": name, "viewKey": dialog["about"]["viewKey"]})
        state.notice = "start asked of the tooling: a free prompt, %s" % named
    state.noticeOf = None
    return None


DIALOG_HANDLERS["routine"] = submitRoutine
DIALOG_HANDLERS["prompt"] = submitPrompt
DIALOG_FILLS["prompt"] = fillPrompt


## What `--magic-spawn-session` printed: `SESSION_ID=`, `ROUTINE=` and `MEMBERS=`, a line
## each, and ahead of them what it noted. Given back: the lines for the left pane, with
## the name the start was asked under, and one line for the bottom line.
def startAnswer(text, name, width):
    told = {}
    notes = []
    for line in text.splitlines():
        field, equals, value = line.partition("=")
        if equals and field in ("SESSION_ID", "ROUTINE", "MEMBERS"):
            told[field] = value.strip()
        elif line.strip():
            notes.append(line.strip())
    lines = fieldLines([
        ("session", told.get("SESSION_ID", "")),
        ("name", (name or "none: it shows by its id") if told.get("SESSION_ID") else ""),
        ("routine", told.get("ROUTINE", "")),
        ("members", ", ".join(told.get("MEMBERS", "").split())),
    ] + [("note", note) for note in notes], width)
    if told.get("SESSION_ID"):
        return lines, "started: session %s%s" % (told["SESSION_ID"], ", members " + ", ".join(told["MEMBERS"].split()) if told.get("MEMBERS") else "")
    return lines, "the start answered no session id"


ACTION_HANDLERS["kill"] = askKill
ACTION_HANDLERS["control"] = askControl
ACTION_HANDLERS["launch"] = askLaunch
ACTION_HANDLERS["prompt"] = askPrompt
ACTION_HANDLERS["unstarted"] = askUnstarted
ACTION_FITS["kill"] = killFits
ACTION_FITS["control"] = controlFits
ACTION_FITS["launch"] = launchFits
ACTION_FITS["unstarted"] = unstartedFits
ACTION_REFUSALS["kill"] = killRefusal
ACTION_REFUSALS["launch"] = launchRefusal


## ---- the plugin: `Sessions (Activity)` ----

registerPlugin({
    "name": "sessions",
    "root": {"id": "sessions", "label": "Sessions (Activity)", "go": "~S~essions (Activity)", "group": "team"},
    ## The rows a level always holds, ahead of the rows its operation gives.
    "rows": {
        "sessions": (("launch", "Launch (Start)", "launch", True),),
        "sessions/launch": (("free", "Free prompt", "free", False),),
    },
    "summaries": {
        "sessions": {"lines": "sessionsSummary", "counted": ("running", "waiting", "unclosed")},
        "sessions/launch": {"lines": "routinesSummary"},
    },
    "reads": {
        ## The coworking sessions with their runs, and last the row of counters of the status lines.
        "list:sessions": {"operation": ["--manager-session-list"], "active": ["--active"],
                          "rows": "sessions", "kind": "sessions", "always": True},
        ## The routines the members carry, each with whether the session spawner would start it.
        "list:sessions/launch": {"operation": ["--manager-routine-list"], "rows": "routines"},
        ## The agents of one session come with the list of the sessions.
        "list:sessions/*": {"from": "list:sessions"},
        "view:sessions:launch": None,
        ## A session whole, and what its runs did: the lines its tracking thread shows.
        "view:sessions:record": {"operation": ["--manager-session-read", "--session-id", "{id}"],
                                 "rows": "session-read", "needs": "session"},
        "feed:sessions:record": {"operation": ["--manager-session-transcript-read", "--session-id", "{id}"],
                                 "log": ["--log"], "rows": "transcript", "needs": "session"},
        ## One run of a session: --run takes the id as a run's own, the founder's too, whose id is its session's.
        "view:sessions/*:record": {"operation": ["--manager-session-read", "--session-id", "{id}", "--run"],
                                   "rows": "session-read", "needs": "run"},
        "feed:sessions/*:record": {"operation": ["--manager-session-transcript-read", "--session-id", "{id}", "--run"],
                                   "log": ["--log"], "rows": "transcript", "needs": "run"},
        ## What the kill of a session, and of one agent, would do, and nothing is done: the rows
        ## of the kill itself, each with what would become of it (KILL_ROWS). Read when the
        ## confirmation of that kill opens, and once more when it is confirmed (submitKill), by
        ## the id it names, as a kind of its own; never on the period, so what the confirmation
        ## says does not change under the word typed into it.
        "plan:kill:session": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--plan"], "rows": "kill", "kind": "plan", "once": True},
        "plan:kill:run": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--run", "--plan"], "rows": "kill", "kind": "plan", "once": True},
    },
    "go": ({"name": "spawn", "path": "sessions/launch", "label": "~L~aunch (Start)"},),
    "commands": (
        {"name": "unstarted", "keys": ("ENTER",),
         "views": ("sessions/launch",), "for": "a routine that cannot be started", "on": ("sessions/launch:record",), "only": True, "tells": True, "does": ("action", "unstarted")},
        {"name": "launch", "keys": ("ENTER",), "menu": ("session", 2), "label": "Start the ro~u~tine", "status": "Start", "window": "list",
         "views": ("sessions/launch",), "for": "a routine", "on": ("sessions/launch:record",), "only": True, "does": ("action", "launch"), "calls": ("launch",)},
        {"name": "prompt", "keys": ("ENTER",), "menu": ("session", 2), "label": "~F~ree prompt", "status": "Start", "window": "list",
         "views": ("sessions/launch",), "for": "the free prompt", "on": ("sessions/launch:free",), "only": True, "does": ("action", "prompt"), "calls": ("prompt",)},
        {"name": "kill", "keys": ("k",), "menu": ("session", 1), "label": "~K~ill", "status": "Kill", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "kill"), "calls": ("kill:session", "kill:run")},
        {"name": "control", "keys": ("c",), "menu": ("session", 1), "label": "~C~ontrol thread", "status": "Control", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session", "asks": True, "on": ("sessions:record",), "does": ("action", "control"), "calls": ("control",)},
        {"name": "pause", "keys": ("p",), "menu": ("session", 3), "label": "~P~ause", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "pause")},
        {"name": "resume", "keys": ("r",), "menu": ("session", 3), "label": "~R~esume", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "resume")},
        {"name": "stop", "keys": ("s",), "menu": ("session", 3), "label": "~S~top", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "stop")},
        {"name": "restart", "keys": ("R",), "menu": ("session", 3), "label": "Res~t~art", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "restart")},
        {"name": "mode", "keys": ("v",), "menu": ("view", 4), "label": "Ne~x~t mode of the left window", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "")},
        ## the summary and the raw mode are those of a Markdown text too: the places of the Markdown view are added to theirs
        {"name": "mode-summary", "keys": ("b",), "menu": ("view", 4), "label": "Su~m~mary", "status": "Summary", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session, an agent or a Markdown text", "on": ("sessions:record", "sessions/*:record"),
         "with": (("markdown", "on"), ("markdown", "help")), "does": ("mode", "summary")},
        {"name": "mode-log", "keys": ("l",), "menu": ("view", 4), "label": "~L~og", "status": "Log", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "log")},
        {"name": "mode-raw", "keys": ("g",), "menu": ("view", 4), "label": "Ra~w~ log", "status": "Raw log", "after": "colours",
         "views": ("sessions", "sessions/*"), "for": "a session, an agent or a Markdown text", "on": ("sessions:record", "sessions/*:record"),
         "with": (("markdown", "on"), ("markdown", "help")), "does": ("mode", "raw")},
    ),
})
