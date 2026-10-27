##
## AgentsManagerScreen.Pending.py -- the root Pending Questions: the asks that wait, and to answer, reject, dismiss and link them.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the asks that wait for an answer ----

## The mark of each kind of ask: the one its own post carries (sh-lib/templates/).
ASK_KIND_MARKS = {
    "question": "❓",
    "readback": "🔁",
    "decision": "🧭",
    "permission": "🔐",
    "permission-set": "🔐",
    "proposal": "📜",
    "review": "🔎",
    "change": "✏️",
}
## What `asker-live:` says where the run that asked is known to be gone, and the mark of
## such a row.
ASKER_GONE = ("no-process", "session-ended")
MARK_GONE = "x"
## What each value of `asker-live:` means, after the help of the operation that prints it.
ASKER_WORDS = {
    "running": "a process of this host runs as it",
    "no-process": "nothing runs as it, so nobody is there to take the answer",
    "session-ended": "its session has ended",
    "no-spawn-record": "a session no spawn started, with no end recorded: not measured",
    "other-host": "asked on another host",
    "host-unrecorded": "the record does not say on which host it was asked",
    "no-session-id": "the record does not say which run asked",
    "not-measured": "this read measured nothing for it",
}
## The fields of an ask the left pane sets out itself. Any other field the read prints is
## shown under its own name.
ASK_FIELDS_SET_OUT = ("status", "owner", "kind", "question-tag", "channel", "question-ts", "thread-ts",
                      "address-to", "session-id", "item", "asked-at", "asker-live", "question")


## The time now, in seconds: what an age is counted from.
def nowEpoch():
    return time.time()


## When an ask was asked, in seconds, from its `asked-at:` (2026-10-01 14:01 +0300), or None.
def askedEpoch(values):
    try:
        return datetime.datetime.strptime(values.get("asked-at", ""), "%Y-%m-%d %H:%M %z").timestamp()
    except ValueError:
        return None


