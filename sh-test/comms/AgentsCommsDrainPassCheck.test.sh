#!/usr/bin/env bash
## AgentsCommsDrainPassCheck -- the comms reader's cache push drains its outbox in one pass and stops only at its bound or at
## an empty outbox (S10.31; AgentsToolsCommsCachePushAll, AgentsTools.CommsCache.include).
## Held:
##   1. the bound the reader passes is 48 posts a pass, which this change sets and no measurement produced
##   2. one pass drains a 40-record outbox to nothing: it ends its turn when its outbox is empty, not at a smaller round bound
##   3. the same pass posts exactly its bound and no more, so a pass is still bounded and a backlog is spread over passes
##   4. a pass with nothing to drain posts nothing, ends at once, and holds no lane behind it
##   5. the control: with no bound the same store drains whole, so rows 2 to 4 turn on the bound and not on the store
## Offline: one mktemp tree, the post stubbed by this file, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigCacheInclude="$rigPkg/sh-lib/comms/AgentsTools.CommsCache.include"
rigSessionInclude="$rigPkg/sh-lib/session/AgentsTools.SessionComms.include"
rigReader="$rigPkg/sh-lib/session/AgentsTools.InternSessionComms.include"
[ -f "$rigCacheInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigCacheInclude" >&2 ; exit 1 ; }
[ -f "$rigSessionInclude" ] || { echo "⛔ ERROR: the session comms is not at the origin this workspace resolves: $rigSessionInclude" >&2 ; exit 1 ; }
## A text-level check never parses: the shell's own parser answers first, on the files this check reads.
for rigParse in "$rigCacheInclude" "$rigSessionInclude" "$rigReader" ; do
	bash -n "$rigParse" || { echo "⛔ ERROR: $rigParse does not parse, so nothing here is measured" >&2 ; exit 1 ; }
done

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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsDrainPassCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## THE RATE THE PASS IS SET TO, read from the code that ships it, never typed into this file.
rigBound="$( . "$rigSessionInclude" > /dev/null 2>&1 ; printf '%s' "$agentsSessionCommsPostsPerPass" )" || rigBound=""
case "$rigBound" in ''|*[!0-9]*) rigBound="" ;; esac
echo "-- the rate the pass is set to --"
rigAssert "the reader's posts a pass is 48" "$rigBound" 48
rigAssert "and the reader passes that setting to the push of every channel's outbox" \
	"$( LC_ALL=C awk '/AgentsToolsCommsCachePushAll "\$commsPassNow" "\$agentsSessionCommsPostsPerPass"/ { c++ ; } END { print c + 0 ; }' "$rigReader" )" 1

## The store, one channel folder holding <count> queued records in the outbox's own shape.
rigStore(){ ## root, count
	local stRoot="$1" stCount="$2" stAt=0
	rm -rf "$stRoot"
	mkdir -p "$stRoot/.local/cache/comms/slack/slack-CRIG" "$stRoot/.local/temp" "$stRoot/.local/agents/comms" || return 1
	while [ "$stAt" -lt "$stCount" ] ; do
		printf 'rig-session\t%s\tmagic-team\tuser\tchat.postMessage\tan ordinary message %s\n' "$stAt" "$stAt" >> "$stRoot/.local/cache/comms/slack/slack-CRIG/outbox.messages.txt"
		stAt=$(( stAt + 1 ))
	done
}
rigPosted=0
rigOnePass(){ ## root, bound -- posts made by one pass, in a shell of its own so the store is the only state carried
	rigPosted=0
	MMDAPP="$1" bash -c '. "$1" > /dev/null 2>&1 || exit 9 ; AgentsToolsSessionCommsPost(){ return 0 ; } ; AgentsToolsCommsCachePushAll 1700001000 "$2" > /dev/null 2>&1 ; printf "%s\n" "$agentsCommsCachePushAllMade"' \
		rig-push "$rigCacheInclude" "$2" 2> /dev/null || return 1
}
rigHeld(){ ## root -- records still queued, from the outbox's own record count less the pointer's sent count
	local hdDir="$1/.local/cache/comms/slack/slack-CRIG" hdSent=0 hdTotal=0 hdSkip
	[ ! -f "$hdDir/.push.txt" ] || { read -r hdSent hdSkip hdSkip < "$hdDir/.push.txt" ; } 2> /dev/null || :
	case "$hdSent" in ''|*[!0-9]*) hdSent=0 ;; esac
	[ ! -f "$hdDir/outbox.pushing.txt" ] || hdTotal="$( LC_ALL=C awk 'END { print NR }' "$hdDir/outbox.pushing.txt" )"
	printf '%s' "$(( hdTotal - hdSent ))"
}

