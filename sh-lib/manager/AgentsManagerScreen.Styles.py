##
## AgentsManagerScreen.Styles.py -- the styles of the screen and how a style draws: the shadows, the marks of a box.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the declaration of the screen: its styles, its windows, its menus, its commands ----

## The styles of the interface, in the order the screen offers them: the name of each, and
## what it is. "label": what it shows as. Every style stands its windows in frames on a
## desktop, under a menu bar and over a status line. "colours": it is drawn in the colours of LOOKS where the terminal has them; without them,
## and on a terminal that has none, in bold, reverse and dim alone. "keys": its key map,
## an entry of KEYMAPS. "names": what its menus, its status line and its help name the keys
## by, an entry of KEY_NAMES; with none, KEY_WORDS alone. What a style may switch on besides,
## each a feature of the drawing that any style can take: "looks", its own colours, an entry
## of STYLE_LOOKS, on a terminal of 256 colours in that palette's exact shades, and taken
## where the terminal has colours also by a style without "colours"; "marks",
## its own marks, an entry of STYLE_MARKS; "titles", the title of a window and of a dialog
## in a look of its own (TITLE_ON, TITLE) between the marks of its frame, in the middle of
## its top, and with "titles" "left" on a terminal that is UTF-8 (styleDraws) at its left,
## TITLE_INSET cells in; "shadow" "slim",
## the shadow of a menu and of a dialog half a cell wide and half a line deep, of quarter
## and half blocks, where without it the style with colours has two cells of shadow; and
## "buttons" "raised", a button in a dialog a face with a slim shadow beside and under it,
## under it the ground of its cells (drawGroundShadow), where without it a button stands between brackets; "shadow" "dim", the shadow of
## Turbo Vision, two cells wide and a line deep, over what lies under it, which keeps its
## characters and is drawn again in the look of a shadow (drawDimShadow); "icons", the
## icons of Turbo Vision in the top border of the active window and of a dialog, the box
## that closes at its left and, on a window, the one that zooms at its right.; "buttons" "bars", the buttons of a
## dialog bars of one width with that shadow, the one with the keys in its look with the
## marks of the focus inside its ends, the default in a look of its own (BOX_BUTTON_DEF).
## Each of these that follow is drawn on a terminal that is UTF-8 alone (styleDraws), where
## on another every style draws in the marks of one byte: "edges" "blocks", a window, a menu
## and a dialog stand in their own colour, a thin line on the bottom edge of the line over
## them, drawn on what lies outside, their title a tab on it, and on the bottom edge of their
## last line, with no mark at their sides, where the change of colour is the edge (MARKS
## "rim"); a window's right column is the shadow it casts, from its second line under its top
## (drawEdges), and its scroll bar is slim, in that column, and with "barLower" that many lines
## lower than the frame's first, its ↓ then on the window's last line (barLower); with
## "bodyLower" that many empty lines stand fixed under a window's top, its content under
## them (bodyLower); "menus" "hung", a
## menu hangs from the menu bar with no top border, its first item on the line under the
## bar, its sides, its bottom and its shadow as in every style; "chips", a key of the
## status line a chip in a colour of its own (KEY_CHIP); "fields" "bracketed", a field to
## type in between brackets with its room filled with dots; "levels", a dialog of what was
## refused or failed (DIALOGS "level") in the looks of its level (ALERT...). The same
## windows, menus, commands and keys are drawn in every style: adding a style is adding an
## entry here. They stand in the order they are offered in, Magic first; the screen starts
## in STYLE_FIRST. Each style is drawn in each of the three colours of COLOURS: "schemes"
## names them for the style, in the order of COLOURS, each with what it changes in its entry
## (its "looks"). The setting of the style (STYLE_VARIABLE) names both, `<style>-<colours>`,
## the colours by the style's own name of them or by that of COLOURS in the same place; a
## style named alone, as one was saved before styles had colours, is in the colours its
## entry names under "bare", and one named as it was before by its name of STYLE_FORMER.
## The compact style (`mc`) is retired, and its drawing with it: a name that
## is no style leaves STYLE_FIRST (setStyle, main), so a saved `mc` starts the screen in
## Turbo Vision. Magic has three sets of colours in STYLE_LOOKS, "nu-blue", "nu-gray" and
## "nu-system" (its choice of the terminal's eight): its "schemes" name the one each takes.
STYLES = (
    ("nu", {"label": "Magic", "colours": True, "keys": "tv", "names": "symbols",
            "looks": "nu-gray", "marks": "magic", "titles": "left", "shadow": "slim", "buttons": "bars",
            "edges": "blocks", "barLower": 1, "bodyLower": 1, "menus": "hung", "chips": True, "fields": "bracketed", "levels": True,
            "bare": "gray", "schemes": (("system", {"looks": "nu-system"}), ("blue", {"looks": "nu-blue"}), ("gray", {"looks": "nu-gray"}))}),
    ("tv", {"label": "Turbo Vision", "colours": True, "keys": "tv", "names": "classic",
            "marks": "tv", "shadow": "dim", "buttons": "raised", "icons": True,
            "bare": "system", "schemes": (("system", {}), ("blue", {"looks": "tv-blue"}), ("gray", {"looks": "tv-gray"}))}),
    ("bw", {"label": "Basic B/W", "colours": False, "keys": "tv", "names": "classic",
            "bare": "system", "schemes": (("system", {}), ("dark", {"looks": "bw-dark"}), ("light", {"looks": "bw-light"}))}),
)
## The three colours of every style, in the order they are offered, each with what it shows
## as: "system", the terminal's own basic colours, as its user set them (no colours at all
## in Basic B/W, but bold, reverse and dim); "dark" and "light", exact shades on a terminal
## of 256 colours (STYLE_LOOKS), the basic colours of the same plan on one of eight.
COLOURS = (("system", "System"), ("dark", "Dark/Blue"), ("light", "Light/Gray"))
## A style by the name it had before.
STYLE_FORMER = {"magic": "nu"}
## The style a screen starts in where nothing names another, with its colours, and the
## variable of the environment that names one for a start.
STYLE_FIRST = "tv-system"
STYLE_VARIABLE = "MDAT_MANAGER_STYLE"
## The style the screen is drawn in now: its entry of STYLES with what its colours change
## in it, under "name" the name of the style, under "scheme" the name of its colours, and
## under "value" the two as the setting names them.
STYLE = {}


