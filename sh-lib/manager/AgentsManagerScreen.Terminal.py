##
## AgentsManagerScreen.Terminal.py -- the terminal: the surface the screen draws on and takes its keys from.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the terminal ----

## The surface of the real terminal: a curses window. A text is drawn where it is put, and
## whoever puts it has cut it to fit. Curses is given every character in the cells the
## screen counts it in (textCells), and no emoji, nor any character curses counts otherwise:
## it gets blanks in its cells, and the character is written into them apart (apartWritten),
## so curses' copy of the terminal stays the terminal's whatever the terminal makes of it.
## Curses never shifts cells sideways or lines up and down to save a write (idcok, idlok),
## which would carry what was written apart with them.
## The keys curses hands over as numbers, by the name the screen gives them.
CURSES_KEYS = {
    curses.KEY_UP: "UP", curses.KEY_DOWN: "DOWN", curses.KEY_LEFT: "LEFT", curses.KEY_RIGHT: "RIGHT",
    curses.KEY_PPAGE: "PGUP", curses.KEY_NPAGE: "PGDN", curses.KEY_HOME: "HOME", curses.KEY_END: "END", curses.KEY_ENTER: "ENTER",
    curses.KEY_BACKSPACE: "BACKSPACE", curses.KEY_RESIZE: "RESIZE", curses.KEY_BTAB: "BACKTAB",
    curses.KEY_F1: "F1", curses.KEY_F5: "F5", curses.KEY_F6: "F6", curses.KEY_F9: "F9", curses.KEY_F10: "F10",
} if curses else {}
## The console user's own setting of .local, beside MDLT_CONSOLE_SPACERS and no setting of the agents, that
## leaves the mouse to the terminal where it reads `disable`, so that the terminal's own selection copies
## text; the mouse is reported to the screen where it names nothing else. Read from the environment of the
## start, where the start of the screen (`--manager`) puts what the user saved.
MOUSE_VARIABLE = "MDLT_CONSOLE_MOUSE"


## How many reads in a row that gave nothing, with the descriptor readable, are the end of the input, and how the screen ends then:
## by the status of a hangup, 128 and its number, as endOnSignal ends it for the signal.
INPUT_LOST_READS = 5
INPUT_LOST_STATUS = 128 + signal.SIGHUP


