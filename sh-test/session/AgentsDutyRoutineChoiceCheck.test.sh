#!/usr/bin/env bash
## Behavioural check on how the schedule picks the routine of a member's duty (S18.4): AgentsToolsScheduleDutyRoutine
## answers the off-duty routine out of the member's hours, and its work-duty routine in them. Held, over a skill folder
## standing the routines up as plain files:
##   1. OUT OF ITS HOURS a member that holds `<member>.off-duty.routine.md` is given that one.
##   2. THE CONTROL: in its hours the same member, over the same folder, is given its work-duty routine. A resolver that
##      ignored the hours passes row 1 or row 2, never both.
##   3. A MEMBER WITH NO OFF-DUTY ROUTINE keeps its own work-duty one out of hours too, and one that holds both takes its
##      off-duty one out of hours and its work-duty one in them.
##   4. A MEMBER HOLDING NEITHER is given the team's work-duty routine, out of hours as in them.
##   5. NO FOLDER AT ALL is given the team's routine, so a missing folder never turns into a crash, and an unstated hour
##      is not out of hours.
## Offline: the schedule include alone, no tool call. No rig folder.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the schedule include is not in this tree: sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyRoutineChoiceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/home" "$rigTmp/ws" "$rigTmp/data" \
	"$rigSkills/magic-coordinator" "$rigSkills/keeper-both" "$rigSkills/keeper-work" "$rigSkills/keeper-none"
for rigOne in magic-coordinator/magic-coordinator.off-duty.routine.md magic-coordinator/magic-coordinator.work-duty.routine.md \
	keeper-both/keeper-both.off-duty.routine.md keeper-both/keeper-both.work-duty.routine.md keeper-work/keeper-work.work-duty.routine.md ; do
	printf -- '---\ntype: routine\n---\n\nrig\n' > "$rigSkills/$rigOne"
done

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
rigChoice(){ ## member, folder, hours word (may be empty) -- what the resolver prints
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" \
		MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
			set +e
			. "$1" > /dev/null 2>&1
			if [ -n "${4:-}" ] ; then AgentsToolsScheduleDutyRoutine "$2" "${3:-}" "$4" ; else AgentsToolsScheduleDutyRoutine "$2" "${3:-}" ; fi
		' rig "$rigInclude" "$1" "${2:-}" "${3:-}" "${4:-}" 2> /dev/null
}

echo "-- 1 and 2. the hours decide, not the files --"
rigAssert "out of its hours, the coordinator's off-duty routine"      "$( rigChoice magic-coordinator "$rigSkills/magic-coordinator" no )" "magic-coordinator.off-duty.routine.md"
rigAssert "in its hours, its work-duty routine (CONTROL)"             "$( rigChoice magic-coordinator "$rigSkills/magic-coordinator" yes )" "magic-coordinator.work-duty.routine.md"

echo "-- 3. a member with no off-duty routine keeps its work-duty one --"
rigAssert "a keeper with only a work-duty routine, out of hours"      "$( rigChoice keeper-work "$rigSkills/keeper-work" no )" "keeper-work.work-duty.routine.md"
rigAssert "a keeper holding both, out of hours, takes its off-duty"   "$( rigChoice keeper-both "$rigSkills/keeper-both" no )" "keeper-both.off-duty.routine.md"
rigAssert "the same keeper in its hours takes its work-duty one"      "$( rigChoice keeper-both "$rigSkills/keeper-both" yes )" "keeper-both.work-duty.routine.md"

echo "-- 4 and 5. no routine of its own, and no folder at all --"
rigAssert "a member holding neither, out of hours: the team's"        "$( rigChoice keeper-none "$rigSkills/keeper-none" no )" "magic-team.work-duty.routine.md"
rigAssert "and in its hours: the team's"                              "$( rigChoice keeper-none "$rigSkills/keeper-none" yes )" "magic-team.work-duty.routine.md"
rigAssert "with no folder given, out of hours: the team's"            "$( rigChoice magic-coordinator "" no )" "magic-team.work-duty.routine.md"
rigAssert "with the hour unstated, a holding member's work-duty one"  "$( rigChoice magic-coordinator "$rigSkills/magic-coordinator" )" "magic-coordinator.work-duty.routine.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY ROUTINE CHOICE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_ROUTINE_CHOICE: OK (%d assertions, offline)\n' "$rigPassCount"
