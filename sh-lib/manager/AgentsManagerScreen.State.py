##
## AgentsManagerScreen.State.py -- the declaration of the dialogs and of the actions, and the state of the screen (ManagerState).
## A part of the manager screen (LocalManagerScreen.py of `myx.distro-.local`): that file executes it, in its own namespace and in the
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
## The handler of each dialog that does something: handler(state, dialog, button) is called
## when a button other than "cancel" is pressed. It gives nothing, and the dialog closes;
## or it gives what it refuses, which then stands in the dialog, and the dialog stays open.
## Set where each is defined.
## The dialogs that hold a plan read while they are open (full:{kind}): the reads of those are kept alive and asked for again while one is open (Reads.py). A part that
## declares such a dialog names it here, once, by readingDialogs.
READING_DIALOGS = ()


def readingDialogs(*names):
    global READING_DIALOGS
    READING_DIALOGS = READING_DIALOGS + tuple(names)


## What Esc does in a dialog where it does more than close it: escape(state, dialog) gives
## True where it did what Esc does there, and the dialog stays. Set where each is defined.
DIALOG_ESCAPES = {}
## The one key a dialog takes beside the keys of its controls: its name, the word the status line gives it and
## what it does, handler(state, dialog). Set where each is defined.
DIALOG_KEYS = {}
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
        ## the filter of the list typed with `/` (F11.12): the words that narrow the rows
        ## already read, and whether its line is open
        self.listFilter = ""
        self.listFilterOpen = False
        ## whether the left window shows the full table of the level instead of the selected
        ## row's own view (F11.12)
        self.fullTable = False
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
        ## the level a command asked to be taken to once it is over (goLink)
        self.goTo = None
        ## the mouse setting was changed and the terminal is to be told (screenTurn)
        self.mouseAsk = False
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
        ## The reads of views that have answered, by their read key: the wait and the empty state ask
        ## this, not a slot that may be empty or stale.
        self.answered = {}
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
        ## the wizard that is being answered, from its start to its end: {"name", "context", "data", "answers", "step"} (startWizard)
        self.wizard = None
        ## the locations as the rule of the locations last took them from their rows: those
        ## rows, the key of each path, and the pattern that finds one in a text (placesKnown)
        self.placed = None
        ## the item the selection rests on, and since when (restLeft)
        self.restKey = None
        self.restSince = 0.0
        ## when the screen last heard anything: a key, a read that ended, an operation that ran
        ## (screenTurn). An idle screen turns slower than a busy one (keyWait).
        self.movedAt = 0.0
        ## when each read that is made on demand alone last answered, by its key: the clock
        ## of the screen then (applyResult)
        self.ran = {}
        ## the item the reads of the focus were last made for, or found fresh (startDueReads)
        self.focusSeen = None
        ## what the last frame was drawn as: its size, its style and its split; the dialog or the menu over it (drawScreen)
        self.drawnAs = None
        ## D5 (--filter/--dialog of a start): the filter a start names, applied once the first turn
        ## has built the left window (runScreen); the one dialog a start shows, and the words it holds.
        self.startFilter = ""
        self.singleDialog = None
        self.singleText = ""
        self.quit = False

