#!/usr/bin/env bash
## Behavioural check on the row of a session that has just ended in `Active Sessions` (S7.29; lingering in
## sh-lib/manager/AgentsManagerScreen.Sessions.py), run rather than read, through the driver and the stand-in dispatcher. Held:
##   1. A session finished within the last half minute still stands in Active Sessions, and its row says `ended just now` where its
##      state stood, so a reader sees why a closed session is there.
##   2. One finished earlier stands in Closed Sessions alone, with its state as it is.
##   3. A running session's row is as it was: its state at its tail.
## Red before S7.29: the ended row kept its state word `finished` as its tail, so row 1 fails.
## Offline: no operation of the real tooling is called. The clock is the driver's `wall`.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.py"
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
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenLingerCheck )" || exit 1
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
## Three sessions: one running, one finished at the wall clock's minute, one finished ten minutes before it.
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003
export MANAGER_SCREEN_RIG="$rigTmp/rig"
mkdir -p "$MANAGER_SCREEN_RIG"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 alive
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow session "$rigS2" just_ended finished 2026-10-13_02:00_+0000 2026-10-13_02:30_+0000 1 finished=1 finished 2026-10-13_02:30_+0000 none
	rigRow run "$rigS2" "$rigS2" magic-tester spawn-succeeded no-process finished 2026-10-13_02:00_+0000 2026-10-13_02:30_+0000 rig-host ws-rig -
	rigRow session "$rigS3" long_ended finished 2026-10-13_01:00_+0000 2026-10-13_02:20_+0000 1 finished=1 finished 2026-10-13_02:20_+0000 none
	rigRow run "$rigS3" "$rigS3" magic-devops spawn-succeeded no-process finished 2026-10-13_01:00_+0000 2026-10-13_02:20_+0000 rig-host ws-rig -
	rigRow counters 1 0 1 0 1 0.42
} > "$MANAGER_SCREEN_RIG/rows"
: > "$MANAGER_SCREEN_RIG/calls"
echo rows > "$MANAGER_SCREEN_RIG/mode"
rigScript(){ ## the commands of the driver on standard input; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\ntable view:magic-team/activity/active-sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
turn 3
get a
cells row3 3 85 119
cells row4 4 85 119
cells row5 5 85 119
at @activity closed-sessions
turn
get c
cells row6 3 85 119
cells row7 4 85 119
RIGSCRIPT
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigListRow(){ ## what a row shows as, its tail -- that row of the list as it is drawn in its 34 cells with the mark of a folder at its right edge, not selected
	printf ' %-*s %s ►' "$(( 30 - ${#2} ))" "$1" "$2"
}
rigAssert "Active Sessions holds the running one and the one that has just ended, two rows under the row that goes up" "$( rigVal a.rows )" "3"
rigAssert "the running session's row is as it was"                        "[$( rigVal row3 )]" "[$( rigListRow "daily of Monday" "running" )]"
rigAssert "the session that has just ended says so where its state stood" "[$( rigVal row4 )]" "[$( rigListRow "just ended" "ended just now" )]"
rigAssert "the one that ended ten minutes ago is not among them"          "[$( rigVal row5 )]" "[]"
rigAssert "Closed Sessions holds both ended ones, each with its state"   "$( rigVal c.rows ) [$( rigVal row6 )][$( rigVal row7 )]" "3 [$( rigListRow "just ended" "finished" )][$( rigListRow "long ended" "finished" )]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LINGER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SCREEN_LINGER: OK ($rigPassCount assertions, offline)"
