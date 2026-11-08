#!/usr/bin/env bash
## Behavioural check on `p` and `r` of `Sessions (Activity)` (S7.19; askPause, askResume in sh-lib/manager/AgentsManagerScreen.Sessions.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py),
## and where it would call the dispatcher it calls the stand-in script (check-fixtures/manager-screen.tools.stub.sh). Held:
##   1. `p` on a session asks `--manager-session-pause --session-id <id>` once, at once, with nothing on its standard input and nothing
##      else called; the notice says so; the answer's row is said in words in the status line and at the head of the left pane; then
##      the list is read again.
##   2. `r` on the same session asks `--manager-session-resume --session-id <id>` the same way, and its answer names what the pause held.
##   3. `p` on the row that goes up, which is no session, asks nothing: the command's own rule refuses it in the status line, with no box.
## Red before S7.19: both keys were declared with no handler, so each said `is not built yet` and called nothing: rows 1 and 2 fail.
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
rigTmp="$( rigTempDir AgentsManagerScreenPauseResumeCheck )" || exit 1
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
## One running session with two agents, and the row of counters, as the list prints them.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 2 running=2 running 2026-10-12_16:58_+0000 alive
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow counters 1 0 1 0 2 0.42
} > "$rigF/rows"
## What the pause and the resume print, by the session they are asked for.
rigRow pause "$rigS1" "/rig/ws/.local/agents/sessions/$rigS1/paused" > "$rigF/rows.--manager-session-pause --session-id $rigS1"
rigRow resume "$rigS1" "/rig/ws/.local/agents/sessions/$rigS1/paused" "2026-10-13_02:20_+0000_magic-coordinator" > "$rigF/rows.--manager-session-resume --session-id $rigS1"
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
rigCalls(){ ## the operation -- how many starts began with it
	LC_ALL=C grep -c -- "^$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigWords(){ ## the operation -- the arguments of every such call, each between brackets, a call a line
	LC_ALL=C grep -F -- "[$1]" "$MANAGER_SCREEN_RIG/words" || :
}
rigElse(){ ## how many starts were neither the list of the sessions, nor a pause, nor a resume, nor the list of the locations
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-session-pause' -e '^--manager-session-resume' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- 1. p pauses the selected session, and asks nothing first --"
rigCase pause
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN
keys p
get asked
wait action 30
get answered
show a
wait sessions 30
RIGSCRIPT
rigAssert "p opens no line to type in: the pause is asked of the tooling at once" "[$( rigVal asked.dialog )] $( rigVal asked.reading ) [$( rigVal asked.notice )]" "[] action:pause:$rigS1 [pause asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session and nothing more" "$( rigCalls --manager-session-pause ) [$( rigWords --manager-session-pause )]" "1 [[--manager-session-pause][--session-id][$rigS1]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( [ -e "$MANAGER_SCREEN_RIG/stdin.--manager-session-pause" ] && printf input || printf none ) $( rigElse )" "none 0"
rigAssert "the notice says the row in words" "[$( rigVal answered.notice )]" "[pause: paused: the session 11111111]"
rigAssert "the same stands at the head of the left pane" "[$( rigPane a 3 )][$( rigPane a 4 )]" "[ the pause, answered 02:30:00:][   paused: the session 11111111]"
rigAssert "then the list is read again" "$( rigCalls --manager-session-list )" 2

echo "-- 2. r resumes it the same way, and says what the pause held --"
rigCase resume
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN
keys r
get asked
wait action 30
get answered
wait sessions 30
RIGSCRIPT
rigAssert "r asks the resume at once" "$( rigVal asked.reading ) [$( rigVal asked.notice )]" "action:resume:$rigS1 [resume asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session" "$( rigCalls --manager-session-resume ) [$( rigWords --manager-session-resume )] $( rigElse )" "1 [[--manager-session-resume][--session-id][$rigS1]] 0"
rigAssert "the notice says the row in words, with what the pause held" "[$( rigVal answered.notice )]" "[resume: resumed: the session 11111111, held since 2026-10-13 02:20 +0000 magic-coordinator]"

echo "-- 3. p on the row that goes up asks nothing and says so --"
rigCase nothing
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys p
get asked
RIGSCRIPT
rigAssert "the status line refuses the key for what is selected, no box opens, and nothing is called" "[$( rigVal asked.notice )] [$( rigVal asked.dialog )] $( rigCalls --manager-session-pause )" "[Pause: for a session or an agent, not for what is selected] [] 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PAUSE RESUME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SCREEN_PAUSE_RESUME: OK ($rigPassCount assertions, offline)"
