#!/usr/bin/env bash
## Behavioural check on the schedule's start of a duty into the session it kept (AgentsToolsScheduleSpawn in
## AgentsTools.DispatcherSchedule.include), run rather than read, over a rig workspace. A start that joins a kept session
## resumes that session's context, and a context that does not load fails every such start at the harness for good.
## Held:
##   1. control: a kept session with no context file is joined, as it always was
##   2. a kept session whose context file does not load is dropped, and the start opens a session of its own
##   3. the drop takes the kept pointer with it, so the next start does not read it again
## The start itself is replaced by a function of this check's own that records its arguments, so nothing is spawned.
## Red before the change: case 2 joins the unloadable session.
## Offline: a rig workspace under this check's temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleKeptContextCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
rigDuty="$rigWs/.local/agents/schedule/duty-session"
rigSpawned="$rigWs/.local/agents/spawned"
rigCalls="$rigTmp/calls"
mkdir -p "$rigWs/.local/agents/schedule/starting" "$rigDuty" "$rigSpawned" "$rigWs/.local/temp" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
export MMDAPP="$rigWs"
set +u
. "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || :
set -u
type AgentsToolsScheduleSpawn > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleSpawn is not defined by sourcing the schedule's functions"
## THE REPLACED PARTS: the start records what it was asked, and the pass states every start may be made.
AgentsToolsScheduleStartingAllowed(){ return 0 ; }
AgentsToolsScheduleDayFirst(){ return 0 ; }
DistroAgentsTools(){ printf '%s\n' "$*" >> "$rigCalls" ; printf 'SESSION_ID=rig-new\n' ; return 0 ; }
## One start of a key, and what the start was asked, once the background start has written it.
rigStart(){ ## member -- the arguments the start passed, or none
	: > "$rigCalls"
	AgentsToolsScheduleSpawn "work-duty.$1" --routine rig.routine.md "$1" || :
	local rigWait=0
	while [ ! -s "$rigCalls" ] && [ "$rigWait" -lt 100 ] ; do sleep 0.1 ; rigWait=$(( rigWait + 1 )) ; done
	cat "$rigCalls"
}
rigJoined(){ ## the arguments of a start -- joined or own
	case "$1" in *"--join-session"*) printf joined ;; *"--spawn-session"*) printf own ;; *) printf none ;; esac
}

echo "-- 1. control: a kept session with no context file is joined --"
printf 'rig-kept-a\n' > "$rigDuty/rig-a"
mkdir -p "$rigSpawned/rig-kept-a"
rigAssert "the start joins the kept session" "$( rigJoined "$( rigStart rig-a )" )" joined

echo "-- 2. a kept session whose context does not load is dropped --"
printf 'rig-kept-b\n' > "$rigDuty/rig-b"
mkdir -p "$rigSpawned/rig-kept-b"
printf 'this is no context\n' > "$rigSpawned/rig-kept-b/context.jsonl"
rigAssert "the start opens a session of its own" "$( rigJoined "$( rigStart rig-b )" )" own

echo "-- 3. the drop takes the kept pointer with it --"
rigAssert "the pointer now names the session the start made, not the dropped one" "$( cat "$rigDuty/rig-b" 2> /dev/null )" "rig-new"

export MMDAPP="$rigReal"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE KEPT CONTEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  AgentsToolsScheduleSpawn in sh-lib/schedule/ -- never the assertion" >&2
	exit 1
fi
echo "SCHEDULE_KEPT_CONTEXT: OK ($rigPassCount assertions, offline)"
