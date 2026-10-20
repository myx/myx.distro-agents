#!/usr/bin/env bash
## Behavioural check on the full-pane table view of the console app (F11.3 of the refactorings epic), run rather than read. The screen's own code
## (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py); no reader is started.
## A stand-in app feature gives each of its rows a table by its focus handler, as a real one does.
## Held (F11.3: "The full-pane table view, in python, has a high ceiling ... a header that stays while the rows scroll, where the viewport holds more than
## five rows; horizontal scrolling of a table wider than the pane, where the view allows it, as most will; the view names a usable column to pin, such as
## its key, and it is pinned only where the width allows; sorting by any column, by a key, and back to the source order; a live filter, typed, narrowing
## the rows; the existing wrap and unwrap, with no resizing of columns"; the filter as the owner agreed it, 2026-10-19):
##   1. the header stays over the rows while they scroll, where the window holds more than five lines of rows, and goes up with them where it does not
##   2. sideways: the table cut to its words is wider than the window and scrolls; the column the view pins stays at the left while the rest scrolls, where
##      the width leaves the scrolling part twenty cells at least; where it does not, nothing is pinned and the whole line scrolls; a view that names no
##      column to pin, or names none, scrolls whole
##   3. sort: `t` sorts by the next column, the first after the source order, a number by its value, a cell that says nothing always last; after the last
##      column it is the source order again; the head of the sorted column carries its mark; the key works whichever window has the keys; where the left
##      window holds no table it says so and names no key
##   4. the filter (agreed): `/` while the left window has the keys opens the line on the last line of the window; every character narrows the rows at once,
##      case aside, in any cell of the row, the cells no column shows too, the words typed all having to be in it; Backspace takes one back; Enter closes the
##      line and keeps the filter, shown as `/text`; Esc closes the line and clears it, and so does Esc with no cursor and no line open; with a cursor on, Esc
##      leaves the cursor first; the bottom border counts `N of M rows`; `#` numbers the rows shown; sort acts on the rows narrowed; another selection starts
##      unfiltered and in its source order
##   5. wrap and cut change nothing of the rows, their order or the filter, and no key changes the width of a column
## Red before F11.3: no pinned column, the header stays whatever the window holds, no sort, no filter line.
## Offline: no operation of the real tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigScreen="$rigPackage/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenTableViewCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

cat > "$rigTmp/probe.py" <<'RIGPROBE'
import importlib.util, re, sys, os

screenFile, driverFile = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("rigdriver", driverFile)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
screen = driver.loadScreen(screenFile)


def say(name, value):
    print("%s=%s" % (name, value))


def attempt(name, function):
    try:
        function()
    except Exception as failure:
        say(name + ".error", "%s: %s" % (type(failure).__name__, str(failure)[:200].replace("\n", " ")))


def session(columns=100, lines=24):
    state = screen.ManagerState("")
    surface = driver.TextSurface(columns, lines)

    def turn(*keys):
        for key in keys or (None,):
            screen.screenTurn(surface, state, None, 0.0, key)

    def status():
        return "".join(surface.cells[surface.lines - 1]).rstrip()

    def box():
        return screen.layoutOf(surface.columns, surface.lines, state.split)["boxes"]["view"]

    def left():
        b = box()
        return ["".join(surface.cells[line][b[0] + 1:b[0] + b[2] - 1]).rstrip() for line in range(b[1] + 1, b[1] + b[3] - 1)]

    def foot():
        ## what the bottom border of the left window says of its rows: `4 rows`, `1 of 4 rows`
        b = box()
        found = re.search(r"[0-9]+ (?:of [0-9]+ )?rows?", "".join(surface.cells[b[1] + b[3] - 1][b[0]:b[0] + b[2]]))
        return found.group(0) if found else ""
    return state, surface, turn, status, left, foot


def selectRow(state, rowId):
    state.path = ["rigtable"]
    rows = screen.levelRows(state)
    index = [row["id"] for row in rows].index(rowId)
    state.cursors["rigtable"] = {"key": screen.rowKey(rows[index]), "index": index, "top": 0}


