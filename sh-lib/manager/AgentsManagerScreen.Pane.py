##
## AgentsManagerScreen.Pane.py -- the left window: which item it shows, how it follows the selection and scrolls.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the left pane ----

## The level the left window looks at. It is the level shown, with the row selected there;
## but while the selection stands on the row that goes up, or on nothing, inside a
## container, it is the level above, with the row of that container: the left window then
## shows the container itself, as its own row showed it one level up, and the commands
## that act on it apply. One rule for every level: a section at the root, `Launch (Start)`,
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
## gave, and "lineKeys" says which entry of the feed each line belongs to. "looks": what
## of a line is drawn in a look of its own, by the number of the line, each as the cell
## it starts at, how many cells it takes and its look (putViewLine). "left" is its first
## cell in view while its lines are cut and it is scrolled sideways.
def newView(viewKey, feeds):
    return {"key": viewKey, "head": [], "lines": [], "top": 0, "feeds": feeds, "follow": feeds,
            "info": None, "feed": None, "acts": None, "lineKeys": [], "built": None, "looks": {}, "left": 0}


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
    ## the looks of the lines are made with them: those its maker set, and over them those a
    ## line carries (Looked); where no line is made new, those of the lines that stand
    kept = state.view["looks"]
    state.view["looks"] = {}
    ## how many rows a table holds is said again by what makes it (tableCount); where nothing is
    ## made new the pane keeps what it said
    counted = state.view.pop("tableRows", None)
    local = localView(state, row)
    if local is None and counted is not None:
        state.view["tableRows"] = counted
    if local is not None:
        state.view["lines"] = local
        state.view["lineKeys"] = []
        state.view["looks"].update((number, line.looks) for number, line in enumerate(local) if getattr(line, "looks", ()))
    else:
        state.view["looks"] = kept
    state.view["head"] = viewHead(state, row)
    if state.view["feed"] is not None and state.view["built"] != (state.viewWidth, state.viewMode):
        buildFeed(state, row)
    if local is None and state.view.get("text") is not None:
        viewText(state, row)


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


## How wide the widest line of the left pane is, its head counted in, in cells, the blanks
## at the end of a line aside: what a sideways scroll goes by. Counted when what the pane
## holds has changed, not at every drawing.
def viewWide(state):
    view = state.view
    stamp = (len(view["lines"]), sum(len(line) for line in view["lines"]), len(view["head"]), sum(len(line) for line in view["head"]))
    if view.get("wideOf") != stamp:
        view["wideOf"] = stamp
        view["wide"] = max([textWidth(line.rstrip()) for line in view["head"] + view["lines"]] or [0])
    return view["wide"]


## Where the left pane stands sideways in that many cells: its first cell in view, never
## past what its widest line needs, and the first one while its lines are wrapped.
def panOf(state, room):
    view = state.view
    view["left"] = 0 if state.wrap else max(0, min(view.get("left", 0), viewWide(state) - room))
    return view["left"]


