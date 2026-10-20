##
## AgentsManagerScreen.ViewTable.py -- a kind of view: the one table of the left window, its columns, its wrapping, its rows apart.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the one table of the left pane ----

## A line of the left pane that carries what of it is drawn in a look of its own, as the
## "looks" of the view hold them: the cell it starts at, how many cells, the look. A line of a
## row of a table carries that row, the one object for all its lines: the heads of the table and
## the cells of the row (paneTable), which the row cursor opens whole (rowCursorEnter).
class Looked(str):
    looks = ()
    row = None
    pinned = 0


## A cell's text broken to that many cells: by textwrap where every character takes one cell (it breaks at hyphens too), else by the count of the screen (wrapToCells), which
## is the one that knows an emoji takes two or more: textwrap counts characters, and a cell with an emoji would be cut where it should be broken.
def wrapCell(text, width):
    if textWidth(text) == len(text):
        return textwrap.wrap(text, width)
    return [line for line in wrapToCells(text, width) if line] if text.strip() else []


def looked(text, look, start=0):
    line = Looked(text)
    line.looks = [(start, textWidth(text) - start, look)]
    return line


## The looks of a table of the left pane: its header, the heading of a group of its rows,
## a row, every other row, and the last line of a row that wraps where the rows are underlined.
TABLE_LOOKS = {"head": ROW_HEAD, "heading": BOLD, "row": ROW, "alt": ROW_ALT, "line": ROW_LINE}


## Whether the terminal draws the exact shades of the colours of a style: it has 256 colours
## (curses.COLORS), as looksOf takes them. Where curses is not started, as in the tests, it has.
def exactShades():
    return getattr(curses, "COLORS", 256) >= 256


## The ground of a look in the colours of the style of now: in its eight colours and, where the
## terminal draws them, in its exact shades, as its own looks name them, else as LOOKS does.
def lookGround(number):
    own = STYLE_LOOKS.get(STYLE.get("looks", ""), {}).get(number)
    return (own[1], own[4] if exactShades() else None) if own else (LOOKS[number][3], None)


## Whether the colours of the style of now name a ground of its own for every other row of a
## table (THE TABLE COLOUR RULE).
def rowsApart():
    return lookGround(ROW_ALT) != lookGround(ROW)


## The kinds of the columns of a table of the left pane: "key", the column a row is known by,
## a path, a place, a name, which has its room first; "enum", one of a few known words, a
## kind, a status, an access, cut to the start that tells its words apart where room is
## short, never wrapped; "text", free words, which give way first, wrapped; "whole", a text
## that is never cut, a public key: as "text", and with the lines not wrapped as wide as it is.
## No key or text column is narrowed below its header, nor below TABLE_LEAST cells, nor below
## its longest word, where that is no longer than TABLE_WORD_MOST cells; no enum column below
## its header, nor below the start of ENUM_PREFIX_LEAST characters, or more, that tells its
## words apart, and its mark of a cut. None is wider than TABLE_CAP cells, which only stops a
## value that runs away, a very long path or text.
## The cells a table keeps for the columns that scroll, beside the ones it pins: it pins none where they would take the room. And how many lines
## the rows of a table must have in the window for its header to stay over them while they scroll.
PIN_ROOM = 20
STICKY_LEAST = 5
TABLE_LEAST = 6
TABLE_WORD_MOST = 16
TABLE_CAP = 80
ENUM_PREFIX_LEAST = 4


## The look of a text that is a state, where the left pane shows one: the worst look of its
## words that STATE_LOOKS names, or None, the look around it.
def stateLook(text):
    found = [STATE_LOOKS[word] for word in text.replace(",", " ").replace(";", " ").replace(":", " ").split() if word in STATE_LOOKS]
    return max(found, key=STATE_RANKS.index) if found else None


## Lines `<name>  <value>` of the left pane, a block of facts: set in by a cell, the names
## padded to the longest of them (FACT_NAME_MOST at most) and dim, each value in the look
## its pair gives as a third word, where it does, and broken to the pane, going on under
## itself. An empty value is left out.
FACT_NAME_MOST = 22


