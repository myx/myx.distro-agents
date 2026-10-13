#!/usr/bin/env python3
##
## AgentsManagerScreen.py -- the manager screen of the agents console: what
## `DistroAgentsConsole.sh --manager` shows, started by `DistroAgentsTools.fn.sh
## --intern-manager`. Two panes between two status lines: the list on the right,
## what is selected there on the left, and under that one line to type in.
##
## The screen only draws and takes keys. What it shows and what it does goes
## through operations of the tooling, each run as a process of its own (READS,
## CALLS, OperationReader), so that another front end can use the same operations.
## It reads no file of a session and no registry itself, and it signals no process
## and starts no CLI itself: a kill and a start are operations too.
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

## How a text is drawn. A surface maps them to what its terminal has.
PLAIN, BOLD, REVERSE, DIM = 0, 1, 2, 3

## The marks of the drawing. plainMarks() changes them for a terminal that is not UTF-8.
MARKS = {"separator": "│", "cut": "…", "plain": False}
MARK_SELECTED = ">"
MARK_READING = "~"
MARK_OLD = "!"

## The root of the list, in its order: the id of each section and what it shows as.
SECTIONS = (
    ("sessions", "Sessions / Activity"),
    ("pending", "Pending Questions"),
    ("team", "Team Members"),
    ("settings", "Settings / Configuration"),
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
## names what a row must carry for the read to be made at all.
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
    ## One member, whole: its information, the sessions it is in, its grants and its settings.
    "view:team:record": {"operation": ["--manager-team-member-read", "{id}"], "rows": "member-read", "needs": "member"},
}

## What each action asks the tooling for: the operation with its arguments, {id} the id of
## what it acts on. The screen itself signals no process and starts no CLI. A session's id
## ends every live run of it; `--run` takes the id as a run's own, so on the row of an
## agent that agent alone is ended, the founder too, whose id is its session's. A start
## names its routine by its selector, or takes the standing default routine with what was
## typed as its task text, which goes on standard input and is never a word of the command.
## One member is started by its name, with what was typed as its prompt, on standard input too.
CALLS = {
    "kill:session": ["--manager-session-kill", "--session-id", "{id}"],
    "kill:run": ["--manager-session-kill", "--session-id", "{id}", "--run"],
    "launch": ["--magic-spawn-session", "--routine", "{id}"],
    "prompt": ["--magic-spawn-session", "--routine-default"],
    "start": ["--manager-spawn-member", "{id}"],
}
## What a start names its session with, ahead of the name.
CALL_NAME = "--session-name-or-comment"
## The word that confirms a kill, typed whole.
KILL_WORD = "yes"

## The key that reads now what is shown, without waiting for the period.
KEY_READ_NOW = "F5"
## The keys that act on what is selected: the key, and the name of its action.
ACTION_KEYS = (
    ("k", "kill"),
    ("p", "pause"),
    ("r", "resume"),
    ("s", "stop"),
    ("R", "restart"),
    ("l", "log"),
    ("n", "start"),
)
## The handler of each action: handler(state, row) gives the text for the bottom line, or
## None. Where it must ask first it opens a dialog with openDialog(). None here: the task of
## that action has not built it.
ACTION_HANDLERS = {
    ## asks for the typed word, then kills the selected session or agent: askKill, set where it is defined
    "kill": None,
    "pause": None,
    "resume": None,
    "stop": None,
    "restart": None,
    ## switches the left pane between the feed and the raw log: switchLog, set where it is defined
    "log": None,
    ## Enter on a routine of `Launch / Spawn`, and on its free prompt: askLaunch and askPrompt, set where they are defined
    "launch": None,
    "prompt": None,
    ## starts the selected team member with a prompt: askStart, set where it is defined
    "start": None,
}
## The actions that act on a row, by its level and the kind of the row. The left pane names
## the keys of those whose handler is built under the item; the bottom line keeps the keys
## of the screen. An ask has none: no key answers one, and answering in the manager comes
## to stand here.
ITEM_ACTIONS = {
    "sessions:record": ("kill", "pause", "resume", "stop", "restart", "log"),
    "sessions/*:record": ("kill", "pause", "resume", "stop", "restart", "log"),
    "pending:record": (),
    "team:record": ("start",),
}
## What Enter does on a row that is not dived into, by its level and the kind of the row:
## the name of its action. The left pane names it `Enter start`.
ENTER_ACTIONS = {
    "sessions/launch:free": "prompt",
    "sessions/launch:record": "launch",
}
## Whether an action acts on a row as it is now: fits(state, row), set where it is defined.
## An action with no entry acts on every row ITEM_ACTIONS and ENTER_ACTIONS give it.
ACTION_FITS = {}
HINTS = "q quit  Tab pane  Enter open  Left up  a all/active  F5 read"


## Everything the screen knows between two keys. Nothing here is the terminal's.
class ManagerState:
    def __init__(self, workspace=""):
        self.workspace = workspace
        self.clock = ""
        ## the levels dived into, the root first: empty is the root
        self.path = []
        ## the selection of each level: level key -> {"key", "index", "top"}
        self.cursors = {}
        ## which pane the keys move in: "list" on the right, "view" on the left
        self.focus = "list"
        self.activeOnly = False
        ## the rows the last good read of each level gave: level key -> rows
        self.rows = {}
        ## the left pane: which item it shows, its lines, the first line in view (newView)
        self.view = newView(None, False)
        ## whether the left pane of a session or an agent shows the raw log in place of the feed
        self.rawLog = False
        ## the bottom line while something is typed: {"prompt", "text", "onSubmit", "lines"}
        self.dialog = None
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
    MARKS["separator"] = "|"
    MARKS["cut"] = "+"
    MARKS["plain"] = True


## A text for a terminal that is not UTF-8: what it cannot show becomes `?`, cell for cell.
def plainText(text):
    return "".join(cell[0] if all(ord(character) < 128 for character in cell[0]) else "?" * cell[1]
                   for cell in textCells(text))


