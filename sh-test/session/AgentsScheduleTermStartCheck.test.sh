#!/usr/bin/env bash
## Behavioural check on the schedule's stop signal reaching the start (S12.15's applied item, board task 20261106T0840Z;
## `AgentsToolsScheduleSpawn` in AgentsTools.DispatcherSchedule.include). A schedule thread told to end sets `serveEnd` in its TERM trap
## (AgentsTools.OnDemandThread.include:200) and finishes the pass it is in. That pass still listed every duty as due, and started them:
## six starts were made after the signal on 2026-11-06. Held, run rather than read:
##   1. WITH NO END SIGNAL a start is made, so the rig is shown to reach the spawner at all.
##   2. WITH serveEnd SET no start is made, and the start answers 1.
##   3. AND NOTHING IS LEFT BEHIND for a later pass to read: no starting marker and no hold.
##   4. THE PASS IN HAND IS NOT ABANDONED: what ended is still reported while the signal stands.
##   5. ANY END WORD STOPS STARTS, not TERM alone, because the guard reads the variable and not its value.
## The spawner is a stand-in on `DistroAgentsTools` that records every call, so nothing is started and no session is made.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: delete the guard that returns 1 while `serveEnd` is
## set (:654 at 2026-11-09 02:47) and rows 2, 3 and 5 fail.
## Offline: the include this check loads, a rig of its own, and no spawner, git or network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Dispatcher include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleTermStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/schedule/starting"
mkdir -p "$rigStore" || exit 1
: > "$rigTmp/calls"
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
## THE STAND-IN SPAWNER IS A FUNCTION, so the start's own subshell inherits it and no tool file is sourced over it: one line per call.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
DistroAgentsTools(){
	printf 'start %s\n' "$*" >> "$RIG_CALLS"
	printf 'SESSION_ID=rig-session\n'
	return 0
}
AgentsToolsScheduleSpawnReport(){ printf 'report\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleLearning(){ printf 'learn\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleAutorun(){ : ; }
AgentsToolsScheduleWorkDuty(){ : ; }
AgentsToolsScheduleSupervision(){ : ; }
AgentsToolsScheduleImportantEmergency(){ : ; }
PRELUDE
## A start is made apart by the function itself, so the check waits for the status file it writes, as the next pass would meet it.
rigStart(){ ## the end word to stand (empty for none), then the key and the arguments
	local startEnd="$1" startKey="$2" startLeft=300
	shift 2
	RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" MMDAPP="$rigWs" bash -c '
		. "$1" ; shift
		[ -z "$1" ] || eval "serveEnd=$1"
		shift
		AgentsToolsScheduleSpawn "$@"
	' rig-start "$rigTmp/prelude.sh" "${startEnd:+"$startEnd"}" "$startKey" "$@" > "$rigTmp/start.out" 2>&1
	rigStartRc=$?
	while [ ! -e "$rigStore/$startKey.rc" ] && [ "$startLeft" -gt 0 ] ; do sleep 0.1 ; startLeft=$(( startLeft - 1 )) ; done
	if [ -e "$rigStore/$startKey.rc" ] ; then rigStartedRc="$( cat "$rigStore/$startKey.rc" )" ; else rigStartedRc="no-status" ; fi
}
rigLog(){ LC_ALL=C grep -c -- "$1" "$rigTmp/calls" 2> /dev/null || : ; }

echo "-- 1. with no end signal a start is made --"
: > "$rigTmp/calls"
rigStart "" autorun.rig-one --routine magic-team.grooming.routine.md
rigAssert "the start answers 0" "$rigStartRc" 0
rigAssert "and the spawner was called once" "$( rigLog '^start ' )" 1
rigAssert "and its own answer is 0" "$rigStartedRc" 0

echo "-- 2. with serveEnd set no start is made --"
rm -f "$rigStore/"*.rc "$rigStore/"*.out
: > "$rigTmp/calls"
rigStart TERM autorun.rig-two --routine magic-team.grooming.routine.md
rigAssert "the start answers 1, as a start not made" "$rigStartRc" 1
rigAssert "the spawner was never called" "$( rigLog '^start ' )" 0

echo "-- 3. and nothing is left behind for a later pass --"
rigAssert "no status file was written for a start that never ran" "$( [ -e "$rigStore/autorun.rig-two.rc" ] && printf written || printf absent )" absent
rigAssert "no starting marker stands for it" "$( [ -e "$rigStore/autorun.rig-two" ] && printf stands || printf absent )" absent
rigAssert "and no hold stands to quiet a later pass" "$( [ -e "$rigStore/autorun.rig-two.hold" ] && printf stands || printf absent )" absent

echo "-- 4. the pass in hand is not abandoned --"
: > "$rigTmp/calls"
RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" MMDAPP="$rigWs" bash -c \
	'. "$1" ; serveEnd=TERM ; AgentsToolsScheduleLoop' rig-loop "$rigTmp/prelude.sh" > /dev/null 2>&1
rigAssert "what ended was still reported in that pass" "$( rigLog '^report$' )" 1
rigAssert "and no start was made in it" "$( rigLog '^start ' )" 0

echo "-- 5. any end word stops starts --"
: > "$rigTmp/calls"
rigStart INT autorun.rig-three --routine magic-team.grooming.routine.md
rigAssert "a start under another end word answers 1 too" "$rigStartRc" 1
rigAssert "and the spawner is still never called" "$( rigLog '^start ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE TERM START CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_TERM_START: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