TABLES = {}


def focus(state, row):
    return TABLES.get(row["id"])


screen.rigFocus = focus
RIG = {
    "name": "rigtable", "root": {"id": "rigtable", "label": "Rig Table", "go": "Rig ~T~able", "group": "team"},
    "rows": {"rigtable": tuple((name, "Table " + name, "rigrow", False) for name in ("long", "wide", "plain", "pinless", "other", "words", "none"))},
    "focus": {"rigtable": "rigFocus"},
}
attempt("register", lambda: screen.registerPlugin(RIG))

TABLES["long"] = {"kind": "table", "heads": ("NAME", "KIND"), "rows": [["row%02d" % number, "kind"] for number in range(1, 41)]}
LONGNAME = "a-key-of-thirty-characters-long"
TABLES["wide"] = {"kind": "table", "heads": ("NAME", "FIRST", "SECOND", "THIRD", "FOURTH"),
                  "rows": [[LONGNAME + str(number), "first-" + "x" * 24, "second-" + "x" * 23, "third-" + "x" * 24, "fourth-" + "x" * 23] for number in range(1, 4)]}
TABLES["pinless"] = dict(TABLES["wide"], pin=0)
TABLES["plain"] = {"kind": "table", "heads": ("NAME", "N", "L"),
                   "rows": [["delta", "3", "c"], ["alpha", "12", "b"], ["charlie", "2", "a"], ["bravo", "30", "d"], ["echo", "-", "e"]]}
TABLES["words"] = {"kind": "table", "heads": ("NAME", "KIND", "REMARK"), "numbered": True,
                   "rows": [["alpha", "greek", "the third of them, long enough to fill a good part of the pane, and then more"],
                            ["beta", "greek", "the second, equally long, with words to fill the cells and a hidden zulu word"],
                            ["gamma", "Greek", "the first one, and nothing hidden"],
                            ["delta", "latin", "the fourth, as long as the others are, a wordy remark"]]}
TABLES["other"] = {"kind": "table", "heads": ("NAME",), "rows": [["solo"], ["duo"]]}


def names(lines, pool):
    ## the first word of each line that is one of the names given, in the order the lines stand
    found = []
    for line in lines:
        for word in line.split():
            if word in pool:
                found.append(word)
                break
    return found


## ---- 1. the header that stays
def sticky():
    for label, lines in (("tall", 24), ("short", 9)):
        state, surface, turn, status, left, foot = session(100, lines)
        selectRow(state, "long")
        turn("TAB")
        turn("END")
        text = left()
        say("sticky.%s.height" % label, state.viewHeight)
        say("sticky.%s.header" % label, "yes" if any("NAME" in line for line in text) else "no")
        say("sticky.%s.first" % label, text[0].split()[0] if text and text[0].split() else "")
        turn("HOME")
        say("sticky.%s.top" % label, "yes" if any("NAME" in line for line in left()) else "no")


attempt("sticky", sticky)


## ---- 2. sideways
def sideways():
    for label, columns, table in (("pinned", 100, "wide"), ("narrow", 60, "wide"), ("pinless", 100, "pinless")):
        state, surface, turn, status, left, foot = session(columns, 24)
        selectRow(state, table)
        turn("TAB", "w")
        say("side.%s.wrap" % label, "yes" if state.wrap else "no")
        before = left()
        turn("RIGHT", "RIGHT", "RIGHT")
        after = left()
        say("side.%s.left" % label, state.view["left"])
        moved = [line for line in before if "long1" in line]
        rows = [line for line in after if "long1" in line]
        header = [line for line in after if "NAME" in line or "FIRST" in line]
        say("side.%s.keyShown" % label, "yes" if rows and rows[0].lstrip().startswith(LONGNAME[:12]) else "no")
        say("side.%s.headShown" % label, "yes" if header and header[0].lstrip().startswith("NAME") else "no")
        say("side.%s.scrolled" % label, "yes" if rows and moved and rows[0] != moved[0] else "no")
        say("side.%s.wider" % label, "yes" if any(len(line.rstrip()) >= state.paneWidth - 3 for line in before) else "no")