## ---- the layout ----

## Where everything stands at that size, or None where the terminal is too small. The list
## takes three tenths of the width, between a quarter and a third; one column parts the
## panes. The first and the last line are the status lines, the second holds the titles,
## and the last line of the left pane is the line to type in.
def layoutOf(columns, lines):
    if columns < MIN_COLUMNS or lines < MIN_LINES:
        return None
    listWidth = columns * 3 // 10
    viewWidth = columns - listWidth - 1
    return {
        "columns": columns,
        "lines": lines,
        "viewWidth": viewWidth,
        "separator": viewWidth,
        "listLeft": viewWidth + 1,
        "listWidth": listWidth,
        "topLine": 0,
        "titleLine": 1,
        "bodyTop": 2,
        "viewHeight": lines - 4,
        "listHeight": lines - 3,
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
    if state.activeOnly and levelKey(path) == "sessions":
        ## the filter shows what --active keeps, the running ones, also of an answer read without it
        listed = [row for row in listed if not row.get("session") or row["session"]["state"] == "running"]
    rows.extend(listed)
    return rows


def levelRows(state):
    return levelRowsAt(state, state.path)


## The one place where what a list operation printed becomes rows, by level: the entry of
## the read names the form under "rows". "sessions": the sessions, and a level for each
## with its runs. "pending": the asks. "routines": the routines to start by hand.
## "members": the team members. "digest": the subjects of the settings, each with its
## lines. No name: the stand-in below.
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

## Which item the left pane shows: the level and the row selected there.
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
            "info": None, "feed": None, "lineKeys": [], "built": None}


## The left pane follows the selection: another item is shown from its first line, and
## nothing of the item before is left. What the pane shows from a list read already made
## (localView, viewHead) is set out again each time, so it follows that read too.
def followSelection(state):
    viewKey = viewKeyOf(state)
    row = selectedRow(state)
    if viewKey != state.view["key"]:
        ## the raw log is asked for of the item that is selected: another item shows its feed
        state.rawLog = False
        state.view = newView(viewKey, viewReadOf(state, row, "feed") is not None)
        ## a pane that is made new holds nothing of its item: its reads are due again,
        ## whenever they were last made
        for part in ("view", "feed"):
            state.started.pop("%s:%s" % (part, viewKey), None)
        ## what an action answered stands on the item it was asked on, and goes with it
        if state.answer is not None and state.answer["key"] != viewKey:
            state.answer = None
    local = localView(state, row)
    if local is not None:
        state.view["lines"] = local
    state.view["head"] = viewHead(state, row)
    if state.view["feed"] is not None and state.view["built"] != (state.viewWidth, state.rawLog):
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
## digest holds. None: the pane has no such content, and shows what its own read gives.
def localView(state, row):
    if row is None:
        return None
    level = levelPattern(state.path)
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
    return None


## The keys that act on the selected row, as the left pane names them under the item: the
## actions ITEM_ACTIONS gives its level and kind, and ahead of them Enter where it starts
## something there (ENTER_ACTIONS), each once its handler is built and while it acts on
## the row as it is now.
def itemKeysText(state):
    row = selectedRow(state)
    if row is None:
        return ""
    place = levelPattern(state.path) + ":" + row["kind"]
    actions = ITEM_ACTIONS.get(place, ())
    keys = ["%s %s" % (key, actionName) for key, actionName in ACTION_KEYS
            if actionName in actions and actionShown(state, row, actionName)]
    if place in ENTER_ACTIONS and actionShown(state, row, ENTER_ACTIONS[place]):
        keys.insert(0, "Enter start")
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
    said = dialogSays(state, layout["viewWidth"], layout["viewHeight"])
    if said:
        return layout["viewHeight"] - len(said)
    return layout["viewHeight"] - (1 if itemKeysText(state) else 0)


## How many of those lines scroll: what the head of the pane leaves.
def viewScrollHeight(state, layout):
    return max(0, viewContentHeight(state, layout) - len(state.view["head"]))