## What the left pane shows with no read of its own, from what a list read already holds:
## the summary of a session and of an agent; of a folder, a row that opens a level, what
## it holds, by its declaration (folderSummary); the selected ask; the selected routine of
## `Launch (Start)` and its free prompt; the selected team member; a line of a subject of
## the digest; a check; a server key and a group of them; the selected thing to start; the
## one block of the selected row of the dashboard; the selected location. None: the pane
## has no such content, and shows what its own read gives.
def localView(state, row):
    if row is None:
        return None
    level = levelPattern(state.path)
    if not logShown(state, row):
        ## the summary of a session and of an agent: its facts, and nothing of its log;
        ## one that has no log has its summary alone, whatever the mode
        if level in ("sessions", "team/*/sessions") and row.get("session"):
            return sessionLines(row["session"], state.viewWidth, state.view["info"], wrap=state.wrap)
        if level == "sessions/*" and row.get("run"):
            return runLines(row["run"], state.viewWidth, state.view["info"])
    summary = folderSummary(state, row)
    if summary is not None:
        return summary
    if level == "pending" and row.get("ask"):
        ## set out again only when the ask, what is stored of it, the width or the minute has changed
        stamp = (row["ask"], id(state.view["info"]), state.viewWidth, int(nowEpoch() // 60))
        if state.view.get("askFor") == stamp:
            return None
        state.view["askFor"] = stamp
        return askLines(row["ask"], state.viewWidth, state.view["info"])
    if level == "sessions/launch" and row.get("routine"):
        return routineLines(row["routine"], state.viewWidth)
    if level == "sessions/launch" and row["kind"] == "free":
        return freePromptLines(state.viewWidth)
    if level == "team" and row.get("member"):
        ## set out again only when the member, what was read of it, the width or the minute has changed
        stamp = (row["member"], id(state.view["info"]), state.viewWidth, int(nowEpoch() // 60))
        if state.view.get("memberFor") == stamp:
            return None
        state.view["memberFor"] = stamp
        return memberLines(row["member"], state.viewWidth, state.view["info"])
    if row.get("line"):
        return settingLines(row["line"], state.viewWidth)
    if row.get("lineGroup"):
        tableCount(state, row["lineGroup"]["lines"])
        return groupLines(row["lineGroup"], state.viewWidth, state.wrap, fullPane(state))
    if row.get("check"):
        return checkLines(row["check"], state.viewWidth)
    if row.get("serverKey"):
        return serverKeyLines(state, state.path, row["serverKey"], state.viewWidth)
    if row.get("keyGroup"):
        return keyGroupLines(state, state.path, [row["keyGroup"]], state.viewWidth)
    if level == "consoles" and row.get("start"):
        return startLines(row["start"], state.viewWidth)
    if level in ("dashboard", TEAM_DATA["level"]) and row.get("block"):
        return blocksView(state, row["id"], levelKey(state.path))
    if level == TEAM_DATA["level"] + "/operations" and row["kind"] == "operation":
        return cleanupLines(state, row)
    if level == "places" and row.get("place"):
        return placeLines(state, row["place"], state.viewWidth, state.view["info"])
    if level == "places/*" and row.get("placeCommand"):
        return placeCommandLines(row["placeCommand"], state.viewWidth)
    if row.get("grant"):
        return grantLines(row["grant"], state.viewWidth)
    if row.get("grantKind"):
        return grantKindLines(state, row, state.viewWidth)
    if row.get("file") and not row["text"]:
        return ["%s: %s, no text: it is not shown." % (row["id"], shortBytes(row["file"]["bytes"]))]
    if row.get("help"):
        return helpLines(state, row, row["help"])
    if helpShown(state, row) and state.view.get("text") is not None:
        ## the help a read gave of the row, as it is written (a tooling command's), set out as the
        ## help is; a read that gave none says so
        return helpLines(state, row, state.view["text"].expandtabs(4).splitlines()) or ["%s has no help file beside it." % row["label"]]
    return None


## The summary of the folder a row opens, for the left window: what SUMMARIES declares
## for the level that row opens, made from the rows of that level. None where the folder
## has none, and until its rows have come. A folder whose read failed before it gave any
## row says so, with the line that read is shown by. A sentence is broken to the window.
def folderSummary(state, row):
    if not row["dive"] or row["kind"] == "up":
        return None
    path = state.path + [row["id"]]
    form = SUMMARIES.get(levelPattern(path))
    if form is None:
        return None
    lines = globals()[form["lines"]](state, path, row, form)
    opened = listReadOf(path)
    if lines is None and opened and opened[0] in state.failed and opened[0] not in state.levelsOf:
        lines = ["%s could not be read: %s" % (row["label"], state.failed[opened[0]])]
    ## a sentence longer than the window is broken at its words; a line that is set in, of
    ## a table or one that hangs, was set out to the window by whoever made it
    room = max(10, state.viewWidth - 1)
    return lines and [part for line in lines for part in (
        [looked(piece, line.looks[0][2]) if getattr(line, "looks", None) else piece for piece in wrapToCells(line, room)]
        if textWidth(line) > room and not line.startswith(" ") else [line])]


## A table of a summary, set in by two, in lines of that many cells: the table of the left
## pane (paneTable), wrapped while the lines of the pane are (a width short of UNWRAPPED_WIDTH).
def summaryTable(heads, rows, width):
    head, blocks = paneTable(heads, [list(line) for line in rows], max(10, width - 1), wrap=width < UNWRAPPED_WIDTH, indent="  ")
    return head + [line for block in blocks for line in block]


## The level and the kind of a row, as COMMANDS names the rows a command acts on.
def placeOf(state, row):
    return levelPattern(state.path) + ":" + row["kind"] if row is not None else ""


## Whether an action acts on that row: its handler is built, and the action acts on the
## row as it is now. The keys that act on the selected row are the status line's to name:
## the left pane names none of its own.
def actionShown(state, row, actionName):
    if ACTION_HANDLERS.get(actionName) is None:
        return False
    fits = ACTION_FITS.get(actionName)
    return fits is None or bool(fits(state, row))


## How many lines of the left pane its content has: all of them.
def viewContentHeight(state, layout):
    return layout["viewHeight"]


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

