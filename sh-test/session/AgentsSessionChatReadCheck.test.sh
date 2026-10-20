#!/usr/bin/env bash
## Behavioural check on the one reader of the session chat file (F3.3's floor, F9.2's pointers): the pointer-and-watch primitive
## the tool returns, the Wait and the work-duty scan share. Run on the functions of sh-lib/session/AgentsTools.SessionChat.include
## over a session folder of the rig's own, with no Slack. Held:
##   1. A POINTER. A member's pointer is made at the end of the file at its first read, and what was there is not new to it;
##      what is appended after is, once; delivered, the pointer moves and the next read finds nothing; it never goes back.
##   2. THE FLOOR. The executor is given every message of the session thread but its own; a participant the ones that name it
##      (its name in the to of the header, `@member` or its Slack account in the body); the replies to a member's own posts are
##      that member's alone; history, a message not posted, a message in another thread and a reply to another member are no
##      one's. A message already delivered by the member's own Wait (the last field of the index) is not delivered again.
##   3. THE SOURCE of each message is named, and consecutive messages of one source share one `# via <source>` line.
##   4. A source of the same Wait that reads a thread itself (covered) has its blocks read past and not printed.
##   5. THE IMPORT. A rendering of a Slack thread becomes blocks for the messages the file does not hold: from is the sender the
##      tooling recorded or else the account (named by the mention-id cache), to what the tooling's header addressed, the body
##      what follows; a message held is not held twice; the first read of a thread makes what was there before the run's launch
##      history; the block of a message the run sent, stamped with its ts, is the same message.
## Offline: no Slack, no network; the session is a folder of the rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is not at the origin this workspace resolves: $rigHere/session/AgentsTools.SessionChat.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatReadCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export MMDAPP="$rigTmp/ws"
mkdir -p "$MMDAPP/.local/.agents" "$MMDAPP/.local/agents/sessions" "$MMDAPP/.local/temp"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD CLAUDE_CODE_SESSION_ID harnessSessionId MDAT_SPAWN_LAUNCH_MARKER
. "$rigHere/session/AgentsTools.SessionChat.include"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigSession="rig-chat-read"
rigThread="CRIGTHR01:1760000000.000010"
rigOther="CRIGOTH01:1760000000.000020"
rigDir="$MMDAPP/.local/agents/sessions/$rigSession"
mkdir -p "$rigDir"
printf '%s\n' "$rigThread" > "$rigDir/session.thread"
## One block: from, to, ts, where, origin, body, seen (default none), the time of its header (default now).
rigBlock(){ ## from to ts where origin body [seen] [time]
	printf '%s' "$6" | AgentsToolsSessionChatAppend "$rigSession" "$1" "$2" "$3" "$4" "$5" "${8:-}" "${7:--}" > /dev/null
}
## What the floor of a member gives, and the pointer after it is delivered.
rigRead(){ ## member, covered (optional) -- into rigOut, in this shell: the pointer to move to is kept in a variable
	AgentsToolsSessionChatFloor "$rigSession" "$1" "${2:-}" > "$rigTmp/floor.out"
	rigOut="$( cat "$rigTmp/floor.out" )"
}
rigMarks(){ ## text of a floor -- the bodies it holds, comma-joined, in order
	printf '%s\n' "$1" | LC_ALL=C awk '/^RIG-/ { printf "%s%s", ( n++ ? "," : "" ), $1 ; }'
}
rigPointerOf(){ ## member
	AgentsToolsSessionChatPointer "$rigSession" "read:$1" || printf none
}

echo "-- 1. a pointer --"
rigBlock keeper-old all 1760000000.000001 "$rigThread" slack "RIG-BEFORE the member's first read"
rigRead keeper-exec
rigAssert "a member with no pointer is given nothing, and the pointer is made at the end of the file" "${#rigOut}:$( rigPointerOf keeper-exec )" "0:1"
rigBlock keeper-old all 1760000000.000101 "$rigThread" slack "RIG-ONE a message of the thread"
rigRead keeper-exec
rigAssert "a message appended after is the floor"                  "$( rigMarks "$rigOut" )" "RIG-ONE"
rigAssert "the pointer stays where it was until delivered"         "$( rigPointerOf keeper-exec )" 1
AgentsToolsSessionChatDelivered "$rigSession" keeper-exec
rigAssert "delivered, the pointer moves to the end read"           "$( rigPointerOf keeper-exec )" 2
rigRead keeper-exec
rigAssert "and the next read finds nothing"                        "${#rigOut}" 0
AgentsToolsSessionChatPointerSet "$rigSession" read:keeper-exec 1 max
rigAssert "a late commit never takes the pointer back"             "$( rigPointerOf keeper-exec )" 2

