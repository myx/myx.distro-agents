##
## AgentsManagerScreen.Dialogs.py -- the dialogs: open, close, keys, drawn.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the dialogs ----

## Opens the dialog of that name of DIALOGS over the screen: it has the keys until it is
## closed. `fill` gives its controls what the declaration cannot know, by their names:
## under "lines" the paragraphs of a text, each a text, or a pair of a name and its value,
## which are set out as the facts of the left window are; under "options" the boxes, the
## radio buttons or the rows of a list, the id of each and what it shows as; under "value"
## what a control holds at first, a text, the id that is chosen, or the ids that are
## checked. `about` is kept for its handler. `title` stands in place of the declared one.
## A dialog opened while another is open waits for that one to close.
def openDialog(state, name, fill=None, about=None, title=None):
    declared = DIALOGS[name]
    controls = []
    for control in declared["controls"]:
        held = dict(control, lines=[], options=[], value=[] if control["kind"] == "checks" else "", top=0, at=0)
        held.update((fill or {}).get(control["name"], {}))
        if name in PLACED["dialogs"] and held["lines"]:
            held["lines"] = placedParagraphs(state, held["lines"])
        ids = [option[0] for option in held["options"]]
        if control["kind"] == "checks":
            held["value"] = list(held["value"])
        elif control["kind"] in ("radios", "list") and ids:
            if held["value"] not in ids:
                held["value"] = ids[0]
            held["at"] = ids.index(held["value"])
        elif control["kind"] == "input":
            ## the cursor starts at the end of what the field holds (the sketch's 14.3); `seen`
            ## says what the field held when it was last drawn or typed in, so a value a fill
            ## puts there after it is open takes the cursor to its end, and typing does not
            held.setdefault("caret", len(held["value"]))
            held.setdefault("seen", held["value"])
        controls.append(held)
    dialog = {"name": name, "title": title or declared["title"], "controls": controls,
              "buttons": list(declared["buttons"]), "about": about or {}, "says": "", "focus": 0, "plan": None,
              "level": declared.get("level", "")}
    for place, (sort, index) in enumerate(dialogStops(dialog)):
        if sort == "control" and controls[index]["name"] == declared.get("first"):
            dialog["focus"] = place
    if state.dialog is None:
        state.dialog = dialog
        state.menu = None
    else:
        state.waiting.append(dialog)
    return dialog


## Closes the dialog that is open: the next one that waits opens, or the keys go back to
## the windows.
def closeDialog(state):
    state.dialog = state.waiting.pop(0) if state.waiting else None


## The message box: what the screen refuses, or what an operation answered when it failed,
## with its whole text under that title. `text` is one paragraph, or several as openDialog
## takes them. Gives an empty text, for a handler of an action to give back: the status
## line then says nothing, the box has said it. `level`: what the box is of, where it is
## not what its dialog declares, "" for one that tells what was asked for.
def tell(state, title, text, name="message", level=None):
    dialog = openDialog(state, name, {"text": {"lines": [text] if isinstance(text, str) else list(text)}}, title=title)
    if level is not None:
        dialog["level"] = level
    return ""


## Where the keys of a dialog can be: its controls that take them, from the top, and after
## them its buttons. Each as its sort, "control" or "button", and its place among those.
def dialogStops(dialog):
    stops = [("control", index) for index, control in enumerate(dialog["controls"])
             if CONTROL_KINDS[control["kind"]]["focus"]]
    return stops + [("button", index) for index in range(len(dialog["buttons"]))]


## What has the keys in a dialog: its kind of CONTROL_KINDS, its place among the controls
## or among the buttons, and the control itself, or None for a button.
def dialogFocus(dialog):
    sort, index = dialogStops(dialog)[dialog["focus"]]
    if sort == "button":
        return "button", index, None
    return dialog["controls"][index]["kind"], index, dialog["controls"][index]


