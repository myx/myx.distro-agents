#!/usr/bin/env bash
## Behavioural check on which members the schedule starts a work duty for, and why (S12.12/S13; `AgentsToolsScheduleWorkDuty` in
## AgentsTools.DispatcherSchedule.include). What is measured is the START and its stated reason, never the roster: the roster, the duty
## records, the flags, the pace and the spawner are all stand-ins, so each rule is met on its own.
## Held:
##   1. WORKTIME starts a standing member that has work, and says so with no reason clause.
##   2. OVERTIME ALONE (worktime off) starts every standing member with work, as worktime does.
##   3. EMERGENCY ALONE (worktime off) starts a member other than the coordinator only for a pending task it owns marked emergency or important.
##   4. A pending item of the member carrying no mark starts nothing out of hours.
##   5. THE COORDINATOR starts in emergency out of hours, whatever it owns.
##   6. A `dispatch-*` pending item is never the reason a member starts. That one rule is declared and is NOT met: see the row that names it.
##   7. A member with a duty already running is left alone.
## Offline: no clock is faked, no workspace is read, and the spawner is a counter.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleWorkDutyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigData="$rigTmp/data" rigMembers="$rigTmp/members" rigSpawned="$rigTmp/spawned"
for m in keeper-rig-one keeper-rig-two magic-coordinator ; do mkdir -p "$rigMembers/$m" ; printf "status: active\n" > "$rigMembers/$m/SKILL.md" ; done
mkdir -p "$rigData/board/pending" "$rigData/inboxes" "$rigMembers/keeper-rig-one" "$rigMembers/keeper-rig-two" "$rigSpawned" "$rigTmp/home" || exit 1

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
## The board takes a pending item as its frontmatter, an owner and a mark.
rigPending(){ ## stem, owner, mark
	{
		printf -- '---\ntype: task\nowner: %s\n' "$2"
		[ -z "${3:-}" ] || printf 'mark: %s\n' "$3"
		printf -- '---\n\nrig item\n'
	} > "$rigData/board/pending/$1.md"
}
rigNoPending(){ rm -f "$rigData/board/pending"/*.md ; }
## THE STAND-INS. Every one is inherited by the include's `type ... || . ` guards, so no real one is sourced over it.
##   the flags come from RIG_FLAGS, one `<flag>: yes|no` line each;
##   the spawner counts its calls in RIG_CALLS and always answers success;
##   the roster is the two rig members;
##   a duty record exists only where RIG_DUTY names the member.
rigRun(){ ## -- the reasons the pass stated, from RIG_CALLS, and the line of each
	: > "$rigTmp/calls"
	: > "$rigTmp/run.out"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_FLAGS="$rigTmp/flags" RIG_CALLS="$rigTmp/calls" RIG_MEMBERS="$rigMembers" RIG_DUTY="$rigTmp/duty" \
		RIG_DATA="$rigData" RIG_SPAWNED="$rigSpawned" \
		bash -c '
			MMDAPP="${RIG_DATA%/data}" ; export MMDAPP
			MDAT_DATA_ROOT="$RIG_DATA" ; export MDAT_DATA_ROOT
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			## The include defines every helper this pass calls, so the stand-ins go in AFTER it is sourced, never before.
			AgentsToolsScheduleCurrentFlags(){ cat "$RIG_FLAGS" ; return 0 ; }
			AgentsToolsSchedulePaceText(){ printf "pace: 1 of 9 calls in 30 minutes -- under 7000, a duty start is allowed\n" ; return 0 ; }
			AgentsToolsScheduleDutyStaleClose(){ return 0 ; }
			AgentsToolsScheduleTeamTags(){ return 0 ; }
			AgentsToolsScheduleDmTags(){ return 0 ; }
			AgentsToolsScheduleTagNews(){ return 1 ; }
			AgentsToolsTeamMemberDirectoryText(){ for m in keeper-rig-one keeper-rig-two magic-coordinator ; do printf "%s\t%s/%s\n" "$m" "$RIG_MEMBERS" "$m" ; done ; }
			AgentsToolsScheduleDutyRoutine(){ printf "magic-team.work-duty.routine.md\n" ; }
			AgentsToolsScheduleSpawn(){ printf "%s\n" "$1" >> "$RIG_CALLS" ; return 0 ; }
			AgentsToolsScheduleTagCarry(){ return 0 ; }
			AgentsToolsScheduleDemand(){ return 0 ; }
			AgentsToolsScheduleDutyRestartDue(){ return 1 ; }
			AgentsToolsScheduleWorkDutyRecord(){ case "$1" in *) [ -s "$RIG_DUTY" ] && [ "$( cat "$RIG_DUTY" )" = "$1" ] && { printf "%s/rig.spawn.md\n" "$RIG_SPAWNED" ; return 0 ; } ; return 1 ;; esac ; }
			AgentsToolsScheduleDutyLifetime(){ return 0 ; }
			AgentsToolsScheduleWorkDuty 2> /dev/null
		' > "$rigTmp/run.out" 2> /dev/null
	printf '%s' "$( LC_ALL=C grep -E '^work-duty\.' "$rigTmp/calls" 2> /dev/null | LC_ALL=C sed 's/^work-duty\.//' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
}
rigFlags(){ ## the flag lines the pass will read
	printf '%s\n' "$@" > "$rigTmp/flags"
}
rigInWorktime(){ rigFlags "worktime: yes" "weekend: no" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no" ; }
rigOutOfTime(){ rigFlags "worktime: no" "weekend: no" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no" ; }
rigOvertime(){ rigFlags "worktime: no" "weekend: no" "holidays: no" "emergency: no" "overtime: yes" "learning: no" "supervised: no" ; }
rigEmergency(){ rigFlags "worktime: no" "weekend: no" "holidays: no" "emergency: yes" "overtime: no" "learning: no" "supervised: no" ; }
rigDuty(){ printf '%s\n' "$1" > "$rigTmp/duty" ; }
rm -f "$rigTmp/duty"
## Every member has an inbox item, so demand is never the thing that varies below.
for m in keeper-rig-one keeper-rig-two magic-coordinator ; do mkdir -p "$rigData/inboxes/$m/incoming" ; printf -- '---\ntype: note\n---\n' > "$rigData/inboxes/$m/incoming/note-20261106T000000Z-rig.md" ; done

echo "-- 1. worktime --"
rigInWorktime ; rigNoPending
rigAssert "in worktime every standing member with work is started, the coordinator too" "$( rigRun )" "keeper-rig-one keeper-rig-two magic-coordinator "

echo "-- 2. overtime alone --"
rigOvertime ; rigNoPending
## Team overtime gives a duty to a magic-* member alone (the owner's ruling): the keepers are started in worktime, or for a task of their own marked urgent or emergency.
rigAssert "with overtime on and worktime off, the magic members with work are started and the keepers are not" "$( rigRun )" "magic-coordinator "

echo "-- 3. emergency alone, a marked pending task --"
rigEmergency
rigNoPending ; rigPending task-20261106T000000Z-rig keeper-rig-one important
## The marks that pass out of hours are bound by time and not by importance: urgent and emergency pass, important does not (AgentsToolsScheduleWorkDuty, dutyOwners).
rigAssert "out of hours a member does not start for a pending task it owns that carries an important mark" "$( rigRun )" "magic-coordinator "
rigNoPending ; rigPending task-20261106T000001Z-rig keeper-rig-two emergency
rigAssert "and for one that carries an emergency mark" "$( rigRun )" "keeper-rig-two magic-coordinator "

echo "-- 4. an unmarked pending task out of hours --"
rigNoPending ; rigPending task-20261106T000002Z-rig keeper-rig-one
rigAssert "an unmarked pending task starts no keeper out of hours" "$( rigRun )" "magic-coordinator "

echo "-- 5. the coordinator in emergency --"
rigNoPending
rigAssert "out of hours in emergency, the keepers wait and the coordinator starts" "$( rigRun )" "magic-coordinator "

echo "-- 6. a dispatch-* item is never the reason --"
rigNoPending ; rigPending dispatch-20261106T000000Z-rig keeper-rig-one important
rigAssert "a dispatch-* pending item starts no keeper out of hours" "$( rigRun )" "magic-coordinator "

echo "-- 7. a member whose duty already runs --"
rigInWorktime ; rigNoPending ; rigDuty keeper-rig-one
rigAssert "a member whose duty is already running is not started again" "$( rigRun )" "keeper-rig-two magic-coordinator "
rm -f "$rigTmp/duty"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE WORK DUTY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_WORK_DUTY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