echo "-- 2. the floor --"
rigBlock keeper-old all 1760000000.000102 "$rigThread" slack "RIG-A to all, in the thread"
rigBlock keeper-old keeper-part 1760000000.000103 "$rigThread" slack "RIG-B to the participant"
rigBlock keeper-old all 1760000000.000104 "$rigThread" slack "RIG-C mentions @keeper-part in its body"
rigBlock keeper-exec all 1760000000.000105 "$rigThread" own "RIG-D the executor's own"
rigBlock keeper-old all 1760000000.000106 "$rigThread" history "RIG-E history"
rigBlock keeper-old all 1760000000.000107 "$rigOther" slack "RIG-F in another thread"
rigBlock keeper-old all 1760000000.000108 "$rigOther" reply:keeper-exec "RIG-G a reply to the executor's post"
rigBlock keeper-old all 1760000000.000109 "$rigOther" reply:keeper-other "RIG-H a reply to another member's post"
## A post that was never made, and has waited more than the floor holds the blocks behind it back for (AgentsSessionCommsCheck holds that
## for a post that is not yet): its header is of the day before, so it is given up here, and is no one's.
rigBlock keeper-old all - - own "RIG-I never posted" - 2026-10-19T10:00:00Z
rigBlock keeper-old all 1760000000.000111 "$rigThread" slack "RIG-J delivered by the member's own Wait" keeper-exec
rigBlock keeper-old all 1760000000.000112 "$rigThread" slack "RIG-K to all, and the Slack account <@URIGPART01> in its body"
rigRead keeper-exec
rigAssert "the executor: every message of the thread but its own, and the replies to its posts" "$( rigMarks "$rigOut" )" "RIG-A,RIG-B,RIG-C,RIG-G,RIG-K"
rigAssert "the pointer it would move to is the last block read" "${agentsSessionChatNewest:-none}" 13
rigPartOut="$( AgentsToolsSessionChatFloor "$rigSession" keeper-part )"
rigAssert "a participant with no pointer yet starts at the end: nothing" "$( rigMarks "$rigPartOut" )" ""
AgentsToolsSessionChatPointerSet "$rigSession" read:keeper-part 2
printf 'keeper-part=URIGPART01=part=Part=Part=d\n' > "$MMDAPP/.local/.agents/slack-mention-ids.cache"
export MDAT_SPAWN_SESSION_ID="rig-chat-read-spawn"
rigPartOut="$( AgentsToolsSessionChatFloor "$rigSession" keeper-part )"
rigAssert "a participant: the ones that name it, in the header, in the body as @member, or as its Slack account" "$( rigMarks "$rigPartOut" )" "RIG-B,RIG-C,RIG-K"
unset MDAT_SPAWN_SESSION_ID
rigAssert "the replies to another member's posts are nobody's here"  "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'RIG-H' )" 0

echo "-- 3. the source of each message --"
rigAssert "the thread's messages come by the thread, the reply by the floor's replies source" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^# via ' | LC_ALL=C tr '\n' ' ' )" "# via slack:$rigThread # via replies:$rigSession # via slack:$rigThread "
rigAssert "consecutive messages of one source share one line"       "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^# via slack:' )" 2
rigAssert "a block is its header, its body, and a blank line"         "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n '2,4p' | LC_ALL=C sed 's/^[0-9T:Z-]* //' | LC_ALL=C tr '\n' '|' )" "keeper-old -> all:|RIG-A to all, in the thread||"

echo "-- 4. a source of the same Wait reads the thread itself --"
AgentsToolsSessionChatPointerSet "$rigSession" read:keeper-cov 1
rigRead keeper-cov "$rigThread"
rigAssert "the covered thread is not printed"                      "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'to all, in the thread' )" 0
rigAssert "and the reply is"                                       "$( rigMarks "$rigOut" )" ""
rigAssert "the pointer moves past it all the same"                 "${agentsSessionChatNewest:-none}" 13
AgentsToolsSessionChatDelivered "$rigSession" keeper-cov
rigAssert "delivered"                                              "$( rigPointerOf keeper-cov )" 13

