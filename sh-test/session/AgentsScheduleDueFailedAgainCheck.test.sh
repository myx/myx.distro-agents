#!/usr/bin/env bash
## Behavioural check of the autorun's bound on a failed start (code-craft: no unbounded retry; `AgentsDispatcherCompleted.awk` with
## `AgentsToolsScheduleDue`). One failed start leaves a routine due, as it never ran (AgentsScheduleDueAfterFailedCheck); a cause that
## outlives a pass, such as a provider's refusal, then started it again on every pass, all day. Held, run rather than read:
##   1. ONE START THAT FAILED, ten minutes ago, still leaves the routine due
##   2. TWO STARTS THAT FAILED WITHIN THE HOUR hold it, naming the last
##   3. TWO THAT FAILED, THE OLDER MORE THAN AN HOUR AGO, leave it due again
## The rig is AgentsScheduleDueAfterFailedCheck's: the real history reader and the real due evaluator, the clock a workday at 13:00.
## Red before the change: two failed starts within the hour left the routine due, so it was started again on the next pass.
## Offline: the include this check loads, a rig of its own, and no spawner, git or network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Dispatcher include is not at $rigInclude"
[ -f "$rigPackage/sh-lib/schedule/AgentsDispatcherCompleted.awk" ] || rigRefuse "the run-history awk is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleDueFailedAgainCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/agents" "$rigSkills/magic-team" || exit 1
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
## THE TWO ROUTINES OF THE RIG: a predecessor that declares an autorun, and a successor that runs after it.
printf -- '---\nruns-at: mon,tue,wed,thu,fri 09:00\n---\n# rig predecessor\n' > "$rigSkills/magic-team/rig-predecessor.routine.md"
printf -- '---\nruns-at: mon,tue,wed,thu,fri 10:00\nruns-after: rig-predecessor\n---\n# rig successor\n' > "$rigSkills/magic-team/rig-successor.routine.md"
## A SPAWN RECORD AS THE SPAWNER WRITES ONE, under the tree the history reader walks.
rigRecord(){ ## the name, the routine, the status, the started minute-of-day, and the resolved one where there is one
	local recName="$1" recRoutine="$2" recStatus="$3" recStarted="$4" recResolved="${5:-}"
	mkdir -p "$rigWs/.local/agents/spawned/$recName" || exit 1
	{
		printf -- '---\n'
		printf 'session-id: %s\nspawn-id: %s\nowner: rig-keeper\nroutine: %s\nstatus: %s\n' "$recName" "$recName" "$recRoutine" "$recStatus"
		printf 'started-at: 2026-11-06 %s +0000\n' "$recStarted"
		[ -z "$recResolved" ] || printf 'resolved-at: 2026-11-06 %s +0000\n' "$recResolved"
		printf -- '---\n'
	} > "$rigWs/.local/agents/spawned/$recName/$recName.spawn.md"
}
## THE ROUND'S SHELL: the real history reader and the real due evaluator, with the routine's frontmatter, the clock and the day as the
## rig's own. The clock says a workday at the minute the check asks for, so the records it writes are the whole story.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
AgentsToolsScheduleTools(){ return 0 ; }
## The resolver answers the routine file a selector names: a name already ending in the routine suffix is taken as it stands, and a bare
## name is the predecessor's own short form, as `runs-after:` writes one.
AgentsToolsSpawnRoutineResolve(){
	case "$1" in
		*.routine.md) [ -f "$RIG_SKILLS/magic-team/$1" ] || return 1 ; printf '%s\n' "$RIG_SKILLS/magic-team/$1" ;;
		*) [ -f "$RIG_SKILLS/magic-team/$1.routine.md" ] || return 1 ; printf '%s\n' "$RIG_SKILLS/magic-team/$1.routine.md" ;;
	esac
}
AgentsToolsRoutineKeyOwn(){
	case "$2" in
		runs-at) LC_ALL=C awk -F': ' '/^runs-at: / { print $2 ; exit ; }' "$1" ;;
		runs-after) LC_ALL=C awk -F': ' '/^runs-after: / { print $2 ; exit ; }' "$1" ;;
	esac
}
AgentsToolsScheduleTimeSeconds(){ printf '%s\n' "$(( ( 10#${1%%:*} * 60 + 10#${1#*:} ) * 60 ))" ; }
AgentsToolsScheduleClock(){ printf '%s %s %s %s\n' "$RIG_EPOCH" 0 5 "$RIG_SECONDS" ; }
AgentsToolsScheduleDayName(){ printf 'fri\n' ; }
## The days value is a comma-separated list, so each day is compared as its own word.
AgentsToolsScheduleDayIn(){ case " $( printf '%s' "$1" | LC_ALL=C tr ',' ' ' ) " in *" $2 "*) return 0 ;; esac ; return 1 ; }
## A RIG THAT DID NOT REACH ITS SUBJECT FAILS LOUDLY, never passes: the include loads its own history reader through MDLT_ORIGIN, and a
## package copy reached by a wrong origin leaves that reader missing, which reads exactly like a routine that never ran.
for rigNeed in AgentsToolsScheduleDue AgentsToolsDispatcherHistory AgentsToolsRoutineKeyOwn AgentsToolsSpawnRoutineResolve ; do
	type "$rigNeed" > /dev/null 2>&1 || { printf '⛔ ERROR: the rig could not load %s\n' "$rigNeed" >&2 ; exit 3 ; }
