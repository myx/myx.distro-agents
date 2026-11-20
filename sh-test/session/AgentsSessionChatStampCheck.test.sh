#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
## Behavioural check on the session chat index's append-only stamps (S1 item 11, stage 2): a stamp and a seen mark add a line
## and rewrite nothing, and every reader still sees the file it saw before. Held:
##   1. a stamp leaves session.chat.index byte for byte as it was, and adds one line to the stamps file
##   2. two stamps add two lines, the second carrying its own block and ts
##   3. a seen mark leaves the index byte for byte as it was, and adds one line
##   4. the newest ts of a thread reads the stamped ts, not the index's dash
##   5. the floor reader gives the block once it is stamped, which is the whole point of the stamp
##   6. the resolved index carries each block once, with the stamp's own fields over the index's
##   7. a session with no stamps file resolves to its index exactly as it was, so an unmigrated workspace reads the same
## Offline: a session folder of the rig's own, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigChat="$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
[ -f "$rigChat" ] || { echo "⛔ ERROR: the session chat is not at the origin this workspace resolves: $rigChat" >&2 ; exit 1 ; }

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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSessionChatStampCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSess="rig-session"
rigDir="$MMDAPP/.local/agents/sessions/$rigSess"
mkdir -p "$rigDir" || exit 1
printf '%s\n' "2026-11-17T10:00:00Z keeper-rig -> all:" "the first message" "" \
	"2026-11-17T10:00:10Z keeper-rig -> all:" "the second message" "" > "$rigDir/session.chat"
printf '1\t-1200000000.000100\tC0RIG:1\town\t1\t-\n2\t-\t-\town\t4\t-\n' > "$rigDir/session.chat.index"
export MDAT_SPAWN_SESSION_ID="$rigSess"
. "$rigChat"

