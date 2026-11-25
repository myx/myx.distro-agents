#!/usr/bin/env bash
## Behavioural check on the schedule's answer to a start that fails again and again (S12.12; AgentsToolsScheduleStartFailed,
## AgentsToolsScheduleStartHeld in AgentsTools.DispatcherSchedule.include), run rather than read, over a rig workspace. Held:
##   1. TWO FAILURES IN A ROW escalate nothing and hold nothing: the count stands at 2.
##   2. THE THIRD FAILURE escalates once, with the key, the count and the last failure's words, and the key is held.
##   3. A FOURTH FAILURE escalates no second time.
##   4. A START THE ROUTINE'S OWN LOCK REFUSED is a wait, not a failure: it counts for nothing.
##   5. A SUCCESS clears the count and the hold, as the start's own success path does.
##   6. A HOLD PAST ITS MINUTES is lifted, with the count, so the next start is a fresh streak.
##   7. THE HOLD IS AGED ON THE PASS CLOCK, as the ten-minute hold of a start is: dated at a pass instant, it holds for its minutes of pass time.
##   8. A FILING THE TOOLING REFUSED MAKES NO HOLD, AND THE NEXT FAILURE FILES IT AGAIN: a key never reads as held while the
##      coordinator was told nothing, and a refusal does not spend the escalation.
## The inquiry's filing is replaced by a function of this check's own, so nothing is posted or written to any inbox.
## Red before the change: the functions are not defined, so every row fails.
## Offline: a rig workspace under this check's temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleStartFailsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every thread a scene started ends before the rig goes (rigControlThreadsEnd, T1905Z).
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/schedule/starting"
mkdir -p "$rigStore" "$rigWs/.local/temp" || exit 1
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
## The include's own sourcing reads a positional parameter, so -u is lifted around it, as AgentsSchedulePaceAndStandingCheck does.
set +u
. "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || :
set -u
type AgentsToolsScheduleStartFailed > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleStartFailed is not defined by sourcing the schedule's functions"
type AgentsToolsScheduleStartHeld > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleStartHeld is not defined by sourcing the schedule's functions"
## THE FILING, replaced: what the escalation hands over is kept in files of this rig, one more line a call.
rigEscalations=0
AgentsToolsScheduleStartEscalate(){ ## key, failures in a row, the last failure's words
	rigEscalations=$(( rigEscalations + 1 ))
	printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$rigTmp/escalated"
	return 0
}
rigKey="work-duty.rig-keeper"
rigFailure=$'something first\n⛔ ERROR: DistroAgentsTools --spawn-session: the brief file is missing\nmore'
rigHeld(){ AgentsToolsScheduleStartHeld "$rigKey" && printf held || printf free ; }
rigCount(){ cat "$rigStore/$rigKey.fails" 2> /dev/null || printf none ; }

echo "-- 1. two failures in a row escalate nothing --"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "the count stands at 2" "$( rigCount )" "2"
rigAssert "nothing was escalated" "$rigEscalations" "0"
rigAssert "the key is not held" "$( rigHeld )" "free"

echo "-- 2. the third failure escalates once and holds the key --"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "one escalation" "$rigEscalations" "1"
rigAssert "with the key, the count and the failure's error line" "$( LC_ALL=C awk -F'\t' '{ print $1 "/" $2 "/" ( index( $3, "the brief file is missing" ) > 0 ? "why" : "nowhy" ) ; }' "$rigTmp/escalated" 2> /dev/null )" "$rigKey/3/why"
rigAssert "the key is held" "$( rigHeld )" "held"

echo "-- 3. a fourth failure escalates no second time --"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "still one escalation" "$rigEscalations" "1"
rigAssert "the count goes on" "$( rigCount )" "4"

echo "-- 4. a start the routine's own lock refused counts for nothing --"
rm -f "$rigStore/$rigKey.fails" "$rigStore/$rigKey.escalated"
AgentsToolsScheduleStartFailed "$rigKey" "⛔ ERROR: the routine is already running: its locking document is held by another session"
rigAssert "no count" "$( rigCount )" "none"
rigAssert "not held" "$( rigHeld )" "free"

