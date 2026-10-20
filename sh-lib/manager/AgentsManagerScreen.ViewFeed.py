##
## AgentsManagerScreen.ViewFeed.py -- a kind of view: a sequence of lines, the feed or the raw log of a session or an agent, read one by one.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- a session and an agent, read one by one: their facts, their feed, their raw log ----

## A free text as an operation writes it, back as it was: a TAB reads `\t`, a line break
## `\n`, a carriage return `\r` and a backslash `\\`. An absent one, `-`, is empty.
def unescaped(value):
    if value == "-":
        return ""
    if "\\" not in value:
        return value
    out = []
    position = 0
    while position < len(value):
        character = value[position]
        if character == "\\" and position + 1 < len(value):
            out.append({"t": "\t", "n": "\n", "r": "\r", "\\": "\\"}.get(value[position + 1], "\\" + value[position + 1]))
            position += 2
        else:
            out.append(character)
            position += 1
    return "".join(out)


## A count for the eye: 414, 308K, 42.8M.
def shortCount(value):
    if not value.isdigit():
        return value
    number = int(value)
    if number >= 1000000:
        return "%.1fM" % (number / 1000000.0)
    if number >= 1000:
        return "%dK" % int(number / 1000.0 + 0.5)
    return str(number)


## A moment as the operations write it (2026-10-13T00:54:53Z), in seconds, or None.
def isoEpoch(value):
    try:
        return datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).timestamp()
    except ValueError:
        return None


## What `--manager-session-read` printed: rows of TAB-separated fields, the first naming
## the row. `dispatch` is what the session was started for; a `run` row is followed by the
## `header` rows of its record and by its `store` row. The `session` row is the list's own.
## `control` is the control thread of the session: the state it stored and when, whether it
## lives, and its pid. A read of before prints no such row, and leaves it None. `tokens` is
## the total of the session: the four figures over its runs, how many runs are summed and
## how many of them run, `final` or `so-far`, and how many runs are left out of it.
STORE_NAMES = ("store", "model", "in", "cacheRead", "cacheWrite", "out", "asks", "marks",
               "milestoneAt", "milestone", "waits", "dismissedBy", "log", "transcript")


def parseSessionRead(text):
    info = {"dispatch": None, "control": None, "tokens": None, "runs": [], "bySpawn": {}}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "dispatch" and len(fields) >= 9:
            info["dispatch"] = {"founder": fields[2], "member": unspaced(fields[3]), "routine": unspaced(fields[4]),
                                "item": unspaced(fields[5]), "sessionThread": unspaced(fields[6]),
                                "trackingThread": unspaced(fields[7]), "description": unescaped(fields[8])}
        elif fields[0] == "tokens" and len(fields) >= 10:
            info["tokens"] = dict(zip(("in", "cacheRead", "cacheWrite", "out", "summed", "running", "total", "unknown"), fields[2:10]))
        elif fields[0] == "control" and len(fields) >= 6:
            info["control"] = {"stored": fields[2], "storedAt": fields[3], "control": fields[4], "pid": fields[5]}
        elif fields[0] == "run" and len(fields) >= 12:
            run = {"session": fields[1], "spawn": fields[2], "member": fields[3], "status": fields[4],
                   "live": fields[5], "state": fields[6], "started": fields[7], "resolved": fields[8],
                   "host": fields[9], "workspace": fields[10], "activity": fields[11], "headers": {}, "store": None}
            info["runs"].append(run)
            info["bySpawn"][fields[2]] = run
        elif fields[0] == "header" and len(fields) >= 4 and fields[1] in info["bySpawn"]:
            info["bySpawn"][fields[1]]["headers"][fields[2]] = unescaped(fields[3])
        elif fields[0] == "store" and len(fields) >= 16 and fields[1] in info["bySpawn"]:
            store = dict(zip(STORE_NAMES, fields[2:16]))
            for name in ("milestone", "waits", "dismissedBy", "log", "transcript"):
                store[name] = unescaped(store[name])
            info["bySpawn"][fields[1]]["store"] = store
    return info


## What `--manager-session-transcript-read` printed: a `source` row for each run, where its
## lines are read from; `log` rows, the lines of a session log, run by run; `feed` rows,
## one operation each as the tracking thread shows it, all runs together by their times.
def parseTranscriptRead(text):
    feed = {"sources": [], "logs": [], "rows": []}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "source" and len(fields) >= 5:
            feed["sources"].append({"spawn": fields[1], "member": fields[2], "kind": fields[3], "path": unescaped(fields[4])})
        elif fields[0] == "log" and len(fields) >= 4:
            feed["logs"].append({"spawn": fields[1], "member": fields[2], "text": unescaped(fields[3])})
        elif fields[0] == "feed" and len(fields) >= 7:
            feed["rows"].append({"time": fields[1], "spawn": fields[2], "member": fields[3], "subject": fields[4],
                                 "regarding": fields[5], "text": fields[6]})
    return feed


