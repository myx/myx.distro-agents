#!/usr/bin/env bash
## Behavioural check on the section `Sessions / Activity` of the manager screen (sh-lib/AgentsManagerScreen.py), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the case's fixture: rows in the
## form `--manager-session-list` prints, TAB between the fields, a `session` row, its `run` rows, and one last
## `counters` row. Held: `Launch / Spawn` is the first row under the row that goes up, also when there is no
## session; then comes every session the operation gives, in its order, the newest first, each by its name with the
## spaces the registry wrote as `_`, or by its id where it has none, with its state at the end of its row; a session
## that is one lone run with no name shows plainer: dimmed, by the member that ran and the head of its id; `a` asks
## the operation again with `--active` and shows what that gives, and `a` again all of them; Enter dives into a
## session and lists its agents under the row that goes up, each by its member with its state and, where it is
## alive, its activity, and Left returns onto that session; the left pane shows the selected session from the same
## rows: its state, when it started and ended, how many agents and in which states, and each agent; and the
## selected agent: its state, status, process, dates, host, workspace and ids; a list read again keeps the selection
## on the same session; a session that is gone from the list takes its level with it; and with five hundred
## sessions PageDown reaches the last one, a drawing writes no more rows than with five, and four hundred keys are
## taken in a few seconds; and inside a session `a` throws nobody out: the level of that session is read without
## the filter and keeps its agents, whatever its state, while the list above it shows the active ones.
## The reads of one selected session or agent are taken out of the table here: AgentsManagerScreenPaneCheck holds them.
## Offline: no operation of the real tooling is called, and no session of this machine is read.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenSessionsCheck )" || exit 1
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
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003
rigS4=44444444-0000-4000-8000-000000000004 ; rigS5=55555555-0000-4000-8000-000000000005
## Five sessions, the newest first: a named one that runs, with three agents (one waits, one works, one has ended);
## one with no name and two agents, waiting; one lone run with no name, finished; one of another host; one lone
## run with no name whose record is still open. Then the row of counters.
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0300 - 3 running=2,finished=1
	rigRow run "$rigS1" a1a1a1a1-0000-4000-8000-0000000000a1 magic-coordinator spawn-started running running 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow run "$rigS1" a2a2a2a2-0000-4000-8000-0000000000a2 magic-tester spawn-started running running 2026-10-12_17:05_+0300 - rig-host ws-rig working
	rigRow run "$rigS1" - keeper-myx spawn-succeeded no-spawn-id finished 2026-10-12_17:06_+0300 2026-10-12_18:00_+0300 rig-host ws-rig -
	rigRow session "$rigS2" - waiting 2026-10-12_09:00_+0300 - 2 finished=2
	rigRow run "$rigS2" b1b1b1b1-0000-4000-8000-0000000000b1 magic-librarian spawn-succeeded no-process finished 2026-10-12_09:00_+0300 2026-10-12_09:30_+0300 rig-host ws-rig -
	rigRow run "$rigS2" b2b2b2b2-0000-4000-8000-0000000000b2 magic-developer spawn-failed no-process finished 2026-10-12_09:10_+0300 2026-10-12_09:20_+0300 rig-host ws-rig -
	rigRow session "$rigS3" - finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 1 finished=1
	rigRow run "$rigS3" "$rigS3" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 rig-host ws-rig -
	rigRow session "$rigS4" far_away unknown-foreign 2026-10-10_08:00_+0300 - 1 unknown-foreign=1
	rigRow run "$rigS4" d1d1d1d1-0000-4000-8000-0000000000d1 keeper-mel spawn-started unknown-foreign unknown-foreign 2026-10-10_08:00_+0300 - other-host ws-rig -
	rigRow session "$rigS5" - unclosed 2026-09-30_10:34_+0300 - 1 unclosed=1
	rigRow run "$rigS5" e1e1e1e1-0000-4000-8000-0000000000e1 keeper-ae3 spawn-started no-process unclosed 2026-09-30_10:34_+0300 - rig-host ws-rig -
	rigRow counters 1 0 1 1 3 0.42
} > "$rigTmp/five.rows"
## What --active gives of them: the one that runs, and the same row of counters.
{ sed -n '1,4p' "$rigTmp/five.rows" ; rigRow counters 1 0 1 1 3 0.42 ; } > "$rigTmp/active.rows"
## The same five in another order, the lone finished one gone.
{ sed -n '5,7p' "$rigTmp/five.rows" ; sed -n '1,4p' "$rigTmp/five.rows" ; sed -n '10,14p' "$rigTmp/five.rows" ; } > "$rigTmp/moved.rows"
rigRow counters 0 0 0 0 0 0.10 > "$rigTmp/none.rows"
## A fresh rig for one case: no call noted yet, and what the stand-in prints at every start, then at start 1, 2, ... where that differs.
rigCase(){ ## name, the fixture of every start, then the fixtures of the starts 1, 2, ...
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
	cp "$rigTmp/$2" "$MANAGER_SCREEN_RIG/rows"
	shift 2
	local caseStart=0
	for caseRows in "$@" ; do
		caseStart=$(( caseStart + 1 ))
		cp "$rigTmp/$caseRows" "$MANAGER_SCREEN_RIG/rows.$caseStart"
	done
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in and the time; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0300\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalls(){ ## how many times the stand-in was started
	LC_ALL=C grep -c '' "$MANAGER_SCREEN_RIG/calls" || :
}
rigCall(){ ## number -- the arguments of that start
	LC_ALL=C sed -n "${1}p" "$MANAGER_SCREEN_RIG/calls"
}
rigLooks(){ ## tag, line counted from 1, the cells from and to counted from 1 -- how those cells are drawn
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}

echo "-- the sessions, each by its name or its id, with its state --"
rigCase list five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
get a
cells title 1 84 120
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells row4 5 84 120
cells row5 6 84 120
cells row6 7 84 120
cells row7 8 84 120
cells row8 9 84 120
looks k
RIGSCRIPT
rigAssert "the operation is --manager-session-list"                  "[$( rigCall 1 )]" "[--manager-session-list]"
rigAssert "Launch / Spawn is the first row under the row that goes up" "[$( rigVal row1 )][$( rigVal row2 )] $( rigVal a.rows )" "[>..][ Launch / Spawn] 7"
rigAssert "a session with a name shows its name, with its spaces, and its state" "[$( rigVal row3 )]" "[ daily of Monday             running]"
rigAssert "one without a name shows the id of its session"           "[$( rigVal row4 )]" "[ 22222222-0000-4000-8000-00… waiting]"
rigAssert "one lone run with no name shows plainer: the member that ran and the head of its id" "[$( rigVal row5 )]" "[ magic-devops 33333333      finished]"
rigAssert "a session of another host carries its own state"          "[$( rigVal row6 )]" "[ far away            unknown-foreign]"
rigAssert "and one whose record is still open"                       "[$( rigVal row7 )][$( rigVal row8 )]" "[ keeper-ae3 55555555        unclosed][]"
rigAssert "a running session stands out, a lone run is dimmed, the others are plain" \
	"$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )$( rigLooks k 7 86 86 )$( rigLooks k 8 86 86 )$( rigLooks k 9 86 86 )" "B.D.D"
rigAssert "the title says that all are shown"                        "[$( rigVal title )]" "[ Sessions / Activity  [all]]"

echo "-- no session at all --"
rigCase none none.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
get a
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells line1 2 0 83
RIGSCRIPT
rigAssert "the level shows the row that goes up, then Launch / Spawn, and nothing more" "$( rigVal a.rows ) [$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )]" "2 [>..][ Launch / Spawn][]"
rigAssert "and the left pane says that there is none"                "[$( rigVal line1 )]" "[ 0 sessions.]"

echo "-- a: all or active --"
rigCase active five.rows five.rows active.rows five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN DOWN
keys a
wait sessions 30
get active
cells activeTitle 1 84 120
cells activeRow3 4 84 120
cells activeRow4 5 84 120
keys a
wait sessions 30
get all
cells allTitle 1 84 120
RIGSCRIPT
rigAssert "a asks the operation again, with --active"                "$( rigCalls ) [$( rigCall 2 )]" "3 [--manager-session-list --active]"
rigAssert "the sessions that are not active are gone from the list"  "$( rigVal active.rows ) [$( rigVal activeTitle )] [$( rigVal activeRow3 )][$( rigVal activeRow4 )]" "3 [ Sessions / Activity  [active]] [>daily of Monday             running][]"
rigAssert "a again asks without it, and shows them all again"        "[$( rigCall 3 )] $( rigVal all.rows ) [$( rigVal allTitle )] $( rigVal all.selected )" "[--manager-session-list] 7 [ Sessions / Activity  [all]] $rigS1"

echo "-- diving into a session shows its agents --"
rigCase dive five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER
get in
cells title 1 84 120
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells row4 5 84 120
cells row5 6 84 120
looks k
keys DOWN DOWN
turn
get agent
show s
keys LEFT
get back
keys RIGHT LEFT
get again
RIGSCRIPT
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//'
}
rigAssert "Enter on a session shows its level, titled by the session" "$( rigVal in.path ) [$( rigVal title )]" "sessions/$rigS1 [ daily of Monday]"
rigAssert "its three agents stand under the row that goes up, each by its member" "$( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row5 )]" "4 [>..][]"
rigAssert "a live agent with its state and its activity: waiting or working" "[$( rigVal row2 )][$( rigVal row3 )]" "[ magic-coordinator   running waiting][ magic-tester        running working]"
rigAssert "one that has ended with its state alone"                  "[$( rigVal row4 )]" "[ keeper-myx                 finished]"
rigAssert "the live ones stand out"                                  "$( rigLooks k 4 86 86 )$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )" "BB."
rigAssert "the level has no read of its own: the list of the sessions fills it" "$( rigCalls ) $( rigVal in.reading )" "1 "
rigAssert "the left pane shows the selected agent: state, status, process, dates" "$( rigVal agent.selected ) [$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 5 )][$( rigPane s 6 )]" \
	"a2a2a2a2-0000-4000-8000-0000000000a2 [ state     running working][ status    spawn-started][ process   running][ started   2026-10-12 17:05 +0300 (9h ago)]"