## The control of that name of a dialog, and what it holds.
def dialogControl(dialog, name):
    for control in dialog["controls"]:
        if control["name"] == name:
            return control
    return None


def dialogValue(dialog, name):
    control = dialogControl(dialog, name)
    return control["value"] if control else None


## The first control of a dialog whose required input is not there, or None: a field that
## holds only blanks and new lines, or not the very word it must hold; boxes with none of
## their options checked.
def dialogMissing(dialog):
    for control in dialog["controls"]:
        if not control.get("required"):
            continue
        value = control["value"]
        if control.get("exactly") is not None:
            if value != control["exactly"]:
                return control
        elif isinstance(value, list):
            if not [option for option in control["options"] if option[0] in value]:
                return control
        elif not value.strip():
            return control
    return None


## The default button of a dialog, which Enter presses and which is drawn with the marks: the first, unless it would act and a required input is not there
## (what it would do is refused), and then the button that cancels. It follows what is typed, both ways.
def dialogDefaultIndex(dialog):
    if dialog["buttons"] and dialog["buttons"][0][0] != "cancel" and DIALOG_HANDLERS.get(dialog["name"]) is not None and dialogMissing(dialog) is not None:
        return next((index for index, (name, label) in enumerate(dialog["buttons"]) if name == "cancel"), 0)
    return 0


## A button of the open dialog is pressed. "cancel", and any button of a dialog that only
## says something, closes it. Any other goes to its handler: what that refuses stays in
## the dialog, which stays open; else the dialog closes. While a required input is not
## there no handler is called: the dialog says so in one line, and the keys go back to
## the control that lacks it.
def pressButton(state, buttonName):
    dialog = state.dialog
    handler = DIALOG_HANDLERS.get(dialog["name"])
    if buttonName == "cancel" or handler is None:
        closeDialog(state)
        return
    missing = dialogMissing(dialog)
    if missing is not None:
        dialog["says"] = missing["required"]
        dialog["focus"] = dialogStops(dialog).index(("control", dialog["controls"].index(missing)))
        return
    dialog["says"] = handler(state, dialog, buttonName) or ""
    if not dialog["says"] and state.dialog is dialog:
        closeDialog(state)


## The place of the cursor in a field of one line, within what the field holds: where the
## keys left it, never outside the text.
def inputCaret(control):
    return max(0, min(control.get("caret", len(control["value"])), len(control["value"])))


