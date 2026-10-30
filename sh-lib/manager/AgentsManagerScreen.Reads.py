##
## AgentsManagerScreen.Reads.py -- the reads through the operations of the tooling, and their reader.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- reading through operations ----

## The words of one read: its operation, what the filter adds, what `l` adds, and the ids
## in their places. The filter is the list's own: the read that fills the level of one
## session is made without it, so that session stays in what is read whatever its state.
def readWords(entry, state, values, filtered=True):
    words = list(values.get("_operation") or entry["operation"])
    if state.activeOnly and filtered:
        words.extend(entry.get("active", ()))
    if rawShown(state):
        words.extend(entry.get("log", ()))
    ## the words a feature's own switch adds: the name of its function in this namespace, asked of the state
    if entry.get("extra"):
        words.extend(globals()[entry["extra"]](state))
    return [word.replace("{id}", values.get("id", "")).replace("{level}", values.get("level", "")).replace("{parent}", values.get("parent", ""))
            .replace("{session}", values.get("session", "")).replace("{member}", values.get("member", "")).replace("{run}", values.get("run", ""))
            .replace("{routine}", values.get("routine", ""))
            for word in words]


## The values of the words of a read of the level at that path: {level}, its own id, and
## {parent}, the id of the level above it; and where it is the folder of a participant of a
## session or lies in it (its `Permissions`), the session, the member and the run of that
## participant: {session}, {member} and {run} (participantValues).
def pathValues(path, state=None):
    values = {"level": path[-1] if path else "", "parent": path[-2] if len(path) > 1 else ""}
    if state is not None:
        values.update(participantValues(state, path))
    return values


## The entry of READS a read is made by, from its key, or nothing: a read made for a row of
## a level ("each") is named by its entry and, after a `|`, by the id of that row.
def readEntry(key):
    return READS.get(key) or READS.get(key.partition("|")[0]) or {}


## The read that fills the list of a level: its key and its entry in READS, or None. A
## level another read fills ("from") has that read.
def listReadOf(path):
    key = "list:" + levelKey(path)
    entry = READS.get("list:" + levelPattern(path))
    if entry and entry.get("from"):
        key = entry["from"]
        entry = READS.get(key)
    return (key, entry) if entry else None


## The read a command that asks on demand asks for now ("demand" in COMMANDS): its key and
## its entry, or None. The list shown where that is read on demand alone, else the list
## of the folder the selection stands on where that one is.
def demandRead(state):
    shown = listReadOf(state.path)
    if shown and shown[1].get("demand"):
        return shown
    row = selectedRow(state)
    opened = listReadOf(state.path + [row["id"]]) if row is not None and row["dive"] and row["kind"] != "up" else None
    return opened if opened and opened[1].get("demand") else None


## The reads of what the left window shows, its facts and its lines: (kind, key, words).
@onShownLevel
def shownReads(state):
    wanted = []
    row = selectedRow(state)
    values = pathValues(state.path, state)
    for part in VIEW_PARTS:
        entry = viewReadOf(state, row, part)
        if entry and (part != "feed" or modeOf(state)["feed"]):
            values["id"] = row["id"]
            values["routine"] = (row.get("routine") or {}).get("selector", "")
            wanted.append((part, part + ":" + viewKeyOf(state), readWords(entry, state, values)))
    return wanted


## The row the left window shows, and its entry in READS for that part of it, or nothing.
@onShownLevel
def shownRead(state, part):
    row = selectedRow(state)
    return row, viewReadOf(state, row, part) or {}


