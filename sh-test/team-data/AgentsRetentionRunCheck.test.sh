#!/usr/bin/env bash
## Behavioural check on the hourly retention the main loop runs (T5, AgentsToolsRetentionRun in sh-lib/team-data/AgentsTools.Retention.include).
## Held, with a stand-in DistroAgentsTools that logs what it is asked:
##   1. THE FIRST CALL runs the reflection sweep and then the final GC, each as magic-coordinator in the main loop's context, and stamps the time
##   2. A CALL INSIDE THE HOUR runs nothing and says nothing
##   3. A CALL AFTER THE HOUR (the stamp aged) runs both again
##   4. A STEP THAT FAILS is a line, the other step still runs, the call returns 0; rc 2 (nothing done) is no failure
##   5. A STAMP THAT IS NOT AN EPOCH counts as never run
## Offline: no tree but this check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/team-data/AgentsTools.Retention.include" ] || rigRefuse "the retention include is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRetentionRunCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws"
export MMDAPP="$rigTmp/ws"
rigCalls="$rigTmp/calls.log"
rigSweepRc=0 rigGcRc=2
## The stand-in: logs the operation and what follows it, answers a line, returns what the check set.
DistroAgentsTools(){
	printf '%s\n' "$*" >> "$rigCalls"
	case "$1" in
		--intern-team-data-reflection-sweep) printf 'reflection-sweep: swept 3 of 9\n' ; return "$rigSweepRc" ;;
		--intern-team-data-final-gc-deletion) printf 'final-gc: nothing to delete\n' ; return "$rigGcRc" ;;
	esac
	return 1
}
. "$rigPackage/sh-lib/team-data/AgentsTools.Retention.include" || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigStamp="$MMDAPP/.local/agents/retention.stamp"
rigRun(){ ## the output of one call, its status in rigRc
	: > "$rigCalls" 2> /dev/null || :
	rigRc=0
	rigOut="$( AgentsToolsRetentionRun )" || rigRc=$?
}

echo "-- 1. the first call --"
rigRun
rigAssert "sweep then GC, as the coordinator in the loop's context" "$( tr '\n' '|' < "$rigCalls" )" "--intern-team-data-reflection-sweep magic-coordinator --context --intern-main-loop|--intern-team-data-final-gc-deletion magic-coordinator --context --intern-main-loop|"
rigAssert "a line for each, the last line of its answer; returns 0" "$rigRc:$( printf '%s' "$rigOut" | tr '\n' '|' )" "0:reflection-sweep: swept 3 of 9|final-gc: nothing to delete"
rigAssert "the time is stamped, an epoch" "$( LC_ALL=C grep -c -E '^[0-9]+$' "$rigStamp" )" "1"

echo "-- 2. inside the hour --"
rigRun
rigAssert "nothing runs, nothing is said, 0" "$( wc -l < "$rigCalls" | tr -d ' ' ):$rigOut:$rigRc" "0::0"

echo "-- 3. after the hour --"
printf '%s\n' "$(( $( date +%s ) - 3700 ))" > "$rigStamp"
rigRun
rigAssert "both run again" "$( wc -l < "$rigCalls" | tr -d ' ' ):$rigRc" "2:0"
MDAT_RETENTION_INTERVAL=5 ; export MDAT_RETENTION_INTERVAL
printf '%s\n' "$(( $( date +%s ) - 10 ))" > "$rigStamp"
rigRun
rigAssert "MDAT_RETENTION_INTERVAL sets the hour" "$( wc -l < "$rigCalls" | tr -d ' ' )" "2"
unset MDAT_RETENTION_INTERVAL

echo "-- 4. a failing step --"
printf '%s\n' "$(( $( date +%s ) - 3700 ))" > "$rigStamp"
rigSweepRc=1
rigRun
rigAssert "the failure is a line, the GC still ran, returns 0" "$rigRc:$( wc -l < "$rigCalls" | tr -d ' ' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c '^retention: the reflection sweep failed (rc 1)$' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c '^final-gc: ' )" "0:2:1:1"
rigSweepRc=2 rigGcRc=1
printf '%s\n' "$(( $( date +%s ) - 3700 ))" > "$rigStamp"
rigRun
rigAssert "rc 2 is nothing done and no failure; a failed GC is a line" "$rigRc:$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'sweep failed' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c '^retention: the final GC failed (rc 1)$' )" "0:0:1"
rigGcRc=0

echo "-- 5. a stamp that is no epoch --"
printf 'garbage\n' > "$rigStamp"
rigRun
rigAssert "counts as never run" "$( wc -l < "$rigCalls" | tr -d ' ' )" "2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ RETENTION RUN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'RETENTION_RUN: OK (%d assertions, offline)\n' "$rigPassCount"
