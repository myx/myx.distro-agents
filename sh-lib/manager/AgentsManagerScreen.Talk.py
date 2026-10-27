##
## AgentsManagerScreen.Talk.py -- what the console says to a session: a message to it or to a participant (`M`), and magic-coordinator joined into
## a session that has finished, waits or is stuck (`J`) (F11.6 of the refactorings epic).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##

## ---- messages and the join: `Message`, `Join` ----

## The commands are those of the rows of `Activity` a session or a participant stands on (activityActs, Sessions.py), and the operations they ask
## are `--manager-session-message` and `--manager-session-join` (AgentsTools.ManagerSessionTalk.include): the screen draws, takes the keys and the
## words, and sends nothing itself. A message is from the person at the console, as `user-<account>`; the operation says so and where the message went.

CALLS["talk"] = ["--manager-session-message", "--session-id", "{id}"]
CALLS["join"] = ["--manager-session-join", "--session-id", "{id}"]
## The states of a session the join is offered for, and what the key says at a row where it is not.
JOIN_STATES = ("finished", "waiting", "unclosed", "running", "starting")
JOIN_SAYS = {
    "unknown-foreign": "it is another host's: nothing can be done with it from here",
}
TALK_ALL = ("", "everybody in the session")
## The dialogs: a message, and the join.
DIALOGS["talk"] = {"title": "Message", "feeds": "talk", "first": "words",
                   "controls": ({"name": "about", "kind": "text"},
                                {"name": "who", "kind": "list", "label": "To"},
                                {"name": "words", "kind": "area", "label": "Message", "required": "nothing is sent: the message is empty"}),
                   "buttons": (("ok", "Send"), ("cancel", "Cancel"))}
DIALOGS["join"] = {"title": "Join the coordinator", "feeds": "join",
                   "controls": ({"name": "about", "kind": "text"},),
                   "buttons": (("ok", "Join"), ("cancel", "Cancel"))}


## What `M` and `J` act on at that row, or None: the session a row is, or the session of the participant it is, and for a participant its member, where
## the message is for it. The session is found among the sessions of the last read of the list.
def talkTargetOf(state, row):
    if row is None:
        return None
    if row.get("session") and row["session"]["id"] not in ("", "-"):
        return {"session": row["session"], "label": row["label"], "member": ""}
    if row.get("run"):
        found = sessionRowOf(state, row["run"]["session"])
        if found is not None:
            return {"session": found["session"], "label": found["label"], "member": row["run"]["member"]}
    return None


def talkFits(state, row):
    return talkTargetOf(state, row) is not None


## The members of a session, each once, in the order of its runs: whom a message can be for.
def talkMembers(session):
    members = []
    for run in session["runs"]:
        if run["member"] not in ("", "-") and run["member"] not in members:
            members.append(run["member"])
    return members


## `M`: the dialog of a message. It is for the whole session, or for one participant, the one the row is where the row is a participant's. What is
## typed goes on the standard input of the operation, never among its words.
def askTalk(state, row):
    target = talkTargetOf(state, row)
    if target is None:
        return ""
    session = target["session"]
    state.answer = None
    openDialog(state, "talk", {
        "about": {"lines": [
            ("session", target["label"]),
            ("state", session["state"]),
            "The message is from you, as the account you are at this console. It goes through the chat file of the session, and into its Slack thread where it has one.",
        ]},
        "who": {"options": [TALK_ALL] + [(member, member) for member in talkMembers(session)], "value": target["member"]},
    }, {"id": session["id"], "label": target["label"], "viewKey": viewKeyOf(state)}, "Message: %s" % target["label"])
    return ""


def submitTalk(state, dialog, button):
    about = dialog["about"]
    who = dialogValue(dialog, "who")
    text = dialogValue(dialog, "words").rstrip("\n")
    askCall(state, "talk", about["id"], callWords("talk", about["id"]) + (["--to", who] if who else []), text + "\n",
            {"viewKey": about["viewKey"], "to": who or "everybody", "label": about["label"]})
    state.notice = "message asked of the tooling: to %s of %s" % (who or "everybody", about["label"])
    state.noticeOf = None
    return None


