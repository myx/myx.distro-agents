#!/usr/bin/env bash
## Behavioural check on the comms cache's one-pull lock, and the wait a same-key miss takes on it (sketch "Comms/Cache/Wait
## summary": one pull per key, and same-key misses wait for that one pull). Held:
##   1. the first take holds the lock, the epoch it was taken at inside
##   2. a second take inside the pull's life is refused, and changes nothing
##   3. a lock a dead pull left is taken over
##   4. a miss waits for the pull that runs, and is served once it is given up
##   5. and it waits no longer than the dead pull's own life
##   6. control: with no lock it answers at once, so row 4's wait is a wait
## Offline: one mktemp tree, no network, nothing of the team's read.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCachePullLockCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCache="$rigTmp/cache/slack/slack-CRIG00001"
mkdir -p "$rigCache" || exit 1
. "$rigInclude"

echo "-- 1. the first take holds the lock, its epoch inside --"
rigNow="$( date +%s )"
AgentsToolsCommsCachePullTake "$rigCache" "$rigNow"
rigTakeRc=$?
rigAssert "the first take holds it" "$rigTakeRc" 0
rigAssert "and the lock holds the epoch it was taken at" "$( cat "$rigCache/.pulling.txt" 2> /dev/null )" "$rigNow"

echo "-- 2. a second take inside the pull's life is refused, and changes nothing --"
AgentsToolsCommsCachePullTake "$rigCache" "$(( rigNow + 5 ))"
rigTakeRc=$?
rigAssert "a second take is refused" "$rigTakeRc" 1
rigAssert "and the lock still holds the first take's epoch" "$( cat "$rigCache/.pulling.txt" 2> /dev/null )" "$rigNow"

echo "-- 3. a lock a dead pull left is taken over --"
printf '%s\n' "$(( rigNow - 61 ))" > "$rigCache/.pulling.txt"
AgentsToolsCommsCachePullTake "$rigCache" "$rigNow"
rigTakeRc=$?
rigAssert "a lock 61 s old is taken" "$rigTakeRc" 0
rigAssert "and the lock now holds this take's epoch" "$( cat "$rigCache/.pulling.txt" 2> /dev/null )" "$rigNow"
AgentsToolsCommsCachePullGive "$rigCache"
rigAssert "and giving it up leaves no lock" "$( [ -f "$rigCache/.pulling.txt" ] && echo held || echo free )" free

## The clock is read either side of the call alone. A background job waited for after the call would put its own delay inside
## the measurement, and a wait that never waited would read as one that did.
rigAwaitFor(){ ## bound -- sets rigAwaitRc and rigAwaitElapsed
	local awaitFrom awaitTo
	awaitFrom="$( date +%s )"
	AgentsToolsCommsCachePullAwait "$rigCache" "$1"
	rigAwaitRc=$?
	awaitTo="$( date +%s )"
	rigAwaitElapsed=$(( awaitTo - awaitFrom ))
}

echo "-- 4. a miss waits for the pull that runs, and is served once it is given up --"
AgentsToolsCommsCachePullTake "$rigCache" "$( date +%s )"
( sleep 3 ; AgentsToolsCommsCachePullGive "$rigCache" ) &
rigGiver=$!
rigAwaitFor 20
rigLockAtReturn="$( [ -f "$rigCache/.pulling.txt" ] && echo held || echo free )"
wait "$rigGiver"
rigAssert "the miss is served once the pull is given up" "$rigAwaitRc:$rigLockAtReturn" "0:free"
rigAssert "and it waited for that pull rather than answering at once" "$( [ "$rigAwaitElapsed" -ge 2 ] && echo waited || echo at-once )" waited

echo "-- 5. and it waits no longer than the dead pull's own life --"
## A pull taken 59 s ago is one second from the code's own 60: the wait is cut to that, whatever bound the caller gave.
printf '%s\n' "$(( $( date +%s ) - 59 ))" > "$rigCache/.pulling.txt"
rigAwaitFor 30
rigAssert "a pull 59 s old is waited for, and its life ends the wait" "$rigAwaitRc:$( [ "$rigAwaitElapsed" -le 5 ] && echo short || echo long )" "0:short"
rm -f "$rigCache/.pulling.txt"

echo "-- 6. control: with no lock it answers at once --"
rigAwaitFor 20
rigAssert "no lock is no wait" "$rigAwaitRc:$( [ "$rigAwaitElapsed" -eq 0 ] && echo at-once || echo waited )" "0:at-once"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