echo "-- 4b. a lock no run holds is given back, and a lock a run holds is left --"
## THE RELEASE, replaced: the console's own release answers by its holder's records, and what it was asked for is kept in a file of this rig.
rigReleaseRc=0
AgentsToolsRoutineLockReleaseConsole(){ ## the routine-lock-document value, the reason
	printf '%s\n' "$1" > "$rigTmp/released"
	return "$rigReleaseRc"
}
rigLocked="⛔ ERROR: DistroAgentsTools: the routine is already running: its locking document note-x-state-and-lock.md (magic-coordinator) is held by session s1 of magic-coordinator (state work-duty-running)"
: > "$rigStore/$rigKey.hold" ; rm -f "$rigTmp/released"
rigReleaseRc=1
AgentsToolsScheduleStartFailed "$rigKey" "$rigLocked"
rigAssert "a holder with a record: the hold stands" "$( [ -e "$rigStore/$rigKey.hold" ] && printf held || printf free )" "held"
rigAssert "and the release was asked for the lock the refusal names" "$( cat "$rigTmp/released" 2> /dev/null )" "inbox:magic-coordinator:note-x-state-and-lock.md"
rigReleaseRc=0
AgentsToolsScheduleStartFailed "$rigKey" "$rigLocked"
rigAssert "a holder with no record: the hold is lifted, so the next pass starts it" "$( [ -e "$rigStore/$rigKey.hold" ] && printf held || printf free )" "free"
rigAssert "and the count is still none" "$( rigCount )" "none"

echo "-- 5. a success clears the count and the hold --"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "held before the success" "$( rigHeld )" "held"
rm -f "$rigStore/$rigKey.hold" "$rigStore/$rigKey.fails" "$rigStore/$rigKey.escalated" 2> /dev/null || :
rigAssert "free after it" "$( rigHeld )" "free"
rigAssert "and the count is gone" "$( rigCount )" "none"

echo "-- 6. a hold past its minutes is lifted with the count --"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
touch -t 202001010000 "$rigStore/$rigKey.escalated"
rigAssert "the key is free again" "$( rigHeld )" "free"
rigAssert "the count is gone with the hold" "$( rigCount )" "none"
rigAssert "a hold within its minutes stands" "$( MDAT_SCHEDULE_START_FAILS_HOLD_MINUTES=1 ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; rigHeld )" "held"

echo "-- 7. the hold is aged on the pass clock --"
rm -f "$rigStore/$rigKey.fails" "$rigStore/$rigKey.escalated"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigPassAt=1792404000
python3 -I -B -c 'import os, sys; e = int(sys.argv[1]); os.utime(sys.argv[2], (e, e))' "$rigPassAt" "$rigStore/$rigKey.escalated" || rigRefuse "the hold could not be dated at the pass instant"
rigAssert "dated at the pass instant, the key is held a minute of pass time later" "$( agentsSchedulePassNow=$(( rigPassAt + 60 )) ; rigHeld )" "held"
rigAssert "and still at 359 minutes of pass time" "$( agentsSchedulePassNow=$(( rigPassAt + 359 * 60 )) ; rigHeld )" "held"
rigAssert "control: past its 360 minutes of pass time it is free, the count gone with it" "$( agentsSchedulePassNow=$(( rigPassAt + 361 * 60 )) ; rigHeld ):$( rigCount )" "free:none"

echo "-- 8. a refused filing holds nothing, and the next failure files again --"
rm -f "$rigStore/$rigKey.fails" "$rigStore/$rigKey.escalated"
## THE FILING, answered by this rig: the status its caller has to read, and how many times it was attempted.
rigFilingRc=1
rigAttempts=0
AgentsToolsScheduleStartEscalate(){ ## key, failures in a row, the last failure's words
	rigAttempts=$(( rigAttempts + 1 ))
	return "$rigFilingRc"
}
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure" ; AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "a refused filing leaves the key unheld" "$( rigHeld )" "free"
rigAssert "and it was tried once" "$rigAttempts" "1"
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "the next failure files it again" "$rigAttempts" "2"
rigAssert "and the key is still unheld" "$( rigHeld )" "free"
rigFilingRc=0
AgentsToolsScheduleStartFailed "$rigKey" "$rigFailure"
rigAssert "control: a filing that lands holds the key" "$( rigHeld )" "held"

export MMDAPP="$rigReal"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE START FAILS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "SCHEDULE_START_FAILS: OK ($rigPassCount assertions, offline)"
