##
## AgentsManagerScreen.Layout.py -- the layout of the windows and the border between them.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the layout ----

## How many cells the right window takes of that width at that ratio, or, at None, at
## the share its place declares: within its own limits (SPLIT), and never so many that
## the left window is none, which keeps half of the smallest terminal.
def splitWidth(columns, ratio=None):
    if ratio is None:
        width = columns * [window["place"]["tenths"] for window in WINDOWS if "tenths" in window["place"]][0] // 10
    else:
        width = int(columns * ratio + 1e-9)
    width = max(SPLIT["least"], min(SPLIT["most"], width))
    return max(1, min(width, columns - MIN_COLUMNS // 2))


## The split moves by one step, towards a wider right window or a narrower one, from
## where it is drawn now, and the ratio that is kept becomes the new one. At a limit
## nothing moves and nothing is kept. Gives what the status line says of it.
def moveSplit(state, columns, direction):
    now = splitWidth(columns, state.split)
    ratio = now / float(columns) + direction * SPLIT["step"]
    moved = splitWidth(columns, ratio)
    if moved == now:
        return "the list is at its %s: %d cells" % ("widest" if direction > 0 else "narrowest", now)
    state.split = ratio
    return "the list takes %d of %d cells" % (moved, columns)


## The border between the windows is put at that column, by the mouse: the right window
## takes what stands from there on, within its limits, and that share of the width is kept.
def placeSplit(state, layout, column):
    columns = layout["columns"]
    wanted = columns - column - (0 if layout["boxes"] else 1)
    state.split = splitWidth(columns, max(1, wanted) / float(columns)) / float(columns)
    state.noticeOf = None
    state.notice = "the list takes %d of %d cells" % (splitWidth(columns, state.split), columns)


## Where each window of WINDOWS stands at that size, by its name: its left column, its top
## line, its width and its height, its frame counted in. The windows fill the desktop, the
## lines between the menu bar and the status line: one with tenths takes them of the
## width, on its side, and the one without takes the rest. `split` is the ratio the user
## moved the split to, or None (splitWidth).
def windowBoxes(columns, lines, split=None):
    boxes = {}
    left, right = 0, columns
    for window in WINDOWS:
        if "tenths" in window["place"]:
            width = splitWidth(columns, split)
            if window["place"]["side"] == "right":
                right -= width
                boxes[window["name"]] = (right, 1, width, lines - 2)
            else:
                boxes[window["name"]] = (left, 1, width, lines - 2)
                left += width
    for window in WINDOWS:
        if window["name"] not in boxes:
            boxes[window["name"]] = (left, 1, right - left, lines - 2)
    return boxes


## Where everything stands at that size, or None where the terminal is too small. The
## first line is the menu bar and the last the status line; between them is the desktop
## with its windows, each in its frame: the list takes three tenths of the width, between
## a quarter and a third, and the window on the left the rest. "viewWidth" is the left
## window less its right border, which stands in the column "separator"; the list stands
## from "listLeft", "listWidth" wide with its frame. Both hold as many lines as the
## desktop has less their borders. "inputLine" is the line of the left window's bottom
## border: the line to type in is drawn there while it is open. `split` is the ratio the
## user moved the split between the windows to, or None: the right window then takes
## what splitWidth gives it, in every style, and the left one the rest.
def layoutOf(columns, lines, split=None):
    if columns < MIN_COLUMNS or lines < MIN_LINES:
        return None
    boxes = windowBoxes(columns, lines, split)
    listWidth = boxes["list"][2]
    viewWidth = boxes["view"][2] - 1
    return {
        "columns": columns,
        "lines": lines,
        "boxes": boxes,
        "viewWidth": viewWidth,
        "separator": viewWidth,
        "listLeft": viewWidth + 1,
        "listWidth": listWidth,
        "topLine": 0,
        "titleLine": 1,
        "bodyTop": 2 + bodyLower(),
        "viewHeight": lines - 4 - bodyLower(),
        "listHeight": lines - 4 - bodyLower(),
        "inputLine": lines - 2,
        "bottomLine": lines - 1,
    }

