##
## AgentsManagerScreen.Schedule.py -- `Schedule` under `Magic-Team (Agents)` (sketch 14.5): the flags of the schedule now, how long to the next switch, the week as a grid of its flags by day and
## hour, and the table of the routines that start by themselves.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##
## IT RENDERS AND DECIDES NOTHING. `--manager-schedule-read` (AgentsTools.ManagerSchedule.include) prints the rows: `now`, a `flag` row for each of the six flags with its answer and what the
## answer is from, the `switch` row (the seconds to the next change of a flag and what changes), and a `cell` row for each day and hour with the flag that stands there. The autorun table is the
## rows of `Routines` (their `runs-at` and `runs-after` as the listing gives them). The screen sums, derives and guesses none of it.
##

SCHEDULE_DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
## How a flag of a cell is drawn in the grid: its glyph and its look. A flag not named here is drawn by its first letter.
SCHEDULE_GLYPHS = {"worktime": ("█", LEVEL_OK), "weekend": ("░", DIM), "holidays": ("▒", LEVEL_WARN), "overtime": ("▓", LEVEL_WARN),
                   "emergency": ("!", LEVEL_BAD), "learning": ("L", BOLD)}
SCHEDULE_NONE = ("·", DIM)
## The columns ahead of the hours: the day, and a blank.
SCHEDULE_LEAD = 5


## What `--manager-schedule-read` printed, as the rows of `Schedule` (a row for each flag, in the order the operation gave them), each carrying the whole picture (`schedule`) for the summary.
def parseScheduleRows(readKey, level, text):
    held = {"now": None, "flags": [], "switch": None, "cells": {}}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "now" and len(fields) >= 4:
            held["now"] = (fields[2], fields[3])
        elif fields[0] == "flag" and len(fields) >= 4:
            held["flags"].append((fields[1], fields[2], fields[3]))
        elif fields[0] == "switch" and len(fields) >= 3:
            held["switch"] = (fields[1], fields[2])
        elif fields[0] == "cell" and len(fields) >= 4:
            held["cells"][(fields[1], fields[2])] = fields[3]
    rows = []
    for name, answer, note in held["flags"]:
        row = newRow(name, name, "record", False)
        row["schedule"] = held
        row["flag"] = (name, answer, note)
        row["tail"] = answer + ("" if note in ("", "-") else " " + note)
        row["look"] = BOLD if answer.startswith("yes") else DIM
        rows.append(row)
    return {level: rows}


ROW_FORMS["schedule"] = parseScheduleRows


## A cell may hold several flags (`worktime,learning`): the one drawn is the first of SCHEDULE_ORDER that it holds, else the first it names.
SCHEDULE_ORDER = ("emergency", "overtime", "holidays", "worktime", "weekend", "learning")


def scheduleCellFlag(cell):
    names = [name for name in cell.split(",") if name]
    for name in SCHEDULE_ORDER:
        if name in names:
            return name
    return names[0] if names else "-"


## The mark each flag carries in a cell, beside its glyph: readable in a cell of several columns.
SCHEDULE_MARKS = {"worktime": "W", "weekend": "E", "holidays": "H", "overtime": "O", "emergency": "!", "learning": "L"}
## The widest a cell of an hour may be, and the narrowest the grid is cut to before it takes more lines.
SCHEDULE_CELL_MOST = 6
SCHEDULE_CELL_LEAST = 3


