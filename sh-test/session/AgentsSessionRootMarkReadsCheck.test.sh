#!/usr/bin/env bash
## Behavioural check on S6.37's read side: a session root's marks are the tooling's reflection for a reader, never an
## arrival and never a member's work, run rather than read, on renderings that the real readers are given.
## Held:
##   1. THE ROOT IS NO ARRIVAL. A root post carrying `checkered_flag` and `white_check_mark` is dropped whole by the
##      tracking drop, mark and all, so no reader of a Wait sees it.
##   2. NO SEEN REACTION FOR IT. A Wait's seen targets, read from the rendering a source serves, hold no ts of a root
##      post, and hold the person's message beside it.
##   3. NO REACTION SET OF THE ROOT IS A MEMBER'S NEWS. The replies reader gives no `reactions on your post` line for a
##      post whose only reactions are the tooling's marks.
##   4. THE COMMS CACHE TAKES IT AS HISTORY. The import records the root as `history`, so no floor delivers it, and a
##      change to its reactions alone adds no block.
## Controls, so the instrument is shown able to see what it excludes: the same rendering read without the tracking
## drop yields the root's ts as a seen target, and the same person's reaction set is reported as news.
## Red before the change: the drop and the import are what make 1 and 4 true, and 3 holds only because the marks are
## never placed on a member's own post; a reader that loses the filter reports the root, as the controls show.
## Offline: renderings of the tooling's own formatter, and this rig's own temp tree. No Slack, no socket.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigDropAwk="$rigPackage/sh-lib/session/AgentsTrackingDrop.awk"
rigImportAwk="$rigPackage/sh-lib/session/AgentsSessionChatImport.awk"
rigRepliesAwk="$rigPackage/sh-lib/member/AgentsWaitOwnPostReplies.awk"
rigMatchAwk="$rigPackage/sh-lib/questions/AgentsDismissalMatch.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigDropAwk" "$rigImportAwk" "$rigRepliesAwk" "$rigMatchAwk" ; do
	[ -f "$rigFile" ] || rigRefuse "a reader this check measures is not at the origin: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionRootMarkReadsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigRootTs="1700000000.000100"
rigPersonTs="1700000000.000200"
rigChannel="CRIG00001"
## A rendering as the formatter writes it: the session's root post, marked as the tooling's, carrying its end marks; then
## a person's message with a reaction of their own.
cat > "$rigTmp/render" <<'RIGRENDER'
1700000000.000100 | UBOT00001 | [reactions: checkered_flag x1 (UBOT00001) white_check_mark x1 (UBOT00001)] [tracking: session-root] [session: 8858d856] 🧵 Session *S6.37*
1700000000.000200 | UHUMAN01 | [reactions: eyes x1 (UOTHER01)] an answer from the owner
RIGRENDER
## What the drop leaves, and what the reader would see without it.
LC_ALL=C awk -v member=magic-developer -v away="" -f "$rigDropAwk" < "$rigTmp/render" > "$rigTmp/kept" 2> /dev/null || :
cat "$rigTmp/render" > "$rigTmp/unfiltered"

echo "-- 1. the root is no arrival --"
rigAssert "the drop keeps no line of the root post" "$( LC_ALL=C grep -c "^$rigRootTs" "$rigTmp/kept" || : )" "0"
rigAssert "and keeps the person's message beside it" "$( LC_ALL=C grep -c "^$rigPersonTs" "$rigTmp/kept" || : )" "1"

echo "-- 2. no seen reaction for it --"
## The seen targets a Wait takes from a served rendering, by the rule its own reader applies: a head line's conversation
## and ts, for a message a person wrote.
rigSeen(){ ## rendering file
	LC_ALL=C awk -v channel="$rigChannel" '
		/^[0-9]+\.[0-9]+ \| / { split( $0, f, " \\| " ) ; if ( f[2] ~ /^[UW][A-Z0-9]+$/ ) { print channel ":" $1 ; } }' "$1" 2> /dev/null
}
rigAssert "the served rendering gives the person's ts and no root ts" "$( rigSeen "$rigTmp/kept" | LC_ALL=C tr '\n' ' ' )" "$rigChannel:$rigPersonTs "
echo "-- controls: the same reading without the drop does see the root --"
rigAssert "control, the unfiltered rendering gives the root's ts too" "$( rigSeen "$rigTmp/unfiltered" | LC_ALL=C tr '\n' ' ' )" "$rigChannel:$rigRootTs $rigChannel:$rigPersonTs "