## The head of the left pane of a session or of an agent, which does not scroll: its facts
## from the row of the list, with what the read of that one item adds once it has come,
## and last where the lines under it come from. It takes half of the pane at most. What
## an action answered on the selected item stands first, on any row (answerLines).
def viewHead(state, row):
    if row is None:
        return []
    level = levelPattern(state.path)
    limit = max(4, state.viewHeight // 2) - 1
    told = answerLines(state, limit)
    own = max(1, limit - len(told))
    if level == "sessions" and row.get("session"):
        lines = told + sessionLines(row["session"], state.viewWidth, state.view["info"], own)
    elif level == "sessions/*" and row.get("run"):
        lines = told + runLines(row["run"], state.viewWidth, state.view["info"], own)
    else:
        return told
    if viewReadOf(state, row, "feed") is not None:
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
## waiting, the asks that wait and the load average of the host, each as it is printed.
COUNTER_NAMES = ("running", "paused", "working", "waiting", "pending", "load")


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
## they show here, under their own names. Viewing only: no key answers an ask.
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
    lines.append("viewing only: an ask is answered where it was posted")
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
def parseSessionLevels(text):
    levels = {"sessions": []}
    sessions = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "session" and len(fields) >= 8:
            session = {"id": fields[1], "name": unspaced(fields[2]), "state": fields[3], "started": fields[4],
                       "stateAt": fields[5], "count": fields[6], "tally": fields[7], "runs": [], "lone": False}
            row = newRow(fields[1], session["name"] or fields[1], "record", True, fields)
            row["session"] = session
            row["tail"] = session["state"]
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
        ("started", registryDate(session["started"])),
        ("ended", registryDate(session["stateAt"])),
        ("agents", "%s: %s" % (session["count"], tally) if tally else session["count"]),
    ]
    more = [("session", session["id"])]
    dispatch = info["dispatch"] if info else None
    if dispatch:
        if dispatch["founder"] == "no-record":
            pairs.append(("founded", "by a client, whose founder left no record"))
        else:
            pairs.append(("for", cutToCells(" ".join(dispatch["description"].split()), 2 * max(10, width - 11)).rstrip()))
            pairs.append(("founded", ", ".join(word for word in (
                "by " + dispatch["member"] if dispatch["member"] else "",
                "routine " + dispatch["routine"] if dispatch["routine"] else "",
                "item " + dispatch["item"] if dispatch["item"] else "") if word)))
        more.append(("threads", ", ".join(word for word in (
            "session " + dispatch["sessionThread"] if dispatch["sessionThread"] else "",
            "tracking " + dispatch["trackingThread"] if dispatch["trackingThread"] else "") if word)))
    runs = info["runs"] if info and info["runs"] else session["runs"]
    facts = fieldLines(pairs, width)
    extra = fieldLines(more, width)
    if limit and len(lines) + len(facts) + len(extra) + 1 + len(runs) > limit:
        extra = []
    lines.extend(facts + extra)
    if limit and len(lines) >= limit:
        return lines[:limit]
    lines.append("")
    room = limit - len(lines) if limit else len(runs)
    shown = runs
    if len(runs) > room:
        order = [run for run in runs if run["live"] == "running"] + [run for run in reversed(runs) if run["live"] != "running"]
        kept = order[:max(0, room - 1)]
        shown = [run for run in runs if run in kept]
    for run in shown:
        when = "since " + unspaced(run["started"]) if run["resolved"] == "-" else "until " + unspaced(run["resolved"])
        lines.append("%-18s %-16s %s" % (run["member"], runStateText(run), when))
    if len(shown) < len(runs):
        lines.append("and %d more: Enter lists them all" % (len(runs) - len(shown)))
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
STORE_NAMES = ("store", "model", "in", "cacheRead", "cacheWrite", "out", "asks", "marks",
               "milestoneAt", "milestone", "waits", "dismissedBy", "log", "transcript")


def parseSessionRead(text):
    info = {"dispatch": None, "runs": [], "bySpawn": {}}
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] == "dispatch" and len(fields) >= 9:
            info["dispatch"] = {"founder": fields[2], "member": unspaced(fields[3]), "routine": unspaced(fields[4]),
                                "item": unspaced(fields[5]), "sessionThread": unspaced(fields[6]),
                                "trackingThread": unspaced(fields[7]), "description": unescaped(fields[8])}
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
    what = "the raw log" if state.rawLog else "the feed"
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
            return "the raw log, its session log" if state.rawLog else "its session log: this run has no transcript"
        return "none: this run has no session log" if state.rawLog else "none: this run has neither a transcript nor a session log"
    told = []
    if kinds.get("transcript"):
        told.append("%d from a transcript" % len(kinds["transcript"]))
    if kinds.get("session-log") and not state.rawLog:
        told.append("%d from a session log, having no transcript (%s)" % (len(kinds["session-log"]), ", ".join(kinds["session-log"])))
    if kinds.get("none"):
        told.append("%d with %s (%s)" % (len(kinds["none"]), "no session log" if state.rawLog else "neither", ", ".join(kinds["none"])))
    return "%s of %d run%s%s" % ("the raw logs" if state.rawLog else "the feed", len(feed["sources"]),
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
def buildFeed(state, row):
    view = state.view
    held = view["lineKeys"][view["top"]] if not view["follow"] and view["top"] < len(view["lineKeys"]) else None
    view["lines"], view["lineKeys"] = feedLines(view["feed"], state.viewWidth, bool(row and row.get("session")))
    view["built"] = (state.viewWidth, state.rawLog)
    if held is not None:
        places = [position for position, key in enumerate(view["lineKeys"]) if key == held]
        if places:
            view["top"] = min(places, key=lambda position: abs(position - view["top"]))


## `l`: the left pane of a session or of an agent shows its feed, or the raw log of its
## run, of every run for a session. What it showed is taken away, and the other is read.
def switchLog(state, row):
    if row is None or viewReadOf(state, row, "feed") is None:
        return "l: this item has no feed and no log"
    state.rawLog = not state.rawLog
    view = state.view
    view["feed"], view["lines"], view["lineKeys"], view["top"], view["follow"] = None, [], [], 0, True
    readNow(state)
    return ""


ACTION_HANDLERS["log"] = switchLog


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


## What `--manager-routine-list` printed, as rows: `routine` rows of TAB-separated fields,
## in the order they come, by owner and then by selector. A routine shows by its selector
## without `.routine.md`. One the session spawner would not start with no member named
## shows plainer: dimmed, with what the operation says of it, `not-startable` or `broken`,
## at the end of its row. Why stands in the left pane, and Enter does not start it. The id
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
        row = newRow(fields[2] + "/" + fields[1], label, "record", False, fields)
        row["routine"] = routine
        if routine["start"] != "startable":
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
         else "%s: Enter does not start it" % routine["start"]),
        ("name", "%s, the name its session takes unless another is typed" % routine["name"] if startable else ""),
        ("why", "" if startable else routine["reason"]),
    ], width)


## The free prompt for the left pane: what a line typed there starts.
def freePromptLines(width):
    lines = []
    for text in ("A line typed here starts a new coworking session, opened by the coordinator, with that line as its brief.",
                 "Enter opens the line to type in. An empty line starts nothing."):
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
def openDialog(state, prompt, onSubmit, text="", lines=None):
    state.dialog = {"prompt": prompt, "text": text, "onSubmit": onSubmit, "lines": list(lines or ())}


