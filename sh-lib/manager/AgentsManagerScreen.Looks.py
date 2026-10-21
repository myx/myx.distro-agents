##
## AgentsManagerScreen.Looks.py -- the looks: the numbers and the colours of a cell, the sets of them each style names, the marks and the looks of a state.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## How a text is drawn. The first four are the looks every terminal has, and what the rows
## and the lines of a window are drawn in. After them come the parts of the frame of the
## screen. Each has in LOOKS, at its number: the letter a test reads a cell's look back
## as; the look it takes on a terminal with no colours, "B" bold, "R" reverse, "D" dim,
## two of them together where two are named; and where the terminal has eight colours its
## text, its ground, and whether the text is bright. A surface maps them to what its
## terminal has (CursesSurface).
PLAIN, BOLD, REVERSE, DIM = 0, 1, 2, 3
DESKTOP, BAR, BAR_HOT, BAR_AT, BAR_ON, BAR_ON_HOT, BAR_OFF, FRAME_ON, FRAME, SCROLL, SHADOW = 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
BOX, BOX_FRAME, BOX_FIELD, BOX_ON, BOX_BUTTON, BOX_BUTTON_ON, BOX_SAYS = 15, 16, 17, 18, 19, 20, 21
FOLDER = 22
LEVEL_OK, LEVEL_WARN, LEVEL_BAD = 23, 24, 25
TITLE_ON, TITLE, SHADE, BOX_SHADE = 26, 27, 28, 29
EDGE_ON, EDGE_ON_SHADE, EDGE, EDGE_SHADE, TRACK, THUMB, KEY_CHIP = 30, 31, 32, 33, 34, 35, 36
BOX_BUTTON_DEF, ALERT, ALERT_FRAME, ALERT_HEAD, ALERT_SHADE = 37, 38, 39, 40, 41
BOX_EDGE = 42
ROW, ROW_ALT, ROW_HEAD, ROW_LINE = 43, 44, 45, 46
LOOKS = (
    ## the text of a window; what stands out in it; the row the selection is on; what is of less weight
    (".", "", "white", "blue", False),
    ("B", "B", "white", "blue", True),
    ("R", "R", "black", "cyan", False),
    ("D", "D", "cyan", "blue", False),
    ## the desktop under the windows
    ("d", "D", "blue", "white", False),
    ## the menu bar, the status line and a pull-down menu; a hot letter or a key in them;
    ## the `@` between the workspace and the machine; the menu that is open and the item
    ## the bar is on, and a hot letter there; an item that does not apply
    ("m", "R", "black", "white", False),
    ("h", "RB", "red", "white", False),
    ("@", "RB", "blue", "white", False),
    ("o", "", "black", "green", False),
    ("O", "B", "red", "green", False),
    ("x", "RD", "black", "white", True),
    ## the frame of the active window, with its title, and of another, which is paler, as
    ## the frame of every window is behind a dialog; a scroll bar
    ("F", "B", "white", "blue", True),
    ("f", "", "cyan", "blue", False),
    ("s", "", "blue", "cyan", False),
    ## the shadow of what lies over the desktop: a menu, a dialog
    ("w", "D", "black", "black", True),
    ## a dialog: its text; its frame with its title; a field to type in or to pick from; the
    ## control, or the item of one, that has the keys; a button, a bar of its own colour where
    ## there are colours and plain as the text of the dialog where there are none, and the one
    ## that has the keys, the only one in a look of its own; what the dialog refuses
    ("g", "R", "black", "white", False),
    ("G", "RB", "white", "white", True),
    ("i", "", "white", "blue", False),
    ("I", "B", "white", "cyan", True),
    ("b", "R", "black", "green", False),
    ("n", "B", "white", "green", True),
    ("!", "RB", "red", "white", False),
    ## the mark of a folder after the name of a row that Enter enters
    ("e", "B", "yellow", "blue", True),
    ## a figure of the dashboard by its level: one that is well, one to look at, one that is bad
    ("k", "", "green", "blue", True),
    ("W", "B", "yellow", "blue", True),
    ("X", "RB", "white", "red", True),
    ## the title in the top border of the active window and of a dialog, and of another
    ## window, where a style sets it apart from its frame (STYLES "titles"); the slim shadow
    ## of a menu or a dialog over a window, and of a raised button inside a dialog ("shadow"),
    ## that under a button here the other way round, as Turbo Vision draws it (drawGroundShadow):
    ## the colour of the dialog on the black of the shadow
    ("T", "R", "white", "blue", True),
    ("t", "", "cyan", "blue", False),
    ("z", "D", "black", "blue", False),
    ("Z", "D", "white", "black", False),
    ## where a style draws the edges of a window of blocks (STYLES "edges"): the thin line of
    ## the active window on its own colour, at its bottom, and on the desktop, over it; the
    ## same of another window; the track of a slim scroll bar, the ground of its cells, the look
    ## too of its arrows and thumb in a window that is not active, and its thumb, a mark on it;
    ## a key of the status line as a chip ("chips")
    ("E", "", "white", "blue", True),
    ("V", "", "white", "black", True),
    ("a", "D", "black", "blue", False),
    ("v", "D", "cyan", "black", False),
    ("|", "D", "black", "cyan", False),
    ("#", "R", "black", "white", False),
    ("K", "R", "black", "yellow", False),
    ## the default button where the keys are on another, where a style marks it by its look
    ## ("buttons" "bars"); a dialog of what was refused or failed, where a style draws it in
    ## the looks of its level ("levels"): its text, its frame, its title, its shadow
    ("N", "RB", "blue", "white", False),
    ("r", "R", "white", "red", True),
    ("q", "RB", "white", "red", True),
    ("Y", "RB", "yellow", "red", True),
    ("y", "D", "black", "red", False),
    ## the thin line at the foot of a dialog, where a style draws edges of blocks: in the colour
    ## of the ground of its title tab, on the dialog's own
    ("L", "RB", "white", "white", True),
    ## a row of a table of the left pane (paneTable), and every other row (THE TABLE COLOUR RULE,
    ## below): the same text, always, and a ground of its own where the colours name one
    ("c", "", "white", "blue", False),
    ("j", "", "white", "blue", False),
    ## the header of such a table, the names of its columns, a little apart from its rows
    ("u", "B", "yellow", "blue", True),
    ## the last line of a row of such a table, underlined where the terminal has it (LINED_LOOKS),
    ## in colours that name no ground of their own for every other row, the lines wrapped
    ("l", "", "white", "blue", False),
)
## A cell of a table with a look of its own, a state, is drawn on the ground of its row (THE TABLE
## COLOUR RULE, below): on a row of the ground of ROW_ALT, that look LOOK_ALT numbers on; on the
## underlined last line of a row, that look LOOK_LINE numbers on. Each keeps the letter, the look with
## no colours, the text and the brightness of the look it is of. The first takes the ground of ROW_ALT
## where the ground of that look is the ground of PLAIN: a ground that is the meaning of a look,
## the red of a bad state, stays. The second is underlined (LINED_LOOKS).
LOOK_ALT, LOOK_LINE = len(LOOKS), 2 * len(LOOKS)
LOOKS = LOOKS + tuple(look if look[3] != LOOKS[PLAIN][3] else look[:3] + (LOOKS[ROW_ALT][3], look[4]) for look in LOOKS) + LOOKS
## THE TABLE COLOUR RULE. Each set of colours of a style names a ground for every other row
## of a table (ROW_ALT) close to that of a row (ROW), or names none. The other rows differ
## from a row only in that ground, never in their text, its colour, its brightness or its
## look with no colours: the text carries what the content means, and nothing else. Where the
## colours name none (rowsApart), the ground never changes; with the lines of the pane wrapped
## each row whose content wraps is underlined instead, on its bottom line, the header too (ROW_LINE),
## where the terminal underlines, and a row of one line is not; with them not wrapped, a row a
## line, nothing marks the rows. A terminal of eight colours
## has not the shades the two are told apart by: there the colours of every style name none.
## The looks a surface underlines, where its terminal has underline.
LINED_LOOKS = (ROW_LINE,) + tuple(range(LOOK_LINE, LOOK_LINE + LOOK_ALT))
## The letter a look without colours reads back as.
MONO_LETTERS = {"": ".", "B": "B", "R": "R", "D": "D", "RB": "H", "RD": "d"}
## The colours of a style that has its own (STYLES "looks"), for each look of LOOKS by its
## number; the letter and the look with no colours stay those of LOOKS. Each gives, for a
## terminal of eight or sixteen colours, its text, its ground and whether the text is bright,
## as LOOKS does; and for one of 256 colours (curses.COLORS) the exact shades of its text
## and its ground, by their numbers in the terminal's own palette, the cube of 6x6x6 (16
## to 231) and the ramp of greys (232 to 255), and whether the text is bold. The palette
## of the terminal is never changed, and no colour of 24 bits is asked for.
STYLE_LOOKS = {
    ## Magic in its blue colours (nu-blue), those of the pictures of the Norton Utilities on blue
    ## (the About box of 7.0, the Disk Editor, Calibrate's window and alert): windows of periwinkle blue on a dark grey desktop, white
    ## text and yellow for what stands out, the active one in a thin white line at its top and
    ## bottom and another in a dark one, black shadows, a scroll bar on that black, its arrows and thumb white, grey in another window; a light grey menu bar (cyan on eight colours),
    ## apart from the white title strip under it, with red hot letters,
    ## the open menu in reverse; cyan dialogs with black text, a white title strip, their thin outline white as it,
    ## light grey buttons with the default's text in red, the one with the keys white; amber
    ## keys in the status line; dark red with a yellow title for what was refused or failed.
    "nu-blue": {
        PLAIN: ("white", "blue", False, 231, 63, False),
        BOLD: ("yellow", "blue", True, 228, 63, True),
        REVERSE: ("black", "cyan", False, 16, 87, False),
        DIM: ("cyan", "blue", False, 189, 63, False),
        DESKTOP: ("black", "black", True, 240, 238, False),
        BAR: ("black", "cyan", False, 16, 252, False),
        BAR_HOT: ("red", "cyan", False, 124, 252, True),
        BAR_AT: ("blue", "cyan", False, 21, 252, False),
        BAR_ON: ("white", "black", True, 231, 16, True),
        BAR_ON_HOT: ("red", "black", True, 203, 16, True),
        BAR_OFF: ("black", "cyan", True, 245, 252, False),
        FRAME_ON: ("white", "blue", True, 231, 63, True),
        FRAME: ("cyan", "blue", False, 104, 63, False),
        SCROLL: ("white", "black", True, 231, 16, True),
        SHADOW: ("black", "black", False, 16, 16, False),
        BOX: ("black", "cyan", False, 16, 87, False),
        BOX_FRAME: ("black", "cyan", False, 16, 87, False),
        BOX_FIELD: ("blue", "cyan", False, 18, 87, False),
        BOX_ON: ("white", "blue", True, 231, 18, True),
        BOX_BUTTON: ("black", "white", False, 16, 252, False),
        BOX_BUTTON_ON: ("white", "blue", True, 160, 231, True),
        BOX_SAYS: ("red", "cyan", False, 124, 87, True),
        FOLDER: ("yellow", "blue", True, 228, 63, True),
        LEVEL_OK: ("green", "blue", True, 120, 63, True),
        LEVEL_WARN: ("yellow", "blue", True, 221, 63, True),
        LEVEL_BAD: ("white", "red", True, 231, 160, True),
        TITLE_ON: ("blue", "white", False, 18, 231, True),
        TITLE: ("black", "cyan", False, 17, 104, False),
        SHADE: ("blue", "black", False, 63, 16, False),
        BOX_SHADE: ("cyan", "black", False, 87, 16, False),
        EDGE_ON: ("white", "blue", False, 231, 63, False),
        EDGE_ON_SHADE: ("white", "black", False, 231, 238, False),
        EDGE: ("black", "blue", False, 16, 63, False),
        EDGE_SHADE: ("black", "black", True, 16, 238, False),
        TRACK: ("white", "black", False, 244, 16, False),
        THUMB: ("white", "black", True, 231, 16, False),
        KEY_CHIP: ("black", "yellow", False, 16, 214, True),
        BOX_BUTTON_DEF: ("red", "white", False, 160, 252, True),
        ALERT: ("white", "red", True, 231, 124, False),
        ALERT_FRAME: ("white", "red", True, 231, 124, True),
        ALERT_HEAD: ("yellow", "red", True, 226, 124, True),
        ALERT_SHADE: ("red", "black", False, 124, 16, False),
        BOX_EDGE: ("white", "cyan", False, 231, 87, False),
        ROW: ("white", "blue", False, 231, 63, False),
        ROW_ALT: ("white", "blue", False, 231, 62, False),
        ROW_HEAD: ("yellow", "blue", True, 228, 61, True),
    },
    ## Magic in its grey colours (nu-gray), those of the picture on grey (the Disk Doctor): the
    ## dark grey desktop, windows of the deep blue of the scroll bars with white text and yellow
    ## for what stands out, periwinkle dialogs with a white title strip and their thin outline white as it, grey bars for
    ## buttons, the one with the keys white with blue text, the selection a white bar with blue
    ## text, a white menu bar, red keys in the status line, the dark red alert.
    "nu-gray": {
        PLAIN: ("white", "blue", True, 231, 19, False),
        BOLD: ("yellow", "blue", True, 228, 19, True),
        REVERSE: ("blue", "white", False, 19, 231, True),
        DIM: ("cyan", "blue", False, 147, 19, False),
        DESKTOP: ("black", "black", True, 240, 238, False),
        BAR: ("black", "white", False, 16, 252, False),
        BAR_HOT: ("red", "white", False, 124, 252, True),
        BAR_AT: ("blue", "white", False, 19, 252, False),
        BAR_ON: ("white", "black", True, 252, 16, True),
        BAR_ON_HOT: ("red", "black", True, 203, 16, True),
        BAR_OFF: ("black", "white", True, 245, 252, False),
        FRAME_ON: ("white", "blue", True, 231, 19, True),
        FRAME: ("cyan", "blue", False, 103, 19, False),
        SCROLL: ("white", "black", True, 231, 16, True),
        SHADOW: ("black", "black", False, 16, 16, False),
        BOX: ("white", "blue", True, 231, 63, False),
        BOX_FRAME: ("black", "blue", False, 16, 63, False),
        BOX_FIELD: ("cyan", "blue", False, 87, 63, False),
        BOX_ON: ("blue", "white", False, 19, 231, True),
        BOX_BUTTON: ("black", "white", False, 16, 250, False),
        BOX_BUTTON_ON: ("black", "cyan", False, 21, 231, True),
        BOX_SAYS: ("yellow", "blue", True, 228, 63, True),
        FOLDER: ("yellow", "blue", True, 228, 19, True),
        LEVEL_OK: ("green", "blue", True, 120, 19, True),
        LEVEL_WARN: ("yellow", "blue", True, 221, 19, True),
        LEVEL_BAD: ("white", "red", True, 231, 160, True),
        TITLE_ON: ("blue", "white", False, 19, 231, True),
        TITLE: ("black", "cyan", False, 236, 244, False),
        SHADE: ("blue", "black", False, 19, 16, False),
        BOX_SHADE: ("blue", "black", False, 63, 16, False),
        EDGE_ON: ("white", "blue", False, 231, 19, False),
        EDGE_ON_SHADE: ("white", "black", False, 231, 238, False),
        EDGE: ("black", "blue", False, 16, 19, False),
        EDGE_SHADE: ("black", "black", True, 16, 238, False),
        TRACK: ("white", "black", False, 244, 16, False),
        THUMB: ("white", "black", True, 231, 16, False),
        KEY_CHIP: ("white", "red", True, 231, 124, True),
        BOX_BUTTON_DEF: ("blue", "white", False, 19, 250, True),
        ALERT: ("white", "red", True, 231, 124, False),
        ALERT_FRAME: ("white", "red", True, 231, 124, True),
        ALERT_HEAD: ("yellow", "red", True, 226, 124, True),
        ALERT_SHADE: ("red", "black", False, 124, 16, False),
        BOX_EDGE: ("white", "blue", False, 231, 63, False),
        ROW: ("white", "blue", True, 231, 19, False),
        ROW_ALT: ("white", "blue", True, 231, 18, False),
        ROW_HEAD: ("yellow", "blue", True, 228, 17, True),
    },
}
## Magic in the terminal's own colours (nu-system): its own choice of the eight named ones, those
## of its blue plan (blue windows on a black desktop, cyan dialogs, a cyan bar with red hot letters,
## black shadows), as the terminal draws them, on a terminal of 256 colours too.
STYLE_LOOKS["nu-system"] = dict((look, own[:3] + (None, None, False)) for look, own in STYLE_LOOKS["nu-blue"].items())
## Turbo Vision in exact shades, each the shade of the colour of the PC it was drawn in: the
## black, blue, green, cyan, red and greys of that palette are 16, 19, 34, 37, 124, 248 and
## 240 of the terminal's, its bright green, cyan, yellow and white 83, 87, 227 and 231.
## "tv-blue", as its editor: blue windows with yellow text and a white frame, a grey bar
## with red keys, grey dialogs with green buttons, a cyan bar on the selection.
STYLE_LOOKS["tv-blue"] = {
    PLAIN: ("yellow", "blue", True, 227, 19, False),
    BOLD: ("white", "blue", True, 231, 19, False),
    REVERSE: ("black", "cyan", False, 16, 37, False),
    DIM: ("white", "blue", False, 248, 19, False),
    DESKTOP: ("blue", "white", False, 19, 248, False),
    BAR: ("black", "white", False, 16, 248, False),
    BAR_HOT: ("red", "white", False, 124, 248, False),
    BAR_AT: ("blue", "white", False, 19, 248, False),
    BAR_ON: ("black", "green", False, 16, 34, False),
    BAR_ON_HOT: ("red", "green", False, 124, 34, False),
    BAR_OFF: ("black", "white", True, 240, 248, False),
    FRAME_ON: ("white", "blue", True, 231, 19, False),
    FRAME: ("white", "blue", False, 248, 19, False),
    SCROLL: ("blue", "cyan", False, 19, 37, False),
    SHADOW: ("black", "black", True, 240, 16, False),
    BOX: ("black", "white", False, 16, 248, False),
    BOX_FRAME: ("white", "white", True, 231, 248, False),
    BOX_FIELD: ("white", "blue", True, 231, 19, False),
    BOX_ON: ("white", "cyan", True, 231, 37, False),
    BOX_BUTTON: ("black", "green", False, 16, 34, False),
    BOX_BUTTON_ON: ("white", "green", True, 231, 34, False),
    BOX_SAYS: ("red", "white", False, 124, 248, False),
    FOLDER: ("white", "blue", True, 231, 19, False),
    LEVEL_OK: ("green", "blue", True, 83, 19, False),
    LEVEL_WARN: ("black", "yellow", False, 16, 227, False),
    LEVEL_BAD: ("white", "red", True, 231, 124, False),
    TITLE_ON: ("white", "blue", True, 231, 19, False),
    TITLE: ("white", "blue", False, 248, 19, False),
    SHADE: ("black", "blue", False, 16, 19, False),
    BOX_SHADE: ("white", "black", False, 248, 16, False),
    ROW: ("yellow", "blue", True, 227, 19, False),
    ROW_ALT: ("yellow", "blue", True, 227, 18, False),
    ROW_HEAD: ("white", "blue", True, 231, 17, False),
}
## "tv-gray", as its demo: grey windows with black text and a white frame on the dithered
## blue and grey desktop, the same grey bar, grey dialogs with green buttons, cyan bars.
STYLE_LOOKS["tv-gray"] = {
    PLAIN: ("black", "white", False, 16, 248, False),
    BOLD: ("blue", "white", False, 19, 248, True),
    REVERSE: ("black", "cyan", False, 16, 37, False),
    DIM: ("black", "white", True, 240, 248, False),
    DESKTOP: ("blue", "white", False, 19, 248, False),
    BAR: ("black", "white", False, 16, 248, False),
    BAR_HOT: ("red", "white", False, 124, 248, False),
    BAR_AT: ("blue", "white", False, 19, 248, False),
    BAR_ON: ("black", "green", False, 16, 34, False),
    BAR_ON_HOT: ("red", "green", False, 124, 34, False),
    BAR_OFF: ("black", "white", True, 240, 248, False),
    FRAME_ON: ("white", "white", True, 231, 248, False),
    FRAME: ("black", "white", False, 16, 248, False),
    SCROLL: ("blue", "cyan", False, 19, 37, False),
    SHADOW: ("black", "black", True, 240, 16, False),
    BOX: ("black", "white", False, 16, 248, False),
    BOX_FRAME: ("white", "white", True, 231, 248, False),
    BOX_FIELD: ("white", "blue", True, 231, 19, False),
    BOX_ON: ("white", "cyan", True, 231, 37, False),
    BOX_BUTTON: ("black", "green", False, 16, 34, False),
    BOX_BUTTON_ON: ("white", "green", True, 231, 34, False),
    BOX_SAYS: ("red", "white", False, 124, 248, False),
    FOLDER: ("blue", "white", False, 19, 248, True),
    LEVEL_OK: ("green", "white", False, 28, 248, True),
    LEVEL_WARN: ("black", "yellow", False, 16, 227, False),
    LEVEL_BAD: ("white", "red", True, 231, 124, False),
    TITLE_ON: ("white", "white", True, 231, 248, False),
    TITLE: ("black", "white", False, 16, 248, False),
    SHADE: ("black", "white", False, 16, 248, False),
    BOX_SHADE: ("white", "black", False, 248, 16, False),
    ROW: ("black", "white", False, 16, 248, False),
    ROW_ALT: ("black", "white", False, 16, 250, False),
    ROW_HEAD: ("blue", "white", False, 19, 246, True),
}
## Basic B/W in colours of its own, each look by how it is drawn with no colours (the second
## field of LOOKS): "bw-dark" white on black, "bw-light" black on white, in greys alone.
BW_SHADES = {
    "bw-dark": {"": ("white", "black", False, 252, 16, False), "B": ("white", "black", True, 231, 16, True),
                "R": ("black", "white", False, 16, 252, False), "D": ("white", "black", False, 244, 16, False),
                "RB": ("black", "white", False, 16, 231, True), "RD": ("black", "white", False, 240, 252, False)},
    "bw-light": {"": ("black", "white", False, 16, 231, False), "B": ("black", "white", True, 16, 231, True),
                 "R": ("white", "black", True, 231, 16, False), "D": ("black", "white", False, 244, 231, False),
                 "RB": ("white", "black", True, 231, 16, True), "RD": ("white", "black", False, 250, 16, False)},
}
for bwName, bwShades in BW_SHADES.items():
    STYLE_LOOKS[bwName] = dict((number, bwShades[look[1]]) for number, look in enumerate(LOOKS))
