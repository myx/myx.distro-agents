##
## AgentsManagerScreen.Mouse.py -- the mouse: where a click lands and what it does.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the mouse ----

## The engine notes each thing it draws that a click can mean: its rectangle and what it
## stands for, a window, a row of the list, a half of a scroll bar, a menu of the bar, an
## item of the open menu, a key of the status line, the open dialog and its fields, its
## options and its buttons. A click is looked up in what the last drawing noted, the thing
## drawn last first, so there is no table of places beside the declaration.
def spot(state, left, top, width, height, what):
    state.spots.append((left, top, width, height, what))


## What was drawn at that cell, of those sorts or of any, or None.
def spotAt(state, column, line, sorts=None):
    for left, top, width, height, what in reversed(state.spots):
        if left <= column < left + width and top <= line < top + height and (sorts is None or what[0] in sorts):
            return what
    return None


## The bit of the wheel turned down, for a Python whose curses does not name it.
WHEEL_DOWN = 0x200000


## What the terminal reported of the mouse, as a key of the screen, `MOUSE:<what>:<column>:<line>`,
## or None for what the screen does not act on. The first button let go, or pressed and
## let go as one click, is `click`: a press alone is `press`, which is nothing but on the
## border between the windows (splitMouse), so one click of the hand is one click here
## however the terminal reports it. A double click is `double`, and the wheel is `up`
## and `down`. `buttons` are the bits curses gives.
def mouseKey(column, line, buttons):
    names = (("click", ("BUTTON1_RELEASED", "BUTTON1_CLICKED")), ("double", ("BUTTON1_DOUBLE_CLICKED",)),
             ("up", ("BUTTON4_PRESSED",)), ("down", ("BUTTON5_PRESSED",)), ("press", ("BUTTON1_PRESSED",)))
    for what, bits in names:
        if any(buttons & getattr(curses, bit, WHEEL_DOWN if bit == "BUTTON5_PRESSED" else 0) for bit in bits):
            return "MOUSE:%s:%d:%d" % (what, column, line)
    return None


## The key a status line shows under that name, or None for a pair of keys shown as one.
def keyOfShown(shown):
    for key, word in keyWords().items():
        if word == shown:
            return key
    if shown == "Space":
        return " "
    if shown.startswith("Alt-"):
        return "ALT-" + shown[4:].lower()
    if len(shown) == 2 and shown.startswith("^"):
        return "CTRL-" + shown[1:].lower()
    return None if "/" in shown else shown


## The mouse on the border between the windows, with no dialog and no menu open. Gives
## whether the event was the border's. A terminal that reports the button going down and
## coming up drags it: pressed on the border and let go in another column, the border is
## put there. One that reports clicks alone, and a click on the border that goes nowhere,
## takes hold of it: the next click in a window puts it there, and a click on the border
## again, or any key, lets it go where it was. A press anywhere else is nothing.
def splitMouse(state, what, column, line, layout):
    onBorder = spotAt(state, column, line, ("split",)) is not None
    if what == "press":
        if onBorder:
            state.splitHeld = "pressed"
        return True
    if state.splitHeld is None and not onBorder:
        return False
    state.noticeOf = None
    if onBorder and state.splitHeld != "held":
        state.splitHeld = "held"
        state.notice = "the border is held: click where it goes, or on it to let it go"
        return True
    state.splitHeld = None
    if onBorder:
        state.notice = ""
        return True
    if not 1 <= line <= layout["lines"] - 2:
        return False
    placeSplit(state, layout, column)
    return True


## One event of the mouse, on the state alone. It does nothing the keys cannot do. A key
## of the status line does what that key does, in every state. With a dialog open: a button
## is pressed, a box toggled, a radio button or a row of a list chosen, a field given the
## keys, the wheel scrolls its text, and a click outside it does nothing. With a menu open:
## an item is chosen, a name of the bar opens that menu or closes its own, and a click
## anywhere else closes the menu. Else: a name of the menu bar opens that menu; a window
## gets the keys; a row of the list is selected, and opened as Enter opens it when it was
## selected already or the click is a double one; a half of the scroll bar pages; and the
## wheel moves in the window under the pointer.
def mouseEvent(state, what, column, line, layout):
    if (what in ("press", "click", "double") and state.dialog is None and state.menu is None
            and splitMouse(state, what, column, line, layout)):
        return
    if what == "press":
        return
    clicked = what in ("click", "double")
    step = 1 if what == "down" else -1
    key = spotAt(state, column, line, ("key",))
    if key is not None and clicked:
        if keyOfShown(key[1]) is not None:
            handleKey(state, keyOfShown(key[1]), layout)
        return
    if state.dialog is not None:
        dialog = state.dialog
        if not clicked:
            for held in dialog["controls"]:
                if held["kind"] == "text":
                    held["top"] = max(0, held["top"] + step)
                    textFollows(held)
                    break
            return
        hit = spotAt(state, column, line, ("button", "option", "field", "close"))
        if hit is None:
            return
        if hit[0] == "close":
            ## the box that closes it, in its top border, does what Esc does
            dialogKey(state, "ESC")
            return
        stops = dialogStops(dialog)
        if hit[0] == "button":
            dialog["focus"] = stops.index(("button", hit[1]))
            pressButton(state, dialog["buttons"][hit[1]][0])
            return
        control = dialog["controls"][hit[1]]
        dialog["focus"] = stops.index(("control", hit[1]))
        if hit[0] == "option":
            control["at"] = hit[2]
            chosen = control["options"][hit[2]][0]
            if control["kind"] != "checks":
                control["value"] = chosen
            elif chosen in control["value"]:
                control["value"].remove(chosen)
            else:
                control["value"].append(chosen)
        return
    if state.menu is not None:
        if not clicked:
            return
        hit = spotAt(state, column, line, ("item", "menu"))
        if hit is None or (hit[0] == "menu" and hit[1] == state.menu["menu"]):
            state.menu = None
        elif hit[0] == "menu":
            openMenu(state, hit[1])
        else:
            state.menu["item"] = hit[1]
            chooseItem(state, menuItems(state, MENUS[state.menu["menu"]][0])[hit[1]], layout)
        return
    if not clicked:
        ## the window under the pointer, or the active one where the pointer is not known
        window = spotAt(state, column, line, ("window",)) or ("window", state.focus)
        if window[1] == "list":
            moveSelection(state, listRowsHeight(state, layout), step)
        else:
            scrollView(state, viewScrollHeight(state, layout), step * 3)
        return
    hit = spotAt(state, column, line)
    if hit is None:
        return
    if hit[0] == "menu":
        openMenu(state, hit[1])
    elif hit[0] == "window":
        state.focus = hit[1]
    elif hit[0] == "bar":
        ## a half of the scroll bar of a window pages in that window
        state.focus = hit[2]
        if hit[2] == "list":
            moveSelection(state, listRowsHeight(state, layout), 0, hit[1])
        else:
            scrollView(state, viewScrollHeight(state, layout), 0, hit[1])
    elif hit[0] == "row":
        height = listRowsHeight(state, layout)
        index = cursorOf(state, levelRows(state), height)["index"]
        again = what == "double" or (state.focus == "list" and index == hit[1])
        state.focus = "list"
        moveSelection(state, height, hit[1] - index)
        if again:
            command = commandOfKey(state, "ENTER")
            if command is not None:
                runCommand(state, command, layout, "ENTER")