attempt("sideways", sideways)


## ---- 3. sort
def sorting():
    state, surface, turn, status, left, foot = session(100, 24)
    pool = ("delta", "alpha", "charlie", "bravo", "echo")
    selectRow(state, "plain")
    turn()
    say("sort.source", " ".join(names(left(), pool)))
    say("sort.statusT", "t Sort" in status())
    turn("t")
    say("sort.name", " ".join(names(left(), pool)))
    say("sort.mark", "yes" if any("NAME " + screen.MARKS["barUp"] in line for line in left()) else "no")
    turn("t")
    say("sort.number", " ".join(names(left(), pool)))
    turn("t")
    say("sort.letter", " ".join(names(left(), pool)))
    turn("t")
    say("sort.back", " ".join(names(left(), pool)))
    say("sort.backNoMark", "yes" if not any(screen.MARKS["barUp"] in line or screen.MARKS["barDown"] in line for line in left()) else "no")
    turn("TAB", "t")
    say("sort.fromView", " ".join(names(left(), pool)))
    say("sort.focus", state.focus)
    selectRow(state, "other")
    turn()
    say("sort.otherSource", " ".join(names(left(), ("solo", "duo"))))
    selectRow(state, "plain")
    turn()
    say("sort.freshAgain", " ".join(names(left(), pool)))
    ## a window that holds no table
    selectRow(state, "none")
    turn()
    turn("t")
    say("sort.noTable", state.notice)
    say("sort.noTableStatus", "t Sort" in status())


attempt("sorting", sorting)


## ---- 4. the filter
def filtering():
    state, surface, turn, status, left, foot = session(100, 24)
    pool = ("alpha", "beta", "gamma", "delta")
    selectRow(state, "words")
    turn()
    say("filter.all", " ".join(names(left(), pool)))
    say("filter.foot", foot())
    turn("/")
    say("filter.listIgnored", "yes" if not state.view["table"].get("filterOpen") else "no")
    turn("TAB", "/")
    say("filter.open", "yes" if state.view["table"].get("filterOpen") else "no")
    turn("p", "h")
    say("filter.ph", " ".join(names(left(), pool)))
    say("filter.line", left()[-1].strip())
    say("filter.foot.ph", foot())
    turn(" ", "A")
    say("filter.words", " ".join(names(left(), pool)) + " | " + left()[-1].strip())
    turn("BACKSPACE", "BACKSPACE")
    say("filter.back", left()[-1].strip())
    turn("ENTER")
    say("filter.kept", left()[-1].strip() + " | " + ("open" if state.view["table"].get("filterOpen") else "closed"))
    say("filter.keptRows", " ".join(names(left(), pool)))
    turn("DOWN")
    say("filter.stillThere", left()[-1].strip())
    turn("ESC")
    say("filter.escClears", " ".join(names(left(), pool)) + " | " + foot())
    say("filter.lineGone", "yes" if not any(line.strip().startswith("/") for line in left()) else "no")
    ## case and the cells no column shows: the remark of two rows has a word the pane has no room for
    turn("/")
    for key in "ZULU":
        turn(key)
    say("filter.hidden", " ".join(names(left(), pool)))
    say("filter.numbers", " ".join(line.split()[0] for line in left() if line.split() and any(word in pool for word in line.split()[:3]) and line.split()[0].isdigit()))
    turn("ESC")
    say("filter.escWhileTyping", " ".join(names(left(), pool)) + " | " + foot())
    ## no row matches
    turn("/")
    for key in "nomatch":
        turn(key)
    say("filter.none", "yes" if any("No row has all of" in line for line in left()) else "no")
    say("filter.noneFoot", foot())
    turn("ESC")
    ## sort acts on the rows narrowed
    turn("/")
    turn("g", "r", "e", "e", "k")
    turn("ENTER")
    say("filter.greek", " ".join(names(left(), pool)))
    turn("TAB", "t", "t", "t")
    say("filter.sorted", " ".join(names(left(), pool)))
    say("filter.sortedFoot", foot())
    ## the cursor leaves first, then the filter
    turn("TAB", "ENTER")
    say("filter.cursor", state.view.get("rowCursor"))
    turn("ESC")
    say("filter.afterFirstEsc", "%s %s" % (state.view.get("rowCursor"), state.view["table"].get("filter")))
    turn("ESC")
    say("filter.afterSecondEsc", "%s [%s]" % (state.view.get("rowCursor"), state.view["table"].get("filter")))
    ## wrap and cut leave rows, order and filter as they are
    turn("/")
    turn("a")
    turn("ENTER")
    before = " ".join(names(left(), pool))
    turn("w")
    after = " ".join(names(left(), pool))
    say("filter.wrapKeeps", "%s | %s | %s" % ("same" if before == after and before else "differs: %s / %s" % (before, after), "four" if len(after.split()) == 4 else "not four", left()[-1].strip()))
    ## another selection starts unfiltered
    selectRow(state, "other")
    turn()
    say("filter.other", "%s | %s" % (" ".join(names(left(), ("solo", "duo"))), "yes" if filterShown(state) else "no"))
    selectRow(state, "words")
    turn()
    say("filter.fresh", "yes" if not filterShown(state) else "no")


