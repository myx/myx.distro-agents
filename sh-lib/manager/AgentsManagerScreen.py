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
    "AgentsManagerScreen.Dashboard.py",
    "AgentsManagerScreen.Sessions.py",
    "AgentsManagerScreen.Pending.py",
    "AgentsManagerScreen.MagicTeam.py",
    "AgentsManagerScreen.Members.py",
    "AgentsManagerScreen.TeamData.py",
    "AgentsManagerScreen.Places.py",
    "AgentsManagerScreen.Consoles.py",
    "AgentsManagerScreen.Settings.py",
    "AgentsManagerScreen.Talk.py",
    "AgentsManagerScreen.Scopes.py",
    "AgentsManagerScreen.Configuration.py",
    "AgentsManagerScreen.Wizards.py",
    "AgentsManagerScreen.Manuals.py",
    "AgentsManagerScreen.Dialogs.py",
    "AgentsManagerScreen.Actions.py",
    "AgentsManagerScreen.Output.py",
    "AgentsManagerScreen.Keys.py",
    "AgentsManagerScreen.Mouse.py",
    "AgentsManagerScreen.Menus.py",
    "AgentsManagerScreen.Reads.py",
    "AgentsManagerScreen.Draw.py",
    "AgentsManagerScreen.Terminal.py",
)

## The parts of the screen that belong to the sibling package `.local`, the common features of every console of the family (F11.4, F11.7):
## the folder is the package's own, `sh-lib/manager` of `myx.distro-.local` beside this package, and each part is loaded after the parts above, as
## they are, when it is there. A workspace whose `.local` has none of them has a screen without those features, and nothing else is changed.
LOCAL_PARTS_FOLDER = os.path.join("..", "..", "..", "myx.distro-.local", "sh-lib", "manager")
LOCAL_PARTS = (
    "LocalManagerScreen.Subsystems.py",
)


def loadParts():
    here = os.path.dirname(os.path.abspath(__file__))
    for part in PARTS:
        path = os.path.join(here, part)
        with open(path, encoding="utf-8") as handle:
            exec(compile(handle.read(), path, "exec"), globals())
    for part in LOCAL_PARTS:
        path = os.path.normpath(os.path.join(here, LOCAL_PARTS_FOLDER, part))
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as handle:
                exec(compile(handle.read(), path, "exec"), globals())


loadParts()
## every app feature has registered itself: the registries are whole, and the keys of the views are asked not to clash
pluginsReady()


## The screen until it is left, by its key or by anything that ends it: it leaves nothing of
## itself on the terminal either way (CursesSurface.wipe).
def runScreen(window, state, reader):
    surface = CursesSurface(window)
    key = None
    try:
        while True:
            screenTurn(surface, state, reader, time.monotonic(), key)
            if state.quit:
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
    reader = OperationReader(toolsCommandOf(options["--tools"]), options["--workspace"])
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