## One key while a dialog is open. Tab and Shift-Tab move between its controls and its
## buttons, around at the ends. Enter presses its first button, or the button the keys are
## on; in a field of several lines it is a new line. Esc closes it and does nothing. Space
## toggles a box, chooses a radio button and presses the button the keys are on; Up and
## Down move among boxes and radio buttons and pick in a list; Left and Right go from
## button to button, and in a field of one line they move its cursor, where Home and End
## take it to the ends. In a field what is typed is added where the cursor stands and
## Backspace takes the character before it away. PgUp and PgDn scroll a text longer than
## its room, and so do Up and Down wherever they mean nothing else. No key of a window, of
## a menu or of the screen works here.
def dialogKey(state, key):
    dialog = state.dialog
    extra = DIALOG_KEYS.get(dialog["name"])
    if extra is not None and key == extra[0]:
        extra[2](state, dialog)
        return
    what, index, control = dialogFocus(dialog)
    stops = dialogStops(dialog)
    if key == "ESC":
        escape = DIALOG_ESCAPES.get(dialog["name"])
        if escape is None or not escape(state, dialog):
            closeDialog(state)
    elif key in ("TAB", "BACKTAB"):
        dialog["focus"] = (dialog["focus"] + (1 if key == "TAB" else -1)) % len(stops)
    elif key == "ENTER" and what == "area":
        control["value"] += "\n"
    elif key == "ENTER" or (key == " " and what == "button"):
        pressButton(state, dialog["buttons"][index if what == "button" else dialogDefaultIndex(dialog)][0])
    elif what == "button" and key in ("LEFT", "RIGHT"):
        dialog["focus"] = len(stops) - len(dialog["buttons"]) + (index + (1 if key == "RIGHT" else -1)) % len(dialog["buttons"])
    elif what == "input" and key in ("LEFT", "RIGHT", "HOME", "END"):
        caret = inputCaret(control)
        control["caret"] = {"LEFT": max(0, caret - 1), "RIGHT": min(len(control["value"]), caret + 1),
                            "HOME": 0, "END": len(control["value"])}[key]
    elif what == "input" and key == "BACKSPACE":
        caret = inputCaret(control)
        if caret:
            control["value"] = control["value"][:caret - 1] + control["value"][caret:]
            control["caret"] = caret - 1
            control["seen"] = control["value"]
    elif what == "area" and key == "BACKSPACE":
        control["value"] = control["value"][:-1]
    elif what == "input" and len(key) == 1:
        ## a key that has a name is longer than one character: this one was typed
        caret = inputCaret(control)
        control["value"] = control["value"][:caret] + key + control["value"][caret:]
        control["caret"] = caret + 1
        control["seen"] = control["value"]
    elif what == "area" and len(key) == 1:
        ## a key that has a name is longer than one character: this one was typed
        control["value"] += key
    elif what in ("radios", "list") and control.get("digits") and key.isdigit() and key in [option[0] for option in control["options"]]:
        ## the digit of an option picks it
        control["at"] = [option[0] for option in control["options"]].index(key)
        control["value"] = key
    elif what in ("checks", "radios", "list") and key in ("UP", "DOWN") and control["options"]:
        control["at"] = max(0, min(len(control["options"]) - 1, control["at"] + (1 if key == "DOWN" else -1)))
        if what == "list":
            control["value"] = control["options"][control["at"]][0]
    elif what == "checks" and key == " " and control["options"]:
        chosen = control["options"][control["at"]][0]
        if chosen in control["value"]:
            control["value"].remove(chosen)
        else:
            control["value"].append(chosen)
    elif what == "radios" and key == " " and control["options"]:
        control["value"] = control["options"][control["at"]][0]
    elif key in ("UP", "DOWN", "PGUP", "PGDN"):
        page = max(1, (dialog["plan"] or {}).get("page", 1))
        step = (1 if key in ("DOWN", "PGDN") else -1) * (page if key.startswith("PG") else 1)
        for held in dialog["controls"]:
            if held["kind"] == "text":
                ## its end is held where it is drawn, which knows how many lines it shows
                held["top"] = max(0, held["top"] + step)
                textFollows(held)
                break


## The keys the status line names while a dialog is open: those of the control that has
## the keys, from CONTROL_KINDS, then what Enter presses, Tab where there is more than one
## place for the keys, what scrolls a text longer than its room, and Esc.
def dialogStatus(dialog):
    what, index, control = dialogFocus(dialog)
    items = [item for item in CONTROL_KINDS[what]["keys"] if what != "button" or len(dialog["buttons"]) > 1]
    if dialog["name"] in DIALOG_KEYS:
        items.append(DIALOG_KEYS[dialog["name"]][:2])
    digits = [option[0] for option in control["options"] if option[0].isdigit()] if control and control.get("digits") else []
    if digits:
        items.append((digits[0] + "-" + digits[-1] if len(digits) > 1 else digits[0], "Choose"))
    pressed = dialog["buttons"][index if what == "button" else dialogDefaultIndex(dialog)]
    if what != "area" and (pressed[0] == "cancel" or dialogMissing(dialog) is None):
        ## a button that would act is no default while a required input is not there
        items.append(("ENTER", pressed[1]))
    if len(dialogStops(dialog)) > 1:
        items.append(("TAB", "Next"))
    if (dialog["plan"] or {}).get("long"):
        items.append(("UP/DOWN" if what in ("input", "area", "button") else "PGUP/PGDN", "Scroll"))
    items.append(("ESC", dialog["about"].get("esc") or ("Cancel" if "cancel" in [button[0] for button in dialog["buttons"]] else "Close")))
    return [(keysShown(keys), word) for keys, word in items]