def filterShown(state):
    return bool(state.view["table"].get("filter") or state.view["table"].get("filterOpen"))


attempt("filtering", filtering)
RIGPROBE
rigOut="$( "$rigPython" -I -B "$rigTmp/probe.py" "$rigScreen" "$rigDriver" 2>&1 )"
rigVal(){ ## name -- the value of the first `<name>=` line, or the error of that step
	local rigLine
	rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1 )"
	[ -n "$rigLine" ] || rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$(printf '%s' "$1" | LC_ALL=C sed 's/\..*//')\.error=/error: /p" | head -1 )"
	[ -n "$rigLine" ] || rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^[a-z]*\.error=/error: /p" | head -1 )"
	printf '%s\n' "${rigLine:--}"
}
rigErr(){ ## probe name -- the error a probe step ended with, or `none`
	local rigLine
	rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1\.error=//p" | head -1 )"
	printf '%s\n' "${rigLine:-none}"
}

echo "-- 1. the header that stays --"
rigAssert "the stand-in feature registers itself, and the probe steps ran" "$( rigErr register ) $( rigErr sticky ) $( rigErr sideways ) $( rigErr sorting ) $( rigErr filtering )" "none none none none none"
rigAssert "a window that holds more than five lines of rows keeps the header over them once the rows have scrolled" "$( rigVal sticky.tall.height ) $( rigVal sticky.tall.header ) $( rigVal sticky.tall.top )" "$( rigVal sticky.tall.height ) yes yes"
rigAssert "a window of five lines or fewer does not: the header goes up with the rows" "$( [ "$( rigVal sticky.short.height )" -le 5 ] && echo small ) $( rigVal sticky.short.header ) $( rigVal sticky.short.top )" "small no yes"

echo "-- 2. sideways --"
rigAssert "cut to its words, the table is wider than the window, and scrolls sideways" "$( rigVal side.pinned.wrap ) $( rigVal side.pinned.wider ) $( rigVal side.pinned.left )" "no yes 24"
rigAssert "the pinned column stays at the left, in the rows and in the header, while the rest scrolls" "$( rigVal side.pinned.keyShown ) $( rigVal side.pinned.headShown ) $( rigVal side.pinned.scrolled )" "yes yes yes"
rigAssert "where the width leaves the scrolling part under twenty cells nothing is pinned and the whole line scrolls" "$( rigVal side.narrow.keyShown ) $( rigVal side.narrow.headShown ) $( rigVal side.narrow.scrolled )" "no no yes"
rigAssert "a view that pins none scrolls whole" "$( rigVal side.pinless.keyShown ) $( rigVal side.pinless.headShown )" "no no"

