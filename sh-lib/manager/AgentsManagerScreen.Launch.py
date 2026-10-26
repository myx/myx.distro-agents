## AgentsManagerScreen.Launch.py -- `Launchpad`: the starts the team can be given by hand, one form for each kind, and the routines it can start.
##
## A SECTION OF MAGIC-TEAM OF ITS OWN, and the third of them, as the sketch orders the team's list:
## Pending Questions, Activity, **Launchpad**, Team Members, Team Data, Routines
## (20261026-refactorings.sketch.md, 14.5). Its level is `magic-team/launch`.
## The starts that are not a routine's are the Dispatcher's `--manager-spawn-member --kind coworking|standalone|work-duty|free`
## (AgentsTools.ManagerSpawn.include); the screen draws their forms and sends what was typed, and decides nothing of what a kind needs
## beyond asking for it. A routine is started as it was: its row, Enter.

## The starts of the rows ahead of the routines: the row, what it shows as, the kind the operation takes, what its dialog says, and
## what its goal or prompt is called there. A free prompt takes a member for now: the operation has no start without one.
PAD_STARTS = (
    ("coworking", "Start Coworking Session...", "Members working together in one session, started with the same goal.",
     "Session goal", "members"),
    ("standalone", "Start Standalone Session...", "One member, alone, in the standalone routine, with the goal as its task.",
     "Session goal", "who"),
    ("work-duty", "Start Work-Duty Session...", "The duty session of one member, by its duty routine: one such session at a time for a member.",
     "Comments or scope, or none", "who"),
    ("free", "Free Prompt...", "A prompt to one member, with no routine: only the floor of the member loads, no instruction of a session kind.",
     "Prompt", "who"),
)
PAD_NAMES = tuple(held[0] for held in PAD_STARTS)


## The dialog of one kind of start: the facts of the kind, who runs it (boxes for several, a list for one), what it is to work on,
## and the name of the session. The goal of a start with a goal, and the prompt of a free one, may not be empty; a duty may have neither.
def padDialog(kind, label, goalLabel, whoKind):
    who = ({"name": "members", "kind": "checks", "label": "Members",
            "empty": "the members are being read",
            "required": "no member is checked: check one at least, with Space"} if whoKind == "members" else
           {"name": "who", "kind": "list", "label": "Member"})
    text = {"name": "prompt" if kind == "free" else "goal", "kind": "area", "label": goalLabel}
    if kind != "work-duty":
        text["required"] = "nothing is started: the %s is empty" % ("prompt" if kind == "free" else "goal")
    return {"title": label.rstrip("."), "feeds": "start", "reads": ("list:team",), "first": text["name"],
            "controls": ({"name": "about", "kind": "text"}, who, text,
                         {"name": "name", "kind": "input", "label": "Name of the session, or none"}),
            "buttons": (("start", "Start"), ("cancel", "Cancel"))}


for padKind, padLabel, padSays, padGoal, padWho in PAD_STARTS:
    DIALOGS["pad-" + padKind] = padDialog(padKind, padLabel, padGoal, padWho)


## Enter on a start of the Launchpad: the dialog of its kind opens, the members offered once the list of the team was read.
def askPad(state, row):
    held = next((one for one in PAD_STARTS if row and one[0] == row["id"]), None)
    if held is None:
        return ""
    state.answer = None
    kind, label, says, goal, whoKind = held
    options = memberOptions(state)
    fill = {"about": {"lines": [says, "No secret belongs in it: a goal shows on the command line of the CLI." if kind != "free" else
                                "No secret belongs in it: a brief shows on the command line of the CLI."]}}
    fill["members" if whoKind == "members" else "who"] = {"options": options or []}
    openDialog(state, "pad-" + kind, fill, {"padKind": kind, "viewKey": viewKeyOf(state), "filled": options is not None}, label.rstrip("."))
    return ""