## How long ago, short: minutes below an hour, hours below two days, then days.
def ageText(asked, now):
    if asked is None:
        return ""
    seconds = max(0, int(now - asked))
    if seconds < 3600:
        return "%dm" % (seconds // 60)
    if seconds < 2 * 86400:
        return "%dh" % (seconds // 3600)
    return "%dd" % (seconds // 86400)


## What `--read-pending-reply <member> --any-owner` printed, as rows. A record starts
## with `PENDING-REPLY: <id>`, holds `<field>: <value>` lines and ends with an empty line;
## the list ends with `PENDING-REPLIES: <count>`. A row shows the mark of an asker that is
## gone, how long ago it was asked, the mark of its kind, who asks, of whom, and the first
## line of the question. The newest ask comes first.
def parsePendingRows(text):
    asks = []
    ask = None
    for line in text.splitlines():
        if line.startswith("PENDING-REPLY: "):
            ask = {"id": line[len("PENDING-REPLY: "):].strip(), "fields": [], "values": {}}
            asks.append(ask)
        elif not line.strip() or line.startswith("PENDING-REPLIES:"):
            ask = None
        elif ask is not None and ":" in line:
            name, colon, value = line.partition(":")
            ask["fields"].append((name, value.strip()))
            ask["values"].setdefault(name, value.strip())
    now = nowEpoch()
    asks.sort(key=lambda one: -(askedEpoch(one["values"]) or 0))
    rows = []
    for ask in asks:
        values = ask["values"]
        label = "%s%4s %s %s > %s  %s" % (
            MARK_GONE if values.get("asker-live") in ASKER_GONE else " ",
            ageText(askedEpoch(values), now),
            ASK_KIND_MARKS.get(values.get("kind"), "  "),
            values.get("owner", "-"), values.get("address-to", "-"), values.get("question", ""))
        row = newRow(ask["id"], label, "record", False, [value for name, value in ask["fields"]])
        row["ask"] = ask
        rows.append(row)
    return rows


## The counters a read carries, for the status lines: the last row of the list of the
## sessions, `counters` and then the sessions running and paused, the agents working and
## waiting, the asks that wait, the load average of the host and last the name of that
## host, each as it is printed. A row of an earlier form ends before the name.
COUNTER_NAMES = ("running", "paused", "working", "waiting", "pending", "load", "host")


def readCounters(form, text):
    if form != "sessions":
        return {}
    for line in reversed(text.splitlines()):
        fields = line.split("\t")
        if fields[0] == "counters":
            return dict(zip(COUNTER_NAMES, fields[1:]))
    return {}


## A question's text as the left pane shows it: Markdown rendered by catMarkdown
## (markdownLines), each line with the looks catMarkdown gives its parts, or the text as it
## is where Markdown cannot be rendered. Nothing of the source is shown where it can be
## drawn (the sketch's 14.3, the Question form).
def questionLines(texts, width):
    text = "\n".join(texts) if not isinstance(texts, str) else texts
    lines, spans = markdownLines(text, width)
    return [lookedAt(line, spans.get(number)) for number, line in enumerate(lines)]


## The selected ask, whole, for the left pane: its kind and how long it waits as its head;
## its question first, as far as the read of the list prints it, which is its first line;
## then as facts who asks and of whom, since when, whether its asker is alive, in its
## colour, its status and its item, the other fields of its row, and its id last. Where it
## was posted and the asking session are left out: they tell nobody anything here. The
## read prints no option of a decision and no entry of a permission set: once an operation
## prints them they show here, under their own names. Its keys answer it from here (askAnswer).
## The read of that one ask by its id gives what the stores hold of it: once it has come,
## the whole question, its options, its entries, its fields and its diff stand in the
## place of the first line (storedLines).
def askLines(ask, width, stored=None):
    values = ask["values"]
    kind = values.get("kind", "")
    age = ageText(askedEpoch(values), nowEpoch())
    lines = [looked(" ".join(word for word in (ASK_KIND_MARKS.get(kind, ""), kind or "ask", values.get("question-tag", ""),
                                               "waits " + age if age else "") if word), BOLD), ""]
    if stored and stored["id"] == ask["id"] and stored["stored"]:
        lines.extend(storedLines(stored["stored"], width))
    else:
        lines.append(looked("question, its first line:", TABLE_LOOKS["heading"]))
        lines.extend(questionLines(values.get("question", ""), width))
    live = values.get("asker-live", "")
    lines.append("")
    lines.extend(factLines([
        ("asked by", values.get("owner", "")),
        ("asked of", values.get("address-to", "")),
        ("asked at", values.get("asked-at", "") + (" (%s ago)" % age if age else "")),
        ("asker", live + (": " + ASKER_WORDS[live] if live in ASKER_WORDS else ""), stateLook(live)),
        ("status", values.get("status", "")),
        ("item", values.get("item", "")),
    ] + [(name, value) for name, value in ask["fields"] if name not in ASK_FIELDS_SET_OUT] + [("ask", ask["id"])], width))
    return lines


## What `--read-pending-reply <member> <id>` printed of the stores of one ask: the
## lines from `PENDING-REPLY-STORED: <id>` to the empty line, each `<name>: <text>`. A text
## of several lines repeats its name, and a name that lists things has one a line: both
## are kept as the lines of that name, in their order. None where it printed no such part.
def parseAskStored(text):
    stored = None
    askId = ""
    for line in text.split("\n"):
        if stored is None:
            if line.startswith("PENDING-REPLY-STORED: "):
                askId = line.partition(": ")[2].strip()
                stored = []
            continue
        if not line.strip():
            break
        name, colon, value = line.partition(":")
        value = value[1:] if value.startswith(" ") else value
        if stored and stored[-1][0] == name:
            stored[-1][1].append(value)
        else:
            stored.append((name, [value]))
    return None if stored is None else {"id": askId, "stored": stored}


## What the stores hold of an ask, set out for the left pane, each part only where it is
## held. First the question whole: what its post was filled with, or, for an ask made
## before that was kept, the post itself. Then its options, numbered as they were asked;
## what else the post was filled with, each under the name of its slot; the entries of a
## permission set, numbered, and its own fields; the refused call of a permission; a held
## change, its diff last and as it is; what its thread added; how it was first asked; a
## verdict noted; and the post itself where it was not the question above. The other
## fields of its record are left out: the facts under it say what of them matters.
def storedLines(stored, width):
    room = max(10, width - 1)
    lines = []
    held = {}
    for name, texts in stored:
        held.setdefault(name, []).extend(texts)

    def block(title, texts, numbered=False, exact=False, rendered=False):
        if lines and lines[-1] != "":
            lines.append("")
        lines.append(looked(title + ":", TABLE_LOOKS["heading"]))
        if rendered:
            lines.extend(questionLines(texts, room))
            return
        for number, text in enumerate(texts, 1):
            if exact:
                lines.append(text.expandtabs(4))
            elif numbered:
                parts = wrapToCells(text, max(10, room - 4))
                lines.append("%2d. %s" % (number, parts[0]))
                lines.extend("    " + part for part in parts[1:])
            else:
                lines.extend(wrapToCells(text, room))

    def part(name, texts):
        if len(texts) != 1:
            block(name, texts)
            return
        parts = wrapToCells(texts[0], max(10, room - len(name) - 1))
        lines.append("%s %s" % (name, parts[0]))
        lines.extend(" " * (len(name) + 1) + more for more in parts[1:])

    def parts(prefix, shown, skip=()):
        for name, texts in stored:
            if name.startswith(prefix) and name not in skip:
                part(shown + name[len(prefix):], texts)

    if "field-question" in held:
        block("question", held["field-question"], rendered=True)
    elif "posted" in held:
        block("question, as posted", held["posted"], rendered=True)
    if "option" in held:
        block("options", held["option"], numbered=True)
    if lines:
        lines.append("")
    parts("field-", "", ("field-question",))
    if "set-entry" in held:
        block("entries", held["set-entry"], numbered=True)
    parts("set-", "", ("set-entry",))
    parts("refused-", "refused ")
    parts("change-", "change ", ("change-diff",))
    if "change-diff" in held:
        block("the diff", held["change-diff"], exact=True)
    if "clarification" in held:
        block("added in its thread", held["clarification"])
    if "first-option" in held:
        block("options as first asked", held["first-option"], numbered=True)
    parts("first-field-", "first ")
    parts("answer-noted-", "answer noted ")
    if "field-question" in held and "posted" in held:
        block("as posted", held["posted"], rendered=True)
    return lines


## What `Pending Questions` holds, for the left pane while the section itself or the row
## that goes up is selected: as its caption how many wait, for whom, the most first, how
## long the oldest waits, and how many have no asker any more; then every ask of the list,
## in its order, as a table (tableSummaryLines): how long it waits, the mark and the word
## of its kind, who asks, in the colour of a gone asker where it is gone, of whom, and its
## question. None until its read has answered.
def pendingSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    asks = [held["ask"]["values"] for held in rows if held.get("ask")]
    if not asks:
        return [looked("Nothing waits for an answer.", BOLD)]
    now = nowEpoch()
    return tableSummaryLines(state, ("AGE", "KIND", "FROM", "TO", "QUESTION"), [
        [ageText(askedEpoch(values), now) or "-", values.get("kind", "-"), values.get("owner", "-"), values.get("address-to", "-"),
         values.get("question", "") or "-"] for values in asks], ("text", "enum", "text", "text", "key"),
        icons=[ASK_KIND_MARKS.get(values.get("kind"), "") for values in asks],
        looks=[[None, None, stateLook(MARK_GONE) if values.get("asker-live") in ASKER_GONE else None, None, None] for values in asks])


## ---- the pending questions: answer, reject, dismiss, link ----

## The fields of the `question` row of `--manager-pending-reply-read --id`, after its first.
## "text": whether it takes words; "reject": the word a reject gives; "dismiss": whether it
## can be dismissed; "link": the link of its message. An absent one is `-`.
ASK_ACT_FIELDS = ("id", "status", "kind", "form", "asker", "addressee", "standsAs", "text", "reject", "dismiss", "link")
## What that row says where the question can be dismissed.
ASK_ACT_YES = "yes"
## The form of a question that takes several of its answers, as the `question` row of its read says it.
ASK_FORM_MANY = "many"
## What each <outcome> of an `answer` row shows as, beside the answer. One that is not
## listed here shows as it is printed.
ASK_OUTCOMES = {
    "settles": "settles it",
    "up-the-chain": "goes up the chain, it stays open",
    "not-taken": "not taken from the console",
}
## What each act on a question is called where its answer is told.
ASK_ACT_WORDS = {"answer": "the answer", "reject": "the reject", "dismiss": "the dismissal"}
## The row each of them prints, by its first field: the names of the fields after the id,
## and what the status line says of it.
ASK_ACT_ROWS = {
    "answered": (("verdict", "as", "by", "words"), "answered: %(verdict)s, as %(as)s"),
    "rejected": (("verdict", "as", "by", "words"), "rejected: %(verdict)s, as %(as)s"),
    "up-the-chain": (("asked of", "as", "by", "why"), "up the chain, still open: now asked of %(asked of)s"),
    "dismissed": (("by", "reason"), "dismissed by %(by)s"),
}


## What `--manager-pending-reply-read --id <id>` printed: the row of the question, by the
## names of ASK_ACT_FIELDS, and its answers, each with its number, its word, its outcome
## and its label, an absent one empty.
def parseAskActs(text):
    acts = {"id": "", "question": None, "answers": []}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "question" and len(fields) > len(ASK_ACT_FIELDS):
            acts["question"] = dict(zip(ASK_ACT_FIELDS, fields[1:]))
            acts["id"] = fields[1]
        elif fields[0] == "answer" and len(fields) >= 5:
            acts["answers"].append({"number": absent(fields[1]), "word": fields[2], "outcome": fields[3], "label": absent(fields[4])})
    return acts


## What can be done with the ask of that row, as it was read for it, or None: while it is
## not read, and on a row that is no ask.
def askActsOf(state, row):
    acts = state.view.get("acts")
    if row is None or not row.get("ask") or not acts or acts["id"] != row["id"] or not acts["question"]:
        return None
    return acts


## Whether each act applies to the ask of that row, as its row of the read says.
def answerFits(state, row):
    acts = askActsOf(state, row)
    return acts is not None and bool(absent(acts["question"]["text"]))


def rejectFits(state, row):
    acts = askActsOf(state, row)
    return acts is not None and bool(absent(acts["question"]["reject"]))


def dismissFits(state, row):
    acts = askActsOf(state, row)
    return acts is not None and acts["question"]["dismiss"] == ASK_ACT_YES


def linkFits(state, row):
    acts = askActsOf(state, row)
    return acts is not None and bool(absent(acts["question"]["link"]))


## Why an act does not apply to the ask of that row: it is not read yet, or its row of
## the read says that it takes none.
def askRefusal(state, row, words):
    acts = askActsOf(state, row)
    if acts is None:
        return askUnread(state, row)
    return words % acts["question"]


## What the status line says of a key of an ask pressed before the ask was read; on a row
## that is no ask the key says nothing and does nothing.
def askUnread(state, row):
    if row is None or not row.get("ask"):
        return ""
    return "what can be done with this question is still being read"


## What a dialog of an ask says of it: who asked and of whom, its kind, whose word an
## answer from here is, and the question as it was posted, whole once the read of the ask
## has come, until then its first line.
ASK_DIALOG_WIDTH = 72


def askSays(state, row, acts):
    question = acts["question"]
    lines = [pair for pair in (
        ("asked by", question["asker"]), ("asked of", question["addressee"]),
        ("kind", " ".join(word for word in (question["kind"], absent(question["form"])) if word)),
        ("answer as", question["standsAs"])) if pair[1]]
    stored = state.view["info"]
    held = {}
    if isinstance(stored, dict) and stored.get("id") == row["id"]:
        for name, texts in stored.get("stored") or ():
            held.setdefault(name, []).extend(texts)
    asked = held.get("field-question") or held.get("posted") or [row["ask"]["values"].get("question", "")]
    ## the question is Markdown: it is shown rendered (catMarkdown, through markdownLines), not as its source; the dialog sets its lines to its own width and scrolls them
    rendered, spans = markdownLines("\n".join(asked), ASK_DIALOG_WIDTH)
    return lines + [" "] + [text if text.strip() else " " for text in rendered]


## What an answer shows as in the list of its dialog: its number where it has one, its
## word, its label, and what it does.
def answerOption(answer):
    return (answer["number"] or answer["word"],
            "%s%s%s  --  %s" % (answer["number"] + ". " if answer["number"] else "", answer["word"],
                                ": " + answer["label"] if answer["label"] else "",
                                ASK_OUTCOMES.get(answer["outcome"], answer["outcome"])))


## Enter, `y`: the dialog of the answer to the selected question. One with answers of its
## own offers them, each with what it does, and takes words to go with the one picked; a
## plain question takes the words that are its answer.
def askAnswer(state, row):
    acts = askActsOf(state, row)
    if acts is None:
        return askUnread(state, row)
    question = acts["question"]
    if not absent(question["text"]):
        return ""
    state.answer = None
    fill = {"about": {"lines": askSays(state, row, acts)}}
    if acts["answers"]:
        fill["answers"] = {"options": [answerOption(answer) for answer in acts["answers"]]}
    openDialog(state, ("answer-many" if question["form"] == ASK_FORM_MANY else "answer") if acts["answers"] else "reply", fill,
               {"id": row["id"], "viewKey": viewKeyOf(state), "kind": question["kind"], "asker": question["asker"],
                "words": dict((answer["number"] or answer["word"], answer["word"]) for answer in acts["answers"])},
               "Answer the %s of %s" % (question["kind"], question["asker"]))
    return ""


## The answers that approve, of the kinds whose approval is asked once more before it is given
## (F6.10): an allow of a permission, and the yes of a confirmation (a readback).
APPROVING_KINDS = ("permission", "permission-set", "readback")
APPROVING_ANSWERS = ("allow", "allow-once", "allow-session", "allow-task", "allow-folder", "allow-project", "allow-set", "yes", "correct")


## Answer in the dialog of an answer: the operation is called once, with the answer picked,
## by its number where it has one, and the words typed beside it; or, for a question that
## takes several, with the numbers of those checked, in their order, as one reply names them;
## or, for a plain question, with the words typed, which are refused there while they are empty.
def submitAnswer(state, dialog, button):
    askId = dialog["about"]["id"]
    words = dialogValue(dialog, "words").strip()
    chosen = dialogValue(dialog, "answers")
    if dialog["name"] == "answer-many":
        chosen = " ".join(optionId for optionId, label in dialogControl(dialog, "answers")["options"] if optionId in chosen)
    if dialog["name"] == "reply":
        call = callWords("answer", askId) + [words]
    else:
        call = callWords("answer", askId) + [chosen] + ([CALL_WORDS["answer"], words] if words else [])
        ## An approving answer is asked once more, in a confirmation, and only its OK gives it.
        picked = dialog["about"].get("words", {}).get(chosen, chosen)
        if dialog["about"].get("kind") in APPROVING_KINDS and picked in APPROVING_ANSWERS:
            openDialog(state, "confirm", {"about": {"lines": [
                "CONFIRM the answer `%s` to the %s of %s: it is given only once you press OK." % (picked, dialog["about"]["kind"], dialog["about"].get("asker", "")),
                " ", "Cancel gives nothing, and the question stays open."]}},
                {"id": askId, "viewKey": dialog["about"]["viewKey"], "call": call},
                "Confirm the answer `%s`" % picked)
            return None
    askCall(state, "answer", askId, call, None, {"viewKey": dialog["about"]["viewKey"]})
    state.notice = "answer asked of the tooling"
    state.noticeOf = None
    return None


## OK in the confirmation of an approving answer: the answer operation is called once, as the
## answer dialog would have called it.
def submitConfirm(state, dialog, button):
    askCall(state, "answer", dialog["about"]["id"], dialog["about"]["call"], None, {"viewKey": dialog["about"]["viewKey"]})
    state.notice = "answer asked of the tooling"
    state.noticeOf = None
    return None


## `j` and `d`: the confirmation of the reject, and of the dismissal, of the selected
## question, each only where the row of the question says that it takes one.
def askReject(state, row):
    acts = askActsOf(state, row)
    if acts is None:
        return askUnread(state, row)
    question = acts["question"]
    if not absent(question["reject"]):
        return ""
    state.answer = None
    openDialog(state, "reject", {"about": {"lines": [
        "REJECT the %s of %s: it is answered `%s`, as %s." % (question["kind"], question["asker"], question["reject"], question["standsAs"]),
        " ", row["ask"]["values"].get("question", "")]}}, {"id": row["id"], "viewKey": viewKeyOf(state)},
        "Reject the %s of %s" % (question["kind"], question["asker"]))
    return ""


def askDismiss(state, row):
    acts = askActsOf(state, row)
    if acts is None:
        return askUnread(state, row)
    question = acts["question"]
    if question["dismiss"] != ASK_ACT_YES:
        return ""
    state.answer = None
    openDialog(state, "dismiss", {"about": {"lines": [
        "DISMISS the %s of %s: it is withdrawn, and nothing is answered, granted or decided." % (question["kind"], question["asker"]),
        " ", row["ask"]["values"].get("question", "")]}}, {"id": row["id"], "viewKey": viewKeyOf(state)},
        "Dismiss the %s of %s" % (question["kind"], question["asker"]))
    return ""


## Reject, and Dismiss, in its confirmation: the operation is called once, by the id of
## the question, with the words typed where any were.
def submitAskAct(state, dialog, button):
    askId = dialog["about"]["id"]
    words = dialogValue(dialog, "words").strip()
    askCall(state, dialog["name"], askId, callWords(dialog["name"], askId) + ([CALL_WORDS[dialog["name"]], words] if words else []),
            None, {"viewKey": dialog["about"]["viewKey"]})
    state.notice = "%s asked of the tooling" % dialog["name"]
    state.noticeOf = None
    return None


## `o`: the link of the message of the selected question, in a box.
def askLink(state, row):
    acts = askActsOf(state, row)
    if acts is None:
        return askUnread(state, row)
    question = acts["question"]
    if not absent(question["link"]):
        return ""
    return tell(state, "Link of the %s of %s" % (question["kind"], question["asker"]),
                ["The message of the question, where it was posted:", " " + question["link"]], "information", level="")


## What an act on a question printed: its one row, set out for the left pane by the names
## of ASK_ACT_ROWS, and what the status line says of it.
def askActAnswer(text, width):
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] in ASK_ACT_ROWS:
            names, says = ASK_ACT_ROWS[fields[0]]
            told = dict(zip(names, [absent(value) for value in fields[2:]]))
            told.update((name, "") for name in names if name not in told)
            return fieldLines([(name, told[name]) for name in names], width), says % told
    return [line for line in text.splitlines() if line.strip()], "the operation printed no row of what it did"


ACTION_HANDLERS["answer"] = askAnswer
ACTION_HANDLERS["reject"] = askReject
ACTION_HANDLERS["dismiss"] = askDismiss
ACTION_HANDLERS["link"] = askLink
ACTION_FITS["answer"] = answerFits
ACTION_FITS["reject"] = rejectFits
ACTION_FITS["dismiss"] = dismissFits
ACTION_FITS["link"] = linkFits
ACTION_REFUSALS["answer"] = lambda state, row: askRefusal(state, row, "this %(kind)s takes no answer any more: it is %(status)s")
ACTION_REFUSALS["reject"] = lambda state, row: askRefusal(state, row, "this %(kind)s has no negative answer of its own: answer it, or dismiss it")
ACTION_REFUSALS["dismiss"] = lambda state, row: askRefusal(state, row, "this %(kind)s cannot be dismissed: it is %(status)s")
ACTION_REFUSALS["link"] = lambda state, row: askRefusal(state, row, "the message of this %(kind)s has no link")
DIALOG_HANDLERS["answer"] = submitAnswer
DIALOG_HANDLERS["answer-many"] = submitAnswer
DIALOG_HANDLERS["reply"] = submitAnswer
DIALOG_HANDLERS["confirm"] = submitConfirm
DIALOG_HANDLERS["reject"] = submitAskAct
DIALOG_HANDLERS["dismiss"] = submitAskAct


## What the left pane shows of the ask selected: its facts, set out again only when the ask, what is stored of it, the width or the minute has changed.
def pendingFocus(state, row):
    if not row.get("ask"):
        return None
    stamp = (row["ask"], id(state.view["info"]), state.viewWidth, int(nowEpoch() // 60))
    if state.view.get("askFor") == stamp:
        return None
    state.view["askFor"] = stamp
    return askLines(row["ask"], state.viewWidth, state.view["info"])


## How many asks wait, for the row of the questions to show after its label: the number the last count read printed (`count:asks`), or None
## before it has come. The row under `Magic-Team (Agents)` counts by the same read, so both places show one number.
def pendingCount(state):
    return int(state.counters["asks"]) if "asks" in state.counters else None


## ---- the plugin: `Pending Questions` ----

PENDING_READS = {
    ## The asks that wait, every owner's. The member named filters nothing with --any-owner; it
    ## is the one the tooling's own read of every owner's asks names (the work-duty scan).
    "list:pending": {"operation": ["--read-pending-reply", "magic-coordinator", "--any-owner"],
                     "rows": "pending"},
    ## One ask, whole: what the stores hold of it.
    "view:pending:record": {"operation": ["--read-pending-reply", "magic-coordinator", "{id}"],
                            "rows": "ask", "needs": "ask"},
    ## What can be done with one ask from the console: the row of the question, with whether it
    ## takes words, a reject and a dismissal and with the link of its message, and a row for
    ## each answer it takes. Read as a part of its own, "acts", beside the view of the ask.
    "acts:pending:record": {"operation": ["--manager-pending-reply-read", "--id", "{id}"],
                            "rows": "ask-acts", "needs": "ask"},
}

## The questions are a root of the list, second after the dashboard, and the same under `Magic-Team (Agents)`: one declaration, two places,
## each with its own copy of the list read, the commands being those of both. The copy of the root also counts (`count`): its operation with
## --count, which prints only the number of the asks, is read whatever is shown, on the period, and the row of both places shows that number
## (pendingCount). The list itself is read where it is shown, and not for this.
registerPlugin({
    "name": "pending",
    "root": {"id": "pending", "label": "Pending Questions", "go": "~P~ending Questions", "group": "watch"},
    "focus": {"pending": "pendingFocus"},
    "counted": {"pending": "pendingCount"},
    "summaries": {
        "pending": {"lines": "pendingSummary"},
    },
    "reads": dict(PENDING_READS, **{"list:pending": dict(PENDING_READS["list:pending"], count="asks")}),
    "commands": (
        {"name": "answer", "keys": ("ENTER", "y"), "menu": ("question", 1), "label": "~A~nswer", "status": "Answer", "window": "list",
         "views": ("pending",), "for": "a question", "on": ("pending:record",), "only": True, "says": "answer",
         "does": ("action", "answer"), "calls": ("answer",)},
        {"name": "reject", "keys": ("j",), "menu": ("question", 1), "label": "Re~j~ect", "status": "Reject", "window": "list",
         "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "reject"), "calls": ("reject",)},
        {"name": "dismiss", "keys": ("d",), "menu": ("question", 1), "label": "~D~ismiss", "status": "Dismiss", "window": "list",
         "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "dismiss"), "calls": ("dismiss",)},
        {"name": "link", "keys": ("o",), "menu": ("question", 2), "label": "Show the ~l~ink", "status": "Link", "window": "list",
         "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "link")},
    ),
})
## PENDING QUESTIONS IS ONE LEVEL, AT THE ROOT: the sketch's note under `Magic-Team` -> `Reorder`
## says *"if we really finished moving `Pending Questions` to global (.local, pun intended) system
## for all/any escalations - then we keep those in root and not duplicating it in `Magic-Team`"*.
## It is global -- the root above is registered -- so the copy mounted on Magic-Team is gone.