echo "-- 3. no reaction set of the root is a member's news --"
rigReactions(){ ## rendering file, the post's ts
	LC_ALL=C awk -v threadTs="$2" -v postTs="$2" -v floorTs="$2" -v callerName=magic-developer -v side="$rigTmp/side" \
		-f "$rigMatchAwk" -f "$rigRepliesAwk" < "$1" > /dev/null 2>&1 || :
	LC_ALL=C sed -n 's/^reactions //p' "$rigTmp/side" 2> /dev/null
}
rigAssert "a post whose reactions are the tooling's marks alone reports none of a member's own" \
	"$( rigReactions "$rigTmp/render" "$rigPersonTs" )" "[reactions: eyes x1 (UOTHER01)]"
echo "-- control: a person's reaction set is reported as news, so the reader is able to report one --"
printf '1700000000.000300 | UHUMAN01 | a post of the member\n1700000000.000400 | UOTHER01 | [reactions: eyes x1 (UOTHER01)] a reply\n' > "$rigTmp/memberpost"
LC_ALL=C awk -v threadTs=1700000000.000300 -v postTs=1700000000.000300 -v floorTs=1700000000.000300 -v callerName=magic-developer -v side="$rigTmp/side2" \
	-f "$rigMatchAwk" -f "$rigRepliesAwk" < "$rigTmp/memberpost" > /dev/null 2>&1 || :
rigAssert "control, a member's post with no reaction reports none" "$( LC_ALL=C sed -n 's/^reactions //p' "$rigTmp/side2" 2> /dev/null )" "-"

echo "-- 4. the comms cache takes the root as history --"
: > "$rigTmp/index"
: > "$rigTmp/names"
LC_ALL=C awk -v channel="$rigChannel" -v where="$rigChannel:$rigRootTs" -v origin=slack -v seen=- -v historyBefore=0 \
	-v startLine=1 -v startNo=1 -v chatOut="$rigTmp/chat" -v indexOut="$rigTmp/idx" \
	-f "$rigImportAwk" "$rigTmp/index" "$rigTmp/names" "$rigTmp/render" 2> /dev/null || :
rigAssert "the root is recorded as history" "$( LC_ALL=C awk -F'\t' -v want="$rigRootTs" '$2 == want { print $4 ; }' "$rigTmp/idx" 2> /dev/null )" "history"
rigAssert "the person's message beside it is a message" "$( LC_ALL=C awk -F'\t' -v want="$rigPersonTs" '$2 == want { print $4 ; }' "$rigTmp/idx" 2> /dev/null )" "slack"
## A change to the root's reactions alone adds no block, once the root is held: the second import writes no index line.
: > "$rigTmp/idx2"
LC_ALL=C awk -v channel="$rigChannel" -v where="$rigChannel:$rigRootTs" -v origin=slack -v seen=- -v historyBefore=0 \
	-v startLine=1 -v startNo=1 -v chatOut=/dev/null -v indexOut="$rigTmp/idx2" \
	-f "$rigImportAwk" "$rigTmp/idx" "$rigTmp/names" "$rigTmp/render" 2> /dev/null || :
rigAssert "and a second import of the same rendering adds no block" "$( LC_ALL=C grep -c . "$rigTmp/idx2" 2> /dev/null || : )" "0"

printf 'SESSION_ROOT_MARK_READS: %s (%d assertions, %d failed, offline, rig tree only)\n' \
	"$( [ "$rigFail" -eq 0 ] && echo OK || echo FAILED )" "$(( rigPass + rigFail ))" "$rigFail"
[ "$rigFail" -eq 0 ] || exit 1
exit 0