## What the open line says above itself, as lines of the left pane: a line longer than the
## pane is broken, and there are no more of them than the pane has lines. Empty with no
## line open, and for a line that says nothing of itself.
def dialogSays(state, width, height):
    if state.dialog is None or not state.dialog.get("lines"):
        return []
    lines = []
    for text in state.dialog["lines"]:
        if textWidth(text) <= width - 1:
            lines.append(text)
        else:
            lines.extend(wrapToCells(text, max(10, width - 1)))
    return lines[:max(0, height)]


def dialogKey(state, key):
    dialog = state.dialog
    if key == "ESC":
        state.dialog = None
        state.notice = ""
        state.noticeOf = None
    elif key == "ENTER":
        state.dialog = None
        state.notice = dialog["onSubmit"](state, dialog["text"]) or ""
        state.noticeOf = None
    elif key == "BACKSPACE":
        dialog["text"] = dialog["text"][:-1]
    elif len(key) == 1:
        ## a key that has a name is longer than one character: this one was typed
        dialog["text"] += key


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


## Whether `k` has anything to end at that row: a session or an agent with a live run.
def killFits(state, row):
    target = killTargetOf(state, row)
    return target is not None and bool(target["runs"])


## What the confirmation of a kill says above its line, exactly: what is ended, by which
## id, and how.
def killSays(target):
    if target["kind"] == "session":
        alive = target["runs"]
        rest = len(target["session"]["runs"]) - len(alive)
        lines = ["KILL the session %s" % target["label"],
                 "session %s" % target["id"],
                 "%s the hard way: no closure runs, none is asked anything." % (
                     "Its 1 live agent ends" if len(alive) == 1 else "Its %d live agents end" % len(alive))]
        lines.extend("  %-18s %-16s %s" % (run["member"], runStateText(run), unspaced(run["spawn"])) for run in alive[:6])
        if len(alive) > 6:
            lines.append("  and %d more" % (len(alive) - 6))
        if rest:
            lines.append("1 other agent is not alive on this host: it is left as it is." if rest == 1
                         else "%d other agents are not alive on this host: they are left as they are." % rest)
    else:
        run = target["run"]
        lines = ["KILL the agent %s alone" % target["label"],
                 "run %s, %s" % (target["id"], runStateText(run)),
                 "of the session %s" % target["sessionLabel"]
                 + (" (%s)" % run["session"] if target["sessionLabel"] != run["session"] else ""),
                 "It ends the hard way: no closure runs, it is asked nothing. The others run on."]
        if run["spawn"] == run["session"]:
            lines.append("It is the founder: its id is its session's. It alone is ended, not the session.")
    lines.append("Type %s and Enter to kill. Esc, or anything else, kills nothing." % KILL_WORD)
    return lines


## `k`: asks for the confirmation of the kill of the selected session or agent, in the
## line to type in, and says above it exactly what will be killed. A row that is no
## session and no agent, and one with no live run, says that there is nothing to kill,
## and nothing is asked.
def askKill(state, row):
    target = killTargetOf(state, row)
    if target is None:
        return "k: nothing to kill here: k kills a session or an agent"
    if not target["runs"]:
        return "k: nothing to kill: %s" % ("no agent of this session is alive" if target["kind"] == "session"
                                           else "this agent is not alive")
    if target["kind"] == "session":
        prompt = "kill the session, %d agent%s? type %s:" % (
            len(target["runs"]), "" if len(target["runs"]) == 1 else "s", KILL_WORD)
    else:
        prompt = "kill the agent %s? type %s:" % (target["label"], KILL_WORD)
    state.answer = None
    ## the answer belongs to the item the key was pressed on, whatever is selected when it comes
    target["viewKey"] = viewKeyOf(state)
    openDialog(state, prompt, lambda dialogState, text: submitKill(dialogState, target, text), "", killSays(target))
    return ""


## The confirmation of a kill was typed. Exactly the word kills: the operation is called
## once, with the id of what the line named. Anything else kills nothing.
def submitKill(state, target, text):
    if text != KILL_WORD:
        return "nothing was killed: the word typed was not %s" % KILL_WORD
    askCall(state, "kill", target["id"], callWords("kill:" + target["kind"], target["id"]), None,
            {"viewKey": target["viewKey"]})
    return "kill asked of the tooling: the %s %s" % ("session" if target["kind"] == "session" else "agent", target["label"])


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
}


## What `--manager-session-kill` printed: one `kill` row for each run the id names, with
## what happened to it. Given back: a line for each run, for the left pane, and how many
## runs had each outcome, for the bottom line.
def killAnswer(text):
    lines = []
    counts = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "kill" or len(fields) < 8:
            continue
        words, counted = KILL_OUTCOMES.get(fields[4], (fields[4], fields[4]))
        lines.append("  %-18s %s" % (fields[3], words))
        for count in counts:
            if count[0] == counted:
                count[1] += 1
                break
        else:
            counts.append([counted, 1])
    return lines, ", ".join("%d %s" % (count, counted) for counted, count in counts)


## Enter on a routine of `Launch / Spawn`. One the session spawner would not start says
## why, and nothing is asked. For another the line to type in opens with the name the
## session takes from its routine, to be typed over: Enter there starts the routine, and
## Esc starts nothing.
def askLaunch(state, row):
    routine = row.get("routine") if row else None
    if routine is None:
        return ""
    if routine["start"] != "startable":
        return "not started: %s is %s: %s" % (routine["selector"], routine["start"], routine["reason"] or "the operation says no more")
    state.answer = None
    shownOn = viewKeyOf(state)
    openDialog(state, "name:", lambda dialogState, text: submitLaunch(dialogState, routine, text, shownOn), routine["name"], [
        "START the routine %s" % routine["selector"],
        "It runs as its executors, whoever is at the console: %s" % routine["executors"],
        "The line below is the name of its session: type over it, or leave it.",
        "With no name the session shows by its id. Enter starts it. Esc starts nothing.",
    ])
    return ""