## What the screen as it stands asks the tooling for: (kind, key, words) for the list of
## the level shown, for every list that is read whatever is shown, for the view of the
## row selected, and for what the open dialog offers, each where READS names an operation;
## and, where `focus` is not put off, for the folder the selection stands on (focusReads).
def wantedReads(state, focus=True):
    wanted = []
    pattern = levelPattern(state.path)
    values = pathValues(state.path, state)
    shown = listReadOf(state.path)
    if shown:
        own = shown[0] == "list:" + levelKey(state.path)
        wanted.append((shown[1].get("kind", "list"), shown[0], readWords(shown[1], state, values, own)))
        for also in (READS.get("list:" + pattern) or {}).get("also", ()):
            wanted.append((READS[also].get("kind", "also"), also, readWords(READS[also], state, {})))
    elif not state.path:
        ## the list of the section the root stands on, where the left window shows that
        ## section from its rows ("peek"): read while it is selected, as while it is opened
        row = selectedRow(state)
        peeked = READS.get("list:" + row["id"]) if row is not None and row["kind"] == "section" else None
        if peeked and peeked.get("peek"):
            wanted.append((peeked.get("kind", "list"), "list:" + row["id"], readWords(peeked, state, {})))
    for key in sorted(READS):
        entry = READS[key]
        if entry and entry.get("always") and not (shown and shown[0] == key):
            wanted.append((entry.get("kind", "list"), key, readWords(entry, state, {})))
        if entry and entry.get("count"):
            ## the count of a list: its operation with --count, which prints only the number, read whatever is shown; kept as the counter of that name
            wanted.append(("count", "count:" + entry["count"], readWords(dict(entry, operation=list(entry["operation"]) + ["--count"]), state, {}, False)))
    wanted.extend(shownReads(state))
    ## every row of the level shown that carries what such a read needs is read by its id
    each = READS.get("each:" + pattern)
    for row in (listedRows(state, state.path) or ()) if each else ():
        if row.get(each["needs"]):
            wanted.append((each.get("kind", "list"), "each:%s|%s" % (pattern, row["id"]),
                           readWords(each, state, {"id": row["id"]}, False)))
    ## what the open dialog offers is read while it is open
    for key, values in dialogReads(state):
        if key not in [wantedKey for kind, wantedKey, words in wanted]:
            wanted.append((READS[key].get("kind", "list"), key, readWords(READS[key], state, values, False)))
    ## the folder the selection stands on is read as it would be on entering it
    for read in focusReads(state) if focus else ():
        if read[1] not in [wantedKey for kind, wantedKey, words in wanted]:
            wanted.append(read)
    return wanted


## The reads of the folder the selection stands on in the list, a row that opens a level
## of its own: (kind, key, words) for the list of that level, in the words it is read by
## when it is entered, and for each of its rows that a read of every row is made for
## ("each"). They are made while the row is selected, so that the left window shows the
## folder from its real rows (SUMMARIES), and run as a kind of their own, "focus", beside
## the list shown: one at a time, so a read under way for a folder that was left holds
## the next one back and never fills another folder, since rows are kept by their level.
def focusReads(state):
    row = selectedRow(state)
    if row is None or not row["dive"] or row["kind"] == "up":
        return []
    path = state.path + [row["id"]]
    opened = listReadOf(path)
    if not opened:
        return []
    wanted = [(opened[1].get("kind", "focus"), opened[0],
               readWords(opened[1], state, pathValues(path, state), opened[0] == "list:" + levelKey(path)))]
    pattern = levelPattern(path)
    for also in (READS.get("list:" + pattern) or {}).get("also", ()):
        wanted.append((READS[also].get("kind", "focus"), also, readWords(READS[also], state, {})))
    each = READS.get("each:" + pattern)
    for held in (listedRows(state, path) or ()) if each else ():
        if held.get(each["needs"]):
            wanted.append((each.get("kind", "focus"), "each:%s|%s" % (pattern, held["id"]),
                           readWords(each, state, {"id": held["id"]}, False)))
    return wanted


## The keys of the reads that are wanted for the focus alone: those wait until the
## selection has rested on its row (restLeft).
def focusOnly(state):
    return (set(key for kind, key, words in wantedReads(state))
            - set(key for kind, key, words in wantedReads(state, False)))