def factLines(pairs, width):
    pairs = [pair for pair in pairs if pair[1]]
    pad = min(FACT_NAME_MOST, max([textWidth(pair[0]) for pair in pairs] + [0]))
    lines = []
    for pair in pairs:
        name = pair[0]
        parts = wrapToCells(pair[1], max(10, width - max(pad, textWidth(name)) - 4))
        at = 1 + max(pad, textWidth(name)) + 2
        for number, part in enumerate(parts):
            line = Looked(" " + (name + " " * (pad - textWidth(name)) if not number else " " * max(pad, textWidth(name))) + "  " + part)
            line.looks = ([(1, textWidth(name), DIM)] if not number else []) + (
                [(at, textWidth(part), pair[2])] if len(pair) > 2 and pair[2] is not None else [])
            lines.append(line)
    return lines


## A heading of a part of a summary of the left pane, under a blank line.
def headingLines(text):
    return ["", looked(text, TABLE_LOOKS["heading"])]


## The least cells of an enum column: the start of its words that tells them apart, with
## the mark of a cut.
def enumLeast(values):
    values = set(value for value in values if value != "-")
    length = ENUM_PREFIX_LEAST
    while len(set(value[:length] for value in values)) < len(values):
        length += 1
    return length + 1


## How many lines a cell takes wrapped at a width, at its words (textwrap); an empty cell takes
## one. Kept, because reassessWidths tries the widths of a table against every cell of it.
WRAPPED_LINES = {}


def wrappedLines(text, width):
    if (text, width) not in WRAPPED_LINES:
        if len(WRAPPED_LINES) > 100000:
            WRAPPED_LINES.clear()
        WRAPPED_LINES[(text, width)] = len(wrapCell(text, width)) or 1
    return WRAPPED_LINES[(text, width)]


## The widths of the columns of a table whose lines wrap, brought to the fewest lines the room
## they share gives: one column takes cells from another (the text columns give first, then
## the key) while the table takes fewer lines for it, no column below its least nor above its
## natural width. A row takes as many lines as its tallest cell, so a column wrapped to four
## lines beside one wrapped to two takes room from it until the row takes two. A move is made
## only for fewer lines of the table, and of two moves that give as many, the one that wraps
## fewer cells wins. An enum column is never wrapped and keeps its width. `widths` is changed
## in place.
def reassessWidths(widths, words, kinds, natural, least):
    free = [index for index in range(len(widths)) if kinds[index] != "enum"]
    if len(free) < 2 or not words:
        return
    counts = {}

    def lines(index, cellWidth):
        if (index, cellWidth) not in counts:
            counts[(index, cellWidth)] = [wrappedLines(row[index], cellWidth) for row in words]
        return counts[(index, cellWidth)]
    held = dict((index, widths[index]) for index in free)
    cells = dict((index, sum(lines(index, held[index]))) for index in free)
    total = (sum(max(rowCounts) for rowCounts in zip(*[lines(index, held[index]) for index in free])), sum(cells.values()))
    order = sorted(free, key=lambda index: ("text", "whole", "key").index(kinds[index]))
    while total[0] > len(words):
        best = None
        for donor in order:
            for taker in free:
                if taker == donor:
                    continue
                others = [lines(index, held[index]) for index in free if index not in (taker, donor)]
                rest = [max(rowCounts) for rowCounts in zip(*others)] if others else [1] * len(words)
                restCells = sum(cells[index] for index in free if index not in (taker, donor))
                for step in range(1, min(held[donor] - least[donor], max(natural[taker], held[taker]) - held[taker]) + 1):
                    takerLines, donorLines = lines(taker, held[taker] + step), lines(donor, held[donor] - step)
                    value = (sum(max(rowCount) for rowCount in zip(rest, takerLines, donorLines)), restCells + sum(takerLines) + sum(donorLines))
                    if value[0] < total[0] and (best is None or value < best[0]):
                        best = (value, taker, donor, step)
        if best is None:
            break
        total, taker, donor, step = best
        held[taker] += step
        held[donor] -= step
        cells[taker], cells[donor] = sum(lines(taker, held[taker])), sum(lines(donor, held[donor]))
    for index in free:
        widths[index] = held[index]


