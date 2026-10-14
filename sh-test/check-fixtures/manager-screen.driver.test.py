#!/usr/bin/env python3
##
## manager-screen.driver.test.py -- the driver of the manager screen's tests. It loads
## sh-lib/AgentsManagerScreen.py as a module and stands in for the terminal, so a test
## reads the screen back as text and needs no real terminal. Run with `python3 -I -B`.
##
##   <driver> <screen file> script
##       Commands on standard input, one a line; what they print is `<tag>.<name>=<value>`
##       and, for a screen, `<tag>|<the line as drawn>|`. The stand-in surface (TextSurface)
##       keeps the cells that were drawn and hands out the keys a command names; time is a
##       number the commands move. The commands are listed at scriptRun below.
##   <driver> <screen file> pty <columns> <lines> <wait-for> <keys> <seconds> -- <command...>
##       The one place a real terminal is used, a pseudo-terminal: runs the command on it,
##       writes the keys once <wait-for> was drawn, and prints how it ended and whether the
##       terminal was given back (`pty.<name>=<value>`).
##   <driver> <screen file> child-raise <arguments of the screen...>
##       The real screen with a stand-in for its data that raises an error: what a list
##       operation printed fails to become rows. For the pty mode to run.
##

import datetime
import fcntl
import importlib.util
import os
import pty
import re
import select
import shutil
import struct
import subprocess
import sys
import termios
import time
import unicodedata

sys.dont_write_bytecode = True


def loadScreen(screenFile):
    spec = importlib.util.spec_from_file_location("AgentsManagerScreen", screenFile)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


## The stand-in for the terminal. It measures a text by itself, not by the screen's own
## count, and a text put past the end of a line or of the screen is counted as a spill.
## A change of size keeps the cells that were there, as a terminal does until it is drawn again.
class TextSurface:
    def __init__(self, columns, lines):
        self.columns = 0
        self.lines = 0
        self.cells = []
        self.looks = []
        self.spills = 0
        self.frames = 0
        self.repaints = 0
        self.puts = 0
        self.cursorAt = None
        ## the children that were given the terminal, each as its words and its folder; how
        ## the next one ends, and the size the terminal has when it does
        self.children = []
        self.childEnd = 0
        self.childSize = None
        self.resize(columns, lines)

    def resize(self, columns, lines):
        cells = [[" "] * columns for line in range(lines)]
        looks = [[0] * columns for line in range(lines)]
        for line in range(min(lines, self.lines)):
            for column in range(min(columns, self.columns)):
                cells[line][column] = self.cells[line][column]
                looks[line][column] = self.looks[line][column]
        self.columns, self.lines, self.cells, self.looks = columns, lines, cells, looks

    def size(self):
        return self.columns, self.lines

    def clear(self):
        self.puts = 0
        for line in range(self.lines):
            for column in range(self.columns):
                self.cells[line][column] = " "
                self.looks[line][column] = 0

    def put(self, line, column, text, look):
        self.puts += 1
        if line < 0 or line >= self.lines or column < 0:
            self.spills += 1
            return
        for character in text:
            codePoint = ord(character)
            joins = codePoint == 0x200D or 0xFE00 <= codePoint <= 0xFE0F or unicodedata.combining(character) != 0
            if joins:
                if column > 0:
                    back = column - 1
                    while back > 0 and self.cells[line][back] == "":
                        back -= 1
                    self.cells[line][back] += character
                continue
            width = 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
            if column + width > self.columns:
                self.spills += 1
                return
            self.cells[line][column] = character
            self.looks[line][column] = look
            if width == 2:
                self.cells[line][column + 1] = ""
                self.looks[line][column + 1] = look
            column += width

    def cursor(self, line, column):
        self.cursorAt = None if line is None else (line, column)

    def show(self):
        self.frames += 1

    ## The next frame sent whole: counted, as `repaints`.
    def repaint(self):
        self.repaints += 1

    ## A child that is given the terminal. None is started here: what it would be started
    ## with is kept, and it ends as the script said the next one does (`child`).
    def child(self, words, directory):
        self.children.append((list(words), directory))
        if self.childSize is not None:
            self.resize(*self.childSize)
        if self.childEnd == "missing":
            raise FileNotFoundError(2, "No such file or directory", words[0])
        return self.childEnd

    def textLines(self):
        return ["".join(lineCells) for lineCells in self.cells]

    ## How each cell is drawn, a letter a cell: `letters` gives the letter of a look.
    def lookLines(self, letters):
        return ["".join(letters(look) for look in lineLooks) for lineLooks in self.looks]


