#!/usr/bin/env bash
## Behavioural check on what makes a run a duty (S18.4): AgentsToolsDutyRoutineIs answers for both duty kinds, work-duty
## and off-duty, and every site that used to test the one suffix asks it. Held, run and not read:
##   1. THE PREDICATE answers yes for `<member>.work-duty.routine.md` and `<member>.off-duty.routine.md`, by bare name
##      and by path, for a member name of the roster's shape.
##   2. THE CONTROL is row 1's four noes: a routine that is no duty, a name that merely ends like one, a bare word, and
##      nothing at all. A predicate that answered yes to everything passes row 1 and fails these.
##   2b. A CALLER THAT NAMES THE KIND asks the one list for that kind: a work-duty routine answers work-duty and not
##      off-duty, and the other way round, so a caller needs no suffix test of its own.
##   3. THE RECORD PATTERN matches a spawn record's own `routine:` line of either kind, and matches no other line.
##   4. THE SITES: every file the design names asks the predicate, the duty-record list asks the pattern, and no case arm
##      or test anywhere in sh-lib or sh-scripts is keyed on one duty suffix alone.
## Offline: the package's own files, and one child process an assertion. No rig folder.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/routine/AgentsTools.DutyRoutine.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the duty predicate is not in this tree: sh-lib/routine/AgentsTools.DutyRoutine.include"
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
rigIs(){ ## routine name or path, [the duty kind] -- yes or no, from the predicate in this tree
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash -c '
		set +e
		. "$1" || exit 9
		AgentsToolsDutyRoutineIs "${2:-}" "${3:-}" && printf yes || printf no
	' rig "$rigInclude" "$1" "${2:-}" 2> /dev/null
}
rigMatches(){ ## one line -- yes or no, from the record pattern
	printf '%s\n' "$1" | env -i PATH="/usr/bin:/bin" bash -c '
		set +e
		. "$1" || exit 9
		LC_ALL=C grep -q -E "$( AgentsToolsDutyRoutineRecordPattern )" && printf yes || printf no
	' rig "$rigInclude" 2> /dev/null
}

echo "-- 1. the predicate answers for both kinds --"
rigAssert "the team's work-duty routine"                     "$( rigIs magic-team.work-duty.routine.md )" "yes"
rigAssert "the coordinator's own work-duty routine"          "$( rigIs magic-coordinator.work-duty.routine.md )" "yes"
rigAssert "the coordinator's off-duty routine"               "$( rigIs magic-coordinator.off-duty.routine.md )" "yes"
rigAssert "a keeper's off-duty routine"                      "$( rigIs keeper-mel.off-duty.routine.md )" "yes"
rigAssert "the same one by its path"                         "$( rigIs /x/skillset/magic-team/magic-coordinator/magic-coordinator.off-duty.routine.md )" "yes"

echo "-- 2. the control: what is no duty --"
rigAssert "CONTROL: a routine that is no duty"               "$( rigIs magic-team.coworking.routine.md )" "no"
rigAssert "CONTROL: a name that only ends like a duty one"   "$( rigIs magic-team.work-duty.routine.md.bak )" "no"
rigAssert "CONTROL: a bare duty word is no routine"          "$( rigIs off-duty )" "no"
rigAssert "CONTROL: nothing at all"                          "$( rigIs '' )" "no"

echo "-- 2b. a caller that names the kind it wants is answered for that kind alone --"
rigAssert "work-duty asked for, on a work-duty routine"     "$( rigIs magic-coordinator.work-duty.routine.md work-duty )" "yes"
rigAssert "off-duty asked for, on an off-duty routine"      "$( rigIs magic-coordinator.off-duty.routine.md off-duty )" "yes"
rigAssert "CONTROL: off-duty asked for, on a work-duty one" "$( rigIs magic-coordinator.work-duty.routine.md off-duty )" "no"
rigAssert "CONTROL: work-duty asked for, on an off-duty one" "$( rigIs magic-coordinator.off-duty.routine.md work-duty )" "no"
rigAssert "CONTROL: a kind named on a routine that is neither" "$( rigIs magic-team.coworking.routine.md off-duty )" "no"

echo "-- 3. the record pattern --"
rigAssert "a work-duty record line"                          "$( rigMatches 'routine: magic-coordinator.work-duty.routine.md' )" "yes"
rigAssert "an off-duty record line"                          "$( rigMatches 'routine: magic-coordinator.off-duty.routine.md' )" "yes"
rigAssert "CONTROL: another routine's record line"           "$( rigMatches 'routine: magic-team.advance.routine.md' )" "no"
rigAssert "CONTROL: the same name not as a record line"      "$( rigMatches 'prefix-routine: magic-coordinator.off-duty.routine.md' )" "no"

echo "-- 4. every site asks it, and no site tests one suffix alone --"
rigSites="sh-lib/schedule/AgentsTools.DispatcherSchedule.include sh-lib/harness/AgentsHarnessSpawn.include sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include sh-lib/spawn/AgentsTools.SpawnSession.include sh-lib/spawn/AgentsTools.SpawnProxyHandbackMissing.include sh-lib/spawn/AgentsTools.SpawnProxyRoutineBrief.include sh-lib/supervise/AgentsTools.SuperviseResume.include sh-lib/supervise/AgentsTools.SuperviseBoard.include"
rigSilent=""
for rigOne in $rigSites ; do
	[ "$( LC_ALL=C grep -c -F 'AgentsToolsDutyRoutineIs ' "$rigPackage/$rigOne" )" -gt 0 ] || rigSilent="$rigSilent $rigOne"
done
rigAssert "every file of the named sites asks the predicate"  "$( [ -z "$rigSilent" ] && printf yes || printf 'no:%s' "$rigSilent" )" "yes"
rigAssert "the duty-record list asks the pattern"             "$( LC_ALL=C grep -c -F 'AgentsToolsDutyRoutineRecordPattern' "$rigPackage/sh-lib/schedule/AgentsTools.StartedRecords.include" )" "2"
rigAssert "and that pattern is built from the kinds' own list" "$( [ "$( LC_ALL=C grep -c 'agentsDutyRoutineKinds' "$rigInclude" )" -ge 2 ] && printf yes || printf no )" "yes"
rigLeft="$( LC_ALL=C grep -rn -E '(\.work-duty\.routine\.md|\.off-duty\.routine\.md)\)' "$rigPackage/sh-lib" "$rigPackage/sh-scripts" 2> /dev/null | LC_ALL=C grep -v 'AgentsTools.DutyRoutine.include' | LC_ALL=C grep -c . || : )"
rigAssert "no case arm in the tooling is keyed on one duty suffix" "$rigLeft" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY ROUTINE IS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_ROUTINE_IS: OK (%d assertions, offline)\n' "$rigPassCount"
