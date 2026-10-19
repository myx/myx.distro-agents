#!/usr/bin/env bash
## Behavioural check on the table lines of F11.0 (the refactorings epic), in the one table renderer of the manager
## screen (sh-lib/manager/AgentsManagerScreen.py, paneTable), so in every table of its left window. Run rather than read: the
## renderer is called by the screen module itself, and the real screen is driven through the stand-in terminal of
## check-fixtures/manager-screen.driver.py, where it would call the dispatcher it calls the stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which prints the case's fixture.
## The layout, in the one renderer, for every table:
##   1. two spaces between the columns where the width allows them all, one where it does not (the column of the
##      numbers and the column of the icons count as columns; with the lines not wrapped the width is the pane's
##      scroll, so two)
##   2. in wrap mode, when a value must wrap, the wrapping of the other columns is reassessed: the row takes the
##      fewest lines that any split of the same width gives, never one narrow column wrapped to three or four lines
##      beside a wide one wrapped to two
##   3. one empty line between rows in the full view (a left window that is a table and nothing else), and one under
##      the header, where the table still fits both ways with it: no column left out, in the pane that does not wrap
##      no wider than the pane, and the header, the rows and the empty lines no taller than the pane; a table inside
##      a summary stays tight
##   3b. the tables of the list on the right (Locations, Permissions) are drawn by the same renderer: the same gaps, the same
##      rows in the look of a row and of every other row, or each underlined where the lines wrap and the colours name no ground
##   4. the real screen: the table of the members, which is the whole left window, has them
## The colour rule, as it is drawn:
##   5. a cell with a look of its own (a state) on an other row is drawn on the ground of that row, and keeps its
##      colour and its brightness: the other rows differ from a row only in their ground
##   6. where the colours of a style name no ground for the other rows, a row whose content wraps is underlined on its
##      bottom line across the table width, under its cells with a look of their own too, a row of one line is not;
##      with the lines not wrapped nothing marks the rows
##   7. a terminal of eight colours has not the exact shades the other rows are told apart by: there the colours of
##      every style name no ground for them
##   8. the separation of the rows, one technique chosen by the style and never stacked: a close background covers the
##      whole row, its padding line included; else an underline on the bottom line of a row that wraps, the header
##      carrying it too; either from the first column of the table to its last, and the header padded from the body
##      like the rows, the padding never underlined; and which styles have a close background
## Red before F11.0: the list on the right with a renderer of its own, the one space between columns, the wrapping that is not reassessed, no empty line between rows,
## a cell that breaks the ground of its row, an underline with holes under the cells, and the shades on eight colours.
## Red before the table separation: the ground that stops short of the padding line, the underline and the padding together
## on rows that do not wrap, the underline and the ground that start in the indent, the header neither padded nor underlined.
## Offline: the only thing the screen calls here is the stand-in for the dispatcher.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenTableCheck )" || exit 1
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

## What the renderer and the full-view wrappers give, by the screen module itself: `<name>=<value>` a line.
cat > "$rigTmp/probe.py" <<'RIGPROBE'
import importlib.util, sys, textwrap
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec) ; spec.loader.exec_module(screen)


def say(name, value):
    print("%s=%s" % (name, value))


def lines(table):
    head, blocks = table
    return head + [line for block in blocks for line in block]


def text(table):
    return "".join("[%s]" % line.rstrip() for line in lines(table))


NAMES = (("alpha", "one", "7"), ("beta", "two", "8"))

## 1. the gaps
for width in (11, 12):
    say("gap2.%d" % width, text(screen.paneTable(("NAME", "KIND"), [list(row[:2]) for row in NAMES], width)))
for width in (14, 15, 16):
    say("gap3.%d" % width, text(screen.paneTable(("NAME", "KIND", "ID"), [list(row) for row in NAMES], width)))
say("gapNumbered", text(screen.paneTable(("NAME", "KIND"), [list(row[:2]) for row in NAMES], 40, numbered=True)))
say("gapIcons", text(screen.paneTable(("NAME", "KIND"), [list(row[:2]) for row in NAMES], 40, icons=["ab", ""])))
say("gapNowrap", text(screen.paneTable(("NAME", "KIND"), [list(row[:2]) for row in NAMES], 1000, wrap=False)))