## script: one command a line, `#` starts a comment.
##   size <columns> <lines>        the size of the terminal; once a screen was drawn, the change comes as a key
##   workspace <path>   now <seconds>   advance <seconds>
##   wall <yyyy-mm-dd hh:mm +zzzz>  the time the screen takes as now: what an age is counted from, and its clock
##   clock <hh:mm:ss>              the same, as that time of today where the test runs
##   tools <command...>            the dispatcher the screen calls (a stand-in script)
##   copy <from> <to>              copies a file, <to> being the rest of the line: what the stand-in prints from then on
##   table <read key> none | <words...> [+active <words...>]   one entry of what the screen asks for
##   root <id>                     the list is at its root, its selection on the row of that root, named by its id in
##                                 the screen's SECTIONS: what a script counts from there does not move when the root
##                                 list gets another row. No turn: the next key or turn draws it
##   keys <key...>                 each key is one turn of the screen
##   turn [<count>]                turns with no key
##   wait <kind> <seconds>         turns, in real time, until no call of that kind runs; the selection is taken as
##                                 rested first, so the reads of the selected item are started
##   child <status>|missing [<columns> <lines>]   how the next child that is given the terminal ends: with that
##                                 status as the system gives it, below 0 the signal that ended it, or it cannot be
##                                 started; and the size the terminal has when it has ended. No child is started.
##   rows <level> <id>=<label>...  the rows of a level, as if its operation had printed them; `+` ahead of an id
##                                 makes its row one that Enter dives into
##   rowsgen <level> <count>       the same, <count> generated rows r001.. labelled `row 001`..
##   view <count>                  <count> lines in the left pane;  viewline <text>  one more line
##   rigdialog [<text>]            opens a dialog of the rig's own, declared here with a control of every kind: a text,
##                                 the field `name`, the field of several lines `notes`, the boxes `who`, the radio
##                                 buttons `how`, the list `pick`, and the buttons OK and Cancel. OK says what each
##                                 control holds, as `pressed ok: ...`, and refuses the name `no` inside the dialog
##   tell <title> | <paragraph> [/ <paragraph>...]   opens the message box with that title and that text
##   opened <name> | <paragraph> [/ <paragraph>...]  opens that dialog of the screen's DIALOGS with that text in its
##                                 control `about`, as the screen's own handlers open one; a paragraph `<name> :: <value>`
##                                 is a pair of a name and its value
##   mouse <what> <column> <line>  one event of the mouse at that cell, counted from 0, as one turn of the screen:
##                                 click, double, up or down (the wheel), or press (the first button going down)
##   mousekey <column> <line> <bit...>   what the screen makes of what curses reports of the mouse, the bits by their
##                                 names in curses, as `mousekey=<key>`, empty where it makes nothing of it
##   box <tag> [roles|looks]       the open dialog as drawn, line by line, with the two cells at its right and the line
##                                 under it, where its shadow falls: as text, or as show, roles and looks give a screen
##   handler <action>              gives that action a handler that says `handled <action> on <row id>`, on every row
##   show <tag>   looks <tag>   fresh <tag>   the screen as text; how each cell is drawn on a terminal with no colours
##                                 (. plain, B bold, R reverse, D dim, H reverse and bold, d reverse and dim); the same
##                                 state drawn on a new terminal
##   roles <tag>                   which part of the drawing each cell is, by the letter LOOKS of the screen gives it
##   cells <tag> <line> <from> <to>   those cells of one line, counted from 0, as `<tag>=<text>` without the spaces at its end
##   border <tag> <line> <from> <to>  the same of a border of a window, without the lines and the corners of the frame
##                                 at its ends: its title, or what stands in its bottom border
##   said <tag>                    what the status line says after its keys, as it is drawn, as `<tag>=<text>`
##   get <tag>                     the state, one `<tag>.<name>=<value>` a line
##   plain                         from here on the screen draws as for a terminal that is not UTF-8
##   style <name>                  from here on the screen draws in that style of its STYLES
##   mode <name>                   the left window is in that mode of its VIEW_MODES, as if its key had been pressed
##                                 earlier in the run of the screen
##   plaintext <tag> <text>        that text as such a terminal is given it, as `<tag>=<text>`
def scriptRun(module):
    state = module.ManagerState("")
    surface = TextSurface(80, 24)
    reader = [None]
    clock = [0.0]
    drawn = [False]

    def turn(key=None):
        first = not drawn[0]
        module.screenTurn(surface, state, reader[0], clock[0], key)
        drawn[0] = True
        if first and reader[0] is not None:
            ## every start of the screen reads the list of the locations, whatever is shown: the
            ## first turn waits here, in real time and with no turn more, until that one call
            ## has ended, so what a script sees does not depend on how fast it ended. It is taken
            ## into the state at the next turn, as ever; since it has ended, the state no longer
            ## names it among the reads that run, which it would say only one turn later.
            call = reader[0].running.get("places")
            deadline = time.time() + 30
            while call is not None and call["process"].poll() is None and time.time() < deadline:
                time.sleep(0.02)
            if call is not None and call["process"].poll() is not None:
                state.reading = dict((kind, key) for kind, key in state.reading.items() if kind != "places")

    def setRows(level, rows):
        state.rows[level] = rows

    ## What has the keys besides the windows and the menu: the open dialog as `<its name>:<the
    ## control or the button the keys are on>|<what that control holds>`, a new line as `\n`,
    ## the checked boxes with commas between them.
    def dialogValue():
        if state.dialog is None:
            return ""
        what, index, control = module.dialogFocus(state.dialog)
        if control is None:
            return "%s:%s|" % (state.dialog["name"], state.dialog["buttons"][index][0])
        value = control["value"]
        return "%s:%s|%s" % (state.dialog["name"], control["name"], ",".join(value) if isinstance(value, list) else value.replace("\n", "\\n"))

    def rigDialog(text):
        module.DIALOGS["rig"] = {"title": "A dialog of the rig", "controls": (
            {"name": "about", "kind": "text"},
            {"name": "name", "kind": "input", "label": "Name"},
            {"name": "notes", "kind": "area", "label": "Notes"},
            {"name": "who", "kind": "checks", "label": "Who"},
            {"name": "how", "kind": "radios", "label": "How"},
            {"name": "pick", "kind": "list", "label": "Pick"},
        ), "buttons": (("ok", "OK"), ("cancel", "Cancel"))}

        def pressed(dialogState, dialog, button):
            if module.dialogValue(dialog, "name") == "no":
                return "the rig refuses the name no"
            dialogState.notice = "pressed %s: name=%s notes=%s who=%s how=%s pick=%s" % (
                button, module.dialogValue(dialog, "name"), module.dialogValue(dialog, "notes").replace("\n", "\\n"),
                ",".join(module.dialogValue(dialog, "who")), module.dialogValue(dialog, "how"), module.dialogValue(dialog, "pick"))
            return None
        module.DIALOG_HANDLERS["rig"] = pressed
        module.openDialog(state, "rig", {
            "about": {"lines": [text or "What the rig asks."]},
            "name": {"value": "typed"},
            "who": {"options": [("a", "alpha"), ("b", "beta"), ("c", "gamma")], "value": ["b"]},
            "how": {"options": [("x", "one way"), ("y", "another")], "value": "y"},
            "pick": {"options": [("p1", "first"), ("p2", "second"), ("p3", "third")]},
        })

    def get(tag):
        columns, lines = surface.size()
        layout = module.layoutOf(columns, lines, state.split)
        rows = module.levelRows(state)
        cursor = module.cursorOf(state, rows, layout["listHeight"] if layout else 0)
        selected = rows[cursor["index"]] if rows else None
        values = [
            ("columns", columns), ("lines", lines),
            ("layout", "none" if layout is None else "ok"),
            ("path", "/".join(state.path)),
            ("rows", len(rows)),
            ("selected", selected["id"] if selected else ""),
            ("selectedLabel", selected["label"] if selected else ""),
            ("index", cursor["index"]), ("top", cursor["top"]),
            ("focus", state.focus),
            ("filter", "active" if state.activeOnly else "all"),
            ("viewTop", state.view["top"]), ("viewLines", len(state.view["lines"])),
            ("viewHead", len(state.view["head"])), ("follow", "yes" if state.view["follow"] else "no"),
            ("rawLog", "yes" if module.rawShown(state) else "no"), ("viewMode", state.viewMode),
            ("wrap", "yes" if state.wrap else "no"), ("viewLeft", state.view.get("left", 0)),
            ("split", "" if state.split is None else "%.4f" % state.split), ("splitHeld", state.splitHeld or ""),
            ("notice", state.notice),
            ("dialog", dialogValue()),
            ("dialogTitle", state.dialog["title"] if state.dialog else ""),
            ("dialogHolds", " / ".join(
                "%s: %s" % paragraph if isinstance(paragraph, tuple) else paragraph
                for control in (state.dialog["controls"] if state.dialog else ()) for paragraph in control["lines"])),
            ("dialogSays", state.dialog["says"] if state.dialog else ""),
            ("dialogBox", ",".join(str(value) for value in state.dialog["plan"]["box"]) if state.dialog and state.dialog["plan"] else ""),
            ("waiting", len(state.waiting)),
            ("menu", "" if getattr(state, "menu", None) is None else "%s:%s" % (
                module.MENUS[state.menu["menu"]][0], module.menuItems(state, module.MENUS[state.menu["menu"]][0])[state.menu["item"]]["name"])),
            ("quit", "yes" if state.quit else "no"),
            ("style", module.STYLE["name"] if hasattr(module, "STYLE") else ""),
            ("reading", ",".join(sorted(state.reading.values()))),
            ("calls", len(getattr(state, "calls", ()))),
            ("answer", len(state.answer["lines"]) if getattr(state, "answer", None) else 0),
            ("restLeft", "%.2f" % module.restLeft(state, clock[0]) if hasattr(module, "restLeft") else ""),
            ("keyWait", "%.3f" % module.keyWait(state, clock[0]) if hasattr(module, "keyWait") else ""),
            ("counters", ",".join("%s=%s" % pair for pair in sorted(state.counters.items()))),
            ("failed", ",".join(sorted(state.failed))),
            ("forced", ",".join(sorted(state.forced))),
            ("spills", surface.spills), ("frames", surface.frames), ("repaints", surface.repaints), ("puts", surface.puts),
            ("cursor", "" if surface.cursorAt is None else "%d,%d" % surface.cursorAt),
            ("children", len(surface.children)),
            ("childWords", "".join("[%s]" % word for word in surface.children[-1][0]) if surface.children else ""),
            ("childDirectory", surface.children[-1][1] if surface.children else ""),
        ]
        if layout is not None:
            for name in ("viewWidth", "separator", "listLeft", "listWidth", "viewHeight", "listHeight", "inputLine", "bottomLine"):
                values.append((name, layout[name]))
        for name, value in values:
            print("%s.%s=%s" % (tag, name, value))

    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        command, _, rest = line.strip().partition(" ")
        words = rest.split()
        if command == "size":
            surface.resize(int(words[0]), int(words[1]))
            if drawn[0]:
                turn("RESIZE")
        elif command == "workspace":
            state.workspace = rest
        elif command == "clock":
            module.nowEpoch = (lambda fixed: lambda: fixed)(time.mktime(time.strptime(time.strftime("%Y-%m-%d ") + rest, "%Y-%m-%d %H:%M:%S")))
        elif command == "now":
            clock[0] = float(words[0])
        elif command == "advance":
            clock[0] += float(words[0])
        elif command == "wall":
            module.nowEpoch = (lambda fixed: lambda: fixed)(datetime.datetime.strptime(rest, "%Y-%m-%d %H:%M %z").timestamp())
        elif command == "copy":
            shutil.copyfile(words[0], rest.partition(" ")[2])
        elif command == "tools":
            reader[0] = module.OperationReader(words)
        elif command == "table":
            if words[1:] == ["none"]:
                module.READS[words[0]] = None
            else:
                operation = words[1:]
                entry = {}
                if "+active" in operation:
                    entry["active"] = operation[operation.index("+active") + 1:]
                    operation = operation[:operation.index("+active")]
                entry["operation"] = operation
                module.READS[words[0]] = entry
        elif command == "root":
            known = [sectionId for sectionId, sectionLabel in module.SECTIONS]
            if rest not in known:
                sys.stderr.write("manager-screen.driver.test.py: no root of that id: %s (the roots: %s)\n" % (rest, " ".join(known)))
                if reader[0] is not None:
                    reader[0].stop()
                return 2
            state.path = []
            state.cursors[""] = {"key": "section:" + rest, "index": known.index(rest), "top": 0}
        elif command == "keys":
            for key in words:
                turn(" " if key == "SPACE" else key)
        elif command == "turn":
            for count in range(int(words[0]) if words else 1):
                turn()
        elif command == "wait":
            ## a test that waits for a read has let the selection rest: the reads of its item start
            if hasattr(module, "restLeft"):
                module.restLeft(state, clock[0])
                state.restSince = clock[0] - 2 * module.REST_SECONDS
            deadline = time.time() + float(words[1])
            turn()
            while reader[0] is not None and reader[0].busy(words[0]) and time.time() < deadline:
                time.sleep(0.05)
                turn()
            turn()
        elif command == "child":
            surface.childEnd = "missing" if words[0] == "missing" else int(words[0])
            surface.childSize = (int(words[1]), int(words[2])) if len(words) > 2 else None
        elif command == "rows":
            setRows(words[0], [module.newRow(word.partition("=")[0].lstrip("+"), word.partition("=")[2], "record", word.startswith("+")) for word in words[1:]])
        elif command == "rowsgen":
            setRows(words[0], [module.newRow("r%03d" % number, "row %03d" % number, "record") for number in range(1, int(words[1]) + 1)])
        elif command == "view":
            module.followSelection(state)
            state.view["lines"] = ["line %03d" % number for number in range(1, int(words[0]) + 1)]
        elif command == "viewline":
            module.followSelection(state)
            state.view["lines"].append(rest)
        elif command == "mouse":
            turn("MOUSE:%s:%s:%s" % (words[0], words[1], words[2]))
        elif command == "mousekey":
            bits = 0
            for name in words[2:]:
                bits |= getattr(module.curses, name, module.WHEEL_DOWN if name == "BUTTON5_PRESSED" else 0)
            print("mousekey=%s" % (module.mouseKey(int(words[0]), int(words[1]), bits) or ""))
        elif command == "rigdialog":
            rigDialog(rest)
        elif command == "opened":
            paragraphs = [paragraph.strip() for paragraph in rest.partition("|")[2].split(" / ")]
            module.openDialog(state, rest.partition("|")[0].strip(), {"about": {"lines": [
                tuple(paragraph.split(" :: ", 1)) if " :: " in paragraph else paragraph for paragraph in paragraphs]}})
        elif command == "tell":
            module.tell(state, rest.partition("|")[0].strip(), [paragraph.strip() for paragraph in rest.partition("|")[2].split(" / ")])
        elif command == "box":
            left, top, width, height = state.dialog["plan"]["box"]
            letters = {"roles": lambda look: module.LOOKS[look][0], "looks": lambda look: module.MONO_LETTERS[module.LOOKS[look][1]]}
            grid = surface.lookLines(letters[words[1]]) if words[1:] else surface.cells
            for gridLine in grid[top:top + height + 1]:
                print("%s|%s|" % (words[0], "".join(gridLine[left:left + width + 2])))
        elif command == "handler":
            module.ACTION_HANDLERS[words[0]] = (lambda action: lambda handlerState, row: "handled %s on %s" % (action, row["id"] if row else "nothing"))(words[0])
            getattr(module, "ACTION_FITS", {}).pop(words[0], None)
        elif command == "show":
            for textLine in surface.textLines():
                print("%s|%s|" % (rest, textLine))
        elif command == "looks":
            for lookLine in surface.lookLines(lambda look: module.MONO_LETTERS[module.LOOKS[look][1]]):
                print("%s|%s|" % (rest, lookLine))
        elif command == "roles":
            for lookLine in surface.lookLines(lambda look: module.LOOKS[look][0]):
                print("%s|%s|" % (rest, lookLine))
        elif command == "border":
            frameMarks = module.MARKS["frame"] + module.MARKS["frameOn"] + " "
            print("%s=%s" % (words[0], "".join(surface.cells[int(words[1])][int(words[2]):int(words[3])]).strip(frameMarks)))
        elif command == "said":
            statusLine = "".join(surface.cells[surface.lines - 1])
            print("%s=%s" % (words[0], statusLine.partition(module.MARKS["separator"])[2].strip(" ")))
        elif command == "fresh":
            other = TextSurface(surface.columns, surface.lines)
            module.drawScreen(other, state)
            for textLine in other.textLines():
                print("%s|%s|" % (rest, textLine))
        elif command == "plain":
            module.plainMarks()
        elif command == "style":
            if not module.setStyle(rest):
                print("style.refused=%s" % rest)
        elif command == "mode":
            state.viewMode = rest
        elif command == "plaintext":
            print("%s=%s" % (words[0], module.plainText(rest.partition(" ")[2])))
        elif command == "cells":
            lineCells = surface.cells[int(words[1])][int(words[2]):int(words[3])]
            print("%s=%s" % (words[0], "".join(lineCells).rstrip(" ")))
        elif command == "get":
            get(rest)
        else:
            sys.stderr.write("manager-screen.driver.test.py: unknown command: %s\n" % line)
            if reader[0] is not None:
                reader[0].stop()
            return 2
    if reader[0] is not None:
        reader[0].stop()
    return 0


