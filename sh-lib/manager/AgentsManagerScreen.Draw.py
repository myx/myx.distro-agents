##
## AgentsManagerScreen.Draw.py -- the drawing: the frame, the list, the left window, the menu bar and the status line.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the drawing ----

## The marks ahead of a title: what is shown is being read, what is shown is old.
def readMarks(state, key):
    marks = ""
    if key in state.reading.values():
        marks += MARK_READING
    if key in state.failed:
        marks += MARK_OLD
    return marks + " " if marks else ""


## The name of the level the list is at, as its title names it, its marks aside.
def levelName(state):
    if not state.path:
        return ROOT_TITLE
    for row in levelRowsAt(state, state.path[:-1]):
        if row["id"] == state.path[-1] and row["kind"] != "up":
            return row["label"]
    return state.path[-1]


## What the list says while it waits for the first rows of its level (POPULATING), or "":
## the read that fills it has not answered yet, and has not failed.
def listWaits(state):
    shown = listReadOf(state.path)
    if not state.reads or not shown or shown[0] in state.levelsOf or shown[0] in state.failed:
        return ""
    if demandWaits(state, shown):
        return ""
    return POPULATING % levelName(state)


## Whether a read waits to be asked for (F11.7: the Config Checker): it is read on demand alone, and nobody asked, so nothing is being populated.
def demandWaits(state, read):
    return bool(read[1].get("demand")) and read[0] not in state.forced and read[0] not in state.reading.values()


## What the left window says while it waits for its first rows (POPULATING), or "": it
## holds no line yet, a read that fills it has not answered, and none of them has failed.
## Its lines come from the read of the selected item, of its log in a mode that shows
## one, or from the list of the level the row opens, which its summary is made of.
@onShownLevel
def viewWaits(state):
    row = selectedRow(state)
    view = state.view
    if not state.reads or row is None or view["lines"]:
        return ""
    viewKey = viewKeyOf(state) or ""
    waits = []
    if logShown(state, row):
        waits.append(("feed:" + viewKey, view["feed"] is None))
    elif viewReadOf(state, row, "view") is not None:
        waits.append(("view:" + viewKey, view["info"] is None))
    opened = listReadOf(state.path + [row["id"]]) if row["dive"] else None
    if opened and not demandWaits(state, opened):
        waits.append((opened[0], opened[0] not in state.levelsOf))
    if any(key in state.failed for key, waiting in waits) or not any(waiting for key, waiting in waits):
        return ""
    return POPULATING % row["label"]


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
    ## and a text that is Markdown, whether it is rendered or raw
    if markdownShown(state, row):
        form = " " + (dict(VIEW_MODES)["raw"]["mark"] if textRawShown(state) else MARKDOWN["mark"])
    ## and whether its long lines are wrapped or cut: the title says it always
    return (marks + " " if marks else "") + (row.get("title") or row["label"]) + form + " " + (WRAP_MARK if state.wrap or panelsShown(state) else CUT_MARK)


## A label with its hot letter between tildes, as parts to draw: the letter in the one
## look and the rest in the other.
def hotParts(label, look, hotLook):
    return [(part, hotLook if index % 2 else look) for index, part in enumerate(label.split("~")) if part]


def hotText(label):
    return label.replace("~", "")


def hotLetter(label):
    parts = label.split("~")
    return parts[1].lower() if len(parts) > 2 else ""


## The names of the keys in the style of now: its own (KEY_NAMES) over KEY_WORDS.
def keyWords():
    return dict(KEY_WORDS, **KEY_NAMES.get(STYLE.get("names"), {}))


## The name of a key as a menu and the status line show it.
def keyShown(key):
    if key.startswith("ALT-"):
        return "Alt-" + key[4:].upper()
    if key.startswith("CTRL-"):
        return "^" + key[5:].upper()
    return keyWords().get(key, key)


## The names of keys with / between, as one: each as keyShown names it.
def keysShown(keys):
    return "/".join(keyShown(key) for key in keys.split("/"))


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


## The table the rows of the list shown are drawn as, where they are those of one: its
## header is the line above them, which stays in place while they scroll. None for a
## list with no table.
def listTableOf(state):
    for row in listedRows(state, state.path) or ():
        if row.get("table"):
            return row["table"]
    return None


