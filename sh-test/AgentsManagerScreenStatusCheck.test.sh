#!/usr/bin/env bash
## Behavioural check on the two status lines of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run rather than
## read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which prints rows in the form `--manager-session-list` prints,
## ending with its row of counters, or fails as the case says. The time is the case's own.
## Held: the top line shows the workspace by the name of its folder, the load average and the clock; the bottom line
## shows the five counters of the row of counters, the sessions running and paused, the agents working and waiting,
## the asks that wait under the word `pending`, and then the general keys; the counter of paused sessions shows 0;
## the row of counters is read whatever is shown, at the root too, once a period; the clock is the screen's own: it
## moves with no key and no call, and goes on when the read fails, while the counters and the load average stay as
## they were, marked as old, until a good read comes; before the first read no counter is shown; and the bottom
## line names the same general keys whatever is selected. The reads of one selected session are taken out of the
## table here: AgentsManagerScreenPaneCheck holds them.
## Offline: no operation of the real tooling is called. The time zone is set here, so the clock reads the same anywhere.
## Reconciled for F11.0: the left pane has no `keys:` line any more; the status line alone names the keys of the row.
## Reconciled for F11.5: the sessions stand in `Activity`, under `Magic-Team (Agents)`: the root of the counters is that one, and the keys of a session are those of a row of Active Sessions.
## Reconciled for F11.5, the lists of Activity: the key `a` (all or only the active) is not offered there, as it has nothing to take: not in the status line, and not in the menu View.
## Reconciled for F11.6: the status line of a session names the send-message key too, `M Message`, between `k Kill` and `u Read`.
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
rigTmp="$( rigTempDir AgentsManagerScreenStatusCheck )" || exit 1
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
## One running session with a waiting and a working agent, and the row of counters: two sessions running, none
## paused, one agent working, two waiting, three asks, a load average of 0.42.
{
	rigRow session 11111111-0000-4000-8000-000000000001 daily_of_Monday running 2026-10-12_16:57_+0000 - 2 running=2
	rigRow run 11111111-0000-4000-8000-000000000001 a1a1a1a1-0000-4000-8000-0000000000a1 magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run 11111111-0000-4000-8000-000000000001 a2a2a2a2-0000-4000-8000-0000000000a2 magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow counters 2 0 1 2 3 0.42
} > "$rigTmp/first.rows"
{ sed -n '1,3p' "$rigTmp/first.rows" ; rigRow counters 3 0 2 2 4 1.25 ; } > "$rigTmp/second.rows"
rigCase(){ ## name, what the stand-in does at every start, then what it does at start 1, 2, ... where that differs; the rows of the first good start and of the later ones
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	cp "$rigTmp/second.rows" "$MANAGER_SCREEN_RIG/rows"
	cp "$rigTmp/first.rows" "$MANAGER_SCREEN_RIG/rows.1"
	printf '%s\n' "$2" > "$MANAGER_SCREEN_RIG/mode"
	shift 2
	local caseStart=0
	for caseMode in "$@" ; do
		caseStart=$(( caseStart + 1 ))
		printf '%s\n' "$caseMode" > "$MANAGER_SCREEN_RIG/mode.$caseStart"
	done
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the workspace and the time; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\nworkspace /somewhere/ws-rig\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalls(){ ## how many times the stand-in was started. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}
rigSqueeze(){ ## a line with every run of spaces as one
	LC_ALL=C sed -e 's/  */ /g'
}
rigHints=" ENTER Open  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut"
rigMenus=" ≡ Go View Help"

echo "-- the counters show what the row of counters holds --"
rigCase counters rows
rigScript <<'RIGSCRIPT'
root magic-team
turn
get first
cells firstTop 0 0 120
cells firstBottom 39 0 120
border firstFoot 38 0 84
border firstLoad 38 84 120
wait sessions 30
get a
cells top 0 0 120
cells bottom 39 0 120
border foot 38 0 84
border load 38 84 120
looks k
RIGSCRIPT
rigAssert "before the first read no counter and no load average is shown: the border of the left window counts the rows of the table of the folders of Magic-Team (Agents) and nothing else" "[$( rigVal firstTop | rigSqueeze )] [$( rigVal firstFoot )] [$( rigVal firstLoad )] [$( rigVal firstBottom )]" "[$rigMenus ws-rig 02:30:00] [3 rows] [] [$rigHints  t Sort]"
rigAssert "the row of counters is read at the root, with nothing of the sessions shown" "[$( rigVal first.path )] $( rigVal first.reading | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -x 'list:magic-team/activity' ) $( rigCalls ) [$( LC_ALL=C grep -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C sed -n '1p' )]" "[] list:magic-team/activity 1 [--manager-session-list]"
rigAssert "the bottom border of the left window holds how many rows its table holds and no counter, its five counters having left it for the dashboard: the screen holds them as the row gave them; and the status line names the general keys" "[$( rigVal foot )] [$( rigVal bottom )] $( rigVal a.counters )" "[3 rows] [$rigHints  t Sort] load=0.42,paused=0,pending=3,running=2,waiting=2,working=1"
rigAssert "the counter of paused sessions shows 0"                   "$( rigVal a.counters | LC_ALL=C tr ',' '\n' | LC_ALL=C grep '^paused=' )" "paused=0"
rigAssert "the menu bar shows the workspace and the clock, and the bottom border of the list is plain: the load average left it for the dashboard" "[$( rigVal top | rigSqueeze )] [$( rigVal load )]" "[$rigMenus ws-rig 02:30:00] []"
rigAssert "both lines stand across the whole width"                  "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^k|//p' | LC_ALL=C sed -n '1p;40p' | LC_ALL=C tr -d 'RH|\n' | LC_ALL=C wc -c | LC_ALL=C tr -d ' ' )" 0

echo "-- the clock moves with no key and no call --"
rigCase clock rows
rigScript <<'RIGSCRIPT'
wait sessions 30
cells before 0 100 120
wall 2026-10-13 02:31 +0000
turn
cells after 0 100 120
get a
RIGSCRIPT
rigAssert "the top line shows the time"                              "[$( rigVal before | rigSqueeze )]" "[ ws-rig 02:30:00]"
rigAssert "one minute on, with no key, it shows the new time"        "[$( rigVal after | rigSqueeze )]" "[ ws-rig 02:31:00]"
rigAssert "and no call was made for it"                              "$( rigCalls ) [$( rigVal a.reading )]" "1 []"

echo "-- the counters are read again once a period --"
rigCase period rows
rigScript <<'RIGSCRIPT'
wait sessions 30
advance 9
turn 3
get early
advance 2
wait sessions 30
get late
border load 38 84 120
border foot 38 0 84
RIGSCRIPT
rigAssert "not before the period has passed"                         "[$( rigVal early.reading )]" "[]"
rigAssert "then by itself, and the screen holds what the new row holds; the borders hold no counter" "$( rigCalls ) $( rigVal late.counters ) [$( rigVal load )] [$( rigVal foot )]" "2 load=1.25,paused=0,pending=4,running=3,waiting=2,working=2 [] [1 row]"

echo "-- the clock goes on when the read fails --"
rigCase fail rows rows fail fail rows
rigScript <<'RIGSCRIPT'
wait sessions 30
advance 11
wall 2026-10-13 02:30 +0000
wait sessions 30
wall 2026-10-13 02:31 +0000
turn
get bad
cells badTop 0 0 120
border badFoot 38 0 84
border badLoad 38 84 120
style tv
turn
keys ESC
advance 11
wait sessions 30
get worse
advance 11
wait sessions 30
get mended
cells mendedTop 0 0 120
border mendedFoot 38 0 84
border mendedLoad 38 84 120
said mendedLine
RIGSCRIPT
rigAssert "the read failed"                                          "[$( rigVal bad.failed )]" "[list:magic-team/activity]"
rigAssert "the clock still moves"                                    "[$( rigVal badTop | rigSqueeze | LC_ALL=C sed -e 's/^.* //' )]" "[02:31:00]"
rigAssert "the counters stay as they were, marked as old, in the screen's state; the borders hold no counter" "$( rigVal bad.counters ) [$( rigVal badFoot )] [$( rigVal badLoad )]" "load=0.42,paused=0,pending=3,running=2,waiting=2,working=1 [1 row] []"
rigAssert "what the read wrote is shown in a box"                      "[$( rigVal bad.dialogTitle )] [$( rigVal bad.dialogHolds )]" "[A read failed] [operation: --manager-session-list / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "a second failure changes nothing"                         "[$( rigVal worse.failed )] $( rigVal worse.counters )" "[list:magic-team/activity] load=0.42,paused=0,pending=3,running=2,waiting=2,working=1"
rigAssert "a good read takes the marks and the error line away, and brings the new counters" "[$( rigVal mended.failed )] $( rigVal mended.counters ) [$( rigVal mendedLoad )] [$( rigVal mendedFoot )] [$( rigVal mendedLine )]" \
	"[] load=1.25,paused=0,pending=4,running=3,waiting=2,working=2 [] [1 row] []"

echo "-- the status line names the general keys, and after them the keys of what is selected --"
rigCase keys rows
rigScript <<'RIGSCRIPT'
handler kill
keys ENTER
wait sessions 30
keys DOWN
turn
get session
cells sessionBottom 39 0 120
cells sessionKeys 37 1 83
root launch
turn
get launch
cells launchBottom 39 0 120
root pending
turn
get pending
cells pendingBottom 39 0 120
RIGSCRIPT
rigAssert "a running session is selected"                            "$( rigVal session.selected )" "11111111-0000-4000-8000-000000000001"
rigAssert "on a session the status line names the keys that act on it, and after them the keys of every window" "[$( rigVal sessionBottom )]" "[ ENTER Open  BSP Up  k Kill  M Message  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "the keys that act on the session stand in no line of the left pane" "[$( rigVal sessionKeys | LC_ALL=C sed -n 's/^\(keys:\).*/\1/p' )]" "[]"
rigAssert "on Launch (Start) it names what the list takes there, then the keys of every window"        "$( rigVal launch.selected ) [$( rigVal launchBottom )]" "launch [ ENTER Open  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "and on another section"                                   "$( rigVal pending.selected ) [$( rigVal pendingBottom )]" "pending [$rigHints]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN STATUS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_STATUS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