## The paragraphs of a text of a dialog as lines of that width: a text is broken between
## words, one that begins with a space is set out already and is broken only where it is
## full, and pairs that follow one another are set out as facts, their names in a column.
def dialogTextLines(control, width):
    if control.get("raw"):
        ## what an operation wrote: each line as it was, broken only where it is full. Each line is broken once, when it has
        ## come (or when the width has changed), whatever came or went before it: "dropped" counts the lines the front lost
        ## (the dialog keeps the last few thousand), so what is kept stays in step with the lines and not with their number.
        lines = control["lines"]
        kept = control.get("wrapped")
        if kept is not None and (kept["width"] != width or kept["first"] > control.get("dropped", 0)
                                 or control.get("dropped", 0) - kept["first"] > len(kept["pieces"])):
            kept = None
        if kept is None:
            kept = {"width": width, "first": control.get("dropped", 0), "pieces": [], "flat": None}
            control["wrapped"] = kept
        gone = control.get("dropped", 0) - kept["first"]
        if gone:
            del kept["pieces"][:gone]
            kept["first"] += gone
            kept["flat"] = None
        if len(kept["pieces"]) < len(lines):
            kept["pieces"].extend(areaLines(line, width) for line in lines[len(kept["pieces"]):])
            kept["flat"] = None
        if kept["flat"] is None:
            kept["flat"] = [part for piece in kept["pieces"] for part in piece]
        return kept["flat"]
    lines = []
    pairs = []
    for paragraph in list(control["lines"]) + [None]:
        if isinstance(paragraph, tuple):
            pairs.append(paragraph)
            continue
        if pairs:
            lines.extend(fieldLines(pairs, width))
            pairs = []
        if paragraph is not None:
            ## a line that begins with a space is set out already: it is broken only where it is full
            lines.extend(areaLines(paragraph, width) if paragraph.startswith(" ") else wrapToCells(paragraph, width))
    return lines


## What was typed into a field of several lines, as lines of that width: a new line where
## one was typed, and where a line is full.
def areaLines(text, width):
    lines = []
    for typed in text.split("\n"):
        line = ""
        used = 0
        for cluster, clusterWidth in textCells(typed):
            if used + clusterWidth > width:
                lines.append(line)
                line = ""
                used = 0
            line += cluster
            used += clusterWidth
        lines.append(line)
    return lines


## The margins of a dialog (F11.0): its frame (its shadow never counted) stands DIALOG_MARGIN_COLUMNS cells from the terminal at each side and
## DIALOG_MARGIN_LINES lines from the menu bar above and from the status line under it, wherever the terminal holds the dialog with them. Where it
## cannot, the dialog has no margin at all and uses the whole desktop, never something in between (dialogPlan). The big dialog (a command followed
## to its end) is held where the terminal gives it DIALOG_COLUMNS cells and DIALOG_BIG_LEAST_LINES lines inside its margins, and grows with the
## terminal up to DIALOG_BIG_COLUMNS by DIALOG_BIG_LINES.
DIALOG_MARGIN_COLUMNS = 4
DIALOG_MARGIN_LINES = 1
DIALOG_BIG_COLUMNS = 190
DIALOG_BIG_LINES = 56
DIALOG_BIG_LEAST_LINES = 18


