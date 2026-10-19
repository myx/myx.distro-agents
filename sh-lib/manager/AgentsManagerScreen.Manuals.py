##
## AgentsManagerScreen.Manuals.py -- the root Manuals (Help): the help entries and its chapters, and the help of a key.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## What `--member-help <member>` printed, as rows: each operation of its help an item, by
## the first of its syntax lines, whose left window is its block as the help gives it, its
## syntax lines and its text; an operation its syntax names that has no block in the help
## shows that it has none. And the whole of it, which `Member Help` shows of itself.
def parseHelpRows(text):
    lines = [line.expandtabs(4) for line in text.splitlines()]
    named = []
    entries = []
    heading = False
    for raw, line in zip(text.splitlines(), lines):
        if raw.startswith("📘 syntax:"):
            words = [word.strip("[]") for word in raw.split()]
            operation = next((word for word in words if word.startswith("--")), "")
            if operation and operation not in named:
                named.append(operation)
        elif raw.startswith("\t\t--"):
            if not heading:
                entries.append({"operation": raw.split()[0], "lines": []})
            entries[-1]["lines"].append(line.strip())
            heading = True
            continue
        elif entries and (raw.startswith("\t\t\t") or not raw.strip()):
            entries[-1]["lines"].append(line[8:] if line.startswith(" " * 8) else line.strip())
        heading = False
    rows = []
    seen = {}
    for entry in entries:
        operation = entry["operation"]
        seen[operation] = seen.get(operation, 0) + 1
        row = newRow(operation if seen[operation] == 1 else "%s#%d" % (operation, seen[operation]), operation, "help-entry")
        while entry["lines"] and not entry["lines"][-1].strip():
            entry["lines"].pop()
        row["help"] = entry["lines"]
        rows.append(row)
    for operation in named:
        if operation not in seen:
            row = newRow(operation, operation, "help-entry")
            row["help"] = [operation, "", "It has no description block in the help."]
            row["look"] = DIM
            rows.append(row)
    return rows, [{"lines": lines}]


## The chapters of the help that `--manager-help-read` prints after its operations, a row a
## line: `chapter`, `head` for a line before the first option or `foot` for one after them,
## and the line as it is written. The text without them, and the lines of each part, with
## no empty line at either end.
def parseHelpChapters(text):
    kept = []
    parts = {"head": [], "foot": []}
    for line in text.splitlines():
        fields = line.split("\t", 2)
        if fields[0] == "chapter" and len(fields) == 3 and fields[1] in parts:
            parts[fields[1]].append(fields[2].expandtabs(4))
        else:
            kept.append(line)
    for lines in parts.values():
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
    return "\n".join(kept), [parts]


## The summary of `Member Help`: the text of the help before its first option, the member's
## syntax lines, then the chapters after the options, the chapters from the read of the level
## its form names ("chapters"); None until both have come. And of `Manuals (Help)`: what a
## user calls, the first part of its read. Each rendered (helpLines).
def helpSummary(state, path, row, form):
    whole = state.rows.get(WHOLE_OF + levelKey(path))
    if not whole:
        return None
    lines = whole[0]["lines"]
    if form.get("chapters"):
        chapters = state.rows.get(CHAPTERS_OF + form["chapters"])
        if not chapters:
            return None
        lines = chapters[0]["head"] + [""] + [line for line in lines if line.startswith("📘")] + [""] + chapters[0]["foot"]
    return helpLines(state, row, lines)


## ---- the help ----

## `?`, F1: the keys of the screen in a box, from the declaration and in the key map of the
## style: first those that act now, on what is selected in the active window, then the
## others, then the menus, and last what every dialog takes.
def askHelp(state, row):
    acting = []
    others = []
    for command in COMMANDS:
        if not command.get("label") and not command.get("status"):
            continue
        keys = ", ".join(keyShown(key) for key in commandKeys(command))
        words = hotText(command["label"]) if command.get("label") else statusWord(state, command)
        if command["does"][0] == "action" and ACTION_HANDLERS.get(command["does"][1]) is None:
            words += " (not built)"
        (acting if commandApplies(state, command) else others).append((keys, words))
    menuKey = keyShown(commandKeys(commandNamed("menu"))[0])
    return tell(state, "Keys", [
        "The keys that act now, on what is selected in the active window:",
    ] + acting + [
        "The other keys, which act in the other window or on another kind of row:",
    ] + others + [
        "The menus: %s opens the menu bar. %s and then its letter, or Alt with that letter, opens one:" % (menuKey, keyShown("ESC")),
    ] + [(hotLetter(label), hotText(label)) for menuName, label in MENUS] + [
        "%s and %s move by a line in the active window, %s, %s and %s by a page, %s and %s to the top and the bottom."
        " A table that is all of the left window is read like that, with no row highlighted: %s there puts a cursor on a"
        " row, %s and %s move it, %s opens the row whole, and %s leaves the cursor."
        " In a dialog %s and Shift-%s go from control to"
        " control, Space toggles a box and chooses a radio button, %s presses the first button or the one the"
        " keys are on, and %s cancels. The mouse does what these keys do."
        % tuple(keyShown(key) for key in ("UP", "DOWN", "PGUP", "PGDN", " ", "HOME", "END", "ENTER", "UP", "DOWN", "ENTER", "ESC", "TAB", "TAB", "ENTER", "ESC")),
    ], "information", level="")


ACTION_HANDLERS["help"] = askHelp

