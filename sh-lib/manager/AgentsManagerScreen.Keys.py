##
## AgentsManagerScreen.Keys.py -- what a key does: the command of a key, run, refused, offered.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

def handleKey(state, key, layout):
    if key is None or key == "RESIZE":
        return
    if layout is None:
        if key in commandKeys(commandNamed("exit")):
            state.quit = True
        return
    if key.startswith("MOUSE:"):
        what, column, line = key.split(":")[1:4]
        mouseEvent(state, what, int(column), int(line), layout)
        return
    ## a key lets go of the border between the windows, where the mouse holds it
    state.splitHeld = None
    if state.dialog is not None:
        dialogKey(state, key)
        return
    if key in OPTION_KEYS:
        ## what the Option key of a Mac types: Alt with that key
        key = "ALT-" + OPTION_KEYS[key]
    if state.menu is not None:
        menuKey(state, key, layout)
        return
    if state.focus == "view" and state.view["table"].get("filterOpen") and filterKey(state, key):
        ## the line of the filter of a table is open: what is typed is its
        return
    if state.focus == "list" and state.listFilterOpen and listFilterKey(state, key):
        ## the line of the filter of the list is open: what is typed is its
        return
    if key == "ESC" and state.focus == "view" and state.view.get("rowCursor") is not None:
        ## the row cursor of a table is left, back to reading it
        state.view["rowCursor"] = None
        return
    if key == "ESC" and state.focus == "view" and state.view["table"].get("filter"):
        ## with no cursor and no line open, Esc clears the filter that narrows the table
        state.view["table"]["filter"] = ""
        state.view["top"] = 0
        return
    if key == "ESC" and state.focus == "list" and state.listFilter:
        ## with no line open, Esc clears the filter that narrows the list
        state.listFilter = ""
        return
    if key == "ESC":
        state.metaAt = state.now
        return
    if state.metaAt is not None:
        ## Esc and then a key, in time: Alt with that key
        if metaPending(state) and len(key) == 1 and key != " ":
            key = "ALT-" + key.lower()
        state.metaAt = None
    if key.startswith("ALT-") and menuOfLetter(state, key[4:]) is not None:
        openMenu(state, menuOfLetter(state, key[4:]))
        return
    command = commandOfKey(state, key)
    if command is not None:
        runCommand(state, command, layout, key)


## The keys of a command in the style of now: those its key map gives it, else its own.
def commandKeys(command):
    if command["does"][0] == "go" and command["name"] not in KEYMAPS.get(STYLE.get("keys"), {}):
        ## a number follows the root list as it is shown now
        return goKeys(command["does"][1])
    return KEYMAPS.get(STYLE.get("keys"), {}).get(command["name"], command["keys"])


## Whether Esc was pressed and the key after it would still be taken as Alt with it.
def metaPending(state):
    return state.metaAt is not None and state.now - state.metaAt <= META_SECONDS


def commandNamed(name):
    for command in COMMANDS:
        if command["name"] == name:
            return command
    return None


## The window a command applies in alone, or None for one that applies in every window: the window a command of a plugin
## names under "window", else the one WINDOWS names it in. Only its keys of navigation (NAVIGATION_KEYS) are held by that window:
## its other keys are buttons, which work whichever window has the keys.
def commandWindow(command):
    if command.get("window"):
        return command["window"]
    for window in WINDOWS:
        if command["name"] in window["commands"]:
            return window["name"]
    return None


## Whether that key of a command is held by the window that does not have the keys: a key of navigation of a command that applies in
## the other window alone.
def keyHeld(state, command, key):
    return commandWindow(command) not in (None, state.focus) and key in NAVIGATION_KEYS


## The first key of a command that works now, or None where the window that has the keys holds them all.
def commandKeyNow(state, command):
    for key in commandKeys(command):
        if not keyHeld(state, command, key):
            return key
    return None


## Whether a command belongs to the view of now, the level the list is at: one that names
## no view belongs to every view but those it names under "except".
def commandInView(state, command):
    pattern = levelPattern(state.path)
    return ("views" not in command or pattern in command["views"]) and pattern not in command.get("except", ())


## The command a key means now, or None: the first of COMMANDS that has the key, belongs
## to the view, applies in the window that has the keys, and, where the key is its own on
## some rows alone, is on such a row with its handler built; one that tells why another
## does nothing ("tells") only on a row its action acts on as it is now.
def commandOfKey(state, key):
    place = placeOf(state, selectedRow(state))
    for command in COMMANDS:
        if key not in commandKeys(command) or keyHeld(state, command, key) or not commandInView(state, command):
            continue
        if command.get("only") and (place not in command["on"] or ACTION_HANDLERS.get(command["does"][1]) is None):
            continue
        if command.get("tells") and not actionShown(state, selectedRow(state), command["does"][1]):
            continue
        return command
    return None