## A read a dialog names, as READS names it: `list:team` is the list of the level of the plugin of that name, wherever it stands
## (`Team Members` stands under `Magic-Team (Agents)`); a read that names no plugin is as it was written.
def dialogReadKey(key):
    kind, colon, rest = key.partition(":")
    level = pluginLevel(rest) if kind == "list" and colon else None
    return kind + colon + level if level else key


## The reads of the open dialog: the key in READS and the values of each entry it names
## that gives an operation. A name that holds {kind} is the entry of the kind of what the
## dialog was opened on, its "target", and is asked by the id of that.
def dialogReads(state):
    if state.dialog is None:
        return []
    target = state.dialog["about"].get("target") or {}
    reads = []
    for name in DIALOGS[state.dialog["name"]].get("reads", ()):
        key = dialogReadKey(name.replace("{kind}", target.get("kind", "")))
        if READS.get(key):
            reads.append((key, {"id": target.get("id", ""), "level": target.get("level", ""), "_operation": target.get("read")} if "{kind}" in name else {}))
    return reads


## The read of a part of the left pane for that row, "view" its facts or "feed" its lines:
## its entry in READS, or None. A row that does not carry what the entry needs has none,
## and neither has a run with no id of its own to ask by, nor a member whose workspace
## cannot be reached, which its read refuses.
def viewReadOf(state, row, part):
    if row is None or row["kind"] == "up":
        return None
    entry = READS.get(part + ":" + levelPattern(state.path) + ":" + row["kind"])
    if not entry or (entry.get("needs") and not row.get(entry["needs"])):
        return None
    if entry.get("participant") and not participantValues(state, state.path):
        ## the read of a participant's own, in the folder of one that is no longer in its session's list
        return None
    if row.get("run") and row["run"]["spawn"] == "-":
        return None
    if row.get("member") and row["member"]["setUp"] == "not-present":
        return None
    return entry


## Whether a read is one that is made seldom and is not the list shown now: such a one
## was read when the screen started, and nothing asks for it again.
def seldomNow(state, key):
    return bool((READS.get(key) or {}).get("seldom")) and key != (listReadOf(state.path) or ("",))[0]


## What is shown is read at the next chance, whatever the period says.
def readNow(state):
    for kind, key, words in wantedReads(state):
        ## one that is read on demand alone is asked for by its own command, not by this;
        ## neither is one that is read seldom, but while it is the list shown
        if not (READS.get(key) or {}).get("demand") and not seldomNow(state, key):
            state.forced.add(key)
    ## a read that decides what stands in the list at all is asked again at each of these: what the user changed, or the refresh, may have changed it
    for key, entry in READS.items():
        if entry and entry.get("recheck"):
            state.forced.add(key)


## How long the selection must still rest on its item before the reads of that one item
## start, and the read of the folder it stands on: 0 once it has rested, and where
## nothing is read of the item. Which item the selection rests on, and since when, is
## noted here.
def restLeft(state, now):
    return restOf(state, now, bool(focusOnly(state)))


@onShownLevel
def restOf(state, now, focused):
    selected = viewKeyOf(state)
    if selected != state.restKey:
        state.restKey = selected
        state.restSince = now
        ## the selection has come to this item anew: the reads of its focus are due again
        state.focusSeen = None
    row = selectedRow(state)
    if not focused and all(viewReadOf(state, row, part) is None for part in VIEW_PARTS):
        return 0.0
    return max(0.0, REST_SECONDS - (now - state.restSince))


## How long the screen waits for a key before its next turn: its turn time, or less where
## the selection rests and the reads of its item are due sooner than that. A screen that has
## heard nothing for a second and has nothing reading turns once a second: a key ends this
## wait at once, so nothing a person does waits on it, and an idle screen costs a fifth.
def keyWait(state, now):
    left = restLeft(state, now)
    if left > 0:
        return min(TURN_SECONDS, left + 0.005)
    if not state.reading and not state.calls and now - state.movedAt >= IDLE_QUIET_SECONDS:
        return IDLE_TURN_SECONDS
    return TURN_SECONDS