## The table of the rows of the list shown, drawn by paneTable like every table, in that many
## cells: its header, and the line of each row of `rows` by its position in them. The icon, where
## the table has one, is the first cell of a row (its cells), then the first column, and each
## column after it while it fits in full, the others left out whole; the first column is cut.
## A row that is no row of the table, a heading of a group or the row that goes up, stands in it as
## a heading, so the rows after it begin again with a row of the look of a row (THE TABLE COLOUR
## RULE). Gives the header and the lines, each a Looked line whose first look is that of its ground.
def listTableLines(state, rows, table, columns):
    head, blocks = paneTable(table["heads"], [row["cells"][1:] if row.get("table") else row["label"] for row in rows], columns,
                             icons=[row["cells"][0] if row.get("table") else "" for row in rows], wrap=state.wrap, kinds=table["kinds"],
                             indent="", cut=table["cut"])
    return head[0], [block[0] for block in blocks]


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


## How many cells at the right edge of a row the mark of a folder takes, with the blank
## ahead of it, in a list that many cells wide: none where the list is too narrow for it.
def folderEdge(width):
    taken = textWidth(styleMark("folder")) + 1
    return taken if width >= taken + 5 else 0


## One row of the list in exactly that many cells: the mark of the selection, what the row
## shows as, and at the end of the line what the row carries as its tail, its state. A row
## of a table shows as its cells in the columns that fit. A row that Enter dives into, a
## folder, has the mark of a folder at the right edge of the row, after a blank, and the
## rest of the row the cells ahead of them, as every row of a table that holds a folder
## has, so that its columns stand under its header; in a table that does not keep that room
## in every row, a folder's mark takes the room its cells leave, and costs it a column only
## where they leave none. A row whose Enter opens a dialog has
## the mark of that after its name: a name too long for its room is cut ahead of that mark,
## which is never cut itself. Gives the text, where in it a mark stands, or None, and the mark.
## `tableAt` gives, for a table, the header and the lines of its rows in that many cells
## (listTableLines), `position` the row's place among them.
def listRowParts(row, chosen, width, enters=False, dives=False, position=0, tableAt=None):
    table = row.get("table")
    edge = folderEdge(width) if dives or (table or {}).get("marks") else 0
    columns = width - edge - 1
    if table and dives and not table.get("marks") and textWidth(tableAt(width - 1)[1][position].rstrip()) + 1 + edge <= width:
        columns = width - 1
    width -= edge
    shown = tableAt(columns)[1][position].rstrip() if table else " " * row.get("indent", 0) + row.get("lead", "") + row["label"] + countedText(row)
    head = (MARK_SELECTED if chosen else " ") + shown
    tail = row.get("tail", "")
    if row.get("wide") and width + edge >= LIST_WIDE["from"]:
        ## the narrow column after the tail
        tail = (tail + " " if tail else "") + " " * max(0, LIST_WIDE["cells"] - textWidth(row["wide"])) + row["wide"]
    tailWidth = textWidth(tail)
    room = width if not tail or tailWidth + 4 > width else width - tailWidth - 1
    markAt = None
    mark = MARKS["dialog"]
    if enters and not dives and not row.get("table") and room > textWidth(mark) + 2:
        if textWidth(head) > room - textWidth(mark):
            head = cutToCells(head, room - textWidth(mark))
        markAt = textWidth(head)
        head += mark
    text = cutToCells(head, room)
    text = text if room == width else text + " " + cutToCells(tail, tailWidth)
    if edge:
        ## in a table the mark stands in the look of its row, as every cell of the table does
        mark = styleMark("folder")
        markAt = width + 1 if dives and not row.get("table") else None
        text += " " + (mark if dives else " " * textWidth(mark))
    return text, markAt, mark


