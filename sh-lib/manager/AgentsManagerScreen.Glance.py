##
## AgentsManagerScreen.Glance.py -- the glance list (F11.12): the list of the right window read at a glance, one identity, one state and one number a row,
## narrowed by a `/` filter of its own, and a key that opens the full table of the level. A part of the manager screen (AgentsManagerScreen.py): that file
## executes it, in its own namespace and in the order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## The list already draws each row as its identity (label), its state at the end (tail), its number in a narrow column where it carries one (wide) and its
## count after the label (countedText), and the cursor selects one: the glance is those, so the part adds what a glance still needed and the list had not, the
## filter that narrows its rows and the key to the full table. The filter is the list's own, as the filter of a table is the table's: what is typed narrows
## the rows already read, and nothing is read again for it. The full table is the summary the level declares (SUMMARIES), the one its folder shows; the key
## shows it in the left window in place of the selected row's own view while it is held.
##

## ---- the glance list: its filter, its count, its key to the full table ----

## Whether a row has every word of the filter in what the glance shows of it: its identity, its state and its number.
def glanceMatches(row, words):
    text = " ".join(str(row.get(field, "")) for field in ("label", "tail", "wide")).lower()
    return all(word in text for word in words)


## The listed rows of the level narrowed by the filter, which the list draws (orderedRows).
def glanceFiltered(state, rows):
    words = state.listFilter.lower().split()
    return [row for row in rows if glanceMatches(row, words)] if words else list(rows)


## `/`: the line of the filter of the list opens, on the last line of the right window, with what is typed there already.
def listFilterOpen(state):
    state.listFilterOpen = True


## Whether the line of the filter stands in the right window: open, or holding a filter that narrows the rows.
def listFilterLineShown(state):
    return state.listFilterOpen or bool(state.listFilter)


## The line of the filter as the right window draws it, or "".
def listFilterLine(state):
    return "/" + state.listFilter if listFilterLineShown(state) else ""


## One key while the line of the filter of the list is open: a character is typed into it and narrows the rows at once, Backspace takes the last one back,
## Enter closes the line and keeps the filter, Esc closes it and clears the filter. Any other key is the screen's own. Gives whether the key was the line's.
def listFilterKey(state, key):
    if key == "ENTER":
        state.listFilterOpen = False
    elif key == "ESC":
        state.listFilterOpen = False
        state.listFilter = ""
    elif key == "BACKSPACE":
        state.listFilter = state.listFilter[:-1]
    elif len(key) == 1 and key.isprintable():
        state.listFilter = state.listFilter + key
    else:
        if key == "TAB":
            state.listFilterOpen = False
        return False
    return True


## The full table of the level the list is at, as its folder shows it (SUMMARIES), set out to the left window; None where the level declares none or its
## read has not answered. The key of the glance list shows this in the left window in place of the selected row's own view.
def glanceFullTable(state):
    form = SUMMARIES.get(levelPattern(state.path))
    if form is None:
        return None
    row = None
    if state.path:
        for held in levelRowsAt(state, state.path[:-1]):
            if held["id"] == state.path[-1] and held["kind"] != "up":
                row = held
                break
    lines = globals()[form["lines"]](state, state.path, row, form)
    if lines is None:
        return None
    room = max(10, state.viewWidth - 1)
    return [part for line in lines for part in (
        [looked(piece, line.looks[0][2]) if getattr(line, "looks", None) else piece for piece in wrapToCells(line, room)]
        if textWidth(line) > room and not line.startswith(" ") else [line])]


registerPlugin({
    "name": "glance",
    "commands": (
        {"name": "list-filter", "keys": ("/",), "menu": ("view", 6), "label": "Filter the list", "status": "Filter", "window": "list",
         "after": "filter", "does": ("listfilter",)},
        {"name": "full-table", "keys": ("e",), "menu": ("view", 6), "label": "Full table", "does": ("fulltable",)},
    ),
})