## Where the lines of the pane come from, in words: its last head line. A run with no
## transcript gives its session log in its place, and the line says which of the two it is.
def sourceText(state, row):
    feed = state.view["feed"]
    what = "the raw log" if rawShown(state) else "the feed"
    if feed is None:
        return what + ", not read yet"
    kinds = {}
    for source in feed["sources"]:
        kinds.setdefault(source["kind"], []).append(source["member"])
    if row.get("run") or row["kind"] == "transcript":
        kind = feed["sources"][0]["kind"] if feed["sources"] else "none"
        if kind == "transcript":
            return "the feed, from its transcript"
        if kind == "session-log":
            return "the raw log, its session log" if rawShown(state) else "its session log: this run has no transcript"
        return "none: this run has no session log" if rawShown(state) else "none: this run has neither a transcript nor a session log"
    told = []
    if kinds.get("transcript"):
        told.append("%d from a transcript" % len(kinds["transcript"]))
    if kinds.get("session-log") and not rawShown(state):
        told.append("%d from a session log, having no transcript (%s)" % (len(kinds["session-log"]), ", ".join(kinds["session-log"])))
    if kinds.get("none"):
        told.append("%d with %s (%s)" % (len(kinds["none"]), "no session log" if rawShown(state) else "neither", ", ".join(kinds["none"])))
    return "%s of %d run%s%s" % ("the raw logs" if rawShown(state) else "the feed", len(feed["sources"]),
                                "" if len(feed["sources"]) == 1 else "s", ": " + ", ".join(told) if told else "")


## The lines of the feed as the pane shows them, and for each the entry it belongs to.
## First the lines of the session logs, run by run, each run under a line that names it
## where there are several; then the feed, the newest last, an entry a head line and its
## body. The head is the time of day here and the member, both as the row gives them,
## ended by a colon: its key says "head", and it is drawn paler (LINE_LOOKS). The body is
## the text with its emoji on the lines after it, set in by the width of the time and one
## blank, so every body starts in the same column; a long one is broken at words and
## keeps that indent. Every entry has its own head, also where the same member spoke in
## the same minute just before: the time of an entry is to the second, and none is left
## out. A line with the date stands where the day changes.
def feedLines(feed, width):
    room = max(10, width - 1)
    lines = []
    keys = []
    several = len(feed["sources"]) > 1
    named = None
    for entry in feed["logs"]:
        if several and entry["spawn"] != named:
            named = entry["spawn"]
            lines.append("%s %s, its session log:" % (entry["member"], entry["spawn"][:8]))
            keys.append(("run", entry["spawn"]))
        text = entry["text"].expandtabs(4)
        indent = min(len(text) - len(text.lstrip(" ")), room // 2)
        parts = wrapToCells(text, max(10, room - indent - 2))
        key = ("log", entry["spawn"], entry["text"])
        lines.append(" " * indent + parts[0])
        keys.append(key)
        for more in parts[1:]:
            lines.append(" " * (indent + 2) + more)
            keys.append(key)
    day = None
    for entry in feed["rows"]:
        moment = isoEpoch(entry["time"])
        stamp = time.localtime(moment) if moment is not None else None
        entryDay = time.strftime("%Y-%m-%d", stamp) if stamp else ""
        if entryDay != day:
            day = entryDay
            if entryDay:
                lines.append(entryDay)
                keys.append(("day", entryDay))
        said = time.strftime("%H:%M:%S", stamp) if stamp else entry["time"]
        indent = textWidth(said) + 1
        key = ("feed", entry["time"], entry["spawn"], entry["text"])
        lines.append(said + (" " + entry["member"] if entry["member"] not in ("", "-") else "") + ":")
        keys.append(("head",) + key[1:])
        for part in wrapToCells(entry["text"], max(10, room - indent)):
            lines.append(" " * indent + part)
            keys.append(key)
    return lines, keys


## The lines of the pane are set out from its feed, at the width the pane has now. A pane
## that was scrolled up stays on the entry that stood at its top, wherever that now is.
## Its lines are drawn in the looks of what they are (lineLook): none that the summary of
## the item carried stays on them.
@onShownLevel
def buildFeed(state, row):
    view = state.view
    held = view["lineKeys"][view["top"]] if not view["follow"] and view["top"] < len(view["lineKeys"]) else None
    view["lines"], view["lineKeys"] = feedLines(view["feed"], state.viewWidth)
    view["looks"] = {}
    view["built"] = (state.viewWidth, state.viewMode)
    if held is not None:
        places = [position for position, key in enumerate(view["lineKeys"]) if key == held]
        if places:
            view["top"] = min(places, key=lambda position: abs(position - view["top"]))


## The look of the line of the left window at that place: of what it is in a log
## (LINE_LOOKS), else the plain one.
def lineLook(view, position):
    keys = view["lineKeys"]
    return LINE_LOOKS.get(keys[position][0], PLAIN) if position < len(keys) else PLAIN


## The mode of the left window now, its entry of VIEW_MODES; whether it shows the raw log;
## and whether it shows the lines of that row, which only a row with a log has.
def modeOf(state):
    return dict(VIEW_MODES)[state.viewMode]


def rawShown(state):
    return modeOf(state)["raw"]


## Whether a Markdown text or the help is shown as it is, in the mode of a text (TEXT_MODE_FIRST);
## and the mode of the left window for the row selected: that of a text where it shows one.
def textRawShown(state):
    return state.textMode == "raw"


@onShownLevel
def modeNow(state):
    return state.textMode if markdownShown(state, selectedRow(state)) else state.viewMode


def logShown(state, row):
    return modeOf(state)["feed"] and viewReadOf(state, row, "feed") is not None


## The left window goes to that mode: what it showed is taken away, it starts at its top,
## or at its end where it shows a log, and the lines of a log are read; the facts of the
## item are kept as they were read, and nothing else is asked for.
def setViewMode(state, name):
    if name == state.viewMode:
        return
    state.viewMode = name
    view = state.view
    view["feed"], view["lines"], view["lineKeys"], view["top"], view["built"] = None, [], [], 0, None
    view["feeds"] = view["follow"] = modeOf(state)["feed"]
    if view["feeds"] and view["key"] is not None:
        state.forced.add("feed:" + view["key"])