## 2. the fewest lines: the rows of the screen against the best split of the two columns, found by trying them all
CASES = (
    (46, [["omicron iota theta", "delta lambda alpha alpha alpha sigma alpha nu eta xi alpha"]]),
    (31, [["omicron lambda", "pi delta alpha kappa nu lambda xi eta iota"], ["iota", "eta upsilon xi alpha theta alpha nu epsilon beta zeta"],
          ["rho xi", "theta rho omicron theta rho alpha nu tau lambda xi"]]),
    (35, [["theta tau gamma", "mu kappa tau sigma delta omicron"], ["delta beta", "alpha upsilon alpha gamma xi delta"], ["eta", "tau xi zeta delta omicron"]]),
    (38, [["zeta", "xi nu sigma"], ["sigma iota", "lambda delta eta lambda beta alpha alpha kappa upsilon"],
          ["omicron nu", "nu gamma gamma lambda upsilon omicron delta"]]),
)
for number, (width, rows) in enumerate(CASES, 1):
    heads = ("KIND", "WHAT")
    natural = [min(screen.TABLE_CAP, max([len(heads[i])] + [len(row[i]) for row in rows])) for i in range(2)]
    least = [min(natural[i], max(len(heads[i]), screen.TABLE_LEAST, min(screen.TABLE_WORD_MOST, max(len(word) for row in rows for word in row[i].split()))))
             for i in range(2)]
    total = width - 1 - 1
    lined = lambda row, a: (max(len(textwrap.wrap(row[0], a)) or 1, len(textwrap.wrap(row[1], total - a)) or 1), (len(textwrap.wrap(row[0], a)) or 1) + (len(textwrap.wrap(row[1], total - a)) or 1))
    ## the best split: the fewest lines for the table, and of those the fewest lines for the cells
    best = min((sum(lined(row, a)[0] for row in rows), sum(lined(row, a)[1] for row in rows))
               for a in range(least[0], natural[0] + 1) if least[1] <= total - a <= natural[1])
    head, blocks = screen.paneTable(heads, rows, width, kinds=("text", "text"))
    first = head[0].index("WHAT") - 2
    made = (sum(len(block) for block in blocks), sum(lined(row, first)[1] for row in rows))
    say("fewest.%d" % number, "%d/%d:%d/%d:%s" % (made + best + ("fits" if max(screen.textWidth(line) for line in lines((head, blocks))) <= width else "wide",)))

## 3. between the rows
BIG = [["alpha", "one"], ["beta", "two"], ["gamma", "six"]]


def pane(columns, height, wrap=True):
    state = screen.ManagerState("")
    state.viewWidth = columns + 1 if wrap else max(columns + 1, screen.UNWRAPPED_WIDTH)
    state.paneWidth = columns + 1
    state.viewHeight = height
    state.wrap = wrap
    return state


def full(columns, height, wrap=True, rows=BIG, heads=("NAME", "KIND")):
    return "".join("[%s]" % line.rstrip() for line in screen.tableSummaryLines(pane(columns, height, wrap), heads, rows))


say("between.fits", full(40, 7))
say("between.tall", full(40, 6))
say("between.nowrapFits", full(40, 7, wrap=False))
say("between.nowrapWide", full(8, 7, wrap=False))
say("between.dropped", full(9, 7, heads=("NAME", "KIND", "REMARK"), rows=[["alpha", "one", "a long remark"], ["beta", "two", "another"], ["gamma", "six", "a third"]]))
say("between.members", "".join("[%s]" % line.rstrip() for line in screen.memberTableLines(
    pane(60, 7), [{"name": name, "icon": "", "live": "-", "status": "active", "kind": "keeper", "folder": ""} for name in ("alpha", "beta", "gamma")], 59, True)).count("[]"))
