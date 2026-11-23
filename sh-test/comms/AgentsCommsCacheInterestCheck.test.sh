#!/usr/bin/env bash
## Behavioural check on the interest mark's write rate (sketch "RE: comms cache": on a cache hit, touch the interest flag
## only if it is older than 1 h; "Comms/Cache/Wait summary": interest marks touched at most once an hour, so writes drop from
## every 15 s to hourly). The mark's ages -- the 48-hour refresh stop and the 240-hour delete -- are the cleanup check's.
## Held:
##   1. a read nineteen minutes after the mark leaves it as it stands
##   2. a read sixty-one minutes after the mark rewrites it, with the reading TTL
##   3. control: a reader whose TTL is shorter than the mark's rewrites it at once, so a fast reader is not held to the hour
##   4. the rig's own puller keeps no mark at all, so the sweep never marks a channel by reading it
## Each row runs in a process of its own, because the function keeps one hour's answers in the process that made them.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheInterestCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The rig's own workspace: the mark and the entry are both under it, and nothing of the caller's is read or written.
rigWs="$rigTmp/ws"
rigEntryName="slack-CRIG00001"
rigDir="$rigWs/.local/cache/comms/slack/$rigEntryName"
rigMark="$rigWs/.local/cache/comms/.interest/$rigEntryName"
mkdir -p "$rigDir" "$rigWs/.local/cache/comms/.interest" "$rigWs/.local/temp" || exit 1
rigNow="$( date +%s )"

## One read of the channel, in a process of its own, with the given TTL. The caller's environment is cleared but for what
## the cache needs, so the process's own memory of the hour starts empty every time.
rigRead(){ ## TTL
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsCommsCacheInterest "$2" "$3" "$4"' _ \
		"$rigInclude" "$rigDir" "$rigNow" "$1"
}
rigMarkWorth(){ cat "$rigMark" 2> /dev/null ; }

echo "-- 1. a read nineteen minutes after the mark leaves it as it stands --"
printf '%s 15\n' "$(( rigNow - 1140 ))" > "$rigMark"
rigBefore="$( rigMarkWorth )"
rigRead 15
rigAssert "the mark is exactly as it was" "$( rigMarkWorth )" "$rigBefore"

echo "-- 2. a read sixty-one minutes after the mark rewrites it --"
printf '%s 15\n' "$(( rigNow - 3660 ))" > "$rigMark"
rigRead 15
rigAssert "the mark now holds this read's moment and TTL" "$( rigMarkWorth )" "$rigNow 15"

echo "-- 3. control: a reader whose TTL is shorter than the mark's rewrites it at once --"
## Nineteen minutes is inside the hour, so only the TTL's own difference can move the mark here.
printf '%s 15\n' "$(( rigNow - 1140 ))" > "$rigMark"
rigRead 3
rigAssert "the mark takes the shorter TTL, under the hour" "$( rigMarkWorth )" "$rigNow 3"
## And the plain case the exception does not cover: a longer TTL under the hour changes nothing.
printf '%s 3\n' "$(( rigNow - 1140 ))" > "$rigMark"
rigBefore="$( rigMarkWorth )"
rigRead 15
rigAssert "control: a longer TTL under the hour still leaves it" "$( rigMarkWorth )" "$rigBefore"

echo "-- 4. the rig's own puller keeps no mark at all --"
rm -f "$rigMark"
env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_COMMS_CACHE_PULLER=true \
	bash -c '. "$1" ; AgentsToolsCommsCacheInterest "$2" "$3" 15' _ "$rigInclude" "$rigDir" "$rigNow"
rigAssert "the puller's own read writes no mark" "$( [ -f "$rigMark" ] && echo written || echo none )" none

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
