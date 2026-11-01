#!/usr/bin/env bash
## Behavioural check on the comms cache's outbox and its one pusher (S21.13, owner 2026-10-28): a send appends there and
## returns, the pusher reads the state, posts after `sent` in order, and moves `sent` on success; a failure sets `retry-at`
## and nothing after it overtakes it; once all is sent the outbox is cut back to empty; one pusher at a time. Held:
##   1. the two appended records are both posted, in the order they were appended
##   2. a payload that carried a newline is posted as the lines it was
##   3. once all is sent the outbox is cut back to empty
##   4. a post refused (rc 1) keeps its place: nothing after it is posted, and it is not posted twice
##   5. the refusal sets `retry-at` ahead of the clock, and leaves `sent` where it was
##   6. the next pass at that moment posts the rest, in order
##   7. a second pusher inside the first one's lock posts nothing
##   8. a record with no block number is dropped, not posted and not left to jam the queue
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheOutboxCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCache="$rigTmp/cache/slack/slack-CRIG"
mkdir -p "$rigCache" || exit 1

. "$rigInclude"

## The post the pusher makes, stubbed: it records what it was given and answers with rigPostRc. A refusal (1) is the expected
## outcome of a rate limit, which the state has to hold for the next pass.
rigPosted=""
rigPostRc=0
rigPosts=0
AgentsToolsSessionCommsPost(){ ## session, the retry file
	rigPosts=$(( rigPosts + 1 ))
	rigPosted="$rigPosted$( LC_ALL=C awk 'held { print ; next } /^-$/ { held = 1 }' "$2" | LC_ALL=C tr '\n' '/' ) "
	return "$rigPostRc"
}
AgentsToolsSessionCommsDir(){ return 1 ; }

## One record as a send appends it: `<session>\t<block>\t<member>\t<identity>\t<method>\t<payload>`, the payload's newlines as \037.
rigAppend(){ ## block, text
	local appendText="${2//$'\n'/$'\037'}"
	AgentsToolsCommsCacheOutboxAppend "$rigCache" rig-session "$1" rig-member user chat.postMessage "$appendText"
}

echo "-- the outbox posts what a send appended, in order, and is cut back to empty --"
rigAppend 1 one
rigAppend 2 "two
lines"
AgentsToolsCommsCachePush "$rigCache" 1000
rigAssert "both records are posted" "$rigPosts" 2
rigAssert "in the order they were appended" "$rigPosted" "one/ two/lines/ "
rigAssert "and the outbox is cut back to empty" "$( [ -s "$rigCache/outbox.messages.txt" ] && echo kept || echo empty )" empty

echo "-- a refusal keeps its place, and nothing after it overtakes it --"
rigPosted="" rigPosts=0
rigAppend 3 three
rigAppend 4 four
rigPostRc=1
AgentsToolsCommsCachePush "$rigCache" 2000
rigAssert "the first record is tried, and the one after it never posted" "$rigPosts" 1
rigAssert "the refused record did not move the sent pointer" "$( cut -d' ' -f1 "$rigCache/.push.txt" )" 0
rigAssert "the refusal set retry-at ahead of the clock" "$( [ "$( cut -d' ' -f2 "$rigCache/.push.txt" )" -gt 2000 ] && echo ahead || echo behind )" ahead
rigAssert "and the queue is still there, whole" "$( LC_ALL=C wc -l < "$rigCache/outbox.pushing.txt" | LC_ALL=C tr -d ' ' )" 2

echo "-- the next pass at that moment posts the rest, in order, and no record twice --"
rigPostRc=0
rigPosted="" rigPosts=0
AgentsToolsCommsCachePush "$rigCache" 99999
rigAssert "the two left are posted" "$rigPosts" 2
rigAssert "in their own order" "$rigPosted" "three/ four/ "
rigAssert "and the outbox is empty again" "$( [ -s "$rigCache/outbox.pushing.txt" ] && echo kept || echo empty )" empty

echo "-- one pusher at a time --"
rigPosted="" rigPosts=0
rigAppend 5 five
printf '%s\n' 99999 > "$rigCache/.pushlock.txt"
AgentsToolsCommsCachePush "$rigCache" 99999
rigAssert "a locked outbox is not pushed" "$rigPosts" 0
rm -f "$rigCache/.pushlock.txt"
AgentsToolsCommsCachePush "$rigCache" 99999
rigAssert "and the pass after the lock posts it" "$rigPosts" 1

echo "-- a record with no block number is dropped, not left to jam the queue --"
rigPosted="" rigPosts=0
rigAppend "" noblock
rigAppend 7 seven
AgentsToolsCommsCachePush "$rigCache" 99999
rigAssert "only the sound record is posted" "$rigPosts" 1
rigAssert "and it is the one that was sound" "$rigPosted" "seven/ "

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
