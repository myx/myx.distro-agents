#!/usr/bin/env bash
## Behavioural check on `s` of `Sessions (Activity)` (S7.19, the soft stop; askStop in sh-lib/manager/AgentsManagerScreen.Sessions.py),
## run rather than read, through the driver (check-fixtures/manager-screen.driver.py) and the stand-in dispatcher
## (check-fixtures/manager-screen.tools.stub.sh). Held:
##   1. `s` on a session asks `--manager-session-stop --session-id <id>` once, at once, with nothing on its standard input; the notice
##      says so; the answer's rows are said in words, one a run, in the status line and at the head of the left pane; the list is read again.
##   2. `s` on an agent of a session asks the stop of that run alone, with `--run`.
## Red before S7.19: the key was declared with no handler, so it said `is not built yet` and called nothing.
## Offline: no operation of the real tooling is called.
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
rigTmp="$( rigTempDir AgentsManagerScreenStopCheck )" || exit 1
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
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 2 running=2 running 2026-10-12_16:58_+0000 alive
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow counters 1 0 1 0 2 0.42
} > "$rigF/rows"
{ rigRow stop "$rigS1" "$rigS1" magic-coordinator dismissed ; rigRow stop "$rigS1" "$rigR2" magic-tester dismissed ; } > "$rigF/rows.--manager-session-stop --session-id $rigS1"
rigRow stop "$rigS1" "$rigR2" magic-tester dismissed > "$rigF/rows.--manager-session-stop --session-id $rigR2 --run"
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\ntable view:magic-team/activity/active-sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot active-sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}
rigWords(){ ## the arguments of every stop call, each between brackets, a call a line
	LC_ALL=C grep -F -- '[--manager-session-stop]' "$MANAGER_SCREEN_RIG/words" || :
}
rigElse(){ ## how many starts were neither the list, nor a stop, nor the list of the locations
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-session-stop' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- 1. s stops the selected session, and asks nothing first --"
rigCase session
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN
keys s
get asked
wait action 30
get answered
show a
wait sessions 30
RIGSCRIPT
rigAssert "s opens no line to type in: the stop is asked of the tooling at once" "[$( rigVal asked.dialog )] $( rigVal asked.reading ) [$( rigVal asked.notice )]" "[] action:stop:$rigS1 [stop asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session and nothing more" "[$( rigWords )] $( rigElse )" "[[--manager-session-stop][--session-id][$rigS1]] 0"
rigAssert "the notice says each run in words" "[$( rigVal answered.notice )]" "[stop: dismissed: magic-coordinator 11111111; dismissed: magic-tester a2a2a2a2]"
rigAssert "the same stands at the head of the left pane" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )]" "[ the stop, answered 02:30:00:][   dismissed: magic-coordinator 11111111][   dismissed: magic-tester a2a2a2a2]"
rigAssert "then the list is read again" "$( LC_ALL=C grep -c -- '^--manager-session-list' "$MANAGER_SCREEN_RIG/calls" )" 2

echo "-- 2. s on an agent stops that run alone --"
rigCase agent
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait sessions 30
keys DOWN DOWN
keys s
get asked
wait action 30
get answered
RIGSCRIPT
rigAssert "the stop of that run is asked with --run" "$( rigVal asked.reading ) [$( rigWords )]" "action:stop:$rigR2 [[--manager-session-stop][--session-id][$rigR2][--run]]"
rigAssert "and its answer names that run" "[$( rigVal answered.notice )]" "[stop: dismissed: magic-tester a2a2a2a2]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN STOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SCREEN_STOP: OK ($rigPassCount assertions, offline)"