## The members of the list of the team into the dialog of a start, once it was read.
def fillPad(state, dialog):
    options = memberOptions(state)
    if dialog["about"]["filled"] or options is None:
        return
    dialog["about"]["filled"] = True
    control = dialogControl(dialog, "members") or dialogControl(dialog, "who")
    control["options"] = list(options)
    if not options and control["kind"] == "checks":
        control["empty"] = "no member can be started from here"
    if control["kind"] == "list" and options and not control["value"]:
        control["value"] = options[0][0]
        control["at"] = 0


## Start in the dialog of a kind: the operation is asked once, with the member (the first checked, the others after `--also`), the kind,
## the goal (a free prompt's text goes on the standard input and never to the command line), and the name left or typed.
def submitPad(state, dialog, button):
    kind = dialog["about"]["padKind"]
    name = dialogValue(dialog, "name").strip()
    options = (dialogControl(dialog, "members") or {}).get("options", [])
    members = [one for one, label in options if one in dialogValue(dialog, "members")] if kind == "coworking" else [dialogValue(dialog, "who")]
    if not members or not members[0]:
        return "no member is chosen"
    words = callWords("start", members[0], name) + ["--kind", kind]
    if len(members) > 1:
        words.extend(["--also", ",".join(members[1:])])
    typed = (dialogValue(dialog, "prompt" if kind == "free" else "goal") or "").strip()
    if kind != "free" and typed:
        words.extend(["--goal", typed])
    askCall(state, "start", members[0], words, typed + "\n" if kind == "free" else None, {"viewKey": dialog["about"]["viewKey"]})
    state.notice = "start asked of the tooling: %s, %s" % (kind, ", ".join(members))
    state.noticeOf = None
    return None


for padKind in PAD_NAMES:
    DIALOG_HANDLERS["pad-" + padKind] = submitPad
    DIALOG_FILLS["pad-" + padKind] = fillPad
ACTION_HANDLERS["pad"] = askPad


## The row selected in `Launchpad` for the left pane: what its kind of start is, or the routine.
def launchpadFocus(state, row):
    held = next((one for one in PAD_STARTS if one[0] == row["id"]), None) if row["kind"] == "pad" else None
    if held is not None:
        lines = []
        for text in (held[2], "Enter opens its dialog: who runs it, the %s, the name of the session." % held[3].lower().replace(", or none", "")):
            lines.extend(wrapToCells(text, max(10, state.viewWidth - 1)))
        return lines
    return launchFocus(state, row)


registerPlugin({
    "name": "launch",
    "mount": "magic-team",
    "root": {"id": "launch", "label": "Launchpad", "go": "~L~aunchpad", "group": "team", "spaceAfter": True},
    ## The rows a level always holds, ahead of the rows its operation gives: a start of each kind that is no routine's.
    "rows": {"launch": tuple((kind, label, "pad", False) for kind, label, says, goal, who in PAD_STARTS)},
    "summaries": {"launch": {"lines": "routinesSummary"}},
    "focus": {"launch": "launchpadFocus"},
    "derived": {},
    "reads": {
        ## The routines the members carry, from the frontmatter alone: the fast list. The full list
        ## asks the validator, the evaluator and the autorun of every routine and takes tens of
        ## seconds on a real member set (24-48 s for 55 routines, measured), which the owner pays
        ## every time this view is opened. The verdicts it adds are not needed to list what can be
        ## started here; they are asked for the row an operator selects, in the Routines view.
        "list:launch": {"operation": ["--manager-routine-list", "--facts-only"], "rows": "routines"},
    },
    "commands": (
        {"name": "pad", "keys": ("ENTER",), "menu": ("session", 2), "label": "~S~tart a session", "status": "Start", "window": "list",
         "views": ("launch",), "for": "a start of the Launchpad", "on": ("launch:pad",), "only": True, "does": ("action", "pad"), "calls": ("start",)},
    ),
})
