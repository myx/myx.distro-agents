#!/usr/bin/env python3
##
## AgentsManagerScreen.py -- the manager screen of the agents console: what
## `DistroAgentsConsole.sh --manager` shows, started by `DistroAgentsTools.fn.sh
## --manager`. It looks as a Turbo Vision program does: a menu bar, a desktop with
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
## operations too. The one thing it starts itself is what `Consoles` lists: a
## console, as a child that is given the whole terminal, from the words an operation
## printed for it, and the screen takes the terminal back when that child ends.
##
## The logic is plain functions over one state (ManagerState): the layout, the
## levels of the list, the selection, the focus, the filter, what a key does and
## which read is due. The drawing goes through a surface: the terminal here
## (CursesSurface), and in a test a stand-in that keeps the cells it was given
## (sh-test/check-fixtures/manager-screen.driver.py).
##

import datetime
import locale
import os
import re
import select
import shlex
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import codecs
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

## The apps the manager screen starts as (F12.2 of the refactorings epic): the agents console
## and the four sibling consoles. The app is read from `--app <name>` of the start, before the
## parts load, since which plugins are kept is decided there. `agents` (the default) keeps every
## plugin; a sibling keeps only the plugins of its day-one scope: the Dashboard and the Manuals.
APP_NAMES = ("agents", "local", "source", "deploy", "remote")


def appOf(arguments):
    for at, word in enumerate(arguments):
        if word == "--app" and at + 1 < len(arguments) and arguments[at + 1] in APP_NAMES:
            return arguments[at + 1]
    return "agents"


SCREEN_APP = appOf(sys.argv[1:])
## The plugins an app keeps, set before the parts load and read by the plugin mechanism (Plugins.py):
## None keeps every plugin. A sibling keeps its two day-one roots, the Dashboard and the Manuals,
## and the plugins that hold no root of their own but offer what those two and the engine's
## commands integrate into: `list` (alphabetical/unfiltered), `markdown` (on/help) and `glance`
## (the list filter). The agents app keeps every one.
APP_PLUGINS = None if SCREEN_APP == "agents" else frozenset(("list", "markdown", "glance", "dashboard", "manuals"))

## The parts of the screen, in the order they are loaded: each is executed here, in the namespace of this file, so the
## screen stays one module whatever its files are -- a declaration names a function by its name (globals()[name]), and a
## test replaces a function of the screen by assigning it to the module. The declarations come first, with the plugin
## mechanism (Plugins), then the engine and the kinds of view, then the app features, the roots of the list, each of which
## registers itself as a plugin, then what every one of them uses.
PARTS = (
    "AgentsManagerScreen.Looks.py",
    "AgentsManagerScreen.Plugins.py",
    "AgentsManagerScreen.Roots.py",
    "AgentsManagerScreen.Styles.py",
    "AgentsManagerScreen.Windows.py",
    "AgentsManagerScreen.State.py",
    "AgentsManagerScreen.Cells.py",
    "AgentsManagerScreen.Layout.py",
    "AgentsManagerScreen.List.py",
    "AgentsManagerScreen.Pane.py",
    "AgentsManagerScreen.ViewTable.py",
    "AgentsManagerScreen.ViewFeed.py",
    "AgentsManagerScreen.ViewMarkdown.py",
    "AgentsManagerScreen.ViewKinds.py",
    "AgentsManagerScreen.Pending.py",
    "AgentsManagerScreen.Sessions.py",
    "AgentsManagerScreen.Launch.py",
    "AgentsManagerScreen.MagicTeam.py",
    "AgentsManagerScreen.Members.py",
    "AgentsManagerScreen.TeamData.py",
    "AgentsManagerScreen.Routines.py",
    "AgentsManagerScreen.Schedule.py",
    "AgentsManagerScreen.Tokens.py",
    "AgentsManagerScreen.Consoles.py",
    "AgentsManagerScreen.Settings.py",
    "AgentsManagerScreen.Talk.py",
    "AgentsManagerScreen.Configuration.py",
    "AgentsManagerScreen.CliPresets.py",
    "AgentsManagerScreen.Wizards.py",
    "AgentsManagerScreen.Manuals.py",
    "AgentsManagerScreen.Dialogs.py",
    "AgentsManagerScreen.Actions.py",
    "AgentsManagerScreen.Output.py",
    "AgentsManagerScreen.Keys.py",
    "AgentsManagerScreen.Mouse.py",
    "AgentsManagerScreen.Menus.py",
    "AgentsManagerScreen.Reads.py",
    "AgentsManagerScreen.Glance.py",
    "AgentsManagerScreen.Draw.py",
    "AgentsManagerScreen.Terminal.py",
)

