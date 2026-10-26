##
## AgentsManagerScreen.Windows.py -- the declaration of the windows, the view modes, the menus, the commands with their keys and the refusals.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## The key maps: the key map is the style's ("keys" there names it). Each gives the keys of
## the commands whose keys are not the same in every style, by the name of the command;
## every other command has the keys COMMANDS gives it. Turbo Vision's map ends the screen
## with Ctrl-X, which every terminal delivers with no setting and which is the key its
## status line and its menu name, with Alt-X and by the Exit item of its menu, and a bare
## `q` does nothing there.
KEYMAPS = {
    "tv": {"exit": ("CTRL-x", "ALT-x")},
}
## What the Option key of a Mac types with a letter or a digit on a US layout, where the
## terminal does not send Option as Meta: each counts as Alt with that key, for the keys
## the screen takes with Alt, outside a dialog, where it is text. On another layout these
## do not come, and nothing is taken for them.
OPTION_KEYS = {"≈": "x", "©": "g", "ß": "s", "µ": "m", "√": "v", "˙": "h", "œ": "q",
               "¡": "1", "™": "2", "£": "3", "¢": "4", "∞": "5", "§": "6", "¶": "7", "•": "8", "ª": "9"}
## Esc and then a key within this many seconds is Alt with that key, where no menu and no
## dialog is open: the Meta every terminal delivers, also one that sends no Alt and keeps
## the function keys for itself. Esc alone closes a menu and a dialog at once, as before.
META_SECONDS = 1.0
## The windows of the desktop, tiled. Each is declared by its name; the function that gives
## its title, which stands in the middle of its top border; its place, the side it stands
## on and, for one that does not take the rest, how many tenths of the width; what it
## shows; and the commands that apply in it alone. "shows" names the body the engine
## draws in it, "rows" a list with a selection or "lines" what is selected there, and the
## entries of READS it is filled from, by what their names begin with: the operation and
## the form of its rows stand there. "foot" names the function whose text stands in its
## bottom border, and "bar" says that its right border is a scroll bar while it holds more
## than it shows. No window has a foot now: the borders are plain, and what stood in them,
## the counters and the load, is the dashboard's. A command that no window names applies
## in every window, and so does a command of a plugin that names none under "window": the buttons
## of the left window, wrap and cut, work whatever window has the keys, so no Tab is needed to
## reach them.
WINDOWS = (
    {"name": "view", "title": "viewTitle", "place": {"side": "left"},
     "shows": {"body": "lines", "reads": VIEW_PARTS}, "bar": True, "count": "viewCount",
     "commands": ("pan", "row")},
    {"name": "list", "title": "listTitle", "place": {"side": "right", "tenths": 3},
     "shows": {"body": "rows", "reads": ("list",)}, "bar": True,
     "commands": ("open", "up", "alphabetical", "filter", "page-left", "climb", "page-right")},
)
## The keys of navigation, which stay with the window that has the keys: a command that applies in one window alone (WINDOWS, "window")
## has these keys there alone. Every other key of a command is a button, and works whichever window has the keys: the
## wrap and the cut of the lines, the raw log, the filter of the list, no Tab needed to reach them. The key of the filter line of
## a table (`/`, as in less) is one of navigation too: it opens a line the left window types into.
NAVIGATION_KEYS = ("ENTER", "LEFT", "RIGHT", "UP", "DOWN", "PGUP", "PGDN", "HOME", "END", " ", "BACKSPACE", "TAB", "ESC", "/")
## The window the keys go to when the screen starts.
WINDOW_FIRST = "list"
## The split between the two windows, which the user moves for the run of the screen: by
## the keys of the commands that do ("split", ...), and with the mouse on the border
## between the windows. It is kept as a ratio, the share of the width the right window
## takes, so it holds when the terminal changes its size: None, the share its place
## declares, until it is moved. "step": the share one press of a key moves it by.
## "least" and "most": the limits, absolute numbers of cells, its frame counted in, and of
## the RIGHT window alone, which cannot scroll sideways; the left window takes the rest,
## and wraps or scrolls. A limit bounds what is drawn at the width of now, and never
## rewrites the ratio that is kept.
SPLIT = {"step": 0.05, "least": 20, "most": 80}
## How the left window shows a line longer than itself when the screen starts: wrapped at
## words (True), or cut with the cut mark and scrolled sideways. The choice is the user's
## for the run of the screen, whatever is selected; a view of panels (blocksView) is
## always wrapped, and the choice is not offered there. What stands for each of the two in
## the title of the window, always, beside its mode; how wide a line is set out while
## lines are not wrapped; and how many cells one press scrolls sideways.
WRAP_FIRST = True
WRAP_MARK = "[wrap]"
CUT_MARK = "[cut]"
UNWRAPPED_WIDTH = 1000
PAN_STEP = 8
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
## The mode of the left window where it shows a Markdown text or the help (markdownShown):
## one of its own, "summary" rendered or "raw" as it is, by the keys of those two modes.
## It is the user's for the run too, and kept apart from the mode of a session: the raw log
## of a session leaves a text rendered, and a text shown raw leaves a session as it was.
TEXT_MODE_FIRST = "summary"
## The look of a line of the left window by what it is in a log, where that is not the
## plain one. "head": the head line of an entry, its time and who, paler than its body.
LINE_LOOKS = {"head": DIM}
## The texts of the left window that are Markdown, drawn rendered: a text that a read shows
## as it is (an entry of READS with no form of rows: a skillset file, an item of the team
## data), of an item whose name ends in one of "suffixes", where the list is at one of the
## places of MARKDOWN_ON. Its headings, its emphasis, its lists, its blocks of code, its
## tables, its links as their text, its rules, its quotes and its front matter are set out
## to the width of the window, wrapped or cut as the window is, and drawn in the looks of
## MARKDOWN_LOOKS, so in the colours of the style of now. In the raw mode (`g`) the window
## shows it as it is, in the summary mode (`b`) rendered again; its title says which, by the
## mark of the raw mode or by "mark". It is set out once for each text, width and mode, never
## on a tick (viewText). A text of more than "lines" lines is set out that far, and the rest
## follows as it is under the line "bound" says. It is rendered by the family's one renderer,
## lib/catMarkdown of myx.common ("command", under its root), in its form for a program
## (--spans), in "seconds" at most; where none is there, or it fails, the text shows as it is.
MARKDOWN = {"suffixes": (".md", ".markdown"), "lines": 2000, "mark": "[markdown]",
            "bound": "The first %d lines are rendered; the %d after them follow as they are.",
            "command": "bin/lib/catMarkdown.Common", "seconds": 10}