## Starts each read that is due and whose kind is free: one never made, one asked for now,
## one whose words have changed, one whose period has passed. Two of one kind never run at
## once: a read that is due while its kind runs waits for the turn after that one ends.
## The reads of one item, its facts and its lines, wait until the selection has rested on
## it (restLeft): a selection that runs down a list starts none of them on its way. So
## does the read of a folder that has the focus and is not shown (focusOnly), and that
## one is made once for each time the selection comes to rest on its row: while the
## selection stays there its period starts it no more.
def startDueReads(state, reader, now):
    resting = restLeft(state, now) > 0
    focused = focusOnly(state)
    came = state.restKey != state.focusSeen
    held = False
    for kind, key, words in wantedReads(state):
        if reader.busy(kind) or (resting and (kind in VIEW_PARTS or key in focused)):
            held = held or key in focused
            continue
        last = state.started.get(key)
        ## a read that is made once is not due again because its period has passed; neither
        ## is one that is read seldom, but while it is the list shown
        once = readEntry(key).get("once") or seldomNow(state, key) or (key in focused and not came)
        ## the period runs from the end of the last read, three times its length where that is longer: a slow read never runs back to back
        took = last["ended"] - last["at"] if last and "ended" in last else 0.0
        aged = now - last.get("ended", last["at"]) >= max(REFRESH_SECONDS, 3 * took) and not once if last else False
        due = key in state.forced or (not (READS.get(key) or {}).get("demand") and (last is None or last["words"] != words or aged))
        if due and reader.start(kind, key, words):
            state.started[key] = {"at": now, "words": words}
            state.forced.discard(key)
    if not resting and not held:
        state.focusSeen = state.restKey


## Starts the action that waits for its start, where none runs: one at a time, in the
## order they were asked for. A request that waits for the answer to it runs apart, as kind
## "escalation", one at a time too, so no other action waits behind it.
def startCalls(state, reader):
    for call in list(state.calls):
        kind = call.get("kind", "action")
        if reader.busy(kind):
            continue
        state.calls.remove(call)
        reader.start(kind, call["key"], call["words"], call["input"])
    ## the operation of the big output dialog: started once, and asked to stop where it was
    follow = state.follow
    if follow is not None and not follow["started"]:
        follow["started"] = reader.follow("follow", follow["key"], follow["words"], follow.get("input"))
    if follow is not None and follow["stop"] == "asked":
        follow["stop"] = "sent" if reader.signal("follow", signal.SIGTERM) else None
    ## the request left pending (the dialog of a request that waits): the tooling call takes SIGUSR1 as that
    if follow is not None and follow["stop"] == "enqueue":
        follow["stop"] = "sent" if reader.signal("follow", signal.SIGUSR1) else None


## The line a failed call is shown by: its first line that says ERROR, else the first line
## it wrote at all.
def firstErrorLine(errorText, outputText, status):
    lines = [line.strip() for line in errorText.splitlines() if line.strip()]
    for line in lines:
        if "ERROR" in line:
            return line
    lines.extend(line.strip() for line in outputText.splitlines() if line.strip())
    if lines:
        return lines[0]
    return "ended with status %d and wrote nothing" % status


## What a failed call wrote, whole, as the paragraphs of a box: the operation with its
## words, and every line it wrote as an error, or the one line it is shown by where it
## wrote none.
def failureLines(result):
    said = [line.strip() for line in result.get("said", "").splitlines() if line.strip()]
    return [("operation", " ".join(result["words"]))] + (said or [result["error"]])