## pty: the command on a pseudo-terminal of that size, a terminal with colours, or the one the
## environment names in MANAGER_SCREEN_PTY_TERM (colours says whether one was set). Once <wait-for> has been drawn the
## keys are written (`-`: none; \r \e \t are read as those keys, \x and two hex digits as that
## byte, and \p is a pause of 0.4 seconds between two keys, as a hand types them; what stands between two
## pauses and begins with \a<text>\a is written only once <text> stands in what was written to the terminal since
## the keys before it, its escape sequences aside; and \z<columns>x<lines> at that place makes the terminal that
## size, as a window that is resized, with no signal). Where the environment names texts in MANAGER_SCREEN_PTY_TRACE,
## <name>=<text> with | between them, the same marks read in a text, the names are printed in the order their
## texts stand in what was written to the terminal, each as often as it stands there (trace). Printed: how it ended
## (rc), whether <wait-for> was drawn (frame), whether a colour of the eight was set (colours) and a shade of a
## palette of 256 (shades), whether the terminal's mode was changed
## while it ran (modeTaken) and is afterwards what it was before (modeBack), whether the
## other screen of the terminal was entered and left again (entered, left), and where it
## last wrote ERROR once the screen was up: after it had left (errorAfterLeft), and that
## line (error). Where no screen came up, error is the last line that says ERROR.
## Where the environment says MANAGER_SCREEN_PTY_SESSION=1 the pseudo-terminal is the controlling terminal of the
## command, which leads a session of its own: Ctrl-C, Ctrl-\ and Ctrl-Z written there are then signals, as at a real terminal.
## The terminal of such a session is taken away when its leader ends, so its mode afterwards cannot be read: modeBack is `unknown`.
def ptyRun(arguments):
    columns, lines, waitFor, keys, seconds = int(arguments[0]), int(arguments[1]), arguments[2], arguments[3], float(arguments[4])
    command = arguments[6:]
    def marksRead(text):
        return re.sub(r"\\x([0-9a-fA-F]{2})", lambda found: chr(int(found.group(1), 16)),
                      text.replace("\\r", "\r").replace("\\e", "\x1b").replace("\\t", "\t"))

    ## what is written at each turn: the text it waits for, or None; the size it makes the terminal, or None; the keys
    chunks = []
    for part in ([] if keys == "-" else keys.split("\\p")):
        awaited = re.match(r"\\a(.*?)\\a", part, re.S)
        part = part[awaited.end():] if awaited else part
        sized = re.match(r"\\z([0-9]+)x([0-9]+)", part)
        part = part[sized.end():] if sized else part
        chunks.append((awaited.group(1) if awaited else None, (int(sized.group(1)), int(sized.group(2))) if sized else None,
                       marksRead(part).encode("utf-8")))
    nextAt = None
    writtenAt = 0
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", lines, columns, 0, 0))
    before = termios.tcgetattr(slave)
    environment = dict(os.environ)
    ## the terminal the command is told it has: one with colours, or the one a test names
    environment["TERM"] = os.environ.get("MANAGER_SCREEN_PTY_TERM", "xterm")
    environment.pop("LINES", None)
    environment.pop("COLUMNS", None)
    ## the command as a program started from a terminal is: the leader of a session of its own, the pseudo-terminal
    ## its controlling terminal, so what is typed there as an interrupt, a quit or a stop is a signal to its foreground group
    def ownTerminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=environment,
                               preexec_fn=ownTerminal if os.environ.get("MANAGER_SCREEN_PTY_SESSION") == "1" else None)
    output = b""
    during = None
    deadline = time.time() + seconds
    while time.time() < deadline:
        readable = select.select([master], [], [], 0.1)[0]
        if readable:
            try:
                output += os.read(master, 65536)
            except OSError:
                pass
        if during is None and waitFor.encode("utf-8") in output:
            during = termios.tcgetattr(slave)
            nextAt = time.time()
        if nextAt is not None and chunks and time.time() >= nextAt:
            awaited, sized, typed = chunks[0]
            since = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>]", "", output[writtenAt:].decode("utf-8", "replace"))
            if awaited is None or awaited in since:
                chunks.pop(0)
                if sized is not None:
                    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", sized[1], sized[0], 0, 0))
                if typed:
                    os.write(master, typed)
                writtenAt = len(output)
                nextAt = time.time() + 0.4
        if process.poll() is not None:
            break
    status = process.poll()
    if status is None:
        process.kill()
        process.wait()
        status = "timeout"
    while select.select([master], [], [], 0.2)[0]:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
    try:
        after = termios.tcgetattr(slave)
    except termios.error:
        ## the terminal of a session whose leader has ended is taken away: its mode can no longer be read
        after = None
    entered = max(output.find(b"\x1b[?1049h"), output.find(b"\x1b[?47h"))
    left = max(output.rfind(b"\x1b[?1049l"), output.rfind(b"\x1b[?47l"))
    ## what was written before the screen came up is not the screen's
    errorAt = output.rfind(b"ERROR")
    if entered != -1 and errorAt < entered:
        errorAt = -1
    errorLine = ""
    if errorAt != -1:
        lineStart = output.rfind(b"\n", 0, errorAt) + 1
        lineStart = max(lineStart, output.rfind("⛔".encode("utf-8"), lineStart, errorAt), output.rfind(b"\x1b", lineStart, errorAt) + 2)
        lineEnd = output.find(b"\r", errorAt)
        errorLine = output[lineStart:lineEnd if lineEnd != -1 else len(output)].decode("utf-8", "replace")
    print("pty.rc=%s" % status)
    print("pty.frame=%s" % ("yes" if during is not None else "no"))
    ## whether a colour was set on the terminal at any time: a text or a ground of the eight
    print("pty.colours=%s" % ("yes" if re.search(rb"\x1b\[(?:[0-9]+;)*(?:3[0-7]|4[0-7])(?:;[0-9]+)*m", output) else "no"))
    ## whether a shade of a palette of 256 colours was set, as a text or a ground, by its number there
    print("pty.shades=%s" % ("yes" if re.search(rb"\x1b\[(?:[0-9]+;)*[34]8;5;[0-9]+(?:;[0-9]+)*m", output) else "no"))
    print("pty.modeTaken=%s" % ("yes" if during is not None and during != before else "no"))
    print("pty.modeBack=%s" % ("unknown" if after is None else "yes" if modeOf(after) == modeOf(before) else "no"))
    print("pty.entered=%s" % ("yes" if entered != -1 else "no"))
    print("pty.left=%s" % ("yes" if entered != -1 and left > entered else "no"))
    print("pty.errorAfterLeft=%s" % ("none" if errorAt == -1 else "yes" if left != -1 and errorAt > left else "no"))
    print("pty.error=%s" % errorLine)
    if os.environ.get("MANAGER_SCREEN_PTY_TRACE"):
        found = []
        for pair in os.environ["MANAGER_SCREEN_PTY_TRACE"].split("|"):
            name, _, text = pair.partition("=")
            sought = marksRead(text).encode("utf-8")
            at = output.find(sought) if sought else -1
            while at != -1:
                found.append((at, name))
                at = output.find(sought, at + 1)
        print("pty.trace=%s" % " ".join(name for at, name in sorted(found)))
    os.close(master)
    os.close(slave)
    return 0


## The settings of a terminal that say whose mode it is in. Left out: the mark the system
## itself sets on a terminal that still holds input (PENDIN).
def modeOf(settings):
    return [settings[0], settings[1], settings[2], settings[3] & ~getattr(termios, "PENDIN", 0),
            [bytes([one]) if isinstance(one, int) else one for one in settings[6]]]


def childRaise(module, arguments):
    def failingRows(readKey, form, text):
        raise RuntimeError("the stand-in for the data of the screen fails")
    module.parseLevels = failingRows
    return module.main(arguments)


def main(arguments):
    if len(arguments) < 2:
        sys.stderr.write("manager-screen.driver.test.py: expects <screen file> script|pty|child-raise ...\n")
        return 2
    if arguments[1] == "pty":
        return ptyRun(arguments[2:])
    module = loadScreen(arguments[0])
    if arguments[1] == "script":
        return scriptRun(module)
    if arguments[1] == "child-raise":
        return childRaise(module, arguments[2:])
    sys.stderr.write("manager-screen.driver.test.py: unknown mode: %s\n" % arguments[1])
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