## The parts of the screen that belong to the sibling package `.local`, the common features of every console of the family (F11.4, F11.7):
## the folder is the package's own, `sh-lib/manager` of `myx.distro-.local` beside this package, and each part is loaded after the parts above, as
## they are, when it is there. A workspace whose `.local` has none of them has a screen without those features, and nothing else is changed.
LOCAL_PARTS_FOLDER = os.path.join("..", "..", "..", "myx.distro-.local", "sh-lib", "manager")
LOCAL_PARTS = (
    "LocalManagerScreen.Subsystems.py",
    "LocalManagerScreen.Scopes.py",
    "LocalManagerScreen.Features.py",
)
## A part of `.local` that stands in the order of the list of roots, since the roots stand in the order they were registered in (Plugins): it is loaded
## ahead of the part of the screen it is named under, the Dashboard ahead of the pending questions, `Locations (Places)` (F11.10) ahead of the tokens, where it stood, and `Workspace (System)` (F11.10) at the end of the places, after the consoles, ahead of the settings.
LOCAL_PARTS_BEFORE = {
    "AgentsManagerScreen.Pending.py": ("LocalManagerScreen.Dashboard.py",),
    "AgentsManagerScreen.Tokens.py": ("LocalManagerScreen.Places.py",),
    "AgentsManagerScreen.Settings.py": ("LocalManagerScreen.Workspace.py", "LocalManagerScreen.Machine.py"),
}


def loadLocalPart(here, part):
    path = os.path.normpath(os.path.join(here, LOCAL_PARTS_FOLDER, part))
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as handle:
            exec(compile(handle.read(), path, "exec"), globals())


def loadParts():
    here = os.path.dirname(os.path.abspath(__file__))
    for part in PARTS:
        for local in LOCAL_PARTS_BEFORE.get(part, ()):
            loadLocalPart(here, local)
        path = os.path.join(here, part)
        with open(path, encoding="utf-8") as handle:
            exec(compile(handle.read(), path, "exec"), globals())
    for part in LOCAL_PARTS:
        loadLocalPart(here, part)
    ## the folder of what the tooling sees stands after every other folder of the Configuration
    registerDiagnostics()


loadParts()
## every app feature has registered itself: the registries are whole, and the keys of the views are asked not to clash
pluginsReady()


## The screen until it is left, by its key or by anything that ends it: it leaves nothing of
## itself on the terminal either way (CursesSurface.wipe). In single-dialog mode (D5) one
## dialog is opened first, and the screen ends when it is closed.
def runScreen(window, state, reader):
    surface = CursesSurface(window)
    key = None
    try:
        if state.singleDialog is not None:
            fill = None
            if state.singleText:
                fill = {"text": {"lines": [state.singleText]}, "about": {"lines": [state.singleText]}}
            openDialog(state, state.singleDialog, fill)
        while True:
            screenTurn(surface, state, reader, time.monotonic(), key)
            if state.quit:
                return
            if state.singleDialog is not None and state.dialog is None:
                return
            key = surface.key(keyWait(state, time.monotonic()))
    finally:
        surface.wipe()


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


## D5: what a start names beside --workspace/--tools/--style, applied to the fresh state before
## the screen runs: --component <path> takes the list to that level (its ids, `/` between them);
## --view <list|view> gives one window the keys; --filter <text> narrows the table of the left
## window and gives it the keys; --dialog <name> shows that one dialog and ends the screen when
## it is closed (single-dialog mode), --text <text> the words it holds. Gives False where a name
## is not one the screen has.
def applyStartOptions(state, options):
    if options["--component"]:
        state.path = [step for step in options["--component"].split("/") if step]
        state.focus = "list"
    if options["--view"]:
        if options["--view"] not in ("list", "view"):
            sys.stderr.write("%s --view takes list or view, got: %s\n" % (PREFIX, options["--view"]))
            return False
        state.focus = options["--view"]
    if options["--filter"]:
        state.startFilter = options["--filter"]
        state.focus = "view"
    if options["--dialog"]:
        if options["--dialog"] not in DIALOGS:
            sys.stderr.write("%s --dialog takes one of: %s, got: %s\n" % (PREFIX, " ".join(sorted(DIALOGS)), options["--dialog"]))
            return False
        state.singleDialog = options["--dialog"]
        state.singleText = options["--text"]
    return True


def main(arguments):
    options = {"--workspace": "", "--tools": "", "--style": "", "--app": "",
               "--component": "", "--filter": "", "--view": "", "--dialog": "", "--text": ""}
    position = 0
    while position < len(arguments):
        if arguments[position] not in options or position + 1 >= len(arguments):
            sys.stderr.write("%s expects: --workspace <path> --tools <dispatcher> [--style <name>] [--app <name>] [--component <path>] [--view <list|view>] [--filter <text>] [--dialog <name>] [--text <text>], got: %s\n" % (PREFIX, " ".join(arguments)))
            return 1
        options[arguments[position]] = arguments[position + 1]
        position += 2
    if not options["--tools"]:
        sys.stderr.write("%s expects: --workspace <path> --tools <dispatcher>\n" % PREFIX)
        return 1
    if options["--app"] and options["--app"] not in APP_NAMES:
        sys.stderr.write("%s --app takes one of: %s, got: %s\n" % (PREFIX, " ".join(APP_NAMES), options["--app"]))
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
    reader = OperationReader(toolsCommandOf(options["--tools"]), options["--workspace"])
    signal.signal(signal.SIGTERM, endOnSignal)
    signal.signal(signal.SIGHUP, endOnSignal)
    ## D5: --component/--view/--filter/--dialog of the start, on the fresh state; a name that is
    ## not one the screen has is refused here, before anything is started.
    if not applyStartOptions(state, options):
        return 1
    refusal = screenRefusal()
    if refusal is not None:
        sys.stderr.write("%s %s\n" % (PREFIX, refusal))
        return 1
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
