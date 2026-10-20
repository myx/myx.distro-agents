#!/usr/bin/env bash
## Behavioural check on the section `Sessions (Activity)` of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the case's fixture: rows in the
## form `--manager-session-list` prints, TAB between the fields, a `session` row, its `run` rows, and one last
## `counters` row. Held: `Launch (Start)` is the first row under the row that goes up, also when there is no
## session; then comes every session the operation gives, in its order, the newest first, each by its name with the
## spaces the registry wrote as `_`, or by its id where it has none, with its state at the end of its row; a session
## that is one lone run with no name shows plainer: dimmed, by the member that ran and the head of its id; `a` asks
## the operation again with `--active` and shows what that gives, and `a` again all of them; Enter dives into a
## session and lists its agents under the row that goes up, each by its member with its state and, where it is
## alive, its activity, and Backspace returns onto that session; the left pane shows the selected session from the same
## rows: its state, when it started and ended, how many agents and in which states, and each agent; and the
## selected agent: its state, status, process, dates, host, workspace and ids; a list read again keeps the selection
## on the same session; a session that is gone from the list takes its level with it; and with five hundred
## sessions PageDown reaches the last one, a drawing writes no more rows than with five, and four hundred keys are
## taken in a few seconds; and inside a session `a` throws nobody out: the level of that session is read without
## the filter and keeps its agents, whatever its state, while the list above it shows the active ones.
## And a `session` row of the eight fields alone still draws: the pane of its session says `-` of the control
## thread. With the three more fields at its end -- the state the control thread of a session stored, its date, and
## whether that thread lives -- the list marks the one session whose thread is gone and the pane of a session says
## what they tell; everything else, the left pane of an agent and the level of a session among it, is drawn cell
## for cell as from rows without them. AgentsManagerScreenControlCheck holds what is shown of the control thread.
## The reads of one selected session or agent are taken out of the table here: AgentsManagerScreenPaneCheck holds them.
## Offline: no operation of the real tooling is called, and no session of this machine is read.
## Reconciled for F11.0: `Launch / Spawn` is named `Launch (Start)`, `Consoles (Tools)` `Consoles`; the spacer under
## `Launch (Start)` moves each session row of the list one line down.
## Reconciled for F11.0, the table lines: two spaces between the columns, an empty line between the rows of the sessions' table, and the columns reassessed for the fewest lines.
## Reconciled for F11.5: the body of the case is rewritten: the sessions are Active Sessions, Closed Sessions and Top Tokens of Activity, the agents Active, Waiting and Closed Agents; a session opens to its participants.
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
rigTmp="$( rigTempDir AgentsManagerScreenSessionsCheck )" || exit 1
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\ntable view:magic-team/activity/active-sessions/*:record none\ntable view:magic-team/activity/active-sessions/*/*:transcript none\ntable feed:magic-team/activity/active-sessions/*/*:transcript none\nwall 2026-10-13 02:30 +0300\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalls(){ ## how many times the stand-in was started. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}
rigCall(){ ## number -- the arguments of that start, the list of the locations, which every start of the screen reads and `a` reads again, not counted
	LC_ALL=C grep -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C sed -n "${1}p"
}
rigLooks(){ ## tag, line counted from 1, the cells from and to counted from 1 -- how those cells are drawn
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}

rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}

echo "-- the sessions, each by its name or its id, with its state: Active Sessions, and Closed Sessions --"
rigCase list five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
get a
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
looks k
at @activity closed-sessions
wait sessions 30
get c
border closedTitle 1 84 120
cells crow1 2 85 119
cells crow2 3 85 119
cells crow3 4 85 119
looks cl
RIGSCRIPT
rigAssert "the operation is --manager-session-list, and read once for both lists"  "[$( rigCall 1 )] $( rigCalls )" "[--manager-session-list] 1"
rigAssert "Active Sessions holds the sessions that are not closed, the row that goes up first, in the order of the operation" "[$( rigVal row1 )] $( rigVal a.rows )" "[>..] 5"
rigAssert "a session with a name shows its name, with its spaces, and its state" "[$( rigVal row2 )]" "[ daily of Monday         running ►]"
rigAssert "one without a name shows the id of its session"           "[$( rigVal row3 )]" "[ 22222222-0000-4000-800… waiting ►]"
rigAssert "a session of another host carries its own state"          "[$( rigVal row4 )]" "[ far away        unknown-foreign ►]"
rigAssert "one lone run with no name shows plainer: the member that ran and the head of its id, and one whose record is still open has its state" "[$( rigVal row5 )][$( rigVal row6 )]" "[ keeper-ae3 55555555    unclosed ►][]"
rigAssert "a running session stands out, a lone run is dimmed, the others are plain" \
	"$( rigLooks k 4 86 86 )$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )$( rigLooks k 7 86 86 )" "B..D"
rigAssert "the title is the name of the folder: no filter is declared for it, a list of the sessions that are not closed being the filter" "[$( rigVal title )] [$( rigVal closedTitle )]" "[Active Sessions] [Closed Sessions]"
rigAssert "Closed Sessions holds the finished one: a lone run with no name, dimmed" "[$( rigVal crow1 )][$( rigVal crow2 )][$( rigVal crow3 )] $( rigLooks cl 4 86 86 ) $( rigVal c.rows )" "[>..][ magic-devops 33333333  finished ►][] D 2"

echo "-- no session at all --"
rigCase none none.rows
rigScript <<'RIGSCRIPT'
size 120 40
at @activity
wait sessions 30
get act
cells actRow2 3 85 119
cells actRow3 4 85 119
at @activity active-sessions
turn
get a
cells row1 2 85 119
cells row2 3 85 119
cells line1 2 1 83
RIGSCRIPT
rigAssert "Activity holds Launch (Start) first, also when there is no session"  "$( rigVal act.rows ) [$( rigVal actRow2 )][$( rigVal actRow3 )]" "8 [ Launch (Start)                  ►][>Active Sessions                 ►]"
rigAssert "the list shows the row that goes up and nothing more"     "$( rigVal a.rows ) [$( rigVal row1 )][$( rigVal row2 )]" "1 [>..][]"
rigAssert "and the left pane says that there is none"                "[$( rigVal line1 )]" "[No sessions.]"

echo "-- diving into a session shows its agents --"
rigCase dive five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN ENTER
get in
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
looks k
keys DOWN DOWN
turn
get agent
show s
keys BACKSPACE
get back
keys RIGHT
get again
RIGSCRIPT
rigAssert "Enter on a session shows its level, titled by the session, in the tree of Activity" "$( rigVal in.path ) [$( rigVal title )]" "magic-team/activity/active-sessions/$rigS1 [daily of Monday]"
rigAssert "its three agents stand under the row that goes up, each by its member" "$( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row5 )]" "4 [>..][]"
rigAssert "a live agent with its state and its activity: waiting or working" "[$( rigVal row2 )][$( rigVal row3 )]" "[ magic-coordina… running waiting ►][ magic-tester    running working ►]"
rigAssert "one that has ended with its state alone"                  "[$( rigVal row4 )]" "[ keeper-myx               finished]"
rigAssert "the live ones stand out"                                  "$( rigLooks k 4 86 86 )$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )" "BB."
rigAssert "the level has no read of its own: the list of the sessions fills it" "$( rigCalls ) $( rigVal in.reading )" "1 "
rigAssert "the left pane shows the selected agent: state, status, process, dates" "$( rigVal agent.selected ) [$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 5 )][$( rigPane s 6 )]" \
	"a2a2a2a2-0000-4000-8000-0000000000a2 [  state      running working][  status     spawn-started][  process    running][  started    2026-10-12 17:05 +0300 (9h ago)]"
rigAssert "its host, its workspace and its own id; its session is the folder it stands in, and not said again" "[$( rigPane s 7 )][$( rigPane s 8 )][$( rigPane s 9 )][$( rigPane s 10 )]" \
	"[  host       rig-host][  workspace  ws-rig][  run        a2a2a2a2-0000-4000-8000-0000000000a2][]"
rigAssert "Backspace returns onto the session it came from"               "$( rigVal back.path ) $( rigVal back.selected )" "magic-team/activity/active-sessions $rigS1"
rigAssert "Right dives nowhere: it pages down in the list"          "$( rigVal again.path )" "magic-team/activity/active-sessions"

echo "-- the left pane shows the selected session, from the same rows --"
rigCase pane five.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN
turn
get a
show s
at @activity closed-sessions
turn
keys DOWN
turn
show t
keys UP
turn
show u
RIGSCRIPT
rigAssert "one read gave all of it"                                  "$( rigCalls ) $( rigVal a.selected )" "1 $rigS1"
rigAssert "its name, its state, the line of its control thread, of which these rows say nothing, and when it started" "[$( rigPane s 2 )][$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 5 )][$( rigPane s 6 )]" "[ daily of Monday [wrap]][ daily of Monday][  state    running][  control  -][  started  2026-10-12 16:57 +0300 (9h ago)]"
rigAssert "its id last, under its agents"                            "[$( rigPane s 13 )][$( rigPane s 14 )]" "[][  session  $rigS1]"
rigAssert "each agent with its state, in a table under a heading, a column no agent has a word for left out" "[$( rigPane s 8 )][$( rigPane s 9 )][$( rigPane s 10 )][$( rigPane s 11 )][$( rigPane s 12 )]" \
	"[ Agents][  MEMBER             STATE            SINCE][  magic-coordinator  running waiting  2026-10-12 16:57 +0300][  magic-tester       running working  2026-10-12 17:05 +0300][  keeper-myx         finished         until 2026-10-12 18:00 +0300]"
rigAssert "a lone run says that it is one, and when it ended"        "[$( rigPane t 3 )][$( rigPane t 4 )][$( rigPane t 7 )]" \
	"[ one lone run with no name][  state    finished][  ended    2026-10-11 14:51 +0300 (35h ago)]"
rigAssert "on the row that goes up the pane is every session of the list as a table, nothing above it, how many in the frame" "[$( rigPane u 3 )] $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^u|' | LC_ALL=C grep -c -F ' 1 row ' )" "[  SESSION                STATE     AGE  AGENTS  TOKENS  MEMBERS] 1"

echo "-- the list read again --"
rigCase again five.rows five.rows moved.rows
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
keys DOWN
get before
keys ENTER
get inNamed
keys BACKSPACE
get named
advance 11
wait sessions 30
get after
cells row2 3 85 119
cells row3 4 85 119
keys DOWN DOWN DOWN
get end
at @activity closed-sessions
turn
get closed
RIGSCRIPT
rigAssert "the named session is selected, the first row, and holds its three agents"  "$( rigVal before.selected ) $( rigVal inNamed.rows )" "$rigS1 4"
rigAssert "back from it, the selection is on it"                      "$( rigVal named.selected ) $( rigVal named.index )" "$rigS1 1"
rigAssert "read again in another order, the selection stays on that session" "$( rigVal after.selected ) $( rigVal after.index ) $( rigVal after.rows ) [$( rigVal row2 )][$( rigVal row3 )]" \
	"$rigS1 2 5 [ 22222222-0000-4000-800… waiting ►][>daily of Monday         running ►]"
rigAssert "the last session is the last row"                         "$( rigVal end.selected ) $( rigVal end.index )" "$rigS5 4"
rigAssert "the session that is gone from the list is gone from Closed Sessions as well" "$( rigVal closed.rows )" "1"

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
at @activity closed-sessions
wait sessions 30
get few
RIGSCRIPT
rigPutsFew="$( rigVal few.puts )"
rigCase many many.rows
rigSecondsBefore="$SECONDS"
rigScript <<RIGSCRIPT
size 120 33
at @activity closed-sessions
wait sessions 30
get a
keys$( rigKeys DOWN 400 )
get moved
cells movedRow 30 85 119
keys$( rigKeys PGDN 20 )
get last
cells lastRow 30 85 119
keys ENTER
get in
keys LEFT$( rigKeys PGUP 20 )
get first
RIGSCRIPT
rigSecondsTaken=$(( SECONDS - rigSecondsBefore ))
rigAssert "the pane has thirty lines, and the level five hundred sessions under its first row" "$( rigVal a.listHeight ) $( rigVal a.rows )" "29 501"
rigAssert "four hundred times Down moves the selection four hundred rows, with its row in view" "$( rigVal moved.index ) $( rigVal moved.top ) [$( rigVal movedRow )]" "400 372 [>session 101            finished ►]"
rigAssert "PageDown reaches the last one"                            "$( rigVal last.index ) $( rigVal last.top ) [$( rigVal lastRow )]" "500 472 [>session 001            finished ►]"
rigAssert "it can be dived into like the first"                      "$( rigVal in.path ) $( rigVal in.rows )" "magic-team/activity/closed-sessions/00000001-0000-4000-8000-000000000000 3"
rigAssert "PageUp returns to the first row"                          "$( rigVal first.index ) $( rigVal first.top )" "0 0"
rigAssert "a drawing writes no more than with five sessions, but for the mark of a folder on each row in view beyond the few of that small list, and three writes at most for each line of the left pane, whose table of the sessions fills it: only the rows in view" "$( [ "$( rigVal first.puts )" -le "$(( rigPutsFew + $( rigVal first.listHeight ) + 3 * $( rigVal first.viewLines ) ))" ] && echo within || echo "over: $( rigVal first.puts )" ) $( rigVal last.spills )" "within 0"
rigAssert "all those keys were taken in a few seconds"               "$( [ "$rigSecondsTaken" -lt 15 ] && printf yes || printf 'no (%s seconds)' "$rigSecondsTaken" )" yes

echo "-- a session row of eight fields still draws, and the three more fields change nothing else that is drawn --"
## The same five sessions, each `session` row with three more fields after its eight, as the operation prints them
## now: one with a stored state and a live control thread, one whose thread is gone, one that ended in order, and
## two that never had one. The `run` rows and the row of counters are as they were.
LC_ALL=C awk -F'\t' '
	$1 != "session" { print ; next }
	{ sessionNo++ ; print $0 "\t" ( sessionNo == 1 ? "running\t2026-10-12_16:58_+0300\talive" : sessionNo == 2 ? "member-dead\t2026-10-12_09:40_+0300\tgone" : sessionNo == 3 ? "finished\t2026-10-11_14:51_+0300\tnone" : "-\t-\tnone" ) }
' "$rigTmp/five.rows" > "$rigTmp/wide.rows"
rigAssert "control: each of the five session rows of the fixture has eleven fields now, and every other row is as it was" "$( LC_ALL=C awk -F'\t' '$1 == "session" { rows++ ; if ( NF == 11 ) wide++ } END { print rows + 0 ":" wide + 0 }' "$rigTmp/wide.rows" ) $( LC_ALL=C grep -v '^session' "$rigTmp/wide.rows" | cmp -s - <( LC_ALL=C grep -v '^session' "$rigTmp/five.rows" ) && echo same )" "5:5 same"
rigWideDrawn(){ ## the fixture -- what the screen draws of it: the list, the left pane of a session, its level, the left pane of an agent, and of a closed session
	rigCase "wide-$1" "$1"
	rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
wait sessions 30
get a
show l
keys DOWN
turn
get session
show s
keys ENTER
get in
show i
keys DOWN DOWN
turn
get agent
show t
at @activity closed-sessions
turn
keys DOWN
turn
get closed
show u
RIGSCRIPT
	printf '%s\n' "$rigOut"
}
rigDrawnEight="$( rigWideDrawn five.rows )"
rigDrawnEleven="$( rigWideDrawn wide.rows )"
rigAssert "control: the screen was driven through the list, a session, its level and an agent, and drew each" "$( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -e '^l|' -e '^s|' -e '^i|' -e '^t|' -e '^u|' | LC_ALL=C awk '{ print ( $1 >= 200 ) ? "drawn" : "not drawn: " $1 }' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C sed -n 's/^a\.rows=//p' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C sed -n 's/^in\.path=//p' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c 'DRIVER-FAILED' )" "drawn 5 magic-team/activity/active-sessions/$rigS1 0"
rigLeftOf(){ ## a drawing -- its lines as they are, but of each line of a screen the left pane alone, without the spaces at its end, and of that nothing where it speaks of a control thread, nor anything of the left pane of the list (l), whose table of the sessions marks a thread that is gone; how many lines the pane holds is left out, and how many writes a drawing took, since the line of a control thread is drawn in the colour of its state, and how many times the screen was drawn, which is as many as the turns it waited for a call, by the clock of the host
	printf '%s\n' "$1" | LC_ALL=C grep -v -e '\.viewLines=' -e '\.frames=' -e '\.puts=' | LC_ALL=C awk '{ rest = substr( $0, 6 ) ; cutAt = index( rest, "│" ) ; if ( substr( $0, 2, 1 ) != "|" || substr( $0, 3, 3 ) != "│" || ! cutAt ) { print ; next } leftText = substr( $0, 1, 5 ) substr( rest, 1, cutAt - 1 ) ; sub( / +$/, "", leftText ) ; if ( leftText ~ /control/ || substr( $0, 1, 1 ) == "l" ) leftText = substr( $0, 1, 5 ) ; print leftText }'
}
rigListOf(){ ## a drawing -- of each line of a screen the list alone, after the tag of its screen, without the spaces at its end
	printf '%s\n' "$1" | LC_ALL=C grep '^[a-z]|.*│║' | LC_ALL=C sed -e 's/^\(..\).*│║/\1/' -e 's/ *║|$//'
}
rigAssert "from the eight fields the pane of a session says - of its control thread, and no row of the list carries a mark" "$( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -e '^s|│ control  -  ' -e '^u|│ control  -  ' ) $( rigListOf "$rigDrawnEight" | LC_ALL=C grep -c -e ' x [a-z-]*$' )" "2 0"
rigAssert "with the three more fields it says what they tell: a thread that lives, one that ended in order, and what each stored" "$( printf '%s\n' "$rigDrawnEleven" | LC_ALL=C grep -c -F -e 's|│ control  alive; stored running, set 2026-10-12 16:58 +0300 (9h ago)  ' ) $( printf '%s\n' "$rigDrawnEleven" | LC_ALL=C grep -c -F -e 'u|│ control  none; stored finished, set 2026-10-11 14:51 +0300 (35h ago)  ' )" "1 1"
rigAssert "the list marks the one session whose thread is gone, on each of the two screens that show the list of the sessions, and no other row differs; the table of the sessions in the left pane marks it too" "$( diff <( rigListOf "$rigDrawnEight" ) <( rigListOf "$rigDrawnEleven" ) | LC_ALL=C grep -c '^> ' ) $( diff <( rigListOf "$rigDrawnEight" ) <( rigListOf "$rigDrawnEleven" ) | LC_ALL=C grep -c -F -e '| 22222222-0000-4000-…... x waiting' ) $( printf '%s\n' "$rigDrawnEleven" | LC_ALL=C grep -c -E -e '^l\|│ 22222222-0000-4000-[0-9-]* +x waiting ' )" "2 0 1"
rigAssert "everything else is read by position as before: but for what it says of the control thread, the screen draws and reports cell for cell what it draws from the eight" "$( [ "$( rigLeftOf "$rigDrawnEleven" )" = "$( rigLeftOf "$rigDrawnEight" )" ] && echo same || { echo differs ; diff <( rigLeftOf "$rigDrawnEight" ) <( rigLeftOf "$rigDrawnEleven" ) | head -6 ; } )" "same"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SESSIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SESSIONS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
