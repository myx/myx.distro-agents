#!/usr/bin/env python3
##
## manager-screen.vt.test.py -- a terminal that keeps its cells, for the checks of the manager screen
## that must see what stays on a real terminal after it was drawn on, and not only what the screen
## meant to draw. Run with `python3 -I -B`.
##
##   <vt> <screen file> run <columns> <lines> <dump file> -- <command...>
##       Starts the command on a pseudo-terminal of that size and reads everything it writes into a
##       terminal of its own (Terminal), as a terminal of a Mac draws it: a character an emoji
##       selector follows takes two cells, one a joiner follows takes the next character into its
##       own cells. The steps come on standard input, one a line; what they print is
##       `<tag>.<name>=<value>` and, for a screen, `<tag>|<the line as it stands>|`:
##         keys <keys>            writes them, `\e` Esc, `\r` Enter, `\t` Tab, `\xNN` a byte, and waits until the screen is still
##         mouse <what> <column> <line>   the first button going down (press) or coming up (release) at that cell, as an xterm reports it
##         drag <column>          the border between the windows, as the screen last placed it, pressed and let go in that column
##         size <columns> <lines> the terminal takes that size, as a window that is dragged does: its cells stay where they were
##         await <text>           waits until the screen shows that text
##         idle <seconds>         reads for that long, and keeps how much came and how many frames were drawn: `<tag>` is `idle`
##         check <tag>            compares every cell with what the screen drew last (the dump the command keeps): how
##                                many cells differ, and of them how many show the mark of the selection, a line of a frame,
##                                a shade or a part of a scroll bar; the first that differ
##         items <tag>            each item of the menu that is open as it stands on the terminal, by its number: its text and
##                                the looks of its cells, a number for each look the run met
##         buttons <tag>          the same of the buttons of the dialog that is open, and which of them has the keys
##         cost <tag> <keys>      writes the keys and says how many bytes the screen wrote in answer
##         advance <tag>          how far the screen counts the terminal moves for each kind of emoji
##         cursor <tag>           where the cursor stands and whether it shows; the field of the dialog it stands in, by
##                                its number, and what that field's line holds from its left up to the cursor; and which
##                                button of the dialog has the keys
##         show <tag>             the screen as it stands
##         drawn <tag>            what the screen drew last, as it means it to stand
##         signal <name>          sends the command that signal, SIGTERM or another, by its name
##         end <tag>              waits for the command's end: its status
##         left <tag>             what stands on the terminal after the end: the cells not blank, the first line that is not,
##                                the cursor, and whether its line is blank from it on
##   <vt> <screen file> inner <dump file> -- <arguments of the screen...>
##       The real screen, with its own curses surface, that also keeps after each frame what it drew in that frame
##       (each text put, laid out in cells by the screen's own count) in the dump file, with the places of
##       what can be clicked: what `check` compares the terminal with. Where MANAGER_SCREEN_VT_DIALOGS=all, every
##       dialog the screen declares is open at its start, each waiting for the one before it to close. Where
##       MANAGER_SCREEN_VT_RAISE=1, the drawing fails after its third frame.
##

import codecs
import fcntl
import importlib.util
import json
import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import unicodedata

sys.dont_write_bytecode = True

## the marks the checks count among the cells that differ
SELECTION_MARKS = ">"
FRAME_MARKS = "┌─┐│└┘╔═╗║╚╝├┤"
SHADE_MARKS = "░▒■▲▼"
## DEC's special graphics, where a terminal is asked for them
GRAPHICS = dict(zip("jklmnqtuvwx`afg~", "┘┐┌└┼─├┤┴┬│◆▒°±·"))


## Whether a character goes into the cell of the one before it: a joiner, a selector, a mark; on a terminal that
## draws emoji wide, the mark of a skin too.
def joins(character, wide=False):
    codePoint = ord(character)
    return (codePoint == 0x200D or 0xFE00 <= codePoint <= 0xFE0F or (wide and 0x1F3FB <= codePoint <= 0x1F3FF)
            or unicodedata.category(character) in ("Mn", "Me"))