## The places of those texts, MARKDOWN_ON, and the places of the help of the tooling, which is
## Markdown too, rendered as `--help` prints it (markdownLines), MARKDOWN_HELP: the registries
## `on` and `help` of the Markdown view (Plugins.py), where each app feature puts its own places.
## The help's are an operation of `Member Help`, the folder of a member whose summary is the help
## (helpSummary), a command of `Tooling Commands`, whose help the family writes in the same
## layout, and a manual of a project, the README.md and the MAGIC.md, each rendered, and raw in
## the raw mode, as a Markdown text is.
## The look of each part of a rendered Markdown text, by the name catMarkdown gives it: its
## headings by their level, from the third on as the third; its strong and its emphasized
## words; its code; a quote; a rule; its front matter; the mark of an item of a list; the
## head of a table; the text of a link.
MARKDOWN_LOOKS = {"h1": FOLDER, "h2": BOLD, "h3": BOLD, "strong": BOLD, "em": LEVEL_OK, "code": DIM,
                  "quote": DIM, "rule": DIM, "meta": DIM, "item": FOLDER, "head": BOLD, "link": FOLDER}

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

## The commands of the engine, each declared once; those of an app feature are declared with the feature's plugin (Plugins.py), in
## the same form, and COMMANDS is built from both (ENGINE_COMMANDS here). "keys": its keys, the first being the one its menu and
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
## view, but the views "except" names. In a view all its commands stand in their menus and have their keys, and a
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
## that level. ("move", <rows>, <pages>) moves in the active window, MOVE_ALL rows to its top or its bottom;
## ("move", <rows>, <pages>, <name>) does the command of that name instead where the selection stands on the
## first row of the list; ("climb",) takes the list up one level and, at the root, does nothing. The others are the
## engine's own: "open", "up", "focus", "filter", "read", "menu", "style", "quit",
## "demand", which asks for the list shown where that is read on demand alone (READS), or
## for the list of the folder selected where that one is, and
## ("mode", <name>), which takes the left window to that mode of VIEW_MODES, or to the
## next one where it names none. A command comes
## to a menu, to the status line and to its key from one place: adding one is adding
## an entry here, or to the "commands" of a plugin. Where two commands share a key, the first that applies has it;
## no two of one view and one window do without one of them being `only` on its rows (keyClashes, which the build asks).
## "says": the word the left window names the key of an "only" command by, where it starts nothing.
## "enters": Enter on a row it acts on enters that row, so the row is drawn as a folder is,
## as a row that dives into a level of its own is (rowEnters).
## "window": the window it applies in alone, else the one WINDOWS names it in, else every window.
## "with" and "exceptWith": the registries of other features that add their views, and their rows, to its own or take
## them from it (Plugins.py). The number keys that take the list to a level are goKeys' (Plugins.py).

