#!/usr/bin/env bash
## Behavioural check on the autorun the day's routines declare (F7.12: the scheduler decides the day rhythm). Held, with the real routine files, run and not read:
##   1. THE DECLARATIONS: magic-librarian.morning-review `runs-at: workdays 09:00`; magic-team.grooming `runs-at: workdays 09:00` after the morning review
##      (`runs-after: magic-librarian.morning-review`); magic-coordinator.daily `runs-at: workdays 10:00` after the grooming (`runs-after: magic-team.grooming`);
##      magic-coordinator.retro `runs-at: none`, the retro staying manual.
##   2. THE ROUTINE VALIDATOR takes each of the four with no row.
##   3. THE DAY, by the scheduler's own evaluation (--routine-due) over a rig clock, a Monday of the team's zone: before 09:00 nothing is due; at 09:05 the
##      morning review is due and the grooming is refused until the review completed that day; once it did, the grooming is due; the daily is not before
##      10:00, and once the grooming completed it is due at 10:05; the retro is never due; on a Saturday none of the three is due (the weekend follows from
##      `workdays`).
##   4. THE DAILY NO LONGER SPAWNS THE MORNING REVIEW: its steps carry no spawn-morning-review, and the numbers of its steps run on from 1.
## Offline, rig tree only: the schedule rig of AgentsScheduleLoopCheck, its clock and its Slack-shaped curl.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigSkillset="$rigPackage/skillset/magic-team"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineAutorunDeclaredCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigReview="$rigSkillset/magic-librarian/magic-librarian.morning-review.routine.md"
rigGrooming="$rigSkillset/magic-team/magic-team.grooming.routine.md"
rigDaily="$rigSkillset/magic-coordinator/magic-coordinator.daily.routine.md"
rigRetro="$rigSkillset/magic-coordinator/magic-coordinator.retro.routine.md"
rigKeys(){ ## file -- its autorun keys, in a line
	LC_ALL=C awk 'NR == 1 { next } $0 == "---" { exit } /^(runs-at|runs-after): / { printf "%s | ", $0 }' "$1"
}

echo "-- 1. the declarations --"
rigAssert "morning review: workdays 09:00, after nothing" "$( rigKeys "$rigReview" )" "runs-at: workdays 09:00 | "
rigAssert "grooming: workdays 09:00, after the morning review" "$( rigKeys "$rigGrooming" )" "runs-at: workdays 09:00 | runs-after: magic-librarian.morning-review | "
rigAssert "daily: workdays 10:00, after the grooming" "$( rigKeys "$rigDaily" )" "runs-at: workdays 10:00 | runs-after: magic-team.grooming | "
rigAssert "retro: none, it stays manual" "$( rigKeys "$rigRetro" )" "runs-at: none | "

. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
rigScheduleSetup 1
cp "$rigReview" "$rigSkills/magic-librarian/" && cp "$rigGrooming" "$rigSkills/magic-team/" && cp "$rigDaily" "$rigRetro" "$rigSkills/magic-coordinator/" || rigRefuse "the real routines could not be copied into the rig"

echo "-- 2. the validator --"
rigValidate(){ ## file -- the rows the validator says, then rc
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigFn" --intern-doc-validate routine "$1" 2>&1 < /dev/null | LC_ALL=C grep -c -E '^[^ ]+:[0-9]+: ' ; echo "rc=${PIPESTATUS[0]}" )
}
for rigFile in "$rigReview" "$rigGrooming" "$rigDaily" "$rigRetro" ; do
	rigAssert "${rigFile##*/}: no row, rc 0" "$( rigValidate "$rigFile" | tr '\n' ' ' )" "0 rc=0 "
done