## A terminal: the cells of its screen and of its other screen, each what is written there and how; the cursor,
## and whether the next character goes to the next line first; the lines it scrolls. It answers where its cursor
## is when it is asked (ESC [ 6 n), as a terminal does, by its own count of the cells, but where
## MANAGER_SCREEN_VT_SILENT=1.
class Terminal:
    def __init__(self, columns, lines):
        self.columns, self.lines = columns, lines
        self.look = (None, None, False, False, False)
        self.main = self.blankLines(columns, lines)
        self.other = self.blankLines(columns, lines)
        self.cells = self.main
        self.y = self.x = 0
        self.wrapNext = False
        self.top, self.bottom = 0, lines - 1
        self.inserting = False
        self.autoWrap = True
        self.saved = (0, 0, self.look, False)
        ## whether the cursor shows
        self.shown = True
        self.graphics = False
        self.last = None
        self.joinNext = False
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")
        self.pending = ""
        self.answers = b""
        ## a terminal that never says where its cursor is, where MANAGER_SCREEN_VT_SILENT=1; one that has no other
        ## screen, as GNU screen with `altscreen off`, where MANAGER_SCREEN_VT_NOALT=1
        self.silent = os.environ.get("MANAGER_SCREEN_VT_SILENT") == "1"
        self.otherScreen = os.environ.get("MANAGER_SCREEN_VT_NOALT") != "1"
        ## how this terminal moves for an emoji a selector makes of a character of one cell, a keycap, and emoji
        ## joined or with the mark of a skin: `wide`, two cells and the joined ones as one, as iTerm does; `narrow`,
        ## the cells of the character before the selector and each joined one in its own, as Terminal.app and
        ## GNU screen do and the curses of the system counts
        self.wideEmoji = os.environ.get("MANAGER_SCREEN_VT_EMOJI", "narrow") == "wide"

    def blank(self):
        return [" ", (None, self.look[1], False, False, False)]

    def blankLines(self, columns, lines):
        return [[[" ", (None, None, False, False, False)] for column in range(columns)] for line in range(lines)]

    def resize(self, columns, lines):
        onOther = self.cells is self.other
        for name in ("main", "other"):
            old = getattr(self, name)
            new = self.blankLines(columns, lines)
            for line in range(min(lines, self.lines)):
                for column in range(min(columns, self.columns)):
                    new[line][column] = old[line][column]
            setattr(self, name, new)
        self.cells = self.other if onOther else self.main
        self.columns, self.lines = columns, lines
        self.top, self.bottom = 0, lines - 1
        self.y, self.x = min(self.y, lines - 1), min(self.x, columns - 1)
        self.wrapNext = False
        self.last = None

    def feed(self, data):
        text = self.pending + self.decoder.decode(data)
        self.pending = ""
        at = 0
        while at < len(text):
            character = text[at]
            if character == "\x1b":
                used = self.escape(text, at)
                if used is None:
                    self.pending = text[at:]
                    return
                at = used
                continue
            at += 1
            if ord(character) < 32 or ord(character) == 127:
                self.control(character)
            else:
                self.printed(character)

    def control(self, character):
        if character == "\r":
            self.x, self.wrapNext = 0, False
        elif character in "\n\x0b\x0c":
            self.lineFeed()
        elif character == "\b":
            self.x, self.wrapNext = max(0, self.x - 1), False
        elif character == "\t":
            self.x, self.wrapNext = min(self.columns - 1, (self.x // 8 + 1) * 8), False
        elif character == "\x0e":
            self.graphics = True
        elif character == "\x0f":
            self.graphics = False

    def lineFeed(self):
        self.wrapNext = False
        if self.y == self.bottom:
            self.scroll(self.top, self.bottom, 1)
        elif self.y < self.lines - 1:
            self.y += 1

    ## lines of the region move up by count (down where count is below 0), blank lines coming in
    def scroll(self, top, bottom, count):
        for _ in range(abs(count)):
            if count > 0:
                del self.cells[top]
                self.cells.insert(bottom, [self.blank() for column in range(self.columns)])
            else:
                del self.cells[bottom]
                self.cells.insert(top, [self.blank() for column in range(self.columns)])

    ## A cell is written on: a character of two cells it was a half of is wiped whole.
    def unwide(self, y, x):
        row = self.cells[y]
        if row[x][0] == "" and x > 0:
            row[x - 1] = self.blank()
        if x + 1 < self.columns and row[x + 1][0] == "":
            row[x + 1] = self.blank()

    def printed(self, character):
        if (self.joinNext and self.wideEmoji) or joins(character, self.wideEmoji):
            self.joinNext = ord(character) == 0x200D
            if self.last is None:
                return
            y, x = self.last
            row = self.cells[y]
            row[x][0] += character
            ## where emoji are drawn wide, a selector makes the character before it take two cells, and the cursor
            ## goes on by one more
            if self.wideEmoji and ord(character) == 0xFE0F and x + 1 < self.columns and row[x + 1][0] != "":
                self.unwide(y, x + 1)
                row[x + 1] = ["", self.look]
                if x + 2 >= self.columns:
                    self.x, self.wrapNext = self.columns - 1, True
                else:
                    self.x = x + 2
            return
        if self.graphics and character in GRAPHICS:
            character = GRAPHICS[character]
        width = 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
        if self.wrapNext and self.autoWrap:
            self.x = 0
            self.lineFeed()
        self.wrapNext = False
        if width == 2 and self.x + 2 > self.columns:
            self.cells[self.y][self.x] = self.blank()
            self.x = 0
            self.lineFeed()
        row = self.cells[self.y]
        if self.inserting:
            for _ in range(width):
                row.insert(self.x, self.blank())
                del row[self.columns]
        self.unwide(self.y, self.x)
        row[self.x] = [character, self.look]
        if width == 2:
            self.unwide(self.y, self.x + 1)
            row[self.x + 1] = ["", self.look]
        self.last = (self.y, self.x)
        if self.x + width >= self.columns:
            self.x, self.wrapNext = self.columns - 1, True
        else:
            self.x += width

    ## an escape sequence from `at`: where it ends, or None while it has not come whole
    def escape(self, text, at):
        if at + 1 >= len(text):
            return None
        kind = text[at + 1]
        if kind == "[":
            found = re.compile(r"\x1b\[([<=>?]?)([0-9;:]*)([ -/]*)([@-~])").match(text, at)
            if found is None:
                return None if re.compile(r"\x1b\[[<=>?]?[0-9;:]*[ -/]*$").match(text, at) else at + 2
            self.csi(found.group(1), [int(part) if part else None for part in re.split("[;:]", found.group(2))] if found.group(2) else [],
                     found.group(3), found.group(4))
            return found.end()
        if kind == "]":
            end = re.compile(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)").match(text, at)
            return end.end() if end else None
        if kind in "()*+":
            if at + 2 >= len(text):
                return None
            if kind == "(":
                self.graphics = text[at + 2] == "0"
            return at + 3
        if kind == "7":
            self.saved = (self.y, self.x, self.look, self.wrapNext)
        elif kind == "8":
            self.y, self.x, self.look, self.wrapNext = (tuple(self.saved) + (self.look, False))[:4]
        elif kind == "M":
            if self.y == self.top:
                self.scroll(self.top, self.bottom, -1)
            elif self.y > 0:
                self.y -= 1
            self.wrapNext = False
        elif kind == "D":
            self.lineFeed()
        elif kind == "E":
            self.x = 0
            self.lineFeed()
        elif kind == "c":
            self.__init__(self.columns, self.lines)
        return at + 2

    def csi(self, private, params, between, final):
        def param(index, default=1):
            value = params[index] if index < len(params) else None
            return default if value in (None, 0) and default is not None else (value if value is not None else 0)
        if private == "?" and final in "hl":
            on = final == "h"
            for mode in params:
                if mode in (1049, 1047, 47) and self.otherScreen:
                    if mode == 1049 and on:
                        self.saved = (self.y, self.x, self.look, False)
                    self.cells = self.other if on else self.main
                    if on:
                        self.other[:] = self.blankLines(self.columns, self.lines)
                    elif mode == 1049:
                        self.y, self.x = self.saved[:2]
                elif mode == 7:
                    self.autoWrap = on
                elif mode == 25:
                    self.shown = on
            return
        if private or between:
            return
        row = self.cells[self.y] if final in "KX@P" else None
        if final in "Hf":
            self.y = min(self.lines - 1, param(0) - 1)
            self.x = min(self.columns - 1, param(1) - 1)
        elif final == "A":
            self.y = max(self.top if self.y >= self.top else 0, self.y - param(0))
        elif final == "B":
            self.y = min(self.bottom if self.y <= self.bottom else self.lines - 1, self.y + param(0))
        elif final == "C":
            self.x = min(self.columns - 1, self.x + param(0))
        elif final == "D":
            self.x = max(0, self.x - param(0))
        elif final == "E":
            self.y, self.x = min(self.lines - 1, self.y + param(0)), 0
        elif final == "F":
            self.y, self.x = max(0, self.y - param(0)), 0
        elif final in "G`":
            self.x = min(self.columns - 1, param(0) - 1)
        elif final == "d":
            self.y = min(self.lines - 1, param(0) - 1)
        elif final == "J":
            how = param(0, None) or 0
            spans = {0: [(self.y, self.x, self.columns)] + [(line, 0, self.columns) for line in range(self.y + 1, self.lines)],
                     1: [(line, 0, self.columns) for line in range(self.y)] + [(self.y, 0, self.x + 1)]}.get(
                         how, [(line, 0, self.columns) for line in range(self.lines)])
            for line, start, end in spans:
                for column in range(start, end):
                    self.cells[line][column] = self.blank()
        elif final == "K":
            how = param(0, None) or 0
            start, end = {0: (self.x, self.columns), 1: (0, self.x + 1)}.get(how, (0, self.columns))
            for column in range(start, end):
                row[column] = self.blank()
        elif final == "X":
            for column in range(self.x, min(self.columns, self.x + param(0))):
                row[column] = self.blank()
        elif final == "@":
            for _ in range(min(param(0), self.columns - self.x)):
                row.insert(self.x, self.blank())
                del row[self.columns]
        elif final == "P":
            for _ in range(min(param(0), self.columns - self.x)):
                del row[self.x]
                row.append(self.blank())
        elif final in "LM":
            if self.top <= self.y <= self.bottom:
                self.scroll(self.y, self.bottom, -param(0) if final == "L" else param(0))
            self.x = 0
        elif final == "S":
            self.scroll(self.top, self.bottom, param(0))
        elif final == "T":
            self.scroll(self.top, self.bottom, -param(0))
        elif final == "r":
            self.top = param(0) - 1
            self.bottom = min(self.lines - 1, param(1, self.lines) - 1)
            self.y = self.x = 0
        elif final == "h" and 4 in params:
            self.inserting = True
        elif final == "l" and 4 in params:
            self.inserting = False
        elif final == "s":
            self.saved = (self.y, self.x, self.look, False)
        elif final == "u":
            self.y, self.x = self.saved[:2]
        elif final == "b" and self.last is not None:
            character = self.cells[self.last[0]][self.last[1]][0]
            for _ in range(param(0)):
                self.printed(character)
        elif final == "m":
            self.sgr(params or [0])
        elif final == "n" and params[:1] == [6] and not self.silent:
            self.answers += ("\x1b[%d;%dR" % (self.y + 1, self.x + 1)).encode("ascii")
        if final not in "mhlb":
            self.wrapNext = False

    def sgr(self, params):
        text, ground, bold, dim, reverse = self.look
        at = 0
        while at < len(params):
            code = params[at] or 0
            if code == 0:
                text, ground, bold, dim, reverse = None, None, False, False, False
            elif code == 1:
                bold = True
            elif code == 2:
                dim = True
            elif code == 22:
                bold = dim = False
            elif code == 7:
                reverse = True
            elif code == 27:
                reverse = False
            elif 30 <= code <= 37 or 90 <= code <= 97:
                text = code
            elif code == 39:
                text = None
            elif 40 <= code <= 47 or 100 <= code <= 107:
                ground = code
            elif code == 49:
                ground = None
            elif code in (38, 48):
                kind = params[at + 1] if at + 1 < len(params) else None
                value = tuple(params[at + 1:at + 3]) if kind == 5 else tuple(params[at + 1:at + 5])
                if code == 38:
                    text = value
                else:
                    ground = value
                at += 2 if kind == 5 else 4
            at += 1
        self.look = (text, ground, bold, dim, reverse)

    def textLines(self):
        return ["".join(cell[0] for cell in row) for row in self.cells]


## What a cell holds, as the checks compare it: its character without what joins it, a half of one of two cells
## as a blank.
def base(cell):
    for character in cell:
        if not joins(character):
            return character
    return " "


def runSteps(arguments):
    columns, lines, dumpPath = int(arguments[0]), int(arguments[1]), arguments[2]
    command = arguments[4:]
    terminal = Terminal(columns, lines)
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", lines, columns, 0, 0))
    environment = dict(os.environ)
    environment["TERM"] = os.environ.get("MANAGER_SCREEN_PTY_TERM", "xterm-256color")
    environment.pop("LINES", None)
    environment.pop("COLUMNS", None)
    ## the command as a program started from a terminal is: the leader of a session of its own, the pseudo-terminal
    ## its controlling terminal, so that a change of its size is signalled to it
    def ownTerminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=environment, preexec_fn=ownTerminal)
    counted = [0]

    def pump(seconds, quiet=None):
        deadline = time.time() + seconds
        lastAt = time.time()
        while time.time() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    return
                counted[0] += len(data)
                terminal.feed(data)
                if terminal.answers:
                    os.write(master, terminal.answers)
                    terminal.answers = b""
                lastAt = time.time()
            elif quiet is not None and time.time() - lastAt >= quiet:
                return
            if process.poll() is not None and not select.select([master], [], [], 0)[0]:
                return

    def dump():
        try:
            with open(dumpPath, encoding="utf-8") as held:
                return json.load(held)
        except (OSError, ValueError):
            return None

    lookIds = {}

    def lookOf(cell):
        return lookIds.setdefault(cell[1], len(lookIds))

    def differences(drawn):
        found = []
        for line in range(min(lines, drawn["lines"])):
            for column in range(min(columns, drawn["columns"])):
                want = drawn["cells"][line][column]
                got = terminal.cells[line][column][0]
                if got == "\ufffd" and (want.startswith("\x00") or want.strip()):
                    ## a multiplexer's mark for a character it cannot draw, where the screen drew one
                    found.append((line, column, "\ufffd", base(want.lstrip("\x00")) or "+"))
                elif want.startswith("\x00"):
                    ## a cell of a character of more than one: the terminal shows it, or its parts, or the blank the
                    ## screen puts after it, or nothing where the character before covers it
                    if got not in ("", " ") and base(got) not in want:
                        found.append((line, column, base(got), "+"))
                elif base(want) != base(got) and not (got == "" and base(want) == " "):
                    found.append((line, column, base(got), base(want)))
        return found

    for step in sys.stdin:
        step = step.rstrip("\n")
        if not step.strip() or step.lstrip().startswith("#"):
            continue
        command, _, rest = step.strip().partition(" ")
        words = rest.split()
        if command == "keys":
            os.write(master, re.sub(r"\\x([0-9a-fA-F]{2})", lambda found: chr(int(found.group(1), 16)),
                                    rest.replace("\\e", "\x1b").replace("\\r", "\r").replace("\\t", "\t")).encode("utf-8"))
            pump(6, 0.5)
        elif command == "mouse":
            button = {"press": 0, "release": 3}[words[0]]
            os.write(master, b"\x1b[M" + bytes([32 + button, 33 + int(words[1]), 33 + int(words[2])]))
            pump(6, 0.5)
        elif command == "drag":
            drawn = dump() or {"spots": []}
            border = [one for one in drawn["spots"] if one[4][0] == "split"]
            if border:
                left, top = border[-1][0], border[-1][1] + 3
                os.write(master, b"\x1b[M" + bytes([32, 33 + left, 33 + top]))
                pump(2, 0.3)
                os.write(master, b"\x1b[M" + bytes([35, 33 + int(words[0]), 33 + top]))
                pump(6, 0.5)
            print("drag.from=%s" % (border[-1][0] if border else "none"))
        elif command == "size":
            columns, lines = int(words[0]), int(words[1])
            terminal.resize(columns, lines)
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", lines, columns, 0, 0))
            pump(6, 0.8)
        elif command == "await":
            deadline = time.time() + 20
            while time.time() < deadline and not any(rest in line for line in terminal.textLines()):
                pump(0.2)
            print("await.%s=%s" % (rest.replace(" ", "_"), "yes" if any(rest in line for line in terminal.textLines()) else "no"))
            pump(3, 0.6)
        elif command == "idle":
            before = dump()
            counted[0] = 0
            pump(float(words[0]))
            after = dump()
            frames = (after["frame"] - before["frame"]) if before and after else 0
            print("idle.bytes=%d" % counted[0])
            print("idle.frames=%d" % frames)
            print("idle.ms=%.2f" % ((after["ms"] - before["ms"]) / frames if frames else 0.0))
        elif command == "check":
            tag = words[0]
            found = None
            for attempt in range(6):
                pump(2, 0.4)
                drawn = dump()
                found = differences(drawn) if drawn else [(-1, -1, "", "no dump")]
                if not found:
                    break
            print("%s.differ=%d" % (tag, len(found)))
            ## of them, the cells where a multiplexer between shows its mark for a character it cannot draw, U+FFFD, in
            ## place of an emoji of the screen: that one is where it should be
            print("%s.replaced=%d" % (tag, len([one for one in found if one[2] == "\ufffd"])))
            print("%s.marks=%d" % (tag, len([one for one in found if one[2] in SELECTION_MARKS])))
            print("%s.frames=%d" % (tag, len([one for one in found if one[2] in FRAME_MARKS])))
            print("%s.shades=%d" % (tag, len([one for one in found if one[2] in SHADE_MARKS])))
            print("%s.first=%s" % (tag, " ".join("%d,%d:%s/%s" % one for one in found[:6])))
        elif command in ("items", "buttons"):
            ## each item of the menu that is open, or each button of the dialog, as it stands on the terminal: its
            ## text and the look of its cells, a number for each look met in the run, and which one has the keys
            tag = words[0]
            pump(2, 0.4)
            drawn = dump() or {"spots": [], "focus": None}
            for left, top, width, height, what in drawn["spots"]:
                if what[0] == command[:-1]:
                    cells = terminal.cells[top][left:left + width]
                    print("%s.%s.%s=%s@%s" % (tag, command[:-1], what[1], "".join(base(cell[0]) for cell in cells).rstrip(),
                                              ",".join(sorted(set(str(lookOf(cell)) for cell in cells)))))
            print("%s.focus=%s" % (tag, drawn.get("focus")))
        elif command == "cost":
            ## the keys after the tag written, and how much the screen wrote in answer
            counted[0] = 0
            os.write(master, rest.partition(" ")[2].replace("\\e", "\x1b").encode("utf-8"))
            pump(6, 0.5)
            print("%s.bytes=%d" % (words[0], counted[0]))
        elif command == "advance":
            drawn = dump() or {}
            print("%s.advance=%s" % (words[0], " ".join("%s=%s" % pair for pair in sorted(drawn.get("advance", {}).items()))))
        elif command == "cursor":
            ## where the cursor stands and whether it shows; the field it stands in, as the screen last placed the fields,
            ## and that field's line from its left up to the cursor; the button that has the keys
            pump(2, 0.4)
            drawn = dump() or {"spots": [], "focus": None}
            field = next(((left, what[1]) for left, top, width, height, what in drawn["spots"] if what[0] == "field"
                          and left <= terminal.x < left + width and top <= terminal.y < top + height), None)
            print("%s.cursor=%d,%d" % (words[0], terminal.y, terminal.x))
            print("%s.shown=%s" % (words[0], "yes" if terminal.shown else "no"))
            print("%s.field=%s" % (words[0], "none" if field is None else field[1]))
            print("%s.before=%s" % (words[0], "" if field is None else "".join(cell[0] for cell in terminal.cells[terminal.y][field[0]:terminal.x])))
            print("%s.focus=%s" % (words[0], drawn.get("focus")))
        elif command == "show":
            for line in terminal.textLines():
                print("%s|%s|" % (words[0], line))
        elif command == "drawn":
            ## what the screen drew last, as it means it to stand
            for row in (dump() or {"cells": []})["cells"]:
                print("%s|%s|" % (words[0], "".join("" if cell.startswith("\x00") else cell for cell in row)))
        elif command == "signal":
            ## that signal sent to the command, by its name
            process.send_signal(getattr(signal, words[0]))
            pump(6, 0.5)
        elif command == "left":
            ## what stands on the terminal once the command has ended: how many cells are not blank, the first line
            ## that is not, where the cursor is and whether its line is blank from it on
            pump(1, 0.3)
            filled = [line.rstrip() for line in terminal.textLines()]
            print("%s.cells=%d" % (words[0], sum(len(line.replace(" ", "")) for line in filled)))
            print("%s.first=%s" % (words[0], next((line.strip() for line in filled if line.strip()), "")))
            print("%s.cursor=%d,%d" % (words[0], terminal.y, terminal.x))
            print("%s.lineBlank=%s" % (words[0], "yes" if not terminal.textLines()[terminal.y][terminal.x:].strip() else "no"))
        elif command == "end":
            deadline = time.time() + 20
            while process.poll() is None and time.time() < deadline:
                pump(0.2)
            if process.poll() is None:
                process.kill()
            print("%s.rc=%s" % (words[0], process.wait()))
    if process.poll() is None:
        process.kill()
        process.wait()
    os.close(master)
    os.close(slave)
    return 0


## The real screen, keeping after each frame what it drew in it: the texts put since the screen was last
## wiped, laid out by the screen's own count (textCells), a character of two cells overwriting the half of
## another wiping it whole as a terminal does; the places that can be clicked; the frames drawn and the time
## the drawing took up to the terminal's refresh, in milliseconds, all frames together.
def innerRun(screenFile, dumpPath, arguments):
    spec = importlib.util.spec_from_file_location("AgentsManagerScreen", screenFile)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    surfaceOf = module.CursesSurface
    drawScreen = module.drawScreen
    kept = {"frame": 0, "ms": 0.0, "state": None, "started": 0.0}

    class KeptSurface(surfaceOf):
        def clear(self):
            self.kept = []
            surfaceOf.clear(self)

        def put(self, line, column, text, look):
            self.kept.append((line, column, text))
            surfaceOf.put(self, line, column, text, look)

        def show(self):
            surfaceOf.show(self)
            kept["ms"] += (time.perf_counter() - kept["started"]) * 1000.0
            columns, lines = self.size()
            cells = [[" "] * columns for line in range(lines)]
            for line, column, text in self.kept:
                if not 0 <= line < lines:
                    continue
                for cluster, width in module.textCells(module.plainText(text) if module.MARKS["plain"] else text):
                    if column + width > columns:
                        break
                    row = cells[line]
                    for at in range(column, column + width):
                        if row[at].startswith("\x00"):
                            back = at
                            while back > 0 and row[back].startswith("\x00"):
                                row[back] = " "
                                back -= 1
                            row[back] = " "
                        after = at + 1
                        while after < columns and row[after].startswith("\x00"):
                            row[after] = " "
                            after += 1
                    row[column] = cluster
                    for at in range(column + 1, column + width):
                        row[at] = "\x00" + cluster
                    column += width
            kept["frame"] += 1
            state = kept["state"]
            focus = None
            if state is not None and state.dialog is not None:
                what, index, control = module.dialogFocus(state.dialog)
                focus = index if what == "button" else None
            held = {"frame": kept["frame"], "ms": kept["ms"], "columns": columns, "lines": lines, "cells": cells,
                    "spots": [list(one) for one in (state.spots if state is not None else ())], "focus": focus,
                    "advance": dict(getattr(module, "EMOJI_ADVANCE", {}))}
            with open(dumpPath + ".new", "w", encoding="utf-8") as written:
                json.dump(held, written)
            os.replace(dumpPath + ".new", dumpPath)

    def timedDraw(surface, state):
        if kept["state"] is None and os.environ.get("MANAGER_SCREEN_VT_DIALOGS") == "all":
            ## every dialog the screen declares, each waiting for the one before it to close; what fills one from
            ## what was read is not run, and each list of options has three
            module.DIALOG_FILLS.clear()
            options = {"options": [("1", "first"), ("2", "second"), ("3", "third")]}
            for name, declared in module.DIALOGS.items():
                module.openDialog(state, name, dict((control["name"], options) for control in declared["controls"]
                                                    if control["kind"] in ("checks", "radios", "list")),
                                  {"text": "the dialog %s" % name}, "Dialog %s" % name)
        kept["state"] = state
        kept["started"] = time.perf_counter()
        if os.environ.get("MANAGER_SCREEN_VT_RAISE") == "1" and kept["frame"] >= 3:
            raise RuntimeError("the rig raises in the drawing")
        drawScreen(surface, state)

    module.CursesSurface = KeptSurface
    module.drawScreen = timedDraw
    return module.main(arguments)


def main(arguments):
    if len(arguments) >= 4 and arguments[1] == "run":
        return runSteps(arguments[2:])
    if len(arguments) >= 4 and arguments[1] == "inner" and arguments[3] == "--":
        return innerRun(arguments[0], arguments[2], arguments[4:])
    sys.stderr.write("manager-screen.vt.test.py: expects <screen file> run <columns> <lines> <dump> -- <command...>"
                     " | inner <dump> -- <arguments...>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