class CursesSurface:
    def __init__(self, window):
        self.window = window
        for kept in (lambda: window.idcok(False), lambda: window.idlok(False)):
            try:
                kept()
            except (curses.error, AttributeError):
                pass
        self.plain, self.coloured = self.looksOf()
        ## what the terminal is told to place the cursor and to draw in a look by, or None where it cannot be
        self.codes = self.codesOf()
        self.sgrs = {}
        ## how many cells curses counts a character in, by the character; what curses is given for a text, by
        ## the text (handedOf)
        self.counted = {}
        self.handed = {}
        try:
            self.counter = curses.newpad(1, 16)
        except curses.error:
            self.counter = None
        ## of the frame being drawn, by line: the characters curses is given that take more than one cell, where
        ## each starts and ends, and its look. Of it and of the one drawn last, by line: the characters written
        ## apart, by their column, each with its cells and its look; and what was put on that line, in its order
        self.wide = {}
        self.apart, self.apartDrawn = {}, {}
        self.puts, self.putsDrawn = {}, {}
        ## whether the next frame is sent to the terminal whole
        self.whole = True
        ## where the cursor stands once the frame is sent, or None where it is hidden (cursor)
        self.at = None
        self.keyNames = CURSES_KEYS
        self.charNames = {"\t": "TAB", "\n": "ENTER", "\r": "ENTER", "\x1b": "ESC", "\x7f": "BACKSPACE", "\b": "BACKSPACE",
                          "\x18": "CTRL-x", "\x12": "CTRL-r"}
        ## Where the pointer was last, for a turn of the wheel that comes with no place.
        self.pointer = (-1, -1)
        self.lost = 0
        self.mouse(True)

    ## The mouse, where the terminal reports one: reported to the screen, its first button
    ## at once, with no wait for a second click, and the wheel; or not reported at all, as
    ## while the terminal is another's, and where the console user turned it off
    ## (MOUSE_VARIABLE). A terminal that reports none changes nothing.
    def mouse(self, reported):
        try:
            curses.mousemask((curses.BUTTON1_PRESSED | curses.BUTTON1_RELEASED | curses.BUTTON1_CLICKED
                              | curses.BUTTON4_PRESSED | getattr(curses, "BUTTON5_PRESSED", WHEEL_DOWN))
                             if reported and os.environ.get(MOUSE_VARIABLE, "") != "disable" else 0)
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
    ## signal of that need have come here, and the next drawing is sent whole.
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
        self.repaint()

    ## Gives the whole terminal to a child and waits for its end: the command from its words
    ## as they are, with no shell, started in that folder, with the environment and the
    ## streams of the screen. However the child ends, and whatever fails here, the terminal
    ## is taken back first (back). While the child runs an interrupt, a quit and a stop
    ## typed at the terminal are the child's alone. Where the screen has the terminal as a
    ## program started from one has it, the child is given it as a shell gives it to a job
    ## (foreground): what is typed there is then signalled to the child's group and to no
    ## other, so the screen and its calls never see it. Where it cannot be handed on so,
    ## the screen notes an interrupt and a quit and does not end with them, and since it
    ## does not ignore them the child starts with what the system does on them. Gives the
    ## status of the child as the system gives it, below 0 the signal that ended it. A
    ## command that cannot be started fails as the system says (OSError).
    def child(self, words, directory):
        self.leave()
        held = {}
        try:
            for number in (signal.SIGINT, signal.SIGQUIT):
                held[number] = signal.signal(number, lambda signalNumber, stackFrame: None)
            terminal = self.ownTerminal()
            if terminal is None:
                return subprocess.call(words, cwd=directory)
            return self.foreground(terminal, words, directory)
        finally:
            for number, handler in held.items():
                signal.signal(number, handler)
            self.back()

    ## The terminal the screen has as its own and is in the foreground of, as the number of
    ## its file, or None: where its input is no terminal it controls, or another group has it.
    def ownTerminal(self):
        try:
            terminal = sys.stdin.fileno()
            return terminal if os.tcgetpgrp(terminal) == os.getpgrp() else None
        except (OSError, ValueError, AttributeError):
            return None

    ## The child as the job that has the terminal: a process group of its own, made the
    ## foreground group of the terminal, in the child before its command starts and here,
    ## so neither comes first. The screen waits for its end. A child that is stopped, by a
    ## stop typed at the terminal or by itself, is continued at once with the terminal:
    ## the screen is no shell that could bring it back later, and a stopped child would
    ## leave the terminal with nobody that reads it. When the child has ended the terminal
    ## is the screen's group's again. The screen does not stop while it takes the terminal
    ## back from the background (SIGTTOU), and the child starts with that as the system has it.
    def foreground(self, terminal, words, directory):
        def lead():
            os.setpgid(0, 0)
            try:
                os.tcsetpgrp(terminal, os.getpgrp())
            except OSError:
                pass
            signal.signal(signal.SIGTTOU, signal.SIG_DFL)
        own = os.getpgrp()
        kept = signal.signal(signal.SIGTTOU, signal.SIG_IGN)
        try:
            process = subprocess.Popen(words, cwd=directory, preexec_fn=lead)
            while True:
                try:
                    os.tcsetpgrp(terminal, process.pid)
                except OSError:
                    pass
                try:
                    found, status = os.waitpid(process.pid, os.WUNTRACED)
                except InterruptedError:
                    continue
                if os.WIFSTOPPED(status):
                    try:
                        os.killpg(process.pid, signal.SIGCONT)
                    except OSError:
                        pass
                    continue
                process.returncode = -os.WTERMSIG(status) if os.WIFSIGNALED(status) else os.WEXITSTATUS(status)
                return process.returncode
        finally:
            try:
                os.tcsetpgrp(terminal, own)
            except OSError:
                pass
            signal.signal(signal.SIGTTOU, kept)

    ## What each look of LOOKS is on this terminal, twice: in bold, reverse and dim alone,
    ## and in its colours, or None where the terminal has not eight of them. The colours are
    ## given for each set a style can name (STYLE_LOOKS), under its name, and under None those
    ## of LOOKS: on a terminal of 256 colours a set takes its exact shades, else its eight. A
    ## set the terminal has not the pairs of colours for is left out: its style draws without.
    ## A look of LINED_LOOKS is underlined besides, in each, where the terminal has underline.
    def looksOf(self):
        flags = {"B": curses.A_BOLD, "R": curses.A_REVERSE, "D": curses.A_DIM}
        try:
            underline = curses.A_UNDERLINE if curses.termattrs() & curses.A_UNDERLINE else 0
        except (curses.error, AttributeError):
            underline = 0
        lined = lambda number: underline if number in LINED_LOOKS else 0
        plain = []
        for number, (letter, mono, text, ground, bright) in enumerate(LOOKS):
            attribute = curses.A_NORMAL | lined(number)
            for flag in mono:
                attribute |= flags[flag]
            plain.append(attribute)
        try:
            if not (curses.has_colors() and curses.COLORS >= 8):
                return plain, None
            ## what is drawn with no colour stands in the terminal's own two, not in white on black
            curses.use_default_colors()
            pairs = {}

            def pairOf(text, ground, bold):
                if (text, ground) not in pairs:
                    curses.init_pair(len(pairs) + 1, text, ground)
                    pairs[(text, ground)] = len(pairs) + 1
                return curses.color_pair(pairs[(text, ground)]) | (curses.A_BOLD if bold else 0)

            def named(name):
                return getattr(curses, "COLOR_" + name.upper())
            coloured = {None: [pairOf(named(text), named(ground), bright) | lined(number) for number, (letter, mono, text, ground, bright) in enumerate(LOOKS)]}
        except (curses.error, AttributeError):
            return plain, None
        fine = curses.COLORS >= 256
        for name, own in STYLE_LOOKS.items():
            try:
                looks = []
                for number, (letter, mono, text, ground, bright) in enumerate(LOOKS):
                    text, ground, bright, fineText, fineGround, bold = own.get(number, (text, ground, bright, None, None, False))
                    looks.append((pairOf(fineText, fineGround, bold) if fine and fineText is not None else pairOf(named(text), named(ground), bright)) | lined(number))
                coloured[name] = looks
            except (curses.error, AttributeError):
                pass
        return plain, coloured

    def size(self):
        lines, columns = self.window.getmaxyx()
        return columns, lines

    ## The looks of the style of now: its colours where it has them and the terminal too, and
    ## its own looks where its colours name them ("looks"), in a style without colours too.
    def looks(self):
        named = STYLE.get("looks")
        coloured = self.coloured.get(named) if (STYLE["colours"] or named) and self.coloured is not None else None
        return coloured if coloured is not None else self.plain

    def clear(self):
        self.apart, self.puts, self.wide = {}, {}, {}
        try:
            self.window.bkgdset(" ", self.looks()[PLAIN])
        except curses.error:
            pass
        self.window.erase()

    ## The next frame is sent to the terminal whole, every cell of it: once, where the terminal
    ## may no longer hold what curses holds of it.
    def repaint(self):
        self.whole = True
        try:
            self.window.clearok(True)
        except curses.error:
            pass

    def put(self, line, column, text, look):
        if MARKS["plain"]:
            text = plainText(text)
        if text.isascii() and text.isprintable():
            handed, apart, wide, cells = text, (), (), len(text)
        else:
            handed, apart, wide, cells = self.handedOf(text)
        self.puts.setdefault(line, []).append((column, text, look))
        held = self.wide.get(line)
        if held:
            ## A character of two cells that the text covers one half of is blanked whole first: curses would keep
            ## the other half as it was, and send it where the terminal has wiped it, or leave an emoji painted
            ## over what now stands on its blank.
            for start, end, was in [one for one in held if one[0] < column < one[1] or one[0] < column + cells < one[1]]:
                try:
                    self.window.addstr(line, start, " " * (end - start), self.looks()[was])
                except curses.error:
                    pass
            held[:] = [one for one in held if one[1] <= column or column + cells <= one[0]]
        for at, width in wide:
            self.wide.setdefault(line, []).append((column + at, column + at + width, look))
        held = self.apart.get(line)
        if held:
            ## what is put over a character written apart takes its cells
            for at in [at for at, (cluster, width, was) in held.items() if at < column + cells and column < at + width]:
                del held[at]
        for at, cluster, width in apart:
            self.apart.setdefault(line, {})[column + at] = (cluster, width, look)
        try:
            self.window.addstr(line, column, handed, self.looks()[look])
        except curses.error:
            ## the last cell of the screen: it is written, and the cursor has nowhere to go
            pass

    ## The cells of a line from that column, that many, drawn again in that look with the
    ## characters this frame put there, as a shadow of Turbo Vision falls on them: in each
    ## what was put there last, and a blank where a character of more than one cell stands
    ## at an end of them, half in and half out, or where nothing was put.
    def shade(self, line, column, count, look):
        owner, held = {}, {}
        for at, text, was in self.puts.get(line, ()):
            for cluster, cells in textCells(text):
                for cell in range(at, at + cells):
                    start = owner.get(cell)
                    if start is not None:
                        for gone in range(start, start + held.pop(start)[1]):
                            owner.pop(gone, None)
                for cell in range(at, at + cells):
                    owner[cell] = at
                held[at] = (cluster, cells)
                at += cells
        shown = []
        cell = column
        while cell < column + count:
            kept = held.get(cell)
            if kept is not None and cell + kept[1] <= column + count:
                shown.append(kept[0])
                cell += kept[1]
            else:
                shown.append(" ")
                cell += 1
        self.put(line, column, "".join(shown), look)

    ## What curses is given for a text: each character in the cells the screen counts it in, but
    ## blanks for an emoji and for a character curses counts otherwise, which is written apart,
    ## with the cell it starts at. The characters curses is given that take more than one cell,
    ## each where it starts and its cells; and the cells of the whole.
    def handedOf(self, text):
        held = self.handed.get(text)
        if held is None:
            parts = []
            apart = []
            wide = []
            at = 0
            for cluster, cells in textCells(text):
                if self.codes is not None and (len(cluster) > 1 or ord(cluster) >= 0x300) and (
                        isEmoji(cluster) or self.cursesCells(cluster) != cells):
                    parts.append(" " * cells)
                    apart.append((at, cluster, cells))
                elif self.codes is None and (len(cluster) > 1 or ord(cluster) >= 0x300) and (
                        isEmoji(cluster) or self.cursesCells(cluster) != cells):
                    ## no way to place the cursor: curses is given the character with the blanks that make up the cells the screen counts it in,
                    ## so that what follows it stands where the screen says, however many cells curses counts it in
                    counted = self.cursesCells(cluster)
                    parts.append(cluster + " " * (cells - counted) if 0 < counted <= cells else " " * cells)
                else:
                    parts.append(cluster)
                    if cells > 1:
                        wide.append((at, cells))
                at += cells
            if len(self.handed) > 4096:
                self.handed.clear()
            held = self.handed[text] = ("".join(parts), tuple(apart), tuple(wide), at)
        return held

    ## How many cells curses counts a character in, as its own cursor moves over it.
    def cursesCells(self, cluster):
        cells = self.counted.get(cluster)
        if cells is None:
            cells = -1
            try:
                self.counter.erase()
                self.counter.addstr(0, 0, cluster)
                cells = self.counter.getyx()[1]
            except (curses.error, AttributeError):
                pass
            self.counted[cluster] = cells
        return cells

    ## What the terminal is told to place its cursor, to keep and to give back where it stands and
    ## how it draws, and to draw in a look by; None where it has no way to place the cursor.
    def codesOf(self):
        try:
            codes = dict((name, curses.tigetstr(name) or b"") for name in ("cup", "sc", "rc", "sgr0", "bold", "dim", "rev", "setaf", "setab"))
        except curses.error:
            return None
        if not codes["cup"]:
            return None
        codes["sc"] = codes["sc"] or b"\x1b7"
        codes["rc"] = codes["rc"] or b"\x1b8"
        return codes

    ## What the terminal is told to draw in that look by, as curses draws it.
    def sgrOf(self, look):
        attribute = self.looks()[look]
        held = self.sgrs.get(attribute)
        if held is None:
            held = self.codes["sgr0"]
            for flag, name in ((curses.A_BOLD, "bold"), (curses.A_DIM, "dim"), (curses.A_REVERSE, "rev")):
                if attribute & flag:
                    held += self.codes[name]
            try:
                pair = curses.pair_number(attribute)
                if pair:
                    text, ground = curses.pair_content(pair)
                    if text >= 0 and self.codes["setaf"]:
                        held += curses.tparm(self.codes["setaf"], text)
                    if ground >= 0 and self.codes["setab"]:
                        held += curses.tparm(self.codes["setab"], ground)
            except curses.error:
                pass
            self.sgrs[attribute] = held
        return held

    ## The characters written apart, after curses has sent its frame: each at its own column, in
    ## its look, the cursor and how the terminal draws kept before and given back after, so that
    ## curses' copy of the terminal stays as it is. On each line curses has sent anew or sent
    ## whole (show), and on every line of a frame sent whole.
    def apartWritten(self, renewed):
        written = []
        for line in sorted(self.apart):
            if self.whole or line in renewed or self.puts.get(line) != self.putsDrawn.get(line):
                for column, (cluster, width, look) in sorted(self.apart[line].items()):
                    written.append(curses.tparm(self.codes["cup"], line, column) + self.sgrOf(look) + cluster.encode("utf-8"))
        if written:
            data = self.codes["sc"] + b"".join(written) + self.codes["rc"]
            while data:
                try:
                    data = data[os.write(sys.stdout.fileno(), data):]
                except InterruptedError:
                    continue
                except OSError:
                    break

    ## The cursor of the frame being drawn: shown at that cell, where a field that has the keys takes
    ## what is typed, or hidden. It is placed when the frame is sent (show), since curses moves its
    ## own cursor with every text put after it.
    def cursor(self, line, column):
        self.at = None if line is None else (line, column)

    ## The screen leaves nothing of itself: every cell blank in the terminal's own colours, sent
    ## whole, the cursor shown at the start of the first line, before curses gives the terminal
    ## back. Where the terminal gives back the screen it had before (its alternate screen) that
    ## comes back as it was; where it has none, it is left empty, and what is said after the end,
    ## and the prompt of the shell, start on a line of their own.
    def wipe(self):
        for leaving in (lambda: self.window.bkgdset(" ", curses.A_NORMAL), self.window.erase, lambda: self.window.clearok(True),
                        lambda: self.window.move(0, 0), self.window.refresh, lambda: curses.curs_set(1)):
            try:
                leaving()
            except curses.error:
                pass

    ## The frame to the terminal. A line where a character written apart in the frame before no
    ## longer stands as it stood is sent whole, every cell of it, once: curses holds blanks there
    ## and would send nothing, and whatever the terminal made of that character, nothing of it
    ## outlives the change. Every other line curses sends as the cells that changed, so a quiet
    ## tick sends what changed alone. The cursor is hidden before the frame is sent, or placed
    ## where it stands, so that curses leaves it there, and the characters written apart give it
    ## back there; it shows only then.
    def show(self):
        renewed = []
        for line, held in self.apartDrawn.items():
            if self.apart.get(line) != held:
                renewed.append(line)
                try:
                    self.window.redrawln(line, 1)
                except curses.error:
                    pass
        try:
            if self.at is None:
                curses.curs_set(0)
            else:
                self.window.move(*self.at)
        except curses.error:
            pass
        self.window.refresh()
        if self.apart:
            self.apartWritten(renewed)
        if self.at is not None:
            try:
                curses.curs_set(1)
            except curses.error:
                pass
        self.apartDrawn, self.putsDrawn = self.apart, self.puts
        self.whole = False

    ## A read that gives nothing is the quiet of the terminal, which is what the screen waits on, or the terminal gone: its
    ## master closed, or hung up, where every read gives nothing at once and for ever. The two are told by the descriptor:
    ## while it reports itself readable, a read that gave nothing can only be the end of its input. A few such reads in a
    ## row end the screen, as a hangup does (INPUT_LOST_STATUS), so that it uses no processor to wait for a terminal that
    ## is not there. A key that comes between the reads, or no readable descriptor, begins the count again.
    def read(self):
        try:
            got = self.window.get_wch() if hasattr(self.window, "get_wch") else self.window.getch()
        except curses.error:
            self.inputGone()
            return None
        self.lost = 0
        return got

    def inputGone(self):
        try:
            readable = select.select([sys.stdin.fileno()], [], [], 0)[0]
        except (OSError, ValueError):
            readable = [0]
        self.lost = self.lost + 1 if readable else 0
        if self.lost >= INPUT_LOST_READS:
            raise SystemExit(INPUT_LOST_STATUS)

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