## A table for the left pane: its header, and its rows, each the lines of one row. With the
## lines of the pane wrapped (`wrap`) it spans the pane, that many cells: a key or text cell
## is wrapped in its own column at its words (textwrap), a row as tall as its tallest cell;
## the widths are those of the words, and where the pane is too narrow for them all, the
## text columns give way first, then the enum ones, then the key, the widest of a kind
## first, each no further than its least; a column that still does not fit is left out
## whole, the last first, and the others are fitted again; the room left over goes to the
## last column, so that the table spans the pane; a table whose every column fits keeps its
## own width. With them not wrapped every column is as wide as its words and the table as
## wide as they, a row a line, and the pane scrolls sideways. No column is wider than
## TABLE_CAP. `kinds`: the kind of each column (the first a key, the others text, where not
## given). A row is a list of words, or a text alone for the heading of a group; `icons`, one
## for each row, stand in a place of their own ahead of it, never wrapped; `numbered` puts
## ahead of them a column `#`, each row's number from 1; `indent` stands ahead of every line. Rows take turns in the looks of a row (TABLE_LOOKS),
## by THE TABLE COLOUR RULE: where the colours set no row apart and the lines are wrapped, the last line of each row that wraps is underlined,
## and the header's with them, or in a style that draws a rule (STYLES "rowRule") a light line of its own stands under each, as wide as the table,
## on the padding line where one stands there; the ground and the underline stand on the table alone, from its first column to its last;
## `looks`, one for each row, gives a look of its own to each cell that has one (None: the
## row's), a state in its colour (stateLook), on the ground of the row (LOOK_ALT, LOOK_LINE). Each line of a
## row carries its header (`stick`), which stays over the rows when it has gone up out of
## the pane (drawLinesBody). The columns, the number and the icon too, stand two cells apart
## where the room left holds that for every gap, else one. With the lines wrapped, the widths
## are tried against every cell: the room is moved from one column that wraps to another while
## the table takes fewer lines for it, so that a row takes the fewest lines the width gives.
## `pane`, the cells and the lines of the left window, is given by a table that is all of it
## (the full view): one empty line then stands between every two rows, where no column is
## left out, the lines not wrapped are no wider than the pane, and the table with them is no
## taller than the pane. `cut`, given by a table of the list on the right (listTableLines),
## makes the table fit the pane without wrapping a cell: each of its lines is one line, a
## column stands only whole or is left out, the last first, and the first is cut at that many
## cells; `wrap` then says only how THE TABLE COLOUR RULE marks the rows.
def paneTable(heads, rows, width, icons=None, wrap=True, kinds=None, indent=" ", numbered=False, looks=None, pane=None, cut=None, pin=0, pinRoom=0, headed=None):
    kinds = list(kinds or ["key"] + ["text"] * (len(heads) - 1))
    words = [row for row in rows if not isinstance(row, str)]
    natural = [(lambda most: most if kinds[index] == "whole" else min(TABLE_CAP, most))(max([textWidth(head)] + [textWidth(row[index]) for row in words])) for index, head in enumerate(heads)]
    if cut is not None:
        natural[0] = min(natural[0], cut)
    wrapped = wrap and cut is None
    fitted = wrapped or cut is not None
    least = [min(natural[index], max(textWidth(head), enumLeast([row[index] for row in words]) if kinds[index] == "enum" else max(
        TABLE_LEAST, min(TABLE_WORD_MOST, max([textWidth(word) for row in words for word in row[index].split()] + [0])))))
        for index, head in enumerate(heads)]
    iconWidth = max([textWidth(icon) for icon in icons or ()] + [0])
    numberWidth = max(1, len(str(len(words)))) if numbered else 0
    ## the columns ahead of the others, and the cells they take, not counting their gaps
    ahead = (1 if numbered else 0) + (1 if iconWidth else 0)
    aheadCells = numberWidth + iconWidth

    def fit(count):
        widths = natural[:count]
        over = aheadCells + ahead + sum(widths) + count - 1 - (width - len(indent))
        for kind in (("text", "whole", "enum", "key") if wrapped else ()):
            while over > 0:
                giving = [index for index in range(count) if kinds[index] == kind and widths[index] > least[index]]
                if not giving:
                    break
                widths[max(giving, key=lambda index: widths[index])] -= 1
                over -= 1
        return widths, over

    shown = len(heads)
    widths, over = fit(shown) if fitted else (natural[:], 0)
    while fitted and over > 0 and shown > 1:
        shown -= 1
        widths, over = fit(shown)
    if cut is not None and over > 0:
        widths[0] = max(1, widths[0] - over)
    ## two cells between the columns where the room that is left holds that for every gap, else
    ## one; what is left of the room, where a column was left out, goes to the last
    gaps = ahead + shown - 1
    spare = max(0, width - len(indent) - aheadCells - ahead - sum(widths) - (shown - 1))
    gap = 2 if gaps and spare >= gaps else 1
    spare -= (gap - 1) * gaps
    if wrapped and shown < len(heads):
        widths[shown - 1] += spare
    if wrapped:
        reassessWidths(widths, words, kinds, natural, least)

    margin = textWidth(indent)
    lead = margin + (numberWidth + gap if numbered else 0) + (iconWidth + gap if iconWidth else 0)

    def rowLines(cells, icon, look, count="", colours=None, shift=0, last=None):
        parts = [(wrapCell(cells[index], widths[index]) if wrapped and kinds[index] != "enum" else [cells[index]]) or [""] for index in range(shown)]
        lines = [looked(indent + ((count if not number else "").rjust(numberWidth) + " " * gap if numbered else "")
                        + (cutToCells(icon if not number else "", iconWidth) + " " * gap if iconWidth else "") + (" " * gap).join(
            cutToCells(part[number] if number < len(part) else "", widths[index]) for index, part in enumerate(parts)), look, margin)
            for number in range(max(len(part) for part in parts))]
        ## only a row whose content wraps is underlined
        last = last if len(lines) > 1 else None
        ## a cell of its own look over the look of its row, as far as its words go, on the ground
        ## of that row (`shift`), and underlined on the last line of a row that is (`last`)
        for index in range(shown if colours else 0):
            if colours[index] is None:
                continue
            start = lead + sum(widths[:index]) + index * gap
            for number, line in enumerate(lines):
                cells = textWidth(cutToCells(parts[index][number], widths[index]).rstrip()) if number < len(parts[index]) else 0
                if cells:
                    line.looks.append((start, cells, colours[index] + (LOOK_LINE if last is not None and number == len(lines) - 1 else shift)))
        if last is not None:
            lines[-1].looks[0] = (margin, lines[-1].looks[0][1], last)
        return lines

    head = rowLines(list(heads), "", TABLE_LOOKS["head"], "#")
    blocks = []
    isRow = []
    alternate = False
    counted = 0
    apart = rowsApart()
    lined = wrapped and not apart
    ruled = lined and styleDraws("rowRule")
    grounds = []
    for index, row in enumerate(rows):
        isRow.append(not isinstance(row, str))
        if isinstance(row, str):
            blocks.append([looked(indent + row, TABLE_LOOKS["heading"])])
            grounds.append(None)
            alternate = False
        else:
            counted += 1
            grounds.append(TABLE_LOOKS["alt" if alternate else "row"])
            blocks.append(rowLines(row, icons[index] if icons else "", TABLE_LOOKS["alt" if alternate else "row"], str(counted),
                                   looks[index] if looks else None, LOOK_ALT if alternate else 0, TABLE_LOOKS["line"] if lined and not ruled else None))
            alternate = apart and not alternate
        for line in blocks[-1]:
            line.stick = head[0]
    ## the header carries the underline too, where a row of the table does
    if lined and not ruled and any(len(block) > 1 for block in blocks):
        head[-1].looks[0] = (margin, head[-1].looks[0][1], TABLE_LOOKS["head"] + LOOK_LINE)

    def padding(ground):
        line = looked(" " * textWidth(head[0]), ground, margin)
        line.stick = head[0]
        return line
    ## one empty line under the header and between every two rows, in the full view, where the table fits both ways with it: a line
    ## of the row above it, on the ground of that row and as wide as the table, never underlined
    between = [number for number in range(len(blocks) - 1) if isRow[number] and isRow[number + 1]]
    under = 1 if isRow and isRow[0] else 0
    ## where the style draws a rule: it stands under the header where a row wraps and under each row that wraps, on the
    ## padding line where one stands, else on a line of its own, which the table then takes in its height
    ruling = [number for number in range(len(blocks)) if ruled and isRow[number] and len(blocks[number]) > 1]
    extra = len([number for number in ruling if number not in between]) + (1 if ruling and not under else 0)
    padded = pane is not None and (between or under) and shown == len(heads) and len(head) + sum(len(block) for block in blocks) + len(between) + under + extra <= pane[1] and (
        wrap or max(textWidth(line) for line in head + [line for block in blocks for line in block]) <= pane[0])
    if padded:
        for number in between:
            blocks[number].append(padding(grounds[number]))
        if under:
            head.append(padding(TABLE_LOOKS["head"]))

    def rule(ground):
        line = looked(" " * margin + styleMark("rule")[1] * (textWidth(head[0]) - margin), ground, margin)
        line.stick = head[0]
        return line
    for number in ruling:
        if padded and number in between:
            blocks[number][-1] = rule(grounds[number])
        else:
            blocks[number].append(rule(grounds[number]))
    if ruling:
        if padded and under:
            head[-1] = rule(TABLE_LOOKS["head"])
        else:
            head.append(rule(TABLE_LOOKS["head"]))
    ## every line of a row, its padding and its rule too, says which row it is of: under the heads the table was given, not those a mark of its sort changed
    for number, block in enumerate(blocks):
        if isRow[number]:
            said = (list(headed or heads), list(rows[number]))
            for line in block:
                line.row = said
    ## the columns at the left that stay while the table is scrolled sideways (`pin` of them, with the number and the icon ahead of them): every line
    ## carries how many cells they take, where the room beside them holds PIN_ROOM cells at least
    stays = lead + sum(widths[:pin]) + pin * gap
    if pin and pin < shown and stays + PIN_ROOM <= pinRoom:
        for line in head + [line for block in blocks for line in block]:
            line.pinned = stays
    return head, blocks


