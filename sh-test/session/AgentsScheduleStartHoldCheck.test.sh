#!/usr/bin/env bash
## Behavioural check on the two bounds of a schedule start that S12.12's first live pass showed were missing (owner's answer, 2026-11-04):
##   1. A START THAT FAILED IS HELD, not retried at the next pass. `AgentsToolsScheduleSpawn` leaves `<key>.hold` when a start ends with a failure,
##      and the guard reads it: a pass inside the ten minutes starts nothing, and one after them tries again. A start that succeeded leaves no hold,
##      so a duty that ended is restarted on its own rule (AgentsToolsScheduleDutyRestartDue).
##   2. A KEPT SESSION ID WITH NO REGISTRY ROW STARTS A FRESH SESSION, in the same attempt. Where the spawner refuses the join, the duty's start is
##      made again with no `--join-session`, and the new id is kept for the next start.
## The real Dispatcher include runs, over a rig of its own. The spawner is a stand-in on PATH that records every call and answers from a scenario
## file, so each fault is made to happen and then read back. No clock is faked: the hold's ten minutes are read through `-mmin`, as the guard does.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the Dispatcher include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleStartHoldCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## THE RIG: a workspace of its own with a settings folder the include finds, a stand-in spawner on PATH, and three scenario files.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/schedule" "$rigWs/.local/agents/spawned" "$rigTmp/store/board" "$rigTmp/bin" || exit 1
## THE STAND-IN SPAWNER is a shell function, exported, so the start's own subshell calls it and no real tool file is sourced over it: one line of the
## calls file for every call, the scenario's answer, and the scenario's status.
DistroAgentsTools(){
	printf '%s\n' "$*" >> "$RIG_CALLS"
	cat "$RIG_ANSWER" 2> /dev/null
	return "$( cat "$RIG_RC" 2> /dev/null || echo 0 )"
}
export -f DistroAgentsTools
: > "$rigTmp/answer" ; printf '0\n' > "$rigTmp/rc" ; : > "$rigTmp/calls"
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/store" MDLT_ORIGIN="$MDLT_ORIGIN"
export RIG_CALLS="$rigTmp/calls" RIG_ANSWER="$rigTmp/answer" RIG_RC="$rigTmp/rc"
export PATH="$rigTmp/bin:$PATH"
cd "$rigWs" || exit 1
## The include is sourced with one harmless positional word: the tooling's own context reader reads $1, and must not be handed the check's arguments.
set -- check
. "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" || rigRefuse "the Dispatcher include would not load"
## A start is made apart, and its markers say when it ended: the call waits for them here, as the next pass would meet them.
rigStart(){ ## the key, then the arguments
	AgentsToolsScheduleSpawn "$@" > /dev/null 2>&1 || return 1
	local waited=300
	while [ -n "$( ls "$rigWs/.local/agents/schedule/starting" 2> /dev/null | LC_ALL=C grep -v -e '\.rc$' -e '\.out$' )" ] && [ "$waited" -gt 0 ] ; do
		sleep 0.1 ; waited=$(( waited - 1 ))
	done
	return 0
}
rigCalls(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/calls" 2> /dev/null || : ; }

echo "-- 1. a start that failed is held --"
printf '%s\n' 'SESSION_ID=run-one' > "$rigTmp/answer" ; printf '0\n' > "$rigTmp/rc"
rigStart probe-key --routine magic-team.work-duty.routine.md probe-member
rigAssert "a start that succeeded is made once, and leaves no hold" "$( rigCalls 'probe-member' ):$( [ -e "$rigWs/.local/agents/schedule/starting/probe-key.hold" ] && printf held )" "1:"
printf '%s\n' '⛔ ERROR: the join was refused' > "$rigTmp/answer" ; printf '1\n' > "$rigTmp/rc"
rigStart hold-key --routine magic-team.work-duty.routine.md hold-member
rigAssert "a start that failed leaves a hold for its key" "$( [ -e "$rigWs/.local/agents/schedule/starting/hold-key.hold" ] && printf held )" "held"
: > "$rigTmp/calls"
rigStart hold-key --routine magic-team.work-duty.routine.md hold-member
rigAssert "and a pass minutes later starts that key no more" "$( rigCalls 'hold-member' )" "0"

echo "-- 2. a refused join starts a fresh session, in the same attempt --"
: > "$rigTmp/calls"
mkdir -p "$rigWs/.local/agents/schedule/duty-session"
printf 'stale-one\n' > "$rigWs/.local/agents/schedule/duty-session/join-member"
printf '%s\n' 'REFUSED: refusing to join session stale-one: no spawned-sessions registry row carries this session' > "$rigTmp/answer"
printf '1\n' > "$rigTmp/rc"
rigStart work-duty.join-member --routine magic-team.work-duty.routine.md join-member
rigAssert "the refused join is followed by a start that joins nothing: two calls, the second with no --join-session" \
	"$( rigCalls 'join-member' ):$( LC_ALL=C grep -v -F -- '--join-session' "$rigTmp/calls" 2> /dev/null | LC_ALL=C grep -c -F -- 'join-member' || : )" "2:1"
rigAssert "the stale id is gone, so the next pass starts a session of its own" "$( [ -e "$rigWs/.local/agents/schedule/duty-session/join-member" ] && printf kept )" ""

echo "-- 3. a start that joined is one call, and its id is kept --"
: > "$rigTmp/calls"
rm -f "$rigWs/.local/agents/schedule/starting/"*.hold
printf '%s\n' 'SESSION_ID=fresh-one' > "$rigTmp/answer" ; printf '0\n' > "$rigTmp/rc"
printf 'live-one\n' > "$rigWs/.local/agents/schedule/duty-session/join-member"
rigStart work-duty.join-member --routine magic-team.work-duty.routine.md join-member
rigAssert "a join the spawner accepts is one call, and the id it answers is kept" \
	"$( rigCalls 'join-member' ):$( cat "$rigWs/.local/agents/schedule/duty-session/join-member" 2> /dev/null )" "1:fresh-one"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE START HOLD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_START_HOLD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