rigAssert "its host, its workspace, its own id and its session"      "[$( rigPane s 7 )][$( rigPane s 8 )][$( rigPane s 9 )][$( rigPane s 10 )]" \
	"[ host      rig-host][ workspace ws-rig][ run       a2a2a2a2-0000-4000-8000-0000000000a2][ session   $rigS1]"
rigAssert "Left returns onto the session it came from"               "$( rigVal back.path ) $( rigVal back.selected )" "sessions $rigS1"
rigAssert "Right dives in as Enter does"                             "$( rigVal again.path ) $( rigVal again.selected )" "sessions $rigS1"

echo "-- the left pane shows the selected session, from the same rows --"
rigCase pane five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get a
show s
keys DOWN DOWN
turn
show t
keys UP UP UP UP
turn
show u
RIGSCRIPT
rigAssert "one read gave all of it"                                  "$( rigCalls ) $( rigVal a.selected )" "1 $rigS1"
rigAssert "its state, and when it started"                           "[$( rigPane s 2 )][$( rigPane s 3 )][$( rigPane s 4 )]" "[ daily of Monday][ state     running][ started   2026-10-12 16:57 +0300 (9h ago)]"
rigAssert "how many agents it has, and in which states"              "[$( rigPane s 5 )][$( rigPane s 6 )]" "[ agents    3: 2 running, 1 finished][ session   $rigS1]"
rigAssert "each agent with its state"                                "[$( rigPane s 8 )][$( rigPane s 9 )][$( rigPane s 10 )]" \
	"[ magic-coordinator  running waiting  since 2026-10-12 16:57 +0300][ magic-tester       running working  since 2026-10-12 17:05 +0300][ keeper-myx         finished         until 2026-10-12 18:00 +0300]"
