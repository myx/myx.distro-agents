#!/usr/bin/env bash
## Behavioural check on the short-timeout read of a stale channel (sketch "Comms/Cache/Wait summary": stale-while-revalidate
## for short-timeout calls -- a Wait call with a zero or small timeout gets what is ready, and the refresh runs detached).
## The read operation here is SLOW, which is what separates the two paths: a call served stale returns at once and has paid no
## pull, and the same call without that mark waits the slow read. With an instant read both paths answer at once, and neither
## the elapsed time nor the pull count tells them apart.
## Held:
##   1. a stale folder is served as it stands by a call that marks itself short-timeout, at once and with no pull paid yet
##   2. and one pull of its own then runs, detached, and brings the channel up to date for the next read
##   3. control: the same call without that mark pays the slow pull, and is served the fresh messages
##   4. control: a folder inside its TTL is served as it stands, and no pull is started for it
## Each scene has a folder of its own, so a detached refresh of one scene never lands in another's.
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
## A detached refresh of one scene is waited for before the next, so it never writes into another scene's folder.
rigPullQuiet(){ ## bound in seconds
	local quietLeft="$1"
	while [ "$quietLeft" -gt 0 ] && [ -f "$rigCache/.pulling.txt" ] ; do
		sleep 1 ; quietLeft=$(( quietLeft - 1 ))
	done
	[ ! -f "$rigCache/.pulling.txt" ]
}

echo "-- 1. a stale folder is served as it stands by a short-timeout call, at once and with no pull paid yet --"
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

echo "-- 2. one pull of its own then runs, detached, and brings the channel up to date --"
## Its effect is read from the channel, waited for with a bound, never from the call's own answer.
rigWaited=0
while [ "$rigWaited" -lt 30 ] && ! LC_ALL=C grep -q 'RIG-FRESH' "$rigCache/$rigMonth/messages.txt" 2> /dev/null ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
rigAssert "the detached pull finished once" "$( rigPullsNow )" 1
rigAssert "and the channel now holds the fresh message" "$( LC_ALL=C grep -c 'RIG-FRESH' "$rigCache/$rigMonth/messages.txt" 2> /dev/null )" 1
rigAssert "and the refresh left no lock behind" "$( rigPullQuiet 30 && echo free || echo held )" free

echo "-- 3. control: the same call without that mark pays the slow pull --"
rigStale 600
rigFrom="$( date +%s )"
MDAT_SLACK_THREAD_CACHE_SECONDS=15 \
	AgentsToolsCommsCacheSlackThread "$rigMember" "$rigChannel:$rigThread" "$rigTmp/fresh.txt" true "$rigNow"
rigRc=$?
rigElapsed=$(( $( date +%s ) - rigFrom ))
rigAssert "the call is served" "$rigRc" 0
rigAssert "and it waited the slow read, where row 1 answered at once" "$( [ "$rigElapsed" -ge "$rigSlow" ] && echo paid || echo quick )" paid
rigAssert "reaching the read operation once, in the call itself" "$( rigPullsNow )" 1
rigAssert "and what it is served is the fresh read" "$( LC_ALL=C grep -c 'RIG-FRESH' "$rigTmp/fresh.txt" )" 1
rigPullQuiet 30 || :

echo "-- 4. control: a folder inside its TTL is served as it stands, and no pull is started --"
rigStale 1
MDAT_COMMS_CACHE_STALE_OK=true MDAT_SLACK_THREAD_CACHE_SECONDS=15 \
	AgentsToolsCommsCacheSlackThread "$rigMember" "$rigChannel:$rigThread" "$rigTmp/freshFolder.txt" true "$rigNow"
rigRc=$?
rigAssert "the fresh folder is served" "$rigRc" 0
rigAssert "with the message it holds" "$( LC_ALL=C grep -c 'RIG-STALE' "$rigTmp/freshFolder.txt" )" 1
rigAssert "and nothing is pulled for it" "$( rigPullsNow )" 0

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