## Whether Enter starts the routine of that row: one the session spawner would start.
def launchFits(state, row):
    return bool(row and row.get("routine") and row["routine"]["start"] == "startable")


## The name of the session was left or typed: the routine is started through the
## operation, once, by its selector, under that name, or under none where it was emptied.
def submitLaunch(state, routine, text, shownOn):
    name = text.strip()
    askCall(state, "launch", routine["selector"], callWords("launch", routine["selector"], name), None,
            {"name": name, "viewKey": shownOn})
    return "start asked of the tooling: %s, %s" % (routine["selector"], "named " + name if name else "with no name")


## Enter on the free prompt of `Launch / Spawn`: the line to type in opens for one line of
## text, the brief of a new coworking session the coordinator opens.
def askPrompt(state, row):
    state.answer = None
    shownOn = viewKeyOf(state)
    openDialog(state, "prompt:", lambda dialogState, text: submitPromptLine(dialogState, text, shownOn), "", [
        "FREE PROMPT: a new coworking session, opened by the coordinator",
        "The line typed below is its brief, given to the operation on its standard input.",
        "Enter goes on to the name of the session. Esc starts nothing.",
    ])
    return ""


## The line of a free prompt was typed. An empty one is refused here, since the operation
## would start a session on its brief block alone. Else the line opens again, for the name
## of the session, which may be left empty.
def submitPromptLine(state, text, shownOn):
    if not text.strip():
        return "nothing was started: the line was empty"
    openDialog(state, "name:", lambda dialogState, name: submitPrompt(dialogState, text, name, shownOn), "", [
        "FREE PROMPT: %s" % text,
        "The line below is the name of its session, or none: it then shows by its id.",
        "Enter starts it. Esc starts nothing.",
    ])
    return ""


## The name of the session of a free prompt was typed, or left empty: the session is
## started through the operation, once, with the line as its task text on standard input.
def submitPrompt(state, line, text, shownOn):
    name = text.strip()
    askCall(state, "prompt", "free", callWords("prompt", "", name), line + "\n", {"name": name, "viewKey": shownOn})
    return "start asked of the tooling: a free prompt, %s" % ("named " + name if name else "with no name")


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
## line of it stands in the bottom line; and what is shown is read again, the list of the
## sessions with it. A call that failed shows its error line in both places, in the pane
## after the rows it printed.
def applyCall(state, result):
    about = state.asked.pop(result["key"], None) or {"action": "", "viewKey": None}
    if about["action"] == "kill":
        what = "the kill"
        lines, summary = killAnswer(result["text"])
        summary = "kill: " + (summary or "the operation named no run")
    elif about["action"] == "start":
        what = "the start"
        lines, summary = spawnAnswer(result["text"], state.viewWidth)
    else:
        what = "the start"
        lines, summary = startAnswer(result["text"], about.get("name", ""), state.viewWidth)
    if result["status"] != 0:
        what += " failed"
        operation = result["words"][0] if result["words"] else ""
        summary = result["error"] if operation.lstrip("-") in result["error"] else "%s: %s" % (operation, result["error"])
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
ACTION_HANDLERS["launch"] = askLaunch
ACTION_HANDLERS["prompt"] = askPrompt
ACTION_FITS["kill"] = killFits
ACTION_FITS["launch"] = launchFits


## ---- the team members: `Team Members` ----

## Why a member is not started from here, in words, or nothing where it can be: one whose
## status says that nobody is started as it, and one whose workspace cannot be reached.
def memberRefusal(member):
    if member["status"] == "reference-only":
        return "its status is reference-only: nobody is started as this member"
    if member["setUp"] == "not-present":
        return "its workspace cannot be reached from this machine"
    return ""


## What `--manager-team-member-list` printed, as rows: `member` rows of TAB-separated
## fields, in the order they come, this workspace's own members first. A member shows by
## its name. One with a live run stands out, with `running` at the end of its row. One
## that is not started from here shows plainer: dimmed, with its status, `reference-only`,
## or where it is set up, `not-present`, at the end of its row.
def parseMemberRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] != "member" or len(fields) < 11:
            continue
        member = {"name": fields[1], "mark": unspaced(fields[2]), "first": unspaced(fields[3]),
                  "family": unspaced(fields[4]), "alias": unspaced(fields[5]), "kind": absent(fields[6]),
                  "workspace": absent(fields[7]), "setUp": fields[8], "status": absent(fields[9]), "live": fields[10]}
        row = newRow(fields[1], fields[1], "record", False, fields)
        row["member"] = member
        if member["live"] == "running":
            row["tail"] = "running"
            row["look"] = BOLD
        if memberRefusal(member):
            row["tail"] = member["status"] if member["status"] == "reference-only" else member["setUp"]
            row["look"] = DIM
        rows.append(row)
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


## `n`: starts the selected team member with a prompt. A row that is no member says that
## there is nothing to start, and a member that is not started says why; nothing is asked.
## Else the line to type in opens for one line of text, the member's prompt.
def askStart(state, row):
    member = row.get("member") if row else None
    if member is None:
        return "n: nothing to start here: n starts a team member with a prompt"
    refusal = memberRefusal(member)
    if refusal:
        return "n: %s is not started: %s" % (member["name"], refusal)
    state.answer = None
    shownOn = viewKeyOf(state)
    openDialog(state, "prompt:", lambda dialogState, text: submitStartLine(dialogState, member, text, shownOn), "", [
        "START the member %s with a prompt, in a new session of its own" % member["name"],
        "It runs as that member, whoever is at the console.",
        "The line typed below is its prompt, given to the operation on its standard input.",
        "No secret belongs in it: a brief shows on the command line of the CLI.",
        "Enter goes on to the name of the session. Esc starts nothing.",
    ])
    return ""