## How the hours are laid out in the room there is: all twenty-four in a line where each gets at least SCHEDULE_CELL_LEAST + 1 columns, else twelve, else six, a block after another;
## and the width of a cell, which is the room shared by the hours of a line, at most SCHEDULE_CELL_MOST.
def scheduleLayout(width):
    room = max(1, width - SCHEDULE_LEAD - 1)
    for perLine in (24, 12, 6):
        if room // perLine >= SCHEDULE_CELL_LEAST + (1 if perLine == 24 else 0) or perLine == 6:
            return perLine, max(2, min(SCHEDULE_CELL_MOST, room // perLine))


## One cell of the grid, `size` columns: the mark of its flag, then its glyph to the cell's end less one blank, or the faint dot where no flag stands.
def scheduleCell(flag, size):
    if flag in ("-", ""):
        return SCHEDULE_NONE[0] * (size - 1) + " ", SCHEDULE_NONE[1]
    glyph, look = SCHEDULE_GLYPHS.get(flag, (flag[:1], BOLD))
    return (SCHEDULE_MARKS.get(flag, flag[:1]) + glyph * (size - 2) + " "), look


## The grid of the week, in as many blocks of hours as the pane's width asks: the hours across the top of a block, each hour in a cell of several columns, a line for each day, the mark and
## the glyph of the flag in each cell, and the cell of now reversed.
def scheduleGridLines(held, width=60):
    perLine, size = scheduleLayout(width)
    nowDay, nowHour = (held["now"][0], held["now"][1][:2]) if held["now"] else ("", "")
    lines = []
    for first in range(0, 24, perLine):
        lines.append(looked(" " * SCHEDULE_LEAD + "".join(("%02d" % hour).ljust(size) for hour in range(first, first + perLine)).rstrip(), DIM))
        for day in SCHEDULE_DAYS:
            texts, spans = [], []
            for position, hour in enumerate(range(first, first + perLine)):
                text, look = scheduleCell(scheduleCellFlag(held["cells"].get((day, "%02d" % hour), "-")), size)
                texts.append(text)
                spans.append((SCHEDULE_LEAD + position * size, size - 1, REVERSE if day == nowDay and "%02d" % hour == nowHour else look))
            lines.append(lookedAt(day.ljust(SCHEDULE_LEAD) + "".join(texts).rstrip(), spans))
        lines.append("")
    named = set(scheduleCellFlag(cell) for cell in held["cells"].values())
    legend = "  ".join("%s %s %s" % (SCHEDULE_MARKS[name], SCHEDULE_GLYPHS[name][0], name) for name in ("worktime", "weekend", "holidays", "overtime", "emergency", "learning") if name in named)
    return lines[:-1] + ([looked(" " * SCHEDULE_LEAD + legend, DIM)] if legend else [])


## The time of day a routine starts at, as its declaration gives it (`daily 09:00`, `workdays 10:00`): the `HH:MM` in it, else a late sentinel that sorts after every time.
def scheduleStartOf(routine):
    found = re.search(r"\b(\d{1,2}):(\d{2})\b", routine["runsAt"] if routine["auto"] == "yes" else "")
    return "%02d:%s" % (int(found.group(1)), found.group(2)) if found else "99:99"


## The routines that start by themselves, in the order the owner reads them: by the time they start, and a routine that runs after another right under that one (its predecessor named by
## `runs-after`, as the listing gives it), a chain in the order it runs. A routine whose predecessor is not among these stands in the time order itself. Each with its depth.
def scheduleAutorunOrder(routines):
    names = dict((routine["selector"], routine) for routine in routines)
    after = {}
    for routine in routines:
        ahead = routine["runsAfter"] if routine["runsAfter"] not in ("", "-") else ""
        if ahead and ahead in names and ahead != routine["selector"]:
            after.setdefault(ahead, []).append(routine)
    roots = sorted((routine for routine in routines if not (routine["runsAfter"] in names and routine["runsAfter"] != routine["selector"])),
                   key=lambda routine: (scheduleStartOf(routine), routine["label"]))
    ordered, seen = [], set()

    def place(routine, depth):
        if routine["selector"] in seen:
            return
        seen.add(routine["selector"])
        ordered.append((routine, depth))
        for follower in sorted(after.get(routine["selector"], ()), key=lambda one: (scheduleStartOf(one), one["label"])):
            place(follower, depth + 1)

    for routine in roots:
        place(routine, 0)
    for routine in routines:
        place(routine, 0)
    return ordered


## The routines that start by themselves, from the rows of `Routines`, in that order: what they declare, `daily 09:00`, with `after <routine>` where one follows another.
def scheduleAutorunLines(state):
    rows = state.rows.get(pluginLevel("routines"))
    if rows is None:
        return [looked("The routines are being read.", DIM)]
    routines = [held["routine"] for held in rows if held.get("routine") and routineTimes(held["routine"]) != "-"]
    if not routines:
        return [looked("No routine starts by itself.", DIM)]
    placed = scheduleAutorunOrder(routines)
    return tableSummaryLines(state, ("ROUTINE", "STARTS"), [[("  " * depth + ("\u21b3 " if depth else "")) + routine["label"], routineTimes(routine)] for routine, depth in placed], ("key", "text"))


## The picture for the left pane: the flags now, how long to the next switch, the week, and the autorun table.
def scheduleSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    held = next((one["schedule"] for one in rows if one.get("schedule")), None)
    if held is None:
        return [looked("The operation listed no flag.", BOLD)]
    lines = [looked("Flags now", BOLD)] + factLines([(name, answer + ("" if note in ("", "-") else " " + note), LEVEL_OK if answer.startswith("yes") else None)
                                                    for name, answer, note in held["flags"]], state.viewWidth)
    if held["switch"]:
        lines.extend(factLines([("next switch", "%s in %s" % (held["switch"][1].replace("-", " "), shortSpan(held["switch"][0])))], state.viewWidth))
    lines.extend([""] + headingLines("The week") + scheduleGridLines(held, state.viewWidth) + [""] + headingLines("Starts by itself") + scheduleAutorunLines(state))
    return lines


def scheduleFocus(state, row):
    return scheduleSummary(state, state.path, row, {})


registerPlugin({
    "name": "schedule",
    "mount": "magic-team",
    "root": {"id": "schedule", "label": "Schedule", "go": "Sche~d~ule", "group": "team"},
    "focus": {"schedule": "scheduleFocus"},
    "summaries": {"schedule": {"lines": "scheduleSummary"}},
    "reads": {
        ## the flags, the next switch and the week, as the tooling gives them; the routines are read beside them (their autorun)
        "list:schedule": {"operation": ["--manager-schedule-read"], "rows": "schedule", "also": ("list:@routines",)},
    },
})
