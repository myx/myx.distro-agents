##
## AgentsManagerScreen.ViewTable.py -- a kind of view: the one table of the left window, its columns, its wrapping, its rows apart.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the one table of the left pane ----

## A line of the left pane that carries what of it is drawn in a look of its own, as the
## "looks" of the view hold them: the cell it starts at, how many cells, the look.
class Looked(str):
    looks = ()


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
        WRAPPED_LINES[(text, width)] = len(textwrap.wrap(text, width)) or 1
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
## and the header's with them; the ground and the underline stand on the table alone, from its first column to its last;
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
def paneTable(heads, rows, width, icons=None, wrap=True, kinds=None, indent=" ", numbered=False, looks=None, pane=None, cut=None):
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
        parts = [(textwrap.wrap(cells[index], widths[index]) if wrapped and kinds[index] != "enum" else [cells[index]]) or [""] for index in range(shown)]
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
                                   looks[index] if looks else None, LOOK_ALT if alternate else 0, TABLE_LOOKS["line"] if lined else None))
            alternate = apart and not alternate
        for line in blocks[-1]:
            line.stick = head[0]
    ## the header carries the underline too, where a row of the table does
    if lined and any(len(block) > 1 for block in blocks):
        head[-1].looks[0] = (margin, head[-1].looks[0][1], TABLE_LOOKS["head"] + LOOK_LINE)

    def padding(ground):
        line = looked(" " * textWidth(head[0]), ground, margin)
        line.stick = head[0]
        return line
    ## one empty line under the header and between every two rows, in the full view, where the table fits both ways with it: a line
    ## of the row above it, on the ground of that row and as wide as the table, never underlined
    between = [number for number in range(len(blocks) - 1) if isRow[number] and isRow[number + 1]]
    under = 1 if isRow and isRow[0] else 0
    if pane is not None and (between or under) and shown == len(heads) and len(head) + sum(len(block) for block in blocks) + len(between) + under <= pane[1] and (
            wrap or max(textWidth(line) for line in head + [line for block in blocks for line in block]) <= pane[0]):
        for number in between:
            blocks[number].append(padding(grounds[number]))
        if under:
            head.append(padding(TABLE_LOOKS["head"]))
    return head, blocks


## A left pane that is a table (the owner: "show all items in table. Full table view - no
## summary on top.", "IF YOU WANT SUMMARIES THAT MUCH - ADD THEM TO PANEL BOTTOM RIGHT
## CORNER", "Do not double - one place"): its header and every row of it, nothing above it,
## the pane scrolling; how many rows it holds stands in the frame alone (tableCount).
def tableSummaryLines(state, heads, rows, kinds=None, icons=None, looks=None, numbered=False):
    head, blocks = paneTable(heads, rows, state.viewWidth - 1, icons=icons, wrap=state.wrap, kinds=kinds, numbered=numbered, looks=looks, pane=fullPane(state))
    tableCount(state, rows)
    return head + [line for block in blocks for line in block]


## The cells and the lines of the left window that a table has for itself, where the table is
## all the window holds (the full view of paneTable): the window less the head that stays above
## its lines.
def fullPane(state):
    return state.paneWidth - 1, state.viewHeight - len(state.view.get("head") or ())


## How many rows the table of the left pane holds, its headings of groups aside, for the
## bottom border of its frame (viewCount).
def tableCount(state, rows):
    state.view["tableRows"] = len([row for row in rows if not isinstance(row, str)])


## What the bottom border of the left window says at its right: how many rows its table holds,
## where it shows one, and nothing where it does not.
def viewCount(state):
    count = state.view.get("tableRows")
    return "" if count is None else "%d row%s" % (count, "" if count == 1 else "s")

