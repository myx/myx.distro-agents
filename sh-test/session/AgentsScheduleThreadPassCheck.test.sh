#!/usr/bin/env bash
## Behavioural check on what the schedule's pass answers the shared thread (S12.12; `AgentsToolsScheduleThreadPass` in
## AgentsTools.ScheduleThread.include): 2 while a flag that keeps duties is on, so the thread stays with no session live to ask,
## and 0 otherwise, so the thread ends by idleness and the next ask starts it again.
## WHAT IS MEASURED IS THE ANSWER, NOT THE FLAG. The flag reader is a stand-in that prints the lines a real `--current-flags` prints, and the
## pass's two heavy steps are stand-ins too. Which flags the clock and the settings produce is AgentsSchedulerFlagsCheck's question.
## Held:
##   1. WITH NO FLAG ON it answers 0, so the thread ends by its idle bound.
##   2. WITH WORKTIME ON it answers 2.
##   3. WITH OVERTIME ALONE, worktime off, it answers 2.
##   4. WITH EMERGENCY ALONE, worktime off, it answers 2.
##   5. THE PASS IS MINUTES APART: a second tick a moment later runs no pass, and it is the same stand-in the first tick called that says so.
## Offline: no clock is faked and no workspace is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadPassCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
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
## THE STAND-INS, inherited by the include's own `type ... || . ` guards so no real one is sourced over them:
##   the flag reader prints the lines the pass reads, from RIG_FLAGS, a file of one `<flag>: yes|no` line each;
##   the pass's two steps count themselves in RIG_STEPS, so "a pass ran" and "a pass did not run" are told apart.
rigRun(){ ## -- what the pass answers, and how many passes ran
	local out=""
	out="$( env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_FLAGS="$rigTmp/flags" RIG_STEPS="$rigTmp/steps" \
		bash -c '
			AgentsToolsScheduleCurrentFlags(){ cat "$RIG_FLAGS" ; return 0 ; }
			AgentsToolsScheduleLoop(){ printf "loop\n" >> "$RIG_STEPS" ; return 0 ; }
			AgentsToolsBoardDependencies(){ printf "board\n" >> "$RIG_STEPS" ; return 0 ; }
			export -f AgentsToolsScheduleCurrentFlags AgentsToolsScheduleLoop AgentsToolsBoardDependencies
			export RIG_FLAGS RIG_STEPS
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ScheduleThread.include" > /dev/null 2>&1
			AgentsToolsScheduleThreadPass
			printf "%s" "$?"
			AgentsToolsScheduleThreadPass
			printf " %s" "$?"
			printf " passes=%s" "$( LC_ALL=C grep -c "^loop$" "$RIG_STEPS" 2> /dev/null || printf 0 )"
		' 2> /dev/null )"
	printf '%s' "$out"
}
rigFlags(){ ## the flag lines the pass will read
	printf '%s\n' "$@" > "$rigTmp/flags"
}
rigNothingOn(){
	rigFlags "worktime: no (default)" "weekend: no (default)" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no"
}
: > "$rigTmp/steps"

echo "-- 1. no flag on: the thread is free to end --"
rigNothingOn
rigAssert "with no flag on, the pass answers 0" "$( rigRun )" "0 0 passes=1"

echo "-- 2. worktime on --"
rigFlags "worktime: yes (default)" "weekend: no (default)" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no"
: > "$rigTmp/steps"
rigAssert "with worktime on, the pass answers 2, and a second tick moments later answers 2 from the same pass" \
	"$( rigRun )" "2 2 passes=1"

echo "-- 3. overtime alone, worktime off --"
rigFlags "worktime: no (default)" "weekend: no (default)" "holidays: no" "emergency: no" "overtime: yes (1200 seconds left)" "learning: no" "supervised: no"
: > "$rigTmp/steps"
rigAssert "with overtime on and worktime off, the pass answers 2" "$( rigRun )" "2 2 passes=1"

