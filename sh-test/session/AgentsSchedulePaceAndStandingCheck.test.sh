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

## THE RECORDS ARE THE HARNESS'S: each call line carries the record's own clock (`ms`), the call's whole time (`dur_ms`, written here as
## ten times the machinery so a reading of it would show) and the machinery time (`mach_ms`), which is what the pace reads. The run's
## spawn record says spawn-started: a live run. rigCallsEnded writes a run that ended, and rigCallsOld a call older than the window.
rigCalls(){ ## spawn id, machinery times (ms)... -- a live run's context.jsonl with one call line for each
	local runId="$1" runDur runNow
	shift
	runNow="$(( $( date +%s ) * 1000 ))"
	mkdir -p "$rigWs/.local/agents/spawned/$runId"
	[ -f "$rigWs/.local/agents/spawned/$runId/$runId.spawn.md" ] || printf 'status: spawn-started\n' > "$rigWs/.local/agents/spawned/$runId/$runId.spawn.md"
	: > "$rigWs/.local/agents/spawned/$runId/context.jsonl"
	for runDur in "$@" ; do printf '{"kind":"tool","tool":"Bash","ms":%s,"dur_ms":%s,"mach_ms":%s}\n' "$runNow" "$(( runDur * 10 ))" "$runDur" >> "$rigWs/.local/agents/spawned/$runId/context.jsonl" ; done
}
rigCallsEnded(){ ## spawn id, machinery times (ms)... -- the same, of a run whose record says it ended
	rigCalls "$@"
	printf 'status: spawn-ended-without-close\n' > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigCallsOld(){ ## spawn id, machinery times (ms)... -- the same, of calls made ten minutes ago, outside the five-minute window
	local oldId="$1" oldDur oldThen
	shift
	oldThen="$(( ( $( date +%s ) - 600 ) * 1000 ))"
	mkdir -p "$rigWs/.local/agents/spawned/$oldId"
	printf 'status: spawn-started\n' > "$rigWs/.local/agents/spawned/$oldId/$oldId.spawn.md"
	: > "$rigWs/.local/agents/spawned/$oldId/context.jsonl"
	for oldDur in "$@" ; do printf '{"kind":"tool","tool":"Bash","ms":%s,"dur_ms":%s,"mach_ms":%s}\n' "$oldThen" "$(( oldDur * 10 ))" "$oldDur" >> "$rigWs/.local/agents/spawned/$oldId/context.jsonl" ; done
}
rigPace(){ ## [limit ms] -- the pace line
	if [ -n "${1:-}" ] ; then MDAT_TOOL_PACE_MS="$1" AgentsToolsSchedulePaceText ; else unset MDAT_TOOL_PACE_MS ; AgentsToolsSchedulePaceText ; fi
}

## The measure is kept for MDAT_TOOL_PACE_CACHE_SECONDS in the product, and these rows read it fresh each time; the cache has its own rows below.
export MDAT_TOOL_PACE_CACHE_SECONDS=0
echo "-- the pace --"
rigAssert "no run wrote a call: no live run, and that is no reason to hold the one start a pass" "$( rigPace )" "pace: no live run made a call in 5 minutes -- a duty start is allowed, one a pass"
rigCalls r1 1000 2000
rigAssert "two calls are too few to judge: a duty start is allowed" "$( rigPace | grep -c 'too few to judge, a duty start is allowed' )" "1"
rigCalls r1 1000 2000 3000 8000 9000
rigAssert "five calls, 1 2 3 8 9 s of machinery: the median is 3 s, under the 4 s limit, a start is allowed; dur_ms, ten times it, is not what is read" "$( rigPace )" "pace: 3.0s machinery a call, 5 calls in 5 minutes -- under 4s, a duty start is allowed"
rigAssert "the same median against a limit of 2 s is over it: a start is held" "$( rigPace 2000 )" "pace: 3.0s machinery a call, 5 calls in 5 minutes -- over 2s, a duty start is held"
rigCallsEnded r9 9000 9000 9000
rigAssert "a run that ended does not count, however fresh its file: still 5 calls" "$( rigPace | sed 's/.*, \([0-9]*\) calls.*/\1/' )" "5"
rigCallsOld r8 9000 9000 9000
rigAssert "calls older than the window do not count, whatever their file's age: still 5 calls" "$( rigPace | sed 's/.*, \([0-9]*\) calls.*/\1/' )" "5"
rm -rf "$rigWs/.local/agents/spawned/r9" "$rigWs/.local/agents/spawned/r8"
rigAssert "a median equal to the limit is held, as the rule says at or over" "$( rigPace 3000 | grep -c 'a duty start is held' )" "1"
rigCalls r1 7000 8000 9000
rigAssert "a median of 8 s is over the 4 s gate: held" "$( rigPace | grep -c -- '-- over 4s, a duty start is held' )" "1"
rigCalls r2 9000 9000 9000
rigAssert "the calls of every live run count, two runs together: six calls" "$( rigPace | sed 's/.*, \([0-9]*\) calls.*/\1/' )" "6"
rigAssert "AgentsToolsSchedulePaceAllows is true under the limit and false over it" "$( rigCalls r1 1000 1000 1000 ; rm -rf "$rigWs/.local/agents/spawned/r2" ; AgentsToolsSchedulePaceAllows && echo yes || echo no ):$( rigCalls r1 9000 9000 9000 ; AgentsToolsSchedulePaceAllows && echo yes || echo no )" "yes:no"

echo "-- the measure is kept, not walked for on every call --"
rm -rf "$rigWs/.local/agents/spawned/r1" "$rigWs/.local/agents/spawned/r2" "$rigWs/.local/agents/schedule/pace.measure"
rigCalls r1 1000 2000 3000 8000 9000
rigKept1="$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText )"
rigCalls r1 9000 9000 9000 9000 9000 9000 9000 9000
rigKept2="$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText )"
rigAssert "the first call takes the measure: five calls, a median of 3 s" "$rigKept1" "pace: 3.0s machinery a call, 5 calls in 5 minutes -- under 4s, a duty start is allowed"
rigAssert "a call within the TTL reads the kept measure and not the new calls" "$rigKept2" "$rigKept1"
rigAssert "the kept measure is a file of one line, the epoch, the window, the median and the count" "$( LC_ALL=C awk 'END { print NR ":" NF }' "$rigWs/.local/agents/schedule/pace.measure" )" "1:4"
rigAssert "a TTL of 0 takes the measure again and sees the new calls" "$( MDAT_TOOL_PACE_CACHE_SECONDS=0 AgentsToolsSchedulePaceText | sed 's/.*, \([0-9]*\) calls.*/\1/' )" "8"
rm -f "$rigWs/.local/agents/schedule/pace.measure"
rigAssert "with the kept file gone, the next call takes the measure at once" "$( MDAT_TOOL_PACE_CACHE_SECONDS=60 AgentsToolsSchedulePaceText | sed 's/.*, \([0-9]*\) calls.*/\1/' )" "8"
rm -rf "$rigWs/.local/agents/spawned/r1" "$rigWs/.local/agents/schedule/pace.measure"

echo "-- who holds a duty --"
AgentsToolsTeamMemberReferenceOnly(){ return 1 ; }
## A member's directory holds its armed skill, `<member>.armed.md`, once the member is set up. A directory without one is a member
## the grants made a directory for and nobody set up, and the spawn refuses it, so the schedule starts no duty for it.
rigMembers="$rigTmp/members"
for rigMember in magic-developer magic-coordinator keeper-myx keeper-ndm partner-ndm-ndxs partner-ndm-camunda warden-x client-ndm magic-team human-owner ; do
	mkdir -p "$rigMembers/$rigMember" && : > "$rigMembers/$rigMember/$rigMember.armed.md"
done
for rigMember in magic-developer magic-coordinator keeper-myx keeper-ndm ; do
	rigAssert "$rigMember holds a duty" "$( AgentsToolsScheduleStanding "$rigMember" "$rigMembers/$rigMember" && echo yes || echo no )" "yes"
done
for rigMember in partner-ndm-ndxs partner-ndm-camunda warden-x client-ndm magic-team human-owner ; do
	rigAssert "$rigMember holds none" "$( AgentsToolsScheduleStanding "$rigMember" "$rigMembers/$rigMember" && echo yes || echo no )" "no"
done
mkdir -p "$rigMembers/keeper-orch"
printf '# keeper-orch\n\nAuto-created access-grant directory. Standing, not scratch.\n' > "$rigMembers/keeper-orch/MAGIC.md"
rigAssert "a keeper directory with no armed skill, one the grants made, holds none" "$( AgentsToolsScheduleStanding keeper-orch "$rigMembers/keeper-orch" && echo yes || echo no )" "no"
rigAssert "a keeper named in no directory at all holds none" "$( AgentsToolsScheduleStanding keeper-orch "$rigMembers/absent" && echo yes || echo no )" "no"
AgentsToolsTeamMemberReferenceOnly(){ return 0 ; }
rigAssert "a member whose skill says reference-only holds none either" "$( AgentsToolsScheduleStanding magic-developer "$rigMembers/magic-developer" && echo yes || echo no )" "no"

echo "-- the member flag key --"
rigAssert "vacation of client-ndm" "$( AgentsToolsScheduleMemberKey vacation client-ndm )" "MDAT_SCHEDULE_VACATION_CLIENT_NDM"
rigAssert "overtime of magic-developer" "$( AgentsToolsScheduleMemberKey overtime magic-developer )" "MDAT_SCHEDULE_OVERTIME_MAGIC_DEVELOPER"
rigAssert "a member's flag reads nothing where none is set" "$( AgentsToolsScheduleMemberFlag vacation client-ndm 1800000000 )" ""

export MMDAPP="$rigReal"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ SCHEDULE PACE AND STANDING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "SCHEDULE_PACE_AND_STANDING: OK ($rigPasses assertions, offline)"