echo "-- 5. the import --"
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigNow="$( date +%s )"
rigImportThread="CRIGIMP01:$(( rigNow - 400 )).000001"
rigRender="$rigTmp/render.txt"
{
	printf '%s\n' "$(( rigNow - 400 )).000001 | URIGOWN01 | the root, before the run began, by the owner"
	printf '%s\n' "$(( rigNow - 200 )).000001 | UBOT01 | [sender: keeper-old] 🔏 *_keeper-old_* → *_keeper-exec_* <@URIGEXEC1>. RIG-IMPORT-ONE first line"
	printf '%s\n' "- second line of it"
	printf '%s\n' "$(( rigNow - 190 )).000001 | URIGOWN01 | RIG-IMPORT-TWO a human message, no header"
	printf '%s\n' "$(( rigNow - 180 )).000001 | UBOT01 | [sender: keeper-old] 🔏 *_keeper-old_* → @here."
	printf '%s\n' "RIG-IMPORT-THREE on its own line"
} > "$rigRender"
printf 'human-owner=URIGOWN01=owner=Owner=Owner=d\n' >> "$MMDAPP/.local/.agents/slack-mention-ids.cache"
rigMarker="$rigTmp/launch.marker"
: > "$rigMarker"
touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigMarker"
AgentsToolsSessionChatPointerSet "$rigSession" read:keeper-imp 13
rigBefore="$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )"
MDAT_SPAWN_LAUNCH_MARKER="$rigMarker" AgentsToolsSessionChatImport "$rigSession" "$rigImportThread" "$rigRender" slack
rigAfter="$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )"
rigAssert "four messages became four blocks"                       "$(( rigAfter - rigBefore ))" 4
rigIdx(){ ## ts -- where, origin and seen of the index line of that message
	LC_ALL=C awk -F'\t' -v want="$1" '$2 == want { print $3 " " $4 " " $6 ; exit ; }' "$rigDir/session.chat.index"
}
rigAssert "a message before the run's launch is history"           "$( rigIdx "$(( rigNow - 400 )).000001" )" "$rigImportThread history -"
rigAssert "a later one is new"                                     "$( rigIdx "$(( rigNow - 200 )).000001" )" "$rigImportThread slack -"
rigBlockOf(){ ## ts -- the block of that message, as the file holds it
	local blockLine
	blockLine="$( LC_ALL=C awk -F'\t' -v want="$1" '$2 == want { print $5 ; exit ; }' "$rigDir/session.chat.index" )"
	LC_ALL=C sed -n "${blockLine},\$p" "$rigDir/session.chat" | LC_ALL=C awk 'NR == 1 { print ; next ; } /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { exit ; } NF { print ; }' | LC_ALL=C sed '1s/^[0-9T:Z-]* //' | LC_ALL=C tr '\n' '|'
}
rigAssert "from is the sender the tooling recorded, to what its header addressed, the body what follows" "$( rigBlockOf "$(( rigNow - 200 )).000001" )" "keeper-old -> keeper-exec:|RIG-IMPORT-ONE first line|- second line of it|"
rigAssert "from is the account, named by the cache; a message with no header is to all" "$( rigBlockOf "$(( rigNow - 190 )).000001" )" "human-owner -> all:|RIG-IMPORT-TWO a human message, no header|"
rigAssert "@here is to all, and the body is the lines under the header"  "$( rigBlockOf "$(( rigNow - 180 )).000001" )" "keeper-old -> all:|RIG-IMPORT-THREE on its own line|"
rigAssert "the time of a header is the message's, in UTC"         "$( LC_ALL=C grep -c -E "^$( date -u -r "$(( rigNow - 200 ))" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$(( rigNow - 200 ))" +%Y-%m-%dT%H:%M:%SZ ) keeper-old -> keeper-exec:\$" "$rigDir/session.chat" )" 1
MDAT_SPAWN_LAUNCH_MARKER="$rigMarker" AgentsToolsSessionChatImport "$rigSession" "$rigImportThread" "$rigRender" slack
rigAssert "the same rendering read again adds nothing"            "$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )" "$rigAfter"
printf '%s\n' "$(( rigNow - 170 )).000001 | URIGOWN01 | RIG-IMPORT-FOUR later" >> "$rigRender"
AgentsToolsSessionChatImport "$rigSession" "$rigImportThread" "$rigRender" slack
rigAssert "a message added to the thread is the one new block"   "$(( $( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' ) - rigAfter ))" 1
rigAssert "and a thread read before is not read as history again" "$( rigIdx "$(( rigNow - 170 )).000001" )" "$rigImportThread slack -"
rigAssert "the first read of the thread is kept in the pointers"  "$( AgentsToolsSessionChatPointer "$rigSession" "import:$rigImportThread" | LC_ALL=C grep -c -E '^[0-9]+$' )" 1
## The message the run sent: recorded first, stamped with its ts, and then read back from Slack: one block.
rigOwnTs="$(( rigNow - 160 )).000001"
rigOwnNo="$( printf 'RIG-OWN-POST' | AgentsToolsSessionChatAppend "$rigSession" keeper-imp all - - own )"
AgentsToolsSessionChatStamp "$rigSession" "$rigOwnNo" "$rigOwnTs" "$rigImportThread"
printf '%s\n' "$rigOwnTs | UBOT01 | [sender: keeper-imp] 🔏 *_keeper-imp_* → @here." "RIG-OWN-POST" >> "$rigRender"
rigBefore="$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )"
AgentsToolsSessionChatImport "$rigSession" "$rigImportThread" "$rigRender" slack
rigAssert "the message the run sent is held once, the stamp having made it the Slack message" "$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )" "$rigBefore"
rigRead keeper-imp
AgentsToolsSessionChatDelivered "$rigSession" keeper-imp
AgentsToolsSessionChatPointerSet "$rigSession" read:keeper-seen 13
rigAssert "a member whose pointer stood before the import: the imported thread is not the session's thread, so nothing of it is its floor" "$( rigMarks "$rigOut" )" ""