## One call that has ended, taken into the state. A good list becomes the rows of its
## level. A failed call leaves what the last good one gave, marks it as old, and what it
## wrote is shown whole in a box, once while it fails in the same words. An answer for a view that is no longer selected is dropped, and so is one
## asked with other words than are wanted now, which is then asked again. The answer of
## an action goes to applyCall.
def applyResult(state, result):
    key = result["key"]
    if key.startswith("action:"):
        applyCall(state, result)
        return
    if key.startswith("follow:"):
        followResult(state, result)
        return
    wantedNow = dict((wantedKey, words) for kind, wantedKey, words in wantedReads(state))
    if key.partition(":")[0] in VIEW_PARTS and key not in wantedNow:
        return
    if key in wantedNow and wantedNow[key] != result["words"]:
        state.forced.add(key)
        return
    if key.startswith("plan:"):
        ## what a kill would do is its confirmation's own: that says what was read, or that
        ## it could not be, and no box does
        state.plans[key] = {"words": result["words"], "rows": parseKillRows(result["text"]),
                            "error": result["error"] if result["status"] != 0 else ""}
        return
    if (READS.get(key) or {}).get("demand"):
        ## when what is read on demand alone last answered: its folder says it
        state.ran[key] = state.clock
    if (READS.get(key) or {}).get("demand") and state.noticeOf == key:
        ## what was asked for on demand has answered: the status line no longer says it was asked
        state.notice = ""
        state.noticeOf = None
    if readEntry(key).get("rows") == "credential-read":
        ## a credential whole is its form's own: held while that form is open, and dropped where it is not
        if state.dialog is not None and state.dialog["name"] == CREDENTIAL_DIALOG:
            state.plans[key] = {"words": result["words"], "value": result["text"].rstrip("\n"),
                                "error": result["error"] if result["status"] != 0 else ""}
        return
    if readEntry(key).get("rows") in PLAN_FORMS:
        ## what an app feature's form reads, kept as the form of that feature takes it, while a dialog is open
        if state.dialog is not None and state.dialog["name"] in READING_DIALOGS:
            state.plans[key] = {"words": result["words"], "rows": PLAN_FORMS[readEntry(key)["rows"]](result["text"]),
                                "error": result["error"] if result["status"] != 0 else ""}
        return
    if readEntry(key).get("rows") == "key-read":
        ## a key whole is its box's and its view's own: they show what was read, or that it could not be
        state.plans[key] = {"words": result["words"], "rows": parseKeyRead(result["text"]),
                            "error": result["error"] if result["status"] != 0 else ""}
        return
    if result["status"] != 0:
        ## a box says it once: a read that fails again in the same words is marked as old, no more
        if state.failed.get(key) != result["error"]:
            tell(state, "A read failed", failureLines(result))
        state.failed[key] = result["error"]
        return
    if state.failed.pop(key, None) is not None and state.noticeOf == key:
        state.notice = ""
        state.noticeOf = None
    if key.startswith("list:"):
        entry = READS.get(key) or READS.get("list:" + levelPattern(key[len("list:"):].split("/"))) or {}
        levels = parseLevels(key, entry.get("rows"), result["text"])
        for gone in state.levelsOf.pop(key, ()):
            state.rows.pop(gone, None)
        state.rows.update(levels)
        state.levelsOf[key] = list(levels)
        if entry.get("active") and all(word in result["words"] for word in entry["active"]):
            state.activeOf[key[len("list:"):]] = set(row["id"] for row in levels.get(key[len("list:"):], ()))
        state.counters.update(readCounters(entry.get("rows"), result["text"]))
    elif key.startswith("count:"):
        ## a read that counts: the number it printed is the counter of its name; what it printed, if it is no number, leaves the counter as it was
        if result["text"].strip().isdigit():
            state.counters[key[len("count:"):]] = result["text"].strip()
    else:
        state.answered[key] = True
        row, entry = shownRead(state, key[:4])
        if entry.get("rows") == "session-read":
            state.view["info"] = parseSessionRead(result["text"])
        elif entry.get("rows") == "ask":
            state.view["info"] = parseAskStored(result["text"])
        elif entry.get("rows") == "ask-acts":
            state.view["acts"] = parseAskActs(result["text"])
        elif entry.get("rows") == "member-read":
            state.view["info"] = parseMemberRead(result["text"])
        elif entry.get("rows") == "place-read":
            state.view["info"] = parsePlaceRead(result["text"])
        elif entry.get("rows") == "routine-frontmatter":
            state.view["front"] = parseRoutineFrontmatter(result["text"])
        elif entry.get("rows") == "routine-history":
            state.view["info"] = parseRoutineHistory(result["text"])
        elif entry.get("rows") == "subsystem-read":
            state.view["info"] = parseSubsystemRead(result["text"])
        elif entry.get("rows") == "transcript":
            state.view["feed"] = parseTranscriptRead(result["text"])
            buildFeed(state, row)
        else:
            ## a text shown as it is, or rendered where it is Markdown: set out here at once, so a
            ## checklist that has just answered is its lines and not an empty pane -- followSelection
            ## sets it out too, whenever the selection moves.
            state.view["text"] = result["text"]
            viewText(state, row)