## The underlined last line of a row is a row in every set of colours: only its line is its own.
## So are the looks of a cell on a row of the ground of ROW_ALT and on that line (LOOK_ALT, LOOK_LINE).
for ownLooks in STYLE_LOOKS.values():
    if ROW in ownLooks:
        ownLooks[ROW_LINE] = ownLooks[ROW]
        for number in range(LOOK_ALT):
            own = ownLooks.get(number)
            if own is not None:
                same = own[1] == ownLooks[PLAIN][1] and own[4] == ownLooks[PLAIN][4]
                ownLooks[LOOK_ALT + number] = own[:1] + (ownLooks[ROW_ALT][1], own[2], own[3], ownLooks[ROW_ALT][4], own[5]) if same else own
                ownLooks[LOOK_LINE + number] = own

## The marks of the drawing. plainMarks() changes them for a terminal that is not UTF-8.
## A frame is its corner at the top left, its line across, its corner at the top right,
## its line down, and its corners at the bottom; "rule" is the line that parts two groups
## of a menu, with its ends.
MARKS = {"separator": "│", "cut": "…", "plain": False,
         "frame": "┌─┐│└┘", "frameOn": "╔═╗║╚╝", "rule": "├─┤", "shade": "░", "system": "≡",
         "barUp": "▲", "barDown": "▼", "barTrack": "▒", "barThumb": "■", "on": "•",
         ## the thumb of a scroll bar in a window that is not active, where a style marks it apart
         "barThumbOff": "■",
         ## what stands inside the brackets of the button Enter presses where the keys are on no button
         "default": "»«",
         ## what stands at the right edge of a row that Enter dives into, a folder (a row whose
         ## Enter opens a dialog has "dialog" after its name): never what is cut
         "folder": "►", "dialog": "...",
         ## a box that is ticked and one that is not, a radio button that is chosen and one that
         ## is not; what stands at each side of a title in a frame that is not active, and in one
         ## that is; a slim shadow: its corner at the top right, its side, its corner at the bottom
         ## left, its line under, its corner at the bottom right
         "checks": ("[X] ", "[ ] "), "radios": ("(*) ", "( ) "), "title": (" ", " "), "titleOn": (" ", " "),
         "shadow": "▖▌▝▀▘",
         ## where a style draws edges of blocks (STYLES "edges"): the outline of a window, a menu and
         ## a dialog, its corner at the top left, its top, its corner at the top right, its left, its
         ## right, its corners and its line at the bottom: a thin line on the bottom edge of its top
         ## line, drawn on what lies outside it, and of its last line, on its own colour, and no mark
         ## at its sides, where the change of colour is the edge. Only a block that stands on the
         ## bottom edge of its cell meets the next one whole on some terminals, whose font draws a block
         ## short of the cell: one that must reach the top or a side of its cell shows a gap there
         "rim": "▁▁▁  ▁▁▁",
         ## inside the ends of the button that has the keys, where buttons are bars ("buttons");
         ## a field to type in, its brackets and what fills its room ("fields" "bracketed")
         "focus": ("►", "◄"), "field": "[.]",
         ## the icons in the top border of a frame that has them (STYLES "icons"): the box that
         ## closes, at its left, and the one that zooms, at its right
         "icons": ("[■]", "[↕]")}