## Where a dialog stands on a terminal of that size, and each of its parts in it: its box,
## in the middle of the desktop, as wide as what it holds asks for, between forty cells
## and DIALOG_COLUMNS, and never nearer the edges than its margins; how
## wide its inside is, within its margins at each side (DIALOG_SIDE); each control with the
## line of its label, its first line and how many lines it has; the lines of what it refuses
## and the line of its buttons, under them the line of their shadow in a style where they
## cast one, and the empty lines under them (DIALOG_TAIL); and the empty lines under its top
## (DIALOG_LEAD), the big dialog too. Where the terminal has not the lines for all of it, the
## empty lines under its top and under its buttons give way first, then the empty lines
## between the controls, then a text
## gives its lines, down to one, then a list of options, and last a field of several lines:
## what is cut there scrolls. "long" says that
## a text holds more than it shows, and "page" how many lines of it show.
def dialogPlan(dialog, columns, lines):
    if DIALOGS.get(dialog["name"], {}).get("big"):
        ## by the size of the terminal alone: what it holds is thousands of lines, laid out for one width only
        held = columns - 2 * DIALOG_MARGIN_COLUMNS >= DIALOG_COLUMNS and lines - 2 - 2 * DIALOG_MARGIN_LINES - 2 >= DIALOG_BIG_LEAST_LINES
        return dialogPlanAt(dialog, columns, lines, DIALOG_MARGIN_COLUMNS if held else 0, DIALOG_MARGIN_LINES if held else 0)
    held = dialogPlanAt(dialog, columns, lines, DIALOG_MARGIN_COLUMNS, DIALOG_MARGIN_LINES)
    return held if held["wide"] and held["high"] else dialogPlanAt(dialog, columns, lines, 0, 0)


