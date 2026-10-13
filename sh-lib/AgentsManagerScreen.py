#!/usr/bin/env python3
##
## AgentsManagerScreen.py -- the manager screen of the agents console: what
## `DistroAgentsConsole.sh --manager` shows, started by `DistroAgentsTools.fn.sh
## --intern-manager`. It looks as a Turbo Vision program does: a menu bar, a desktop with
## two windows tiled on it, the list on the right and what is selected there on the left,
## a status line, and dialogs over them. What it is made of is declared as data, its
## windows (WINDOWS), its menus (MENUS), its commands with their keys (COMMANDS) and its
## dialogs (DIALOGS), and one small engine draws them and routes the keys.
##
## The screen only draws and takes keys. What it shows and what it does goes
## through operations of the tooling, each run as a process of its own (READS,
## CALLS, OperationReader), so that another front end can use the same operations.
## It reads no file of a session and no registry itself, and it signals no process
## and starts no CLI itself: a kill, a start and the start of a control thread are
## operations too. The one thing it starts itself is what `Consoles (Tools)` lists: a
## console, as a child that is given the whole terminal, from the words an operation
## printed for it, and the screen takes the terminal back when that child ends.
##
## The logic is plain functions over one state (ManagerState): the layout, the
## levels of the list, the selection, the focus, the filter, what a key does and
## which read is due. The drawing goes through a surface: the terminal here
## (CursesSurface), and in a test a stand-in that keeps the cells it was given
## (sh-test/check-fixtures/manager-screen.driver.test.py).
##

import datetime
import locale
import os
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unicodedata

try:
    import curses
except ImportError:
    curses = None

PREFIX = "⛔ ERROR: AgentsManagerScreen:"

## Below this size nothing is drawn but one line that says so.
MIN_COLUMNS = 40
MIN_LINES = 8
## How long the screen waits for a key before it looks at its reads and its clock again.
TURN_SECONDS = 0.2
## The period on which what is shown is read again. Fixed here: what one read costs is not measured yet.
REFRESH_SECONDS = 10.0
## How long the selection rests on an item before the reads of that one item start: while
## a key is held and the selection runs down a list, nothing is read for the rows it passes.
REST_SECONDS = 1.0 / 3

## How a text is drawn. The first four are the looks every terminal has, and what the rows
## and the lines of a window are drawn in. After them come the parts of the frame of the
## screen. Each has in LOOKS, at its number: the letter a test reads a cell's look back
## as; the look it takes on a terminal with no colours, "B" bold, "R" reverse, "D" dim,
## two of them together where two are named; and where the terminal has eight colours its
## text, its ground, and whether the text is bright. A surface maps them to what its
## terminal has (CursesSurface).
PLAIN, BOLD, REVERSE, DIM = 0, 1, 2, 3
DESKTOP, BAR, BAR_HOT, BAR_AT, BAR_ON, BAR_ON_HOT, BAR_OFF, FRAME_ON, FRAME, SCROLL, SHADOW = 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
BOX, BOX_FRAME, BOX_FIELD, BOX_ON, BOX_BUTTON, BOX_BUTTON_ON, BOX_SAYS = 15, 16, 17, 18, 19, 20, 21
FOLDER = 22
LOOKS = (
    ## the text of a window; what stands out in it; the row the selection is on; what is of less weight
    (".", "", "white", "blue", False),
    ("B", "B", "white", "blue", True),
    ("R", "R", "black", "cyan", False),
    ("D", "D", "cyan", "blue", False),
    ## the desktop under the windows
    ("d", "D", "blue", "white", False),
    ## the menu bar, the status line and a pull-down menu; a hot letter or a key in them;
    ## the `@` between the workspace and the machine; the menu that is open and the item
    ## the bar is on, and a hot letter there; an item that does not apply
    ("m", "R", "black", "white", False),
    ("h", "RB", "red", "white", False),
    ("@", "RB", "blue", "white", False),
    ("o", "", "black", "green", False),
    ("O", "B", "red", "green", False),
    ("x", "RD", "black", "white", True),
    ## the frame of the active window, with its title, and of another; a scroll bar
    ("F", "B", "white", "blue", True),
    ("f", "", "white", "blue", False),
    ("s", "", "blue", "cyan", False),
    ## the shadow of what lies over the desktop: a menu, a dialog
    ("w", "D", "black", "black", True),
    ## a dialog: its text; its frame with its title; a field to type in or to pick from; the
    ## control, or the item of one, that has the keys; a button, and the one that has the
    ## keys; what the dialog refuses
    ("g", "R", "black", "white", False),
    ("G", "RB", "white", "white", True),
    ("i", "", "white", "blue", False),
    ("I", "B", "white", "cyan", True),
    ("b", "R", "black", "green", False),
    ("n", "B", "white", "green", True),
    ("!", "RB", "red", "white", False),
    ## the mark of a folder after the name of a row that Enter enters
    ("e", "B", "yellow", "blue", True),
)
## The letter a look without colours reads back as.
MONO_LETTERS = {"": ".", "B": "B", "R": "R", "D": "D", "RB": "H", "RD": "d"}

## The marks of the drawing. plainMarks() changes them for a terminal that is not UTF-8.
## A frame is its corner at the top left, its line across, its corner at the top right,
## its line down, and its corners at the bottom; "rule" is the line that parts two groups
## of a menu, with its ends.
MARKS = {"separator": "│", "cut": "…", "plain": False,
         "frame": "┌─┐│└┘", "frameOn": "╔═╗║╚╝", "rule": "├─┤", "shade": "░", "system": "≡",
         "barUp": "▲", "barDown": "▼", "barTrack": "▒", "barThumb": "■", "on": "•",
         ## what stands after the name of a row that Enter enters, a folder: never what is cut
         "folder": "..."}
MARK_SELECTED = ">"
MARK_READING = "~"
MARK_OLD = "!"

## The root of the list, in its order: the id of each section and what it shows as.
SECTIONS = (
    ("sessions", "Sessions (Activity)"),
    ("pending", "Pending Questions"),
    ("team", "Team Members"),
    ("consoles", "Consoles (Tools)"),
    ("settings", "Settings (Configuration)"),
)
ROOT_TITLE = "/"
ROW_UP = ".."
## The rows a level always holds, ahead of the rows its operation gives:
## id, what it shows as, kind, whether Enter dives into it.
FIXED_ROWS = {
    "sessions": (("launch", "Launch / Spawn", "launch", True),),
    "sessions/launch": (("free", "Free prompt", "free", False),),
}

## What each level of the list and each view of the left pane asks the tooling for: the
## operation with its arguments, as the dispatcher takes them, and under "active" what the
## `a` filter adds. None: no operation yet, the task of that level or view names it.
## A level below a record is named with `*` in the place of that record's id, and {level}
## in an argument is that id. A view is named by its level and the kind of the row that is
## selected there, and {id} in an argument is the id of that row. An entry with "always" is
## read whatever is shown, since a status line counts by it, and "kind" then names the kind
## it runs as, beside the one list and the one view that are shown. "rows" names the form
## of what a list operation prints (parseLevels). A level with "from" has no read of its
## own: the read named there fills it. Beside the "view" of a row, its facts, stands its
## "feed", its lines, read as a kind of its own; "log" is what `l` adds to it. "needs"
## names what a row must carry for the read to be made at all. "acts" is what can be done
## with a row, read as one more part of it (VIEW_PARTS). "once": it is read when it is asked
## for, and never again because its period has passed (startDueReads).
VIEW_PARTS = ("view", "feed", "acts")
READS = {
    ## The coworking sessions with their runs, and last the row of counters of the status lines.
    "list:sessions": {"operation": ["--manager-session-list"], "active": ["--active"],
                      "rows": "sessions", "kind": "sessions", "always": True},
    ## The routines the members carry, each with whether the session spawner would start it.
    "list:sessions/launch": {"operation": ["--manager-routine-list"], "rows": "routines"},
    ## The agents of one session come with the list of the sessions.
    "list:sessions/*": {"from": "list:sessions"},
    ## The asks that wait, every owner's. The member named filters nothing with --any-owner; it
    ## is the one the tooling's own read of every owner's asks names (the heartbeat's input scan).
    "list:pending": {"operation": ["--member-pending-reply-read", "magic-coordinator", "--any-owner"],
                     "rows": "pending"},
    ## The members of the team as this workspace knows them, one row each.
    "list:team": {"operation": ["--manager-team-member-list"], "rows": "members"},
    ## The settings of the workspace as they are, by subject. For viewing: no call changes one.
    "list:settings": {"operation": ["--manager-config-digest"], "rows": "digest"},
    ## What is started from here with the whole terminal, in the order of a menu: the consoles
    ## of the workspace, each with the folder it starts in and its command, a field a word (STARTS).
    "list:consoles": {"operation": ["--manager-console-list"], "rows": "starts"},
    "view::section": None,
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
    ## One ask, whole: what the stores hold of it.
    "view:pending:record": {"operation": ["--member-pending-reply-read", "magic-coordinator", "{id}"],
                            "rows": "ask", "needs": "ask"},
    ## What can be done with one ask from the console: the row of the question, with whether it
    ## takes words, a reject and a dismissal and with the link of its message, and a row for
    ## each answer it takes. Read as a part of its own, "acts", beside the view of the ask.
    "acts:pending:record": {"operation": ["--manager-pending-reply-read", "--id", "{id}"],
                            "rows": "ask-acts", "needs": "ask"},
    ## One member, whole: its information, the sessions it is in, its grants and its settings.
    "view:team:record": {"operation": ["--manager-team-member-read", "{id}"], "rows": "member-read", "needs": "member"},
    ## What the kill of a session, and of one agent, would do, and nothing is done: the rows
    ## of the kill itself, each with what would become of it (KILL_ROWS). Read when the
    ## confirmation of that kill opens, and once more when it is confirmed (submitKill), by
    ## the id it names, as a kind of its own; never on the period, so what the confirmation
    ## says does not change under the word typed into it.
    "plan:kill:session": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--plan"], "rows": "kill", "kind": "plan", "once": True},
    "plan:kill:run": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--run", "--plan"], "rows": "kill", "kind": "plan", "once": True},
}

## What each action asks the tooling for: the operation with its arguments, {id} the id of
## what it acts on. The screen itself signals no process and starts no CLI. A session's id
## finishes that session: every live run of it is ended, its questions that wait are
## dismissed and its records left open are closed; `--run` takes the id as a run's own, so on the row of an
## agent that agent alone is ended, the founder too, whose id is its session's. A start
## names its routine by its selector, or takes the standing default routine with what was
## typed as its task text, which goes on standard input and is never a word of the command.
## One member is started by its name, with what was typed as its prompt, on standard input too.
## The control thread of a session is started again by the id of that session: whether one
## is started is the operation's to say, which starts none where one lives or none is needed.
CALLS = {
    "kill:session": ["--manager-session-kill", "--session-id", "{id}"],
    "kill:run": ["--manager-session-kill", "--session-id", "{id}", "--run"],
    "control": ["--manager-session-control-start", "--session-id", "{id}"],
    "launch": ["--magic-spawn-session", "--routine", "{id}"],
    "prompt": ["--magic-spawn-session", "--routine-default"],
    "start": ["--manager-spawn-member", "{id}"],
    ## a pending question is answered, rejected by the negative answer of its kind, or
    ## dismissed, by its id; the answer chosen or typed is the word after --answer
    "answer": ["--manager-pending-reply-answer", "--id", "{id}", "--answer"],
    "reject": ["--manager-pending-reply-answer", "--id", "{id}", "--reject"],
    "dismiss": ["--manager-pending-reply-dismiss", "--id", "{id}"],
    ## a setting that offers choices is saved for the user who runs the console, by its
    ## key, the value chosen being the word after it
    "set": ["--manager-config-set", "{id}"],
}
## What each of those is given the words typed beside it with, where any were typed.
CALL_WORDS = {"answer": "--text", "reject": "--text", "dismiss": "--reason"}
## What a start names its session with, ahead of the name.
CALL_NAME = "--session-name-or-comment"
## The word that confirms a kill, typed whole.
KILL_WORD = "yes"
## The state of a session that is finished, as its row of the list gives it: such a one
## takes no kill, since nothing of it is left to end, to dismiss or to close.
SESSION_FINISHED = "finished"
## What the confirmation of a kill says in its own line between the press of its button
## and the deed: while its plan is read once more; where the plan was not read yet; and
## where the plan read then is not the one the confirmation showed.
KILL_SAYS = {
    "checking": "its plan is read once more: it is done if nothing of it has changed",
    "unread": "nothing is done yet: its plan is still being read",
    "changed": "nothing was done: its plan changed while this stood open. It stands above as it is now: type the word again",
}

## What the root `Consoles (Tools)` holds: the things that are started with the whole
## terminal, each sort by the name of the row its operation prints for one. "fields": the
## names of the fields of such a row after the first, written as the family writes them,
## `_` for a blank and `-` for absent. The fields after those are exact, as they are
## printed, and are never rewritten: the folder it is started in, and then its command,
## a field a word, the first the program. "terminal": the word of its field of that name
## that says it needs a terminal. "said": what one of that sort is called where the screen
## speaks of it. Another sort of thing to start is one more entry here: its rows come in
## the same list, and Enter starts it the same way (askRun, runChild).
STARTS = {
    "console": {"fields": ("key", "group", "label", "terminal"), "terminal": "terminal", "said": "console"},
}

## ---- the declaration of the screen: its styles, its windows, its menus, its commands ----

## The styles of the interface, in the order the screen offers them: the name of each, and
## what it is. "label": what it shows as. "frames": the windows stand in frames on a desktop,
## under a menu bar and over a status line; without them the screen is compact, two panes
## between two status lines with one column between them and nothing spent on frames.
## "colours": it is drawn in the colours of LOOKS where the terminal has them; without them,
## and on a terminal that has none, in bold, reverse and dim alone. "keys": its key map,
## an entry of KEYMAPS. The same windows, menus,
## commands and keys are drawn in every style: adding a style is adding an entry here.
STYLES = (
    ("tv", {"label": "Turbo Vision", "frames": True, "colours": True, "keys": "tv"}),
    ("mc", {"label": "MC (Compact)", "frames": False, "colours": False, "keys": "mc"}),
    ("bw", {"label": "B/W", "frames": True, "colours": False, "keys": "tv"}),
)
## The key maps: the key map is the style's ("keys" there names it). Each gives the keys of
## the commands whose keys are not the same in every style, by the name of the command;
## every other command has the keys COMMANDS gives it. Turbo Vision's map ends the screen
## with Ctrl-X, which every terminal delivers with no setting and which is the key its
## status line and its menu name, with Alt-X and by the Exit item of its menu, and a bare
## `q` does nothing there; the compact style keeps the map the screen had before it had
## styles, with `q`.
KEYMAPS = {
    "tv": {"exit": ("CTRL-x", "ALT-x")},
    "mc": {"exit": ("q", "CTRL-x", "ALT-x")},
}
## What the Option key of a Mac types with a letter or a digit on a US layout, where the
## terminal does not send Option as Meta: each counts as Alt with that key, for the keys
## the screen takes with Alt, outside a dialog, where it is text. On another layout these
## do not come, and nothing is taken for them.
OPTION_KEYS = {"≈": "x", "©": "g", "ß": "s", "µ": "m", "√": "v", "˙": "h", "œ": "q",
               "¡": "1", "™": "2", "£": "3", "¢": "4", "∞": "5", "§": "6"}
## Esc and then a key within this many seconds is Alt with that key, where no menu and no
## dialog is open: the Meta every terminal delivers, also one that sends no Alt and keeps
## the function keys for itself. Esc alone closes a menu and a dialog at once, as before.
META_SECONDS = 1.0
## The style a screen starts in where nothing names another, and the variable of the
## environment that names one for a start.
STYLE_FIRST = "tv"
STYLE_VARIABLE = "MDAT_MANAGER_STYLE"
## The style the screen is drawn in now: its entry of STYLES, and under "name" its name.
STYLE = dict(dict(STYLES)[STYLE_FIRST], name=STYLE_FIRST)


## Takes the style of that name for what is drawn from now on. Gives whether there is one.
def setStyle(name):
    if name not in dict(STYLES):
        return False
    STYLE.clear()
    STYLE.update(dict(STYLES)[name], name=name)
    return True



## The windows of the desktop, tiled. Each is declared by its name; the function that gives
## its title, which stands in the middle of its top border; its place, the side it stands
## on and, for one that does not take the rest, how many tenths of the width; what it
## shows; and the commands that apply in it alone. "shows" names the body the engine
## draws in it, "rows" a list with a selection or "lines" what is selected there, and the
## entries of READS it is filled from, by what their names begin with: the operation and
## the form of its rows stand there. "foot" names the function whose text stands in its
## bottom border, and "bar" says that its right border is a scroll bar while it holds more
## than it shows. A command that no window names applies in every window.
WINDOWS = (
    {"name": "view", "title": "viewTitle", "place": {"side": "left"},
     "shows": {"body": "lines", "reads": VIEW_PARTS}, "foot": "countersText",
     "commands": ()},
    {"name": "list", "title": "listTitle", "place": {"side": "right", "tenths": 3},
     "shows": {"body": "rows", "reads": ("list",)}, "foot": "loadText", "bar": True,
     "commands": ("launch", "prompt", "answer", "reject", "dismiss", "link", "setting", "run", "open", "up", "filter")},
)
## The window the keys go to when the screen starts.
WINDOW_FIRST = "list"
## The modes of the left window for a thing that has a log, a session or an agent: one at
## a time, never mixed. "label": what a mode shows as in a menu and in the status line;
## "mark": what stands for it in the title of the window; "feed": whether it shows the
## lines of the thing, read by the "feed" of READS, in place of its facts; "raw": whether
## those lines are the raw log. The mode is the user's for the run of the screen: it is
## kept whatever is selected, entered or read. A thing with no log has its summary alone.
VIEW_MODES = (
    ("summary", {"label": "Summary", "mark": "[summary]", "feed": False, "raw": False}),
    ("log", {"label": "Log", "mark": "[log]", "feed": True, "raw": False}),
    ("raw", {"label": "Raw log", "mark": "[raw]", "feed": True, "raw": True}),
)
VIEW_MODE_FIRST = "summary"

## The menus of the menu bar, in their order: the name of each and what it shows as, its hot
## letter between tildes. Alt with that letter opens it, and F10 opens the first.
## A menu is in the bar while it holds a command of the view, the level the list is at
## (menusShown): one whose commands are all of other views is not there. `Go`, `View` and
## `Help` hold commands of every view, so they are always there.
MENUS = (
    ("go", "~G~o"),
    ("session", "~S~ession"),
    ("member", "~M~ember"),
    ("console", "~C~onsole"),
    ("view", "~V~iew"),
    ("question", "~Q~uestion"),
    ("help", "~H~elp"),
)