## THE MAIN ACTION OF AN ITEM (owner, 2026-10-20): where the selected item does not handle Enter itself, Enter runs the item's main action, one framework rule and no rule of a
## view. The action a command declares as main ("main": True) first; else the first of edit, configure, change and open the item has; else any other action it has, one that
## destroys last (DESTRUCTIVE_SAYS) -- every one asks for its confirmation, as it does by its own key. Within a kind, the first in the order the commands stand in, which is
## the status line's. Only an action on the row (a command that names its places, "on") is one; None where the item has none.
MAIN_SAYS = ("edit", "configure", "change", "open")
DESTRUCTIVE_SAYS = ("delete", "kill", "uninstall", "regenerate", "clear", "finish", "reject", "dismiss", "remove", "unset")


def mainActionOf(state):
    handled = commandOfKey(state, "ENTER")
    if handled is not None and handled["does"][0] != "open":
        return None
    best = None
    for index, command in enumerate(COMMANDS):
        if command["does"][0] != "action" or "on" not in command or "ENTER" in commandKeys(command):
            continue
        if not commandInView(state, command) or not commandApplies(state, command):
            continue
        says = command.get("says", "")
        rank = (0 if command.get("main") else 1 if says in MAIN_SAYS else 3 if says in DESTRUCTIVE_SAYS else 2, MAIN_SAYS.index(says) if says in MAIN_SAYS else 0, index)
        if best is None or rank < best[0]:
            best = (rank, command)
    return best[1] if best else None


## What a command is named by where the screen says something of it: as its menu shows
## it, else its word of the status line.
def commandSaid(command):
    return hotText(command["label"]) if command.get("label") else command.get("status") or command["name"]


## Why a command does not apply now, in one line (REFUSALS), or "" where it applies. A
## menu shows one that does not as greyed and does not choose it, the status line leaves
## it out, and its key does nothing: tried, by its key or by a click, it says this line in
## the status line, and no handler is called.
def commandRefusal(state, command):
    said = commandSaid(command)
    if commandWindow(command) not in (None, state.focus) and commandKeyNow(state, command) is None:
        return REFUSALS["window"] % said
    does = command["does"]
    row = selectedRow(state)
    other = REFUSALS["rowFor"] % (said, command["for"]) if command.get("for") else REFUSALS["row"] % said
    if does[0] == "action":
        if ACTION_HANDLERS.get(does[1]) is None:
            return REFUSALS["unbuilt"] % said
        if "on" not in command:
            return ""
        ## an action acts on what the left window shows: on the container too, while the
        ## selection stands on the row that goes up inside it
        with shownLevel(state, not command.get("only")):
            row = selectedRow(state)
            if placeOf(state, row) not in command["on"]:
                return other
            if actionShown(state, row, does[1]) or command.get("asks"):
                return ""
            words = ACTION_REFUSALS[does[1]](state, row) if does[1] in ACTION_REFUSALS else ""
            return "%s: %s" % (said, words) if words else REFUSALS["fits"] % said
    if does[0] == "go" and pathHidden(state, does[1]):
        return REFUSALS["absent"] % (said, pathHidden(state, does[1]))
    if does[0] == "mode":
        ## a mode is of a thing that has a log, or of a text that is Markdown (rendered or
        ## raw): on any other the keys of the modes do nothing
        with shownLevel(state):
            row = selectedRow(state)
            if placeOf(state, row) not in command["on"]:
                return other
            return "" if viewReadOf(state, row, "feed") is not None or markdownShown(state, row) else REFUSALS["mode"] % said
    if does[0] == "demand":
        ## it asks for a list that is read on demand alone: the one shown, or the one of the folder selected
        return "" if demandRead(state) else other
    if does[0] == "wrap":
        ## panels have no cut mode
        return other if panelsShown(state) else ""
    if does[0] == "pan":
        ## wrapped lines hold nothing to the side
        return REFUSALS["wrapped"] % said if state.wrap or panelsShown(state) else ""
    if does[0] in ("tablesort", "tablefilter"):
        ## the keys of a table act on a table that is all of the left window
        return "" if tableShown(state) else REFUSALS["table"] % said
    if does[0] == "listfilter":
        ## the filter of the list narrows rows already read: nothing to narrow where the level holds none
        return "" if (listedRows(state, state.path) or ()) else REFUSALS["listFilter"] % said
    if does[0] == "fulltable":
        ## the full table is the summary the level declares: none where the level declares none
        return "" if SUMMARIES.get(levelPattern(state.path)) is not None else REFUSALS["fullTable"] % said
    if does[0] == "up":
        return "" if state.path else REFUSALS["up"] % said
    if does[0] == "open":
        return "" if row is not None and (row["dive"] or row["kind"] == "up" or mainActionOf(state) is not None) else REFUSALS["open"] % said
    return ""


## Whether a command applies now: it belongs to the view, and nothing refuses it.
def commandApplies(state, command):
    return commandInView(state, command) and not commandRefusal(state, command)


## Whether the status line names a command now, its stricter rule: the command applies,
## and one whose operation says itself whether it does anything ("asks") also fits the
## row as it is now.
def commandOffered(state, command):
    if not commandApplies(state, command):
        return False
    if not command.get("asks"):
        return True
    with shownLevel(state, not command.get("only")):
        return actionShown(state, selectedRow(state), command["does"][1])