rigAssert "a lone run says that it is one, and when it ended"        "[$( rigPane t 3 )][$( rigPane t 5 )][$( rigPane t 7 )][$( rigPane t 8 )]" \
	"[ one lone run with no name][ state     finished][ ended     2026-10-11 14:51 +0300 (35h ago)][ agents    1: 1 finished]"
rigAssert "on the row that goes up the pane says what the section holds" "[$( rigPane u 3 )][$( rigPane u 4 )]" "[ 5 sessions.][ In the workspace: sessions 1 running, 0 paused; agents 1 working, 1 waiting.]"

echo "-- the list read again --"
rigCase again five.rows five.rows moved.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN DOWN DOWN DOWN
get before
keys ENTER
get inLone
keys LEFT UP UP
get named
advance 11
wait sessions 30
get after
cells row3 4 84 120
cells row4 5 84 120
keys DOWN DOWN DOWN
get end
RIGSCRIPT
rigAssert "the lone run is selected, and holds its one agent"        "$( rigVal before.selected ) $( rigVal inLone.rows )" "$rigS3 2"
rigAssert "the named session is selected, the third row"             "$( rigVal named.selected ) $( rigVal named.index )" "$rigS1 2"
rigAssert "read again in another order, the selection stays on that session" "$( rigVal after.selected ) $( rigVal after.index ) $( rigVal after.rows ) [$( rigVal row3 )][$( rigVal row4 )]" \
	"$rigS1 3 6 [ 22222222-0000-4000-8000-00… waiting][>daily of Monday             running]"
rigAssert "the session that is gone from the list is gone from the screen" "$( rigVal end.selected ) $( rigVal end.index )" "$rigS5 5"