## A left pane that is a table (the owner: "show all items in table. Full table view - no
## summary on top.", "IF YOU WANT SUMMARIES THAT MUCH - ADD THEM TO PANEL BOTTOM RIGHT
## CORNER", "Do not double - one place"): its header and every row of it, nothing above it,
## the pane scrolling; how many rows it holds stands in the frame alone (tableCount). It is the one
## table of the left window, and every key of a table is its: the rows sorted by a column, back to
## the source order, narrowed by what is typed (tableOrder); its first columns kept while it is
## scrolled sideways, `pin` of them, by default the first where it is a key (PIN_ROOM).
def tableSummaryLines(state, heads, rows, kinds=None, icons=None, looks=None, numbered=False, pin=None):
    table = state.view["table"]
    table["columns"] = len(heads)
    order = tableOrder(table, heads, rows)
    sort = table.get("sort")
    marked = [head + " " + MARKS["barUp"] if index == sort else head for index, head in enumerate(heads)]
    kept = [rows[index] for index in order]
    head, blocks = paneTable(marked, kept, state.viewWidth - 1, icons=[icons[index] for index in order] if icons else None, wrap=state.wrap, kinds=kinds,
                             numbered=numbered, looks=[looks[index] for index in order] if looks else None, pane=fullPane(state),
                             pin=(1 if kinds is None or kinds[0] == "key" else 0) if pin is None else pin, pinRoom=state.paneWidth - 2, headed=heads)
    tableCount(state, kept, len([row for row in rows if not isinstance(row, str)]) if table.get("filter") else None)
    lines = head + [line for block in blocks for line in block]
    if rows and not kept:
        lines.append(Looked("  No row has all of: %s" % table["filter"]))
    return lines


