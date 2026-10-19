##
## AgentsManagerScreen.Cells.py -- text in cells: how many cells a text takes, cut, panned and wrapped to them.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- text in cells ----

## The cells an emoji takes on a line, on every terminal alike. An emoji is one character,
## however many code points it is written with: one a selector U+FE0F makes of a character
## whose own presentation is text (🏛️ ⚖️ ⚠️ ⚒️), a keycap (1️⃣), one wide by itself (🔗 🤔 📥),
## emoji joined by U+200D or with the mark of a skin (🧑‍💻 👍🏽), a flag (🇳🇿). Terminals do not
## agree how far they move for one, and a multiplexer between may count otherwise again: so it
## takes EMOJI_CELLS, or as many as its parts would take each in its own where that is more
## (🧑‍💻 four), and curses is never given one. Curses holds blanks there, and the emoji is written
## into them apart, at its own column (CursesSurface.apartWritten): however far the terminal
## moves for it, nothing after it moves, and a cell it leaves is a blank of the screen's own.
EMOJI_CELLS = 2
## The symbols of those blocks that are text and no emoji, each one cell as Unicode counts it:
## names of keys (KEY_NAMES), the tick of a box (STYLE_MARKS), the mark of an item of a list
## that catMarkdown draws (markdownLines).
TEXT_SYMBOLS = frozenset("⏎⎋⌫✓➤")


## The cells one character takes by Unicode, as itself.
def ownCells(character):
    return 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1


## Whether a character of the screen is an emoji, or may be drawn as one: by what it is written
## with, and by its block, where a terminal may draw its symbols as emoji whatever Unicode says
## of their width (☀ ⚙ ✔ ❤ in Miscellaneous Symbols and Dingbats, ⌚ ⏳ in Miscellaneous
## Technical, ⬛ ⭐ in Miscellaneous Symbols and Arrows, and everything from U+1F000 on).
def isEmoji(cluster):
    if cluster in TEXT_SYMBOLS:
        return False
    first = ord(cluster[0])
    if "\u20e3" in cluster or "\ufe0f" in cluster or "\u200d" in cluster:
        return True
    if any(0x1F3FB <= ord(character) <= 0x1F3FF for character in cluster[1:]):
        return True
    if 0x1F1E6 <= first <= 0x1F1FF:
        return len(cluster) > 1
    return first >= 0x1F000 or 0x2600 <= first < 0x27C0 or 0x2300 <= first < 0x2400 or 0x2B00 <= first < 0x2C00


## The cells a character of the screen takes on a line: an emoji EMOJI_CELLS, or its parts'
## where they take more; another as Unicode counts it, a mark that joins it taking none.
def clusterCells(cluster):
    own = sum(0 if ord(character) == 0x200D or 0xFE00 <= ord(character) <= 0xFE0F or 0x20E3 == ord(character)
              or unicodedata.category(character) in ("Mn", "Me") else ownCells(character) for character in cluster)
    if (len(cluster) > 1 or ord(cluster) >= 0x2300) and isEmoji(cluster):
        return max(EMOJI_CELLS, own)
    return own


## A text as the cells it takes on a terminal: [what is written, how many cells]. A mark
## that joins the character before it stays with that character; an emoji is one character,
## in the cells clusterCells gives it. What a terminal would act on, and not show, is left out.
def textCells(text):
    cells = []
    joining = False
    for character in text:
        if character == "\t":
            character = " "
        codePoint = ord(character)
        category = unicodedata.category(character)
        if cells and (joining or (0x1F3FB <= codePoint <= 0x1F3FF and isEmoji(cells[-1][0]))
                      or (0x1F1E6 <= codePoint <= 0x1F1FF and len(cells[-1][0]) == 1 and 0x1F1E6 <= ord(cells[-1][0]) <= 0x1F1FF)):
            ## the emoji joined to the one before, the mark of its skin, the second letter of a flag: one emoji with it
            joining = False
            cells[-1][0] += character
            continue
        if codePoint == 0x200D or 0xFE00 <= codePoint <= 0xFE0F or category in ("Mn", "Me"):
            if cells:
                cells[-1][0] += character
                joining = codePoint == 0x200D
            continue
        joining = False
        if category in ("Cc", "Cf", "Cs", "Zl", "Zp"):
            continue
        cells.append([character, 0])
    for cell in cells:
        if len(cell[0]) == 1 and ord(cell[0]) < 0x2300:
            cell[1] = ownCells(cell[0])
        else:
            cell[1] = clusterCells(cell[0])
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


## A text as exactly that many cells from its cell `left` on: what a window that is
## scrolled sideways shows of a line. Where the text stands to the left of it, the cut
## mark stands in its first cell; where it goes on past its last, cutToCells puts it there.
def panToCells(text, left, width):
    if left <= 0 or width <= 0:
        return cutToCells(text, width)
    before = []
    rest = []
    used = 0
    for cluster, clusterWidth in textCells(text):
        if used + clusterWidth <= left + 1:
            before.append(cluster)
        elif used < left + 1:
            ## a character of two cells that the edge parts: a blank stands for its half
            before.append(cluster)
            rest.append(" " * (used + clusterWidth - left - 1))
        else:
            rest.append(cluster)
        used += clusterWidth
    return (MARKS["cut"] if "".join(before).strip() else " ") + cutToCells("".join(rest), width - 1)


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
    MARKS.update({"separator": "|", "cut": "+", "plain": True, "frame": "+-+|++", "frameOn": "#=#|##", "rule": "+-+",
                  "shade": " ", "system": "=", "barUp": "^", "barDown": "v", "barTrack": ":", "barThumb": "#", "barThumbOff": "#", "on": "*",
                  "default": "><", "folder": ">", "shadow": "     ", "focus": "><", "icons": ("[#]", "[|]")})


## A text for a terminal that is not UTF-8: what it cannot show becomes `?`, cell for cell.
def plainText(text):
    return "".join(cell[0] if all(ord(character) < 128 for character in cell[0]) else "?" * cell[1]
                   for cell in textCells(text))