## The prompt of a member's start was typed. An empty one is refused here, as the
## operation refuses it. Else the line opens again, for the name of the session, which may
## be left empty.
def submitStartLine(state, member, text, shownOn):
    if not text.strip():
        return "nothing was started: the line was empty"
    openDialog(state, "name:", lambda dialogState, name: submitStart(dialogState, member, text, name, shownOn), "", [
        "START %s: %s" % (member["name"], text),
        "The line below is the name of its session, or none: it then shows by its id.",
        "Enter starts it. Esc starts nothing.",
    ])
    return ""


## The name of the session was typed, or left empty: the member is started through the
## operation, once, by its name, with the line as its prompt on standard input.
def submitStart(state, member, line, text, shownOn):
    name = text.strip()
    askCall(state, "start", member["name"], callWords("start", member["name"], name), line + "\n",
            {"viewKey": shownOn})
    return "start asked of the tooling: the member %s, %s" % (member["name"], "named " + name if name else "with no name")


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


## ---- the settings: `Settings / Configuration` ----

## What each subject of the digest holds, in words, for the head of its pane. A subject
## that is not listed here shows by its name alone.
SUBJECT_WORDS = {
    "workspace": "the paths of this workspace, and the places it knows",
    "cli": "the CLI service the workspace asks for, and each CLI the console knows",
    "systems": "each outside system, by the scopes that hold a setting of it",
    "loop": "the main loop and the heartbeat, as they last left their state",
    "scopes": "each scope that holds a key, with its keys",
}
## The states of a line that say that something is not there.
STATES_MISSING = ("missing", "secret-missing")


## What `--manager-config-digest` printed, as rows: a `subject` row for each subject, in
## the order of the operation, followed by its `line` rows, which the row of the subject
## keeps. A subject shows by its name, as the operation takes it, and with how many of
## its lines are missing at the end of its row.
def parseDigestRows(text):
    rows = []
    bySubject = {}
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "subject" and len(fields) >= 3:
            row = newRow(fields[1], fields[1], "record", False, fields)
            row["subject"] = {"name": fields[1], "lines": []}
            bySubject[fields[1]] = row
            rows.append(row)
        elif fields[0] == "line" and len(fields) >= 6 and fields[1] in bySubject:
            bySubject[fields[1]]["subject"]["lines"].append({"group": absent(fields[2]), "key": absent(fields[3]),
                                                             "state": fields[4], "value": absent(fields[5])})
    for row in rows:
        missing = len([line for line in row["subject"]["lines"] if line["state"] in STATES_MISSING])
        if missing:
            row["tail"] = "%d missing" % missing
    return rows


## What one line of the digest reads as. A secret reads only as configured or not: the
## value of its row is never looked at. A scope of an outside system reads as set, with
## the keys it lacks, or as missing them; a CLI is usable or not; any other line by its
## value, a missing one marked as that.
def digestWords(subjectName, line):
    value = line["value"]
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
## its own: the mark of a missing one, the key, and what it reads as. Viewing only.
def subjectLines(subject, width):
    words = SUBJECT_WORDS.get(subject["name"], "")
    missing = len([line for line in subject["lines"] if line["state"] in STATES_MISSING])
    lines = wrapToCells(subject["name"] + (": " + words if words else ""), max(10, width - 1))
    lines.append("%d line%s%s" % (len(subject["lines"]), "" if len(subject["lines"]) == 1 else "s",
                                 ", %d missing, each marked %s" % (missing, MARK_MISSING) if missing else ""))
    groups = []
    for line in subject["lines"]:
        if not groups or groups[-1][0] != line["group"]:
            groups.append((line["group"], []))
        groups[-1][1].append(line)
    for group, groupLines in groups:
        lines.extend(["", group or "-"])
        keyWidth = min(34, max(textWidth(line["key"] or "-") for line in groupLines))
        for line in groupLines:
            key = line["key"] or ("no scope" if subject["name"] == "systems" else "-")
            lines.extend(hangLines("%s %s  %s" % (
                MARK_MISSING if line["state"] in STATES_MISSING else " ",
                key + " " * max(0, keyWidth - textWidth(key)), digestWords(subject["name"], line)), width))
    return lines


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
            "Viewing only: no key changes a setting here."]


## ---- what a key does ----

## One key, on the state alone. With a line open the key goes to that line. Otherwise:
## the keys of the screen, the keys that act on what is selected, then the keys of the
## pane that has the focus.
def handleKey(state, key, layout):
    if key is None or key == "RESIZE":
        return
    if layout is None:
        if key == "q":
            state.quit = True
        return
    if state.dialog is not None:
        dialogKey(state, key)
        return
    if key == "q":
        state.quit = True
    elif key == "TAB":
        state.focus = "view" if state.focus == "list" else "list"
    elif key == "ESC":
        return
    elif key == KEY_READ_NOW:
        readNow(state)
    elif key in dict(ACTION_KEYS):
        actionKey(state, key)
    elif state.focus == "list":
        listKey(state, key, layout["listHeight"])
    else:
        viewKey(state, key, viewScrollHeight(state, layout))


def listKey(state, key, height):
    if key == "UP":
        moveSelection(state, height, -1)
    elif key == "DOWN":
        moveSelection(state, height, 1)
    elif key == "PGUP":
        moveSelection(state, height, 0, -1)
    elif key == "PGDN":
        moveSelection(state, height, 0, 1)
    elif key == "ENTER" and enterActionOf(state) is not None:
        state.noticeOf = None
        state.notice = ACTION_HANDLERS[enterActionOf(state)](state, selectedRow(state)) or ""
    elif key in ("ENTER", "RIGHT"):
        diveIn(state, height)
    elif key == "LEFT":
        goUp(state)
    elif key == "a":
        state.activeOnly = not state.activeOnly
        readNow(state)


def viewKey(state, key, height):
    if key == "UP":
        scrollView(state, height, -1)
    elif key == "DOWN":
        scrollView(state, height, 1)
    elif key == "PGUP":
        scrollView(state, height, 0, -1)
    elif key == "PGDN":
        scrollView(state, height, 0, 1)


