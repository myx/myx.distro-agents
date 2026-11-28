#!/usr/bin/env bash
## Behavioural check of the schedule ask's clock on the comms reader's pass (code-craft: no process per call; a caller's clock is used).
## AgentsToolsScheduleThreadAskDue in a rig, its "is the thread wanted" answer held at no, date counted wherever it is called:
##   1. a hundred asks given the caller's epoch start no date
##   2. and the first of them keeps that epoch as its moment
##   3. the ask is still once a minute: thirty seconds later it keeps its moment, sixty-one seconds later it takes the new one
##   4. control: an ask given no epoch still keeps the moment, from date
## Red before the change: each ask started date, a hundred for a hundred passes.
## Offline: a rig workspace of this check's own; no thread is asked for.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleAskDueClockCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigStamp="$rigTmp/ws/.local/agents/schedule-thread/ask-due.stamp"
mkdir -p "${rigStamp%/*}" || exit 1
rigForks="$rigTmp/forks"
rigShell(){ ## script: run with the schedule include loaded, the wanted answer held at no, date counted
	: > "$rigForks"
	env -u MDAT_SCHEDULE_THREAD MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigForks="$rigForks" bash -c '
		. "$rigPkg/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 1
		AgentsToolsScheduleThreadWantedInto(){ agentsScheduleThreadKeep=no ; return 0 ; }
		AgentsToolsScheduleThreadAsk(){ printf "ask\n" >> "$rigForks" ; return 0 ; }
		date(){ printf "date\n" >> "$rigForks" ; command date "$@" ; }
		'"$1" 2> /dev/null
}
rigNow="$( date +%s )"

echo "-- 1. a hundred asks given the caller's epoch: no date --"
rm -f "$rigStamp"
rigShell 'i=0 ; while [ $i -lt 100 ] ; do AgentsToolsScheduleThreadAskDue "" '"$rigNow"' ; i=$(( i + 1 )) ; done'
rigAssert "date started by a hundred asks" "$( LC_ALL=C grep -cx date "$rigForks" )" 0
rigAssert "no thread was asked for, as none is wanted" "$( LC_ALL=C grep -cx ask "$rigForks" )" 0

echo "-- 2. the first ask keeps the caller's epoch --"
rigAssert "the moment kept" "$( cat "$rigStamp" 2> /dev/null )" "$rigNow"

echo "-- 3. still once a minute --"
rigShell 'AgentsToolsScheduleThreadAskDue "" '"$(( rigNow + 30 ))"
rigAssert "thirty seconds later the moment stands" "$( cat "$rigStamp" 2> /dev/null )" "$rigNow"
rigShell 'AgentsToolsScheduleThreadAskDue "" '"$(( rigNow + 61 ))"
rigAssert "sixty-one seconds later it is the new one" "$( cat "$rigStamp" 2> /dev/null )" "$(( rigNow + 61 ))"

echo "-- 4. control: no epoch given, the moment comes from date --"
rm -f "$rigStamp"
rigShell 'AgentsToolsScheduleThreadAskDue'
rigGot="$( cat "$rigStamp" 2> /dev/null )"
rigAssert "a moment within five seconds of date's" "$( [ -n "$rigGot" ] && [ $(( $( date +%s ) - rigGot )) -le 5 ] && echo within || echo "got [$rigGot]" )" within

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SCHEDULE ASK DUE CLOCK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_ASK_DUE_CLOCK: OK (%d assertions, offline, rig workspace only)\n' "$rigPass"