rigIndexBytes(){ wc -c < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' ; }
rigStampsLines(){ { wc -l < "$rigDir/session.chat.stamps" ; } 2> /dev/null | LC_ALL=C tr -d ' ' ; }
rigStampsLines(){ if [ -f "$rigDir/session.chat.stamps" ] ; then wc -l < "$rigDir/session.chat.stamps" | LC_ALL=C tr -d ' ' ; else printf 0 ; fi ; }

echo "-- 1 and 2. a stamp adds a line, and neither the index's bytes nor its mtime move --"
rigBefore="$( rigIndexBytes )"
rigIndexMtime="$( stat -f %m "$rigDir/session.chat.index" 2> /dev/null || stat -c %Y "$rigDir/session.chat.index" 2> /dev/null )"
sleep 1
AgentsToolsSessionChatStamp "$rigSess" 2 1794900000.000200 "C0RIG:1794900000.000200"
rigAssert "the index is byte for byte as it was after a stamp" "$( rigIndexBytes )" "$rigBefore"
rigAssert "and its mtime is unmoved, so the write this stage removes is really gone" "$( stat -f %m "$rigDir/session.chat.index" 2> /dev/null || stat -c %Y "$rigDir/session.chat.index" 2> /dev/null )" "$rigIndexMtime"
rigAssert "and the stamps file holds one line" "$( rigStampsLines )" 1
rigAssert "the line names that block and its ts" "$( LC_ALL=C awk -F'\t' '$1 == 2 && $2 == "1794900000.000200" { print "yes" }' "$rigDir/session.chat.stamps" 2> /dev/null )" yes
AgentsToolsSessionChatStamp "$rigSess" 1 1794800000.000300 "C0RIG:1794800000.000300"
rigAssert "a second stamp leaves the index as it was too" "$( rigIndexBytes )" "$rigBefore"
rigAssert "and the stamps file holds two lines" "$( rigStampsLines )" 2


 echo "-- 3. a seen mark adds a line and rewrites nothing --"
AgentsToolsSessionChatSeen "$rigSess" keeper-rig 2
rigAssert "the index is byte for byte as it was after a seen mark" "$( rigIndexBytes )" "$rigBefore"
rigAssert "and the stamps file holds three lines: two stamps and this seen mark" "$( rigStampsLines )" 3

echo "-- 4. the newest ts of a thread reads the stamped ts --"
AgentsToolsSessionChatNewestInto rigNewest "$rigSess" "C0RIG:1794900000.000200"
rigAssert "the newest message of the stamped thread is its own block's stamp" "$rigNewest" 1794900000

echo "-- 5. the floor gives a block once it is stamped --"
rigReadPath=""
AgentsToolsSessionChatReadPath "$rigSess" && rigReadPath="${agentsSessionChatReadPath:-}"
rigAssert "the resolved index could be made" "$( [ -n "$rigReadPath" ] && echo yes || echo no )" yes
rigFloor="$( LC_ALL=C awk -v after=1 -v session="$rigSess" -v member=magic-developer -v role=executor -v thread="C0RIG:1794900000.000200" \
	-v covered="" -v pendingBefore="" -v replySource="replies:$rigSess" -v side="$rigTmp/side" -v filter="" -v memberId="" \
	-f "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsSessionChatRead.awk" \
	"${rigReadPath:-/nonexistent}" "$rigDir/session.chat" 2> /dev/null )"
AgentsToolsSessionChatReadPathDone
rigAssert "the stamped block is the floor's" "$( printf '%s\n' "$rigFloor" | LC_ALL=C grep -c 'the second message' )" 1

echo "-- 6. the resolved index carries each block once, with the stamp's fields over the index's --"
rigResolved="$( AgentsToolsSessionChatResolve "$rigDir/session.chat.index" "$rigDir/session.chat.stamps" )"
rigAssert "the resolved index holds one line a block" "$( printf '%s\n' "$rigResolved" | LC_ALL=C grep -c . )" 2
rigAssert "the stamped block carries the stamp's ts" "$( printf '%s\n' "$rigResolved" | LC_ALL=C awk -F'\t' '$1 == 2 { print $2 }' )" 1794900000.000200
rigAssert "and the seen mark the stamps added" "$( printf '%s\n' "$rigResolved" | LC_ALL=C awk -F'\t' '$1 == 2 { print $6 }' )" keeper-rig
rigAssert "and the index itself still carries neither" "$( LC_ALL=C awk -F'\t' '$1 == 2 { print $2 }' "$rigDir/session.chat.index" )" -

echo "-- 6b. two members marked on one block are both carried, which last-wins would drop --"
AgentsToolsSessionChatSeen "$rigSess" magic-tester 2
rigResolved="$( AgentsToolsSessionChatResolve "$rigDir/session.chat.index" "$rigDir/session.chat.stamps" )"
rigAssert "the block is one line still, over two seen lines" "$( printf '%s\n' "$rigResolved" | LC_ALL=C awk -F'\t' '$1 == 2' | wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "and it carries both members, in the order they were marked" "$( printf '%s\n' "$rigResolved" | LC_ALL=C awk -F'\t' '$1 == 2 { print $6 }' )" "keeper-rig,magic-tester"

echo "-- 6c. the render is kept once it settles, and an append inside its own second rebuilds it --"
rigInode(){ ## file -- its inode, which a rebuild changes where mtime may not
	stat -f %i "$1" 2> /dev/null || stat -c %i "$1" 2> /dev/null
}
rigKept=""
AgentsToolsSessionChatReadPath "$rigSess" && rigKept="${agentsSessionChatReadPath:-}"
rigAssert "a render was made" "$( [ -n "$rigKept" ] && echo yes || echo no )" yes
AgentsToolsSessionChatReadPathDone
rigAssert "the render is one kept file a session" "${rigKept##*/}" "session.chat.resolved"
## THE TIE PROPERTY: an append inside the render's own whole second must force a rebuild. The index grows, and the
## guard cannot tell that from the same-second case, so it rebuilds. Inode, not mtime: a rebuild inside one second keeps it.
rigTieInode="$( rigInode "$rigKept" )"
printf 'a third message\n' | AgentsToolsSessionChatAppend "$rigSess" keeper-rig all 1794900100.000400 "C0RIG:1794900100.000400" own > /dev/null
rigTie=""
AgentsToolsSessionChatReadPath "$rigSess" && rigTie="${agentsSessionChatReadPath:-}"
AgentsToolsSessionChatReadPathDone
rigAssert "an append in the render own second forces a rebuild" "$( [ "$( rigInode "$rigKept" )" != "$rigTieInode" ] && echo rebuilt || echo kept )" rebuilt
rigAssert "and the render then holds a row for the appended block" "$( { wc -l < "$rigTie" ; } 2> /dev/null | LC_ALL=C tr -d ' ' )" "$( { wc -l < "$rigDir/session.chat.index" ; } 2> /dev/null | LC_ALL=C tr -d ' ' )"
## THE SETTLE PROPERTY: once a read has settled the render a whole second newer than its inputs, further quiet reads
## leave it alone. Two of them, so one lucky pass is not the evidence.
sleep 1
AgentsToolsSessionChatReadPath "$rigSess" > /dev/null && AgentsToolsSessionChatReadPathDone
rigSettledInode="$( rigInode "$rigKept" )"
sleep 1
for rigQuietRound in 1 2 ; do
	rigQuiet=""
	AgentsToolsSessionChatReadPath "$rigSess" && rigQuiet="${agentsSessionChatReadPath:-}"
	AgentsToolsSessionChatReadPathDone
	rigAssert "quiet read $rigQuietRound takes the settled render" "$rigQuiet" "$rigKept"
	rigAssert "and writes it not at all, by inode" "$( rigInode "$rigKept" )" "$rigSettledInode"
done

echo "-- 7. a session with no stamps resolves to its index exactly as it was --"
mkdir -p "$rigDir/../rig-plain" || exit 1
rigPlain="$MMDAPP/.local/agents/sessions/rig-plain"
printf '1\t1794800000.000100\tC0RIG:1\town\t1\t-\n' > "$rigPlain/session.chat.index"
rigAssert "an unmigrated session prints its index byte for byte" "$( AgentsToolsSessionChatResolve "$rigPlain/session.chat.index" "$rigPlain/session.chat.stamps" )" "$( cat "$rigPlain/session.chat.index" )"

echo "-- 8. a stamp wakes a Wait whose mark the index and pointers alone leave unchanged --"
## THE WAKE THE STAMP MUST CAUSE: a Wait's own mark, newer than the index and the pointers and older than a stamp, is no longer
## "unchanged", or the block it woke for is never read. Red where the predicate looks at the index and its pointers alone.
printf 'mark\n' > "$rigTmp/mark"
rigAssert "a mark newer than the index alone is unchanged, which is the control" "$( AgentsToolsSessionChatUnchangedSince "$rigSess" "$rigTmp/mark" && echo unchanged || echo changed )" unchanged
sleep 1
AgentsToolsSessionChatStamp "$rigSess" 2 1794900000.000500 "C0RIG:1794900000.000500"
rigAssert "a later stamp makes that mark stale, so the Wait reads the block" "$( AgentsToolsSessionChatUnchangedSince "$rigSess" "$rigTmp/mark" && echo unchanged || echo changed )" changed

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