## One row of the list, drawn in that many cells: in its own look, or in the look of the
## selection; the mark of a folder, or of a dialog, in the palette entry of a folder, but on
## the row the selection is on, whose bar is whole. The row that goes up is no folder.
def putListRow(surface, state, line, column, row, chosen, width, position=0, tableAt=None):
    text, markAt, mark = listRowParts(row, chosen, width, rowEnters(state, row), row["dive"] and row.get("kind") != "up", position, tableAt)
    look = row.get("look", PLAIN)
    if row.get("table"):
        ## a row of a table is in the look of its ground (THE TABLE COLOUR RULE), and one that stands out
        ## or is dimmed in that look on that ground (LOOK_ALT, LOOK_LINE)
        ground = tableAt(width - 1)[1][position].looks[0][2]
        look = ground if look == PLAIN else look + (LOOK_ALT if ground == TABLE_LOOKS["alt"] else LOOK_LINE if ground == TABLE_LOOKS["line"] else 0)
    if chosen:
        look = REVERSE if state.focus == "list" else BOLD
    surface.put(line, column, text, look)
    if markAt is not None and not chosen:
        surface.put(line, column + markAt, mark, FOLDER)


## The word of a command in the status line now: of one that toggles, what its key will do.
def statusWord(state, command):
    word = command.get("status")
    if isinstance(word, tuple):
        return word[1 if getattr(state, command["toggle"]) else 0]
    if command["does"][0] == "open":
        ## on an item that does not open, Enter runs its main action (mainActionOf): the line names that, and not Open
        row = selectedRow(state)
        main = mainActionOf(state) if row is not None and not row["dive"] and row["kind"] != "up" else None
        if main is not None and main.get("status"):
            return main["status"]
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
        return [(keysShown(keys), word) for keys, word in STATUS_KEYS["menu"]]
    if metaPending(state):
        ## after Esc: the keys that are Alt with a letter, each by its letter alone
        return ([(hotLetter(MENUS[index][1]), hotText(MENUS[index][1])) for index in menusShown(state)]
                + [(key[4:], statusWord(state, command) or hotText(command["label"])) for command in COMMANDS
                   for key in commandKeys(command) if key.startswith("ALT-")])
    own = []
    everywhere = []
    for command in COMMANDS:
        if command.get("status") and commandOffered(state, command) and command["does"] != ("mode", modeNow(state)):
            wide = commandWindow(command) is None and "on" not in command
            (everywhere if wide else own).append((keysShown(command["shown"]) if command.get("shown") else keyShown(commandKeyNow(state, command) or commandKeys(command)[0]), statusWord(state, command)))
    return own + everywhere


