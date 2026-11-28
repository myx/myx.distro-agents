#!/usr/bin/env bash
## Behavioural check of the passive poll of a member's open asks reading as a live Wait reads. Every --read-pending-reply probes each
## of the caller's open asks (AgentsToolsPendingReplyPollOwn), and the manager console reads it on every refresh. A live Wait reads
## the comms cache alone while a comms thread is live, so that thread pulls and no probe calls Slack. Held:
##   1. with a comms thread live, every probe is made cache-only
##   2. with none, no probe is
##   3. each open ask of the member is probed, and only those
## Red before the change: the poll never said cache-only, so each probe pulled Slack itself however often the console asked.
## Offline: a rig workspace of this check alone; the probe and the liveness are the rig's own stand-ins, so nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPendingPollCacheOnlyCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/ws/.local/agents/pending" "$rigTmp/ws/.local/temp" || exit 1
for rigAsk in ask-one ask-two ; do printf -- '---\nstatus: reply-pending\nowner: magic-tester\n---\n' > "$rigTmp/ws/.local/agents/pending/$rigAsk.md" ; done
printf -- '---\nstatus: reply-pending\nowner: magic-architect\n---\n' > "$rigTmp/ws/.local/agents/pending/ask-other.md"
printf -- '---\nstatus: reply-received\nowner: magic-tester\n---\n' > "$rigTmp/ws/.local/agents/pending/ask-done.md"
rigPoll(){ ## live (0|1) -- prints `<ask>=<cache-only>` for each probe made
	MMDAPP="$rigTmp/ws" bash -c '. "$1/sh-lib/questions/AgentsTools.PendingReplyRecords.include" || exit 9
		. "$1/sh-lib/wait/AgentsTools.MemberWaitAsk.include" || exit 9
		. "$1/sh-lib/session/AgentsTools.SessionComms.include" || exit 9
		rigLive="$2" ; AgentsToolsSessionCommsLive(){ return "$rigLive" ; }
		AgentsWaitProbeAsk(){ printf "%s=%s\n" "$2" "${MDAT_COMMS_CACHE_ONLY:-unset}" >> "'"$rigTmp"'/probes" ; return 1 ; }
		AgentsToolsPendingReplyPollOwn magic-tester' rig "$rigPkg" "$1" > /dev/null 2>&1
	sort "$rigTmp/probes" 2> /dev/null | tr '\n' ' ' ; rm -f "$rigTmp/probes"
}

echo "-- 1. a comms thread live --"
rigAssert "the probes, each cache-only" "$( rigPoll 0 )" "ask-one=true ask-two=true "

echo "-- 2. none live --"
rigAssert "the probes, none cache-only" "$( rigPoll 1 )" "ask-one=false ask-two=false "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PENDING POLL CACHE ONLY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_POLL_CACHE_ONLY: OK (%d assertions, offline)\n' "$rigPass"
