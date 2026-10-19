#!/usr/bin/env bash
## Behavioural check on the layout of the manager screen (sh-lib/manager/AgentsManagerScreen.py) and on the inside of its left
## window, run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which prints rows in the forms the operations print.
## Held: THE SPLIT between the windows is kept as a ratio of the width, None until it is moved; two keys move it a
## step, in either window and in every style, and the status line says how wide the list now is; the limits are
## absolute numbers of cells and the right window's alone, its smallest and its largest, and the left window keeps
## what a window needs; a limit bounds what is drawn and does not rewrite the ratio, which holds again when the
## terminal is made another size; the mouse drags the border where the button going down and coming up are
## reported, else a click on the border takes hold of it and the next click puts it, a click on it again or a key
## lets it go, a press elsewhere is nothing, and a held border is drawn in another look. THE LEFT WINDOW wraps its
## long lines at words, or cuts them with the mark and scrolls sideways, by Left and Right while it has the keys
## and no further than its widest line; the choice is kept for the run whatever is selected, stands in the status
## line as what its key will do and in the title while lines are cut; a body of the log that is cut keeps its
## indent; a character of two cells at the edge spills nothing; a table is a line a row in both; and the right
## border of the left window is a scroll bar while it holds more than it shows, whose halves page.
## Offline: no operation of the real tooling is called. The time zone is set here, so the times read the same anywhere.
## Reconciled for F11.0, the table lines: the table of the agents is two cells wider (two spaces between its columns), so the pane scrolls two cells further.
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
rigTmp="$( rigTempDir AgentsManagerScreenLayoutCheck )" || exit 1
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
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
## One session that runs, with two agents, and its feed: a short entry and a long one.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2
rigLong='✉️ to *magic-tester*: please run the named tests once more against live and say exactly which ones you ran, by name, and then wait for the next word from me before anything else is started'
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 2 running=2
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow counters 1 0 1 1 0 0.42
} > "$rigF/rows"
{
	rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log
	rigRow feed 2026-10-13T02:00:05Z "$rigS1" magic-coordinator member magic-coordinator '🧠 round 98 · in 37K · cache 163K · out 56'
	rigRow feed 2026-10-13T02:01:10Z "$rigS1" magic-coordinator member magic-coordinator "$rigLong"
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1"
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigBare(){ ## the commands of the driver on standard input, with no dispatcher: the rows and the lines are the script's own
	rigOut="$( { printf 'workspace /somewhere/ws-rig\nwall 2026-10-13 02:30 +0000\nsize %s\n' "${rigSize:-100 30}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigWide(){ ## tag -- the three widths of the layout of that state and its ratio: the left window to its border, where the list stands, how wide it is
	printf '%s %s %s [%s]' "$( rigVal "$1.viewWidth" )" "$( rigVal "$1.listLeft" )" "$( rigVal "$1.listWidth" )" "$( rigVal "$1.split" )"
}
rigColumn(){ ## tag, column counted from 0, first line, last line -- those cells of one column of a drawn screen, top to bottom
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "$(( $3 + 1 )),$(( $4 + 1 ))p" | "$rigPython" -I -B -c 'import sys
column = int(sys.argv[1])
print("".join(line[column:column + 1] for line in sys.stdin.buffer.read().decode("utf-8").split("\n") if line))' "$2" | LC_ALL=C cat
}
rigChars(){ ## tag, from, to -- those characters of the value of that name, counted from 0; a to below 0 counts from its end
	rigVal "$1" | "$rigPython" -I -B -c 'import sys
text = sys.stdin.buffer.read().decode("utf-8").rstrip("\n")
sys.stdout.buffer.write(text[int(sys.argv[1]):int(sys.argv[2]) or None].encode("utf-8"))' "$2" "$3"
}
rigIndent(){ ## tag... -- the indent of the value of each name, a `_` a blank
	local indentTag
	for indentTag in "$@" ; do rigVal "$indentTag" | LC_ALL=C sed -e 's/^\( *\).*$/\1/' | LC_ALL=C tr ' \n' '_ ' ; done
}

echo "-- the split: a ratio, moved by two keys, within the limits of the right window --"
rigBare <<'RIGSCRIPT'
rows sessions a=alpha b=beta
turn
get first
keys [
get one
said oneSaid
keys TAB [ [ [
get half
size 200 30
get wide
size 100 30
get back
keys ] ] ] ] ] ] ]
get least
said leastSaid
keys ]
get stays
size 80 30
keys [ [ [ [ [ [ [ [ [ [ [
get most
said mostSaid
cells bottom 29 0 31
RIGSCRIPT
rigAssert "until it is moved the list takes the share its place declares, and no ratio is kept" "$( rigWide first )" "69 70 30 []"
rigAssert "[ makes the list a step wider, and the status line says how wide it is now" "$( rigWide one ) [$( rigVal oneSaid )]" "64 65 35 [0.3500] [the list takes 35 of 100 cells]"
rigAssert "it works in the left window too, a step a press"          "$( rigVal half.focus ) $( rigWide half )" "view 49 50 50 [0.5000]"
rigAssert "the largest the right window is drawn is 80 cells, and the ratio that is kept is not rewritten" "$( rigWide wide )" "119 120 80 [0.5000]"
rigAssert "so at the old width the split stands where it stood"       "$( rigWide back )" "49 50 50 [0.5000]"
rigAssert "] makes it narrower, down to its smallest, 20 cells"       "$( rigWide least ) [$( rigVal leastSaid )]" "79 80 20 [0.2000] [the list is at its narrowest: 20 cells]"
rigAssert "at the limit a press keeps the ratio as it is"             "$( rigWide stays )" "79 80 20 [0.2000]"
rigAssert "the left window keeps what a window needs, half of the smallest terminal" "$( rigWide most ) [$( rigVal mostSaid )]" "19 20 60 [0.7500] [the list is at its widest: 60 cells]"
rigAssert "the keys of the split are not in the status line"          "[$( rigVal bottom )]" "[ a Active  u Read  m Menu  ^X E]"

echo "-- the limits are absolute, whatever the width of the terminal, and hold in every style --"
rigSize="60 30" rigBare <<'RIGSCRIPT'
turn
get narrow
size 40 30
get smallest
size 300 30
get huge
style magic
size 100 30
get compact
keys [
get compactMoved
size 60 30
get compactNarrow
RIGSCRIPT
rigAssert "at 60 columns the declared share is 18 cells, and the list is drawn its smallest, 20" "$( rigWide narrow )" "39 40 20 []"
rigAssert "at the smallest terminal too"                             "$( rigVal smallest.layout ) $( rigWide smallest )" "ok 19 20 20 []"
rigAssert "at 300 columns the declared share is 90 cells, and the list is drawn its largest, 80" "$( rigWide huge )" "219 220 80 []"
rigAssert "Magic takes the same split"                               "$( rigVal compact.style ) $( rigWide compact ) / $( rigWide compactMoved ) / $( rigWide compactNarrow )" "nu 69 70 30 [] / 64 65 35 [0.3500] / 38 39 21 [0.3500]"

echo "-- the mouse on the border between the windows --"
rigBare <<'RIGSCRIPT'
rows sessions a=alpha b=beta
turn
mousekey 5 7 BUTTON1_PRESSED
mouse press 70 5
get pressed
mouse click 55 9
get dragged
mouse click 55 5
get held
said heldSaid
roles heldRoles
mouse click 30 9
get put
roles putRoles
mouse click 30 5
mouse click 30 9
get letGo
mouse click 30 5
keys DOWN
get keyed
mouse click 60 9
get after
mouse press 10 9
get elsewhere
mouse click 30 5
mouse click 95 9
get clampedLeast
mouse click 80 5
mouse click 3 9
get clampedMost
mouse click 20 5
mouse click 50 29
get offWindows
tell A box | its text
mouse press 20 5
mouse click 20 5
get boxed
RIGSCRIPT
rigAssert "the first button going down is a press"                   "$( rigVal mousekey )" "MOUSE:press:5:7"
rigAssert "pressed on the border, it takes hold of it"               "$( rigVal pressed.splitHeld ) $( rigWide pressed )" "pressed 69 70 30 []"
rigAssert "let go in another column, the border is put there: a drag" "[$( rigVal dragged.splitHeld )] $( rigWide dragged ) [$( rigVal dragged.notice )]" "[] 54 55 45 [0.4500] [the list takes 45 of 100 cells]"
rigAssert "a click on the border takes hold of it, and the status line says so" "$( rigVal held.splitHeld ) $( rigWide held ) [$( rigVal heldSaid )]" "held 54 55 45 [0.4500] [the border is held: click where it goes, or on it to let it go]"
rigAssert "a held border is drawn in another look, and no more once it is put" "[$( rigColumn heldRoles 55 5 7 )] [$( rigColumn putRoles 30 5 7 )]" "[RRR] [FFF]"
rigAssert "the next click in a window puts it there"                 "[$( rigVal put.splitHeld )] $( rigWide put )" "[] 29 30 70 [0.7000]"
rigAssert "a click on a held border lets it go where it was"          "[$( rigVal letGo.splitHeld )] $( rigWide letGo )" "[] 29 30 70 [0.7000]"
rigAssert "a key lets it go too, and the click after it moves nothing" "[$( rigVal keyed.splitHeld )] $( rigWide after )" "[] 29 30 70 [0.7000]"
rigAssert "a press that is not on the border is nothing"             "[$( rigVal elsewhere.splitHeld )] $( rigVal elsewhere.focus ) $( rigWide elsewhere )" "[] list 29 30 70 [0.7000]"
rigAssert "the mouse cannot put it past the smallest of the right window" "$( rigWide clampedLeast )" "79 80 20 [0.2000]"
rigAssert "nor past its largest"                                     "$( rigWide clampedMost )" "19 20 80 [0.8000]"
rigAssert "a click outside the windows lets a held border go, and puts nothing" "[$( rigVal offWindows.splitHeld )] $( rigWide offWindows )" "[] 19 20 80 [0.8000]"
rigAssert "behind a dialog the border is not taken"                   "[$( rigVal boxed.splitHeld )] $( rigVal boxed.dialogTitle )" "[] A box"

echo "-- the left window wraps its long lines, or cuts them and scrolls sideways --"
rigCase wrap
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN l
wait feed 30
get wrapped
cells wrappedBottom 39 0 120
border wrappedTitle 1 0 84
cells w6 6 1 83
cells w7 7 1 83
cells w8 8 1 83
cells w9 9 1 83
cells w10 10 1 83
keys TAB
turn
cells viewBottom 39 0 120
keys w
turn
get cut
border cutTitle 1 0 84
cells cutBottom 39 0 120
cells c6 6 1 83
cells c7 7 1 83
cells c8 8 1 83
keys RIGHT
get indent
cells i4 4 1 83
cells i5 5 1 83
keys RIGHT
get panned
cells p4 4 1 83
cells p5 5 1 83
keys RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT
get end
cells e7 7 1 83
keys LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT
get start
keys RIGHT TAB UP DOWN
turn
get moved
keys ENTER DOWN
turn
get dived
keys LEFT
get up
keys TAB w
wait feed 30
get again
border againTitle 1 0 84
keys LEFT
get refused
said refusedSaid
RIGSCRIPT
rigAssert "the screen starts with its lines wrapped: a long body takes three lines" "$( rigVal wrapped.wrap ) $( rigVal wrapped.viewLines ) [$( rigVal wrappedTitle )] [$( rigVal w6 )] $( rigIndent w7 w8 w9 )[$( rigVal w10 )]" \
	"yes 7 [daily of Monday [log] [wrap]] [02:01:10 magic-coordinator:] _________ _________ _________ []"
rigAssert "the key of the wrap is a button of both windows: the status line names it, by what it will do, with the list or the left window holding the keys" "[$( rigVal wrappedBottom | LC_ALL=C grep -o ' w [A-Za-z]*' )] [$( rigVal viewBottom | LC_ALL=C grep -o ' w [A-Za-z]*' )]" "[ w Cut] [ w Cut]"
rigAssert "w cuts the lines: the title says so, and the status line names Left and Right" "$( rigVal cut.wrap ) $( rigVal cut.viewLines ) [$( rigVal cutTitle )] [$( rigVal cutBottom | LC_ALL=C grep -o '←/→ Scroll\| w [A-Za-z]*' | tr '\n' '|' )]" "no 5 [daily of Monday [log] [cut]] [←/→ Scroll| w Wrap|]"
rigAssert "a long body is one line, cut with the mark at the border, and still set in" "[$( rigVal c6 )][$( rigChars c7 0 30 )][$( rigChars c7 -1 0 )][$( rigVal c8 )] $( rigVal cut.spills )" \
	"[02:01:10 magic-coordinator:][         ✉️ to *magic-tester*:][…][] 0"
rigAssert "Right scrolls sideways, a step a press: what stands to the left is marked, and an indent is not" "$( rigVal indent.viewLeft ) [$( rigVal i4 )][$( rigVal i5 )] $( rigVal indent.spills )" \
	"8 […magic-coordinator:][ 🧠 round 98 · in 37K · cache 163K · out 56] 0"
rigAssert "and on: a body whose start is out of view is marked too"   "$( rigVal panned.viewLeft ) [$( rigVal p4 )][$( rigVal p5 )] $( rigVal panned.spills )" \
	"16 […ordinator:][… 98 · in 37K · cache 163K · out 56] 0"
rigAssert "no further than the end of the widest line"               "$( rigVal end.viewLeft ) [$( rigVal e7 | LC_ALL=C sed -e 's/^.* \([a-z]* [a-z]* [a-z]*\)$/\1/' )] $( rigVal end.spills )" "115 [else is started] 0"
rigAssert "and Left back to its start"                               "$( rigVal start.viewLeft )" "0"
rigAssert "the choice is kept when the selection moves, and the place sideways is the item's" "$( rigVal moved.wrap ) $( rigVal moved.selected ) $( rigVal moved.viewLeft )" "no $rigS1 0"
rigAssert "and inside a session, where Left and Right in the list are the list's own: Left pages up there" "$( rigVal dived.wrap ) $( rigVal dived.path ) [$( rigVal up.path )] $( rigVal up.selected ) $( rigVal up.wrap )" "no sessions/$rigS1 [sessions/$rigS1] .. no"
rigAssert "w wraps them again"                                       "$( rigVal again.wrap ) $( rigVal again.viewLines ) [$( rigVal againTitle )]" "yes 7 [daily of Monday [log] [wrap]]"
rigAssert "wrapped, nothing stands to the side: Left says so"         "$( rigVal refused.viewLeft ) [$( rigVal refusedSaid )]" "0 [Scroll: the lines are wrapped, none is cut]"

echo "-- a character of two cells at the edge, and a table --"
rigCase table
rigSize="80 24" rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN
wait view 30
get t
show wrappedTable
keys TAB w
turn
show cutTable
get tc
viewline ab🧠cd🧠ef🧠gh and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on
keys RIGHT
get x1
viewline xy
keys LEFT
turn
get x2
RIGSCRIPT
rigAssert "a table is a line a row, wrapped or cut"                  "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^wrappedTable|' | LC_ALL=C cut -c1-70 | LC_ALL=C grep -c 'magic-tester' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^cutTable|' | LC_ALL=C cut -c1-70 | LC_ALL=C grep -c 'magic-tester' )" "1 1"
rigAssert "nothing is drawn past the window, at any place sideways: Right goes no further than the widest line, the table of the agents with no column that none of them has a word for" "$( rigVal t.spills ) $( rigVal tc.spills ) $( rigVal x1.spills ) $( rigVal x2.spills ) $( rigVal x1.viewLeft )" "0 0 0 0 5"

echo "-- the right border of the left window is a scroll bar while it holds more than it shows --"
rigBare <<'RIGSCRIPT'
rows sessions a=alpha b=beta
keys 2 DOWN DOWN
view 5
turn
show few
view 80
turn
show many
get top
keys TAB PGDN PGDN PGDN PGDN
show end
get bottom
mouse click 69 4
get pagedUp
keys TAB
mouse click 69 25
get pagedDown
RIGSCRIPT
rigAssert "lines that fit: the border is the frame's"                "[$( rigColumn few 69 2 4 )]" "[│││]"
rigAssert "more than fit: its ends are the arrows, and the thumb stands at the top" "[$( rigColumn many 69 2 4 )][$( rigColumn many 69 26 27 )] $( rigVal top.viewTop )" "[▲■▒][▒▼] 0"
rigAssert "scrolled to the end, the thumb stands at the bottom"       "[$( rigColumn end 69 25 27 )] $( rigVal bottom.viewTop )" "[▒■▼] 54"
rigAssert "a click on its upper half pages up, and gives the window the keys" "$( rigVal pagedUp.viewTop ) $( rigVal pagedUp.focus )" "28 view"
rigAssert "a click on its lower half pages down, from the other window too" "$( rigVal pagedDown.viewTop ) $( rigVal pagedDown.focus )" "54 view"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LAYOUT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LAYOUT: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