echo "-- 6. a thread that is the session's --"
printf '%s\n' "$rigImportThread" > "$rigDir/session.thread"
rigBefore="$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )"
printf '%s\n' "$(( rigNow - 150 )).000001 | URIGOWN01 | RIG-IMPORT-FIVE" >> "$rigRender"
AgentsToolsSessionChatImport "$rigSession" "$rigImportThread" "$rigRender" slack keeper-seen
rigRead keeper-imp
rigAssert "an executor is given what came into the session's thread after its pointer, never its own post and never history" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -E 'RIG-IMPORT-FIVE' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -E 'RIG-OWN-POST|the root, before' )" "1:0"
rigRead keeper-seen
rigAssert "a member whose own Wait delivered the import itself is not given it again" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'RIG-IMPORT-FIVE' )" 0

echo "-- 7. a session with no thread: what the console leaves for its chat file alone (F11.6) --"
## A message to such a session is recorded with the conversation `local`: no ts, and nothing posted. Its floor is the thread's: the executor every
## one, a participant the ones that name it; and a session that has a thread takes no `local` block for its floor.
rigLocal="rig-chat-local"
rigLocalDir="$MMDAPP/.local/agents/sessions/$rigLocal"
mkdir -p "$rigLocalDir"
rigLocalBlock(){ ## session, from, to, where, body
	printf '%s' "$5" | AgentsToolsSessionChatAppend "$1" "$2" "$3" - "$4" console > /dev/null
}
rigReadOf(){ ## session, member -- the floor of that member in that session, into rigOut
	AgentsToolsSessionChatFloor "$1" "$2" > "$rigTmp/floor.out"
	rigOut="$( cat "$rigTmp/floor.out" )"
}
rigReadOf "$rigLocal" keeper-exec
rigLocalBlock "$rigLocal" user-rig all local "RIG-L1 to all"
rigLocalBlock "$rigLocal" user-rig keeper-part local "RIG-L2 to the participant"
rigLocalBlock "$rigLocal" user-rig all local "RIG-L3 mentions @keeper-part in its body"
rigLocalBlock "$rigLocal" keeper-old all "$rigOther" "RIG-L4 in a thread that is not the session's"
rigLocalBlock "$rigLocal" keeper-exec all local "RIG-L5 the executor's own"
rigLocalBlock "$rigLocal" user-rig all - "RIG-L6 not posted, for a session that has no thread to post to"
rigReadOf "$rigLocal" keeper-exec
rigAssert "the executor of a session with no thread is given every local message but its own, from the chat file" "$( rigMarks "$rigOut" )" "RIG-L1,RIG-L2,RIG-L3"
rigAssert "and they come by the local source" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^# via ' | LC_ALL=C tr '\n' ' ' )" "# via local "
AgentsToolsSessionChatPointerSet "$rigLocal" read:keeper-part 0
export MDAT_SPAWN_SESSION_ID="rig-chat-local-spawn"
rigReadOf "$rigLocal" keeper-part
unset MDAT_SPAWN_SESSION_ID
rigAssert "a participant of it, the ones that name it in the header or the body" "$( rigMarks "$rigOut" )" "RIG-L2,RIG-L3"
rigLocalBlock "$rigSession" user-rig all local "RIG-L7 local, in a session that has a thread"
rigReadOf "$rigSession" keeper-exec
rigAssert "a session that has a thread takes no local block for its floor" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'RIG-L7' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CHAT READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_READ: OK (%d assertions, offline)\n' "$rigPassCount"