done
PRELUDE
## The day the clock stands in: 2026-11-06, and the seconds into it the check asks for (13:00, past both earliest starts).
## The include sources its own history reader from `$MDLT_ORIGIN/myx/myx.distro-agents`, so the origin here is the folder holding that
## `myx/myx.distro-agents`, taken from the package under test and never from the session. A copy that does not hold that layout fails
## loudly below, because its history reader would be missing and every routine would read as never run.
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents, so its own history reader cannot be loaded: $rigPackage" ;;
esac
[ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] || rigRefuse "no package tree under $rigOrigin"
rigDueFor(){ ## the routine to ask about
	RIG_INCLUDE="$rigInclude" RIG_SKILLS="$rigSkills" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" RIG_EPOCH="$(( rigEpoch + 46800 ))" RIG_SECONDS="46800" \
		bash -c '. "$1" ; shift ; AgentsToolsScheduleDue --read-only "$1"' rig-due "$rigTmp/prelude.sh" "$@" 2>&1 ; }
rigEpoch="$( date -u -j -f '%Y-%m-%d %H:%M' '2026-11-06 00:00' '+%s' 2> /dev/null || date -u -d '2026-11-06 00:00' '+%s' )"
[ -n "$rigEpoch" ] || rigRefuse "this host's date cannot give the epoch of the rig's day"

echo "-- 1. one start that failed, ten minutes ago, leaves it due --"
rigRecord failed-one rig-predecessor.routine.md spawn-failed '12:50'
rigAssert "the routine is due" "$( rigDueFor rig-predecessor.routine.md )" 'DUE: rig-predecessor.routine.md'

echo "-- 2. two that failed within the hour hold it --"
rigRecord failed-two rig-predecessor.routine.md spawn-failed '12:55'
rigAssert "the routine is not due, naming the last failed start" "$( rigDueFor rig-predecessor.routine.md )" \
	'NOT-DUE: rig-predecessor.routine.md: its start failed twice within the hour, the last at 2026-11-06_12:55_+0000'

echo "-- 3. two that failed, the older more than an hour ago, leave it due --"
rm -rf "$rigWs/.local/agents/spawned"/*
rigRecord failed-old rig-predecessor.routine.md spawn-failed '11:50'
rigRecord failed-new rig-predecessor.routine.md spawn-failed '12:55'
rigAssert "the routine is due again" "$( rigDueFor rig-predecessor.routine.md )" 'DUE: rig-predecessor.routine.md'

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE DUE FAILED AGAIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_DUE_FAILED_AGAIN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