echo "-- 4. emergency alone, worktime off --"
rigFlags "worktime: no (default)" "weekend: no (default)" "holidays: no" "emergency: yes (3600 seconds left)" "overtime: no" "learning: no" "supervised: no"
: > "$rigTmp/steps"
rigAssert "with emergency on and worktime off, the pass answers 2" "$( rigRun )" "2 2 passes=1"

echo "-- 5. a flag that keeps no duty does not keep the thread --"
rigFlags "worktime: no (default)" "weekend: no (default)" "holidays: no" "emergency: no" "overtime: no" "learning: yes" "supervised: yes"
: > "$rigTmp/steps"
rigAssert "with learning and supervised on and no duty flag, the pass answers 0" "$( rigRun )" "0 0 passes=1"

## THE THREAD IS WANTED, AND ASKED FOR (S12.71): a member's own overtime, or worktime within thirty minutes, wants it as a flag does; a live caller (the comms
## reader) asks for it by AgentsToolsScheduleThreadAskDue, once a minute, and asks for it only where it is wanted.
rigAskDue(){ ## the member with overtime (may be empty), seconds to the next worktime (may be empty) -- how many asks two calls made, and what the first left in the keep
	local asked=""
	asked="$( env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_FLAGS="$rigTmp/flags" RIG_ASKS="$rigTmp/asks" RIG_OVER="$1" RIG_TO="$2" \
		bash -c '
			AgentsToolsScheduleCurrentFlags(){ cat "$RIG_FLAGS" ; return 0 ; }
			export -f AgentsToolsScheduleCurrentFlags
			export RIG_FLAGS RIG_ASKS RIG_OVER RIG_TO
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ScheduleThread.include" > /dev/null 2>&1
			## The include, and the includes it sources, define these themselves, so the stand-ins go in after it.
			AgentsToolsTeamMemberDirectoryText(){ printf "keeper-rig\t/x\nmagic-coordinator\t/y\n" ; }
			AgentsToolsScheduleMemberFlag(){ [ "$2" = "$RIG_OVER" ] && [ "$1" = overtime ] && printf "on\n" ; return 0 ; }
			AgentsToolsScheduleClock(){ printf "1000000 0 0 0\n" ; }
			AgentsToolsScheduleNextWorkStart(){ [ -z "$RIG_TO" ] || printf "%s\n" "$(( $1 + RIG_TO ))" ; }
			AgentsToolsScheduleThreadAsk(){ printf "ask\n" >> "$RIG_ASKS" ; printf "alive 1\n" ; }
			AgentsToolsScheduleThreadAskDue
			printf "%s" "$agentsScheduleThreadKeep"
			AgentsToolsScheduleThreadAskDue
			printf " asks=%s" "$( LC_ALL=C grep -c "^ask$" "$RIG_ASKS" 2> /dev/null | LC_ALL=C head -1 )"
		' 2> /dev/null )"
	printf '%s' "$asked"
}
echo "-- 6. a member's overtime, or the hour near, wants the thread; a live caller asks for it --"
rigNothingOn
: > "$rigTmp/asks"
rigAssert "nothing on, worktime far: not wanted, nothing asked" "$( rigAskDue "" "" )" "no asks=0"
: > "$rigTmp/asks"
rigAssert "a member's own overtime on: wanted, asked once, and not again inside the minute" "$( rigAskDue magic-coordinator "" )" "yes asks=1"
: > "$rigTmp/asks"
rigAssert "worktime in 20 minutes: wanted, asked once" "$( rigAskDue "" 1200 )" "yes asks=1"
: > "$rigTmp/asks"
rigAssert "worktime in two hours: not wanted, nothing asked" "$( rigAskDue "" 7200 )" "no asks=0"
rigFlags "worktime: yes (default)" "weekend: no (default)" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no"
: > "$rigTmp/asks"
rigAssert "worktime on: wanted, asked" "$( rigAskDue "" "" )" "yes asks=1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD PASS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_PASS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