## Takes the style of that name, `<style>-<colours>` or a style alone, for what is drawn
## from now on, under the style's own names of both. Gives whether there is one: a name
## that is none changes nothing.
def setStyle(name):
    style, dash, colours = name.partition("-")
    style = STYLE_FORMER.get(style, style)
    entry = dict(STYLES).get(style)
    if entry is None:
        return False
    names = [scheme for scheme, changes in entry["schemes"]]
    if not dash:
        colours = entry["bare"]
    elif colours not in names and colours in dict(COLOURS):
        colours = names[[colour for colour, label in COLOURS].index(colours)]
    if colours not in names:
        return False
    STYLE.clear()
    STYLE.update(entry, name=style, scheme=colours, value="%s-%s" % (style, colours))
    STYLE.update(dict(entry["schemes"])[colours])
    return True


setStyle(STYLE_FIRST)


## Where the colours of the style of now stand in COLOURS.
def colourPlace():
    return [scheme for scheme, changes in STYLE["schemes"]].index(STYLE["scheme"])


## What the style of now shows as: the label of the style, and of its colours.
def styleLabel():
    return "%s - %s" % (STYLE["label"], COLOURS[colourPlace()][1])


## Whether a frame that many cells wide, with that title in its middle, has the icons of the
## style of now ("icons") in its top border: where the title fits whole between them, its
## blanks and a line at each side; else the title has the room, and the icons give way.
def iconsFit(width, title):
    if not STYLE.get("icons"):
        return False
    close, zoom = styleMark("icons")
    return textWidth(title) + 2 + 2 * (textWidth(close) + 2) <= width