## The cells and the lines of the left window that a table has for itself, where the table is
## all the window holds (the full view of paneTable): the window less the head that stays above
## its lines.
def fullPane(state):
    return state.paneWidth - 1, state.viewHeight - len(state.view.get("head") or ()) - (1 if filterLineShown(state) else 0)


## How many rows the table of the left pane holds, its headings of groups aside, for the
## bottom border of its frame (viewCount); and, while a filter narrows it, how many it holds
## without it.
def tableCount(state, rows, total=None):
    state.view["tableRows"] = len([row for row in rows if not isinstance(row, str)])
    state.view["tableAll"] = total


## What the bottom border of the left window says at its right: how many rows its table holds,
## where it shows one, and nothing where it does not; `3 of 40 rows` while a filter narrows it.
def viewCount(state):
    count = state.view.get("tableRows")
    if count is None:
        return ""
    total = state.view.get("tableAll")
    return ("%d of %d row%s" % (count, total, "" if total == 1 else "s")) if total is not None else "%d row%s" % (count, "" if count == 1 else "s")


## ---- the table sorted and narrowed: its keys ----

## How a cell sorts: a number by its value (a k, K, M, G or T after it counts thousands, millions, and so on), before the words, which sort
## by their letters, before the cell that says nothing, `-` or empty, which stands last.
SORT_NUMBER = re.compile(r"^([+-]?[0-9]+(?:\.[0-9]+)?)([kKMGT]?)")
SORT_UNITS = {"": 1.0, "k": 1e3, "K": 1e3, "M": 1e6, "G": 1e9, "T": 1e12}