say("between.inside", "".join("[%s]" % line.rstrip() for line in screen.summaryTable(("NAME", "KIND"), BIG, 40)).count("[]"))
## a heading of a group stands against its rows: the empty line is between two rows only
say("between.headings", "".join("[%s]" % line.rstrip() for line in screen.tableSummaryLines(pane(40, 20), ("NAME", "KIND"), ["group one", ["a", "1"], ["b", "2"], "group two", ["c", "3"], ["d", "4"]])))

## What a look is, as the screen resolves it in the style of now: how it is drawn with no colours, and its colours.
def seen(number):
    base = screen.LOOKS[number]
    own = screen.STYLE_LOOKS.get(screen.STYLE.get("looks", ""), {}).get(number)
    colours = tuple(own) if own else tuple(base[2:5])
    return base[1], colours


def words(number):
    mono, colours = seen(number)
    return mono, tuple(colours[i] for i in (0, 2, 3, 5) if i < len(colours))


## 4. the tables of the list on the right (Locations), drawn by the one renderer: the same gaps, the same rows in the same looks
PLACES = "\n".join("place\t" + line for line in (
    "ws-rig\tWs_Rig\tworkspace\tread-write\t/rig/ws-rig\tpresent\tyes\t1", "ws-far\tWs_Far\tworkspace\tread-write\t/rig/ws-far\tpresent\tno\t0",
    "deep\tDeep\tdirectory\tread-only\t/rig/deep\tpresent\tno\t-", "far\tFar\tdirectory\tread-only\t/rig/far\tpresent\tno\t-"))


def listed(columns, wrap=True):
    try:
        rows = screen.parsePlaceRows(PLACES)
        state = pane(columns + 1, 20, wrap)
        head, lines = screen.listTableLines(state, rows, rows[0]["table"], columns)
        return head, lines, rows
    except Exception as error:
        return "ERROR %s" % error, [], []


for columns in (200, 47, 17):
    head, lines, rows = listed(columns)
    say("list.%d" % columns, "[%s]%s" % (str(head).rstrip(), "".join("[%s]" % str(line).rstrip() for line in lines[:2])))
rowLooks = []
for style, entry in screen.STYLES:
    for scheme, changes in entry["schemes"]:
        name = "%s-%s" % (style, scheme)
        screen.setStyle(name)
        for wrap in (True, False):
            head, lines, rows = listed(60, wrap)
            ground = [line.looks[0][2] for line in lines] if lines else []
            if screen.rowsApart():
                want = [screen.ROW, screen.ROW_ALT, screen.ROW, screen.ROW_ALT]
            else:
                ## the rows of the list are cut to a line, never wrapped: no underline marks them
                want = [screen.ROW] * 4
            ## the look of a row as the screen resolves it, so that the two names of one colour are one
            got = [repr(seen(look)) for look in ground]
            if got != [repr(seen(look)) for look in want]:
                rowLooks.append("%s%s" % (name, "" if wrap else "-nowrap"))
say("list.looks", " ".join(rowLooks))