## The key of an action goes to the handler of that action, with the row that is selected.
def actionKey(state, key):
    actionName = dict(ACTION_KEYS)[key]
    handler = ACTION_HANDLERS.get(actionName)
    state.noticeOf = None
    if handler is None:
        state.notice = "%s: %s is not built yet" % (key, actionName)
        return
    state.notice = handler(state, selectedRow(state)) or ""


## The action Enter starts on the selected row, where its level and its kind have one whose
## handler is built, or None: Enter then dives in.
def enterActionOf(state):
    row = selectedRow(state)
    if row is None:
        return None
    actionName = ENTER_ACTIONS.get(levelPattern(state.path) + ":" + row["kind"])
    return actionName if ACTION_HANDLERS.get(actionName) is not None else None


## ---- reading through operations ----

## The words of one read: its operation, what the filter adds, what `l` adds, and the ids
## in their places. The filter is the list's own: the read that fills the level of one
## session is made without it, so that session stays in what is read whatever its state.
def readWords(entry, state, values, filtered=True):
    words = list(entry["operation"])
    if state.activeOnly and filtered:
        words.extend(entry.get("active", ()))
    if state.rawLog:
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


## What the screen as it stands asks the tooling for: (kind, key, words) for the list of
## the level shown, for every list that is read whatever is shown, and for the view of the
## row selected, each where READS names an operation.
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
    row = selectedRow(state)
    for part in ("view", "feed"):
        entry = viewReadOf(state, row, part)
        if entry:
            values["id"] = row["id"]
            wanted.append((part, part + ":" + viewKeyOf(state), readWords(entry, state, values)))
    return wanted


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
def restLeft(state, now):
    selected = viewKeyOf(state)
    if selected != state.restKey:
        state.restKey = selected
        state.restSince = now
    row = selectedRow(state)
    if viewReadOf(state, row, "view") is None and viewReadOf(state, row, "feed") is None:
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
        if reader.busy(kind) or (resting and kind in ("view", "feed")):
            continue
        last = state.started.get(key)
        due = key in state.forced or last is None or last["words"] != words or now - last["at"] >= REFRESH_SECONDS
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


## One call that has ended, taken into the state. A good list becomes the rows of its
## level. A failed call leaves what the last good one gave, marks it as old, and its error
## line is shown. An answer for a view that is no longer selected is dropped, and so is one
## asked with other words than are wanted now, which is then asked again. The answer of
## an action goes to applyCall.
def applyResult(state, result):
    key = result["key"]
    if key.startswith("action:"):
        applyCall(state, result)
        return
    wantedNow = dict((wantedKey, words) for kind, wantedKey, words in wantedReads(state))
    if key.startswith(("view:", "feed:")) and key not in wantedNow:
        return
    if key in wantedNow and wantedNow[key] != result["words"]:
        state.forced.add(key)
        return
    if result["status"] != 0:
        state.failed[key] = result["error"]
        operation = result["words"][0] if result["words"] else ""
        state.notice = result["error"] if operation in result["error"] else "%s: %s" % (operation, result["error"])
        state.noticeOf = key
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
        state.counters.update(readCounters(entry.get("rows"), result["text"]))
    else:
        row = selectedRow(state)
        entry = viewReadOf(state, row, key[:4]) or {}
        if entry.get("rows") == "session-read":
            state.view["info"] = parseSessionRead(result["text"])
        elif entry.get("rows") == "ask":
            state.view["info"] = parseAskStored(result["text"])
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
                               "text": "", "error": "could not be started: %s" % failure})
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
                            "text": outputText,
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


def viewTitle(state):
    row = selectedRow(state)
    if row is None:
        return ""
    marks = readMarks(state, "view:" + (viewKeyOf(state) or "")) + readMarks(state, "feed:" + (viewKeyOf(state) or ""))
    marks = "".join(mark for mark in (MARK_READING, MARK_OLD) if mark in marks)
    return (marks + " " if marks else "") + row["label"]


## The top status line: the workspace by the name of its folder, the load average of the
## host as the row of counters gives it, marked as old where that read last failed, and
## the clock.
def topLineText(state, columns):
    right = state.clock + " "
    if "load" in state.counters:
        right = "load %s%s  %s" % (state.counters["load"], " " + MARK_OLD if "list:sessions" in state.failed else "", right)
    rightWidth = textWidth(right)
    if rightWidth >= columns:
        return cutToCells(right, columns)
    return cutToCells(" " + os.path.basename(state.workspace.rstrip("/")), columns - rightWidth) + right


## The counters of the bottom status line, from the row of counters: the sessions running
## and paused, the agents working and waiting, the asks that wait. Empty until that row
## was read; marked as old where its read last failed.
def countersText(state):
    if "running" not in state.counters:
        return ""
    text = "  ".join("%s %s" % (name, state.counters.get(name, "-")) for name in COUNTER_NAMES[:5])
    return text + (" " + MARK_OLD if "list:sessions" in state.failed else "")


## One row of the list in exactly that many cells: the mark of the selection, what the row
## shows as, and at the end of the line what the row carries as its tail, its state.
def listRowText(row, chosen, width):
    head = (MARK_SELECTED if chosen else " ") + row["label"]
    tail = row.get("tail", "")
    tailWidth = textWidth(tail)
    if not tail or tailWidth + 4 > width:
        return cutToCells(head, width)
    return cutToCells(head, width - tailWidth - 1) + " " + cutToCells(tail, tailWidth)


def bottomLineText(state, columns):
    counters = countersText(state)
    return cutToCells(" " + (counters + "  " if counters else "") + HINTS, columns)