echo "-- 3. sort --"
rigAssert "the source order first, and t names its key" "$( rigVal sort.source ) / $( rigVal sort.statusT )" "delta alpha charlie bravo echo / True"
rigAssert "t sorts by the first column, its head marked" "$( rigVal sort.name ) / $( rigVal sort.mark )" "alpha bravo charlie delta echo / yes"
rigAssert "then by the next, a number by its value and the cell that says nothing last" "$( rigVal sort.number )" "charlie delta alpha bravo echo"
rigAssert "then by the last" "$( rigVal sort.letter )" "charlie alpha delta bravo echo"
rigAssert "and then back to the source order, no mark" "$( rigVal sort.back ) / $( rigVal sort.backNoMark )" "delta alpha charlie bravo echo / yes"
rigAssert "the key is a button of both windows" "$( rigVal sort.fromView ) / $( rigVal sort.focus )" "alpha bravo charlie delta echo / view"
rigAssert "another table starts in its source order, and the first again is back in its own" "$( rigVal sort.otherSource ) / $( rigVal sort.freshAgain )" "solo duo / delta alpha charlie bravo echo"
rigAssert "where the left window holds no table the key says so and the status line names none" "$( rigVal sort.noTable ) / $( rigVal sort.noTableStatus )" "Sort by the next column: the left window holds no table / False"

echo "-- 4. the filter --"
rigAssert "the table whole first, its bottom border counting its rows" "$( rigVal filter.all ) / $( rigVal filter.foot )" "alpha beta gamma delta / 4 rows"
rigAssert "/ is the left window's key: with the list holding the keys it opens nothing, and the line opens when the left window has them" "$( rigVal filter.listIgnored ) $( rigVal filter.open )" "yes yes"
rigAssert "each character narrows the rows at once; the line shows what is typed on the last line of the window; the border counts" "$( rigVal filter.ph ) | $( rigVal filter.line ) | $( rigVal filter.foot.ph )" "alpha | /ph | 1 of 4 rows"
rigAssert "the words typed all have to be in the row, case aside" "$( rigVal filter.words )" "alpha | /ph A"
rigAssert "Backspace takes one back" "$( rigVal filter.back )" "/ph"
rigAssert "Enter closes the line and keeps the filter, shown as /text" "$( rigVal filter.kept ) / $( rigVal filter.keptRows ) / $( rigVal filter.stillThere )" "/ph | closed / alpha / /ph"
rigAssert "Esc with no cursor and no line open clears it, and the line goes" "$( rigVal filter.escClears ) / $( rigVal filter.lineGone )" "alpha beta gamma delta | 4 rows / yes"
rigAssert "a cell no column of the pane shows counts, and the case does not" "$( rigVal filter.hidden )" "beta"
rigAssert "# numbers the rows shown" "$( rigVal filter.numbers )" "1"
rigAssert "Esc while typing closes the line and clears the filter" "$( rigVal filter.escWhileTyping )" "alpha beta gamma delta | 4 rows"
rigAssert "a filter no row has all the words of says so, and the border counts none" "$( rigVal filter.none ) / $( rigVal filter.noneFoot )" "yes / 0 of 4 rows"
rigAssert "the sort acts on the rows narrowed, and the border counts" "$( rigVal filter.greek ) / $( rigVal filter.sorted ) / $( rigVal filter.sortedFoot )" "alpha beta gamma / gamma beta alpha / 3 of 4 rows"
rigAssert "with the cursor on, Esc leaves the cursor first and the filter on the second Esc" "$( rigVal filter.cursor ) / $( rigVal filter.afterFirstEsc ) / $( rigVal filter.afterSecondEsc )" "0 / None greek / None []"
rigAssert "wrap and cut change nothing of the rows, their order or the filter" "$( rigVal filter.wrapKeeps )" "same | four | /a"
rigAssert "another selection starts unfiltered, and the table is back to what it was" "$( rigVal filter.other ) / $( rigVal filter.fresh )" "solo duo | no / yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TABLE VIEW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_TABLE_VIEW: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