## 5, 6, 7. the colour rule as it is drawn, in every style and each of its colour schemes
STATES = [["a", "running"], ["b", "running"], ["c", "running"], ["d", "failed"]]
LOOKED = [[None, screen.LEVEL_OK]] * 3 + [[None, screen.LEVEL_BAD]]
## the same, the first and the third with a state that wraps onto two lines
WRAPPED_STATES = [["a", "running well on all of the lines"], ["b", "running"], ["c", "running well on all of the lines"], ["d", "failed"]]
patched, holes, marked, apart = [], [], [], []
for style, entry in screen.STYLES:
    for scheme, changes in entry["schemes"]:
        name = "%s-%s" % (style, scheme)
        screen.setStyle(name)
        head, blocks = screen.paneTable(("NAME", "STATE"), STATES, 40, looks=LOOKED)
        if screen.rowsApart():
            apart.append(name)
            for number, block in enumerate(blocks):
                cell = block[-1].looks[-1][2]
                own = (screen.LEVEL_OK, screen.LEVEL_OK, screen.LEVEL_OK, screen.LEVEL_BAD)[number]
                if words(cell) != words(own):
                    patched.append("%s:text:%d" % (name, number))
                ## a state that has a ground of its own (the red of a bad one) keeps it: that ground is what it means
                want = screen.lookGround(screen.ROW_ALT) if number % 2 and screen.lookGround(own) == screen.lookGround(screen.PLAIN) else screen.lookGround(own)
                if number % 2 and screen.lookGround(cell) != want:
                    patched.append("%s:ground:%d" % (name, number))
        else:
            ## the underline of a row that wraps is on its bottom line, in every cell of it; a row of one line has none
            head, blocks = screen.paneTable(("NAME", "STATE"), WRAPPED_STATES, 24, looks=LOOKED)
            for number, block in enumerate(blocks):
                if len(block) != (2 if number % 2 == 0 else 1):
                    holes.append("%s:%d:shape" % (name, number))
                elif [look for start, count, look in block[-1].looks if (look in screen.LINED_LOOKS) != (len(block) > 1)]:
                    holes.append("%s:%d" % (name, number))
            head, blocks = screen.paneTable(("NAME", "STATE"), STATES, 40, looks=LOOKED, wrap=False)
            if [look for block in blocks for start, count, look in block[-1].looks[:1] if look in screen.LINED_LOOKS] or len(set(repr(seen(block[-1].looks[0][2])) for block in blocks)) != 1:
                marked.append(name)
say("patched", " ".join(patched))
say("holes", " ".join(holes))
say("marked", " ".join(marked))
say("apart", len(apart) > 0)

## 8. the separation of the rows: one technique, chosen by the style; the padding; the width of the table
HEADS = ("NAME", "KIND")
WRAPPING = [["a", "one"], ["b", "two words that wrap on and on over the lines"], ["c", "three"],
            ["d", "four more words that wrap on and on over the lines"], ["e", "five"]]
SINGLE = [["a", "one"], ["b", "two"], ["c", "three"], ["d", "four"]]


def groundOf(line):
    return screen.lookGround(line.looks[0][2]) if getattr(line, "looks", None) else None


def lined(line):
    return any(look in screen.LINED_LOOKS for start, count, look in getattr(line, "looks", ()))


def everyLine(table):
    head, blocks = table
    return head + [line for block in blocks for line in block]


closed, bgLined, lineApart, wholeRow, wholeHead, edges, lineWrapped, lineHead, lineNone, padHead, padLine = ([] for index in range(11))
for style, entry in screen.STYLES:
    for scheme, changes in entry["schemes"]:
        name = "%s-%s" % (style, scheme)
        screen.setStyle(name)
        near = screen.rowsApart()
        if near:
            closed.append(name)
        for wrap in (True, False):
            for indent in (" ", "  "):
                tag = "%s%s%d" % (name, "" if wrap else "-nowrap", len(indent))
                head, blocks = screen.paneTable(HEADS, WRAPPING, 30, wrap=wrap, indent=indent, pane=(1000, 1000))
                every = everyLine((head, blocks))
                width = screen.textWidth(head[0])
                ## the table's own width: a ground or an underline from its first column to its last, on every line of it
                if any(not getattr(line, "looks", None) or line.looks[0][0] != len(indent) or line.looks[0][0] + line.looks[0][1] != width
                       or screen.textWidth(line) != width for line in every):
                    edges.append(tag)
                ## the header is padded from the body as the rows are from each other, and the padding carries no underline
                pads = [line for line in every if not line.strip()]
                if len(head) != 2 or head[1].strip():
                    padHead.append(tag)
                if len(pads) != len(WRAPPING) or any(lined(line) for line in pads):
                    padLine.append(tag)
                if near:
                    ## a close background is the whole technique: nothing is underlined, and every line of a row has its ground, its padding line too
                    if any(lined(line) for line in every):
                        bgLined.append(tag)
                    for number, block in enumerate(blocks):
                        if any(groundOf(line) != screen.lookGround(screen.ROW_ALT if number % 2 else screen.ROW) for line in block):
                            wholeRow.append("%s:%d" % (tag, number))
                    if any(groundOf(line) != screen.lookGround(screen.ROW_HEAD) for line in head):
                        wholeHead.append(tag)
                else:
                    ## no close background: the ground never changes
                    if any(groundOf(line) != screen.lookGround(screen.ROW) for block in blocks for line in block if line.strip()):
                        lineApart.append(tag)
                    if wrap:
                        ## the underline is on the bottom line of a row that wraps, and the header carries it too
                        for number, block in enumerate(blocks):
                            texts = len([line for line in block if line.strip()])
                            if [lined(line) for line in block] != [texts > 1 and at == texts - 1 for at in range(len(block))]:
                                lineWrapped.append("%s:%d" % (tag, number))
                        if not lined(head[0]):
                            lineHead.append(tag)
                    elif any(lined(line) for line in every):
                        lineNone.append(tag)
        ## a table whose rows do not wrap carries no underline, the header included
        if not near:
            for indent in (" ", "  "):
                if any(lined(line) for line in everyLine(screen.paneTable(HEADS, SINGLE, 30, indent=indent, pane=(1000, 1000)))):
                    lineNone.append("%s%d" % (name, len(indent)))