## More rows than any pane holds: a move by that many stops at the top or at the bottom (Home, End).
MOVE_ALL = 1 << 30

ENGINE_COMMANDS = (
    {"name": "read", "keys": ("u", "F5"), "menu": ("view", 1), "label": "~R~ead now", "status": "Read",
     "does": ("read",)},
    {"name": "menu", "keys": ("m", "F10"), "status": "Menu", "does": ("menu",)},
    {"name": "exit", "keys": ("CTRL-x", "ALT-x"), "menu": ("go", 4), "label": "E~x~it", "status": "Exit",
     "does": ("quit",)},
    {"name": "open", "keys": ("ENTER",), "menu": ("go", 3), "label": "~O~pen", "status": "Open",
     "does": ("open",)},
    {"name": "up", "keys": ("BACKSPACE",), "menu": ("go", 3), "label": "~U~p one level", "status": "Up",
     "does": ("up",)},
    {"name": "focus", "keys": ("TAB", "F6"), "menu": ("view", 2), "label": "~N~ext window", "status": "Window",
     "does": ("focus",)},
    {"name": "help", "keys": ("?", "F1"), "menu": ("help", 1), "label": "~K~eys", "status": "Help",
     "does": ("action", "help")},
    {"name": "alphabetical", "keys": ("a",), "menu": ("view", 1), "label": "Alpha~b~etical or build order", "status": ("Alphabetical", "Build order"), "toggle": "alphabetical",
     "with": (("list", "alphabetical"),), "does": ("alphabetical",)},
    {"name": "filter", "keys": ("a",), "menu": ("view", 1), "label": "~A~ll or active", "status": ("Active", "All"), "toggle": "activeOnly",
     "exceptWith": (("list", "alphabetical"), ("list", "unfiltered")), "does": ("filter",)},
    ## the left window's own: its long lines wrapped at words, or cut and scrolled sideways
    ## ("shown": what the status line names its keys by, a pair of keys as one); and the
    ## split between the windows, a step at a time ("split", towards a wider right window
    ## or a narrower one). The wrap works whatever window has the keys, and the sideways
    ## scroll is the left window's, whose arrows are its own.
    {"name": "wrap", "keys": ("w",), "menu": ("view", 5), "label": "Wra~p~ or cut long lines", "status": ("Wrap", "Cut"), "toggle": "wrap",
     "does": ("wrap",)},
    {"name": "pan", "keys": ("LEFT", "RIGHT"), "status": "Scroll", "shown": "LEFT/RIGHT", "does": ("pan",)},
    ## in the left window, on a table that is all of it: Enter puts the row cursor on the top row in view, and then opens the row whole
    {"name": "row", "keys": ("ENTER",), "does": ("row",)},
    ## the table of the left window, where it is all of it: its rows sorted by the next column, and the source order after the last (a button of both
    ## windows), and the line that narrows them by what is typed (the left window's: it types into its line)
    {"name": "sort", "keys": ("t",), "menu": ("view", 6), "label": "S~o~rt by the next column", "status": "Sort", "does": ("tablesort",)},
    {"name": "rows-filter", "keys": ("/",), "menu": ("view", 6), "label": "Fi~l~ter the rows", "status": "Filter", "window": "view", "does": ("tablefilter",)},
    {"name": "split-wider", "keys": ("[",), "menu": ("view", 5), "label": "Wi~d~er list", "does": ("split", 1)},
    {"name": "split-narrower", "keys": ("]",), "menu": ("view", 5), "label": "Narrower lis~t~", "does": ("split", -1)},
    {"name": "style", "keys": ("I", "F9"), "menu": ("view", 3), "label": "Interface ~s~tyle: the next", "does": ("style",)},
    {"name": "colours", "keys": ("i",), "menu": ("view", 3), "label": "~I~nterface colours: the next", "does": ("colours",)},
    {"name": "line-up", "keys": ("UP",), "does": ("move", -1, 0)},
    {"name": "line-down", "keys": ("DOWN",), "does": ("move", 1, 0)},
    {"name": "page-up", "keys": ("PGUP",), "does": ("move", 0, -1)},
    {"name": "page-down", "keys": ("PGDN", " "), "does": ("move", 0, 1)},
    {"name": "go-top", "keys": ("HOME",), "does": ("move", -MOVE_ALL, 0)},
    {"name": "go-bottom", "keys": ("END",), "does": ("move", MOVE_ALL, 0)},
    ## the list's own Left and Right: Left pages up as PgUp does, and on the first row of the list it
    ## stays there -- it never climbs a level, which is Backspace's alone; Right pages down as PgDn does
    {"name": "page-left", "keys": ("LEFT",), "does": ("move", 0, -1)},
    {"name": "climb", "keys": (), "does": ("climb",)},
    {"name": "page-right", "keys": ("RIGHT",), "does": ("move", 0, 1)},
)

