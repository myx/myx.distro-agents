#!/usr/bin/env bash
## Behavioural check on how the manager screen reads through operations of the tooling (sh-lib/AgentsManagerScreen.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start with its arguments and then prints rows,
## sleeps or fails as the case says. Time is a number the case moves, so no case waits for a period to pass.
## Held: the root asks for nothing; the level of `Sessions (Activity)` asks `--manager-session-list` once, as a
## process of its own, and what it printed becomes rows, a record a line, its fields split at each TAB; `a` asks
## again at once with `--active`; a call that sleeps five seconds does not hold a key: the selection moves while it
## runs, and the title carries the mark of a read; a call that fails shows its first error line, not the line of
## noise before it, and the rows of the last good call stay, marked as old, until a good call comes; the period that
## passes twice while one call runs starts no second call; nothing is read again before the period has passed, and
## the key that checks now starts a read at once; an answer asked before the filter changed is dropped and asked
## again; the left pane reads the item that is selected, and an answer that comes for an item that is no longer
## selected is dropped; and a dispatcher that cannot be started at all is shown as a failed call.
## These cases hold how a read is made, not what a section shows: the list of `Sessions (Activity)` stands in their
## table as a plain list in the stand-in's form, read only while it is shown, and the list of the asks is taken out,
## so every start the stand-in notes is one of the case's own. What the sessions and the asks show, and the read
## that is made whatever is shown, are held by AgentsManagerScreenSessionsCheck, AgentsManagerScreenStatusCheck and
## AgentsManagerScreenPendingCheck.
## Offline: no operation of the real tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.test.py"
rigTools="$rigFixtures/manager-screen.tools.test.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
rigTmp="$( mktemp -d -t AgentsManagerScreenReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A fresh rig for one case: no call noted yet, the rows the stand-in prints, and what it does at each start.
rigCase(){ ## name, what the stand-in does at every start, then what it does at start 1, 2, ... where that differs
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	printf '%s\n' "$2" > "$MANAGER_SCREEN_RIG/mode"
	printf 's1\talpha\trunning\ns2\tbeta\tfinished\ns3\tgamma\tfinished\n' > "$MANAGER_SCREEN_RIG/rows"
	shift 2
	local caseStart=0
	for caseMode in "$@" ; do
		caseStart=$(( caseStart + 1 ))
		printf '%s\n' "$caseMode" > "$MANAGER_SCREEN_RIG/mode.$caseStart"
	done
}
rigScript(){ ## the commands of the driver on standard input, after the one that names the stand-in; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable list:sessions --manager-session-list +active --active\nroot sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalls(){ ## how many times the stand-in was started. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}
rigCall(){ ## number -- the arguments of that start
	## the list of the locations, which every start of the screen reads first, is not counted
	LC_ALL=C grep -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C sed -n "${1}p"
}

echo "-- the list of Sessions (Activity) is read through its operation --"
rigCase list rows
rigScript <<'RIGSCRIPT'
size 120 40
turn 3
get root
keys ENTER
get asked
wait list 30
get a
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
RIGSCRIPT
rigAssert "the root asks the tooling for nothing"                    "[$( rigVal root.reading )]" "[]"
rigAssert "the level asks at once, and the call runs beside the screen" "$( rigVal asked.path ) $( rigVal asked.reading )" "sessions list:sessions"
rigAssert "the operation is --manager-session-list, started once"    "$( rigCalls ) [$( rigCall 1 )]" "1 [--manager-session-list]"
rigAssert "what it printed is rows under Launch / Spawn, a record a line, its fields split at each TAB" \
	"[$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )][$( rigVal row6 )]" \
	"[>..][ Launch / Spawn                  ►][ s1  alpha  running][ s2  beta  finished][ s3  gamma  finished][]"
rigAssert "nothing is read any more, and nothing is marked"          "$( rigVal a.rows ) [$( rigVal a.reading )] [$( rigVal a.failed )] [$( rigVal title )]" "5 [] [] [Sessions (Activity)  [all]]"

echo "-- a: the active ones are asked for, at once --"
rigCase active rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait list 30
keys a
get asked
wait list 30
get a
border title 1 84 120
turn 3
get later
RIGSCRIPT
rigAssert "a starts a read at once"                                  "$( rigVal asked.filter ) $( rigVal asked.reading )" "active list:sessions"
rigAssert "with --active after the operation"                        "$( rigCalls ) [$( rigCall 2 )]" "2 [--manager-session-list --active]"
rigAssert "and the title says which are shown"                       "[$( rigVal title )]" "[Sessions (Activity)  [active]]"

echo "-- a slow call does not hold a key --"
rigCase slow "sleep 5"
rigSecondsBefore="$SECONDS"
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
get started
keys DOWN
get moved
border title 1 84 120
cells row2 3 85 119
keys TAB TAB UP
get again
RIGSCRIPT
rigSecondsTaken=$(( SECONDS - rigSecondsBefore ))
rigAssert "the call was started, and runs"                           "$( rigCalls ) $( rigVal started.reading ) $( rigVal started.index )" "1 list:sessions 0"
rigAssert "Down moves the selection at once, while it runs"          "$( rigVal moved.index ) $( rigVal moved.selected ) $( rigVal moved.reading ) [$( rigVal row2 )]" "1 launch list:sessions [>Launch / Spawn                  ►]"
rigAssert "the title carries the mark of a read, over what is known so far" "[$( rigVal title )]" "[~ Sessions (Activity)  [all]]"
rigAssert "every other key goes on working too"                      "$( rigVal again.index ) $( rigVal again.focus ) $( rigVal again.reading )" "0 list list:sessions"
rigAssert "none of that waited for the five seconds of the call"     "$( [ "$rigSecondsTaken" -lt 4 ] && printf yes || printf 'no (%s seconds)' "$rigSecondsTaken" )" yes

echo "-- a failed call shows its error and keeps the old rows --"
rigCase fail rows rows fail fail rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait list 30
keys DOWN DOWN
get good
advance 11
wait list 30
get bad
border badTitle 1 84 120
cells badRow3 4 85 119
cells badRow5 6 85 119
keys ESC
advance 11
wait list 30
get worse
advance 11
wait list 30
get mended
border mendedTitle 1 84 120
said mendedLine
RIGSCRIPT
rigAssert "the first call gave three rows"                           "$( rigVal good.rows ) $( rigVal good.selected ) [$( rigVal good.failed )]" "5 s1 []"
rigAssert "the second call failed, after the period"                 "$( rigCalls ) [$( rigVal bad.failed )]" "4 [list:sessions]"
rigAssert "the three rows stay, and the selection with them"         "$( rigVal bad.rows ) $( rigVal bad.selected ) [$( rigVal badRow3 )][$( rigVal badRow5 )]" "5 s1 [>s1  alpha  running][ s3  gamma  finished]"
rigAssert "they are marked as old"                                   "[$( rigVal badTitle )]" "[! Sessions (Activity)  [all]]"
rigAssert "what the read wrote is shown in a box, whole, with its operation" "[$( rigVal bad.dialogTitle )] [$( rigVal bad.dialogHolds )]" "[A read failed] [operation: --manager-session-list / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "a second failure keeps them still"                        "$( rigVal worse.rows ) [$( rigVal worse.failed )]" "5 [list:sessions]"
rigAssert "a good call takes the mark and the error line away"       "$( rigVal mended.rows ) [$( rigVal mended.failed )] [$( rigVal mendedTitle )] [$( rigVal mendedLine )]" "5 [] [Sessions (Activity)  [all]] []"

echo "-- a second read is not started while the first runs --"
rigCase once "sleep 5"
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
advance 11
turn
advance 11
turn
keys F5
turn
get a
RIGSCRIPT
rigAssert "the period passed twice, and the key that checks now was pressed: the stand-in was started once" "$( rigCalls ) $( rigVal a.reading )" "1 list:sessions"

echo "-- the period, and the key that checks now --"
rigCase now rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait list 30
advance 9
turn 5
get early
RIGSCRIPT
rigAssert "before the period has passed nothing is read again"       "$( rigCalls ) [$( rigVal early.reading )]" "1 []"
rigCase now2 rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait list 30
advance 9
keys F5
get pressed
wait list 30
advance 2
turn 3
get after
advance 9
wait list 30
RIGSCRIPT
rigAssert "the key that checks now starts a read at once"            "$( rigVal pressed.reading ) [$( rigCall 2 )]" "list:sessions [--manager-session-list]"
rigAssert "the period counts from that read"                         "[$( rigVal after.reading )]" "[]"
rigAssert "and when it has passed the list is read again by itself"  "$( rigCalls )" 3

echo "-- an answer asked before the filter changed is dropped --"
rigCase stale rows "sleep 2" fail
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER a
get a
wait list 30
get b
RIGSCRIPT
rigAssert "a was pressed while the read for all still ran"           "$( rigVal a.reading ) $( rigVal a.filter ) $( rigVal a.rows )" "list:sessions active 2"
rigAssert "the read with the new words starts when the one that runs has ended" "$( rigCalls ) [$( rigCall 1 )] [$( rigCall 2 )]" "2 [--manager-session-list] [--manager-session-list --active]"
rigAssert "what the first one printed, for all, is not shown as the active ones" "$( rigVal b.rows ) [$( rigVal b.failed )]" "2 [list:sessions]"

echo "-- the left pane reads what is selected, and a late answer for another item is dropped --"
rigCase view rows
printf 'the first line of the item\nits second line\n' > "$MANAGER_SCREEN_RIG/rows"
rigScript <<'RIGSCRIPT'
size 120 40
table list:sessions none
table view:sessions:launch --rig-view {id}
# the row is a folder too, and a folder is read while it is selected: its own list is put off here, since this case is of the read of one item
table list:sessions/launch none
keys ENTER DOWN
advance 1
turn
get asked
wait view 30
get a
cells line1 2 1 83
cells line2 3 1 83
border title 1 0 84
keys UP
get up
cells upLine1 2 1 83
RIGSCRIPT
rigAssert "the operation of that view is asked with the id of the row" "$( rigVal asked.reading ) $( rigCalls ) [$( rigCall 1 )]" "view:sessions|launch:launch 1 [--rig-view launch]"
rigAssert "the pane shows what it printed"                           "$( rigVal a.viewLines ) [$( rigVal line1 )][$( rigVal line2 )] [$( rigVal title )]" "2 [the first line of the item][its second line] [Launch / Spawn [wrap]]"
rigAssert "moving the selection replaces the pane"                   "$( rigVal up.selected ) $( rigVal up.viewLines ) [$( rigVal upLine1 )]" ".. 0 []"
rigCase late "sleep 2"
printf 'a line of the item that was left\n' > "$MANAGER_SCREEN_RIG/rows"
rigScript <<'RIGSCRIPT'
size 120 40
table list:sessions none
table view:sessions:launch --rig-view {id}
# the row is a folder too, and a folder is read while it is selected: its own list is put off here, since this case is of the read of one item
table list:sessions/launch none
keys ENTER DOWN
advance 1
turn
get asked
keys UP
wait view 30
get a
cells line1 2 1 83
RIGSCRIPT
rigAssert "the read for one item is slow, and the selection moves on before it ends" "$( rigVal asked.reading ) $( rigCalls )" "view:sessions|launch:launch 1"
rigAssert "when the answer comes, the pane still shows the item that is selected now" "$( rigVal a.selected ) $( rigVal a.viewLines ) [$( rigVal line1 )] [$( rigVal a.reading )]" ".. 0 [] []"

echo "-- a dispatcher that cannot be started --"
rigCase gone rows
rigOut="$( printf '%s\n' "tools $rigTmp/no-such-dispatcher" "table list:pending none" "table list:sessions --manager-session-list +active --active" "table list:places none" "size 120 40" "root sessions" "keys ENTER" "turn" "get a" "said line" | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
## the list of the locations is read by no operation here: it would fail the same way, and its box would stand in front of this one
rigAssert "it is shown as a failed call, and the screen goes on"     "[$( rigVal a.failed )] $( rigVal a.quit ) $( rigVal a.dialogHolds | LC_ALL=C grep -c -- 'operation: --manager-session-list / could not be started: ' )" "[list:sessions] no 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_READ: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
