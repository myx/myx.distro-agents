#!/usr/bin/env bash
## Behavioural check of the pace measure's one writer (epic ruling: the pace measure is never computed on a call path; one
## writer on a tick keeps it, and every reader reads the kept value). AgentsToolsSchedulePaceText run in a rig of its own:
##   1. a reader (no schedule pass) leaves a stale kept measure byte for byte, and reports its median
##   2. a reader with no kept measure writes none, and says it was not read
##   3. control, the other direction: the schedule pass (agentsSchedulePassNow set) does refresh the same stale measure
## Red before the change: a reader past the measure's TTL computes it again and rewrites the file.
## Offline: a rig workspace of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSchedulePaceReaderKeptCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
rigKept="$rigWs/.local/agents/schedule/pace.measure"
mkdir -p "${rigKept%/*}" || exit 1
rigStale="$(( $( date +%s ) - 1000 )) 300 7000 50"
rigPace(){ ## NAME=value pairs: the line AgentsToolsSchedulePaceText prints in the rig
	env "$@" bash -c '. "$1/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" || exit 1 ; MMDAPP="$2" ; AgentsToolsSchedulePaceText' rig "$rigPkg" "$rigWs" 2> /dev/null
}

echo "-- 1. a reader reads the kept measure, whatever its age --"
printf '%s\n' "$rigStale" > "$rigKept"
rigLine="$( rigPace )"
rigAssert "a reader leaves a stale kept measure as it was" "$( cat "$rigKept" )" "$rigStale"
case "$rigLine" in *'7.0s machinery a call, 50 calls'*) rigGot=kept ;; *) rigGot="other: $rigLine" ;; esac
rigAssert "and reports the kept median and calls" "$rigGot" kept

echo "-- 2. a reader with no kept measure writes none --"
rm -f "$rigKept"
rigLine="$( rigPace )"
rigAssert "no kept measure is written by a reader" "$( [ -e "$rigKept" ] && echo written || echo none )" none
rigAssert "and the line says it was not read" "$rigLine" "pace: not read -- a duty start is allowed"

echo "-- 3. control: the schedule pass is the writer --"
printf '%s\n' "$rigStale" > "$rigKept"
rigPace agentsSchedulePassNow="$( date +%s )" > /dev/null
rigAssert "the pass refreshes the same stale measure" "$( [ "$( cat "$rigKept" )" = "$rigStale" ] && echo kept || echo refreshed )" refreshed

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SCHEDULE PACE READER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_PACE_READER: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
