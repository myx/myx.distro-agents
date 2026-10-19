##
## AgentsManagerScreen.Actions.py -- what every action shares: its call to the tooling, its answer, the escalation.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the actions: a kill, a start ----

## The words of one action: its entry in CALLS with the id in its place, and after them
## the name of the session where one is given.
def callWords(callName, callId="", sessionName=""):
    words = [word.replace("{id}", callId) for word in CALLS[callName]]
    if sessionName:
        words.extend([CALL_NAME, sessionName])
    return words


## An action is asked of the tooling: it is started at the next chance, after those asked
## before it (startCalls), through the reader as every call of the screen. `inputText` is
## what goes to the operation on its standard input, or None. `about` is kept for its
## answer, with the action: under "viewKey" the item it was asked on, which is the item
## selected now where `about` names none.
def askCall(state, actionName, callId, words, inputText, about=None):
    key = "action:%s:%s" % (actionName, callId) if not (about or {}).get("escalation") else "action:%s:%s:%s" % (actionName, about["escalation"], callId)
    state.calls.append({"key": key, "words": words, "input": inputText})
    told = {"viewKey": viewKeyOf(state)}
    told.update(about or {})
    told["action"] = actionName
    state.asked[key] = told
    state.answer = None


## The answer of an action, taken into the state. What the operation printed is set out
## for the left pane, where it stands while the item it was asked on stays selected; one
## line of it stands in the status line; and what is shown is read again, the list of the
## sessions with it. A call that failed shows what it wrote, whole, in a box, and its error
## line in the pane after the rows it printed. The start of a control thread that printed
## its row and failed has the words of that row first in the box: the row says why none
## was started.
def applyCall(state, result):
    about = state.asked.pop(result["key"], None) or {"action": "", "viewKey": None}
    if escalateOffered(state, result, about):
        return
    if about.get("escalation"):
        what = "the request"
        lines = [line for line in result["text"].splitlines() if line.strip()]
        summary = lines[0] if lines else ""
    elif about["action"] == "kill":
        what = "the kill"
        lines, summary = killAnswer(result["text"])
        summary = "kill: " + (summary or "the operation named no run")
    elif about["action"] == "control":
        what = "the control start"
        lines, summary = controlAnswer(result["text"], state.viewWidth)
    elif about["action"] == "start":
        what = "the start"
        lines, summary = spawnAnswer(result["text"], state.viewWidth)
    elif about["action"] == "setting":
        what = "the save"
        lines, summary = settingAnswer(result["text"], about.get("says", ""), state.viewWidth)
    elif about["action"] in ASK_ACT_WORDS:
        what = ASK_ACT_WORDS[about["action"]]
        lines, summary = askActAnswer(result["text"], state.viewWidth)
    else:
        what = "the start"
        lines, summary = startAnswer(result["text"], about.get("name", ""), state.viewWidth)
    if result["status"] != 0:
        what += " failed"
        tell(state, what[0].upper() + what[1:], ([summary] if about["action"] == "control" and lines else []) + failureLines(result))
        summary = ""
        lines = lines + wrapToCells(result["error"], max(10, state.viewWidth - 1))
    title = "%s, answered %s:" % (what, time.strftime("%H:%M:%S", time.localtime(nowEpoch())))
    state.notice = summary
    state.noticeOf = None
    state.answer = {"key": about["viewKey"], "lines": [title] + lines} if about["viewKey"] == viewKeyOf(state) else None
    readNow(state)


## An answer, reject, dismissal or kill refused for the authority it needs (F6.10, the status
## and the words of AgentsTools.Authority.include): the person may always ask for it, so the
## refusal opens the dialog of the two ways to, with what the operation said. Not where the call
## refused was such a request already.
AUTHORITY_REFUSED = 3
AUTHORITY_SAYS = "needs the authority of"
AUTHORITY_ACTIONS = ("answer", "reject", "dismiss", "kill")


def escalateOffered(state, result, about):
    if result["status"] != AUTHORITY_REFUSED or about["action"] not in AUTHORITY_ACTIONS or about.get("escalation"):
        return False
    said = [line.strip() for line in result.get("said", "").splitlines() if line.strip()]
    if not [line for line in said if AUTHORITY_SAYS in line]:
        return False
    openDialog(state, "escalate", {"about": {"lines": said + [" ",
        "Request and wait: the same call asks for the authority, and waits for the answer, in the background.",
        "Enqueue: the same call asks for it, and returns at once; it acts once the answer comes."]}},
        {"id": result["key"].split(":", 2)[2], "action": about["action"], "words": list(result["words"]), "viewKey": about["viewKey"]},
        "Without the authority")
    state.notice = "refused: it needs the authority of another"
    state.noticeOf = None
    return True


## The way picked in that dialog: the same call again, with --escalate-wait, which runs apart from
## the other actions so that none waits behind it, or with --escalate-enqueue, as any action.
def submitEscalate(state, dialog, button):
    about = dialog["about"]
    flag = "--escalate-wait" if button == "wait" else "--escalate-enqueue"
    askCall(state, about["action"], about["id"], about["words"] + [flag], None,
            {"viewKey": about["viewKey"], "escalation": button})
    if button == "wait":
        state.calls[-1]["kind"] = "escalation"
    state.notice = "request asked of the tooling"
    state.noticeOf = None
    return None


DIALOG_HANDLERS["escalate"] = submitEscalate


## What an action answered on the selected item, as the first lines of the left pane, with
## an empty line under them: no more than that many lines of it. Empty where the last
## answer was for another item, and where there is none.
def answerLines(state, limit):
    if state.answer is None or state.answer["key"] != viewKeyOf(state):
        return []
    lines = state.answer["lines"]
    if len(lines) > limit:
        lines = lines[:limit - 1] + ["  and %d more" % (len(lines) - limit + 1)]
    return lines + [""]