## The one part of the screen that calls the tooling. An operation of the dispatcher runs
## as a process of its own, with no input, or with what was typed as its input from a
## file, and its output kept in files, so a call never holds a key and never fills a pipe;
## what it wrote is taken when it has ended. One call of a kind at a time. Every call is
## cut off from the terminal's signals, a session of its own: an interrupt or a quit typed
## at the terminal, for the screen or for a child that has the terminal, ends no call. A
## call that acts is besides not ended with the screen: what was confirmed is carried out
## whole.
class OperationReader:
    ## The kinds of call that act, and so run on when the screen ends.
    LASTING = ("action",)

    def __init__(self, toolsCommand, workspace=""):
        self.toolsCommand = list(toolsCommand)
        self.workspace = workspace
        self.running = {}
        self.ended = []

    ## Where a call's files are kept: the workspace's own scratch folder, .local/agents/scratch,
    ## never the system's temp folder. The workspace is the screen's own, else the one MMDAPP
    ## names; with neither there is no folder, and no call is started.
    def scratch(self):
        root = self.workspace or os.environ.get("MMDAPP", "")
        if not root or not os.path.isdir(root):
            return None
        folder = os.path.join(root, ".local", "agents", "scratch")
        try:
            os.makedirs(folder, exist_ok=True)
        except OSError:
            return None
        return folder

    def busy(self, kind):
        return kind in self.running

    def runningKeys(self):
        return dict((kind, call["key"]) for kind, call in self.running.items())

    def start(self, kind, key, words, inputText=None):
        if kind in self.running:
            return False
        folder = self.scratch()
        if folder is None:
            self.ended.append({"kind": kind, "key": key, "words": list(words), "status": 127, "text": "", "said": "",
                               "error": "could not be started: no workspace to keep its output in (.local/agents/scratch)"})
            return True
        outputFile = tempfile.TemporaryFile(dir=folder)
        errorFile = tempfile.TemporaryFile(dir=folder)
        inputFile = None
        if inputText is not None:
            ## what was typed goes to the operation on its standard input, never as a word of its command
            inputFile = tempfile.TemporaryFile(dir=folder)
            inputFile.write(inputText.encode("utf-8", "replace"))
            inputFile.flush()
            inputFile.seek(0)
        try:
            process = subprocess.Popen(self.toolsCommand + list(words),
                                       stdin=subprocess.DEVNULL if inputFile is None else inputFile,
                                       stdout=outputFile, stderr=errorFile, start_new_session=True)
        except OSError as failure:
            outputFile.close()
            errorFile.close()
            self.ended.append({"kind": kind, "key": key, "words": list(words), "status": 127,
                               "text": "", "said": "", "error": "could not be started: %s" % failure})
            return True
        finally:
            if inputFile is not None:
                inputFile.close()
        self.running[kind] = {"key": key, "words": list(words), "process": process,
                              "output": outputFile, "error": errorFile}
        return True

    def collect(self):
        results = self.ended
        self.ended = []
        for kind in list(self.running):
            call = self.running[kind]
            if "pipe" in call:
                results.extend(self.followed(kind, call))
                continue
            status = call["process"].poll()
            if status is None:
                continue
            del self.running[kind]
            outputText = self.textOf(call["output"])
            errorText = self.textOf(call["error"])
            results.append({"kind": kind, "key": call["key"], "words": call["words"], "status": status,
                            "text": outputText, "said": errorText,
                            "error": firstErrorLine(errorText, outputText, status) if status != 0 else ""})
        return results

    ## A call whose output is followed as it comes (the big output dialog): its standard
    ## output and its standard error go into one pipe, so its lines keep the order they were
    ## written in; at each turn what the pipe holds is taken, and the call is never waited
    ## for. Cut off from the terminal's signals as every call is.
    def follow(self, kind, key, words, inputText=None):
        if kind in self.running:
            return False
        inputFile = None
        if inputText is not None:
            ## what was typed goes to the operation on its standard input, never as a word of its command; kept in a file of the workspace's scratch folder
            folder = self.scratch()
            if folder is None:
                self.ended.append({"kind": kind, "key": key, "words": list(words), "status": 127, "text": "", "said": "", "seconds": 0.0,
                                   "error": "could not be started: no workspace to keep its input in (.local/agents/scratch)"})
                return True
            inputFile = tempfile.TemporaryFile(dir=folder)
            inputFile.write(inputText.encode("utf-8", "replace"))
            inputFile.flush()
            inputFile.seek(0)
        try:
            process = subprocess.Popen(self.toolsCommand + list(words), stdin=subprocess.DEVNULL if inputFile is None else inputFile,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as failure:
            self.ended.append({"kind": kind, "key": key, "words": list(words), "status": 127, "text": "",
                               "said": "", "error": "could not be started: %s" % failure, "seconds": 0.0})
            return True
        finally:
            if inputFile is not None:
                inputFile.close()
        os.set_blocking(process.stdout.fileno(), False)
        self.running[kind] = {"key": key, "words": list(words), "process": process, "pipe": process.stdout,
                              "decoder": codecs.getincrementaldecoder("utf-8")("replace"), "since": time.time(),
                              "output": process.stdout, "error": None}
        return True

    ## What a followed call wrote since the last turn, as a result with its "chunk"; and,
    ## once it has ended, the rest it left in the pipe and a result with its status and how
    ## long it ran. Its end is taken first, so what it wrote before it is all in the pipe.
    def followed(self, kind, call):
        status = call["process"].poll()
        data = []
        for turn in range(16):
            try:
                piece = os.read(call["pipe"].fileno(), 65536)
            except BlockingIOError:
                break
            except OSError:
                piece = b""
            if not piece:
                break
            data.append(piece)
        text = call["decoder"].decode(b"".join(data), final=status is not None)
        results = [{"kind": kind, "key": call["key"], "words": call["words"], "chunk": text}] if text else []
        if status is not None:
            del self.running[kind]
            call["pipe"].close()
            results.append({"kind": kind, "key": call["key"], "words": call["words"], "status": status, "text": "",
                            "said": "", "error": "", "seconds": time.time() - call["since"]})
        return results

    ## A signal to a followed call that runs, to its whole group: the stop of the big output dialog.
    def signal(self, kind, number):
        call = self.running.get(kind)
        if call is None or "pipe" not in call:
            return False
        try:
            os.killpg(call["process"].pid, number)
        except OSError:
            return False
        return True

    def textOf(self, keptFile):
        keptFile.seek(0)
        text = keptFile.read().decode("utf-8", "replace")
        keptFile.close()
        return text

    ## The screen ends: a read still running is ended with it. A call that acts runs on to
    ## its own end: a kill or a start is never left half done.
    def stop(self):
        for kind, call in self.running.items():
            if kind not in self.LASTING:
                try:
                    call["process"].terminate()
                    call["process"].wait(2)
                except subprocess.TimeoutExpired:
                    call["process"].kill()
                except OSError:
                    pass
            for kept in (call["output"], call["error"]):
                if kept is not None:
                    kept.close()
        self.running = {}