## The commands, each declared once. "keys": its keys, the first being the one its menu and
## the status line show, where the key map of the style gives it no others (KEYMAPS). The
## first is always a key every terminal delivers: a function key and Alt with a letter do
## not arrive from every terminal, so a function key and Alt with a key stand second,
## behind a key that needs neither, and Alt with a letter is also Esc and then that letter
## (META_SECONDS) and what the Option key of a Mac types with it (OPTION_KEYS). "menu": its menu and its group there, a line parting two groups,
## and "label" what it shows as there, its hot letter between tildes. "status": its word in
## the status line, shown while it applies; a command that toggles how a view shows names
## under "toggle" what it toggles in the state, which is kept for the run of the screen
## whatever is selected, and has two words there, what its key will do while that is off
## and while it is on. "on": the rows it acts on, by their level and
## kind; with none it acts wherever its window has the keys. "views": the views it belongs
## to, each a level of the list named as "on" names one; with none it belongs to every
## view. In a view all its commands stand in their menus and have their keys, and a
## command of another view is in no menu there and its key is not its key. One that
## belongs to the view and does not apply to what is selected is greyed in its menu, is
## not chosen, and says why in one line of the status line when it is tried, by its key
## or by a click (commandRefusal); "for" names in that line what it acts on. "asks": whether
## it does anything is its operation's to say, so it applies to every row it is for, and
## what ACTION_FITS says of a row only keeps it out of the status line. "only": its key is its own on
## those rows alone, and another command's elsewhere. "tells": its key is its own only on
## the rows its action acts on as they are now (ACTION_FITS), where it tells in a dialog why
## another command of that key does nothing there; elsewhere the key is the next command's
## that has it, and the left window does not name it among the keys of the item. "does": what it does. ("action",
## <name>) is the handler of that action (ACTION_HANDLERS) with the selected row, which
## asks first where it must and then calls the operations "calls" names in CALLS; while
## its handler is not built the command does not apply. ("go", <path>) takes the list to
## that level. ("move", <rows>, <pages>) moves in the active window. The others are the
## engine's own: "open", "up", "focus", "filter", "read", "menu", "style", "quit", and
## ("mode", <name>), which takes the left window to that mode of VIEW_MODES, or to the
## next one where it names none. A command comes
## to a menu, to the status line and to its key from this one place: adding one is adding
## an entry here. Where two commands share a key, the first that applies has it. "says":
## the word the left window names the key of an "only" command by, where it starts nothing.
## "enters": Enter on a row it acts on enters that row, so the row is drawn as a folder is,
## as a row that dives into a level of its own is (rowEnters).
COMMANDS = (
    {"name": "help", "keys": ("?", "F1"), "menu": ("help", 1), "label": "~K~eys",
     "does": ("action", "help")},
    {"name": "read", "keys": ("u", "F5"), "menu": ("view", 1), "label": "~R~ead now", "status": "Read",
     "does": ("read",)},
    {"name": "menu", "keys": ("m", "F10"), "status": "Menu", "does": ("menu",)},
    {"name": "exit", "keys": ("CTRL-x", "ALT-x"), "menu": ("go", 4), "label": "E~x~it", "status": "Exit",
     "does": ("quit",)},
    {"name": "unstarted", "keys": ("ENTER", "RIGHT"),
     "views": ("sessions/launch",), "for": "a routine that cannot be started", "on": ("sessions/launch:record",), "only": True, "tells": True, "does": ("action", "unstarted")},
    {"name": "launch", "keys": ("ENTER",), "menu": ("session", 2), "label": "Start the ro~u~tine", "status": "Start",
     "views": ("sessions/launch",), "for": "a routine", "on": ("sessions/launch:record",), "only": True, "does": ("action", "launch"), "calls": ("launch",)},
    {"name": "prompt", "keys": ("ENTER",), "menu": ("session", 2), "label": "~F~ree prompt", "status": "Start",
     "views": ("sessions/launch",), "for": "the free prompt", "on": ("sessions/launch:free",), "only": True, "does": ("action", "prompt"), "calls": ("prompt",)},
    {"name": "answer", "keys": ("ENTER", "y"), "menu": ("question", 1), "label": "~A~nswer", "status": "Answer",
     "views": ("pending",), "for": "a question", "on": ("pending:record",), "only": True, "says": "answer", "does": ("action", "answer"), "calls": ("answer",)},
    {"name": "reject", "keys": ("j",), "menu": ("question", 1), "label": "Re~j~ect", "status": "Reject",
     "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "reject"), "calls": ("reject",)},
    {"name": "dismiss", "keys": ("d",), "menu": ("question", 1), "label": "~D~ismiss", "status": "Dismiss",
     "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "dismiss"), "calls": ("dismiss",)},
    {"name": "link", "keys": ("o",), "menu": ("question", 2), "label": "Show the ~l~ink", "status": "Link",
     "views": ("pending",), "for": "a question", "on": ("pending:record",), "does": ("action", "link")},
    {"name": "setting", "keys": ("ENTER",), "menu": ("view", 3), "label": "~C~hange the setting", "status": "Change",
     "views": ("settings",), "for": "a subject of the settings", "on": ("settings:record",), "only": True, "enters": True, "says": "change", "does": ("action", "setting"), "calls": ("set",)},
    {"name": "run", "keys": ("ENTER",), "menu": ("console", 1), "label": "~S~tart", "status": "Start",
     "views": ("consoles",), "for": "something to start", "on": ("consoles:record",), "only": True, "says": "start", "does": ("action", "run")},
    {"name": "open", "keys": ("ENTER", "RIGHT"), "menu": ("go", 3), "label": "~O~pen", "status": "Open",
     "does": ("open",)},
    {"name": "up", "keys": ("LEFT",), "menu": ("go", 3), "label": "~U~p one level", "status": "Up",
     "does": ("up",)},
    {"name": "focus", "keys": ("TAB", "F6"), "menu": ("view", 2), "label": "~N~ext window", "status": "Window",
     "does": ("focus",)},
    {"name": "filter", "keys": ("a",), "menu": ("view", 1), "label": "~A~ll or active", "status": ("Active", "All"), "toggle": "activeOnly",
     "does": ("filter",)},
    {"name": "style", "keys": ("i", "F9"), "menu": ("view", 3), "label": "Interface ~s~tyle: the next", "does": ("style",)},
    {"name": "kill", "keys": ("k",), "menu": ("session", 1), "label": "~K~ill", "status": "Kill",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "kill"), "calls": ("kill:session", "kill:run")},
    {"name": "control", "keys": ("c",), "menu": ("session", 1), "label": "~C~ontrol thread", "status": "Control",
     "views": ("sessions", "sessions/*"), "for": "a session", "asks": True, "on": ("sessions:record",), "does": ("action", "control"), "calls": ("control",)},
    {"name": "pause", "keys": ("p",), "menu": ("session", 3), "label": "~P~ause",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "pause")},
    {"name": "resume", "keys": ("r",), "menu": ("session", 3), "label": "~R~esume",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "resume")},
    {"name": "stop", "keys": ("s",), "menu": ("session", 3), "label": "~S~top",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "stop")},
    {"name": "restart", "keys": ("R",), "menu": ("session", 3), "label": "Res~t~art",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("action", "restart")},
    {"name": "mode", "keys": ("v",), "menu": ("view", 4), "label": "Ne~x~t mode of the left window",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "")},
    {"name": "mode-summary", "keys": ("b",), "menu": ("view", 4), "label": "Su~m~mary", "status": "Summary",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "summary")},
    {"name": "mode-log", "keys": ("l",), "menu": ("view", 4), "label": "~L~og", "status": "Log",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "log")},
    {"name": "mode-raw", "keys": ("g",), "menu": ("view", 4), "label": "Ra~w~ log", "status": "Raw log",
     "views": ("sessions", "sessions/*"), "for": "a session or an agent", "on": ("sessions:record", "sessions/*:record"), "does": ("mode", "raw")},
    {"name": "start", "keys": ("n",), "menu": ("member", 1), "label": "~S~tart", "status": "Start",
     "views": ("team",), "for": "a team member", "on": ("team:record",), "does": ("action", "start"), "calls": ("start",)},
    {"name": "sessions", "keys": ("1", "ALT-1"), "menu": ("go", 1), "label": "~S~essions (Activity)",
     "does": ("go", ("sessions",))},
    {"name": "pending", "keys": ("2", "ALT-2"), "menu": ("go", 1), "label": "~P~ending Questions",
     "does": ("go", ("pending",))},
    {"name": "team", "keys": ("3", "ALT-3"), "menu": ("go", 1), "label": "~T~eam Members",
     "does": ("go", ("team",))},
    {"name": "consoles", "keys": ("6", "ALT-6"), "menu": ("go", 1), "label": "Co~n~soles (Tools)",
     "does": ("go", ("consoles",))},
    {"name": "settings", "keys": ("4", "ALT-4"), "menu": ("go", 1), "label": "Settings (~C~onfiguration)",
     "does": ("go", ("settings",))},
    {"name": "spawn", "keys": ("5", "ALT-5"), "menu": ("go", 2), "label": "~L~aunch / Spawn",
     "does": ("go", ("sessions", "launch"))},
    {"name": "line-up", "keys": ("UP",), "does": ("move", -1, 0)},
    {"name": "line-down", "keys": ("DOWN",), "does": ("move", 1, 0)},
    {"name": "page-up", "keys": ("PGUP",), "does": ("move", 0, -1)},
    {"name": "page-down", "keys": ("PGDN",), "does": ("move", 0, 1)},
)
## What the status line shows in place of the commands while something else has the keys:
## a pull-down menu, the line to type in. Each a key and its word. A dialog names its own
## keys, from CONTROL_KINDS. The status line names no key but those that act for what has
## the keys now.
STATUS_KEYS = {
    "menu": (("Enter", "Choose"), ("Esc", "Close"), ("Left/Right", "Menus"), ("Up/Down", "Items")),
    "line": (("Enter", "OK"), ("Esc", "Cancel")),
}
## How the name of a key shows in a menu and in the status line, where it is not its own name.
KEY_WORDS = {"ENTER": "Enter", "TAB": "Tab", "ESC": "Esc", "LEFT": "Left", "RIGHT": "Right",
             "UP": "Up", "DOWN": "Down", "PGUP": "PgUp", "PGDN": "PgDn"}
## What the status line says when a command of the view is tried and does not apply, by
## why it does not; %s is the command as its menu names it. "window": the other window has
## the keys; "unbuilt": its action is not built; "row": what is selected is not what it
## acts on, and "rowFor" the same of a command that names what it acts on ("for"); "fits":
## its action does not act on that row as it is now and says no more itself
## (ACTION_REFUSALS); "mode": what is selected has no log; "up": the list has no level
## above; "open": the row has no level of its own.
REFUSALS = {
    "window": "%s: the other window has the keys (Tab)",
    "unbuilt": "%s is not built yet",
    "row": "%s: not for what is selected",
    "rowFor": "%s: for %s, not for what is selected",
    "fits": "%s: not for what is selected, as it is now",
    "mode": "%s: what is selected has no log",
    "up": "%s: this is the top level",
    "open": "%s: this row has nothing to open",
}

## ---- the declaration of the dialogs ----

