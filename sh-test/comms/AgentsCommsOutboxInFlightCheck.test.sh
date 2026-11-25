#!/usr/bin/env bash
## Behavioural check on S10.31: a record a send appends while a channel's outbox file is already being posted is not left behind
## that file's backlog. It is folded into the file in flight and the file merged again, so the coalesce lifts a message ahead of the
## tracking posts it would have waited behind, and the records already sent keep the head where the pointer names them.
## Held:
##   1. a pass posts its share and leaves the file in flight, with the pointer on what it posted
##   2. an ask appended while that file is in flight is posted on the next pass, and as that pass's first message
##   3. the posts already sent are not posted again, and no box of the backlog is lost or posted twice
##   4. the outbox drains to nothing
##   5. the control: with no backlog the ask is the only post there is
## Offline: one mktemp tree, the post stubbed by this file, no network, nothing of the team's read.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsOutboxInFlightCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCache="$rigTmp/cache/slack/slack-CRIG"
rigWs="$rigTmp/ws"
mkdir -p "$rigCache" "$rigWs/.local/temp" || exit 1

. "$rigInclude"

## Every call from here is the rig workspace's, never the one the check was started in.
MMDAPP="$rigWs"

## The post the pusher makes, stubbed: one entry a message, `ASK` or `TRACKING`, and the boxes that message carried.
rigLog="" rigTrackBoxes=0 rigAskPosts=0
AgentsToolsSessionCommsPost(){ ## session, the retry file
	local postBoxes
	postBoxes="$( LC_ALL=C grep -o '"type":"container"' "$2" | LC_ALL=C grep -c . || : )"
	if [ "$( LC_ALL=C grep -c '"tracking":"activity"' "$2" || : )" -gt 0 ] ; then
		rigTrackBoxes=$(( rigTrackBoxes + postBoxes ))
		rigLog="$rigLog${rigLog:+,}TRACKING"
	else
		rigAskPosts=$(( rigAskPosts + 1 ))
		rigLog="$rigLog${rigLog:+,}ASK"
	fi
	return 0
}
AgentsToolsSessionCommsDir(){ return 1 ; }

## One record as the outbox keeps it. A box is a container and its two children, weight 3, so a message holds 16 of them.
rigBox='{"type":"container","width":"full","children":[{"type":"section","text":"a"},{"type":"context","text":"b"}]}'
rigTracking(){ ## block
	printf 'rig-session\t%s\tmagic-tester\tbot\tchat.postMessage\t{"channel":"CRIG","text":"run - 1 line","blocks":[%s],"thread_ts":"1793000000.000100","metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-tester","tracking":"activity","session":"rig-session"}}}\n' "$1" "$rigBox"
}
rigAsk(){
	printf 'rig-session\t9999\tmagic-developer\tbot\tchat.postMessage\t{"channel":"CRIG","text":"the ask","blocks":[%s],"thread_ts":"1793000000.000100","metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-developer","session":"rig-session"}}}\n' "$rigBox"
}

echo "-- a pass posts its share and leaves the file in flight --"
for n in $( seq 1 40 ) ; do rigTracking "$n" ; done > "$rigCache/outbox.messages.txt"
AgentsToolsCommsCachePush "$rigCache" 1000 2
rigAssert "two messages posted, 16 boxes each" "$rigTrackBoxes" 32
rigAssert "and the file is still in flight, the pointer on its two posted records" "$( cut -d' ' -f1 "$rigCache/.push.txt" ):$( [ -f "$rigCache/outbox.pushing.txt" ] && echo in-flight || echo gone )" "2:in-flight"

echo "-- an ask appended while that file is in flight --"
rigLog="" rigAskPosts=0
rigAsk > "$rigCache/outbox.messages.txt"
AgentsToolsCommsCachePush "$rigCache" 1000 2
rigAssert "the ask is posted on the next pass" "$rigAskPosts" 1
rigAssert "and it is that pass's first message" "${rigLog%%,*}" "ASK"

echo "-- to the end, with nothing posted twice and nothing lost --"
rigPass=0
while [ -f "$rigCache/outbox.pushing.txt" ] || [ -f "$rigCache/outbox.messages.txt" ] ; do
	rigPass=$(( rigPass + 1 ))
	[ "$rigPass" -le 40 ] || break
	AgentsToolsCommsCachePush "$rigCache" 1000 2
done
rigAssert "every box of the backlog is posted once, and none twice: all 40 of them" "$rigTrackBoxes" 40
rigAssert "the ask is posted once in the whole run, and not again" "$rigAskPosts" 1
rigAssert "and the outbox drains to nothing" "$( ls -A "$rigCache" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" ""

echo "-- the control: with no backlog the ask is the only post there is --"
rm -rf "$rigCache" ; mkdir -p "$rigCache"
rigLog="" rigTrackBoxes=0 rigAskPosts=0
rigAsk > "$rigCache/outbox.messages.txt"
AgentsToolsCommsCachePush "$rigCache" 1000 2
rigAssert "the ask alone posts once" "$rigLog" "ASK"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