## Whether `J` acts at that row: a session that has finished, waits or is stuck, or a participant of one.
def joinFits(state, row):
    target = talkTargetOf(state, row)
    return target is not None and target["session"]["state"] in JOIN_STATES


def joinRefusal(state, row):
    target = talkTargetOf(state, row)
    if target is None:
        return "that is no session"
    return JOIN_SAYS.get(target["session"]["state"], "it reads %s, and the join is for a session on this host" % target["session"]["state"])


## `J`: asks first, in a box that says what the join does. OK joins magic-coordinator into the session through the operation.
def askJoin(state, row):
    target = talkTargetOf(state, row)
    if target is None:
        return ""
    session = target["session"]
    state.answer = None
    openDialog(state, "join", {"about": {"lines": [
        ("session", target["label"]),
        ("state", session["state"]),
        "magic-coordinator joins this session, in its thread, with a task: to assess it, unblock it interactively with the people in its thread, and report.",
        "It runs as a session of its own, and outlives this console.",
    ]}}, {"id": session["id"], "label": target["label"], "viewKey": viewKeyOf(state)}, "Join: %s" % target["label"])
    return ""


def submitJoin(state, dialog, button):
    about = dialog["about"]
    askCall(state, "join", about["id"], callWords("join", about["id"]), None, {"viewKey": about["viewKey"], "label": about["label"]})
    state.notice = "join asked of the tooling: magic-coordinator into %s" % about["label"]
    state.noticeOf = None
    return None


ACTION_HANDLERS["talk"] = askTalk
ACTION_HANDLERS["join"] = askJoin
ACTION_FITS["talk"] = talkFits
ACTION_FITS["join"] = joinFits
ACTION_REFUSALS["talk"] = lambda state, row: "that is no session and no participant of one"
ACTION_REFUSALS["join"] = joinRefusal
DIALOG_HANDLERS["talk"] = submitTalk
DIALOG_HANDLERS["join"] = submitJoin


## What `--manager-session-message` printed: its `message` row, set out for the left pane and said in one line for the bottom line.
def talkAnswer(text, about, width):
    for printed in text.splitlines():
        fields = printed.split("\t")
        if fields[0] == "message" and len(fields) >= 6:
            local = fields[4] == "chat-file"
            how = ("recorded in its chat file, block %s: the session has no Slack thread, so nothing is posted" % fields[5]) if local else "left for the writer, which sends it into the thread"
            return "the message", fieldLines([("session", about.get("label", fields[1])), ("from", fields[2]), ("to", fields[3].replace(",", ", ")), ("how", how)], width), (
                "recorded in the chat file of %s, nothing posted: it has no Slack thread" % about.get("label", fields[1]) if local
                else "message left for %s: the writer sends it into the thread as %s" % (about.get("label", fields[1]), fields[2]))
    return "the message", [line for line in text.splitlines() if line.strip()], "the operation printed no row of what it left"


## What `--manager-session-join` printed: its `join` row.
def joinAnswer(text, about, width):
    for printed in text.splitlines():
        fields = printed.split("\t")
        if fields[0] == "join" and len(fields) >= 4:
            return "the join", fieldLines([("session", about.get("label", fields[1])), ("member", fields[2]), ("item", fields[3])], width), (
                "%s joined %s: its dispatch item is %s" % (fields[2], about.get("label", fields[1]), fields[3]))
    return "the join", [line for line in text.splitlines() if line.strip()], "the operation printed no row of what it started"


ACTION_ANSWERS["talk"] = talkAnswer
ACTION_ANSWERS["join"] = joinAnswer


## ---- the plugin: the commands ----

## Mounted where `Activity` is, with no root of its own: the levels of its commands are those of Activity, below Magic-Team (Agents).
registerPlugin({
    "name": "talk",
    "mount": "magic-team",
    "commands": (
        activityActs(name="talk", keys=("M",), menu=("session", 4), label="~M~essage", status="Message", after="colours",
                     **{"for": "a session or a participant", "does": ("action", "talk"), "calls": ("talk",)}),
        activityActs(name="join", keys=("J",), menu=("session", 4), label="~J~oin the coordinator", status="Join", after="colours",
                     **{"for": "a session that has finished, waits or is stuck", "does": ("action", "join"), "calls": ("join",)}),
    ),
})
