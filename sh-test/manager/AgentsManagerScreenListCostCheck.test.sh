#!/usr/bin/env bash
## Behavioural check on what the manager screen asks of the tooling while nobody touches it: a quiet
## screen must not re-run `--manager-session-list`. The screen's own code
## (sh-lib/manager/LocalManagerScreen.py) runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py) and the stand-in for the dispatcher
## (check-fixtures/manager-screen.tools.stub.sh), which records every start in the rig's `calls` file.
## The trigger half of the task, one changed session running the list once, needs the change-stamp
## operation, whose name is unruled: it is held until that ruling lands.
## Offline: no operation of the real tooling is called, and no session of this machine is read.
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
rigTmp="$( rigTempDir AgentsManagerScreenListCostCheck )" || exit 1
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

## One rig for both cases: the fixtures, one session that runs with one agent, and nothing read yet.
rigF="$rigTmp/fixtures"
mkdir -p "$rigF"
{
	rigRow session 11111111-0000-4000-8000-000000000001 daily_of_Monday running 2026-10-12_16:57_+0300 - 1 running=1
	rigRow run 11111111-0000-4000-8000-000000000001 a1a1a1a1-0000-4000-8000-0000000000a1 magic-coordinator spawn-started running waiting 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow counters 1 1 1 0 0 0 0.42
} > "$rigF/rows.--manager-session-list"
echo rows > "$rigF/mode"

rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
}
rigScript(){ ## the driver's commands on standard input, after the ones that name the stand-in and the time
	rigOut="$( { printf 'tools bash %s\nworkspace %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" "$MMDAPP" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
## Sixty seconds of a screen nobody touches, ten seconds a step, which is the screen's own period. A
## period that fires shows here as one more pass.
quietTurns(){
	local step
	for step in 1 2 3 4 5 6 ; do
		printf 'advance 10\nturn\nturn\nturn\n'
	done
}

echo "-- 1. the baseline: an opened screen reads the list once --"
rigCase baseline
rigScript <<RIGSCRIPT
at @activity
turn
wait sessions 5
RIGSCRIPT
rigBaseline="$( rigCalled '--manager-session-list' )"
rigAssert "one pass for the first read" "$rigBaseline" "1"

echo "-- 2. the same screen left quiet for 60 s runs no further pass --"
rigCase quiet
rigScript <<RIGSCRIPT
at @activity
turn
wait sessions 5
$( quietTurns )
RIGSCRIPT
rigAssert "no further pass over 60 s of a quiet screen" "$( rigCalled '--manager-session-list' )" "$rigBaseline"

echo
if [ "$rigFailCount" -gt 0 ] ; then
	echo "⛔ MANAGER SCREEN LIST COST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)"
	exit 1
fi
echo "✅ MANAGER SCREEN LIST COST CHECK: all $rigPassCount assertions hold"
exit 0