## The status line: the keys that work now, each in the look of a hot letter and followed
## by its word, as many as fit; and after a mark what the screen says, the outcome of the
## last action. What the screen says has its room first, up to two thirds of the line, and
## the keys that do not fit beside it are left out, the last ones first. In a style with
## chips each key is a chip of its own colour, the blank at each side of it in the chip.
def drawStatusLine(surface, state, line, columns):
    surface.put(line, 0, " " * columns, BAR)
    notice = state.notice if state.dialog is None else ""
    reserved = min(textWidth(notice) + 4, columns * 2 // 3) if notice else 0
    column = 1
    for key, word in statusItems(state):
        width = textWidth(key) + 1 + textWidth(word)
        if column + width > columns - reserved:
            break
        if styleDraws("chips"):
            surface.put(line, column - 1, " " + key + " ", KEY_CHIP)
        else:
            surface.put(line, column, key, BAR_HOT)
        surface.put(line, column + textWidth(key) + 1, word, BAR)
        spot(state, column, line, width, 1, ("key", key))
        column += width + 2
    if notice and columns - column > 2:
        surface.put(line, column, MARKS["separator"] + " " + cutToCells(notice, columns - column - 2), BAR)


## A title in the middle of the top border of a box that many cells wide, in the look of its
## frame, between the marks `ends` of the style names for that frame (" " and " " in MARKS).
## In a style with "titles" the title stands with a blank at each side in a look of its own,
## `chip`, between those marks in the look of the frame; a mark that is a blank is left out
## there, so the title stands where it stands without them. With "titles" "left" it stands at
## the left, TITLE_INSET cells in, and is cut to leave at least as many cells at its right, on
## a terminal that is UTF-8: on another in the middle, as every style draws there.
def putTitle(surface, line, left, width, title, look, ends, chip):
    before, after = styleMark(ends)
    text = fitToCells(title, width - 4 - textWidth(before) - textWidth(after))
    if not STYLE.get("titles"):
        text = before + text + after
        surface.put(line, left + (width - textWidth(text)) // 2, text, look)
        return
    before, after = before.strip(), after.strip()
    column = left + (width - textWidth(text) - 2 - textWidth(before) - textWidth(after)) // 2
    if styleDraws("titles", "left"):
        text = fitToCells(title, max(0, width - 2 * TITLE_INSET - 2 - textWidth(before) - textWidth(after)))
        column = left + TITLE_INSET
    surface.put(line, column, before, look)
    surface.put(line, column + textWidth(before), " " + text + " ", chip)
    surface.put(line, column + textWidth(before) + textWidth(text) + 2, after, look)


## How many cells in from the left of its top a title stands where a style sets it at the
## left (STYLES "titles" "left"), and how many at least stay at its right.
TITLE_INSET = 3


## The frame of a window: double for the active one and single for another, its title in
## the middle of the top border, `foot` in the bottom border from its left, and its right
## border a scroll bar where `bar` says that it holds more than it shows: how many it
## holds, the first one shown, how many it shows. In a style with "icons" the active one,
## while no dialog is over it, has them in its top border, the box that closes at its left and the one that zooms at
## its right, where its title fits whole between them (iconsFit).
def drawFrame(surface, box, title, active, foot="", bar=None, lit=None, count=""):
    left, top, width, height = box
    marks = styleMark("frameOn" if active else "frame")
    ## `lit`: whether it is drawn in the look of the active one, where that is not what
    ## `active` says: behind a dialog no frame is, and the double line stays
    look = FRAME_ON if (active if lit is None else lit) else FRAME
    if styleDraws("edges", "blocks"):
        return drawEdges(surface, box, title, look == FRAME_ON, bar, count)
    room = width - 2
    bottom = top + height - 1
    surface.put(top, left, marks[0] + marks[1] * room + marks[2], look)
    if title and room >= 6:
        putTitle(surface, top, left, width, title, look, "titleOn" if active else "title", TITLE_ON if look == FRAME_ON else TITLE)
    if look == FRAME_ON and iconsFit(width, title or ""):
        close, zoom = styleMark("icons")
        surface.put(top, left + 2, close, look)
        surface.put(top, left + width - 2 - textWidth(zoom), zoom, look)
    rows = height - 2
    barred = bar is not None and bar[0] > bar[2] and rows >= 3
    thumb = 1 + bar[1] * (rows - 3) // max(1, bar[0] - bar[2]) if barred else 0
    for offset in range(rows):
        surface.put(top + 1 + offset, left, marks[3], look)
        if barred:
            mark = "barUp" if offset == 0 else "barDown" if offset == rows - 1 else "barThumb" if offset == thumb else "barTrack"
            surface.put(top + 1 + offset, left + width - 1, styleMark(mark), SCROLL)
        else:
            surface.put(top + 1 + offset, left + width - 1, marks[3], look)
    surface.put(bottom, left, marks[4] + marks[1] * room + marks[5], look)
    if foot and room >= 6:
        surface.put(bottom, left + 2, " " + fitToCells(foot, room - 4) + " ", look)
    if count:
        putCount(surface, bottom, left, width, count, look, "titleOn" if active else "title", TITLE_ON if look == FRAME_ON else TITLE)


## A count in the bottom border of a box at its right, what a window's "count" gives (WINDOWS),
## as a title stands in its top border: between the same marks, in the same looks (putTitle),
## two cells in from its corner; where the border has no room for it, none.
def putCount(surface, line, left, width, count, look, ends, chip):
    before, after = styleMark(ends)
    if not STYLE.get("titles"):
        text = before + count + after
        if textWidth(text) + 6 <= width:
            surface.put(line, left + width - 3 - textWidth(text), text, look)
        return
    before, after = before.strip(), after.strip()
    cells = textWidth(before) + textWidth(count) + 2 + textWidth(after)
    if cells + 6 > width:
        return
    column = left + width - 3 - cells
    surface.put(line, column, before, look)
    surface.put(line, column + textWidth(before), " " + count + " ", chip)
    surface.put(line, column + textWidth(before) + textWidth(count) + 2, after, look)


## The edges of a window in a style that draws them of blocks (STYLES "edges"): its top line
## the desktop with a thin line on its bottom edge, over the window (EDGE_ON_SHADE where it is
## drawn as the active one, else EDGE_SHADE), its title a tab on that line; the window in its
## own colour, no mark at its left, where the change of colour is the edge, its last line
## with a thin line on its bottom edge (EDGE_ON, EDGE), and its right column the shadow it
## casts, whole black cells (SHADOW) from its second line under its top, as Turbo Vision's
## shadow, the desktop beside its top and its first line: no cell of the layout is spent. Where `bar` says that it holds more than it shows, that column is a slim scroll bar:
## an arrow in a box at each end, and between them the track with a thumb as long as the
## share it shows, where that stands; as many lines lower than the window's first as the
## style says (barLower), as long, its ↓ then on the window's last line; its arrows and thumb
## in a look of their own where the window is active (SCROLL, THUMB), else in the track's.
def drawEdges(surface, box, title, lit, bar, count=""):
    left, top, width, height = box
    rim = styleMark("rim")
    look, shade = (EDGE_ON, EDGE_ON_SHADE) if lit else (EDGE, EDGE_SHADE)
    rows = height - 2
    surface.put(top, left, rim[0] + rim[1] * (width - 2) + " ", shade)
    if title and width >= 8:
        putTitle(surface, top, left, width - 1, title, shade, "titleOn" if lit else "title", TITLE_ON if lit else TITLE)
    barred = bar is not None and bar[0] > bar[2] and rows >= 3
    lower = barLower() if barred else 0
    if barred:
        size = max(1, (rows - 2) * bar[2] // bar[0])
        start = 1 + (rows - 2 - size) * bar[1] // max(1, bar[0] - bar[2])
    for offset in range(rows):
        surface.put(top + 1 + offset, left, rim[3], look)
    surface.put(top + height - 1, left, rim[5] + rim[6] * (width - 2), look)
    if count:
        putCount(surface, top + height - 1, left, width - 1, count, look, "titleOn" if lit else "title", TITLE_ON if lit else TITLE)
    ## the right column, from the window's first line to its last: the shadow, or the scroll bar
    for offset in range(rows + 1):
        place = offset - lower
        if not barred or not 0 <= place < rows:
            surface.put(top + 1 + offset, left + width - 1, rim[4], shade if offset == 0 and rows else SHADOW)
        elif place in (0, rows - 1):
            surface.put(top + 1 + offset, left + width - 1, styleMark("barUp" if place == 0 else "barDown"), SCROLL if lit else TRACK)
        else:
            thumb = start <= place < start + size
            mark = ("barThumb" if lit else "barThumbOff") if thumb else "barTrack"
            surface.put(top + 1 + offset, left + width - 1, styleMark(mark), THUMB if thumb and lit else TRACK)


## How many lines lower than a window's first its scroll bar stands: the style's "barLower"
## where it draws the edges of its windows (drawEdges), else none, as a frame draws it.
def barLower():
    return STYLE.get("barLower", 0) if styleDraws("edges", "blocks") else 0


## How many empty lines stand fixed between a window's top and its first line of content:
## the style's "bodyLower" where it draws the edges of its windows (drawEdges), else none.
def bodyLower():
    return STYLE.get("bodyLower", 0) if styleDraws("edges", "blocks") else 0


## One line of what the left window holds, by its number, in exactly that many cells, in
## the look of what it is (lineLook); and over it what of that line is drawn in a look of
## its own (the "looks" of the view). `placing`: the view takes the rule of the locations.
def putViewLine(surface, state, line, column, position, room, placing=False, marked=None):
    lines = state.view["lines"]
    text = lines[position] if position < len(lines) else ""
    if marked is not None and marked[0] <= position <= marked[1]:
        ## a line of the row the row cursor is on: in the look of the selection. A line of a table is selected as wide as the table is (F11.0: a background
        ## starts at the table's first column and ends at its last, and never protrudes), the cells ahead of its first column and past its last as they were
        look = REVERSE if state.focus == "view" else BOLD
        own = getattr(text, "looks", ())
        if own and getattr(text, "row", None) is not None:
            putLooked(surface, state, line, column, text, room, lineLook(state.view, position), [(own[0][0], textWidth(text) - own[0][0], look)], placing)
        else:
            putLooked(surface, state, line, column, text, room, look, (), placing)
        return
    putLooked(surface, state, line, column, text, room, lineLook(state.view, position),
              state.view["looks"].get(position, ()) if text else (), placing)


## A text of the left window in exactly that many cells, in that look, and over it the
## parts of it that are drawn in a look of their own, each as the cell it starts at, how
## many cells it takes and its look, as far as the window shows them: never over the mark
## of a line that is cut. Where the view takes the rule of the locations (`placing`), a
## path inside a location is drawn by the key of that location, the key in the look of a
## folder: the line that is held is not changed.
def putLooked(surface, state, line, column, text, room, look, spans, placing, left=None):
    pinned = getattr(text, "pinned", 0)
    if placing and "/" in text:
        placed, keys = placedLine(state, text)
        if keys:
            text, spans, pinned = placed, keys, 0
    ## from the cell the pane stands at sideways (panOf, at the drawing of its body)
    viewLeft = state.view["left"] if left is None else left
    if pinned and viewLeft and 0 < pinned < room:
        ## the columns that stay: the cells they take as they stand, and the rest of the line scrolled in the room that is left
        kept, rest = splitAtCell(text, pinned)
        putLooked(surface, state, line, column, kept, pinned, look, spansWithin(spans, 0, pinned), False, 0)
        putLooked(surface, state, line, column + pinned, rest, room - pinned, look, spansWithin(spans, pinned, None), False, viewLeft)
        return
    surface.put(line, column, panToCells(text, viewLeft, room), look)
    if not spans:
        return
    cells = []
    total = 0
    for cluster, clusterWidth in textCells(text):
        cells.append((total, cluster, clusterWidth))
        total += clusterWidth
    ## what the window shows of the line: from its first cell in view, or from the one
    ## after the mark of what stands to its left, to its last, or to the one ahead of the
    ## mark of a line that is cut
    first = viewLeft + 1 if viewLeft else 0
    limit = viewLeft + (room if total - viewLeft <= room else room - 1)
    for start, count, look in spans:
        shown = [(at, cluster) for at, cluster, clusterWidth in cells
                 if max(start, first) <= at and at + clusterWidth <= min(start + count, limit)]
        if shown:
            surface.put(line, column + shown[0][0] - viewLeft, "".join(cluster for at, cluster in shown), look)


## A text cut in two at that cell: the cells before it, filled out to it, and the rest. A character of two cells that the cut would part goes to the rest.
def splitAtCell(text, cell):
    cells = textCells(text)
    used = 0
    taken = 0
    for cluster, clusterWidth in cells:
        if used + clusterWidth > cell:
            break
        used += clusterWidth
        taken += 1
    return "".join(cluster for cluster, clusterWidth in cells[:taken]) + " " * (cell - used), "".join(cluster for cluster, clusterWidth in cells[taken:])


## The parts of a line that lie from that cell to that cell (None: to its end), each as the cell it starts at there, how many cells and its look.
def spansWithin(spans, first, last):
    kept = []
    for start, count, look in spans or ():
        begin = max(start, first)
        end = start + count if last is None else min(start + count, last)
        if end > begin:
            kept.append((begin - first, end - begin, look))
    return kept


## The body of a window that shows lines: what is selected in the list. Its head, which
## does not scroll; under it its lines.
def drawLinesBody(surface, state, layout, box):
    column = box[0] + 1
    top = box[1] + 1
    room = box[2] - 2
    contentHeight = viewContentHeight(state, layout)
    headHeight = min(len(state.view["head"]), contentHeight)
    placing = placedShown(state)
    panOf(state, room)
    for offset in range(headHeight):
        putLooked(surface, state, top + offset, column, state.view["head"][offset], room, PLAIN, (), placing)
    scrollView(state, contentHeight - headHeight, 0)
    ## a table whose header has gone up out of the pane keeps it over its rows, sideways with them (paneTable)
    lines = state.view["lines"]
    stuck = headerStuck(state)
    marked = rowCursorLines(state)
    for offset in range(contentHeight - headHeight):
        if offset == 0 and stuck is not None:
            putLooked(surface, state, top + headHeight, column, stuck, room, PLAIN, stuck.looks, placing)
            continue
        putViewLine(surface, state, top + headHeight + offset, column, state.view["top"] + offset, room, placing, marked)
    if contentHeight > headHeight and viewWaits(state):
        surface.put(top + headHeight, column, cutToCells(viewWaits(state), room), DIM)
    if filterLineShown(state):
        ## the line of the filter, on the last line of the window; the cursor stands after what is typed while the line is open
        typed = filterLine(state)
        surface.put(top + contentHeight, column, cutToCells(typed, room), BOLD)
        if state.view["table"].get("filterOpen") and state.focus == "view" and state.dialog is None and state.menu is None:
            surface.cursor(top + contentHeight, column + min(textWidth(typed), room - 1))
    return (len(state.view["lines"]), state.view["top"], contentHeight - headHeight)


## The body of a window that shows rows: the level of the list, its selection in the look
## of the bar while the window is active, a blank line at each of its spacers below the
## first row shown (spacersAt). Gives what its scroll bar goes by, in lines.
def drawRowsBody(surface, state, layout, box):
    column = box[0] + 1
    top = box[1] + 1
    room = box[2] - 2
    rows = levelRows(state)
    rowsHeight = listRowsHeight(state, layout)
    table = listTableOf(state)
    drawn = {}

    def tableAt(columns):
        if columns not in drawn:
            drawn[columns] = listTableLines(state, rows, table, columns)
        return drawn[columns]
    if table:
        surface.put(top, column, cutToCells(" " + tableAt(room - 1)[0], room), TABLE_LOOKS["head"])
        top += 1
    cursor = cursorOf(state, rows, rowsHeight)
    spacers = spacersAt(state, rows)
    position = cursor["top"]
    spaced = True
    for offset in range(rowsHeight):
        if position < len(rows) and position in spacers and not spaced:
            surface.put(top + offset, column, " " * room, PLAIN)
            spaced = True
            continue
        spaced = False
        if position < len(rows):
            putListRow(surface, state, top + offset, column, rows[position], position == cursor["index"], room, position, tableAt)
            spot(state, column, top + offset, room, 1, ("row", position))
        elif position == len(rows) and listWaits(state):
            surface.put(top + offset, column, cutToCells(" " + listWaits(state), room), DIM)
        else:
            surface.put(top + offset, column, " " * room, PLAIN)
        position += 1
    if not rows:
        return (0, 0, rowsHeight)
    return (rowLinesBetween(spacers, 0, len(rows) - 1), rowLinesBetween(spacers, 0, cursor["top"]) - 1, rowsHeight)


## The bodies the engine draws, by the name a window of WINDOWS gives under "shows".
BODIES = {"lines": drawLinesBody, "rows": drawRowsBody}


## One window of WINDOWS, drawn from its declaration: its body, then its frame around it.
def drawWindow(surface, state, layout, window):
    box = layout["boxes"][window["name"]]
    spot(state, box[0], box[1], box[2], box[3], ("window", window["name"]))
    ## the empty lines under its top, where the style keeps them (bodyLower): its body stands under them
    under = bodyLower()
    for offset in range(under):
        surface.put(box[1] + 1 + offset, box[0] + 1, " " * (box[2] - 2), PLAIN)
    held = BODIES[window["shows"]["body"]](surface, state, layout, (box[0], box[1] + under, box[2], box[3] - under))
    foot = globals()[window["foot"]](state) if window.get("foot") else ""
    drawFrame(surface, box, globals()[window["title"]](state), state.focus == window["name"], foot,
              held if window.get("bar") else None, state.focus == window["name"] and state.dialog is None,
              globals()[window["count"]](state) if window.get("count") else "")
    rows = box[3] - 2
    if window.get("bar") and held is not None and held[0] > held[2] and rows >= 3:
        ## the scroll bar, where it stands (barLower): its upper half pages up, its lower half down
        lower = barLower()
        spot(state, box[0] + box[2] - 1, box[1] + 1 + lower, 1, rows // 2, ("bar", -1, window["name"]))
        spot(state, box[0] + box[2] - 1, box[1] + 1 + lower + rows // 2, 1, rows - rows // 2, ("bar", 1, window["name"]))


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
    keyWidth = max(textWidth(keyShown(commandKeys(command)[0])) if commandKeys(command) else 0 for command in listed)
    width = labelWidth + keyWidth + 6
    left = 3 + sum(textWidth(hotText(MENUS[index][1])) + 2 for index in menusShown(state) if index < menu["menu"])
    left = max(0, min(left, layout["columns"] - width - 2))
    frame = boxMarks("frame")
    rule = styleMark("rule")
    slim = STYLE.get("shadow") == "slim"
    ## Turbo Vision's keeps what lies under it, and is drawn once over the whole box at the end
    dim = STYLE.get("shadow") == "dim"
    last = layout["lines"] - 2
    ## one that hangs from the bar has no top border: its first item stands on the line under the bar
    line = 0 if styleDraws("menus", "hung") else 1
    if line:
        surface.put(1, left, frame[0] + frame[1] * (width - 2) + frame[2], BAR)
    for index, command in enumerate(items):
        if line + 1 >= last:
            break
        line += 1
        ## the shadow beside every row, a line between two groups as much as an item
        if not slim and not dim:
            surface.put(line, left + width, "  ", SHADOW)
        if command is None:
            surface.put(line, left, rule[0] + rule[1] * (width - 2) + rule[2], BAR)
            continue
        on = index == menu["item"]
        spot(state, left + 1, line, width - 2, 1, ("item", index))
        look = BAR_ON if on else BAR if commandApplies(state, command) else BAR_OFF
        hotLook = look if look == BAR_OFF else BAR_ON_HOT if on else BAR_HOT
        surface.put(line, left, frame[3], BAR)
        ## the mode the left window is in is marked
        lead = MARKS["on"] if command["does"] == ("mode", modeNow(state)) else " "
        column = putParts(surface, line, left + 1, hotParts(lead + command["label"], look, hotLook), width - 2)
        keyText = keyShown(commandKeys(command)[0]) if commandKeys(command) else ""
        surface.put(line, column, " " * (left + width - 2 - column - textWidth(keyText)) + keyText + " ", look)
        surface.put(line, left + width - 1, frame[4], BAR)
    line += 1
    surface.put(line, left, frame[5] + frame[6] * (width - 2) + frame[7], BAR)
    if slim:
        drawSlimShadow(surface, (left, 1, width, line), last, layout["columns"], SHADE, False)
        return
    if dim:
        drawDimShadow(surface, (left, 1, width, line), last, layout["columns"], SHADOW)
        return
    surface.put(line, left + width, "  ", SHADOW)
    if line + 1 <= last:
        surface.put(line + 1, left + 2, " " * width, SHADOW)


## The whole screen, drawn again from the state in the style of now: every cell of every
## line, so nothing of an earlier drawing, of an earlier size or of another style is left.
## The desktop first, then each window
## of WINDOWS on it, the line to type in where it is open, the menu bar, the dialog that
## is open, drawn over the windows in every style, the status line, and the menu that is open.
def drawScreen(surface, state):
    columns, lines = surface.size()
    layout = layoutOf(columns, lines, state.split)
    ## What this frame is drawn as: its size, its style and where the windows part; and the
    ## dialog or the menu over it. Where that changed, or what lay over the frame before has
    ## closed, the terminal may hold cells curses no longer knows of: the frame is sent whole,
    ## once. Every other frame curses sends as the cells that changed.
    shape = (columns, lines, STYLE["value"], layout["listLeft"] if layout else None)
    over = ("dialog", id(state.dialog)) if state.dialog is not None else ("menu", state.menu["menu"]) if state.menu is not None else None
    if state.drawnAs is not None and (state.drawnAs[0] != shape or state.drawnAs[1] not in (None, over)):
        surface.repaint()
    state.drawnAs = (shape, over)
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
    ## the border between the windows, which the mouse takes hold of: the left border of
    ## the list, shown in another look while it is held
    spot(state, layout["listLeft"], 1, 1, lines - 2, ("split",))
    if state.splitHeld is not None:
        for line in range(2, lines - 2):
            surface.put(line, layout["listLeft"], MARKS["frame"][3], REVERSE)
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
    layout = layoutOf(columns, lines, state.split)
    ## lines that are not wrapped are set out wide, and the window shows a part of them
    state.viewWidth = (layout["viewWidth"] if state.wrap else max(layout["viewWidth"], UNWRAPPED_WIDTH)) if layout else 0
    state.paneWidth = layout["viewWidth"] if layout else 0
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
    state.reads = reader is not None
    noteRoots(state)
    handleKey(state, key, layout)
    if key is not None:
        ## a key may have moved the split, or changed how the lines of the left window are set out
        sizeTaken(surface, state)
    if state.child is not None:
        ## what an operation of the tooling runs is started by the dispatcher the reads are made by
        if state.child.get("tools") and reader is not None:
            state.child["words"] = list(reader.toolsCommand) + state.child["words"]
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