echo "-- one pass over an outbox smaller than the bound drains it to nothing --"
rigStore "$rigTmp/forty" 40
rigMade="$( rigOnePass "$rigTmp/forty" "$rigBound" )" || rigMade="error"
rigAssert "one pass posts all forty records, ending when its outbox is empty and not at a smaller round bound" "$rigMade" 40
rigAssert "and nothing of the outbox is left queued" "$( rigHeld "$rigTmp/forty" )" 0

echo "-- the same pass over a backlog drains exactly its bound --"
rigStore "$rigTmp/twohundred" 200
rigMade="$( rigOnePass "$rigTmp/twohundred" "$rigBound" )" || rigMade="error"
rigAssert "one pass posts exactly its bound of 48 and no more" "$rigMade" 48
rigAssert "and the backlog it did not reach still stands, so passes share the work" "$( rigHeld "$rigTmp/twohundred" )" 152

echo "-- a backlog behind the rig's own many near-empty folders --"
## The live rig holds 105 channel folders, and one of them holds almost the whole backlog. A pass that spends its bound one post
## on each folder drains that backlog a record a pass, so the backlog never clears and the ask path stays slow.
rigFeedHeld(){ ## root -- the backlog folder's own unsent records
	local fdDir="$1/.local/cache/comms/slack/slack-C000FEED" fdSent=0 fdTotal=0 fdSkip
	[ ! -f "$fdDir/.push.txt" ] || { read -r fdSent fdSkip fdSkip < "$fdDir/.push.txt" ; } 2> /dev/null || :
	case "$fdSent" in ''|*[!0-9]*) fdSent=0 ;; esac
	[ ! -f "$fdDir/outbox.pushing.txt" ] || fdTotal="$( LC_ALL=C awk 'END { print NR }' "$fdDir/outbox.pushing.txt" )"
	printf '%s' "$(( fdTotal - fdSent ))"
}
rigMany="$rigTmp/many"
rm -rf "$rigMany"
mkdir -p "$rigMany/.local/cache/comms/slack" "$rigMany/.local/temp" "$rigMany/.local/agents/comms" || exit 1
rigFeed="$rigMany/.local/cache/comms/slack/slack-C000FEED"
mkdir -p "$rigFeed" || exit 1
rigAt=0
while [ "$rigAt" -lt 200 ] ; do
	printf 'rig-session\t%s\tmagic-team\tuser\tchat.postMessage\tbacklog %s\n' "$rigAt" "$rigAt" >> "$rigFeed/outbox.messages.txt"
	rigAt=$(( rigAt + 1 ))
done
for rigAt in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 ; do
	rigDir="$rigMany/.local/cache/comms/slack/slack-C$rigAt"
	mkdir -p "$rigDir" || exit 1
	printf 'rig-session\t1\tmagic-team\tuser\tchat.postMessage\tone of many\n' > "$rigDir/outbox.messages.txt"
done
rigMade="$( rigOnePass "$rigMany" "$rigBound" )" || rigMade="error"
rigAssert "the pass spends its whole bound on the backlog it can reach" "$rigMade" 48
rigAssert "so the backlog folder drains by the whole bound, not one post of it" "$( rigFeedHeld "$rigMany" )" 152

echo "-- a pass with nothing to drain --"
rigStore "$rigTmp/empty" 0
rigStarted="$( date +%s )"
rigMade="$( rigOnePass "$rigTmp/empty" "$rigBound" )" || rigMade="error"
rigAssert "posts nothing" "$rigMade" 0
rigAssert "leaves no lane behind it: no push lock is held" "$( LC_ALL=C ls -A "$rigTmp/empty/.local/cache/comms/slack/slack-CRIG" | LC_ALL=C grep -c '^\.pushlock\.txt$' || : )" 0
rigAssert "and ends at once, well inside a second" "$(( $( date +%s ) - rigStarted <= 1 ))" 1

echo "-- the control: with no bound the same store drains whole --"
rigStore "$rigTmp/unbounded" 200
rigMade="$( rigOnePass "$rigTmp/unbounded" 0 )" || rigMade="error"
rigAssert "every record of the store is posted in one pass, so the rows above turn on the bound" "$rigMade" 200

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
