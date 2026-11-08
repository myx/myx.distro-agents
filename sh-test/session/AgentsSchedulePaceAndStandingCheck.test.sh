#!/usr/bin/env bash
## Behavioural check on three small rules of the schedule (AgentsTools.DispatcherSchedule.include), run rather than read, in a workspace built here.
## THE PACE (`AgentsToolsSchedulePaceText`): the median tool call, in milliseconds, of the calls the live runs wrote into their `context.jsonl` in the last
## window, against a limit; under it a duty start is allowed and at or over it, held; fewer than three calls is too few to judge, and no calls at all is no
## reason to hold. The limit is the caller's, as the 5 s throttle reads it. WHO HOLDS A DUTY (`AgentsToolsScheduleStanding`): a magic or keeper member, never the
## team, a partner, a warden, a client or a record of a person. THE MEMBER FLAG KEY (`AgentsToolsScheduleMemberKey`): the flag and the member, upper-cased,
## with the hyphens as underscores. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSchedulePaceAndStandingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/spawned"
export MMDAPP="$rigWs" MDSC_CMD=check
set +u
. "$rigHere/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
set -u
type AgentsToolsSchedulePaceText > /dev/null 2>&1 || rigRefuse "the schedule's functions are not defined by sourcing them"

rigCalls(){ ## spawn id, durations (ms)... -- a run's context.jsonl with one call line for each
	local runId="$1" runDur
	shift
	mkdir -p "$rigWs/.local/agents/spawned/$runId"
	: > "$rigWs/.local/agents/spawned/$runId/context.jsonl"
	for runDur in "$@" ; do printf '{"kind":"tool","tool":"Bash","dur_ms":%s}\n' "$runDur" >> "$rigWs/.local/agents/spawned/$runId/context.jsonl" ; done
}
rigPace(){ ## [limit ms] -- the pace line
	if [ -n "${1:-}" ] ; then MDAT_TOOL_PACE_MS="$1" AgentsToolsSchedulePaceText ; else unset MDAT_TOOL_PACE_MS ; AgentsToolsSchedulePaceText ; fi
}

## The measure is kept for MDAT_TOOL_PACE_CACHE_SECONDS in the product, and these rows read it fresh each time; the cache has its own rows below.
export MDAT_TOOL_PACE_CACHE_SECONDS=0
echo "-- the pace --"
rigAssert "no run wrote a call: no measure, and no measure is no reason to hold" "$( rigPace )" "pace: 0 of 0 calls in 30 minutes -- too few to judge, a duty start is allowed"
rigCalls r1 1000 2000
rigAssert "two calls are too few to judge: a duty start is allowed" "$( rigPace | grep -c 'too few to judge, a duty start is allowed' )" "1"
rigCalls r1 1000 2000 3000 8000 9000
rigAssert "five calls, 1 2 3 8 9 s: the median is 3 s, under the 7 s limit, a start is allowed" "$( rigPace )" "pace: 3000 of 5 calls in 30 minutes -- under 7000, a duty start is allowed"
rigAssert "the same median against a limit of 2 s is over it: a start is held" "$( rigPace 2000 )" "pace: 3000 of 5 calls in 30 minutes -- over 2000, a duty start is held"
rigAssert "a median equal to the limit is held, as the rule says at or over" "$( rigPace 3000 | grep -c 'a duty start is held' )" "1"
rigCalls r1 7000 8000 9000
rigAssert "a median of 8 s is over the 7 s gate: held" "$( rigPace | grep -c -- '-- over 7000, a duty start is held' )" "1"
rigCalls r2 9000 9000 9000
rigAssert "the calls of every run count, two runs together: six calls" "$( rigPace | sed 's/.* of \([0-9]*\) calls.*/\1/' )" "6"
rigAssert "AgentsToolsSchedulePaceAllows is true under the limit and false over it" "$( rigCalls r1 1000 1000 1000 ; rm -rf "$rigWs/.local/agents/spawned/r2" ; AgentsToolsSchedulePaceAllows && echo yes || echo no ):$( rigCalls r1 9000 9000 9000 ; AgentsToolsSchedulePaceAllows && echo yes || echo no )" "yes:no"

echo "-- the measure is kept, not walked for on every call --"
rm -rf "$rigWs/.local/agents/spawned/r1" "$rigWs/.local/agents/spawned/r2" "$rigWs/.local/agents/schedule/pace.measure"
rigCalls r1 1000 2000 3000 8000 9000
rigKept1="$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText )"
rigCalls r1 9000 9000 9000 9000 9000 9000 9000 9000
rigKept2="$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText )"
rigAssert "the first call takes the measure: five calls, a median of 3 s" "$rigKept1" "pace: 3000 of 5 calls in 30 minutes -- under 7000, a duty start is allowed"
rigAssert "a call within the TTL reads the kept measure and not the new calls" "$rigKept2" "$rigKept1"
rigAssert "the kept measure is a file of one line, the epoch, the window, the median and the count" "$( LC_ALL=C awk 'END { print NR ":" NF }' "$rigWs/.local/agents/schedule/pace.measure" )" "1:4"
rigAssert "a TTL of 0 takes the measure again and sees the new calls" "$( MDAT_TOOL_PACE_CACHE_SECONDS=0 AgentsToolsSchedulePaceText | sed 's/.* of \([0-9]*\) calls.*/\1/' )" "8"
rm -f "$rigWs/.local/agents/schedule/pace.measure"
rigAssert "with the kept file gone, the next call takes the measure at once" "$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText | sed 's/.* of \([0-9]*\) calls.*/\1/' )" "8"
rm -rf "$rigWs/.local/agents/spawned/r1" "$rigWs/.local/agents/schedule/pace.measure"

echo "-- who holds a duty --"
AgentsToolsTeamMemberReferenceOnly(){ return 1 ; }
for rigMember in magic-developer magic-coordinator keeper-myx keeper-ndm ; do
	rigAssert "$rigMember holds a duty" "$( AgentsToolsScheduleStanding "$rigMember" /some/dir && echo yes || echo no )" "yes"
done
for rigMember in partner-ndm-ndxs partner-ndm-camunda warden-x client-ndm magic-team human-owner ; do
	rigAssert "$rigMember holds none" "$( AgentsToolsScheduleStanding "$rigMember" /some/dir && echo yes || echo no )" "no"
done
AgentsToolsTeamMemberReferenceOnly(){ return 0 ; }
rigAssert "a member whose skill says reference-only holds none either" "$( AgentsToolsScheduleStanding magic-developer /some/dir && echo yes || echo no )" "no"

echo "-- the member flag key --"
rigAssert "vacation of client-ndm" "$( AgentsToolsScheduleMemberKey vacation client-ndm )" "MDAT_SCHEDULE_VACATION_CLIENT_NDM"
rigAssert "overtime of magic-developer" "$( AgentsToolsScheduleMemberKey overtime magic-developer )" "MDAT_SCHEDULE_OVERTIME_MAGIC_DEVELOPER"
rigAssert "a member's flag reads nothing where none is set" "$( AgentsToolsScheduleMemberFlag vacation client-ndm 1800000000 )" ""

export MMDAPP="$rigReal"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ SCHEDULE PACE AND STANDING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "SCHEDULE_PACE_AND_STANDING: OK ($rigPasses assertions, offline)"
