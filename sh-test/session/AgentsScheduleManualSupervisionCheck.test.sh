#!/usr/bin/env bash
## Behavioural check on the schedule's supervision rule (S13.1; AgentsToolsScheduleSupervision in
## AgentsTools.DispatcherSchedule.include). While the `supervised` flag is off, the rule told ANY live supervision run
## to go, including a run started by hand; the dismissal's hard kill then recorded the console owner as the killer
## although no person acted. The flag's own run is the one whose session id stands in
## `.local/agents/schedule/supervision-session/magic-coordinator`, the file the start writes. Held, run rather than read:
##   1. A RUN STARTED BY HAND IS LEFT ALONE, and the rule says why.
##   2. THE FLAG'S OWN RUN IS TOLD TO GO, as before.
##   3. THE HARD KILL AFTER THAT DISMISSAL IS RECORDED UNDER `schedule`, never an empty name the console fills with the owner.
## A rig of its own, a stand-in spawner and stand-in store reads: no session, no git, no network.
## RED RECIPE, measured on the live package 2026-11-25: with a guard that reads a record field instead of the kept session,
## section 2 records no dismissal for the flag's run, because the record carries no such field.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Dispatcher include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleManualSupervisionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigDismissed="$rigWs/.local/agents/schedule/dismissed"
rigKept="$rigWs/.local/agents/schedule/supervision-session"
mkdir -p "$rigSpawned/rig-manual" "$rigSpawned/rig-flag" "$rigDismissed" "$rigKept" || exit 1
rigManual="$rigSpawned/rig-manual/rig-manual.spawn.md"
rigFlag="$rigSpawned/rig-flag/rig-flag.spawn.md"
printf -- '---\nsession-id: rig-manual\nspawn-id: rig-manual\nowner: magic-coordinator\nstatus: spawn-started\nroutine: magic-coordinator.supervision-session.routine.md\n---\n' > "$rigManual" || exit 1
printf -- '---\nsession-id: rig-flag\nspawn-id: rig-flag\nowner: magic-coordinator\nstatus: spawn-started\nroutine: magic-coordinator.supervision-session.routine.md\n---\n' > "$rigFlag" || exit 1
printf 'some-other-session\n' > "$rigKept/magic-coordinator" || exit 1
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
## THE STUBS ARE FUNCTIONS OF THE RIG, defined after the include loads, so its guarded loads keep them: the flag read,
## the record list and the liveness read are the rig's own, and nothing of the workspace is touched.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
AgentsToolsScheduleStartsAllowed(){ return 0 ; }
AgentsToolsSchedulePassFlagsInto(){ printf -v "$1" '%s' 'worktime: yes
supervised: no' ; }
AgentsToolsSpawnedRecordsOfRoutine(){ printf '%s\n' "$RIG_SUP_RECORD" ; }
AgentsToolsLivenessOf(){ printf 'alive\n' ; }
AgentsToolsScheduleDismiss(){ printf 'dismiss %s\n' "$*" >> "$RIG_CALLS" ; }
PRELUDE
cat > "$rigTmp/prelude-kill.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
AgentsToolsManagerSessionKill(){ printf 'kill %s\n' "$*" >> "$RIG_CALLS" ; }
PRELUDE
rigSupervise(){ ## the record the rig shows the rule
	RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" RIG_SUP_RECORD="$1" MMDAPP="$rigWs" \
		bash -c '. "$1" ; AgentsToolsScheduleSupervision' rig-sup "$rigTmp/prelude.sh" > "$rigTmp/sup.out" 2>&1
}
rigLog(){ LC_ALL=C grep -c -- "$1" "$rigTmp/calls" 2> /dev/null || : ; }

echo "-- 1. a run started by hand is left alone --"
: > "$rigTmp/calls"
printf 'some-other-session\n' > "$rigKept/magic-coordinator" || exit 1
rigSupervise "$rigManual"
rigAssert "no dismissal of the hand-started run" "$( rigLog '^dismiss ' )" 0
rigAssert "and the rule says why" "$( LC_ALL=C grep -c 'left alone' "$rigTmp/sup.out" 2> /dev/null || : )" 1

echo "-- 2. the flag's own run is told to go --"
: > "$rigTmp/calls"
printf 'rig-flag\n' > "$rigKept/magic-coordinator" || exit 1
rigSupervise "$rigFlag"
rigAssert "one dismissal of the flag's run" "$( rigLog '^dismiss ' )" 1

echo "-- 3. the hard kill is recorded under the schedule --"
: > "$rigTmp/calls"
printf 'rig-flag\n' > "$rigKept/magic-coordinator" || exit 1
touch -t "$( date -v-20M +%Y%m%d%H%M )" "$rigDismissed/rig-flag" || exit 1
RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" MMDAPP="$rigWs" \
	bash -c '. "$1" ; AgentsToolsScheduleDismiss "$2" "the reason"' rig-kill "$rigTmp/prelude-kill.sh" "$rigFlag" > "$rigTmp/kill.out" 2>&1
rigAssert "the kill names the schedule as its actor" "$( rigLog '^kill .*rig-flag run schedule$' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE MANUAL SUPERVISION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_MANUAL_SUPERVISION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
