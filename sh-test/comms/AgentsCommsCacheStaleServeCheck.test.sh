#!/usr/bin/env bash
## Behavioural check on the short-timeout read of a stale channel (sketch "Comms/Cache/Wait summary": stale-while-revalidate
## for short-timeout calls -- a Wait call with a zero or small timeout gets what is ready). Epic `## Decisions` line 95 keeps
## ruling 14: a reader never starts a refresh, and only the comms thread fills an entry. So a served-stale call answers from what
## the cache holds and starts no pull of its own; the rows about a detached refresh that followed it went with that branch.
## Held:
##   1. a stale folder is served as it stands by a call that marks itself short-timeout, at once and with no pull paid
##   2. control: a folder inside its TTL is served as it stands, and no pull is started for it
## Each scene has a folder of its own, so nothing of one scene lands in another's.
## Offline: the read operation and the rendering are stubbed by this file, so nothing leaves the machine.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheStaleServeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigMember="rig-member"
rigChannel="CRIG00001"
rigThread="1793000000.000100"
rigMonth="202610"
rigPulls="$rigTmp/pulls"
rigSlow=3

## The read operation, stubbed: it counts the pull it is, after a slow read of that many seconds. The cache loads the real tool
## only where this name is not already a function, so the stub is what a pull reaches.
DistroAgentsTools(){ ## the read operation's stand-in
	sleep "$rigSlow"
	printf 'pull\n' >> "$rigPulls"
	return 0
}
## The rendering, stubbed the same way: one fresh message, in the form the merge reads.
AgentsToolsSlackFormatPagedConversation(){ ## member, the read's text
	printf '%s | RIG-FRESH\n' "1793000900.000100"
}

. "$rigInclude"

rigNow="$( date +%s )"
## The channel's folder, spelled by the cache's own function, never by hand.
AgentsToolsCommsCacheSlackDir "$rigMember" true "$rigChannel" "$rigThread"
rigCache="$agentsCommsCacheDir"
[ -n "$rigCache" ] || { echo "⛔ ERROR: the cache resolves no folder for $rigChannel" >&2 ; exit 1 ; }

## One channel with pointers whose pull moment is the given age, holding one message.
rigStale(){ ## how old the pull moment is, in seconds
	rm -rf "$rigCache" ; mkdir -p "$rigCache/$rigMonth" || exit 1
	printf '%s 1793000000 1793000000.000100\n## target=%s\nslack-thread %s:%s %s true\n' \
		"$(( rigNow - $1 ))" "$rigChannel" "$rigChannel" "$rigThread" "$rigMember" > "$rigCache/.state.txt"
	printf '%s | RIG-STALE\n' "1793000000.000100" > "$rigCache/$rigMonth/messages.txt"
	: > "$rigPulls"
}
rigPullsNow(){ LC_ALL=C wc -l < "$rigPulls" 2> /dev/null | LC_ALL=C tr -d ' ' ; }

echo "-- 1. a stale folder is served as it stands by a short-timeout call, at once and with no pull paid at all --"
rigStale 600
rigFrom="$( date +%s )"
MDAT_COMMS_CACHE_STALE_OK=true MDAT_SLACK_THREAD_CACHE_SECONDS=15 \
	AgentsToolsCommsCacheSlackThread "$rigMember" "$rigChannel:$rigThread" "$rigTmp/stale.txt" true "$rigNow"
rigRc=$?
rigElapsed=$(( $( date +%s ) - rigFrom ))
rigPullsAtReturn="$( rigPullsNow )"
rigAssert "the call is served" "$rigRc" 0
rigAssert "with the message the cache already held" "$( LC_ALL=C grep -c 'RIG-STALE' "$rigTmp/stale.txt" )" 1
rigAssert "and it answered before the slow read could have finished" "$( [ "$rigElapsed" -lt "$rigSlow" ] && echo quick || echo slow )" quick
rigAssert "and no pull had finished by then, so the answer was the cache's own" "$rigPullsAtReturn" 0
## A reader starts no refresh (epic `## Decisions` line 95, ruling 14): the pull the old branch started detached is looked for
## after a window longer than the slow read, so a refresh that began and has not yet finished is caught too.
sleep $(( rigSlow + 2 ))
rigAssert "and no pull starts afterwards either, the comms thread being what fills an entry" "$( rigPullsNow )" 0

echo "-- 2. control: a folder inside its TTL is served as it stands, and no pull is started for it --"
rigStale 1
MDAT_COMMS_CACHE_STALE_OK=true MDAT_SLACK_THREAD_CACHE_SECONDS=15 \
	AgentsToolsCommsCacheSlackThread "$rigMember" "$rigChannel:$rigThread" "$rigTmp/freshFolder.txt" true "$rigNow"
rigRc=$?
rigAssert "the fresh folder is served" "$rigRc" 0
rigAssert "with the message it holds" "$( LC_ALL=C grep -c 'RIG-STALE' "$rigTmp/freshFolder.txt" )" 1
sleep $(( rigSlow + 1 ))
rigAssert "and nothing is pulled for it" "$( rigPullsNow )" 0

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