echo "-- inside a session, a throws nobody out --"
rigCase inside five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN DOWN DOWN ENTER DOWN
get in
keys a
get pressed
wait sessions 30
get after
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells title 1 84 120
advance 11
wait sessions 30
get later
keys LEFT
get up
wait sessions 30
get list
cells listTitle 1 84 120
cells listRow3 4 84 120
cells listRow4 5 84 120
RIGSCRIPT
rigAssert "a session that is not active is entered, one of its agents selected" "$( rigVal in.path ) $( rigVal in.rows ) $( rigVal in.selected )" "sessions/$rigS2 3 b1b1b1b1-0000-4000-8000-0000000000b1"
rigAssert "a switches to the active ones, and the person is still in that session, on that agent" "$( rigVal pressed.filter ) $( rigVal after.path ) $( rigVal after.rows ) $( rigVal after.selected )" "active sessions/$rigS2 3 b1b1b1b1-0000-4000-8000-0000000000b1"
rigAssert "its agents are all there"                                 "[$( rigVal title )] [$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )]" "[ 22222222-0000-4000-8000-0000000000…] [ ..][>magic-librarian            finished][ magic-developer            finished]"
rigAssert "inside a session the list is read without the filter, also on the period" "$( LC_ALL=C grep -c -- '--active' "$MANAGER_SCREEN_RIG/calls" || : ) $( rigVal later.rows )" "1 3"
rigAssert "Left returns to the list, which is read with the filter again" "$( rigVal up.path ) [$( LC_ALL=C sed -n '$p' "$MANAGER_SCREEN_RIG/calls" )]" "sessions [--manager-session-list --active]"
rigAssert "and shows the active ones only, whatever answer it holds" "$( rigVal up.rows ) $( rigVal list.rows ) [$( rigVal listTitle )] [$( rigVal listRow3 )][$( rigVal listRow4 )]" "3 3 [ Sessions / Activity  [active]] [>daily of Monday             running][]"

echo "-- five hundred sessions --"
{
	rigNumber=500
	while [ "$rigNumber" -ge 1 ] ; do
		rigId="$( printf '%08d-0000-4000-8000-000000000000' "$rigNumber" )"
		rigRow session "$rigId" "$( printf 'session_%03d' "$rigNumber" )" finished 2026-10-01_10:00_+0300 2026-10-01_11:00_+0300 2 finished=2
		rigRow run "$rigId" "$( printf '%08d-0000-4000-8000-00000000000a' "$rigNumber" )" magic-developer spawn-succeeded no-process finished 2026-10-01_10:00_+0300 2026-10-01_10:30_+0300 rig-host ws-rig -
		rigRow run "$rigId" "$( printf '%08d-0000-4000-8000-00000000000b' "$rigNumber" )" magic-tester spawn-succeeded no-process finished 2026-10-01_10:10_+0300 2026-10-01_11:00_+0300 rig-host ws-rig -
		rigNumber=$(( rigNumber - 1 ))
	done
	rigRow counters 0 0 0 0 0 0.10
} > "$rigTmp/many.rows"
rigKeys(){ ## key, count -- that key that many times, on one line
	local keysText="" keysLeft="$2"
	while [ "$keysLeft" -gt 0 ] ; do keysText="$keysText $1" ; keysLeft=$(( keysLeft - 1 )) ; done
	printf '%s' "$keysText"
}
rigCase few five.rows
rigScript <<'RIGSCRIPT'
size 120 33
keys ENTER
wait sessions 30
get few
RIGSCRIPT
rigPutsFew="$( rigVal few.puts )"
rigCase many many.rows
rigSecondsBefore="$SECONDS"
rigScript <<RIGSCRIPT
size 120 33
keys ENTER
wait sessions 30
get a
keys$( rigKeys DOWN 400 )
get moved
cells movedRow 31 84 120
keys$( rigKeys PGDN 20 )
get last
cells lastRow 31 84 120
keys ENTER
get in
keys LEFT$( rigKeys PGUP 20 )
get first
RIGSCRIPT
rigSecondsTaken=$(( SECONDS - rigSecondsBefore ))
rigAssert "the pane has thirty lines, and the level five hundred sessions under its two first rows" "$( rigVal a.listHeight ) $( rigVal a.rows )" "30 502"
rigAssert "four hundred times Down moves the selection four hundred rows, with its row in view" "$( rigVal moved.index ) $( rigVal moved.top ) [$( rigVal movedRow )]" "400 371 [>session 102                finished]"
rigAssert "PageDown reaches the last one"                            "$( rigVal last.index ) $( rigVal last.top ) [$( rigVal lastRow )]" "501 472 [>session 001                finished]"
rigAssert "it can be dived into like the first"                      "$( rigVal in.path ) $( rigVal in.rows )" "sessions/00000001-0000-4000-8000-000000000000 3"
rigAssert "PageUp returns to the first row"                          "$( rigVal first.index ) $( rigVal first.top )" "0 0"
rigAssert "a drawing writes no more than with five sessions: only the rows in view" "$( rigVal last.puts ) $( rigVal last.spills )" "$rigPutsFew 0"
rigAssert "all those keys were taken in a few seconds"               "$( [ "$rigSecondsTaken" -lt 15 ] && printf yes || printf 'no (%s seconds)' "$rigSecondsTaken" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SESSIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SESSIONS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