## The marks of a style that has its own (STYLES "marks"), where they are not those of MARKS:
## on a terminal that is not UTF-8 the marks of MARKS stand (plainMarks), in every style.
STYLE_MARKS = {
    ## Magic: outlines (MARKS "rim"), a line between two groups of a menu from side to side, a
    ## slim scroll bar in the cells of the shadow, its thumb ▍ on its track (▎ in a window that is
    ## not active), with an arrow at each end, a tick and a dot for
    ## what is chosen and a faint dot for what is not, and a shadow a cell wide at the right of
    ## a box and half a line deep under it: drawn in a look whose ground is the black of the
    ## shadow and whose text is the colour under it, so the black of each cell is its ground,
    ## which joins the next line's with no gap, and the lower half block on the bottom edge of
    ## a cell under it draws what lies under; the corner under its left is left as it lies
    "magic": {"rule": " ─ ", "barUp": "↑", "barDown": "↓", "barTrack": " ", "barThumb": "▍", "barThumbOff": "▎",
              "checks": ("✓ ", "· "), "radios": ("• ", "· "), "shadow": (" ", " ", "", "▄", "▄")},
    ## Turbo Vision: the shadow of a raised button (drawGroundShadow): ▅ beside its face, the
    ## shadow over the dialog, and ▅ under it from one cell after its left, the dialog over the
    ## shadow, its side the shadow alone and its corner at the bottom left the dialog alone;
    ## and a radio button chosen with its dot
    "tv": {"shadow": "▅  ▅▅", "radios": ("(•) ", "( ) ")},
}
MARK_SELECTED = ">"
MARK_READING = "~"
MARK_OLD = "!"
## What a window says while it waits for its first rows, its name in it, in a pale look.
## One that was read and holds nothing, and one whose read failed, keep their own words.
POPULATING = "Populating %s..."
## The narrow column at the right end of a row of the list, after its tail: what the row
## carries under "wide", a session the total of its tokens. Shown where a row has that
## many cells, and that many cells wide, its figures one under another.
LIST_WIDE = {"from": 34, "cells": 6}
## How a state shows where the left pane sets one out, in a cell of a table or as the value
## of a fact (stateLook): by the words the operations print, the look of what is well, of
## what to look at, of what is bad, and dim for what is over. A word not named here is
## drawn as the text around it. STATE_RANKS: the order of those looks, the worst last,
## which the worst word of a text gives it.
STATE_LOOKS = {
    "running": LEVEL_OK, "working": LEVEL_OK, "alive": LEVEL_OK, "present": LEVEL_OK, "ok": LEVEL_OK, "startable": LEVEL_OK,
    "set": LEVEL_OK, "secret-set": LEVEL_OK, "succeeded": LEVEL_OK,
    "waiting": LEVEL_WARN, "unclosed": LEVEL_WARN, "paused": LEVEL_WARN, "warn": LEVEL_WARN, "missing": LEVEL_WARN,
    "secret-missing": LEVEL_WARN, "members": LEVEL_WARN, "not-in-registry": LEVEL_WARN,
    "fail": LEVEL_BAD, "failed": LEVEL_BAD, "gone": LEVEL_BAD, "broken": LEVEL_BAD, "not-startable": LEVEL_BAD,
    "no-process": LEVEL_BAD, "session-ended": LEVEL_BAD, "not-present": LEVEL_BAD, "x": LEVEL_BAD,
    "finished": DIM, "skipped": DIM, "never": DIM,
}
STATE_RANKS = (DIM, LEVEL_OK, LEVEL_WARN, LEVEL_BAD)
