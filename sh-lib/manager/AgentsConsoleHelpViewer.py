#!/usr/bin/env python3
##
## AgentsConsoleHelpViewer.py -- the help viewer of the console completion (F12.1 of the
## refactorings epic): a command's help in a scrollable view, not a dump to stderr. The help
## is read as text on standard input, already rendered by myx.common lib/catMarkdown (the one
## Markdown renderer), and shown on the terminal's alternate screen; the terminal's buffer is
## given back when the view is left. Its one option is `--find <prefix>`: the view then opens
## scrolled to the first line that begins with that prefix (an option of the help being typed
## as the completion prefix), holds it highlighted for a moment, and then leaves it as the rest.
##
## It is a small view of its own, not the manager screen: the help of one command, read once
## and left. Keys: Up/Down/j/k by a line, Space/PageDown and PageUp by a page, Home/End (g/G)
## to the top and the bottom, q or Esc leaves. Where python has no curses module, the help is
## printed to stderr as the plain dump, so the help is not lost.
##

import os
import sys
import time

HIGHLIGHT_SECONDS = 1.5


def findLine(lines, prefix):
    for index, line in enumerate(lines):
        if line.lstrip().startswith(prefix):
            return index
    return None


def openTty():
    try:
        return open("/dev/tty", "r"), open("/dev/tty", "w")
    except OSError:
        return None, None


def run(stdscr, lines, findAt):
    try:
        curses = sys.modules["curses"]
        curses.curs_set(0)
    except Exception:
        pass
    top = 0
    height, width = stdscr.getmaxyx()
    highlightUntil = 0.0
    if findAt is not None:
        top = max(0, min(findAt, max(0, len(lines) - height + 1)))
        highlightUntil = time.monotonic() + HIGHLIGHT_SECONDS
    while True:
        height, width = stdscr.getmaxyx()
        stdscr.erase()
        for row in range(max(0, height - 1)):
            lineIndex = top + row
            if lineIndex >= len(lines):
                break
            text = lines[lineIndex][: width - 1]
            if findAt is not None and lineIndex == findAt and time.monotonic() < highlightUntil:
                stdscr.addstr(row, 0, text, curses.A_REVERSE)
            else:
                stdscr.addstr(row, 0, text)
        status = " Help: Up/Down by a line, Space/PageUp/PageDown by a page, Home/End the ends, q or Esc leaves "
        try:
            stdscr.addstr(height - 1, 0, status[: width - 1], curses.A_REVERSE)
        except Exception:
            pass
        stdscr.refresh()
        key = stdscr.getch()
        if key in (ord("q"), ord("Q"), 27):
            return
        if key in (curses.KEY_UP, ord("k")):
            top = max(0, top - 1)
        elif key in (curses.KEY_DOWN, ord("j")):
            top = min(max(0, len(lines) - height + 1), top + 1)
        elif key in (curses.KEY_PPAGE,):
            top = max(0, top - (height - 1))
        elif key in (curses.KEY_NPAGE, ord(" ")):
            top = min(max(0, len(lines) - height + 1), top + (height - 1))
        elif key in (curses.KEY_HOME, ord("g")):
            top = 0
        elif key in (curses.KEY_END, ord("G")):
            top = max(0, len(lines) - height + 1)


def main():
    args = sys.argv[1:]
    prefix = None
    if len(args) >= 2 and args[0] == "--find":
        prefix = args[1]
        args = args[2:]
    text = sys.stdin.read()
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines:
        return 0
    findAt = findLine(lines, prefix) if prefix else None

    try:
        import curses
    except ImportError:
        sys.stderr.write(text if text.endswith("\n") else text + "\n")
        return 0

    ttyIn, ttyOut = openTty()
    if ttyIn is None or ttyOut is None or not ttyIn.isatty() or not ttyOut.isatty():
        sys.stderr.write(text if text.endswith("\n") else text + "\n")
        return 0

    oldIn, oldOut = sys.stdin, sys.stdout
    sys.stdin, sys.stdout = ttyIn, ttyOut
    try:
        curses.wrapper(run, lines, findAt)
    finally:
        sys.stdin, sys.stdout = oldIn, oldOut
        try:
            ttyIn.close()
            ttyOut.close()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