def sortKeyOf(cell):
    text = str(cell).strip()
    if text in ("", "-"):
        return (2, 0.0, "")
    found = SORT_NUMBER.match(text)
    if found:
        return (0, float(found.group(1)) * SORT_UNITS[found.group(2)], text.lower())
    return (1, 0.0, text.lower())


## Whether a row has every word of the filter in its cells, whatever the case; cells that no column of the pane shows count too.
def rowMatches(row, words):
    text = " ".join(str(cell) for cell in row).lower()
    return all(word in text for word in words)


## The rows of a table as it shows them now, by their numbers in the rows it was given: a group (a heading, and the rows under it, or the rows alone)
## narrowed by the filter, each sorted by the column of the sort, a group that has no row left dropped. The source order where neither is on.
def tableOrder(table, heads, rows):
    words = table.get("filter", "").lower().split()
    sort = table.get("sort")
    groups = [[None, []]]
    for index, row in enumerate(rows):
        if isinstance(row, str):
            groups.append([index, []])
        elif not words or rowMatches(row, words):
            groups[-1][1].append(index)
    order = []
    for heading, members in groups:
        if sort is not None:
            found = [index for index in members if str(rows[index][sort]).strip() not in ("", "-")]
            blank = [index for index in members if index not in found]
            members = sorted(found, key=lambda index: sortKeyOf(rows[index][sort])) + blank
        if heading is not None and (members or not words):
            order.append(heading)
        order.extend(members)
    return order


## Whether the left window holds a table that is all of it, which these keys act on.
def tableShown(state):
    return state.view.get("tableRows") is not None and bool(state.view["table"].get("columns"))


## `t`: the rows sorted by the next column, the first after the source order and the source order after the last. The pane goes to the top of
## the table and the cursor of its row, if it had one, is left.
def tableSort(state):
    table = state.view["table"]
    column = 0 if table.get("sort") is None else table["sort"] + 1
    table["sort"] = column if column < table["columns"] else None
    state.view["rowCursor"] = None
    state.view["top"] = 0


## `/`: the line of the filter opens, on the last line of the left window, with what is typed there already.
def tableFilterOpen(state):
    state.view["table"]["filterOpen"] = True


## Whether the line of the filter stands in the left window: open, or holding a filter that narrows the rows.
def filterLineShown(state):
    table = state.view.get("table") or {}
    return bool(table.get("filterOpen") or table.get("filter"))


## One key while the line of the filter is open: a character is typed into it and narrows the rows at once, Backspace takes the last one back, Enter closes
## the line and keeps the filter, Esc closes it and clears the filter. Any other key is the screen's own. Gives whether the key was the line's.
def filterKey(state, key):
    table = state.view["table"]
    if key == "ENTER":
        table["filterOpen"] = False
    elif key == "ESC":
        table["filterOpen"] = False
        table["filter"] = ""
    elif key == "BACKSPACE":
        table["filter"] = table.get("filter", "")[:-1]
    elif len(key) == 1 and key.isprintable():
        table["filter"] = table.get("filter", "") + key
    else:
        if key == "TAB":
            table["filterOpen"] = False
        return False
    state.view["rowCursor"] = None
    state.view["top"] = 0
    return True


## The line of the filter as the left window draws it, or "".
def filterLine(state):
    table = state.view.get("table") or {}
    return "/" + table.get("filter", "") if filterLineShown(state) else ""


## ---- reading a table first: the row cursor ----

