#!/usr/bin/env bash
## Behavioural check on the Slack budget of the work-duty demand test (F7.5 of the refactorings epic, second gate; the coordinator's ruling: a
## source is read ONCE per its TTL, whatever the number of members, and every member's demand is derived from that one read; F4.2: no source is
## polled by many members). The real loop (--one) runs in a rig of the schedule (check-fixtures/rig-schedule-loop.include.sh) with 17 members
## eligible for a duty: 15 keepers, magic-coordinator and magic-librarian, none with anything in its inbox, so every demand test turns to the
## team channel, where a mention of a member lands. Held:
##   1. The first iteration of worktime reads the team channel once: ONE Slack read (`conversations.history`) for the 17, not 17.
##   2. An iteration 5 seconds later, inside the TTL of the source in AgentsToolsSourceTtlOf (15 s), makes no Slack read for them.
##   3. An iteration past the TTL reads it once again, and no more.
##   4. After worktime nobody is eligible: an iteration reads nothing for them.
##   5. A mention of one member in that one read gives that member, and no other, its duty; the next iteration starts no second.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleBudgetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
rigScheduleSetup 15
rigMon13=1792404000 ; rigMon18=1792422000

rigAt "$rigMon13"
rigOneRun a
rigAssert "17 members eligible at worktime: the team channel is read once, one Slack read for all" "$( rigCalls conversations.history )" "1"
rigHistoryA="$( rigCalls conversations.history )"
rigAt $(( rigMon13 + 5 ))
rigOneRun b
rigAssert "an iteration inside the TTL of the source (15 s) makes no Slack read for them" "$( rigCalls conversations.history )" "$rigHistoryA"
rigAt $(( rigMon13 + 40 ))
rigOneRun c
rigAssert "an iteration past the TTL reads it once again, and no more" "$(( $( rigCalls conversations.history ) - rigHistoryA ))" "1"
rigHistoryC="$( rigCalls conversations.history )"
rigAt "$rigMon18"
rigOneRun d
rigAssert "after worktime nobody is eligible: an iteration reads nothing for them" "$( rigCalls conversations.history )" "$rigHistoryC"
## A mention of keeper-rig-09 (its Slack id URIG09 in the rig) in the team channel, newer than the last read, and one of nobody.
rigTue13=$(( rigMon13 + 86400 ))
printf '{"ok":true,"messages":[{"type":"message","user":"U1","text":"<@URIG09> please look at this","ts":"%s.000100"},{"type":"message","user":"U2","text":"plain talk","ts":"%s.000200"}],"has_more":false}\n' "$(( rigTue13 - 5 ))" "$(( rigTue13 - 4 ))" > "$rigScn/history-body"
rigAt "$rigTue13" ; rigMentionCache
rigOneRun e ; rigWaitStarts
rigAssert "a mention of keeper-rig-09 gives it its duty, and no other member of the 17 is given one: one read, one start" "$(( $( rigCalls conversations.history ) - rigHistoryC )):$( rigDutyCount keeper-rig-09 ):$( rigSaid e 'work-duty: started the duty of' )" "1:1:1"
rigAt $(( rigTue13 + 40 ))
rigOneRun f ; rigWaitStarts
rigAssert "the next iteration past the TTL starts no second duty for that mention" "$( rigDutyCount keeper-rig-09 ):$( rigSaid f 'work-duty: started the duty of' )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE BUDGET CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_BUDGET: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