say("sepClosed", " ".join(closed))
say("sepBgLined", " ".join(bgLined))
say("sepWholeRow", " ".join(wholeRow))
say("sepWholeHead", " ".join(wholeHead))
say("sepLineApart", " ".join(lineApart))
say("sepLineWrapped", " ".join(lineWrapped))
say("sepLineHead", " ".join(lineHead))
say("sepLineNone", " ".join(lineNone))
say("sepEdges", " ".join(edges))
say("sepPadHead", " ".join(padHead))
say("sepPadLine", " ".join(padLine))
eight = []
screen.curses = type("Eight", (), {"COLORS": 8})
for style, entry in screen.STYLES:
    for scheme, changes in entry["schemes"]:
        screen.setStyle("%s-%s" % (style, scheme))
        if screen.rowsApart():
            eight.append("%s-%s" % (style, scheme))
say("eight", " ".join(eight))
RIGPROBE
rigProbe="$( cd "$rigTmp" && "$rigPython" -I -B "$rigTmp/probe.py" "$rigScreen" 2>&1 )" || rigProbe="$rigProbe"$'\n'"PROBE-FAILED rc=$?"
rigGot(){ ## name -- the value of the first `<name>=` line of the probe
	printf '%s\n' "$rigProbe" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
[ -n "$( rigGot gap2.11 )" ] || rigRefuse "the probe of the renderer gave nothing: $( printf '%s\n' "$rigProbe" | LC_ALL=C grep -m3 -e PROBE-FAILED -e Traceback -e Error )"

echo "-- 1. two spaces between the columns where the width allows, one where it does not --"
rigAssert "two columns that fit with one space between and not with two: one space" "$( rigGot gap2.11 )" "[ NAME  KIND][ alpha one][ beta  two]"
rigAssert "one cell of room more: two spaces" "$( rigGot gap2.12 )" "[ NAME   KIND][ alpha  one][ beta   two]"
rigAssert "three columns, room for the second space in one of the two gaps only: one space" "$( rigGot gap3.15 )" "[ NAME  KIND ID][ alpha one  7][ beta  two  8]"
rigAssert "room for it in both: two" "$( rigGot gap3.16 )" "[ NAME   KIND  ID][ alpha  one   7][ beta   two   8]"
rigAssert "with no room to spare at all: one" "$( rigGot gap3.14 )" "[ NAME  KIND ID][ alpha one  7][ beta  two  8]"
rigAssert "the column of the numbers is a column: two spaces after it" "$( rigGot gapNumbered )" "[ #  NAME   KIND][ 1  alpha  one][ 2  beta   two]"
rigAssert "so is the column of the icons" "$( rigGot gapIcons )" "[     NAME   KIND][ ab  alpha  one][     beta   two]"
rigAssert "with the lines not wrapped the width is not a limit: two spaces" "$( rigGot gapNowrap )" "[ NAME   KIND][ alpha  one][ beta   two]"

echo "-- 2. a value that wraps: the other columns are reassessed, the row takes the fewest lines --"
for rigN in 1 2 3 4 ; do
	rigAssert "case $rigN: the lines the table takes and the lines of its cells, the fewest any split of its width gives, and no line wider than the pane" "$( rigGot fewest.$rigN )" "$( rigGot fewest.$rigN | LC_ALL=C awk -F: '{ print $2 ":" $2 ":fits" }' )"
done

echo "-- 3. one empty line between the rows of the full view, where the table fits both ways with it --"
rigAssert "the header and the rows fit with the empty lines: one under the header and one between every two rows" "$( rigGot between.fits )" "[ NAME   KIND][][ alpha  one][][ beta   two][][ gamma  six]"
rigAssert "one line too few for them: none" "$( rigGot between.tall )" "[ NAME   KIND][ alpha  one][ beta   two][ gamma  six]"
rigAssert "the lines not wrapped, the table no wider than the pane: they stand there too" "$( rigGot between.nowrapFits )" "[ NAME   KIND][][ alpha  one][][ beta   two][][ gamma  six]"
rigAssert "the lines not wrapped and the table wider than the pane: none" "$( rigGot between.nowrapWide )" "[ NAME   KIND][ alpha  one][ beta   two][ gamma  six]"
rigAssert "a column left out for the width of the pane: none" "$( rigGot between.dropped | LC_ALL=C grep -c -F '[]' )" "0"
rigAssert "the table of the members, which is the whole left window, has them" "$( rigGot between.members )" "3"
rigAssert "a table inside a summary stays tight" "$( rigGot between.inside )" "0"
rigAssert "a heading of a group stands against its rows: the empty line is between two rows, never next to a heading" "$( rigGot between.headings )" "[ NAME  KIND][ group one][ a     1][][ b     2][ group two][ c     3][][ d     4]"

echo "-- 3b. the tables of the list on the right: drawn by the same renderer, the same gaps and the same looks of rows --"
rigAssert "two spaces between the columns where the pane has the room, the mark of the location ahead of the first column too" "$( rigGot list.200 )" "[   PLACE   KIND       CEILING     STATE    SESSIONS][•  ws-rig  workspace  read-write  present  1][   ws-far  workspace  read-write  present  0]"
rigAssert "one where it has not" "$( rigGot list.47 )" "[  PLACE  KIND      CEILING    STATE   SESSIONS][• ws-rig workspace read-write present 1][  ws-far workspace read-write present 0]"
rigAssert "a column that does not fit is left out whole, the last first" "$( rigGot list.17 )" "[   PLACE][•  ws-rig][   ws-far]"
rigAssert "in every style and colour scheme the rows take turns in the look of a row and of every other row where the colours name a ground, else all are the look of a row: a row of the list is cut to a line, never wrapped, so none is underlined" "[$( rigGot list.looks )]" "[]"

echo "-- 4. the real screen: the table of the members has them --"
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
rigS1=11111111-0000-4000-8000-000000000001
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 gone
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow counters 1 0 1 0 1 0.42
} > "$rigF/rows"
{
	rigRow member human-owner :myx: - - - human ws-rig here reference-only no-process
	rigRow member magic-coordinator :mouse: Magic Vane dispatchr magic ws-rig here active no-process
	rigRow member keeper-myx :triangular_ruler: Sage Bourne cronjob keeper ws-rig here active running
	rigRow member keeper-far :ear_of_rice: Thea Vance farmhand keeper ws-far elsewhere active no-process
} > "$rigF/rows.--manager-team-member-list"
{
	rigRow place ws-rig Ws_Rig workspace read-write /rig/ws-rig present yes 1
	rigRow place ws-far Ws_Far workspace read-write /rig/ws-far present no 0
	rigRow place deep Deep directory read-only /rig/deep present no -
	rigRow place far Far directory read-only /rig/far present no -
} > "$rigF/rows.--manager-place-list"
rigCase(){ ## name -- a fresh rig: a copy of the fixtures, no call noted yet
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; : > "$MANAGER_SCREEN_RIG/ended"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigPane(){ ## tag -- the lines of the left pane of that screen, the spaces at their ends cut, each between brackets
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/^│//' -e 's/^║//' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' -e 's/  *$//'
}
rigPaneUnder(){ ## tag, text, count -- that many lines of the left pane from the one that is exactly the text, each between brackets
	rigPane "$1" | LC_ALL=C awk -v text="$2" -v count="$3" '$0 == text && !n { n = count } n > 0 { printf "[%s]", $0 ; n-- }'
}
rigTableLine(){ ## number, name, run, status, kind, where -- one line of the table of the members as the fixture gives it, two spaces between the columns
	printf ' %-1s  %-17s  %-7s  %-8s  %-6s  %s' "$@" | LC_ALL=C sed 's/  *$//'
}
rigHead="$( rigTableLine '#' MEMBER RUN STATUS KIND WHERE )"
rigRow1="$( rigTableLine 1 human-owner - ref-only human - )" ; rigRow2="$( rigTableLine 2 magic-coordinator - active magic - )"
rigRow3="$( rigTableLine 3 keeper-myx running active keeper - )" ; rigRow4="$( rigTableLine 4 keeper-far - active keeper - )"
rigCase members
rigSize="120 40"
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
root team
turn 2
turn
keys ENTER
wait list 30
turn
show tall
RIGSCRIPT
rigAssert "control: the table of the members is drawn, a header over the four members" "$( rigPane tall | LC_ALL=C grep -c -E '^ # +MEMBER +RUN +STATUS +KIND +WHERE$' ):$( rigPane tall | LC_ALL=C grep -c -E '^ [1-4] +(human-owner|magic-coordinator|keeper-myx|keeper-far) ' )" "1:4"
rigAssert "the columns are two spaces apart, an empty line stands under the header and between every two members" \
	"$( rigPaneUnder tall "$rigHead" 9 )" \
	"[$rigHead][][$rigRow1][][$rigRow2][][$rigRow3][][$rigRow4]"
rigSize="120 9"
rigCase short
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
root team
turn 2
turn
keys ENTER
wait list 30
turn
show short
RIGSCRIPT
rigAssert "the window too short for the empty lines: the members stand one under the other" \
	"$( rigPaneUnder short "$rigHead" 5 )" \
	"[$rigHead][$rigRow1][$rigRow2][$rigRow3][$rigRow4]"

rigRowRoles(){ ## shown tag, roles tag -- from the header of the table of the members on, nine lines: the look letter of the first cell of each, the look letter of the cell ahead of it, and how many different widths those lines are drawn to
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, sys
show, roles = sys.argv[1:3]
out = os.environ["RIG_OUT"].split("\n")
shown = [line[len(show) + 1:] for line in out if line.startswith(show + "|")]
drawn = [line[len(roles) + 1:] for line in out if line.startswith(roles + "|")]
first = [number for number, line in enumerate(shown) if " MEMBER " in line][0]
lines = drawn[first:first + 9]
widths = set()
for line in lines:
    run = 0
    while line[2 + run] == line[2]:
        run += 1
    widths.add(run)
print("".join(line[2] for line in lines), "".join(line[1] for line in lines), len(widths))
' "$1" "$2"
}
rigCase looked
rigSize="120 40"
rigScript <<'RIGSCRIPT'
style nu-blue
turn
wait sessions 30
root team
turn 2
turn
keys ENTER
wait list 30
turn
show blue
roles blueRoles
style nu-system
turn
show sys
roles sysRoles
RIGSCRIPT
rigAssert "where the colours name a close ground, the header is on its own, and a row with its padding line under it is on its ground, the rows taking turns: from the first cell of the table, none in the cell ahead of it, every line the same width" "$( rigRowRoles blue blueRoles )" "uuccjjccj ......... 1"
rigAssert "where they name none, no row is marked: the rows are not wrapped, so none is underlined, and the padding lines are of the rows" "$( rigRowRoles sys sysRoles )" "uuccccccc ......... 1"

rigLetterAt(){ ## shown tag, roles tag, text -- the letter of the first cell of that text in the list, on the first line that holds it from column 140 on
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, sys
show, roles, text = sys.argv[1:4]
out = os.environ["RIG_OUT"].split("\n")
shown = [line[len(show) + 1:] for line in out if line.startswith(show + "|")]
drawn = [line[len(roles) + 1:] for line in out if line.startswith(roles + "|")]
for number, line in enumerate(shown):
    at = line.find(text, 140)
    if at != -1:
        print(drawn[number][at:at + 1]) ; break
' "$1" "$2" "$3"
}
rigLetters(){ ## shown tag, roles tag -- the letters of the first cell of each of the four locations of the list, in their order
	for rigPlace in ws-rig ws-far deep far ; do rigLetterAt "$1" "$2" "$rigPlace" ; done | LC_ALL=C tr -d '\n'
}
rigCase locations
rigSize="200 40"
rigScript <<'RIGSCRIPT'
style nu-blue
turn
wait sessions 30
root places
turn 2
turn
keys ENTER
wait places 30
turn
show blue
roles blueRoles
style nu-system
turn
show sys
roles sysRoles
RIGSCRIPT
rigAssert "the list of the locations on the real screen: where the colours name a ground for every other row its rows take turns (the one the console runs in standing out), each in the look of its ground" "$( rigLetters blue blueRoles )" "Bjcj"
rigAssert "where they name none, no row is marked, for a row of the list is cut to a line and never wraps: the one that stands out stands out, the others are rows" "$( rigLetters sys sysRoles )" "Bccc"
rigAssert "its header is drawn in the look of the header of a table" "$( rigLetterAt blue blueRoles PLACE )" "u"

echo "-- 5. a cell with a look of its own is drawn on the ground of its row --"
rigAssert "in every style and colour scheme that gives the other rows a ground, a state cell of such a row has that ground and its own colour and brightness" "[$( rigGot patched )]" "[]"
rigAssert "control: there are styles and schemes that give the other rows a ground" "$( rigGot apart )" "True"

echo "-- 6. the underline of a row that wraps runs across the table, under the cells with a look of their own --"
rigAssert "where no ground is named for the other rows, the last line of a row that wraps is underlined across the table, in every cell too, and a row of one line is not" "[$( rigGot holes )]" "[]"
rigAssert "with the lines not wrapped nothing marks the rows" "[$( rigGot marked )]" "[]"

echo "-- 7. a terminal of eight colours names no ground for the other rows --"
rigAssert "with eight colours no style and scheme gives the other rows a ground" "[$( rigGot eight )]" "[]"

echo "-- 8. the separation of the rows: one technique, chosen by the style, never stacked --"
rigAssert "the assessment of the palettes: the styles with a background close to their normal one for the other rows, and no other" "$( rigGot sepClosed )" "nu-blue nu-gray tv-blue tv-gray"
rigAssert "where there is a close background it is the whole technique: nothing is underlined, the header and the padding lines too" "[$( rigGot sepBgLined )]" "[]"
rigAssert "the background belongs to the whole row: every line of it and its padding line are on its ground" "[$( rigGot sepWholeRow )]" "[]"
rigAssert "the header and its padding line are on the ground of the header" "[$( rigGot sepWholeHead )]" "[]"
rigAssert "where there is none the ground never changes" "[$( rigGot sepLineApart )]" "[]"
rigAssert "the underline is on the bottom line of a row whose content wraps, never in its middle, and a row of one line has none" "[$( rigGot sepLineWrapped )]" "[]"
rigAssert "the header carries the underline too, where rows of its table wrap" "[$( rigGot sepLineHead )]" "[]"
rigAssert "a table whose rows do not wrap carries no underline, the header included, and with the lines not wrapped nothing marks the rows" "[$( rigGot sepLineNone )]" "[]"
rigAssert "a ground or an underline starts at the first column of the table and ends at its last, on every line, never in the indent ahead of it" "[$( rigGot sepEdges )]" "[]"
rigAssert "the header is padded from the body, as the rows are from each other" "[$( rigGot sepPadHead )]" "[]"
rigAssert "a padding line carries no underline, and there is one under the header and between every two rows" "[$( rigGot sepPadLine )]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TABLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_TABLE: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