## What a command does, on the state alone. `key` is the key it came by, or None where a
## menu gave it.
def runCommand(state, command, layout, key=None):
    does = command["does"]
    refusal = commandRefusal(state, command)
    if refusal:
        ## it does not apply: nothing is done, and the status line says why
        state.noticeOf = None
        state.notice = refusal
        return
    if does[0] == "quit":
        state.quit = True
    elif does[0] == "focus":
        names = [window["name"] for window in WINDOWS]
        state.focus = names[(names.index(state.focus) + 1) % len(names)]
    elif does[0] == "read":
        readNow(state)
    elif does[0] == "filter":
        state.activeOnly = not state.activeOnly
        readNow(state)
    elif does[0] == "listfilter":
        listFilterOpen(state)
    elif does[0] == "fulltable":
        state.fullTable = not state.fullTable
    elif does[0] == "alphabetical":
        state.alphabetical = not state.alphabetical
    elif does[0] == "menu":
        openMenu(state, 0)
    elif does[0] == "demand":
        ## a list that is read on demand alone, the one shown or the one of the folder
        ## selected: it is asked for now, once, unless it runs
        shown = demandRead(state)
        if shown:
            ## what the status line says of it stands until it has answered (applyResult)
            state.noticeOf = shown[0]
            if shown[0] in state.reading.values() or shown[0] in state.forced:
                state.notice = "%s: it is running" % commandSaid(command)
            else:
                state.forced.add(shown[0])
                state.notice = "%s: asked of the tooling%s" % (commandSaid(command), ", " + shown[1]["said"] if shown[1].get("said") else "")
    elif does[0] == "style":
        ## the next style, in the colours of now
        names = [name for name, style in STYLES]
        setStyle("%s-%s" % (names[(names.index(STYLE["name"]) + 1) % len(names)], COLOURS[colourPlace()][0]))
        state.noticeOf = None
        state.notice = "interface style: %s" % styleLabel()
    elif does[0] == "colours":
        ## the next colours, in the style of now
        setStyle("%s-%s" % (STYLE["name"], COLOURS[(colourPlace() + 1) % len(COLOURS)][0]))
        state.noticeOf = None
        state.notice = "interface style: %s" % styleLabel()
    elif does[0] == "mode":
        ## a Markdown text or the help has a mode of its own (TEXT_MODE_FIRST)
        with shownLevel(state):
            text = markdownShown(state, selectedRow(state))
        if text and does[1]:
            state.textMode = does[1]
        else:
            names = [name for name, mode in VIEW_MODES]
            setViewMode(state, does[1] or names[(names.index(state.viewMode) + 1) % len(names)])
    elif does[0] == "wrap":
        state.wrap = not state.wrap
        state.view["left"] = 0
    elif does[0] == "tablesort":
        tableSort(state)
    elif does[0] == "tablefilter":
        tableFilterOpen(state)
    elif does[0] == "pan":
        ## the pane is brought within what it holds when it is drawn (panOf)
        state.view["left"] = max(0, state.view.get("left", 0) + (1 if key == "RIGHT" else -1) * PAN_STEP)
    elif does[0] == "split":
        state.noticeOf = None
        state.notice = moveSplit(state, layout["columns"], does[1])
    elif does[0] == "move":
        if state.focus == "list" and len(does) > 3 and levelRows(state) and cursorOf(state, levelRows(state), listRowsHeight(state, layout))["index"] == 0:
            ## on the first row of the list: the command it names, in place of the move
            runCommand(state, commandNamed(does[3]), layout, key)
        elif state.focus == "list":
            moveSelection(state, listRowsHeight(state, layout), does[1], does[2])
        elif state.view.get("rowCursor") is not None and not does[2] and abs(does[1]) == 1:
            ## an arrow with the row cursor on moves the cursor
            rowCursorMove(state, viewScrollHeight(state, layout), does[1])
        else:
            scrollView(state, viewScrollHeight(state, layout), does[1], does[2])
            rowCursorKeep(state, viewScrollHeight(state, layout))
    elif does[0] == "row":
        rowCursorEnter(state)
    elif does[0] == "climb":
        ## one level up a press; at the root nothing (goUp), and the keys stay in the list
        goUp(state)
    elif does[0] == "open":
        row = selectedRow(state)
        main = mainActionOf(state) if row is not None and not row["dive"] and row["kind"] != "up" else None
        if main is not None:
            ## the row does not take Enter itself: Enter runs its main action, which asks first as it always did
            runCommand(state, main, layout)
        else:
            diveIn(state, listRowsHeight(state, layout))
    elif does[0] == "up":
        goUp(state)
    elif does[0] == "go":
        state.path = list(does[1])
        state.focus = "list"
    elif does[0] == "action":
        ## the handler of the action, with the row that is selected
        handler = ACTION_HANDLERS[does[1]]
        state.noticeOf = None
        with shownLevel(state, not command.get("only")):
            state.notice = handler(state, selectedRow(state)) or ""