## A table that is all of the left window is read like a text with `less`, with no row
## highlighted (the keys of the paging scroll it). Enter puts a row cursor on the top row in
## view, the arrows move it a row, Enter on a row opens it whole in the information dialog,
## and Esc leaves the cursor, back to reading. The cursor is the number of a row of the table
## in view["rowCursor"], None while it is read; there is no setting for it.

## The rows of the table the left window holds, each as [its first line, its last line, the row
## it says (Looked.row)], in their order; none where the window holds no table that is all of it.
def tableRowsOf(state):
    rows = []
    if state.view.get("tableRows") is None:
        return rows
    for number, line in enumerate(state.view["lines"]):
        said = getattr(line, "row", None)
        if said is None:
            continue
        if rows and rows[-1][2] is said:
            rows[-1][1] = number
        else:
            rows.append([number, number, said])
    return rows


## The first line of the table in view that is seen: the header stays over the rows (stick) once the pane has
## gone down, and takes the place of the line at its top.
def firstSeenLine(state):
    top = state.view["top"]
    return top + 1 if headerStuck(state) is not None else top


## The header that stays over the rows of a table that has gone up out of the window, or None: the window must hold more than STICKY_LEAST lines of rows.
def headerStuck(state):
    view = state.view
    lines = view["lines"]
    room = state.viewHeight - len(view["head"]) - (1 if filterLineShown(state) else 0)
    return getattr(lines[view["top"]], "stick", None) if 0 < view["top"] < len(lines) and room > STICKY_LEAST else None


## The row the cursor is on, as the lines it takes, (first, last), or None while the table is read;
## the cursor is brought within the rows the table has now.
def rowCursorLines(state):
    cursor = state.view.get("rowCursor")
    if cursor is None:
        return None
    rows = tableRowsOf(state)
    if not rows:
        state.view["rowCursor"] = None
        return None
    cursor = state.view["rowCursor"] = max(0, min(cursor, len(rows) - 1))
    return rows[cursor][0], rows[cursor][1]


## Enter in the left window: where it holds a table, the cursor on the top row in view, else
## the row the cursor is on, opened whole in the information dialog, a line `head: cell` for
## each column, its first cell its title.
def rowCursorEnter(state):
    rows = tableRowsOf(state)
    if not rows:
        return
    if state.view.get("rowCursor") is None:
        seen = firstSeenLine(state)
        state.view["rowCursor"] = next((number for number, row in enumerate(rows) if row[1] >= seen), len(rows) - 1)
        return
    heads, cells = rows[max(0, min(state.view["rowCursor"], len(rows) - 1))][2]
    tell(state, str(cells[0]) if cells and str(cells[0]) else "Row",
         [(str(head), str(cell) or "-") for head, cell in zip(heads, cells)], "information", level="")


## An arrow with the cursor on moves it that many rows, and the pane with it as far as the row needs.
def rowCursorMove(state, height, step):
    rows = tableRowsOf(state)
    view = state.view
    if not rows or view.get("rowCursor") is None:
        return
    cursor = view["rowCursor"] = max(0, min(view["rowCursor"] + step, len(rows) - 1))
    first, last = rows[cursor][0], rows[cursor][1]
    ## the row comes into view whole, its first line not under the header that stays over the rows
    if first < firstSeenLine(state):
        view["top"] = max(0, first - 1)
    elif last >= view["top"] + height:
        view["top"] = min(last - height + 1, max(0, first - 1))
    view["top"] = max(0, min(view["top"], max(0, len(view["lines"]) - height)))


## The pane was scrolled by a key of the paging with the cursor on: a row the pane left out of view
## gives the cursor up to the top row in view where the pane went down, and to the last one where it
## went up.
def rowCursorKeep(state, height):
    rows = tableRowsOf(state)
    view = state.view
    if not rows or view.get("rowCursor") is None:
        return
    cursor = max(0, min(view["rowCursor"], len(rows) - 1))
    if rows[cursor][1] < firstSeenLine(state):
        cursor = next((number for number, row in enumerate(rows) if row[1] >= firstSeenLine(state)), len(rows) - 1)
    elif rows[cursor][0] >= view["top"] + height:
        cursor = max([number for number, row in enumerate(rows) if row[0] < view["top"] + height] or [0])
    view["rowCursor"] = cursor