## A mark of the drawing in the style of now: its own (STYLE_MARKS), else that of MARKS. On a
## terminal that is not UTF-8 that of MARKS, which plainMarks() made of one byte.
def styleMark(name):
    if MARKS["plain"]:
        return MARKS[name]
    return STYLE_MARKS.get(STYLE.get("marks"), {}).get(name, MARKS[name])


## Whether the style of now draws by that feature of its entry of STYLES, with that value: on
## a terminal that is UTF-8 alone, where the marks of the feature can be shown.
def styleDraws(feature, value=True):
    return not MARKS["plain"] and STYLE.get(feature) == value


## The marks of a box, a menu or a dialog, in the style of now, as eight: its corner at the
## top left, its top, its corner at the top right, its left, its right, its corners and its
## line at the bottom. A rim of half blocks where the style draws edges of blocks, else its
## frame of that name, the one line at both its sides and at its top and its bottom.
def boxMarks(name):
    if styleDraws("edges", "blocks"):
        return styleMark("rim")
    frame = styleMark(name)
    return frame[0] + frame[1] + frame[2] + frame[3] + frame[3] + frame[4] + frame[1] + frame[5]


## A slim shadow of a box, of quarter and half blocks in that look: half a cell wide at its
## right, from half a line under its top, and half a line deep under it, from half a cell
## after its left. A mark that is empty is not drawn: what lies there stays. Without its
## `corner` its corner at the top right is not drawn either, and what lies there stays: its
## side starts on the line under, as Turbo Vision's shadow does. Nothing of it below the line
## `last`, or past the column `columns`.
def drawSlimShadow(surface, box, last, columns, look, corner=True):
    left, top, width, height = box
    marks = styleMark("shadow")
    if left + width < columns:
        if corner:
            surface.put(top, left + width, marks[0], look)
        for line in range(top + 1, min(top + height, last + 1)):
            surface.put(line, left + width, marks[1], look)
    if top + height <= last:
        if marks[2]:
            surface.put(top + height, left, marks[2], look)
        surface.put(top + height, left + 1, marks[3] * (width - 1), look)
        if left + width < columns:
            surface.put(top + height, left + width, marks[4], look)


## A slim shadow of a box as Turbo Vision draws that of a raised button, with the style's
## marks of a shadow in the order of drawSlimShadow's, each a block on the cell's bottom edge:
## its corner at the top right the shadow over what it falls on, in the look `side`, and the
## rest the other way round, in that look: the shadow is the ground of those cells, and the
## block of each what it falls on. A terminal may draw a block of its font short of the cell's
## height, but one on the bottom edge reaches it, and a ground fills the whole cell: so the
## part beside the box and the part under it meet across the line between them. Its corner
## at the bottom left, what it falls on alone, is left as it is, and so is all of it on a
## terminal that is not UTF-8, where there is no block. Nothing of it below the line `last`,
## or past the column `columns`.
def drawGroundShadow(surface, box, last, columns, look, side):
    if MARKS["plain"]:
        return
    left, top, width, height = box
    marks = styleMark("shadow")
    if left + width < columns:
        surface.put(top, left + width, marks[0], side)
        for line in range(top + 1, min(top + height, last + 1)):
            surface.put(line, left + width, marks[1], look)
    if top + height <= last:
        surface.put(top + height, left + 1, marks[3] * (width - 1), look)
        if left + width < columns:
            surface.put(top + height, left + width, marks[4], look)


## The shadow of a box as Turbo Vision draws one: two cells wide at its right, from the line
## under its top, and a line deep under it, from two cells after its left. What lies there
## keeps its characters and is drawn again in that look (the surface's shade). Nothing of it
## below the line `last`, or past the column `columns`.
def drawDimShadow(surface, box, last, columns, look):
    left, top, width, height = box
    side = min(2, columns - left - width)
    for line in range(top + 1, min(top + height, last + 1)):
        if side > 0:
            surface.shade(line, left + width, side, look)
    if top + height <= last:
        surface.shade(top + height, left + 2, min(width, columns - left - 2), look)