## What the status line shows in place of the commands while something else has the keys:
## a pull-down menu. Each a key, or two with / between, and its word. A dialog names its own
## keys, from CONTROL_KINDS. The status line names no key but those that act for what has
## the keys now.
STATUS_KEYS = {
    "menu": (("ENTER", "Choose"), ("ESC", "Close"), ("LEFT/RIGHT", "Menus"), ("UP/DOWN", "Items")),
}
## How the name of a key shows in a menu and in the status line, where it is not its own name.
KEY_WORDS = {"ENTER": "Enter", "TAB": "Tab", "ESC": "Esc", "LEFT": "Left", "RIGHT": "Right",
             "UP": "Up", "DOWN": "Down", "PGUP": "PgUp", "PGDN": "PgDn", "HOME": "Home", "END": "End", " ": "Space",
             "BACKSPACE": "Backspace"}
## The names a style gives keys in place of those of KEY_WORDS ("names" of its entry of STYLES).
## "classic": capitals, and the arrows of the IBM PC character set the frames come from;
## "symbols": a symbol each. Each name of either is one cell on every terminal (TEXT_SYMBOLS).
KEY_NAMES = {
    "classic": {"ENTER": "ENTER", "TAB": "TAB", "ESC": "ESC", "LEFT": "←", "RIGHT": "→",
                "UP": "UP", "DOWN": "DN", "BACKSPACE": "BSP"},
    "symbols": {"ENTER": "⏎", "TAB": "⇥", "ESC": "⎋", "LEFT": "←", "RIGHT": "→",
                "UP": "↑", "DOWN": "↓", "BACKSPACE": "⌫"},
}
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
    "absent": "%s: %s",
    "wrapped": "%s: the lines are wrapped, none is cut",
    "table": "%s: the left window holds no table",
    "listFilter": "%s: this level holds no rows to filter",
    "fullTable": "%s: this level has no full table",
}

## The commands of the engine stand in COMMANDS from here, before any plugin is registered.
pluginsApplied(pluginsBuilt())