## The kinds of control a dialog is made of. "focus": whether the keys go to one of that
## kind. "keys": the keys it takes while they do, each as the status line names it, with
## its word. Tab and Shift-Tab go to the next control and to the one before, Enter presses
## the first button of the dialog, or the button the keys are on, and Esc closes it and
## does nothing: those are every dialog's.
CONTROL_KINDS = {
    ## a text, broken to the dialog; one longer than its room scrolls
    "text": {"focus": False, "keys": ()},
    ## one line to type in
    "input": {"focus": True, "keys": ()},
    ## several lines to type in: Enter there is a new line, and a button is reached by Tab
    "area": {"focus": True, "keys": (("Enter", "New line"),)},
    ## boxes, any number of them checked: [X]
    "checks": {"focus": True, "keys": (("Space", "Toggle"), ("Up/Down", "Move"))},
    ## radio buttons, one of them chosen: (*)
    "radios": {"focus": True, "keys": (("Space", "Choose"), ("Up/Down", "Move"))},
    ## a list: the row its bar is on is the one picked
    "list": {"focus": True, "keys": (("Up/Down", "Pick"),)},
    ## a button of the dialog
    "button": {"focus": True, "keys": (("Left/Right", "Buttons"),)},
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
    ## what the screen refuses, and what an operation answered when it failed, whole
    "message": {"title": "Message", "controls": ({"name": "text", "kind": "text"},),
                "buttons": (("ok", "OK"),)},
    ## why something cannot be done with what is selected, set out by its facts
    "information": {"title": "Information", "controls": ({"name": "text", "kind": "text"},),
                    "buttons": (("ok", "OK"),)},
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
    ## a prompt and who runs it: the free prompt of `Launch / Spawn`, and the start of one
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
    ## a setting that offers choices: what it is now, and its choices, one of them chosen
    "setting": {"title": "Setting", "feeds": "setting",
                "controls": ({"name": "about", "kind": "text"},
                             {"name": "choice", "kind": "radios", "label": "Choices"}),
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
## The width a dialog takes at most, and how many lines of a list of options and of a
## field of several lines it shows, where the terminal has them.
DIALOG_COLUMNS = 78
DIALOG_OPTIONS = 8
DIALOG_AREA = 4

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
    ## Enter on a routine of `Launch / Spawn`, and on its free prompt: askLaunch and askPrompt, set where they are defined
    "launch": None,
    "prompt": None,
    ## Enter and Right on a routine of `Launch / Spawn` that cannot be started: askUnstarted, set where it is defined
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
    ## Enter on a subject of the settings that offers choices: askSetting, set where it is defined
    "setting": None,
    ## Enter on a row of `Consoles (Tools)`: it is started with the whole terminal: askRun, set where it is defined
    "run": None,
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
        ## the selection of each level: level key -> {"key", "index", "top"}
        self.cursors = {}
        ## which window is active and has the keys: "list" on the right, "view" on the left
        self.focus = WINDOW_FIRST
        ## the pull-down menu that is open: {"menu", "item"}, its place in MENUS and the place
        ## of the item its bar is on
        self.menu = None
        self.activeOnly = False
        ## the rows the last answer of a list gave when it was asked with what its filter
        ## adds: level key -> ids
        self.activeOf = {}
        ## the rows the last good read of each level gave: level key -> rows
        self.rows = {}
        ## the left pane: which item it shows, its lines, the first line in view (newView)
        self.view = newView(None, False)
        ## the mode of the left window of a session or an agent, of VIEW_MODES
        self.viewMode = VIEW_MODE_FIRST
        ## the line to type in while it is open: {"prompt", "text", "onSubmit", "lines"}
        self.line = None
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
        ## the counters of the status lines, by name, each from the read that counts it
        self.counters = {}
        ## how wide the left pane is now: what its own lines are broken to
        self.viewWidth = 0
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
        ## the item the selection rests on, and since when (restLeft)
        self.restKey = None
        self.restSince = 0.0
        self.quit = False


## ---- text in cells ----

## A text as the cells it takes on a terminal: [what is written, how many cells]. A mark
## that joins the character before it stays with that character; an emoji selector makes
## it two cells wide. What a terminal would act on, and not show, is left out.
def textCells(text):
    cells = []
    for character in text:
        if character == "\t":
            character = " "
        codePoint = ord(character)
        category = unicodedata.category(character)
        if codePoint == 0x200D or 0xFE00 <= codePoint <= 0xFE0F or category in ("Mn", "Me"):
            if cells:
                cells[-1][0] += character
                if codePoint == 0xFE0F:
                    cells[-1][1] = 2
            continue
        if category in ("Cc", "Cf", "Cs", "Zl", "Zp"):
            continue
        cells.append([character, 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1])
    return cells


def textWidth(text):
    return sum(cell[1] for cell in textCells(text))


## A text as exactly that many cells: filled with spaces, or cut with the cut mark. A
## character of two cells that no longer fits is left out whole, never drawn in half.
def cutToCells(text, width):
    if width <= 0:
        return ""
    cells = textCells(text)
    total = sum(cell[1] for cell in cells)
    if total <= width:
        return "".join(cell[0] for cell in cells) + " " * (width - total)
    kept = []
    used = 0
    for cluster, clusterWidth in cells:
        if used + clusterWidth > width - 1:
            break
        kept.append(cluster)
        used += clusterWidth
    return "".join(kept) + MARKS["cut"] + " " * (width - 1 - used)


## The end of a text in at most that many cells, and how many it took: what was typed last
## stays in view.
def tailToCells(text, width):
    kept = []
    used = 0
    for cluster, clusterWidth in reversed(textCells(text)):
        if used + clusterWidth > width:
            break
        kept.append(cluster)
        used += clusterWidth
    return "".join(reversed(kept)), used


## A text as lines of at most that many cells, broken between words; a word longer than a
## line is broken where the line ends.
def wrapToCells(text, width):
    lines = []
    line = ""
    used = 0
    for word in text.split():
        wordCells = textCells(word)
        wordWidth = sum(cell[1] for cell in wordCells)
        if used and used + 1 + wordWidth <= width:
            line += " " + "".join(cell[0] for cell in wordCells)
            used += 1 + wordWidth
            continue
        if used:
            lines.append(line)
        while wordWidth > width:
            piece = []
            pieceWidth = 0
            while wordCells and pieceWidth + wordCells[0][1] <= width:
                pieceWidth += wordCells[0][1]
                piece.append(wordCells.pop(0)[0])
            if not piece:
                break
            lines.append("".join(piece))
            wordWidth -= pieceWidth
        line = "".join(cell[0] for cell in wordCells)
        used = wordWidth
    if used or not lines:
        lines.append(line)
    return lines


## For a terminal that is not UTF-8: marks of one byte, and plainText() for what is drawn.
def plainMarks():
    MARKS.update({"separator": "|", "cut": "+", "plain": True, "frame": "+-+|++", "frameOn": "#=#|##", "rule": "+-+",
                  "shade": " ", "system": "=", "barUp": "^", "barDown": "v", "barTrack": ":", "barThumb": "#", "on": "*"})


## A text for a terminal that is not UTF-8: what it cannot show becomes `?`, cell for cell.
def plainText(text):
    return "".join(cell[0] if all(ord(character) < 128 for character in cell[0]) else "?" * cell[1]
                   for cell in textCells(text))


## ---- the layout ----

## Where each window of WINDOWS stands at that size, by its name: its left column, its top
## line, its width and its height, its frame counted in. The windows fill the desktop, the
## lines between the menu bar and the status line: one with tenths takes them of the
## width, on its side, and the one without takes the rest.
def windowBoxes(columns, lines):
    boxes = {}
    left, right = 0, columns
    for window in WINDOWS:
        if "tenths" in window["place"]:
            width = columns * window["place"]["tenths"] // 10
            if window["place"]["side"] == "right":
                right -= width
                boxes[window["name"]] = (right, 1, width, lines - 2)
            else:
                boxes[window["name"]] = (left, 1, width, lines - 2)
                left += width
    for window in WINDOWS:
        if window["name"] not in boxes:
            boxes[window["name"]] = (left, 1, right - left, lines - 2)
    return boxes


## Where everything stands at that size in the style of now, or None where the terminal
## is too small. With frames: the
## first line is the menu bar and the last the status line; between them is the desktop
## with its windows, each in its frame: the list takes three tenths of the width, between
## a quarter and a third, and the window on the left the rest. "viewWidth" is the left
## window less its right border, which stands in the column "separator"; the list stands
## from "listLeft", "listWidth" wide with its frame. Both hold as many lines as the
## desktop has less their borders. "inputLine" is the line of the left window's bottom
## border: the line to type in is drawn there while it is open.
def layoutOf(columns, lines):
    if columns < MIN_COLUMNS or lines < MIN_LINES:
        return None
    if not STYLE["frames"]:
        ## the compact style: the first and the last line are the status lines, the second
        ## holds the titles, one column parts the panes, and the last line of the left pane
        ## is the line to type in, beside which the list goes on
        listWidth = columns * 3 // 10
        viewWidth = columns - listWidth - 1
        return {"columns": columns, "lines": lines, "boxes": None, "viewWidth": viewWidth, "separator": viewWidth,
                "listLeft": viewWidth + 1, "listWidth": listWidth, "topLine": 0, "titleLine": 1, "bodyTop": 2,
                "viewHeight": lines - 4, "listHeight": lines - 3, "inputLine": lines - 2, "bottomLine": lines - 1}
    boxes = windowBoxes(columns, lines)
    listWidth = boxes["list"][2]
    viewWidth = boxes["view"][2] - 1
    return {
        "columns": columns,
        "lines": lines,
        "boxes": boxes,
        "viewWidth": viewWidth,
        "separator": viewWidth,
        "listLeft": viewWidth + 1,
        "listWidth": listWidth,
        "topLine": 0,
        "titleLine": 1,
        "bodyTop": 2,
        "viewHeight": lines - 4,
        "listHeight": lines - 4,
        "inputLine": lines - 2,
        "bottomLine": lines - 1,
    }


## ---- the list: its levels, its rows, its selection ----

def levelKey(path):
    return "/".join(path)


## The name of a level in READS and FIXED_ROWS: a step that is no section and no fixed row
## is the id of a record, and stands as `*`.
def levelPattern(path):
    words = []
    for word in path:
        if words:
            known = [fixed[0] for fixed in FIXED_ROWS.get("/".join(words), ())]
        else:
            known = [section[0] for section in SECTIONS]
        words.append(word if word in known else "*")
    return "/".join(words)


def newRow(rowId, label, kind, dive=False, fields=None):
    return {"id": rowId, "label": label, "kind": kind, "dive": dive, "fields": fields or []}


## What a selection is kept by: the kind of the row and its id.
def rowKey(row):
    return row["kind"] + ":" + row["id"]


## The rows of a level: the root holds the sections; below it the first row goes up, then
## come the rows the level always holds, then the rows its operation gave.
def levelRowsAt(state, path):
    if not path:
        return [newRow(sectionId, sectionLabel, "section", True) for sectionId, sectionLabel in SECTIONS]
    rows = [newRow(ROW_UP, ROW_UP, "up")]
    for rowId, label, kind, dive in FIXED_ROWS.get(levelPattern(path), ()):
        rows.append(newRow(rowId, label, kind, dive))
    listed = state.rows.get(levelKey(path), ())
    if state.activeOnly and levelKey(path) in state.activeOf:
        ## the filter shows what the operation gave when it was last asked for the active
        ## ones, also of an answer read without it: which are active is the operation's to say
        listed = [row for row in listed if row["id"] in state.activeOf[levelKey(path)]]
    rows.extend(listed)
    return rows


def levelRows(state):
    return levelRowsAt(state, state.path)


## The one place where what a list operation printed becomes rows, by level: the entry of
## the read names the form under "rows". "sessions": the sessions, and a level for each
## with its runs. "pending": the asks. "routines": the routines to start by hand.
## "members": the team members. "digest": the subjects of the settings, each with its
## lines. "starts": what is started with the whole terminal. No name: the stand-in below.
def parseLevels(readKey, form, text):
    if form == "sessions":
        return parseSessionLevels(text)
    level = readKey[len("list:"):]
    if form == "pending":
        return {level: parsePendingRows(text)}
    if form == "routines":
        return {level: parseRoutineRows(text)}
    if form == "members":
        return {level: parseMemberRows(text)}
    if form == "digest":
        return {level: parseDigestRows(text)}
    if form == "starts":
        return {level: parseStartRows(text)}
    return {level: parseRows(readKey, text)}


## The stand-in for a list whose task has not said what its operation prints. A line is a
## record and its fields stand between TABs: the first is taken as its id, and the fields
## are what is shown.
def parseRows(readKey, text):
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        rows.append(newRow(fields[0], "  ".join(fields), "record", False, fields))
    return rows


## The selection of the level shown, brought in line with its rows as they are now. It
## stays on the same item, found by its key; where that item is gone it takes the row at
## the same place. The rows in view follow it.
def cursorOf(state, rows, height):
    cursor = state.cursors.setdefault(levelKey(state.path), {"key": None, "index": 0, "top": 0})
    index = cursor["index"]
    for position, row in enumerate(rows):
        if rowKey(row) == cursor["key"]:
            index = position
            break
    index = max(0, min(index, len(rows) - 1))
    cursor["index"] = index
    cursor["key"] = rowKey(rows[index]) if rows else None
    top = cursor["top"]
    if index < top:
        top = index
    if height > 0 and index >= top + height:
        top = index - height + 1
    cursor["top"] = max(0, min(top, max(0, len(rows) - max(height, 1))))
    return cursor


def selectedRow(state):
    rows = levelRows(state)
    if not rows:
        return None
    return rows[cursorOf(state, rows, 0)["index"]]


## The selection moves by rows, or by pages of the pane. It stops at the first and at the
## last row: it never wraps.
def moveSelection(state, height, step, pages=0):
    rows = levelRows(state)
    if not rows:
        return
    cursor = cursorOf(state, rows, height)
    index = max(0, min(cursor["index"] + step + pages * height, len(rows) - 1))
    cursor["index"] = index
    cursor["key"] = rowKey(rows[index])
    cursor["top"] = cursor["top"] + pages * height
    cursorOf(state, rows, height)


def diveIn(state, height):
    rows = levelRows(state)
    if not rows:
        return
    row = rows[cursorOf(state, rows, height)["index"]]
    if row["kind"] == "up":
        goUp(state)
    elif row["dive"]:
        state.path = state.path + [row["id"]]


## Up one level, onto the row that was dived into.
def goUp(state):
    if not state.path:
        return
    left = state.path[-1]
    state.path = state.path[:-1]
    cursor = state.cursors.setdefault(levelKey(state.path), {"key": None, "index": 0, "top": 0})
    for position, row in enumerate(levelRows(state)):
        if row["id"] == left and row["kind"] != "up":
            cursor["key"] = rowKey(row)
            cursor["index"] = position
            break


## ---- the left pane ----

## The level the left window looks at. It is the level shown, with the row selected there;
## but while the selection stands on the row that goes up, or on nothing, inside a
## container, it is the level above, with the row of that container: the left window then
## shows the container itself, as its own row showed it one level up, and the commands
## that act on it apply. One rule for every level: a section at the root, `Launch / Spawn`,
## a session.
def shownPath(state):
    if not state.path:
        return state.path
    row = selectedRow(state)
    return state.path[:-1] if row is None or row["kind"] == "up" else state.path


## While it is entered, the state stands at the level the left window looks at (shownPath),
## the selection of that level on the row of the container: what is asked of the selected
## row in it is asked of what the left window shows. `shift` false leaves the level as it
## is, for a command whose key is its own on the rows of the list alone.
class shownLevel:
    def __init__(self, state, shift=True):
        self.state = state
        self.shift = shift

    def __enter__(self):
        state = self.state
        self.kept = state.path
        if self.shift and not state.shown:
            shown = shownPath(state)
            if shown is not state.path:
                for index, row in enumerate(levelRowsAt(state, shown)):
                    if row["id"] == state.path[-1] and row["kind"] != "up":
                        state.cursors[levelKey(shown)] = dict(state.cursors.get(levelKey(shown), {"top": 0}),
                                                              key=rowKey(row), index=index)
                        break
                state.path = shown
        state.shown += 1
        return state

    def __exit__(self, kind, failure, trace):
        self.state.shown -= 1
        self.state.path = self.kept
        return False


## A function of the state that is about what the left window shows: it runs at that level.
def onShownLevel(function):
    def atShownLevel(state, *arguments):
        with shownLevel(state):
            return function(state, *arguments)
    return atShownLevel


## Which item the left pane shows: the level it looks at and the row selected there.
@onShownLevel
def viewKeyOf(state):
    row = selectedRow(state)
    if row is None:
        return None
    return levelKey(state.path) + "|" + rowKey(row)


## The left pane of one item, new: nothing of an item before is in it. "head" is what
## stands at its top and does not scroll, "lines" what scrolls under it, "top" the first
## of those in view. A pane that feeds follows its newest line until it is scrolled up.
## "info" is what the read of the item's facts gave, "feed" what the read of its lines
## gave, and "lineKeys" says which entry of the feed each line belongs to.
def newView(viewKey, feeds):
    return {"key": viewKey, "head": [], "lines": [], "top": 0, "feeds": feeds, "follow": feeds,
            "info": None, "feed": None, "acts": None, "lineKeys": [], "built": None}


## The left pane follows the selection: another item is shown from its first line, and
## nothing of the item before is left. What the pane shows from a list read already made
## (localView, viewHead) is set out again each time, so it follows that read too. A choice
## of how a view shows, the feed or the raw log, is the user's for the run of the screen:
## it is kept as the selection moves.
@onShownLevel
def followSelection(state):
    viewKey = viewKeyOf(state)
    row = selectedRow(state)
    if viewKey != state.view["key"]:
        state.view = newView(viewKey, logShown(state, row))
        ## a pane that is made new holds nothing of its item: its reads are due again,
        ## whenever they were last made
        for part in VIEW_PARTS:
            state.started.pop("%s:%s" % (part, viewKey), None)
        ## what an action answered stands on the item it was asked on, and goes with it
        if state.answer is not None and state.answer["key"] != viewKey:
            state.answer = None
    local = localView(state, row)
    if local is not None:
        state.view["lines"] = local
    state.view["head"] = viewHead(state, row)
    if state.view["feed"] is not None and state.view["built"] != (state.viewWidth, state.viewMode):
        buildFeed(state, row)


## The lines of the left pane move, or are brought in line with what the pane holds now.
## A pane that feeds stays on its newest line while it follows; scrolled up it stays where
## it is, and scrolled back to its end it follows again.
def scrollView(state, height, step, pages=0):
    view = state.view
    last = max(0, len(view["lines"]) - height)
    if view["follow"] and not step and not pages:
        view["top"] = last
        return
    view["top"] = max(0, min(view["top"] + step + pages * height, last))
    if view["feeds"]:
        view["follow"] = view["top"] >= last


## What the left pane shows with no read of its own, from what a list read already holds:
## the selected ask, and what the section of asks holds; the selected routine of `Launch /
## Spawn`, its free prompt, and what it holds; the selected team member, and what the
## section of the members holds; the selected subject of the settings, and what the
## digest holds; the selected thing to start, and what `Consoles (Tools)` holds. None: the
## pane has no such content, and shows what its own read gives.
def localView(state, row):
    if row is None:
        return None
    level = levelPattern(state.path)
    if not logShown(state, row):
        ## the summary of a session and of an agent: its facts, and nothing of its log;
        ## one that has no log has its summary alone, whatever the mode
        if level == "sessions" and row.get("session"):
            return sessionLines(row["session"], state.viewWidth, state.view["info"])
        if level == "sessions/*" and row.get("run"):
            return runLines(row["run"], state.viewWidth, state.view["info"])
    if level == "pending" and row.get("ask"):
        ## set out again only when the ask, what is stored of it, the width or the minute has changed
        stamp = (row["ask"], id(state.view["info"]), state.viewWidth, int(nowEpoch() // 60))
        if state.view.get("askFor") == stamp:
            return None
        state.view["askFor"] = stamp
        return askLines(row["ask"], state.viewWidth, state.view["info"])
    if (level == "pending" and row["kind"] == "up") or (level == "" and row["kind"] == "section" and row["id"] == "pending"):
        return pendingSummary(state)
    if (level == "sessions" and row["kind"] == "up") or (level == "" and row["kind"] == "section" and row["id"] == "sessions"):
        return sessionsSummary(state)
    if level == "sessions/launch" and row.get("routine"):
        return routineLines(row["routine"], state.viewWidth)
    if level == "sessions/launch" and row["kind"] == "free":
        return freePromptLines(state.viewWidth)
    if (level == "sessions/launch" and row["kind"] == "up") or (level == "sessions" and row["kind"] == "launch"):
        return routinesSummary(state)
    if level == "team" and row.get("member"):
        ## set out again only when the member, what was read of it, the width or the minute has changed
        stamp = (row["member"], id(state.view["info"]), state.viewWidth, int(nowEpoch() // 60))
        if state.view.get("memberFor") == stamp:
            return None
        state.view["memberFor"] = stamp
        return memberLines(row["member"], state.viewWidth, state.view["info"])
    if (level == "team" and row["kind"] == "up") or (level == "" and row["kind"] == "section" and row["id"] == "team"):
        return membersSummary(state)
    if level == "settings" and row.get("subject"):
        return subjectLines(row["subject"], state.viewWidth)
    if (level == "settings" and row["kind"] == "up") or (level == "" and row["kind"] == "section" and row["id"] == "settings"):
        return digestSummary(state)
    if level == "consoles" and row.get("start"):
        return startLines(row["start"], state.viewWidth)
    if (level == "consoles" and row["kind"] == "up") or (level == "" and row["kind"] == "section" and row["id"] == "consoles"):
        return startsSummary(state)
    return None


## The level and the kind of a row, as COMMANDS names the rows a command acts on.
def placeOf(state, row):
    return levelPattern(state.path) + ":" + row["kind"] if row is not None else ""


## The keys that act on the selected row, as the left window names them under the item:
## the actions COMMANDS gives its level and kind, in their order, and ahead of them the
## key that starts something there and is another command's elsewhere, each once its
## handler is built and while it acts on the row as it is now.
@onShownLevel
def itemKeysText(state):
    row = selectedRow(state)
    if row is None:
        return ""
    place = placeOf(state, row)
    keys = []
    for command in COMMANDS:
        if command["does"][0] != "action" or place not in command.get("on", ()):
            continue
        if command.get("tells") or not actionShown(state, row, command["does"][1]):
            continue
        if command.get("only"):
            keys.insert(0, "%s %s" % (keyShown(commandKeys(command)[0]), command.get("says", "start")))
        else:
            keys.append("%s %s" % (commandKeys(command)[0], command["does"][1]))
    return "keys: " + "  ".join(keys) if keys else ""


## Whether the left pane names the key of an action under that row: its handler is built,
## and the action acts on the row as it is now.
def actionShown(state, row, actionName):
    if ACTION_HANDLERS.get(actionName) is None:
        return False
    fits = ACTION_FITS.get(actionName)
    return fits is None or bool(fits(state, row))


## How many lines of the left pane its content has: one less where the keys of the item
## stand under it; and while a line is typed in, less by what that line says above itself.
def viewContentHeight(state, layout):
    said = lineSays(state, layout["viewWidth"], layout["viewHeight"])
    if said:
        return layout["viewHeight"] - len(said)
    return layout["viewHeight"] - (1 if itemKeysText(state) else 0)


## How many of those lines scroll: what the head of the pane leaves.
def viewScrollHeight(state, layout):
    return max(0, viewContentHeight(state, layout) - len(state.view["head"]))


## The head of the left pane, which does not scroll: what an action answered on the
## selected item, on any row (answerLines), and, where the window shows a log, the one
## line that says where its lines come from. It takes half of the pane at most. The facts
## of a session and of an agent are its summary, which scrolls (localView).
def viewHead(state, row):
    if row is None:
        return []
    limit = max(4, state.viewHeight // 2) - 1
    lines = answerLines(state, limit)
    if logShown(state, row) and (row.get("session") or row.get("run")):
        lines.extend(fieldLines([("lines", sourceText(state, row))], state.viewWidth))
    return lines


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


## What `--member-pending-reply-read <member> --any-owner` printed, as rows. A record starts
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


## The selected ask, whole, for the left pane: its kind, who asks and of whom, since when,
## whether its asker is alive, its asking session and item, where it was posted, and its
## question as far as the read prints it, which is its first line, each broken to the
## width of the pane. The read prints no
## option of a decision and no entry of a permission set: once an operation prints them
## they show here, under their own names. Its keys answer it from here (askAnswer).
## The read of that one ask by its id gives what the stores hold of it: once it has come,
## the whole question, its options, its entries, its fields and its diff stand in the
## place of the first line (storedLines).
def askLines(ask, width, stored=None):
    values = ask["values"]
    kind = values.get("kind", "")
    lines = [" ".join(word for word in (ASK_KIND_MARKS.get(kind, ""), kind or "ask", values.get("question-tag", "")) if word), ""]
    age = ageText(askedEpoch(values), nowEpoch())
    live = values.get("asker-live", "")
    setOut = [
        ("asked by", values.get("owner", "")),
        ("asked of", values.get("address-to", "")),
        ("asked at", values.get("asked-at", "") + (" (%s ago)" % age if age else "")),
        ("asker", live + (": " + ASKER_WORDS[live] if live in ASKER_WORDS else "")),
        ("session", values.get("session-id", "")),
        ("item", values.get("item", "")),
        ("posted", "channel %s, thread %s, message %s" % (
            values.get("channel", "-"), values.get("thread-ts", "-"), values.get("question-ts", "-"))),
        ("status", values.get("status", "")),
        ("ask", ask["id"]),
    ]
    setOut.extend((name, value) for name, value in ask["fields"] if name not in ASK_FIELDS_SET_OUT)
    for name, value in setOut:
        if value:
            parts = wrapToCells(value, max(10, width - 11))
            lines.append("%-9s %s" % (name, parts[0]))
            lines.extend(" " * 10 + part for part in parts[1:])
    lines.append("")
    if stored and stored["id"] == ask["id"] and stored["stored"]:
        lines.extend(storedLines(stored["stored"], width))
    else:
        lines.append("question, its first line:")
        lines.extend(wrapToCells(values.get("question", ""), max(10, width - 1)))
    lines.append("")
    lines.append("an ask is answered where it was posted, or from here by its keys")
    return lines


## What `--member-pending-reply-read <member> <id>` printed of the stores of one ask: the
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
## verdict noted; the post itself where it was not the question above; and last the other
## fields of its record.
def storedLines(stored, width):
    room = max(10, width - 1)
    lines = []
    held = {}
    for name, texts in stored:
        held.setdefault(name, []).extend(texts)

    def block(title, texts, numbered=False, exact=False):
        if lines and lines[-1] != "":
            lines.append("")
        lines.append(title + ":")
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
        block("question", held["field-question"])
    elif "posted" in held:
        block("question, as posted", held["posted"])
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
        block("as posted", held["posted"])
    record = [(name, texts) for name, texts in stored if name != "posted" and name != "option" and name != "clarification"
              and not name.startswith(("field-", "set-", "refused-", "change-", "first-", "answer-noted-"))]
    if record:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append("its record:")
        for name, texts in record:
            part(name, texts)
    return lines


## What the section of asks holds, for the left pane while the section itself or the row
## that goes up is selected: how many wait, and how many of those have no asker any more.
## Counted from the asks as they were read, and until then from the counters of the status
## lines; None while neither is known.
def pendingSummary(state):
    if "pending" in state.rows:
        count = len(state.rows["pending"])
    elif str(state.counters.get("pending", "")).isdigit():
        count = int(state.counters["pending"])
    else:
        return None
    if count == 0:
        return ["Nothing waits for an answer."]
    gone = len([row for row in state.rows.get("pending", ())
                if row.get("ask") and row["ask"]["values"].get("asker-live") in ASKER_GONE])
    lines = ["%d ask%s for an answer." % (count, " waits" if count == 1 else "s wait")]
    if gone:
        lines.append("%d of them %s asked by a run that is gone (%s in the list): nobody is there to take the answer." % (
            gone, "was" if gone == 1 else "were", MARK_GONE))
    return lines


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
    levels = {"sessions": []}
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
            sessions[fields[1]] = row
            levels["sessions"].append(row)
            levels["sessions/" + fields[1]] = []
        elif fields[0] == "run" and len(fields) >= 12 and fields[1] in sessions:
            runs = levels["sessions/" + fields[1]]
            run = {"session": fields[1], "spawn": fields[2], "member": fields[3], "status": fields[4],
                   "live": fields[5], "state": fields[6], "started": fields[7], "resolved": fields[8],
                   "host": fields[9], "workspace": fields[10], "activity": fields[11]}
            row = newRow(fields[2] if fields[2] != "-" else "-%d" % len(runs), fields[3], "record", False, fields)
            row["run"] = run
            row["tail"] = runStateText(run)
            row["look"] = BOLD if run["live"] == "running" else PLAIN
            sessions[fields[1]]["session"]["runs"].append(run)
            runs.append(row)
    for row in levels["sessions"]:
        session = row["session"]
        if not session["name"] and len(session["runs"]) == 1:
            session["lone"] = True
            row["label"] = "%s %s" % (session["runs"][0]["member"], session["id"][:8])
            if row["look"] == PLAIN:
                row["look"] = DIM
    return levels


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


## The selected session for the left pane, from its row and the rows of its runs:
## its state, when it started and ended, how many agents it has and in which states, and
## each agent with its state and since when it runs, or until when it ran. Once the read
## of that one session has come (info), also its dispatch: what it was started for, by
## whom, the routine and the item, and its two threads; and its agents as that read has
## them. Within a limit of lines its id and its threads go first; then, of its agents,
## those that are alive stay, then the latest, above one line that counts the rest.
def sessionLines(session, width, info=None, limit=0):
    tally = ", ".join("%s %s" % (part.partition("=")[2], part.partition("=")[0])
                      for part in session["tally"].split(",") if "=" in part)
    lines = ["one lone run with no name", ""] if session["lone"] else []
    pairs = [
        ("state", session["state"]),
        ("control", controlText(session, info)),
        ("started", registryDate(session["started"])),
        ("ended", registryDate(session["stateAt"])),
        ("agents", "%s: %s" % (session["count"], tally) if tally else session["count"]),
        ("tokens", tokensText(info["tokens"]) if info and info.get("tokens") else ""),
    ]
    more = [("session", session["id"])]
    dispatch = info["dispatch"] if info else None
    if dispatch:
        if dispatch["founder"] == "no-record":
            pairs.append(("founded", "by a client, whose founder left no record"))
        else:
            pairs.append(("founded", ", ".join(word for word in (
                "by " + dispatch["member"] if dispatch["member"] else "",
                "routine " + dispatch["routine"] if dispatch["routine"] else "",
                "item " + dispatch["item"] if dispatch["item"] else "") if word)))
        more.append(("threads", ", ".join(word for word in (
            "session " + dispatch["sessionThread"] if dispatch["sessionThread"] else "",
            "tracking " + dispatch["trackingThread"] if dispatch["trackingThread"] else "") if word)))
    runs = info["runs"] if info and info["runs"] else session["runs"]
    lines.extend(fieldLines(pairs, width) + fieldLines(more, width))
    lines.append("")
    lines.extend(agentsTable(runs, width))
    lines.extend(dispatchLines(dispatch, width))
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


## The columns of the table of the agents of a session, and what of a run stands in each:
## the member always shows, and those after it in this order while the window has room.
AGENT_COLUMNS = (
    ("MEMBER", lambda run, store: run["member"]),
    ("STATE", lambda run, store: runStateText(run)),
    ("SINCE", lambda run, store: unspaced(run["started"]) if run["resolved"] == "-" else "until " + unspaced(run["resolved"])),
    ("TOKENS", lambda run, store: shortCount(str(sum(int(store[name]) for name in ("in", "cacheRead", "cacheWrite", "out"))))
     if all(store.get(name, "").isdigit() for name in ("in", "cacheRead", "cacheWrite", "out")) else ""),
    ("CLI", lambda run, store: (run.get("headers") or {}).get("cli", "")),
    ("MODEL", lambda run, store: unspaced(store.get("model", "-"))),
)


## The agents of a session as a table under a header, in the manner of the members' table
## and by its rule: a column that does not fit is left out whole, never cut.
def agentsTable(runs, width):
    words = [[column[1](run, run.get("store") or {}) or "-" for column in AGENT_COLUMNS] for run in runs]
    table = {"heads": [column[0] for column in AGENT_COLUMNS], "iconWidth": 0,
             "widths": [max([textWidth(column[0])] + [textWidth(line[index]) for line in words])
                        for index, column in enumerate(AGENT_COLUMNS)]}
    return [tableLineText(table, [""] + line, max(10, width - 1)) for line in [table["heads"]] + words]


## What a session was started with, as far as its read gives it, under a line of its
## own: the text of its dispatch, whole, broken to the window.
def dispatchLines(dispatch, width):
    if not dispatch or dispatch["founder"] == "no-record" or not dispatch["description"].strip():
        return []
    lines = ["", "dispatch"]
    for paragraph in dispatch["description"].split("\n"):
        lines.extend(wrapToCells(paragraph, max(10, width - 1)) if paragraph.strip() else [""])
    return lines


## The selected agent of a session for the left pane, from its row; once the read of that
## one run has come (info), also what it waits on while it is alive, its open asks, its
## model and its token counts, its last milestone and its marks. Within a limit of lines
## the last ones go.
def runLines(run, width, info=None, limit=0):
    told = info["bySpawn"].get(run["spawn"]) if info else None
    store = told["store"] if told and told["store"] else {}
    headers = told["headers"] if told else {}
    run = told or run
    asks = [one for one in store.get("asks", "-").split(",") if one and one != "-"]
    milestoneAge = ageText(isoEpoch(store.get("milestoneAt", "")), nowEpoch())
    lines = fieldLines([
        ("state", runStateText(run)),
        ("status", unspaced(run["status"])),
        ("process", unspaced(run["live"])),
        ("started", registryDate(run["started"])),
        ("ended", registryDate(run["resolved"])),
        ("waits on", store.get("waits", "") if run["live"] == "running" else ""),
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
        ("session", run["session"]),
    ], width)
    lines.extend(dispatchLines(info.get("dispatch") if info else None, width))
    return lines[:limit] if limit else lines


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
    if row.get("run"):
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
## where there are several; then the feed, the newest last: the time of day here, the
## member where the pane shows a whole session, and the text with its emoji, a long one
## broken under itself. A line with the date stands where the day changes.
def feedLines(feed, width, withMember):
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
    memberWidth = max([len(entry["member"]) for entry in feed["rows"]] or [0]) if withMember else 0
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
        prefix = (time.strftime("%H:%M:%S", stamp) if stamp else entry["time"]) + " "
        if withMember:
            prefix += entry["member"].ljust(memberWidth) + " "
        parts = wrapToCells(entry["text"], max(10, room - len(prefix)))
        key = ("feed", entry["time"], entry["spawn"], entry["text"])
        lines.append(prefix + parts[0])
        keys.append(key)
        for more in parts[1:]:
            lines.append(" " * len(prefix) + more)
            keys.append(key)
    return lines, keys


## The lines of the pane are set out from its feed, at the width the pane has now. A pane
## that was scrolled up stays on the entry that stood at its top, wherever that now is.
@onShownLevel
def buildFeed(state, row):
    view = state.view
    held = view["lineKeys"][view["top"]] if not view["follow"] and view["top"] < len(view["lineKeys"]) else None
    view["lines"], view["lineKeys"] = feedLines(view["feed"], state.viewWidth, bool(row and row.get("session")))
    view["built"] = (state.viewWidth, state.viewMode)
    if held is not None:
        places = [position for position, key in enumerate(view["lineKeys"]) if key == held]
        if places:
            view["top"] = min(places, key=lambda position: abs(position - view["top"]))


## The mode of the left window now, its entry of VIEW_MODES; whether it shows the raw log;
## and whether it shows the lines of that row, which only a row with a log has.
def modeOf(state):
    return dict(VIEW_MODES)[state.viewMode]


def rawShown(state):
    return modeOf(state)["raw"]


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




## What the section of the sessions holds, for the left pane while the section itself or
## the row that goes up is selected. None until its read has answered.
def sessionsSummary(state):
    if "sessions" not in state.rows and "running" not in state.counters:
        return None
    lines = []
    if "sessions" in state.rows:
        count = len(state.rows["sessions"])
        lines.append("%d %ssession%s." % (count, "active " if state.activeOnly else "", "" if count == 1 else "s"))
    if "running" in state.counters:
        lines.append("In the workspace: sessions %s running, %s paused; agents %s working, %s waiting." % tuple(
            state.counters.get(name, "-") for name in COUNTER_NAMES[:4]))
    gone = len([row for row in state.rows.get("sessions", ()) if row.get("session") and row["session"].get("control") == "gone"])
    if gone:
        lines.append("%s a control thread that is gone (%s in the list)." % (
            "1 session has" if gone == 1 else "%d sessions have" % gone, MARK_GONE))
    return lines


## ---- the routines to start by hand: `Launch / Spawn` ----

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


## The selected routine for the left pane, from its row: its file, the member that owns
## it, its title, who runs it, the kind of its session, and whether Enter starts it:
## under which name, or why not.
def routineLines(routine, width):
    startable = routine["start"] == "startable"
    return fieldLines([
        ("routine", routine["selector"]),
        ("owner", routine["owner"]),
        ("title", routine["title"]),
        ("executors", routine["executors"]),
        ("session", "coworking: the spawner adds magic-coordinator to it" if routine["session"] == "coworking" else routine["session"]),
        ("start", "Enter starts it, as its executors, whoever is at the console" if startable
         else "Enter asks for the members to start it with, in one session" if routineAsksMembers(routine)
         else "%s: Enter does not start it" % routine["start"]),
        ("name", "%s, the name its session takes unless another is typed" % routine["name"] if startable else ""),
        ("why", "" if startable else routine["reason"]),
    ], width)


## The free prompt for the left pane: what a prompt typed there starts.
def freePromptLines(width):
    lines = []
    for text in ("A prompt typed here starts a new coworking session, opened by the coordinator, with that prompt as its brief.",
                 "Enter opens its dialog: who runs it, the prompt, the name of the session. An empty prompt starts nothing."):
        lines.extend(wrapToCells(text, max(10, width - 1)))
    return lines


## What `Launch / Spawn` holds, for the left pane while the row that goes up is selected
## there, or its own row in the list of the sessions. None until its read has answered.
def routinesSummary(state):
    if "sessions/launch" not in state.rows:
        return None
    routines = [row["routine"] for row in state.rows["sessions/launch"] if row.get("routine")]
    startable = len([routine for routine in routines if routine["start"] == "startable"])
    return ["%d routine%s: %d can be started here, %d cannot." % (
        len(routines), "" if len(routines) == 1 else "s", startable, len(routines) - startable)]


## ---- the bottom line: what is typed, and what the screen says ----

## Opens the line to type in. onSubmit(state, text) is called on Enter and gives the text
## the line then shows, or None; Esc closes the line and calls nothing. `text` stands in
## the line from the start, to be typed over. `lines` is what the line says of itself:
## it is shown above the line, at the foot of the left pane, while the line is open.
def openLine(state, prompt, onSubmit, text="", lines=None):
    state.line = {"prompt": prompt, "text": text, "onSubmit": onSubmit, "lines": list(lines or ())}


## What the open line says above itself, as lines of the left pane: a line longer than the
## pane is broken, and there are no more of them than the pane has lines. Empty with no
## line open, and for a line that says nothing of itself.
def lineSays(state, width, height):
    if state.line is None or not state.line.get("lines"):
        return []
    lines = []
    for text in state.line["lines"]:
        if textWidth(text) <= width - 1:
            lines.append(text)
        else:
            lines.extend(wrapToCells(text, max(10, width - 1)))
    return lines[:max(0, height)]


def lineKey(state, key):
    dialog = state.line
    if key == "ESC":
        state.line = None
        state.notice = ""
        state.noticeOf = None
    elif key == "ENTER":
        state.line = None
        state.notice = dialog["onSubmit"](state, dialog["text"]) or ""
        state.noticeOf = None
    elif key == "BACKSPACE":
        dialog["text"] = dialog["text"][:-1]
    elif len(key) == 1:
        ## a key that has a name is longer than one character: this one was typed
        dialog["text"] += key


## ---- the dialogs ----

## Opens the dialog of that name of DIALOGS over the screen: it has the keys until it is
## closed. `fill` gives its controls what the declaration cannot know, by their names:
## under "lines" the paragraphs of a text, each a text, or a pair of a name and its value,
## which are set out as the facts of the left window are; under "options" the boxes, the
## radio buttons or the rows of a list, the id of each and what it shows as; under "value"
## what a control holds at first, a text, the id that is chosen, or the ids that are
## checked. `about` is kept for its handler. `title` stands in place of the declared one.
## A dialog opened while another is open waits for that one to close.
def openDialog(state, name, fill=None, about=None, title=None):
    declared = DIALOGS[name]
    controls = []
    for control in declared["controls"]:
        held = dict(control, lines=[], options=[], value=[] if control["kind"] == "checks" else "", top=0, at=0)
        held.update((fill or {}).get(control["name"], {}))
        ids = [option[0] for option in held["options"]]
        if control["kind"] == "checks":
            held["value"] = list(held["value"])
        elif control["kind"] in ("radios", "list") and ids:
            if held["value"] not in ids:
                held["value"] = ids[0]
            held["at"] = ids.index(held["value"])
        controls.append(held)
    dialog = {"name": name, "title": title or declared["title"], "controls": controls,
              "buttons": list(declared["buttons"]), "about": about or {}, "says": "", "focus": 0, "plan": None}
    for place, (sort, index) in enumerate(dialogStops(dialog)):
        if sort == "control" and controls[index]["name"] == declared.get("first"):
            dialog["focus"] = place
    if state.dialog is None:
        state.dialog = dialog
        state.menu = None
    else:
        state.waiting.append(dialog)
    return dialog


## Closes the dialog that is open: the next one that waits opens, or the keys go back to
## the windows.
def closeDialog(state):
    state.dialog = state.waiting.pop(0) if state.waiting else None


## The message box: what the screen refuses, or what an operation answered when it failed,
## with its whole text under that title. `text` is one paragraph, or several as openDialog
## takes them. Gives an empty text, for a handler of an action to give back: the status
## line then says nothing, the box has said it.
def tell(state, title, text, name="message"):
    openDialog(state, name, {"text": {"lines": [text] if isinstance(text, str) else list(text)}}, title=title)
    return ""


## Where the keys of a dialog can be: its controls that take them, from the top, and after
## them its buttons. Each as its sort, "control" or "button", and its place among those.
def dialogStops(dialog):
    stops = [("control", index) for index, control in enumerate(dialog["controls"])
             if CONTROL_KINDS[control["kind"]]["focus"]]
    return stops + [("button", index) for index in range(len(dialog["buttons"]))]


## What has the keys in a dialog: its kind of CONTROL_KINDS, its place among the controls
## or among the buttons, and the control itself, or None for a button.
def dialogFocus(dialog):
    sort, index = dialogStops(dialog)[dialog["focus"]]
    if sort == "button":
        return "button", index, None
    return dialog["controls"][index]["kind"], index, dialog["controls"][index]


## The control of that name of a dialog, and what it holds.
def dialogControl(dialog, name):
    for control in dialog["controls"]:
        if control["name"] == name:
            return control
    return None


def dialogValue(dialog, name):
    control = dialogControl(dialog, name)
    return control["value"] if control else None


## The first control of a dialog whose required input is not there, or None: a field that
## holds only blanks and new lines, or not the very word it must hold; boxes with none of
## their options checked.
def dialogMissing(dialog):
    for control in dialog["controls"]:
        if not control.get("required"):
            continue
        value = control["value"]
        if control.get("exactly") is not None:
            if value != control["exactly"]:
                return control
        elif isinstance(value, list):
            if not [option for option in control["options"] if option[0] in value]:
                return control
        elif not value.strip():
            return control
    return None


## A button of the open dialog is pressed. "cancel", and any button of a dialog that only
## says something, closes it. Any other goes to its handler: what that refuses stays in
## the dialog, which stays open; else the dialog closes. While a required input is not
## there no handler is called: the dialog says so in one line, and the keys go back to
## the control that lacks it.
def pressButton(state, buttonName):
    dialog = state.dialog
    handler = DIALOG_HANDLERS.get(dialog["name"])
    if buttonName == "cancel" or handler is None:
        closeDialog(state)
        return
    missing = dialogMissing(dialog)
    if missing is not None:
        dialog["says"] = missing["required"]
        dialog["focus"] = dialogStops(dialog).index(("control", dialog["controls"].index(missing)))
        return
    dialog["says"] = handler(state, dialog, buttonName) or ""
    if not dialog["says"] and state.dialog is dialog:
        closeDialog(state)


## One key while a dialog is open. Tab and Shift-Tab move between its controls and its
## buttons, around at the ends. Enter presses its first button, or the button the keys are
## on; in a field of several lines it is a new line. Esc closes it and does nothing. Space
## toggles a box, chooses a radio button and presses the button the keys are on; Up and
## Down move among boxes and radio buttons and pick in a list; Left and Right go from
## button to button. In a field what is typed is added and Backspace takes the last of it
## away. PgUp and PgDn scroll a text longer than its room, and so do Up and Down wherever
## they mean nothing else. No key of a window, of a menu or of the screen works here.
def dialogKey(state, key):
    dialog = state.dialog
    what, index, control = dialogFocus(dialog)
    stops = dialogStops(dialog)
    if key == "ESC":
        closeDialog(state)
    elif key in ("TAB", "BACKTAB"):
        dialog["focus"] = (dialog["focus"] + (1 if key == "TAB" else -1)) % len(stops)
    elif key == "ENTER" and what == "area":
        control["value"] += "\n"
    elif key == "ENTER" or (key == " " and what == "button"):
        pressButton(state, dialog["buttons"][index if what == "button" else 0][0])
    elif what == "button" and key in ("LEFT", "RIGHT"):
        dialog["focus"] = len(stops) - len(dialog["buttons"]) + (index + (1 if key == "RIGHT" else -1)) % len(dialog["buttons"])
    elif what in ("input", "area") and key == "BACKSPACE":
        control["value"] = control["value"][:-1]
    elif what in ("input", "area") and len(key) == 1:
        ## a key that has a name is longer than one character: this one was typed
        control["value"] += key
    elif what in ("radios", "list") and control.get("digits") and key.isdigit() and key in [option[0] for option in control["options"]]:
        ## the digit of an option picks it
        control["at"] = [option[0] for option in control["options"]].index(key)
        control["value"] = key
    elif what in ("checks", "radios", "list") and key in ("UP", "DOWN") and control["options"]:
        control["at"] = max(0, min(len(control["options"]) - 1, control["at"] + (1 if key == "DOWN" else -1)))
        if what == "list":
            control["value"] = control["options"][control["at"]][0]
    elif what == "checks" and key == " " and control["options"]:
        chosen = control["options"][control["at"]][0]
        if chosen in control["value"]:
            control["value"].remove(chosen)
        else:
            control["value"].append(chosen)
    elif what == "radios" and key == " " and control["options"]:
        control["value"] = control["options"][control["at"]][0]
    elif key in ("UP", "DOWN", "PGUP", "PGDN"):
        page = max(1, (dialog["plan"] or {}).get("page", 1))
        step = (1 if key in ("DOWN", "PGDN") else -1) * (page if key.startswith("PG") else 1)
        for held in dialog["controls"]:
            if held["kind"] == "text":
                ## its end is held where it is drawn, which knows how many lines it shows
                held["top"] = max(0, held["top"] + step)
                break


## The keys the status line names while a dialog is open: those of the control that has
## the keys, from CONTROL_KINDS, then what Enter presses, Tab where there is more than one
## place for the keys, what scrolls a text longer than its room, and Esc.
def dialogStatus(dialog):
    what, index, control = dialogFocus(dialog)
    items = [item for item in CONTROL_KINDS[what]["keys"] if what != "button" or len(dialog["buttons"]) > 1]
    digits = [option[0] for option in control["options"] if option[0].isdigit()] if control and control.get("digits") else []
    if digits:
        items.append((digits[0] + "-" + digits[-1] if len(digits) > 1 else digits[0], "Choose"))
    pressed = dialog["buttons"][index if what == "button" else 0]
    if what != "area" and (pressed[0] == "cancel" or dialogMissing(dialog) is None):
        ## a button that would act is no default while a required input is not there
        items.append(("Enter", pressed[1]))
    if len(dialogStops(dialog)) > 1:
        items.append(("Tab", "Next"))
    if (dialog["plan"] or {}).get("long"):
        items.append(("Up/Down" if what in ("input", "area", "button") else "PgUp/PgDn", "Scroll"))
    items.append(("Esc", "Cancel" if "cancel" in [button[0] for button in dialog["buttons"]] else "Close"))
    return items


## The paragraphs of a text of a dialog as lines of that width: a text is broken between
## words, one that begins with a space is set out already and is broken only where it is
## full, and pairs that follow one another are set out as facts, their names in a column.
def dialogTextLines(control, width):
    lines = []
    pairs = []
    for paragraph in list(control["lines"]) + [None]:
        if isinstance(paragraph, tuple):
            pairs.append(paragraph)
            continue
        if pairs:
            lines.extend(fieldLines(pairs, width))
            pairs = []
        if paragraph is not None:
            ## a line that begins with a space is set out already: it is broken only where it is full
            lines.extend(areaLines(paragraph, width) if paragraph.startswith(" ") else wrapToCells(paragraph, width))
    return lines


## What was typed into a field of several lines, as lines of that width: a new line where
## one was typed, and where a line is full.
def areaLines(text, width):
    lines = []
    for typed in text.split("\n"):
        line = ""
        used = 0
        for cluster, clusterWidth in textCells(typed):
            if used + clusterWidth > width:
                lines.append(line)
                line = ""
                used = 0
            line += cluster
            used += clusterWidth
        lines.append(line)
    return lines


## Where a dialog stands on a terminal of that size, and each of its parts in it: its box,
## in the middle of the desktop, as wide as what it holds asks for, between forty cells
## and DIALOG_COLUMNS, and never wider than the terminal less two cells at each side; how
## wide its inside is; each control with the line of its label, its first line and how
## many lines it has; the lines of what it refuses and the line of its buttons, the last
## inside its frame. Where the terminal has not the lines for all of it, a text gives its
## lines first, down to one, then a list of options, then a field of several lines, and
## last the empty lines between the controls: what is cut there scrolls. "long" says that
## a text holds more than it shows, and "page" how many lines of it show.
def dialogPlan(dialog, columns, lines):
    wanted = max(textWidth(dialog["title"]) + 2, sum(textWidth(label) + 6 for name, label in dialog["buttons"]))
    for control in dialog["controls"]:
        wanted = max(wanted, textWidth(control.get("label", "")))
        if control["kind"] in ("input", "area"):
            wanted = max(wanted, 52)
        for paragraph in control["lines"]:
            wanted = max(wanted, 11 + textWidth(paragraph[1]) if isinstance(paragraph, tuple) else textWidth(paragraph))
        for optionId, label in control["options"]:
            wanted = max(wanted, textWidth(label) + 4)
    width = min(columns - 4, max(40, min(wanted + 4, DIALOG_COLUMNS)))
    inner = width - 4
    room = lines - 4
    parts = []
    for index, control in enumerate(dialog["controls"]):
        kind = control["kind"]
        holds = len(dialogTextLines(control, inner)) if kind == "text" else len(control["options"])
        height = 1 if kind == "input" else DIALOG_AREA if kind == "area" else max(1, holds) if kind == "text" else max(1, min(holds, DIALOG_OPTIONS))
        parts.append({"index": index, "kind": kind, "label": 1 if control.get("label") else 0, "height": height, "holds": holds})
    says = wrapToCells(dialog["says"], inner)[:2] if dialog["says"] else []
    gap = 1
    over = sum(part["label"] + part["height"] for part in parts) + gap * len(parts) + len(says) + 1 - room
    for kinds in (("text",), ("checks", "radios", "list"), ("area",)):
        for part in parts:
            if over > 0 and part["kind"] in kinds:
                cut = min(over, part["height"] - 1)
                part["height"] -= cut
                over -= cut
    if over > 0:
        gap = 0
    inside = sum(part["label"] + part["height"] for part in parts) + gap * len(parts) + len(says) + 1
    height = max(1, min(inside, room)) + 2
    left = (columns - width) // 2
    top = 1 + max(0, (lines - 2 - height) // 2)
    line = top + 1
    for part in parts:
        part["labelLine"] = line if part["label"] else None
        part["line"] = line + part["label"]
        line += part["label"] + part["height"] + gap
    texts = [part for part in parts if part["kind"] == "text"]
    return {"box": (left, top, width, height), "inner": inner, "parts": parts, "says": says, "saysLine": line,
            "buttonsLine": top + height - 2,
            "long": any(part["holds"] > part["height"] for part in texts),
            "page": texts[0]["height"] if texts else 1}


## The open dialog, drawn over the screen from its declaration and its plan: its frame
## with its title, in the style with colours its shadow, each control, what it refuses,
## and its buttons. The control that has the keys, or the item of it they are on, stands
## in a look of its own, and a field that has them shows the cursor after what was typed.
## A mark at the right says that a text, or a list of options, goes on above or below.
def drawDialog(surface, state, columns, lines):
    dialog = state.dialog
    plan = dialog["plan"]
    left, top, width, height = plan["box"]
    inner = plan["inner"]
    marks = MARKS["frameOn"]
    surface.put(top, left, marks[0] + marks[1] * (width - 2) + marks[2], BOX_FRAME)
    title = " " + fitToCells(dialog["title"], width - 6) + " "
    surface.put(top, left + (width - textWidth(title)) // 2, title, BOX_FRAME)
    for offset in range(1, height - 1):
        surface.put(top + offset, left, marks[3], BOX_FRAME)
        surface.put(top + offset, left + 1, " " * (width - 2), BOX)
        surface.put(top + offset, left + width - 1, marks[3], BOX_FRAME)
    surface.put(top + height - 1, left, marks[4] + marks[1] * (width - 2) + marks[5], BOX_FRAME)
    if STYLE["colours"]:
        for offset in range(1, height):
            surface.put(top + offset, left + width, "  ", SHADOW)
        if top + height <= lines - 2:
            surface.put(top + height, left + 2, " " * width, SHADOW)
    what, focusIndex, focused = dialogFocus(dialog)
    column = left + 2
    last = plan["buttonsLine"]
    spot(state, left, top, width, height, ("dialog",))
    for part in plan["parts"]:
        control = dialog["controls"][part["index"]]
        on = control is focused
        kind = part["kind"]
        if part["labelLine"] is not None and part["labelLine"] < last:
            surface.put(part["labelLine"], column, cutToCells(control["label"], inner), BOX)
        rows = max(0, min(part["height"], last - part["line"]))
        if not rows:
            continue
        if kind == "input":
            typed, typedWidth = tailToCells(control["value"], inner - 1)
            surface.put(part["line"], column, cutToCells(typed, inner), BOX_ON if on else BOX_FIELD)
            spot(state, column, part["line"], inner, 1, ("field", part["index"]))
            if on:
                surface.cursor(part["line"], column + typedWidth)
            continue
        if kind == "area":
            held = areaLines(control["value"], inner - 1)[-rows:]
            spot(state, column, part["line"], inner, rows, ("field", part["index"]))
            for offset in range(rows):
                surface.put(part["line"] + offset, column, cutToCells(held[offset] if offset < len(held) else "", inner),
                            BOX_ON if on else BOX_FIELD)
            if on:
                surface.cursor(part["line"] + len(held) - 1, column + textWidth(held[-1]))
            continue
        if kind == "text":
            held = [(line, BOX) for line in dialogTextLines(control, inner)]
        else:
            if control["at"] < control["top"]:
                control["top"] = control["at"]
            if control["at"] >= control["top"] + rows:
                control["top"] = control["at"] - rows + 1
            held = []
            for position, (optionId, label) in enumerate(control["options"]):
                if kind == "checks":
                    mark = "[X] " if optionId in control["value"] else "[ ] "
                elif kind == "radios":
                    mark = "(*) " if optionId == control["value"] else "( ) "
                else:
                    mark = (MARK_SELECTED if optionId == control["value"] else " ") + " "
                held.append((mark + label, BOX_ON if on and position == control["at"] else BOX_FIELD if kind == "list" else BOX))
            if not held:
                held.append((control.get("empty", ""), BOX))
        control["top"] = max(0, min(control["top"], len(held) - rows))
        for offset in range(rows):
            if control["top"] + offset < len(held):
                text, look = held[control["top"] + offset]
                surface.put(part["line"] + offset, column, cutToCells(text, inner), look)
                if kind != "text" and control["options"]:
                    spot(state, column, part["line"] + offset, inner, 1, ("option", part["index"], control["top"] + offset))
        if control["top"] > 0:
            surface.put(part["line"], left + width - 2, MARKS["barUp"], BOX_FRAME)
        if control["top"] + rows < len(held):
            surface.put(part["line"] + rows - 1, left + width - 2, MARKS["barDown"], BOX_FRAME)
    for offset, text in enumerate(plan["says"]):
        if plan["saysLine"] + offset < last:
            surface.put(plan["saysLine"] + offset, column, cutToCells(text, inner), BOX_SAYS)
    labels = ["[ %s ]" % label for name, label in dialog["buttons"]]
    column = left + max(2, (width - sum(textWidth(label) + 2 for label in labels) + 2) // 2)
    for index, label in enumerate(labels):
        if column + textWidth(label) > left + width - 2:
            break
        ## a button that would act is greyed while a required input is not there
        off = dialog["buttons"][index][0] != "cancel" and DIALOG_HANDLERS.get(dialog["name"]) is not None and dialogMissing(dialog) is not None
        surface.put(last, column, label, BOX_BUTTON_ON if what == "button" and focusIndex == index else BAR_OFF if off else BOX_BUTTON)
        spot(state, column, last, textWidth(label), 1, ("button", index))
        column += textWidth(label) + 2


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
    key = "action:%s:%s" % (actionName, callId)
    state.calls.append({"key": key, "words": words, "input": inputText})
    told = {"viewKey": viewKeyOf(state)}
    told.update(about or {})
    told["action"] = actionName
    state.asked[key] = told
    state.answer = None


## The row of a session in the list of the sessions, by its id, or None.
def sessionRowOf(state, sessionId):
    for row in state.rows.get("sessions", ()):
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
    if level == "sessions" and row.get("session") and row["session"]["id"] not in ("", "-"):
        session = row["session"]
        return {"kind": "session", "id": session["id"], "label": row["label"], "session": session,
                "runs": [run for run in session["runs"] if run["live"] == "running"]}
    if level == "sessions/*" and row.get("run"):
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
## not change under the word; after its button was pressed, see killChecked.
def fillKill(state, dialog):
    target = dialog["about"]["target"]
    if dialog["about"].get("pressed") is not None and not killChecked(state, dialog):
        return
    rows, note = killPlanOf(state, target)
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
## thread is a session's, so an agent of one, a section and `Launch / Spawn` have none.
def controlTargetOf(state, row):
    if row is None or levelPattern(state.path) != "sessions" or not row.get("session"):
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


## Enter on a routine of `Launch / Spawn`. One the session spawner would not start gets
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
            ("session", "coworking: the spawner adds magic-coordinator to it" if routine["session"] == "coworking" else routine["session"]),
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
    if "team" not in state.rows:
        return None
    return [(row["member"]["name"], row["member"]["name"]) for row in state.rows["team"]
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


## Enter on the free prompt of `Launch / Spawn`: its dialog opens, who runs it, the prompt,
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


## The answer of an action, taken into the state. What the operation printed is set out
## for the left pane, where it stands while the item it was asked on stays selected; one
## line of it stands in the status line; and what is shown is read again, the list of the
## sessions with it. A call that failed shows what it wrote, whole, in a box, and its error
## line in the pane after the rows it printed. The start of a control thread that printed
## its row and failed has the words of that row first in the box: the row says why none
## was started.
def applyCall(state, result):
    about = state.asked.pop(result["key"], None) or {"action": "", "viewKey": None}
    if about["action"] == "kill":
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


## ---- the pending questions: answer, reject, dismiss, link ----

## The fields of the `question` row of `--manager-pending-reply-read --id`, after its first.
## "text": whether it takes words; "reject": the word a reject gives; "dismiss": whether it
## can be dismissed; "link": the link of its message. An absent one is `-`.
ASK_ACT_FIELDS = ("id", "status", "kind", "form", "asker", "addressee", "standsAs", "text", "reject", "dismiss", "link")
## What that row says where the question can be dismissed.
ASK_ACT_YES = "yes"
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
    return lines + [" "] + [text if text.strip() else " " for text in asked]


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
    openDialog(state, "answer" if acts["answers"] else "reply", fill, {"id": row["id"], "viewKey": viewKeyOf(state)},
               "Answer the %s of %s" % (question["kind"], question["asker"]))
    return ""


## Answer in the dialog of an answer: the operation is called once, with the answer picked,
## by its number where it has one, and the words typed beside it; or, for a plain
## question, with the words typed, which are refused there while they are empty.
def submitAnswer(state, dialog, button):
    askId = dialog["about"]["id"]
    words = dialogValue(dialog, "words").strip()
    if dialog["name"] == "reply":
        call = callWords("answer", askId) + [words]
    else:
        call = callWords("answer", askId) + [dialogValue(dialog, "answers")] + ([CALL_WORDS["answer"], words] if words else [])
    askCall(state, "answer", askId, call, None, {"viewKey": dialog["about"]["viewKey"]})
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
                ["The message of the question, where it was posted:", " " + question["link"]], "information")


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
DIALOG_HANDLERS["reply"] = submitAnswer
DIALOG_HANDLERS["reject"] = submitAskAct
DIALOG_HANDLERS["dismiss"] = submitAskAct


## ---- the team members: `Team Members` ----

## The status of a member that is started from here, as its row of the list gives it. Any
## other word there, whatever it is, says that nobody is started as that member.
MEMBER_STARTS = "active"
## What a status shows as in the column of the members' table, where the word is longer
## than the column should be. The left window shows the word whole.
MEMBER_STATUS_SHORT = {"reference-only": "ref-only"}


## Why a member is not started from here, in words, or nothing where it can be: one whose
## status is not the one of a member that is started, and one whose workspace cannot be reached.
def memberRefusal(member):
    if member["setUp"] == "not-present":
        return "its workspace cannot be reached from this machine"
    if member["status"] != MEMBER_STARTS:
        return "its status is %s: nobody is started as this member" % (member["status"] or "not given")
    return ""


## The columns of the members' table after the icon, named in the installer's manner, and
## what of a member stands in each. The name always shows. Those after it show in this
## order while the pane has room, so whether a member runs is the last of them to be lost.
MEMBER_COLUMNS = (
    ("MEMBER", lambda member: member["name"]),
    ("RUN", lambda member: "running" if member["live"] == "running" else ""),
    ("STATUS", lambda member: MEMBER_STATUS_SHORT.get(member["status"], member["status"])),
    ("KIND", lambda member: member["kind"]),
    ("WHERE", lambda member: member["setUp"]),
)


## The rows of the members as one table, like the member table of the installer: under a
## header, each member's icon, its name, whether it runs now, its status, its kind and
## where it is set up, in columns as wide as their widest word, an absent one `-`. The
## icon is the one the operation gave, and no icon is named here. It is measured in cells
## as every text of the screen is, so a wide one, and one an emoji selector makes wide,
## take two; a member with none keeps that place empty. Each row gets its table, which
## all of them share, and its own cells in it: its icon, then a word for each column.
def memberTable(rows):
    members = [row["member"] for row in rows]
    words = [[column[1](member) or "-" for column in MEMBER_COLUMNS] for member in members]
    table = {"heads": [column[0] for column in MEMBER_COLUMNS],
             "widths": [max([textWidth(column[0])] + [textWidth(line[index]) for line in words])
                        for index, column in enumerate(MEMBER_COLUMNS)],
             "iconWidth": max([textWidth(member["icon"]) for member in members] + [0])}
    for row, member, line in zip(rows, members, words):
        row["table"] = table
        row["cells"] = [member["icon"]] + line


## One line of a table in that many cells: the icon, where the table has one, the first
## column, and each column after it, in its order, while it fits in full. The first that
## does not, and every one after it, is left out whole, never cut. A header is such a
## line, of the names of the columns with no icon, so it follows the same choice. Only
## the first column can be longer than its room: whoever draws the line cuts it there.
def tableLineText(table, cells, width):
    iconWidth = table["iconWidth"]
    widths = table["widths"]
    shown = 1
    used = (iconWidth + 1 if iconWidth else 0) + widths[0]
    while shown < len(widths) and used + 1 + widths[shown] <= width:
        used += 1 + widths[shown]
        shown += 1
    parts = [cutToCells(cells[0], iconWidth)] if iconWidth else []
    return " ".join(parts + [cutToCells(word, widths[index]) for index, word in enumerate(cells[1:shown + 1])]).rstrip()


## What `--manager-team-member-list` printed, as rows: `member` rows of TAB-separated
## fields, in the order they come, this workspace's own members first. The members show
## as a table (memberTable). One with a live run stands out. One that is not started from
## here, whose status is `reference-only` or whose workspace is `not-present`, shows
## plainer: dimmed. The last field is the member's icon: a row without it, as the
## operation printed a row before it gave one, is a member with no icon.
def parseMemberRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "member" or len(fields) < 11:
            continue
        member = {"name": fields[1], "mark": unspaced(fields[2]), "first": unspaced(fields[3]),
                  "family": unspaced(fields[4]), "alias": unspaced(fields[5]), "kind": absent(fields[6]),
                  "workspace": absent(fields[7]), "setUp": fields[8], "status": absent(fields[9]), "live": fields[10],
                  "icon": absent(fields[11]) if len(fields) > 11 else ""}
        row = newRow(fields[1], fields[1], "record", False, fields)
        row["member"] = member
        if member["live"] == "running":
            row["look"] = BOLD
        if memberRefusal(member):
            row["look"] = DIM
        rows.append(row)
    memberTable(rows)
    return rows


## What `--manager-team-member-read` printed of one member: its own `member` row, `info`
## rows, the `bullet` rows of its basic.md, each `session` row with the member's own `run`
## rows in it, `grant` rows and `setting` rows.
def parseMemberRead(text):
    info = {"name": "", "info": [], "bullets": [], "sessions": [], "grants": [], "settings": []}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "member" and len(fields) >= 11:
            info["name"] = fields[1]
        elif fields[0] == "info" and len(fields) >= 3:
            ## its description is prose; a path and a name stand as they are written
            info["info"].append((fields[1], unspaced(fields[2]) if fields[1] == "description" else absent(fields[2])))
        elif fields[0] == "bullet" and len(fields) >= 3:
            info["bullets"].append((unspaced(fields[1]), unspaced(fields[2])))
        elif fields[0] == "session" and len(fields) >= 8:
            info["sessions"].append({"id": fields[1], "name": unspaced(fields[2]), "state": fields[3], "started": fields[4],
                                     "stateAt": fields[5], "count": fields[6], "tally": fields[7], "runs": []})
        elif fields[0] == "run" and len(fields) >= 12 and info["sessions"]:
            info["sessions"][-1]["runs"].append({"session": fields[1], "spawn": fields[2], "member": fields[3],
                                                 "status": fields[4], "live": fields[5], "state": fields[6],
                                                 "started": fields[7], "resolved": fields[8], "host": fields[9],
                                                 "workspace": fields[10], "activity": fields[11]})
        elif fields[0] == "grant" and len(fields) >= 7:
            info["grants"].append({"kind": fields[1], "access": absent(fields[2]), "target": absent(fields[3]),
                                   "place": absent(fields[4]), "origin": absent(fields[5]).replace("_by_", " by "),
                                   "ends": unspaced(fields[6])})
        elif fields[0] == "setting" and len(fields) >= 5:
            info["settings"].append({"key": fields[1], "state": fields[2], "value": absent(fields[3]),
                                     "workspace": absent(fields[4])})
    return info


## One line of a list in the left pane, set in by two cells, as it is where it fits; where
## it is longer than the pane it is broken between its words and goes on under itself, set
## in further.
def hangLines(text, width):
    if textWidth(text) <= width - 3:
        return ["  " + text]
    parts = wrapToCells(text, max(10, width - 7))
    return ["  " + parts[0]] + ["      " + part for part in parts[1:]]


## What a setting reads as: its value where it is set and no secret, and for a secret only
## whether it is configured, never anything of its value. The mark of one that is missing.
MARK_MISSING = "!"


def settingWords(settingState, value):
    if settingState == "secret-set":
        return "configured"
    if settingState == "secret-missing":
        return "not configured"
    if settingState == "missing":
        return "missing" if not value else "%s (missing)" % value
    if settingState == "set":
        return value or "set"
    return settingState + (" " + value if value else "")


## The selected member for the left pane. From its row of the list: its mark and names,
## its kind, its status, whether a run of it is alive, the workspace it is set up in, and
## whether `n` starts it, or why not. Once the read of that one member has come (info):
## what it is for; its information, the bullets of its basic.md; the sessions of this
## workspace it has a run in, those with a live run first, as the operation gives them;
## its workspace, by its paths; its grants; and its settings, a secret one only as
## configured or not.
def memberLines(member, width, info=None):
    names = " ".join(word for word in (member["first"], member["family"]) if word)
    refusal = memberRefusal(member)
    where = {"here": "set up here", "elsewhere": "set up in another workspace of this machine",
             "not-present": "its workspace cannot be reached"}.get(member["setUp"], member["setUp"])
    facts = dict(info["info"]) if info else {}
    lines = [" ".join(word for word in (member["mark"], names or member["name"]) if word)
             + (", alias " + member["alias"] if member["alias"] else ""), ""]
    lines.extend(fieldLines([
        ("kind", member["kind"]),
        ("status", member["status"]),
        ("process", "a run of it is alive" if member["live"] == "running" else "no run of it is alive"),
        ("workspace", ", ".join(word for word in (member["workspace"], where) if word)),
        ("start", "not started from here: " + refusal if refusal else "n starts it with a prompt, in a session of its own"),
        ("for", facts.get("description", "")),
    ], width))
    if info is None:
        if member["setUp"] == "not-present":
            return lines + ["", "nothing more is read of it: its workspace cannot be reached from this machine"]
        return lines + ["", "its information, its sessions, its grants and its settings: not read yet"]
    if info["bullets"]:
        lines.extend(["", "its information:"])
        for name, text in info["bullets"]:
            lines.extend(hangLines("%s: %s" % (name, text), width))
    alive = len([session for session in info["sessions"] if any(run["live"] == "running" for run in session["runs"])])
    lines.extend(["", "the sessions it is in: %d%s" % (len(info["sessions"]), ", %d with a live run of it" % alive if alive else "")])
    for session in info["sessions"]:
        told = "; ".join("%s %s" % (runStateText(run), "since " + unspaced(run["started"]) if run["resolved"] == "-"
                                    else "until " + unspaced(run["resolved"])) for run in session["runs"])
        lines.append("  %s %s %s" % (cutToCells(session["name"] or session["id"], 24), cutToCells(session["state"], 9), told))
    lines.extend(["", "its workspace:"])
    for name, shown in (("workspace", "path"), ("home", "home"), ("link-kind", "link"), ("skillset-path", "skillset"), ("persona", "persona")):
        if facts.get(name):
            lines.extend(hangLines("%-9s %s" % (shown, facts[name]), width))
    lines.extend(["", "its grants: %d" % len(info["grants"])])
    for grant in info["grants"]:
        lines.extend(hangLines("%-8s %-7s %s, from %s%s" % (
            grant["kind"], grant["access"], grant["place"] or grant["target"], grant["origin"] or "-",
            ", ends " + grant["ends"] if grant["ends"] not in ("", "none") else ""), width))
    lines.extend(["", "its settings: %d" % len(info["settings"])])
    keyWidth = min(34, max([len(setting["key"]) for setting in info["settings"]] or [0]))
    for setting in info["settings"]:
        if setting["state"] == "elsewhere":
            words = "read in the workspace it is set up in"
        else:
            words = settingWords(setting["state"], setting["value"])
        lines.extend(hangLines("%s %s  %s" % (
            MARK_MISSING if setting["state"] in ("missing", "secret-missing") else " ",
            setting["key"].ljust(keyWidth), words), width))
    return lines


## What the section of the members holds, for the left pane while the section itself or
## the row that goes up is selected. None until its read has answered.
def membersSummary(state):
    if "team" not in state.rows:
        return None
    members = [row["member"] for row in state.rows["team"] if row.get("member")]
    alive = len([member for member in members if member["live"] == "running"])
    refused = len([member for member in members if memberRefusal(member)])
    lines = ["%d member%s, %d with a live run." % (len(members), "" if len(members) == 1 else "s", alive)]
    if refused:
        lines.append("%d of them %s not started from here." % (refused, "is" if refused == 1 else "are"))
    return lines


## Whether `n` starts the member of that row: one the operation would start.
def memberFits(state, row):
    return bool(row and row.get("member") and not memberRefusal(row["member"]))


## `n`: starts the selected team member with a prompt: the dialog of a prompt opens, its
## list on that member. On a row that is no member, and on a member that is not started,
## the key says its line in the status line and this is not reached.
def askStart(state, row):
    member = row.get("member") if row else None
    if member is None or memberRefusal(member):
        return ""
    return openPrompt(state, member["name"], "Start the member %s" % member["name"])


## What `--manager-spawn-member` printed: one `spawn` row, with the id of the new session,
## the member, the name of the session as its record keeps it, and the dispatch item the
## start made. Given back: the lines for the left pane, and one line for the bottom line.
def spawnAnswer(text, width):
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "spawn" and len(fields) >= 5:
            lines = fieldLines([
                ("session", fields[1]),
                ("member", fields[2]),
                ("name", unspaced(fields[3]) or "none: it shows by its id"),
                ("item", unspaced(fields[4])),
            ], width)
            return lines, "started: %s, session %s" % (fields[2], fields[1])
    return [], "the start answered no session id"


ACTION_HANDLERS["start"] = askStart
ACTION_FITS["start"] = memberFits
ACTION_REFUSALS["start"] = lambda state, row: "%s is not started: %s" % (row["member"]["name"], memberRefusal(row["member"])) if row and row.get("member") else ""


## ---- the settings: `Settings (Configuration)` ----

## What each subject of the digest holds, in words, for the head of its pane. A subject
## that is not listed here shows by its name alone.
SUBJECT_WORDS = {
    "workspace": "the paths of this workspace, and the places it knows",
    "cli": "the CLI service the workspace asks for, and each CLI the console knows",
    "systems": "each outside system, by the scopes that hold a setting of it",
    "loop": "the main loop and the heartbeat, as they last left their state",
    "scopes": "each scope that holds a key, with its keys",
    "interface": "how this console looks, saved for the user who runs it",
}
## What each <source> of a line that offers choices shows as, after its value: where the
## value comes from. One that is not listed here shows as it is printed.
SOURCE_WORDS = {
    "environment": "named by the environment",
    "user": "saved for this user",
    "default": "the default",
}
## The states of a line that say that something is not there.
STATES_MISSING = ("missing", "secret-missing")


## What `--manager-config-digest` printed, as rows: a `subject` row for each subject, in
## the order of the operation, followed by its `line` rows, which the row of the subject
## keeps. The last field of a row that has one more than its form is its label, with `_`
## for a blank: a subject and a line show by it, and by the name or the key, as the
## operation takes them, where a row has none. A line of nine fields offers choices: its
## seventh says where its value comes from, its eighth lists them, <value>=<label> with
## commas between. At the end of its row a subject shows how many of its lines are
## missing, or else what its line that offers choices is set to.
def parseDigestRows(text):
    rows = []
    bySubject = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "subject" and len(fields) >= 3:
            label = unspaced(fields[-1]) if len(fields) >= 4 else ""
            row = newRow(fields[1], label or fields[1], "record", False, fields)
            row["subject"] = {"name": fields[1], "label": label, "lines": []}
            bySubject[fields[1]] = row
            rows.append(row)
        elif fields[0] == "line" and len(fields) >= 6 and fields[1] in bySubject:
            held = {"group": absent(fields[2]), "key": absent(fields[3]), "state": fields[4], "value": absent(fields[5]),
                    "label": unspaced(fields[-1]) if len(fields) >= 7 else "", "source": "", "choices": []}
            if len(fields) >= 9:
                held["source"] = absent(fields[6])
                held["choices"] = [(choice.partition("=")[0], unspaced(choice.partition("=")[2]) or choice.partition("=")[0])
                                   for choice in absent(fields[7]).split(",") if choice]
            bySubject[fields[1]]["subject"]["lines"].append(held)
    for row in rows:
        missing = len([line for line in row["subject"]["lines"] if line["state"] in STATES_MISSING])
        offered = settingOf(row)
        if missing:
            row["tail"] = "%d missing" % missing
        elif offered is not None:
            row["tail"] = dict(offered["choices"]).get(offered["value"], offered["value"])
    return rows


## The line of a subject that offers choices, the first of them, or None: the setting
## Enter changes on that row.
def settingOf(row):
    for line in (row.get("subject") or {}).get("lines", ()) if row else ():
        if line.get("choices"):
            return line
    return None


## What one line of the digest reads as. A secret reads only as configured or not: the
## value of its row is never looked at. A scope of an outside system reads as set, with
## the keys it lacks, or as missing them; a CLI is usable or not; any other line by its
## value, a missing one marked as that.
def digestWords(subjectName, line):
    value = line["value"]
    if line.get("choices"):
        return dict(line["choices"]).get(value, value) + (", " + SOURCE_WORDS.get(line["source"], line["source"]) if line.get("source") else "")
    if line["state"] in ("secret-set", "secret-missing"):
        return settingWords(line["state"], "")
    if subjectName == "systems" and line["state"] == "set":
        return "set" + (", lacks " + value.replace(",", ", ") if value else "")
    if subjectName == "systems" and line["state"] == "missing":
        return "missing" + (": " + value.replace(",", ", ") if value else "")
    if line["key"] == "usable":
        return value or line["state"]
    if registryEpoch(value) is not None:
        value = unspaced(value)
    return settingWords(line["state"], value)


## The selected subject of the settings for the left pane: what it holds, how many lines
## and how many of them missing, then its lines group by group, each group under a line of
## its own: the mark of a missing one, its label, what it reads as, and after that its
## key, the detail, where its label is not the key. A subject and a line with no label
## show by the name and the key. Under the lines, what Enter changes where a line offers
## choices, and the style this screen is drawn in where that is not what the line says.
def subjectLines(subject, width):
    words = SUBJECT_WORDS.get(subject["name"], "")
    missing = len([line for line in subject["lines"] if line["state"] in STATES_MISSING])
    lines = wrapToCells((subject.get("label") or subject["name"]) + (": " + words if words else ""), max(10, width - 1))
    lines.append("%s%d line%s%s" % ("subject %s, " % subject["name"] if subject.get("label") else "",
                                   len(subject["lines"]), "" if len(subject["lines"]) == 1 else "s",
                                   ", %d missing, each marked %s" % (missing, MARK_MISSING) if missing else ""))
    groups = []
    for line in subject["lines"]:
        if not groups or groups[-1][0] != line["group"]:
            groups.append((line["group"], []))
        groups[-1][1].append(line)
    for group, groupLines in groups:
        lines.extend(["", group or "-"])
        keyWidth = min(34, max(textWidth(line.get("label") or line["key"] or "-") for line in groupLines))
        for line in groupLines:
            key = line.get("label") or line["key"] or ("no scope" if subject["name"] == "systems" else "-")
            detail = "  (%s)" % line["key"] if line.get("label") and line["key"] and line["label"] != line["key"] else ""
            lines.extend(hangLines("%s %s  %s%s" % (
                MARK_MISSING if line["state"] in STATES_MISSING else " ",
                key + " " * max(0, keyWidth - textWidth(key)), digestWords(subject["name"], line), detail), width))
    for line in subject["lines"]:
        if line.get("choices"):
            lines.extend(["", "Enter changes %s: %s." % (line.get("label") or line["key"], ", ".join(label for value, label in line["choices"]))])
            if line["key"] == STYLE_VARIABLE and STYLE["name"] != line["value"]:
                lines.append("This screen is drawn in %s now." % STYLE["label"])
    return lines


## Whether Enter changes something on that row: a subject with a line that offers choices.
def settingFits(state, row):
    return settingOf(row) is not None


## Enter on a subject of the settings: the dialog of its line that offers choices, with
## what it is now and its choices as radio buttons. The style of the interface stands on
## the one this screen is drawn in. A subject that offers none takes no Enter.
def askSetting(state, row):
    line = settingOf(row)
    if line is None:
        return ""
    state.answer = None
    own = line["key"] == STYLE_VARIABLE
    openDialog(state, "setting", {
        "about": {"lines": [("now", digestWords(row["subject"]["name"], line)), ("key", line["key"]),
                            "OK saves it for the user who runs this console%s. Space chooses." % (
                                ", and this screen takes it at once" if own else "")]},
        "choice": {"options": list(line["choices"]), "value": STYLE["name"] if own else line["value"]},
    }, {"line": line, "viewKey": viewKeyOf(state)}, line.get("label") or line["key"])
    return ""


## OK in the dialog of a setting: the style of the interface is taken by this screen at
## once, and the choice is saved through the operation, once, by the key of the line.
def submitSetting(state, dialog, button):
    line = dialog["about"]["line"]
    value = dialogValue(dialog, "choice")
    says = "%s: %s" % (line.get("label") or line["key"], dict(line["choices"]).get(value, value))
    if line["key"] == STYLE_VARIABLE:
        setStyle(value)
    askCall(state, "setting", line["key"], callWords("set", line["key"]) + [value], None,
            {"viewKey": dialog["about"]["viewKey"], "says": says})
    state.notice = "save asked of the tooling: %s" % says
    state.noticeOf = None
    return None


## What the save of a setting printed: its row `saved`, the key, the value as it was read
## back, whom it is saved for, and the file, set out for the left pane, and what the
## status line says of it.
def settingAnswer(text, says, width):
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "saved" and len(fields) >= 5:
            return fieldLines([("saved", fields[1]), ("value", fields[2]), ("scope", fields[3]), ("in", fields[4])], width), "saved: %s" % says
    return [line for line in text.splitlines() if line.strip()], "the save printed no row of what it saved"


ACTION_HANDLERS["setting"] = askSetting
ACTION_FITS["setting"] = settingFits
ACTION_REFUSALS["setting"] = lambda state, row: "nothing of this subject is changed from here"
DIALOG_HANDLERS["setting"] = submitSetting


## What the digest holds, for the left pane while the section itself or the row that goes
## up is selected. None until its read has answered.
def digestSummary(state):
    if "settings" not in state.rows:
        return None
    subjects = [row["subject"] for row in state.rows["settings"] if row.get("subject")]
    total = sum(len(subject["lines"]) for subject in subjects)
    missing = sum(len([line for line in subject["lines"] if line["state"] in STATES_MISSING]) for subject in subjects)
    return ["%d subject%s, %d line%s, %d missing." % (len(subjects), "" if len(subjects) == 1 else "s",
                                                      total, "" if total == 1 else "s", missing),
            "Enter changes a setting on a subject that offers choices; the others are for viewing."]


## ---- what is started with the whole terminal: `Consoles (Tools)` ----

## What `--manager-console-list` printed, as rows, in the order they come, which is the
## order of a menu: group after group. A row of a sort STARTS names: its fields by their
## names there, then, exact as they are printed, the folder it is started in and its
## command, a field a word; a line that is none of them, and one too short to hold a
## command, is left out. A row shows by its label, with its group at the end of its line.
def parseStartRows(text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        form = STARTS.get(fields[0])
        if form is None or len(fields) < len(form["fields"]) + 3:
            continue
        start = dict(zip(form["fields"], fields[1:]))
        start.update(sort=fields[0], directory=fields[len(form["fields"]) + 1], words=fields[len(form["fields"]) + 2:])
        row = newRow(start["key"], unspaced(start["label"]) or start["key"], "record", False, fields)
        row["start"] = start
        row["tail"] = unspaced(start["group"])
        rows.append(row)
    return rows


## A command for the eye, word by word: a word that holds a blank, or anything a shell
## would read as more than a word, stands between quotes, so where each word ends shows.
## Only what is shown: a command is started from its words as they are, with no shell.
def commandText(words):
    return " ".join(shlex.quote(word) for word in words)


## The selected thing to start for the left pane, from its row: its label, its key and its
## group, the folder it is started in, its command as it will be run, whether it needs a
## terminal, and what Enter does.
def startLines(start, width):
    form = STARTS[start["sort"]]
    return fieldLines([
        (form["said"], unspaced(start["label"])),
        ("key", start["key"]),
        ("group", unspaced(start["group"])),
        ("directory", start["directory"]),
        ("command", commandText(start["words"])),
        ("terminal", "it needs a terminal, on its input and on its output" if start["terminal"] == form["terminal"] else "it needs none"),
        ("start", "Enter gives it the whole terminal. The screen is back when it ends, and says how it ended."),
    ], width)


## What `Consoles (Tools)` holds, for the left pane while the section itself or the row
## that goes up is selected: how many there are to start, group by group in the order of
## the operation. None until its read has answered.
def startsSummary(state):
    if "consoles" not in state.rows:
        return None
    groups = []
    for row in state.rows["consoles"]:
        if not row.get("start"):
            continue
        if not groups or groups[-1][0] != row["tail"]:
            groups.append([row["tail"], 0])
        groups[-1][1] += 1
    total = sum(count for group, count in groups)
    if not total:
        return ["Nothing to start here: the operation listed none."]
    return ["%d to start: %s." % (total, ", ".join("%d %s" % (count, group or "-") for group, count in groups)),
            "Enter starts one with the whole terminal; the screen is back when it ends."]


## Enter on a row of `Consoles (Tools)`: what the row names is started with the whole
## terminal at the end of this turn of the screen (runChild), from its words as the
## operation printed them and in its folder.
def askRun(state, row):
    start = row.get("start") if row else None
    if start is None:
        return ""
    state.answer = None
    state.child = {"label": row["label"], "said": STARTS[start["sort"]]["said"],
                   "words": list(start["words"]), "directory": start["directory"]}
    return ""


ACTION_HANDLERS["run"] = askRun
ACTION_FITS["run"] = lambda state, row: bool(row and row.get("start"))


## How a child ended, for the status line, by its status as the system gives it: the
## status it ended with, or, below 0, the signal that ended it, by its number and its name.
def childSays(child, status):
    if status < 0:
        try:
            name = " (%s)" % signal.Signals(-status).name
        except ValueError:
            name = ""
        return "%s: ended by signal %d%s" % (child["label"], -status, name)
    return "%s: ended with status %d" % (child["label"], status)


## What was asked to be started with the whole terminal is started, and the screen waits
## for its end: the surface gives the terminal away and takes it back, however the child
## ended (its `child`). Then the status line says how it ended, and what is shown is read
## again, since it may be old by now. One that cannot be started says why in a box, whole.
def runChild(surface, state):
    child, state.child = state.child, None
    try:
        status = surface.child(child["words"], child["directory"])
    except OSError as failure:
        tell(state, "It did not start", [(child["said"], child["label"]), ("directory", child["directory"]),
                                         ("command", commandText(child["words"])), str(failure)])
        return
    state.noticeOf = None
    state.notice = childSays(child, status)
    readNow(state)


## ---- what a key does ----

## One key, on the state alone. With a dialog open the key goes to that dialog, with a
## menu open to that menu, and with a line open to that line. Else Esc and then a key
## within META_SECONDS is Alt with that key. Otherwise Alt with the hot letter of a menu opens it, and any
## other key is the key of a command of COMMANDS, or of none.
def handleKey(state, key, layout):
    if key is None or key == "RESIZE":
        return
    if layout is None:
        if key in commandKeys(commandNamed("exit")):
            state.quit = True
        return
    if key.startswith("MOUSE:"):
        what, column, line = key.split(":")[1:4]
        mouseEvent(state, what, int(column), int(line), layout)
        return
    if state.dialog is not None:
        dialogKey(state, key)
        return
    if key in OPTION_KEYS and state.line is None:
        ## what the Option key of a Mac types: Alt with that key
        key = "ALT-" + OPTION_KEYS[key]
    if state.menu is not None:
        menuKey(state, key, layout)
        return
    if state.line is not None:
        lineKey(state, key)
        return
    if key == "ESC":
        state.metaAt = state.now
        return
    if state.metaAt is not None:
        ## Esc and then a key, in time: Alt with that key
        if metaPending(state) and len(key) == 1 and key != " ":
            key = "ALT-" + key.lower()
        state.metaAt = None
    if key.startswith("ALT-") and menuOfLetter(state, key[4:]) is not None:
        openMenu(state, menuOfLetter(state, key[4:]))
        return
    command = commandOfKey(state, key)
    if command is not None:
        runCommand(state, command, layout, key)


## ---- the help ----

## `?`, F1: the keys of the screen in a box, from the declaration and in the key map of the
## style: first those that act now, on what is selected in the active window, then the
## others, then the menus, and last what every dialog takes.
def askHelp(state, row):
    acting = []
    others = []
    for command in COMMANDS:
        if not command.get("label") and not command.get("status"):
            continue
        keys = ", ".join(keyShown(key) for key in commandKeys(command))
        words = hotText(command["label"]) if command.get("label") else statusWord(state, command)
        if command["does"][0] == "action" and ACTION_HANDLERS.get(command["does"][1]) is None:
            words += " (not built)"
        (acting if commandApplies(state, command) else others).append((keys, words))
    menuKey = keyShown(commandKeys(commandNamed("menu"))[0])
    return tell(state, "Keys", [
        "The keys that act now, on what is selected in the active window:",
    ] + acting + [
        "The other keys, which act in the other window or on another kind of row:",
    ] + others + [
        "The menus: %s opens the menu bar. Esc and then its letter, or Alt with that letter, opens one:" % menuKey,
    ] + [(hotLetter(label), hotText(label)) for menuName, label in MENUS] + [
        "Up, Down, PgUp and PgDn move in the active window. In a dialog Tab and Shift-Tab go from control to"
        " control, Space toggles a box and chooses a radio button, Enter presses the first button or the one the"
        " keys are on, and Esc cancels. The mouse does what these keys do.",
    ], "information")


ACTION_HANDLERS["help"] = askHelp


## ---- the mouse ----

## The engine notes each thing it draws that a click can mean: its rectangle and what it
## stands for, a window, a row of the list, a half of a scroll bar, a menu of the bar, an
## item of the open menu, a key of the status line, the open dialog and its fields, its
## options and its buttons. A click is looked up in what the last drawing noted, the thing
## drawn last first, so there is no table of places beside the declaration.
def spot(state, left, top, width, height, what):
    state.spots.append((left, top, width, height, what))


## What was drawn at that cell, of those sorts or of any, or None.
def spotAt(state, column, line, sorts=None):
    for left, top, width, height, what in reversed(state.spots):
        if left <= column < left + width and top <= line < top + height and (sorts is None or what[0] in sorts):
            return what
    return None


## The bit of the wheel turned down, for a Python whose curses does not name it.
WHEEL_DOWN = 0x200000


## What the terminal reported of the mouse, as a key of the screen, `MOUSE:<what>:<column>:<line>`,
## or None for what the screen does not act on. The first button let go, or pressed and
## let go as one click, is `click`: a press alone is nothing, so one click of the hand is
## one click here however the terminal reports it. A double click is `double`, and the
## wheel is `up` and `down`. `buttons` are the bits curses gives.
def mouseKey(column, line, buttons):
    names = (("click", ("BUTTON1_RELEASED", "BUTTON1_CLICKED")), ("double", ("BUTTON1_DOUBLE_CLICKED",)),
             ("up", ("BUTTON4_PRESSED",)), ("down", ("BUTTON5_PRESSED",)))
    for what, bits in names:
        if any(buttons & getattr(curses, bit, WHEEL_DOWN if bit == "BUTTON5_PRESSED" else 0) for bit in bits):
            return "MOUSE:%s:%d:%d" % (what, column, line)
    return None


## The key a status line shows under that name, or None for a pair of keys shown as one.
def keyOfShown(shown):
    for key, word in KEY_WORDS.items():
        if word == shown:
            return key
    if shown == "Space":
        return " "
    if shown.startswith("Alt-"):
        return "ALT-" + shown[4:].lower()
    if len(shown) == 2 and shown.startswith("^"):
        return "CTRL-" + shown[1:].lower()
    return None if "/" in shown else shown


## One event of the mouse, on the state alone. It does nothing the keys cannot do. A key
## of the status line does what that key does, in every state. With a dialog open: a button
## is pressed, a box toggled, a radio button or a row of a list chosen, a field given the
## keys, the wheel scrolls its text, and a click outside it does nothing. With a menu open:
## an item is chosen, a name of the bar opens that menu or closes its own, and a click
## anywhere else closes the menu. Else: a name of the menu bar opens that menu; a window
## gets the keys; a row of the list is selected, and opened as Enter opens it when it was
## selected already or the click is a double one; a half of the scroll bar pages; and the
## wheel moves in the window under the pointer.
def mouseEvent(state, what, column, line, layout):
    clicked = what in ("click", "double")
    step = 1 if what == "down" else -1
    key = spotAt(state, column, line, ("key",))
    if key is not None and clicked:
        if keyOfShown(key[1]) is not None:
            handleKey(state, keyOfShown(key[1]), layout)
        return
    if state.dialog is not None:
        dialog = state.dialog
        if not clicked:
            for held in dialog["controls"]:
                if held["kind"] == "text":
                    held["top"] = max(0, held["top"] + step)
                    break
            return
        hit = spotAt(state, column, line, ("button", "option", "field"))
        if hit is None:
            return
        stops = dialogStops(dialog)
        if hit[0] == "button":
            dialog["focus"] = stops.index(("button", hit[1]))
            pressButton(state, dialog["buttons"][hit[1]][0])
            return
        control = dialog["controls"][hit[1]]
        dialog["focus"] = stops.index(("control", hit[1]))
        if hit[0] == "option":
            control["at"] = hit[2]
            chosen = control["options"][hit[2]][0]
            if control["kind"] != "checks":
                control["value"] = chosen
            elif chosen in control["value"]:
                control["value"].remove(chosen)
            else:
                control["value"].append(chosen)
        return
    if state.menu is not None:
        if not clicked:
            return
        hit = spotAt(state, column, line, ("item", "menu"))
        if hit is None or (hit[0] == "menu" and hit[1] == state.menu["menu"]):
            state.menu = None
        elif hit[0] == "menu":
            openMenu(state, hit[1])
        else:
            state.menu["item"] = hit[1]
            chooseItem(state, menuItems(state, MENUS[state.menu["menu"]][0])[hit[1]], layout)
        return
    if not clicked:
        ## the window under the pointer, or the active one where the pointer is not known
        window = spotAt(state, column, line, ("window",)) or ("window", state.focus)
        if window[1] == "list":
            moveSelection(state, listRowsHeight(state, layout), step)
        else:
            scrollView(state, viewScrollHeight(state, layout), step * 3)
        return
    hit = spotAt(state, column, line)
    if hit is None:
        return
    if hit[0] == "menu":
        openMenu(state, hit[1])
    elif hit[0] == "window":
        state.focus = hit[1]
    elif hit[0] == "bar":
        state.focus = "list"
        moveSelection(state, listRowsHeight(state, layout), 0, hit[1])
    elif hit[0] == "row":
        height = listRowsHeight(state, layout)
        index = cursorOf(state, levelRows(state), height)["index"]
        again = what == "double" or (state.focus == "list" and index == hit[1])
        state.focus = "list"
        moveSelection(state, height, hit[1] - index)
        if again:
            command = commandOfKey(state, "ENTER")
            if command is not None:
                runCommand(state, command, layout, "ENTER")


## The keys of a command in the style of now: those its key map gives it, else its own.
def commandKeys(command):
    return KEYMAPS.get(STYLE.get("keys"), {}).get(command["name"], command["keys"])


## Whether Esc was pressed and the key after it would still be taken as Alt with it.
def metaPending(state):
    return state.metaAt is not None and state.now - state.metaAt <= META_SECONDS


def commandNamed(name):
    for command in COMMANDS:
        if command["name"] == name:
            return command
    return None


## The window a command applies in alone, or None for one that applies in every window.
def commandWindow(command):
    for window in WINDOWS:
        if command["name"] in window["commands"]:
            return window["name"]
    return None


## Whether a command belongs to the view of now, the level the list is at: one that names
## no view belongs to every view.
def commandInView(state, command):
    return "views" not in command or levelPattern(state.path) in command["views"]


## The command a key means now, or None: the first of COMMANDS that has the key, belongs
## to the view, applies in the window that has the keys, and, where the key is its own on
## some rows alone, is on such a row with its handler built; one that tells why another
## does nothing ("tells") only on a row its action acts on as it is now.
def commandOfKey(state, key):
    place = placeOf(state, selectedRow(state))
    for command in COMMANDS:
        if key not in commandKeys(command) or commandWindow(command) not in (None, state.focus) or not commandInView(state, command):
            continue
        if command.get("only") and (place not in command["on"] or ACTION_HANDLERS.get(command["does"][1]) is None):
            continue
        if command.get("tells") and not actionShown(state, selectedRow(state), command["does"][1]):
            continue
        return command
    return None


## What a command is named by where the screen says something of it: as its menu shows
## it, else its word of the status line.
def commandSaid(command):
    return hotText(command["label"]) if command.get("label") else command.get("status") or command["name"]


## Why a command does not apply now, in one line (REFUSALS), or "" where it applies. A
## menu shows one that does not as greyed and does not choose it, the status line leaves
## it out, and its key does nothing: tried, by its key or by a click, it says this line in
## the status line, and no handler is called.
def commandRefusal(state, command):
    said = commandSaid(command)
    if commandWindow(command) not in (None, state.focus):
        return REFUSALS["window"] % said
    does = command["does"]
    row = selectedRow(state)
    other = REFUSALS["rowFor"] % (said, command["for"]) if command.get("for") else REFUSALS["row"] % said
    if does[0] == "action":
        if ACTION_HANDLERS.get(does[1]) is None:
            return REFUSALS["unbuilt"] % said
        if "on" not in command:
            return ""
        ## an action acts on what the left window shows: on the container too, while the
        ## selection stands on the row that goes up inside it
        with shownLevel(state, not command.get("only")):
            row = selectedRow(state)
            if placeOf(state, row) not in command["on"]:
                return other
            if actionShown(state, row, does[1]) or command.get("asks"):
                return ""
            words = ACTION_REFUSALS[does[1]](state, row) if does[1] in ACTION_REFUSALS else ""
            return "%s: %s" % (said, words) if words else REFUSALS["fits"] % said
    if does[0] == "mode":
        ## a mode is of a thing that has a log: on any other the keys of the modes do nothing
        with shownLevel(state):
            row = selectedRow(state)
            if placeOf(state, row) not in command["on"]:
                return other
            return "" if viewReadOf(state, row, "feed") is not None else REFUSALS["mode"] % said
    if does[0] == "up":
        return "" if state.path else REFUSALS["up"] % said
    if does[0] == "open":
        return "" if row is not None and (row["dive"] or row["kind"] == "up") else REFUSALS["open"] % said
    return ""


## Whether a command applies now: it belongs to the view, and nothing refuses it.
def commandApplies(state, command):
    return commandInView(state, command) and not commandRefusal(state, command)


## Whether the status line names a command now, its stricter rule: the command applies,
## and one whose operation says itself whether it does anything ("asks") also fits the
## row as it is now.
def commandOffered(state, command):
    if not commandApplies(state, command):
        return False
    if not command.get("asks"):
        return True
    with shownLevel(state, not command.get("only")):
        return actionShown(state, selectedRow(state), command["does"][1])


## What a command does, on the state alone. `key` is the key it came by, or None where a
## menu gave it.
def runCommand(state, command, layout, key=None):
    does = command["does"]
    refusal = commandRefusal(state, command)
    if refusal:
        ## it does not apply: nothing is done, and the status line says why
        state.noticeOf = None
        state.notice = refusal
        return
    if does[0] == "quit":
        state.quit = True
    elif does[0] == "focus":
        names = [window["name"] for window in WINDOWS]
        state.focus = names[(names.index(state.focus) + 1) % len(names)]
    elif does[0] == "read":
        readNow(state)
    elif does[0] == "filter":
        state.activeOnly = not state.activeOnly
        readNow(state)
    elif does[0] == "menu":
        openMenu(state, 0)
    elif does[0] == "style":
        names = [name for name, style in STYLES]
        setStyle(names[(names.index(STYLE["name"]) + 1) % len(names)])
        state.noticeOf = None
        state.notice = "interface style: %s" % STYLE["label"]
    elif does[0] == "mode":
        names = [name for name, mode in VIEW_MODES]
        setViewMode(state, does[1] or names[(names.index(state.viewMode) + 1) % len(names)])
    elif does[0] == "move":
        if state.focus == "list":
            moveSelection(state, listRowsHeight(state, layout), does[1], does[2])
        else:
            scrollView(state, viewScrollHeight(state, layout), does[1], does[2])
    elif does[0] == "open":
        diveIn(state, listRowsHeight(state, layout))
    elif does[0] == "up":
        goUp(state)
    elif does[0] == "go":
        state.path = list(does[1])
        state.focus = "list"
    elif does[0] == "action":
        ## the handler of the action, with the row that is selected
        handler = ACTION_HANDLERS[does[1]]
        state.noticeOf = None
        with shownLevel(state, not command.get("only")):
            state.notice = handler(state, selectedRow(state)) or ""


## ---- the menus ----

## The items of a menu in the view of now, in their order: the commands of that view
## COMMANDS places in it, group after group, and None where a line parts two groups.
def menuItems(state, menuName):
    listed = sorted((command for command in COMMANDS
                     if command.get("menu", ("",))[0] == menuName and commandInView(state, command)),
                    key=lambda command: command["menu"][1])
    items = []
    for command in listed:
        if items and items[-1]["menu"][1] != command["menu"][1]:
            items.append(None)
        items.append(command)
    return items


## The menus the bar holds in the view of now, each by its place in MENUS: those that
## hold a command of that view.
def menusShown(state):
    return [index for index, (menuName, label) in enumerate(MENUS) if menuItems(state, menuName)]


## The place in MENUS of the menu of the bar with that hot letter, or None.
def menuOfLetter(state, letter):
    for index in menusShown(state):
        if hotLetter(MENUS[index][1]) == letter.lower():
            return index
    return None


## Opens the pull-down of that menu, its bar on its first item.
def openMenu(state, index):
    state.menu = {"menu": index, "item": 0}


## One key while a menu is open. Left and Right go to the menu beside it in the bar, Up and Down move
## the bar, over the lines that part the groups, and around at the ends. Enter chooses the
## item the bar is on and the hot letter of an item chooses that one: the menu closes and
## the command is done, as its key would do it; an item that does not apply is not chosen,
## the menu stays open, and the status line says why (commandRefusal).
## Esc and F10 close the menu. The key that ends the screen ends it from here too.
def menuKey(state, key, layout):
    menu = state.menu
    items = menuItems(state, MENUS[menu["menu"]][0])
    if key in ("ESC", "F10"):
        state.menu = None
    elif key in ("LEFT", "RIGHT"):
        shown = menusShown(state)
        at = shown.index(menu["menu"]) if menu["menu"] in shown else 0
        openMenu(state, shown[(at + (1 if key == "RIGHT" else -1)) % len(shown)])
    elif key in ("UP", "DOWN"):
        step = 1 if key == "DOWN" else -1
        index = (menu["item"] + step) % len(items)
        while items[index] is None:
            index = (index + step) % len(items)
        menu["item"] = index
    elif key == "ENTER":
        chooseItem(state, items[menu["item"]], layout)
    elif key in commandKeys(commandNamed("exit")):
        state.quit = True
    elif key.startswith("ALT-"):
        if menuOfLetter(state, key[4:]) is not None:
            openMenu(state, menuOfLetter(state, key[4:]))
    elif len(key) == 1:
        for index, command in enumerate(items):
            if command is not None and hotLetter(command["label"]) == key.lower():
                menu["item"] = index
                chooseItem(state, command, layout)
                break


def chooseItem(state, command, layout):
    refusal = commandRefusal(state, command)
    if refusal:
        state.noticeOf = None
        state.notice = refusal
        return
    state.menu = None
    runCommand(state, command, layout)


## ---- reading through operations ----

## The words of one read: its operation, what the filter adds, what `l` adds, and the ids
## in their places. The filter is the list's own: the read that fills the level of one
## session is made without it, so that session stays in what is read whatever its state.
def readWords(entry, state, values, filtered=True):
    words = list(entry["operation"])
    if state.activeOnly and filtered:
        words.extend(entry.get("active", ()))
    if rawShown(state):
        words.extend(entry.get("log", ()))
    return [word.replace("{id}", values.get("id", "")).replace("{level}", values.get("level", "")) for word in words]


## The read that fills the list of a level: its key and its entry in READS, or None. A
## level another read fills ("from") has that read.
def listReadOf(path):
    key = "list:" + levelKey(path)
    entry = READS.get("list:" + levelPattern(path))
    if entry and entry.get("from"):
        key = entry["from"]
        entry = READS.get(key)
    return (key, entry) if entry else None


## The reads of what the left window shows, its facts and its lines: (kind, key, words).
@onShownLevel
def shownReads(state):
    wanted = []
    row = selectedRow(state)
    values = {"level": state.path[-1] if state.path else ""}
    for part in VIEW_PARTS:
        entry = viewReadOf(state, row, part)
        if entry and (part != "feed" or modeOf(state)["feed"]):
            values["id"] = row["id"]
            wanted.append((part, part + ":" + viewKeyOf(state), readWords(entry, state, values)))
    return wanted


## The row the left window shows, and its entry in READS for that part of it, or nothing.
@onShownLevel
def shownRead(state, part):
    row = selectedRow(state)
    return row, viewReadOf(state, row, part) or {}


## What the screen as it stands asks the tooling for: (kind, key, words) for the list of
## the level shown, for every list that is read whatever is shown, for the view of the
## row selected, and for what the open dialog offers, each where READS names an operation.
def wantedReads(state):
    wanted = []
    pattern = levelPattern(state.path)
    values = {"level": state.path[-1] if state.path else ""}
    shown = listReadOf(state.path)
    if shown:
        own = shown[0] == "list:" + levelKey(state.path)
        wanted.append((shown[1].get("kind", "list"), shown[0], readWords(shown[1], state, values, own)))
    for key in sorted(READS):
        entry = READS[key]
        if entry and entry.get("always") and not (shown and shown[0] == key):
            wanted.append((entry.get("kind", "list"), key, readWords(entry, state, {})))
    wanted.extend(shownReads(state))
    ## what the open dialog offers is read while it is open
    for key, values in dialogReads(state):
        if key not in [wantedKey for kind, wantedKey, words in wanted]:
            wanted.append((READS[key].get("kind", "list"), key, readWords(READS[key], state, values, False)))
    return wanted


## The reads of the open dialog: the key in READS and the values of each entry it names
## that gives an operation. A name that holds {kind} is the entry of the kind of what the
## dialog was opened on, its "target", and is asked by the id of that.
def dialogReads(state):
    if state.dialog is None:
        return []
    target = state.dialog["about"].get("target") or {}
    reads = []
    for name in DIALOGS[state.dialog["name"]].get("reads", ()):
        key = name.replace("{kind}", target.get("kind", ""))
        if READS.get(key):
            reads.append((key, {"id": target.get("id", "")} if key != name else {}))
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
    if row.get("run") and row["run"]["spawn"] == "-":
        return None
    if row.get("member") and row["member"]["setUp"] == "not-present":
        return None
    return entry


## What is shown is read at the next chance, whatever the period says.
def readNow(state):
    for kind, key, words in wantedReads(state):
        state.forced.add(key)


## How long the selection must still rest on its item before the reads of that one item
## start: 0 once it has rested, and where nothing is read of the item. Which item the
## selection rests on, and since when, is noted here.
@onShownLevel
def restLeft(state, now):
    selected = viewKeyOf(state)
    if selected != state.restKey:
        state.restKey = selected
        state.restSince = now
    row = selectedRow(state)
    if all(viewReadOf(state, row, part) is None for part in VIEW_PARTS):
        return 0.0
    return max(0.0, REST_SECONDS - (now - state.restSince))


## How long the screen waits for a key before its next turn: its turn time, or less where
## the selection rests and the reads of its item are due sooner than that.
def keyWait(state, now):
    left = restLeft(state, now)
    return min(TURN_SECONDS, left + 0.005) if left > 0 else TURN_SECONDS


## Starts each read that is due and whose kind is free: one never made, one asked for now,
## one whose words have changed, one whose period has passed. Two of one kind never run at
## once: a read that is due while its kind runs waits for the turn after that one ends.
## The reads of one item, its facts and its lines, wait until the selection has rested on
## it (restLeft): a selection that runs down a list starts none of them on its way.
def startDueReads(state, reader, now):
    resting = restLeft(state, now) > 0
    for kind, key, words in wantedReads(state):
        if reader.busy(kind) or (resting and kind in VIEW_PARTS):
            continue
        last = state.started.get(key)
        ## a read that is made once is not due again because its period has passed
        aged = now - last["at"] >= REFRESH_SECONDS and not (READS.get(key) or {}).get("once") if last else False
        due = key in state.forced or last is None or last["words"] != words or aged
        if due and reader.start(kind, key, words):
            state.started[key] = {"at": now, "words": words}
            state.forced.discard(key)


## Starts the action that waits for its start, where none runs: one at a time, in the
## order they were asked for.
def startCalls(state, reader):
    while state.calls and not reader.busy("action"):
        call = state.calls.pop(0)
        reader.start("action", call["key"], call["words"], call["input"])


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
        entry = READS.get("list:" + levelPattern(key[len("list:"):].split("/"))) or {}
        levels = parseLevels(key, entry.get("rows"), result["text"])
        for gone in state.levelsOf.pop(key, ()):
            state.rows.pop(gone, None)
        state.rows.update(levels)
        state.levelsOf[key] = list(levels)
        if entry.get("active") and all(word in result["words"] for word in entry["active"]):
            state.activeOf[key[len("list:"):]] = set(row["id"] for row in levels.get(key[len("list:"):], ()))
        state.counters.update(readCounters(entry.get("rows"), result["text"]))
    else:
        row, entry = shownRead(state, key[:4])
        if entry.get("rows") == "session-read":
            state.view["info"] = parseSessionRead(result["text"])
        elif entry.get("rows") == "ask":
            state.view["info"] = parseAskStored(result["text"])
        elif entry.get("rows") == "ask-acts":
            state.view["acts"] = parseAskActs(result["text"])
        elif entry.get("rows") == "member-read":
            state.view["info"] = parseMemberRead(result["text"])
        elif entry.get("rows") == "transcript":
            state.view["feed"] = parseTranscriptRead(result["text"])
            buildFeed(state, row)
        else:
            state.view["lines"] = result["text"].splitlines()


## The one part of the screen that calls the tooling. An operation of the dispatcher runs
## as a process of its own, with no input, or with what was typed as its input from a
## file, and its output kept in files, so a call never holds a key and never fills a pipe;
## what it wrote is taken when it has ended. One call of a kind at a time. A call that
## acts is cut off from the terminal's signals and is not ended with the screen: what was
## confirmed is carried out whole.
class OperationReader:
    ## The kinds of call that act, and so run on when the screen ends.
    LASTING = ("action",)

    def __init__(self, toolsCommand):
        self.toolsCommand = list(toolsCommand)
        self.running = {}
        self.ended = []

    def busy(self, kind):
        return kind in self.running

    def runningKeys(self):
        return dict((kind, call["key"]) for kind, call in self.running.items())

    def start(self, kind, key, words, inputText=None):
        if kind in self.running:
            return False
        outputFile = tempfile.TemporaryFile()
        errorFile = tempfile.TemporaryFile()
        inputFile = None
        if inputText is not None:
            ## what was typed goes to the operation on its standard input, never as a word of its command
            inputFile = tempfile.TemporaryFile()
            inputFile.write(inputText.encode("utf-8", "replace"))
            inputFile.flush()
            inputFile.seek(0)
        try:
            process = subprocess.Popen(self.toolsCommand + list(words),
                                       stdin=subprocess.DEVNULL if inputFile is None else inputFile,
                                       stdout=outputFile, stderr=errorFile, start_new_session=kind in self.LASTING)
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
            call["output"].close()
            call["error"].close()
        self.running = {}


## ---- the drawing ----

## The marks ahead of a title: what is shown is being read, what is shown is old.
def readMarks(state, key):
    marks = ""
    if key in state.reading.values():
        marks += MARK_READING
    if key in state.failed:
        marks += MARK_OLD
    return marks + " " if marks else ""


def listTitle(state):
    title = ROOT_TITLE
    if state.path:
        title = state.path[-1]
        for row in levelRowsAt(state, state.path[:-1]):
            if row["id"] == state.path[-1] and row["kind"] != "up":
                title = row["label"]
                break
    entry = READS.get("list:" + levelPattern(state.path))
    if entry and entry.get("active"):
        title += "  [active]" if state.activeOnly else "  [all]"
    shown = listReadOf(state.path)
    return readMarks(state, shown[0] if shown else "list:" + levelKey(state.path)) + title


@onShownLevel
def viewTitle(state):
    row = selectedRow(state)
    if row is None:
        return ""
    marks = readMarks(state, "view:" + (viewKeyOf(state) or "")) + readMarks(state, "feed:" + (viewKeyOf(state) or ""))
    marks = "".join(mark for mark in (MARK_READING, MARK_OLD) if mark in marks)
    ## the mode of the window, where the item has a log: it shows in the title
    form = " " + modeOf(state)["mark"] if viewReadOf(state, row, "feed") is not None else ""
    return (marks + " " if marks else "") + row["label"] + form


## A label with its hot letter between tildes, as parts to draw: the letter in the one
## look and the rest in the other.
def hotParts(label, look, hotLook):
    return [(part, hotLook if index % 2 else look) for index, part in enumerate(label.split("~")) if part]


def hotText(label):
    return label.replace("~", "")


def hotLetter(label):
    parts = label.split("~")
    return parts[1].lower() if len(parts) > 2 else ""


## The name of a key as a menu and the status line show it.
def keyShown(key):
    if key.startswith("ALT-"):
        return "Alt-" + key[4:].upper()
    if key.startswith("CTRL-"):
        return "^" + key[5:].upper()
    return KEY_WORDS.get(key, key)


def partsWidth(parts):
    return sum(textWidth(text) for text, look in parts)


## Draws parts, each a text and its look, one after another from that column, in no more
## than that many cells: the part that no longer fits is cut. Gives the column after them.
def putParts(surface, line, column, parts, room):
    for text, look in parts:
        if room <= 0:
            break
        width = textWidth(text)
        if width > room:
            text, width = cutToCells(text, room), room
        surface.put(line, column, text, look)
        column += width
        room -= width
    return column


## The end of parts in at most that many cells: what stands last stays whole.
def tailParts(parts, room):
    kept = []
    for text, look in reversed(parts):
        if room <= 0:
            break
        tail, used = tailToCells(text, room)
        kept.insert(0, (tail, look))
        room -= used
        if used < textWidth(text):
            break
    return kept


## A text in at most that many cells, cut with the cut mark where it is longer, and not
## filled where it is shorter.
def fitToCells(text, width):
    return text if textWidth(text) <= width else cutToCells(text, width)


## The start of a text cut away, with the cut mark in its place, so that its end stands in
## at most that many cells.
def leftCut(text, room):
    if textWidth(text) <= room:
        return text
    return MARKS["cut"] + tailToCells(text, room - 1)[0] if room > 0 else ""


## The workspace, the machine and the clock as they show in that many cells, of which
## `extra` are taken by what stands between and beside them. The machine's name and the
## clock are the last to be cut: first the workspace's name loses its start, then the
## clock its seconds, and only then the machine's name its start, never its end, which is
## the short name of the machine.
def whereShown(state, room, extra):
    name = os.path.basename(state.workspace.rstrip("/"))
    host = state.counters["host"] if state.counters.get("host", "-") not in ("", "-") else ""
    clock = state.clock
    for clock in (state.clock, state.clock[:5]):
        left = room - extra - textWidth(clock) - (1 + textWidth(host) if host else 0)
        if left >= min(textWidth(name), 2 if clock == state.clock else 1):
            return leftCut(name, left), host, clock
    if not host:
        return leftCut(name, max(1, room - extra - textWidth(clock))), host, clock
    return MARKS["cut"], leftCut(host, max(1, room - extra - textWidth(clock) - 2)), clock


## The menu bar, from its left: the system mark, then each menu of MENUS that the view has
## (menusShown), its hot letter in the look of one. The menu that is open stands in the
## look of the bar of a menu.
def menuBarParts(state):
    parts = [(" " + MARKS["system"] + " ", BAR)]
    for index in menusShown(state):
        label = MENUS[index][1]
        opened = state.menu is not None and state.menu["menu"] == index
        parts.extend(hotParts(" " + label + " ", BAR_ON if opened else BAR, BAR_ON_HOT if opened else BAR_HOT))
    return parts


## The right end of the menu bar: the workspace by the name of its folder, `@` in a look of
## its own, the machine the tooling runs on as the row of counters names it, and the
## clock. Until that row was read, and from a row that names no machine, the workspace
## stands alone. In that many cells: what is cut, and in which order, is whereShown's.
def whereParts(state, room):
    name, host, clock = whereShown(state, room, 3)
    parts = [(name, BAR)]
    if host:
        parts.extend([("@", BAR_AT), (host, BAR)])
    parts.append(("  " + clock + " ", BAR))
    return parts


def drawMenuBar(surface, state, columns):
    surface.put(0, 0, " " * columns, BAR)
    after = putParts(surface, 0, 0, menuBarParts(state), columns)
    column = textWidth(MARKS["system"]) + 2
    for index in menusShown(state):
        label = MENUS[index][1]
        spot(state, column, 0, textWidth(hotText(label)) + 2, 1, ("menu", index))
        column += textWidth(hotText(label)) + 2
    ## where the bar is too narrow for all of it, the machine and the clock stay longest
    right = tailParts(whereParts(state, columns - after - 1), columns - after - 1)
    if partsWidth(right) >= 10:
        putParts(surface, 0, columns - partsWidth(right), right, columns)


## The counters in the bottom border of the left window, from the row of counters: the sessions running
## and paused, the agents working and waiting, the asks that wait. Empty until that row
## was read; marked as old where its read last failed.
def countersText(state):
    if "running" not in state.counters:
        return ""
    text = "  ".join("%s %s" % (name, state.counters.get(name, "-")) for name in COUNTER_NAMES[:5])
    return text + (" " + MARK_OLD if "list:sessions" in state.failed else "")


## The table the rows of the list shown are drawn as, where they are those of one: its
## header is the line above them, which stays in place while they scroll. None for a
## list with no table.
def listTableOf(state):
    for row in state.rows.get(levelKey(state.path), ()):
        if row.get("table"):
            return row["table"]
    return None


## The header of a table in exactly that many cells, set in under the cell of the mark of
## the selection: the names of the columns that fit there.
def listHeadText(table, width):
    return cutToCells(" " + tableLineText(table, [""] + table["heads"], width - 1), width)


## How many lines the rows of the list have: the pane's, less the one a header takes.
def listRowsHeight(state, layout):
    return layout["listHeight"] - (1 if listTableOf(state) else 0)


## Whether Enter enters a row, which is then drawn as a folder: it dives into a level of
## its own, or a command declared with "enters" acts on it as it is now.
def rowEnters(state, row):
    if row["dive"]:
        return True
    place = placeOf(state, row)
    return any(command.get("enters") and place in command.get("on", ()) and actionShown(state, row, command["does"][1])
               for command in COMMANDS)


## One row of the list in exactly that many cells: the mark of the selection, what the row
## shows as, and at the end of the line what the row carries as its tail, its state. A row
## of a table shows as its cells in the columns that fit. A row that Enter enters has the
## mark of a folder after its name: a name too long for its room is cut ahead of that
## mark, which is never cut itself. Gives the text, and where in it the mark stands, or None.
def listRowParts(row, chosen, width, enters=False):
    shown = tableLineText(row["table"], row["cells"], width - 1) if row.get("table") else row["label"]
    head = (MARK_SELECTED if chosen else " ") + shown
    tail = row.get("tail", "")
    tailWidth = textWidth(tail)
    room = width if not tail or tailWidth + 4 > width else width - tailWidth - 1
    markAt = None
    mark = MARKS["folder"]
    if enters and not row.get("table") and room > textWidth(mark) + 2:
        if textWidth(head) > room - textWidth(mark):
            head = cutToCells(head, room - textWidth(mark))
        markAt = textWidth(head)
        head += mark
    text = cutToCells(head, room)
    return (text if room == width else text + " " + cutToCells(tail, tailWidth)), markAt


## One row of the list, drawn in that many cells: in its own look, or in the look of the
## selection; the mark of a folder in its own palette entry, but on the row the selection
## is on, whose bar is whole.
def putListRow(surface, state, line, column, row, chosen, width):
    text, markAt = listRowParts(row, chosen, width, rowEnters(state, row))
    look = row.get("look", PLAIN)
    if chosen:
        look = REVERSE if state.focus == "list" else BOLD
    surface.put(line, column, text, look)
    if markAt is not None and not chosen:
        surface.put(line, column + markAt, MARKS["folder"], FOLDER)


## ---- the compact style: two panes between two status lines, nothing spent on frames ----

## The workspace by the name of its folder, and after an `@` the machine the tooling runs
## on, as the row of counters names it; the workspace alone until that row names one.
def whereText(state):
    name = os.path.basename(state.workspace.rstrip("/"))
    return name + "@" + state.counters["host"] if state.counters.get("host", "-") not in ("", "-") else name


## The top status line of the compact style: the workspace by the name of its folder, the load average of the
## host as the row of counters gives it, marked as old where that read last failed, and
## the clock.
def topLineText(state, columns):
    load = ""
    if "load" in state.counters:
        load = "load %s%s  " % (state.counters["load"], " " + MARK_OLD if "list:sessions" in state.failed else "")
    ## the workspace gives way first, then the seconds of the clock, then the start of the machine's name
    name, host, clock = whereShown(state, columns, textWidth(load) + 3)
    right = load + clock + " "
    rightWidth = textWidth(right)
    if rightWidth >= columns:
        return cutToCells(right, columns)
    return cutToCells(" " + name + ("@" + host if host else ""), columns - rightWidth) + right


## The top line of the compact style: its status line, or, while a menu is open, the menu
## bar. The `@` between the workspace and the machine stands in a look of its own.
def drawCompactTop(surface, state, columns):
    if state.menu is not None:
        drawMenuBar(surface, state, columns)
        return
    text = topLineText(state, columns)
    surface.put(0, 0, text, REVERSE)
    load = "load %s%s  " % (state.counters["load"], " " + MARK_OLD if "list:sessions" in state.failed else "") if "load" in state.counters else ""
    name, host, clock = whereShown(state, columns, textWidth(load) + 3)
    if host and text.startswith(" " + name + "@"):
        surface.put(0, 1 + textWidth(name), "@", BOLD)


## The bottom status line of the compact style: the counters, and after them the keys
## that act for what has the keys now, each with its word, as the status line of the
## other styles names them (statusItems), as many as fit whole.
def bottomLineText(state, columns):
    text = " " + countersText(state)
    for key, word in statusItems(state):
        item = ("  " if text.strip() else "") + key + " " + word
        if textWidth(text) + textWidth(item) > columns:
            break
        text += item
    return cutToCells(text, columns)


## The whole screen in the compact style, between its two status lines: the titles, the
## column between the panes, the list, what is selected there, and the line to type in.
def drawCompact(surface, state, layout):
    columns = layout["columns"]
    viewWidth = layout["viewWidth"]
    listLeft = layout["listLeft"]
    listWidth = layout["listWidth"]
    drawCompactTop(surface, state, columns)
    panesHeight = layout["inputLine"] - layout["titleLine"] + 1
    spot(state, 0, layout["titleLine"], viewWidth, panesHeight, ("window", "view"))
    spot(state, listLeft, layout["titleLine"], listWidth, panesHeight, ("window", "list"))
    surface.put(layout["titleLine"], 0, cutToCells(" " + viewTitle(state), viewWidth),
                REVERSE if state.focus == "view" else BOLD)
    surface.put(layout["titleLine"], listLeft, cutToCells(" " + listTitle(state), listWidth),
                REVERSE if state.focus == "list" else BOLD)
    for line in range(layout["titleLine"], layout["inputLine"] + 1):
        surface.put(line, layout["separator"], MARKS["separator"], PLAIN)
    rows = levelRows(state)
    listTop = layout["bodyTop"]
    listHeight = listRowsHeight(state, layout)
    listTable = listTableOf(state)
    if listTable:
        surface.put(listTop, listLeft, listHeadText(listTable, listWidth), PLAIN)
        listTop += 1
    cursor = cursorOf(state, rows, listHeight)
    for offset in range(listHeight):
        position = cursor["top"] + offset
        if position < len(rows):
            putListRow(surface, state, listTop + offset, listLeft, rows[position], position == cursor["index"], listWidth)
            spot(state, listLeft, listTop + offset, listWidth, 1, ("row", position))
        else:
            surface.put(listTop + offset, listLeft, " " * listWidth, PLAIN)
    contentHeight = viewContentHeight(state, layout)
    headHeight = min(len(state.view["head"]), contentHeight)
    for offset in range(headHeight):
        surface.put(layout["bodyTop"] + offset, 0, cutToCells(" " + state.view["head"][offset], viewWidth), PLAIN)
    scrollView(state, contentHeight - headHeight, 0)
    viewLines = state.view["lines"]
    for offset in range(contentHeight - headHeight):
        position = state.view["top"] + offset
        text = " " + viewLines[position] if position < len(viewLines) else ""
        surface.put(layout["bodyTop"] + headHeight + offset, 0, cutToCells(text, viewWidth), PLAIN)
    said = lineSays(state, viewWidth, layout["viewHeight"])
    for offset, text in enumerate(said):
        surface.put(layout["bodyTop"] + contentHeight + offset, 0, cutToCells(" " + text, viewWidth), BOLD if offset == 0 else PLAIN)
    if not said and contentHeight < layout["viewHeight"]:
        surface.put(layout["bodyTop"] + contentHeight, 0, cutToCells(" " + itemKeysText(state), viewWidth), BOLD)
    if state.line is not None:
        prompt = " " + state.line["prompt"] + " "
        promptWidth = min(textWidth(prompt), max(0, viewWidth - 2))
        typed, typedWidth = tailToCells(state.line["text"], viewWidth - promptWidth - 1)
        surface.put(layout["inputLine"], 0, cutToCells(prompt, promptWidth), BOLD)
        surface.put(layout["inputLine"], promptWidth, cutToCells(typed, viewWidth - promptWidth), PLAIN)
        surface.cursor(layout["inputLine"], promptWidth + typedWidth)
    else:
        surface.put(layout["inputLine"], 0, cutToCells(" " + state.notice, viewWidth), PLAIN)
    surface.put(layout["bottomLine"], 0, bottomLineText(state, columns), REVERSE)


## The load average of the host as the row of counters gives it, marked as old where that
## read last failed: what stands in the bottom border of the list. Empty until that row
## was read.
def loadText(state):
    if "load" not in state.counters:
        return ""
    return "load %s%s" % (state.counters["load"], " " + MARK_OLD if "list:sessions" in state.failed else "")


## The word of a command in the status line now: of one that toggles, what its key will do.
def statusWord(state, command):
    word = command.get("status")
    if isinstance(word, tuple):
        return word[1 if getattr(state, command["toggle"]) else 0]
    return word


## The keys the status line names now, each with its word: only those that act for what
## has the keys. While a dialog is open, the keys of that dialog and of the control they
## are on, and no other; while a menu is open, or the line to type in, the keys of that.
## Else the commands of COMMANDS that have a word there and apply in the active window to
## what is selected: first those that are that window's own or act on the selected row,
## in their order, and after them those that work in every window, the menu, the exit,
## the other window, which are so the first to be left out where the line is too short.
## After Esc, while the key after it is taken as Alt with it, the letters that then act.
def statusItems(state):
    if state.dialog is not None:
        return dialogStatus(state.dialog)
    if state.menu is not None:
        return list(STATUS_KEYS["menu"])
    if state.line is not None:
        return list(STATUS_KEYS["line"])
    if metaPending(state):
        ## after Esc: the keys that are Alt with a letter, each by its letter alone
        return ([(hotLetter(MENUS[index][1]), hotText(MENUS[index][1])) for index in menusShown(state)]
                + [(key[4:], statusWord(state, command) or hotText(command["label"])) for command in COMMANDS
                   for key in commandKeys(command) if key.startswith("ALT-")])
    own = []
    everywhere = []
    for command in COMMANDS:
        if command.get("status") and commandOffered(state, command) and command["does"] != ("mode", state.viewMode):
            wide = commandWindow(command) is None and "on" not in command
            (everywhere if wide else own).append((keyShown(commandKeys(command)[0]), statusWord(state, command)))
    return own + everywhere


## The status line: the keys that work now, each in the look of a hot letter and followed
## by its word, as many as fit; and after a mark what the screen says, the outcome of the
## last action. What the screen says has its room first, up to two thirds of the line, and
## the keys that do not fit beside it are left out, the last ones first.
def drawStatusLine(surface, state, line, columns):
    surface.put(line, 0, " " * columns, BAR)
    notice = state.notice if state.line is None and state.dialog is None else ""
    reserved = min(textWidth(notice) + 4, columns * 2 // 3) if notice else 0
    column = 1
    for key, word in statusItems(state):
        width = textWidth(key) + 1 + textWidth(word)
        if column + width > columns - reserved:
            break
        surface.put(line, column, key, BAR_HOT)
        surface.put(line, column + textWidth(key) + 1, word, BAR)
        spot(state, column, line, width, 1, ("key", key))
        column += width + 2
    if notice and columns - column > 2:
        surface.put(line, column, MARKS["separator"] + " " + cutToCells(notice, columns - column - 2), BAR)


## The frame of a window: double for the active one and single for another, its title in
## the middle of the top border, `foot` in the bottom border from its left, and its right
## border a scroll bar where `bar` says that it holds more than it shows: how many it
## holds, the first one shown, how many it shows.
def drawFrame(surface, box, title, active, foot="", bar=None):
    left, top, width, height = box
    marks = MARKS["frameOn" if active else "frame"]
    look = FRAME_ON if active else FRAME
    room = width - 2
    bottom = top + height - 1
    surface.put(top, left, marks[0] + marks[1] * room + marks[2], look)
    if title and room >= 6:
        text = " " + fitToCells(title, room - 4) + " "
        surface.put(top, left + 1 + (room - textWidth(text)) // 2, text, look)
    rows = height - 2
    barred = bar is not None and bar[0] > bar[2] and rows >= 3
    thumb = 1 + bar[1] * (rows - 3) // max(1, bar[0] - bar[2]) if barred else 0
    for offset in range(rows):
        surface.put(top + 1 + offset, left, marks[3], look)
        if barred:
            mark = "barUp" if offset == 0 else "barDown" if offset == rows - 1 else "barThumb" if offset == thumb else "barTrack"
            surface.put(top + 1 + offset, left + width - 1, MARKS[mark], SCROLL)
        else:
            surface.put(top + 1 + offset, left + width - 1, marks[3], look)
    surface.put(bottom, left, marks[4] + marks[1] * room + marks[5], look)
    if foot and room >= 6:
        surface.put(bottom, left + 2, " " + fitToCells(foot, room - 4) + " ", look)


## The body of a window that shows lines: what is selected in the list. Its head, which
## does not scroll; under it its lines; and at its foot the keys of the item, or, while a
## line is typed in, what that line says of itself.
def drawLinesBody(surface, state, layout, box):
    column = box[0] + 1
    top = box[1] + 1
    room = box[2] - 2
    contentHeight = viewContentHeight(state, layout)
    headHeight = min(len(state.view["head"]), contentHeight)
    for offset in range(headHeight):
        surface.put(top + offset, column, cutToCells(state.view["head"][offset], room), PLAIN)
    scrollView(state, contentHeight - headHeight, 0)
    viewLines = state.view["lines"]
    for offset in range(contentHeight - headHeight):
        position = state.view["top"] + offset
        surface.put(top + headHeight + offset, column, cutToCells(viewLines[position] if position < len(viewLines) else "", room), PLAIN)
    said = lineSays(state, layout["viewWidth"], layout["viewHeight"])
    for offset, text in enumerate(said):
        surface.put(top + contentHeight + offset, column, cutToCells(text, room), BOLD if offset == 0 else PLAIN)
    if not said and contentHeight < layout["viewHeight"]:
        surface.put(top + contentHeight, column, cutToCells(itemKeysText(state), room), BOLD)
    return None


## The body of a window that shows rows: the level of the list, its selection in the look
## of the bar while the window is active. Gives what its scroll bar goes by.
def drawRowsBody(surface, state, layout, box):
    column = box[0] + 1
    top = box[1] + 1
    room = box[2] - 2
    rows = levelRows(state)
    rowsHeight = listRowsHeight(state, layout)
    table = listTableOf(state)
    if table:
        surface.put(top, column, listHeadText(table, room), PLAIN)
        top += 1
    cursor = cursorOf(state, rows, rowsHeight)
    for offset in range(rowsHeight):
        position = cursor["top"] + offset
        if position < len(rows):
            putListRow(surface, state, top + offset, column, rows[position], position == cursor["index"], room)
            spot(state, column, top + offset, room, 1, ("row", position))
        else:
            surface.put(top + offset, column, " " * room, PLAIN)
    return (len(rows), cursor["top"], rowsHeight)


## The bodies the engine draws, by the name a window of WINDOWS gives under "shows".
BODIES = {"lines": drawLinesBody, "rows": drawRowsBody}


## One window of WINDOWS, drawn from its declaration: its body, then its frame around it.
def drawWindow(surface, state, layout, window):
    box = layout["boxes"][window["name"]]
    spot(state, box[0], box[1], box[2], box[3], ("window", window["name"]))
    held = BODIES[window["shows"]["body"]](surface, state, layout, box)
    foot = globals()[window["foot"]](state) if window.get("foot") else ""
    drawFrame(surface, box, globals()[window["title"]](state), state.focus == window["name"], foot,
              held if window.get("bar") else None)
    rows = box[3] - 2
    if window.get("bar") and held is not None and held[0] > held[2] and rows >= 3:
        ## the scroll bar: its upper half pages up, its lower half down
        spot(state, box[0] + box[2] - 1, box[1] + 1, 1, rows // 2, ("bar", -1))
        spot(state, box[0] + box[2] - 1, box[1] + 1 + rows // 2, 1, rows - rows // 2, ("bar", 1))


## The pull-down of the menu that is open, under its name in the menu bar: a frame, its
## items with their hot letters and at the right their keys, a line between two groups,
## an item that does not apply greyed, the bar on one item, and its shadow.
def drawMenu(surface, state, layout):
    menu = state.menu
    items = menuItems(state, MENUS[menu["menu"]][0])
    listed = [command for command in items if command is not None]
    if not listed:
        ## the view has left the menu behind: it closes
        state.menu = None
        return
    labelWidth = max(textWidth(hotText(command["label"])) for command in listed)
    keyWidth = max(textWidth(keyShown(commandKeys(command)[0])) for command in listed)
    width = labelWidth + keyWidth + 6
    left = 3 + sum(textWidth(hotText(MENUS[index][1])) + 2 for index in menusShown(state) if index < menu["menu"])
    left = max(0, min(left, layout["columns"] - width - 2))
    frame = MARKS["frame"]
    last = layout["lines"] - 2
    surface.put(1, left, frame[0] + frame[1] * (width - 2) + frame[2], BAR)
    line = 1
    for index, command in enumerate(items):
        if line + 1 >= last:
            break
        line += 1
        if command is None:
            surface.put(line, left, MARKS["rule"][0] + MARKS["rule"][1] * (width - 2) + MARKS["rule"][2], BAR)
            continue
        on = index == menu["item"]
        spot(state, left + 1, line, width - 2, 1, ("item", index))
        look = BAR_ON if on else BAR if commandApplies(state, command) else BAR_OFF
        hotLook = look if look == BAR_OFF else BAR_ON_HOT if on else BAR_HOT
        surface.put(line, left, frame[3], BAR)
        ## the mode the left window is in is marked
        lead = MARKS["on"] if command["does"] == ("mode", state.viewMode) else " "
        column = putParts(surface, line, left + 1, hotParts(lead + command["label"], look, hotLook), width - 2)
        keyText = keyShown(commandKeys(command)[0])
        surface.put(line, column, " " * (left + width - 2 - column - textWidth(keyText)) + keyText + " ", look)
        surface.put(line, left + width - 1, frame[3], BAR)
        surface.put(line, left + width, "  ", SHADOW)
    line += 1
    surface.put(line, left, frame[4] + frame[1] * (width - 2) + frame[5], BAR)
    surface.put(line, left + width, "  ", SHADOW)
    if line + 1 <= last:
        surface.put(line + 1, left + 2, " " * width, SHADOW)


## The whole screen, drawn again from the state in the style of now: every cell of every
## line, so nothing of an earlier drawing, of an earlier size or of another style is left.
## The compact style has a drawing of its own (drawCompact). With frames: the desktop first, then each window
## of WINDOWS on it, the line to type in where it is open, the menu bar, the dialog that
## is open, drawn over the windows in every style, the status line, and the menu that is open.
def drawScreen(surface, state):
    columns, lines = surface.size()
    layout = layoutOf(columns, lines)
    surface.clear()
    surface.cursor(None, None)
    state.spots = []
    if layout is not None and state.dialog is not None:
        state.dialog["plan"] = dialogPlan(state.dialog, columns, lines)
    if layout is None:
        if columns > 0 and lines > 0:
            surface.put(0, 0, cutToCells("Too small: %dx%d (needs %dx%d)" % (columns, lines, MIN_COLUMNS, MIN_LINES), columns), PLAIN)
        surface.show()
        return
    if not STYLE["frames"]:
        drawCompact(surface, state, layout)
        if state.dialog is not None:
            drawDialog(surface, state, columns, lines)
        if state.menu is not None:
            drawMenu(surface, state, layout)
        surface.show()
        return
    ## the desktop shows where no window stands
    for line in range(1, lines - 1):
        column = 0
        for left, top, width, height in sorted(layout["boxes"].values()):
            if top <= line < top + height:
                if left > column:
                    surface.put(line, column, MARKS["shade"] * (left - column), DESKTOP)
                column = max(column, left + width)
        if column < columns:
            surface.put(line, column, MARKS["shade"] * (columns - column), DESKTOP)
    for window in WINDOWS:
        drawWindow(surface, state, layout, window)
    if state.line is not None:
        ## the line to type in, over the bottom border of the left window: what it asks for,
        ## and the field with what was typed, its end in view
        viewWidth = layout["viewWidth"]
        prompt = " " + state.line["prompt"] + " "
        promptWidth = min(textWidth(prompt), max(0, viewWidth - 2))
        typed, typedWidth = tailToCells(state.line["text"], viewWidth - promptWidth - 1)
        surface.put(layout["inputLine"], 1, cutToCells(prompt[1:], promptWidth - 1), BOLD)
        surface.put(layout["inputLine"], promptWidth, cutToCells(typed, viewWidth - promptWidth), REVERSE)
        surface.cursor(layout["inputLine"], promptWidth + typedWidth)
    drawMenuBar(surface, state, columns)
    if state.dialog is not None:
        drawDialog(surface, state, columns, lines)
    drawStatusLine(surface, state, layout["bottomLine"], columns)
    if state.menu is not None:
        drawMenu(surface, state, layout)
    surface.show()


## The size of the terminal as it is now, taken into the state: gives the layout of it,
## or None where it is too small to draw.
def sizeTaken(surface, state):
    columns, lines = surface.size()
    layout = layoutOf(columns, lines)
    state.viewWidth = layout["viewWidth"] if layout else 0
    state.viewHeight = layout["viewHeight"] if layout else 0
    return layout


## One turn of the screen: the key that came, if one did; what that key asked to be started
## with the whole terminal, which is waited for here; the calls that have ended; the
## actions that were asked for; the reads that are due now; the drawing. `now` is a clock
## that only goes forward.
def screenTurn(surface, state, reader, now, key):
    layout = sizeTaken(surface, state)
    state.clock = time.strftime("%H:%M:%S", time.localtime(nowEpoch()))
    state.now = now
    handleKey(state, key, layout)
    if state.child is not None:
        ## the terminal is another's until that ends: its size is taken again after it
        runChild(surface, state)
        sizeTaken(surface, state)
    if reader is not None:
        for result in reader.collect():
            applyResult(state, result)
        startCalls(state, reader)
        startDueReads(state, reader, now)
        state.reading = reader.runningKeys()
    if state.dialog is not None and state.dialog["name"] in DIALOG_FILLS:
        DIALOG_FILLS[state.dialog["name"]](state, state.dialog)
    followSelection(state)
    drawScreen(surface, state)


## ---- the terminal ----

## The surface of the real terminal: a curses window. A text is drawn where it is put, and
## whoever puts it has cut it to fit.
class CursesSurface:
    def __init__(self, window):
        self.window = window
        self.plain, self.coloured = self.looksOf()
        self.keyNames = {
            curses.KEY_UP: "UP", curses.KEY_DOWN: "DOWN", curses.KEY_LEFT: "LEFT", curses.KEY_RIGHT: "RIGHT",
            curses.KEY_PPAGE: "PGUP", curses.KEY_NPAGE: "PGDN", curses.KEY_ENTER: "ENTER",
            curses.KEY_BACKSPACE: "BACKSPACE", curses.KEY_RESIZE: "RESIZE", curses.KEY_BTAB: "BACKTAB",
            curses.KEY_F1: "F1", curses.KEY_F5: "F5", curses.KEY_F6: "F6", curses.KEY_F9: "F9", curses.KEY_F10: "F10",
        }
        self.charNames = {"\t": "TAB", "\n": "ENTER", "\r": "ENTER", "\x1b": "ESC", "\x7f": "BACKSPACE", "\b": "BACKSPACE",
                          "\x18": "CTRL-x"}
        ## Where the pointer was last, for a turn of the wheel that comes with no place.
        self.pointer = (-1, -1)
        self.mouse(True)

    ## The mouse, where the terminal reports one: reported to the screen, its first button
    ## at once, with no wait for a second click, and the wheel; or not reported at all, as
    ## while the terminal is another's. A terminal that reports none changes nothing.
    def mouse(self, reported):
        try:
            curses.mousemask((curses.BUTTON1_PRESSED | curses.BUTTON1_RELEASED | curses.BUTTON1_CLICKED
                              | curses.BUTTON4_PRESSED | getattr(curses, "BUTTON5_PRESSED", WHEEL_DOWN)) if reported else 0)
            curses.mouseinterval(0)
        except (curses.error, AttributeError):
            pass

    ## The terminal leaves the mode of the screen, for a child that is given it whole: the
    ## mouse is no longer reported, the cursor shows, the keypad is the terminal's own, the
    ## mode of the screen is kept for the way back, and the terminal is the shell's again.
    def leave(self):
        self.mouse(False)
        for restore in (lambda: curses.curs_set(1), lambda: self.window.keypad(False), curses.def_prog_mode, curses.endwin):
            try:
                restore()
            except curses.error:
                pass

    ## The terminal is the screen's again: its mode as it was kept, the keypad, the mouse.
    ## What was typed and not read by the child is dropped, not taken as keys of the screen.
    ## The size of the terminal is read anew, since it may have changed meanwhile and no
    ## signal of that need have come here, and the next drawing draws every cell.
    def back(self):
        for restore in (curses.reset_prog_mode, lambda: self.window.keypad(True), curses.flushinp):
            try:
                restore()
            except curses.error:
                pass
        self.mouse(True)
        try:
            size = os.get_terminal_size(sys.stdout.fileno())
            if curses.is_term_resized(size.lines, size.columns):
                curses.resizeterm(size.lines, size.columns)
        except (OSError, ValueError, AttributeError, curses.error):
            pass
        try:
            self.window.clearok(True)
        except curses.error:
            pass

    ## Gives the whole terminal to a child and waits for its end: the command from its words
    ## as they are, with no shell, started in that folder, with the environment and the
    ## streams of the screen. However the child ends, and whatever fails here, the terminal
    ## is taken back first (back). While the child runs an interrupt and a quit typed at
    ## the terminal are the child's alone: the screen notes them and does not end with them,
    ## and since it does not ignore them the child starts with what the system does on them.
    ## Gives the status of the child as the system gives it, below 0 the signal that ended
    ## it. A command that cannot be started fails as the system says (OSError).
    def child(self, words, directory):
        self.leave()
        held = {}
        try:
            for number in (signal.SIGINT, signal.SIGQUIT):
                held[number] = signal.signal(number, lambda signalNumber, stackFrame: None)
            return subprocess.call(words, cwd=directory)
        finally:
            for number, handler in held.items():
                signal.signal(number, handler)
            self.back()

    ## What each look of LOOKS is on this terminal, twice: in bold, reverse and dim alone,
    ## and in its colours, or None where the terminal has not eight of them.
    def looksOf(self):
        flags = {"B": curses.A_BOLD, "R": curses.A_REVERSE, "D": curses.A_DIM}
        plain = []
        for letter, mono, text, ground, bright in LOOKS:
            attribute = curses.A_NORMAL
            for flag in mono:
                attribute |= flags[flag]
            plain.append(attribute)
        try:
            if not (curses.has_colors() and curses.COLORS >= 8):
                return plain, None
            ## what is drawn with no colour stands in the terminal's own two, not in white on black
            curses.use_default_colors()
            coloured = []
            pairs = {}
            for letter, mono, text, ground, bright in LOOKS:
                if (text, ground) not in pairs:
                    curses.init_pair(len(pairs) + 1, getattr(curses, "COLOR_" + text.upper()), getattr(curses, "COLOR_" + ground.upper()))
                    pairs[(text, ground)] = len(pairs) + 1
                coloured.append(curses.color_pair(pairs[(text, ground)]) | (curses.A_BOLD if bright else 0))
            return plain, coloured
        except (curses.error, AttributeError):
            return plain, None

    def size(self):
        lines, columns = self.window.getmaxyx()
        return columns, lines

    ## The looks of the style of now: its colours where it has them and the terminal too.
    def looks(self):
        return self.coloured if STYLE["colours"] and self.coloured is not None else self.plain

    def clear(self):
        try:
            self.window.bkgdset(" ", self.looks()[PLAIN])
        except curses.error:
            pass
        self.window.erase()

    def put(self, line, column, text, look):
        if MARKS["plain"]:
            text = plainText(text)
        try:
            self.window.addstr(line, column, text, self.looks()[look])
        except curses.error:
            ## the last cell of the screen: it is written, and the cursor has nowhere to go
            pass

    def cursor(self, line, column):
        try:
            if line is None:
                curses.curs_set(0)
            else:
                curses.curs_set(1)
                self.window.move(line, column)
        except curses.error:
            pass

    def show(self):
        self.window.refresh()

    def read(self):
        try:
            return self.window.get_wch() if hasattr(self.window, "get_wch") else self.window.getch()
        except curses.error:
            return None

    ## The next key by its name, or None when none came within that time. Alt with a key
    ## comes from a terminal as Esc and that key at once, and is named `ALT-` and the key.
    def key(self, seconds):
        self.window.timeout(int(seconds * 1000))
        got = self.read()
        if got is None:
            return None
        if isinstance(got, int):
            if got == getattr(curses, "KEY_MOUSE", -1):
                try:
                    device, column, line, depth, buttons = curses.getmouse()
                except curses.error:
                    ## a curses that has no fifth button reports the wheel turned down as an
                    ## event of the mouse it cannot give: that, and nothing else, comes so
                    if hasattr(curses, "BUTTON5_PRESSED"):
                        return None
                    return "MOUSE:down:%d:%d" % self.pointer
                self.pointer = (column, line)
                return mouseKey(column, line, buttons)
            if got in self.keyNames:
                return self.keyNames[got]
            if got < 0 or got > 255:
                return None
            got = chr(got)
        if got == "\x1b":
            self.window.timeout(0)
            after = self.read()
            if isinstance(after, str) and len(after) == 1 and after.isprintable() and after != " ":
                return "ALT-" + after.lower()
            return "ESC"
        if got in self.charNames:
            return self.charNames[got]
        return got if got.isprintable() else None


def runScreen(window, state, reader):
    surface = CursesSurface(window)
    key = None
    while True:
        screenTurn(surface, state, reader, time.monotonic(), key)
        if state.quit:
            return
        key = surface.key(keyWait(state, time.monotonic()))


## Why the screen cannot start here, or None where it can.
def screenRefusal():
    if curses is None:
        return "the manager screen needs the curses module of Python, and this Python has none: %s" % sys.executable
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        return "the manager screen needs a terminal, and its input or its output is not one"
    return None


def endOnSignal(signalNumber, stackFrame):
    raise SystemExit(128 + signalNumber)


## The command the screen calls the dispatcher by: with the bash the tooling runs in where it handed one on
## (MDAT_BASH, set at the tool's own entry), so that no `bash` has to be found on the PATH for the first line
## of the script; handed none, by the script's own path, as before.
def toolsCommandOf(toolsPath):
    bashPath = os.environ.get("MDAT_BASH", "")
    if os.path.isabs(bashPath) and os.access(bashPath, os.X_OK):
        return [bashPath, toolsPath]
    return [toolsPath]


def main(arguments):
    options = {"--workspace": "", "--tools": "", "--style": ""}
    position = 0
    while position < len(arguments):
        if arguments[position] not in options or position + 1 >= len(arguments):
            sys.stderr.write("%s expects: --workspace <path> --tools <dispatcher> [--style <name>], got: %s\n" % (PREFIX, " ".join(arguments)))
            return 1
        options[arguments[position]] = arguments[position + 1]
        position += 2
    if not options["--tools"]:
        sys.stderr.write("%s expects: --workspace <path> --tools <dispatcher>\n" % PREFIX)
        return 1
    refusal = screenRefusal()
    if refusal is not None:
        sys.stderr.write("%s %s\n" % (PREFIX, refusal))
        return 1
    try:
        locale.setlocale(locale.LC_ALL, "")
    except locale.Error:
        pass
    ## The codeset of the locale itself: what Python prefers for its own files says UTF-8
    ## also where the terminal's locale is not.
    try:
        codeset = locale.nl_langinfo(locale.CODESET)
    except (AttributeError, ValueError):
        codeset = locale.getpreferredencoding(False)
    if "utf" not in codeset.lower():
        plainMarks()
    ## A lone Esc is told from the start of a longer key at once, not after a second.
    os.environ.setdefault("ESCDELAY", "25")
    ## The style of this start: the one it is given, else the one the environment names, else
    ## the first; a name that is no style leaves the first.
    setStyle(options["--style"] or os.environ.get(STYLE_VARIABLE, "") or STYLE_FIRST)
    state = ManagerState(options["--workspace"])
    reader = OperationReader(toolsCommandOf(options["--tools"]))
    signal.signal(signal.SIGTERM, endOnSignal)
    signal.signal(signal.SIGHUP, endOnSignal)
    ## curses.wrapper gives the terminal back as it was before anything else happens, on
    ## every way out: the quit key, a signal, a failure.
    try:
        curses.wrapper(runScreen, state, reader)
    except KeyboardInterrupt:
        return 130
    except Exception as failure:
        where = ""
        trace = failure.__traceback__
        while trace is not None:
            where = "%s:%d" % (os.path.basename(trace.tb_frame.f_code.co_filename), trace.tb_lineno)
            trace = trace.tb_next
        sys.stderr.write("%s the screen failed, and the terminal was given back first: %s: %s (%s)\n" % (
            PREFIX, type(failure).__name__, failure, where))
        return 1
    finally:
        reader.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