## The plan of a dialog with those margins: and whether it is held in them, wide enough and high enough, as "wide" and "high".
def dialogPlanAt(dialog, columns, lines, marginColumns, marginLines):
    wanted = max(textWidth(dialog["title"]) + 2, sum(textWidth(label) + 6 for name, label in dialog["buttons"]))
    big = DIALOGS.get(dialog["name"], {}).get("big")
    ## the big dialog is as wide as the terminal whatever it holds: the lines of its text, up to thousands, are not measured at every turn
    for control in () if big else dialog["controls"]:
        wanted = max(wanted, textWidth(control.get("label", "")))
        if control["kind"] in ("input", "area"):
            wanted = max(wanted, 52)
        for paragraph in control["lines"]:
            wanted = max(wanted, 11 + textWidth(paragraph[1]) if isinstance(paragraph, tuple) else textWidth(paragraph))
        for optionId, label in control["options"]:
            wanted = max(wanted, textWidth(label) + 4)
    maxWidth = columns - 2 * marginColumns
    naturalWidth = DIALOG_COLUMNS if big else max(40, min(wanted + 2 * DIALOG_SIDE, DIALOG_COLUMNS))
    wide = naturalWidth <= maxWidth
    width = min(maxWidth, DIALOG_BIG_COLUMNS if big else naturalWidth)
    inner = width - 2 * DIALOG_SIDE
    room = lines - 2 - 2 * marginLines - 2
    high = room >= DIALOG_BIG_LEAST_LINES if big else True
    if big:
        room = min(room, DIALOG_BIG_LINES - 2)
    parts = []
    for index, control in enumerate(dialog["controls"]):
        kind = control["kind"]
        holds = len(dialogTextLines(control, inner)) if kind == "text" else len(control["options"])
        height = 1 if kind == "input" else DIALOG_AREA if kind == "area" else max(1, holds) if kind == "text" else max(1, min(holds, DIALOG_OPTIONS))
        parts.append({"index": index, "kind": kind, "label": 1 if control.get("label") else 0, "height": height, "holds": holds})
    says = wrapToCells(dialog["says"], inner)[:2] if dialog["says"] else []
    ## the line of the buttons, and in a style with raised buttons the line of their shadow
    foot = 2 if STYLE.get("buttons") in ("raised", "bars") else 1
    ## the empty lines under its top, and those under its buttons
    lead, tail = DIALOG_LEAD, DIALOG_TAIL + 2 - foot
    if big:
        ## the big dialog: its first text takes the room the rest of it leaves, the empty lines
        ## between its parts, under its top and under its buttons kept
        parts[0]["height"] = max(1, room - sum(part["label"] + part["height"] for part in parts[1:]) - parts[0]["label"] - len(parts) - len(says) - foot - lead - tail)
    gap = 1
    over = lead + sum(part["label"] + part["height"] for part in parts) + gap * len(parts) + len(says) + foot + tail - room
    high = high and (over <= 0 or big)
    if over > 0:
        over -= lead + tail
        lead = tail = 0
    if over > 0:
        over -= gap * len(parts)
        gap = 0
    for kinds in (("text",), ("checks", "radios", "list"), ("area",)):
        for part in parts:
            if over > 0 and part["kind"] in kinds:
                cut = min(over, part["height"] - 1)
                part["height"] -= cut
                over -= cut
    inside = lead + sum(part["label"] + part["height"] for part in parts) + gap * len(parts) + len(says) + foot + tail
    height = max(1, min(inside, room)) + 2
    left = max(marginColumns, min((columns - width) // 2, columns - width - marginColumns))
    top = max(1 + marginLines, min(1 + max(0, (lines - 2 - height) // 2), lines - 1 - marginLines - height))
    line = top + 1 + lead
    for part in parts:
        part["labelLine"] = line if part["label"] else None
        part["line"] = line + part["label"]
        line += part["label"] + part["height"] + gap
    texts = [part for part in parts if part["kind"] == "text"]
    return {"box": (left, top, width, height), "inner": inner, "parts": parts, "says": says, "saysLine": line,
            "buttonsLine": top + height - 1 - foot - tail,
            "long": any(part["holds"] > part["height"] for part in texts),
            "page": texts[0]["height"] if texts else 1, "wide": wide, "high": high}


## The open dialog, drawn over the screen from its declaration and its plan: its frame
## with its title, in the style with colours its shadow, each control, what it refuses,
## and its buttons. The control that has the keys, or the item of it they are on, stands
## in a look of its own, and a field that has them shows the cursor after what was typed.
## A mark at the right says that a text, or a list of options, goes on above or below.
def drawDialog(surface, state, columns, lines):
    dialog = state.dialog
    plan = dialog["plan"]
    left, top, width, height = plan["box"]
    inner = plan["inner"]
    ## its text, its frame and its shadows: in a style that draws a dialog by its level, one of
    ## what was refused or failed in the looks of that
    alert = STYLE.get("levels") and dialog.get("level") == "bad"
    body, rim, shade = (ALERT, ALERT_FRAME, ALERT_SHADE) if alert else (BOX, BOX_FRAME, BOX_SHADE)
    marks = boxMarks("frameOn")
    ## where a style draws edges of blocks, its top line is drawn on what lies under it, a window,
    ## in the look of a line over a window's colour, and its last line on its own colour, each
    ## line in the colour of the ground of its title tab (that of what was refused or failed white
    ## as its rim), and its shadow falls from the line under its first, as Turbo Vision's
    edged = styleDraws("edges", "blocks")
    head = EDGE_ON if edged else rim
    edge = BOX_EDGE if edged and not alert else rim
    surface.put(top, left, marks[0] + marks[1] * (width - 2) + marks[2], head)
    putTitle(surface, top, left, width, dialog["title"], head, "titleOn", ALERT_HEAD if alert else TITLE_ON)
    ## in a style with "icons" the box that closes it, at the left of its top border, does what Esc does
    if iconsFit(width, dialog["title"]):
        surface.put(top, left + 2, styleMark("icons")[0], rim)
        spot(state, left + 2, top, textWidth(styleMark("icons")[0]), 1, ("close",))
    for offset in range(1, height - 1):
        surface.put(top + offset, left, marks[3], rim)
        surface.put(top + offset, left + 1, " " * (width - 2), body)
        surface.put(top + offset, left + width - 1, marks[4], rim)
    surface.put(top + height - 1, left, marks[5] + marks[6] * (width - 2) + marks[7], edge)
    if STYLE.get("shadow") == "slim":
        drawSlimShadow(surface, (left, top + 1, width, height - 1) if edged else plan["box"], lines - 2, columns, SHADE, False)
    elif STYLE.get("shadow") == "dim":
        drawDimShadow(surface, plan["box"], lines - 2, columns, SHADOW)
    elif STYLE["colours"]:
        for offset in range(1, height):
            surface.put(top + offset, left + width, "  ", SHADOW)
        if top + height <= lines - 2:
            surface.put(top + height, left + 2, " " * width, SHADOW)
    what, focusIndex, focused = dialogFocus(dialog)
    column = left + DIALOG_SIDE
    last = plan["buttonsLine"]
    spot(state, left, top, width, height, ("dialog",))
    for part in plan["parts"]:
        control = dialog["controls"][part["index"]]
        on = control is focused
        kind = part["kind"]
        if part["labelLine"] is not None and part["labelLine"] < last:
            surface.put(part["labelLine"], column, cutToCells(control["label"], inner), body)
        rows = max(0, min(part["height"], last - part["line"]))
        if not rows:
            continue
        if kind == "input":
            ## in a style with bracketed fields, between its brackets, what is typed in the look of
            ## the keys where it has them, the rest of its room filled; the cursor stands where the
            ## keys left it, and the field scrolls to keep it in view (the sketch's 14.3)
            ends = MARKS["field"] if STYLE.get("fields") == "bracketed" else ""
            room = max(1, inner - 2 if ends else inner)
            value = control["value"]
            if control.get("seen") != value:
                ## a fill put a value there after the field was open: the cursor goes to its end
                control["caret"] = len(value)
                control["seen"] = value
            caret = inputCaret(control)
            caretCell = textWidth(value[:caret])
            ## the column of the text that stands first: moved only to keep the cursor in view
            pan = max(0, control.get("caretLeft", 0))
            if caretCell < pan:
                pan = caretCell
            if caretCell - pan >= room:
                pan = caretCell - room + 1
            control["caretLeft"] = pan
            ## what the field shows of its text, from that column, in no more than its room: the
            ## rest of a bracketed field keeps what fills it
            shown = []
            used = 0
            for cluster, clusterWidth in textCells(splitAtCell(value, pan)[1]):
                if used + clusterWidth > room:
                    break
                shown.append(cluster)
                used += clusterWidth
            typed = "".join(shown)
            if ends:
                surface.put(part["line"], column, ends[0] + ends[1] * room + ends[2], BOX_FIELD)
                if typed:
                    surface.put(part["line"], column + 1, typed, BOX_ON if on else BOX_FIELD)
            else:
                surface.put(part["line"], column, cutToCells(typed, inner), BOX_ON if on else BOX_FIELD)
            spot(state, column, part["line"], inner, 1, ("field", part["index"]))
            if on:
                surface.cursor(part["line"], column + (1 if ends else 0) + (caretCell - pan))
            continue
        if kind == "area":
            held = areaLines(control["value"], inner - 1)[-rows:]
            spot(state, column, part["line"], inner, rows, ("field", part["index"]))
            for offset in range(rows):
                surface.put(part["line"] + offset, column, cutToCells(held[offset] if offset < len(held) else "", inner),
                            BOX_ON if on else BOX_FIELD)
            if on:
                surface.cursor(part["line"] + len(held) - 1, column + textWidth(held[-1]))
            continue
        if kind == "text":
            held = [(line, control.get("look", body)) for line in dialogTextLines(control, inner)]
        else:
            if control["at"] < control["top"]:
                control["top"] = control["at"]
            if control["at"] >= control["top"] + rows:
                control["top"] = control["at"] - rows + 1
            held = []
            for position, (optionId, label) in enumerate(control["options"]):
                if kind == "checks":
                    mark = styleMark("checks")[0 if optionId in control["value"] else 1]
                elif kind == "radios":
                    mark = styleMark("radios")[0 if optionId == control["value"] else 1]
                else:
                    mark = (MARK_SELECTED if optionId == control["value"] else " ") + " "
                held.append((mark + label, BOX_ON if on and position == control["at"] else BOX_FIELD if kind == "list" else body))
            if not held:
                held.append((control.get("empty", ""), body))
        if control.get("follow") and control.get("following", True):
            control["top"] = len(held) - rows
        control["top"] = max(0, min(control["top"], len(held) - rows))
        control["bottom"] = max(0, len(held) - rows)
        for offset in range(rows):
            if control["top"] + offset < len(held):
                text, look = held[control["top"] + offset]
                surface.put(part["line"] + offset, column, cutToCells(text, inner), look)
                if kind != "text" and control["options"]:
                    spot(state, column, part["line"] + offset, inner, 1, ("option", part["index"], control["top"] + offset))
        if control["top"] > 0:
            surface.put(part["line"], left + width - 2, styleMark("barUp"), rim)
        if control["top"] + rows < len(held):
            surface.put(part["line"] + rows - 1, left + width - 2, styleMark("barDown"), rim)
    for offset, text in enumerate(plan["says"]):
        if plan["saysLine"] + offset < last:
            surface.put(plan["saysLine"] + offset, column, cutToCells(text, inner), BOX_SAYS)
    ## Each button between its brackets; the first, which Enter presses where the keys are on
    ## no button, with the marks of the default inside them, whichever has the keys. The button
    ## that has the keys, and no other, stands in the look of the keys: plain, greyed or that one,
    ## each in the same cells, so a move of the keys changes a look and no character. A raised
    ## button is its face, blanks where the brackets were, with a slim shadow beside and under it,
    ## under it the ground of its cells (drawGroundShadow).
    ## Buttons that are bars are of one width, each with its shadow, the label in the middle: the
    ## one that has the keys with the marks of the focus inside its ends, the default in its own look.
    ## There is one default at a time, and Enter presses it (dialogDefaultIndex)
    defaultIndex = dialogDefaultIndex(dialog)
    labels = [("[%s%s%s]" % (MARKS["default"][0], label, MARKS["default"][1]) if index == defaultIndex else "[ %s ]" % label)
              for index, (name, label) in enumerate(dialog["buttons"])]
    bars = STYLE.get("buttons") == "bars"
    raised = bars or STYLE.get("buttons") == "raised"
    if bars:
        face = max(textWidth(label) for name, label in dialog["buttons"]) + 2
        labels = []
        for index, (name, label) in enumerate(dialog["buttons"]):
            ends = MARKS["focus"] if what == "button" and focusIndex == index else "  "
            spare = face - textWidth(label)
            labels.append(ends[0] + " " * (spare // 2) + label + " " * (spare - spare // 2) + ends[1])
    elif raised:
        labels = [" " + label[1:-1] + " " for label in labels]
    column = left + max(2, (width - sum(textWidth(label) + 2 for label in labels) + 2) // 2)
    for index, label in enumerate(labels):
        if column + textWidth(label) + (1 if raised else 0) > left + width - 2:
            break
        ## a button that would act is greyed while a required input is not there
        off = dialog["buttons"][index][0] != "cancel" and DIALOG_HANDLERS.get(dialog["name"]) is not None and dialogMissing(dialog) is not None
        surface.put(last, column, label, BOX_BUTTON_ON if what == "button" and focusIndex == index else BAR_OFF if off
                    else BOX_BUTTON_DEF if bars and index == defaultIndex else BOX_BUTTON)
        if bars:
            drawSlimShadow(surface, (column, last, textWidth(label), 1), last + 1, left + width - 1, shade)
        elif raised:
            drawGroundShadow(surface, (column, last, textWidth(label), 1), last + 1, left + width - 1, shade, body)
        spot(state, column, last, textWidth(label), 1, ("button", index))
        column += textWidth(label) + 2