echo "-- 3. the day --"
rigDue(){ ## routine name -- what --routine-due says, its answer line without the routine's own file name, then its rc
	local dueOut dueRc=0
	dueOut="$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --routine-due "$1" 2> /dev/null < /dev/null )" || dueRc=$?
	printf '%s rc=%s' "$( printf '%s\n' "$dueOut" | LC_ALL=C grep -E '^(DUE|NOT-DUE|REFUSED): ' | head -1 | LC_ALL=C sed 's/ [^ :]*\.routine\.md:\{0,1\}//' )" "$dueRc"
}
rigDone(){ ## id, owner, routine file name, started, resolved -- a completed run of a routine, as the spawner records it
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: %s\nroutine: %s\nstatus: spawn-succeeded\nstarted-at: %s\nresolved-at: %s\n---\n\n# Spawn session: %s\n' "$1" "$1" "$rigHost" "$2" "$3" "$4" "$5" "$1" > "$rigSp/$1/$1.md"
}
## Monday 2026-10-19 in Etc/GMT-3: 08:00, 09:05, 09:50, 10:05; Saturday 2026-10-24 13:00.
rigAt 1792386000
rigAssert "Monday 08:00: the morning review is not due, before its earliest start" "$( rigDue magic-librarian.morning-review )" "NOT-DUE: before its earliest start, 09:00 rc=1"
rigAt 1792389900
rigAssert "Monday 09:05: the morning review is due" "$( rigDue magic-librarian.morning-review )" "DUE: rc=0"
rigAssert "...the grooming is refused until the review completed that day" "$( rigDue magic-team.grooming )" "REFUSED: magic-librarian.morning-review.routine.md has not completed today rc=2"
rigAssert "...and the daily is not due before 10:00" "$( rigDue magic-coordinator.daily )" "NOT-DUE: before its earliest start, 10:00 rc=1"
rigDone rig-review-$rigTag magic-librarian magic-librarian.morning-review.routine.md "2026-10-19 09:06 +0300" "2026-10-19 09:30 +0300"
rigAt 1792392600
rigAssert "Monday 09:50, the review completed: the grooming is due" "$( rigDue magic-team.grooming )" "DUE: rc=0"
rigAssert "...the daily is still not due: before 10:00" "$( rigDue magic-coordinator.daily )" "NOT-DUE: before its earliest start, 10:00 rc=1"
rigDone rig-groom-$rigTag magic-coordinator magic-team.grooming.routine.md "2026-10-19 09:51 +0300" "2026-10-19 10:01 +0300"
rigAt 1792393500
rigAssert "Monday 10:05, the grooming completed: the daily is due" "$( rigDue magic-coordinator.daily )" "DUE: rc=0"
rigAssert "the retro is never due" "$( rigDue magic-coordinator.retro )" "NOT-DUE: it declares no autorun (runs-at: none) rc=1"
rigAt 1792836000
rigAssert "Saturday: none of the three is due, workdays being the days" "$( rigDue magic-librarian.morning-review | LC_ALL=C cut -c1-32 ):$( rigDue magic-team.grooming | LC_ALL=C cut -c1-32 ):$( rigDue magic-coordinator.daily | LC_ALL=C cut -c1-32 )" "NOT-DUE: today is not one of its:NOT-DUE: today is not one of its:NOT-DUE: today is not one of its"

echo "-- 4. the daily spawns no morning review --"
rigAssert "no spawn-morning-review in the daily or the librarian's routine" "$( LC_ALL=C grep -c 'spawn-morning-review' "$rigDaily" "$rigReview" | LC_ALL=C tr '\n' ' ' )" "$rigDaily:0 $rigReview:0 "
rigAssert "the steps of the daily are numbered from 1, one after another" "$( LC_ALL=C awk '/^# Steps/ { on = 1 ; next } /^# / { on = 0 } on && /^[0-9]+\. \*\*/ { n++ ; split( $0, a, "." ) ; if ( a[1] + 0 != n ) bad++ } END { print n + 0, bad + 0 }' "$rigDaily" )" "9 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE AUTORUN DECLARED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_AUTORUN_DECLARED: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