## The whole screen, drawn again from the state: every cell of every line, so nothing of
## an earlier drawing or of an earlier size is left.
def drawScreen(surface, state):
    columns, lines = surface.size()
    layout = layoutOf(columns, lines)
    surface.clear()
    surface.cursor(None, None)
    if layout is None:
        if columns > 0 and lines > 0:
            surface.put(0, 0, cutToCells("Too small: %dx%d (needs %dx%d)" % (columns, lines, MIN_COLUMNS, MIN_LINES), columns), PLAIN)
        surface.show()
        return
    viewWidth = layout["viewWidth"]
    listLeft = layout["listLeft"]
    listWidth = layout["listWidth"]
    surface.put(layout["topLine"], 0, topLineText(state, columns), REVERSE)
    surface.put(layout["titleLine"], 0, cutToCells(" " + viewTitle(state), viewWidth),
                REVERSE if state.focus == "view" else BOLD)
    surface.put(layout["titleLine"], listLeft, cutToCells(" " + listTitle(state), listWidth),
                REVERSE if state.focus == "list" else BOLD)
    for line in range(layout["titleLine"], layout["inputLine"] + 1):
        surface.put(line, layout["separator"], MARKS["separator"], PLAIN)
    rows = levelRows(state)
    cursor = cursorOf(state, rows, layout["listHeight"])
    for offset in range(layout["listHeight"]):
        position = cursor["top"] + offset
        text = " " * listWidth
        look = PLAIN
        if position < len(rows):
            chosen = position == cursor["index"]
            text = listRowText(rows[position], chosen, listWidth)
            look = rows[position].get("look", PLAIN)
            if chosen:
                look = REVERSE if state.focus == "list" else BOLD
        surface.put(layout["bodyTop"] + offset, listLeft, text, look)
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
    said = dialogSays(state, viewWidth, layout["viewHeight"])
    for offset, text in enumerate(said):
        surface.put(layout["bodyTop"] + contentHeight + offset, 0, cutToCells(" " + text, viewWidth), BOLD if offset == 0 else PLAIN)
    if not said and contentHeight < layout["viewHeight"]:
        surface.put(layout["bodyTop"] + contentHeight, 0, cutToCells(" " + itemKeysText(state), viewWidth), BOLD)
    if state.dialog is not None:
        prompt = " " + state.dialog["prompt"] + " "
        promptWidth = min(textWidth(prompt), max(0, viewWidth - 2))
        typed, typedWidth = tailToCells(state.dialog["text"], viewWidth - promptWidth - 1)
        surface.put(layout["inputLine"], 0, cutToCells(prompt, promptWidth), BOLD)
        surface.put(layout["inputLine"], promptWidth, cutToCells(typed, viewWidth - promptWidth), PLAIN)
        surface.cursor(layout["inputLine"], promptWidth + typedWidth)
    else:
        surface.put(layout["inputLine"], 0, cutToCells(" " + state.notice, viewWidth), PLAIN)
    surface.put(layout["bottomLine"], 0, bottomLineText(state, columns), REVERSE)
    surface.show()


## One turn of the screen: the key that came, if one did; the calls that have ended; the
## actions that were asked for; the reads that are due now; the drawing. `now` is a clock
## that only goes forward.
def screenTurn(surface, state, reader, now, key):
    columns, lines = surface.size()
    layout = layoutOf(columns, lines)
    state.viewWidth = layout["viewWidth"] if layout else 0
    state.viewHeight = layout["viewHeight"] if layout else 0
    state.clock = time.strftime("%H:%M:%S", time.localtime(nowEpoch()))
    handleKey(state, key, layout)
    if reader is not None:
        for result in reader.collect():
            applyResult(state, result)
        startCalls(state, reader)
        startDueReads(state, reader, now)
        state.reading = reader.runningKeys()
    followSelection(state)
    drawScreen(surface, state)


## ---- the terminal ----

## The surface of the real terminal: a curses window. A text is drawn where it is put, and
## whoever puts it has cut it to fit.
class CursesSurface:
    def __init__(self, window):
        self.window = window
        self.looks = {PLAIN: curses.A_NORMAL, BOLD: curses.A_BOLD, REVERSE: curses.A_REVERSE, DIM: curses.A_DIM}
        self.keyNames = {
            curses.KEY_UP: "UP", curses.KEY_DOWN: "DOWN", curses.KEY_LEFT: "LEFT", curses.KEY_RIGHT: "RIGHT",
            curses.KEY_PPAGE: "PGUP", curses.KEY_NPAGE: "PGDN", curses.KEY_ENTER: "ENTER",
            curses.KEY_BACKSPACE: "BACKSPACE", curses.KEY_RESIZE: "RESIZE", curses.KEY_F5: "F5",
        }
        self.charNames = {"\t": "TAB", "\n": "ENTER", "\r": "ENTER", "\x1b": "ESC", "\x7f": "BACKSPACE", "\b": "BACKSPACE"}

    def size(self):
        lines, columns = self.window.getmaxyx()
        return columns, lines

    def clear(self):
        self.window.erase()

    def put(self, line, column, text, look):
        if MARKS["plain"]:
            text = plainText(text)
        try:
            self.window.addstr(line, column, text, self.looks[look])
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

    ## The next key by its name, or None when none came within that time.
    def key(self, seconds):
        self.window.timeout(int(seconds * 1000))
        try:
            got = self.window.get_wch() if hasattr(self.window, "get_wch") else self.window.getch()
        except curses.error:
            return None
        if isinstance(got, int):
            if got in self.keyNames:
                return self.keyNames[got]
            if got < 0 or got > 255:
                return None
            got = chr(got)
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


def main(arguments):
    options = {"--workspace": "", "--tools": ""}
    position = 0
    while position < len(arguments):
        if arguments[position] not in options or position + 1 >= len(arguments):
            sys.stderr.write("%s expects: --workspace <path> --tools <dispatcher>, got: %s\n" % (PREFIX, " ".join(arguments)))
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
    state = ManagerState(options["--workspace"])
    reader = OperationReader([options["--tools"]])
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
