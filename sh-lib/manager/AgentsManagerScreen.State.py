##
## AgentsManagerScreen.State.py -- the declaration of the dialogs and of the actions, and the state of the screen (ManagerState).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the declaration of the dialogs ----

## The kinds of control a dialog is made of. "focus": whether the keys go to one of that
## kind. "keys": the keys it takes while they do, each by its name in KEY_WORDS (two with /
## between), which the status line shows in the names of the style (keysShown), with its
## word. Tab and Shift-Tab go to the next control and to the one before, Enter presses
## the first button of the dialog, or the button the keys are on, and Esc closes it and
## does nothing: those are every dialog's.
CONTROL_KINDS = {
    ## a text, broken to the dialog; one longer than its room scrolls
    "text": {"focus": False, "keys": ()},
    ## one line to type in
    "input": {"focus": True, "keys": ()},
    ## several lines to type in: Enter there is a new line, and a button is reached by Tab
    "area": {"focus": True, "keys": (("ENTER", "New line"),)},
    ## boxes, any number of them checked: [X]
    "checks": {"focus": True, "keys": (("Space", "Toggle"), ("UP/DOWN", "Move"))},
    ## radio buttons, one of them chosen: (*)
    "radios": {"focus": True, "keys": (("Space", "Choose"), ("UP/DOWN", "Move"))},
    ## a list: the row its bar is on is the one picked
    "list": {"focus": True, "keys": (("UP/DOWN", "Pick"),)},
    ## a button of the dialog
    "button": {"focus": True, "keys": (("LEFT/RIGHT", "Buttons"),)},
}
## The dialogs, each declared once by its name. "title": what stands in its top border,
## where the one that opens it gives no other. "controls": its controls from the top, each
## with its name, its kind of CONTROL_KINDS and, for one that is not a text, its "label",
## the line above it. "buttons": its buttons, the name of each and what it shows as between
## brackets; the first is the one Enter presses, and one named "cancel" does what Esc does.
## "feeds": the command of COMMANDS it asks for, or the commands, whose operations its
## handler calls (DIALOG_HANDLERS); a dialog with none only says something. "first": the
## control the keys are on when it opens, where that is not its first one. "reads": the entries of
## READS that are read while it is open, since it offers what they give (DIALOG_FILLS); a
## name there that holds {kind} is the entry of the kind of what the dialog was opened on,
## its "target", and that one is asked by the id of the target (dialogReads).
## A control may be declared "required": what the dialog says, and does not do, while that
## control holds nothing, a field only blanks, boxes none checked, or, with "exactly", while
## a field does not hold that very word. The engine holds it for every dialog (dialogMissing):
## no handler is called, the buttons that would act are greyed, and Enter presses none.
## A control of options may say under "empty" what stands in it while it has none, and
## under "digits" that a digit typed while the keys are on it picks the option whose id is
## that digit. What a
## dialog cannot know before it is opened, a text, the options of a list, comes from the
## one that opens it (openDialog). One engine draws them all and gives them the keys, in every style: adding
## a dialog is adding an entry here and, where it does something, its handler.
DIALOGS = {
    ## what the screen refuses, and what an operation answered when it failed, whole; "level":
    ## what it is of, which a style may draw it by (STYLES "levels"), "bad" what was refused
    ## or failed, and the one who opens it may say another (tell)
    "message": {"title": "Message", "controls": ({"name": "text", "kind": "text"},),
                "buttons": (("ok", "OK"),), "level": "bad"},
    ## why something cannot be done with what is selected, set out by its facts
    "information": {"title": "Information", "controls": ({"name": "text", "kind": "text"},),
                    "buttons": (("ok", "OK"),), "level": "bad"},
    ## the members a routine that any member executes is started with, in one session, and
    ## what that session is to work on
    "members": {"title": "Start the routine with members", "feeds": "launch", "reads": ("list:team",),
                "controls": ({"name": "about", "kind": "text"},
                             {"name": "members", "kind": "checks", "label": "Members",
                              "empty": "the members are being read",
                              "required": "no member is checked: check one at least, with Space"},
                             {"name": "task", "kind": "input", "label": "What the session is to work on"}),
                "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
    ## the confirmation of a kill: exactly what will be killed, dismissed and closed, as
    ## the plan of that kill gives it, and the word that confirms it, typed whole
    "kill": {"title": "Kill", "feeds": "kill", "reads": ("plan:kill:{kind}",),
             "controls": ({"name": "about", "kind": "text"},
                          {"name": "word", "kind": "input", "label": "Type %s to kill" % KILL_WORD, "exactly": KILL_WORD,
                           "required": "nothing is killed: the word typed is not %s" % KILL_WORD}),
             "buttons": (("kill", "Kill"), ("cancel", "Cancel"))},
    ## the same confirmation where nothing of the session lives: it is closed, and its
    ## title, its button and its word say so (fillKill)
    "close": {"title": "Close", "feeds": "kill", "reads": ("plan:kill:{kind}",),
              "controls": ({"name": "about", "kind": "text"},
                           {"name": "word", "kind": "input", "label": "Type %s to close" % KILL_WORD, "exactly": KILL_WORD,
                            "required": "nothing is closed: the word typed is not %s" % KILL_WORD}),
              "buttons": (("kill", "Close"), ("cancel", "Cancel"))},
    ## the start of a routine the spawner starts as its executors: what its session is to
    ## work on, and the name of that session
    "routine": {"title": "Start the routine", "feeds": "launch",
                "controls": ({"name": "about", "kind": "text"},
                             {"name": "task", "kind": "input", "label": "What the session is to work on"},
                             {"name": "name", "kind": "input", "label": "Name of the session, or none"}),
                "buttons": (("start", "Start"), ("cancel", "Cancel"))},
    ## a prompt and who runs it: the free prompt of `Launch (Start)`, and the start of one
    ## member; the keys are on the prompt first
    "prompt": {"title": "Free prompt", "feeds": ("prompt", "start"), "reads": ("list:team",), "first": "prompt",
               "controls": ({"name": "about", "kind": "text"},
                            {"name": "who", "kind": "list", "label": "Who runs it"},
                            {"name": "prompt", "kind": "area", "label": "Prompt",
                             "required": "nothing is started: the prompt is empty"},
                            {"name": "name", "kind": "input", "label": "Name of the session, or none"}),
               "buttons": (("start", "Start"), ("cancel", "Cancel"))},
    ## the answer to a pending question that has answers of its own: the question as it was
    ## posted, its answers with what each does, and words to go with the one picked
    "answer": {"title": "Answer", "feeds": "answer", "first": "answers",
               "controls": ({"name": "about", "kind": "text"},
                            {"name": "answers", "kind": "list", "label": "Answers", "digits": True},
                            {"name": "words", "kind": "input", "label": "Words to go with it, or none"}),
               "buttons": (("answer", "Answer"), ("cancel", "Cancel"))},
    ## the answer to a question that takes several of its answers (its form `many`): the same, with
    ## boxes in place of the list, and at least one checked
    "answer-many": {"title": "Answer", "feeds": "answer", "first": "answers",
                    "controls": ({"name": "about", "kind": "text"},
                                 {"name": "answers", "kind": "checks", "label": "Answers",
                                  "required": "nothing is answered: no answer is checked: check one at least, with Space"},
                                 {"name": "words", "kind": "input", "label": "Words to go with them, or none"}),
                    "buttons": (("answer", "Answer"), ("cancel", "Cancel"))},
    ## the answer to a plain question: the words typed are its answer
    "reply": {"title": "Answer", "feeds": "answer",
              "controls": ({"name": "about", "kind": "text"},
                           {"name": "words", "kind": "input", "label": "The answer",
                            "required": "nothing is answered: the answer is empty"}),
              "buttons": (("answer", "Answer"), ("cancel", "Cancel"))},
    ## the confirmation of a reject, and of a dismissal, of a pending question
    "reject": {"title": "Reject", "feeds": "reject",
               "controls": ({"name": "about", "kind": "text"},
                            {"name": "words", "kind": "input", "label": "Words to go with it, or none"}),
               "buttons": (("reject", "Reject"), ("cancel", "Cancel"))},
    "dismiss": {"title": "Dismiss", "feeds": "dismiss",
                "controls": ({"name": "about", "kind": "text"},
                             {"name": "words", "kind": "input", "label": "Reason, or none"}),
                "buttons": (("dismiss", "Dismiss"), ("cancel", "Cancel"))},
    ## the confirmation of an approving answer (F6.10): an allow of a permission, the yes of a
    ## confirmation; only its OK gives the answer
    "confirm": {"title": "Confirm", "feeds": "answer",
                "controls": ({"name": "about", "kind": "text"},),
                "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
    ## an operation refused for the authority it needs (F6.10): the same operation again, asking
    ## the one who holds it, and waiting for the answer, or returning at once with the request made
    "escalate": {"title": "Authority", "feeds": ("answer", "reject", "dismiss", "kill"),
                 "controls": ({"name": "about", "kind": "text"},),
                 "buttons": (("wait", "Request and wait"), ("enqueue", "Enqueue"), ("cancel", "Cancel"))},
    ## a public key of this server whole, to copy: its line, read while the box is open
    "keyline": {"title": "Public key", "reads": ("full:{kind}",),
                "controls": ({"name": "text", "kind": "text"},),
                "buttons": (("ok", "OK"),)},
    ## the confirmation of a cleanup of `Team Data`: what will run, and that it runs at once
    "cleanup": {"title": "Run", "feeds": "cleanup",
                "controls": ({"name": "about", "kind": "text"},),
                "buttons": (("run", "Run"), ("cancel", "Cancel"))},
    ## the confirmation of a command of a workspace: what will run, where, and how
    "placecommand": {"title": "Run", "feeds": "placecommand",
                     "controls": ({"name": "about", "kind": "text"},),
                     "buttons": (("run", "Run"), ("cancel", "Cancel"))},
    ## the big dialog that runs an operation and follows what it writes, both its streams
    ## in the order they came, to the end unless it is scrolled up ("follow": its lines are
    ## the end of the text while nothing scrolled them, "raw": each line as it was written);
    ## then the result in a line of its own. "big": it takes most of the screen, and its
    ## first text the room the rest leaves. The one way for any command whose output is to
    ## be watched (runFollowed); its buttons are its handler's while it runs (OUTPUT_SAYS).
    "output": {"title": "Output", "big": True,
               "controls": ({"name": "output", "kind": "text", "raw": True, "follow": True},
                            {"name": "result", "kind": "text"}),
               "buttons": (("stop", "Stop"),)},
    ## a setting that offers choices: what it is now, and its choices, one of them chosen
    "setting": {"title": "Setting", "feeds": "setting", "first": "choice",
                "controls": ({"name": "about", "kind": "text"},
                             {"name": "choice", "kind": "radios", "label": "Choices"}),
                "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
    ## the style of the interface: what it is now, the style and the colours, one of each chosen
    "setting-style": {"title": "Setting", "feeds": "setting", "first": "style",
                      "controls": ({"name": "about", "kind": "text"},
                                   {"name": "style", "kind": "radios", "label": "Style"},
                                   {"name": "colours", "kind": "radios", "label": "Colours"}),
                      "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
    ## a setting that is a number: what it is now, and the number typed, which the one
    ## that opens it labels with the range of the row (askSetting)
    "setting-number": {"title": "Setting", "feeds": "setting", "first": "number",
                       "controls": ({"name": "about", "kind": "text"},
                                    {"name": "number", "kind": "input", "label": "A whole number",
                                     "required": "nothing is saved: no number is typed"}),
                       "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
    ## a setting of any other kind: a short text, typed
    "setting-text": {"title": "Setting", "feeds": "setting", "first": "words",
                     "controls": ({"name": "about", "kind": "text"},
                                  {"name": "words", "kind": "input", "label": "Its value",
                                   "required": "nothing is saved: nothing is typed"}),
                     "buttons": (("ok", "OK"), ("cancel", "Cancel"))},
}
## The handler of each dialog that does something: handler(state, dialog, button) is called
## when a button other than "cancel" is pressed. It gives nothing, and the dialog closes;
## or it gives what it refuses, which then stands in the dialog, and the dialog stays open.
## Set where each is defined.
DIALOG_HANDLERS = {}
## What fills a dialog from what was read, while it is open: fill(state, dialog), called at
## every turn of the screen. Set where each is defined.
DIALOG_FILLS = {}
## What Esc does in a dialog where it does more than close it: escape(state, dialog) gives
## True where it did what Esc does there, and the dialog stays. Set where each is defined.
DIALOG_ESCAPES = {}
## The width a dialog takes at most, and how many lines of a list of options and of a
## field of several lines it shows, where the terminal has them.
DIALOG_COLUMNS = 82
DIALOG_OPTIONS = 8
DIALOG_AREA = 4
## The margins inside the frame of every dialog, a modal one, a popup and the big window of
## an operation's output alike, where the terminal has the room: the cells at each side of
## what it holds, its frame and three blank ones; the empty lines under its top; the empty
## lines under the shadow of its buttons, where buttons cast none the line of their shadow
## one more.
DIALOG_SIDE = 4
DIALOG_LEAD = 2
DIALOG_TAIL = 1

## The handler of each action: handler(state, row) gives the text for the bottom line, or
## None. Where it must ask first it opens a dialog with openDialog(). It is called only on
## a row its command applies to (commandRefusal): what does not apply says its one line in
## the status line and reaches no handler. None here: the task of
## that action has not built it.
ACTION_HANDLERS = {
    ## asks for the typed word, then kills the selected session or agent: askKill, set where it is defined
    "kill": None,
    ## starts the control thread of the selected session again, asking nothing first: askControl, set where it is defined
    "control": None,
    "pause": None,
    "resume": None,
    "stop": None,
    "restart": None,
    ## Enter on a routine of `Launch (Start)`, and on its free prompt: askLaunch and askPrompt, set where they are defined
    "launch": None,
    "prompt": None,
    ## Enter and Right on a routine of `Launch (Start)` that cannot be started: askUnstarted, set where it is defined
    "unstarted": None,
    ## starts the selected team member with a prompt: askStart, set where it is defined
    "start": None,
    ## shows the keys of the screen, from COMMANDS: askHelp, set where it is defined
    "help": None,
    ## a pending question: its answer, its reject, its dismissal, each asked in a dialog, and
    ## the link of its message in a box: askAnswer, askReject, askDismiss, askLink, set where they are defined
    "answer": None,
    "reject": None,
    "dismiss": None,
    "link": None,
    ## Enter on a setting, inside a subject: the dialog of its kind: askSetting, set where it is defined
    "setting": None,
    ## Enter on a row of `Consoles`: it is started with the whole terminal: askRun, set where it is defined
    "run": None,
    ## the whole public line of the selected key of the server, in a box: askKeyLine, set where it is defined
    "line": None,
    ## Enter on a cleanup of `Team Data`: asked first, then run in the big output dialog: askCleanup, set where it is defined
    "cleanup": None,
    ## Enter on a command of a workspace in `Locations (Places)`: asked first, then run in the big output dialog,
    ## or with the whole terminal where it runs so: askPlaceCommand, set where it is defined
    "placecommand": None,
}
## Whether an action acts on a row as it is now: fits(state, row), set where it is defined.
## An action with no entry acts on every row COMMANDS gives it.
ACTION_FITS = {}
## Why an action does not act on a row ACTION_FITS refuses: refusal(state, row) gives the
## words, set where it is defined. They stand in the status line, after the name of the
## command, when it is tried there. An action with no entry has the engine's own words.
ACTION_REFUSALS = {}


## Everything the screen knows between two keys. Nothing here is the terminal's.
class ManagerState:
    def __init__(self, workspace=""):
        self.workspace = workspace
        self.clock = ""
        ## the levels dived into, the root first: empty is the root
        self.path = []
        ## the selection of each level: level key -> {"key", "index", "top"}; the root's is on START_ROOT
        self.cursors = {levelKey([]): {"key": "section:" + START_ROOT, "index": 0, "top": 0}}
        ## which window is active and has the keys: "list" on the right, "view" on the left
        self.focus = WINDOW_FIRST
        ## the pull-down menu that is open: {"menu", "item"}, its place in MENUS and the place
        ## of the item its bar is on
        self.menu = None
        self.activeOnly = False
        ## whether the lists of ALPHABETICAL show their rows by name, not in the order of the operation
        self.alphabetical = False
        ## the rows the last answer of a list gave when it was asked with what its filter
        ## adds: level key -> ids
        self.activeOf = {}
        ## the rows the last good read of each level gave: level key -> rows
        self.rows = {}
        ## the left pane: which item it shows, its lines, the first line in view (newView)
        self.view = newView(None, False)
        ## the mode of the left window of a session or an agent, of VIEW_MODES
        self.viewMode = VIEW_MODE_FIRST
        ## the mode of the left window of a Markdown text and of the help (TEXT_MODE_FIRST)
        self.textMode = TEXT_MODE_FIRST
        ## whether the left window wraps its long lines, or cuts them and scrolls sideways
        self.wrap = WRAP_FIRST
        ## the split between the windows as the user moved it, the share of the width the
        ## right one takes, or None; and how the mouse holds its border: None, "pressed"
        ## by a button that is down, "held" by a click, until the next one
        self.split = None
        self.splitHeld = None
        ## the dialog that is open and has the keys (openDialog), and those that wait for it to close
        self.dialog = None
        self.waiting = []
        ## the clock of the turn, which only goes forward, and when Esc was pressed with
        ## nothing open to close: the key after it, in time, is Alt with that key
        self.now = 0.0
        self.metaAt = None
        ## what the last drawing drew that a click can mean: its rectangle and what it stands for (spot)
        self.spots = []
        ## how deep the screen is in looking at what the left window shows (shownLevel)
        self.shown = 0
        self.notice = ""
        self.noticeOf = None
        ## the reads: when each was last started and with which words, which failed last
        ## with which line, which must start at the next chance, which run now by kind
        self.started = {}
        self.failed = {}
        self.forced = set()
        self.reading = {}
        ## whether the screen has a reader of operations: only then does a window wait for rows
        self.reads = False
        ## the counters of the status lines, by name, each from the read that counts it
        self.counters = {}
        ## how wide the left pane is now: what its own lines are broken to; and how wide it
        ## is on the terminal, whether its lines are wrapped or not (blocksView)
        self.viewWidth = 0
        self.paneWidth = 0
        self.viewHeight = 0
        ## the levels the last good answer of each list read filled: read key -> level keys
        self.levelsOf = {}
        ## the calls that act, asked for and not started yet, in their order, and what each
        ## call that was asked for is about, by its key (askCall)
        self.calls = []
        self.asked = {}
        ## what the last call that acted answered, shown while the item it was asked on
        ## stays selected: {"key", "lines"}
        self.answer = None
        ## what the kill that is being confirmed would do, as its plan was last read: read
        ## key -> {"words", "rows", "error"} (applyResult, killPlanOf)
        self.plans = {}
        ## what was asked to be started with the whole terminal, and is at the end of the
        ## turn of its key: {"label", "said", "words", "directory"} (askRun, runChild)
        self.child = None
        ## the operation the big output dialog runs and follows, from its start to its end:
        ## {"key", "label", "words", "started", "stop", "rest"} (runFollowed, followResult)
        self.follow = None
        ## the locations as the rule of the locations last took them from their rows: those
        ## rows, the key of each path, and the pattern that finds one in a text (placesKnown)
        self.placed = None
        ## the item the selection rests on, and since when (restLeft)
        self.restKey = None
        self.restSince = 0.0
        ## when each read that is made on demand alone last answered, by its key: the clock
        ## of the screen then (applyResult)
        self.ran = {}
        ## the item the reads of the focus were last made for, or found fresh (startDueReads)
        self.focusSeen = None
        ## what the last frame was drawn as: its size, its style and its split; the dialog or the menu over it (drawScreen)
        self.drawnAs = None
        self.quit = False

