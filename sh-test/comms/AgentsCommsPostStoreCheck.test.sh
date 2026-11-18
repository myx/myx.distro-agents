#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
## Behavioural check on the comms cache's own-post store (S1 item 11): a message our tooling posts is stored once, with a
## local id, when it is posted, and one later append records its Slack ts against that local id. Held:
##   1. a post writes one line, into its month's messages.txt, its first field the post's own epoch
##   2. its body carries the local id as `[local: <id>]`, and the id is the EventIdentifier form
##   3. the line is written with no Slack answer at all, so a post that waits or is never delivered is stored
##   4. two posts get two ids and two lines
##   5. Serve serves the stored post once, as a message of its own time
##   6. after the link line, Serve serves it once still: neither the reference line nor a Slack read's own copy of it
##   7. a reader whose floor sits between the post's epoch and its ts still gets the message, once
##   8. the ingest's fold holds the ts the link names, so the read does not make a second message of it
## Offline: a cache folder of the rig's own, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigCacheInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigCacheInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigCacheInclude" >&2 ; exit 1 ; }
rigIngestAwk="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsCommsIngestEvents.awk"
[ -f "$rigIngestAwk" ] || { echo "⛔ ERROR: the ingest's events awk is not at the origin: $rigIngestAwk" >&2 ; exit 1 ; }

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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsPostStoreCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigEntry="$rigTmp/cache/slack/slack-CRIGPOST"
mkdir -p "$rigEntry/202611" || exit 1
## A month file of one real message of the thread, so a served read has something that is not ours in it.
printf '%s\n' "1794918100.000100 | U0BT7PCNG7Q | a message of another member" > "$rigEntry/202611/messages.txt"
printf '%s %s %s\n%s\n%s\n' 1794918000 1794917000 1794918100 "## target=slack:CRIGPOST" "slack-thread CRIGPOST magic-developer false" > "$rigEntry/.state.txt"

. "$rigCacheInclude"

echo "-- 1 to 4. a post is stored once, with its own id, before any answer --"
rigFirst="$( AgentsToolsCommsCachePostStore "$rigEntry" magic-developer "RIG-POST-BODY" )"
rigIdForm="no"
case "$rigFirst" in
	[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z-*) rigIdForm="yes" ;;
esac
rigAssert "a post answers with a local id" "$rigIdForm" yes
rigAssert "and writes one line, into its month's messages.txt" "$( LC_ALL=C grep -c 'RIG-POST-BODY' "$rigEntry/202611/messages.txt" )" 1
rigAssert "whose body carries that id as its local tag" "$( LC_ALL=C grep -c -F "[local: $rigFirst]" "$rigEntry/202611/messages.txt" )" 1
rigAssert "and whose first field is the post's own epoch, in the store's own ts form" "$( LC_ALL=C awk '/RIG-POST-BODY/ { print ( $1 ~ /^[0-9]+\.[0-9][0-9][0-9][0-9][0-9][0-9]$/ ? "yes" : $1 ) }' "$rigEntry/202611/messages.txt" )" yes
rigSecond="$( AgentsToolsCommsCachePostStore "$rigEntry" magic-developer "RIG-POST-TWO" )"
rigAssert "a second post gets its own id" "$( [ "$rigSecond" != "$rigFirst" ] && echo different || echo same )" different
rigAssert "and the store holds two lines of our own" "$( LC_ALL=C grep -c 'RIG-POST' "$rigEntry/202611/messages.txt" )" 2

echo "-- 5. Serve serves the stored post once, and the thread's own message with it --"
rigServed="$( AgentsToolsCommsCacheServe "$rigEntry" 0 nohead )"
rigAssert "the stored post is served" "$( printf '%s\n' "$rigServed" | LC_ALL=C grep -c 'RIG-POST-BODY' )" 1
rigAssert "and the other member's message is served too" "$( printf '%s\n' "$rigServed" | LC_ALL=C grep -c 'another member' )" 1
rigAssert "so the whole serve is three messages: the thread's, and our two posts" "$( printf '%s\n' "$rigServed" | LC_ALL=C grep -c . )" 3

echo "-- 6. after the link, our own post is served once still, though the store holds three lines of it --"
rigPostEpoch="$( LC_ALL=C awk '/RIG-POST-BODY/ { sub(/\..*/, "", $1) ; print $1 ; exit }' "$rigEntry/202611/messages.txt" )"
rigTs="$(( rigPostEpoch + 3 )).000100"
AgentsToolsCommsCachePostLink "$rigEntry" magic-developer "$rigFirst" "$rigPostEpoch" "$rigTs"
## The Slack read's own copy of the same message: untagged, its ts in field one, the body repeated.
printf '%s\n' "$rigTs | U0BT7PCNG7Q | RIG-POST-BODY" >> "$rigEntry/202611/messages.txt"
rigAssert "the store now holds the post's line, its link line, and the read's copy" "$( LC_ALL=C grep -c 'RIG-POST-BODY\|\[local: '"$rigFirst"'\]' "$rigEntry/202611/messages.txt" )" 3
rigServed="$( AgentsToolsCommsCacheServe "$rigEntry" 0 nohead )"
rigAssert "the post is served once from the whole store" "$( printf '%s\n' "$rigServed" | LC_ALL=C grep -c 'RIG-POST-BODY' )" 1
rigAssert "and it is the post's own line, at its own time" "$( printf '%s\n' "$rigServed" | LC_ALL=C awk '/RIG-POST-BODY/ { sub(/\..*/, "", $1) ; print $1 }' )" "$rigPostEpoch"

echo "-- 7. a reader whose floor sits between the post's epoch and its ts still gets it once --"
rigServed="$( AgentsToolsCommsCacheServe "$rigEntry" "$(( rigPostEpoch + 1 ))" nohead )"
rigAssert "the message is served once to that reader" "$( printf '%s\n' "$rigServed" | LC_ALL=C grep -c 'RIG-POST-BODY' )" 1
rigAssert "and it is the read's line, which is at or after the floor" "$( printf '%s\n' "$rigServed" | LC_ALL=C awk '/RIG-POST-BODY/ { print $1 }' )" "$rigTs"

echo "-- 8. the ingest's fold holds the ts the link names, so the read makes no second message of it --"
## A read of the thread as Slack answers it: our own post, and the other member's message.
printf '%s' '{"ok":true,"messages":[{"ts":"'"$rigTs"'","user":"U0BT7PCNG7Q","text":"RIG-POST-BODY"},{"ts":"1794918100.000100","user":"U0BT7PCNG7Q","text":"a message of another member"}]}' > "$rigTmp/read.json"
rigRows="$( LC_ALL=C awk -v storeFiles="$rigEntry/202611/messages.txt" -v lineBytes=2000 -v headBytes=400 \
	-f "$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessJsonField.awk" -f "$rigIngestAwk" < "$rigTmp/read.json" )"
rigAssert "a read of messages the store already holds makes no new message of them" "$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' '$1 == "msg"' | wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "and our own post is no second message of the store" "$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' -v ts="$rigTs" '$1 == "msg" && $3 == ts' | wc -l | LC_ALL=C tr -d ' ' )" 0

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
