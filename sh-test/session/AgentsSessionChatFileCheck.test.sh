#!/usr/bin/env bash
## Behavioural check on the session chat file and the write path (F9.1 of the refactorings epic): the session comms
## channel, though it is a Slack thread, is recorded in a file of the session folder, `session.chat`, one per session.
## A message sent by a run is recorded in it first, in a proper format with from and to, and only then posted to Slack,
## in the shape it always had. Held, run and not read:
##   1. THE RECORD. A send in a session leaves one block in sessions/<session>/session.chat: the header
##      `<iso-time> <from> -> <to>:` and the body as the sender wrote it, Markdown kept (lists, code blocks, emphasis).
##      From is the member, never the bot account that posted it; to is the addressees, `all` where it named none.
##   2. FIRST, THEN THE POST. The file already held the block when Slack was called; a post Slack refuses leaves the
##      block in the file, and the send fails as it did.
##   3. THE POST IS UNCHANGED. The Slack payload carries the author line and the addressee line it always did, and the
##      header of the file is not in it.
##   4. ONE FILE A SESSION. A second send, to another conversation, adds a block to the same file. The index
##      (session.chat.index) has a line for each block, with the Slack ts and the conversation:thread the post got
##      once it was posted, and `-` where it was never posted.
##   5. THE FORMS. A body line that reads as a header is kept one space in, so the blocks of the file stay countable;
##      a blocks-format send records its text version; an edit (--update-ts) records nothing; a call with no session
##      records nothing and posts as ever.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI
## is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatFileCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-bot" "$rigTmp/skills/keeper-addr"
for rigMember in keeper-rig keeper-bot keeper-addr ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-ADDR\n' > "$rigWs/.local/.agents/keeper-addr.agent.env"

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

rigScene=""
rigSession=""
rigChat=""
rigSceneMake(){ ## scenario name, its session id (empty: a call with no session)
	rigScene="$rigTmp/$1"
	rigSession="$2"
	mkdir -p "$rigScene"
	: > "$rigScene/calls"
	rigChat="$rigWs/.local/agents/sessions/${rigSession:-none}/session.chat"
	rm -rf "$rigWs/.local/agents/sessions/${rigSession:-none}"
}
## One send of the member, with the body on its standard input; the output and the exit code kept.
rigSend(){ ## member, target, body, send options...
	local sendMember="$1" sendTarget="$2" sendBody="$3"
	shift 3
	printf '%s' "$sendBody" | ( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID \
		"PATH=$rigTmp/bin:$PATH" "RIG_SCENARIO=$rigScene" "RIG_CHAT=$rigChat" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" ${rigSession:+MDAT_SESSION_ID=$rigSession} \
		bash "$rigTool" --slack-send-message --team-member "$sendMember" "$sendTarget" "$@" --from-stdin ) > "$rigScene/send.out" 2> "$rigScene/send.err"
	printf '%s' "$?" > "$rigScene/send.rc"
}
rigHeaders(){ ## how many header lines the chat file holds
	[ -f "$rigChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$rigChat"
}
rigNth(){ ## the Nth header line of the chat file, without its time
	[ -f "$rigChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$1" '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; if ( count == want ) { sub(/^[^ ]* /, "") ; print ; exit ; } }' "$rigChat"
}
rigIndex(){ ## the index line of block N
	[ -f "$rigChat.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want { print $2 " " $3 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$rigChat.index"
}
rigPayload(){ ## the Nth payload posted
	cat "$rigScene/post.$1" 2>/dev/null || printf 'no-payload'
}

BODY=$'RIG-BODY **strong** line\n\n- one\n- two\n\n```\ncode here\n```\n\n> quoted'

echo "-- 1. the record --"
rigSceneMake record rig-chat-1
rigSend keeper-rig magic-team "$BODY" --address-to keeper-addr
rigAssert "the send succeeds"                                  "$( cat "$rigScene/send.rc" )" 0
rigAssert "the chat file is in the session's folder, one block" "$( [ -f "$rigChat" ] && printf 'file:' ; rigHeaders )" "file:1"
rigAssert "the header is <iso-time> <from> -> <to>:"            "$( LC_ALL=C head -1 "$rigChat" | LC_ALL=C sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z //' )" "keeper-rig -> keeper-addr:"
rigAssert "the time is UTC, to the second"                     "$( LC_ALL=C head -1 "$rigChat" | LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ' )" 1
rigAssert "the body is the Markdown the sender wrote"           "$( LC_ALL=C sed -n '2,$p' "$rigChat" | LC_ALL=C awk 'NF || seen { seen = 1 ; lines[++n] = $0 ; } END { while ( n > 0 && lines[n] == "" ) { n-- ; } for ( i = 1 ; i <= n ; i++ ) { print lines[i] ; } }' )" "$BODY"
rigAssert "no Slack shape in the file: no arrow, no bold addressee" "$( LC_ALL=C grep -c -e '→' -e '\*_' "$rigChat" )" 0
rigSceneMake record-all rig-chat-2
rigSend keeper-rig magic-team "RIG-NO-ADDRESSEE"
rigAssert "a message that names nobody is to all"               "$( rigNth 1 )" "keeper-rig -> all:"
rigSceneMake record-bot rig-chat-3
rigSend keeper-bot magic-team "RIG-BY-THE-BOT" --identity-bot
rigAssert "from is the member, though the bot account posted it" "$( rigNth 1 )" "keeper-bot -> all:"
rigAssert "the post went out under the bot token"               "$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 ; exit ; }' "$rigScene/calls" )" "rig-bot-token-TEAM"

echo "-- 2. first, then the post --"
rigSceneMake first rig-chat-4
rigSend keeper-rig magic-team "RIG-FIRST"
rigAssert "Slack was called once"                               "$( cat "$rigScene/posts" 2>/dev/null )" 1
rigAssert "the file already held header and body when it was called" "$( cat "$rigScene/at-post" 2>/dev/null )" "1 3"
rigSceneMake refused rig-chat-5
printf 'is_archived\n' > "$rigScene/post-errors"
rigSend keeper-rig magic-team "RIG-REFUSED"
rigAssert "a post Slack refuses fails the send as it did"       "$( [ "$( cat "$rigScene/send.rc" )" != 0 ] && printf failed ; LC_ALL=C grep -c 'nothing was posted' "$rigScene/send.err" )" "failed1"
rigAssert "the message stays recorded"                          "$( rigNth 1 )" "keeper-rig -> all:"
rigAssert "and its index line has no ts, and says Slack refused it (F9.3: the writer never posts it again)" "$( rigIndex 1 )" "- refused"

echo "-- 3. the post is unchanged --"
rigSceneMake payload rig-chat-6
rigSend keeper-rig magic-team "RIG-PAYLOAD" --address-to keeper-addr
rigAssert "the Slack text opens with the arrow and the addressee as ever" "$( rigPayload 1 | LC_ALL=C grep -c -F -e '→' -e 'keeper-addr' )" 1
rigAssert "the body is in the Slack payload"                    "$( rigPayload 1 | LC_ALL=C grep -c 'RIG-PAYLOAD' )" 1
rigAssert "the header of the file is not"                       "$( rigPayload 1 | LC_ALL=C grep -c -F ' -> keeper-addr:' )" 0

echo "-- 4. one file a session --"
rigSceneMake onefile rig-chat-7
rigSend keeper-rig magic-team "RIG-ONE"
rigSend keeper-rig magic-team "RIG-TWO" --address-to keeper-addr
rigAssert "two sends, one file, two blocks"                     "$( rigHeaders )" 2
rigAssert "the second block is from the second send"            "$( rigNth 2 )" "keeper-rig -> keeper-addr:"
rigAssert "the index has a line for each block"                 "$( LC_ALL=C wc -l < "$rigChat.index" | LC_ALL=C tr -d ' ' )" 2
rigAssert "block 1 carries the ts Slack gave it and its conversation" "$( rigIndex 1 )" "1760000000.000101 CRIG00001:1760000000.000101"
rigAssert "block 2 likewise"                                    "$( rigIndex 2 )" "1760000000.000102 CRIG00001:1760000000.000102"
rigSceneMake other rig-chat-8
rigSend keeper-rig magic-team "RIG-OTHER"
rigAssert "another session has a file of its own"              "$( [ -f "$rigWs/.local/agents/sessions/rig-chat-7/session.chat" ] && [ -f "$rigChat" ] && printf 'both' )" both
rigSceneMake thread rig-chat-9
rigSend keeper-rig CRIG00001:1760000000.000050 "RIG-IN-THREAD"
rigAssert "a post into a thread is indexed by that thread"      "$( rigIndex 1 )" "1760000000.000101 CRIG00001:1760000000.000050"

echo "-- 5. the forms --"
rigSceneMake forms rig-chat-10
rigSend keeper-rig magic-team $'RIG-LINE-ONE\n2026-10-19T10:00:00Z somebody -> else:\nRIG-LINE-THREE'
rigAssert "a body line that reads as a header does not make a block" "$( rigHeaders )" 1
rigAssert "it is kept, one space in"                            "$( LC_ALL=C grep -c -x -F ' 2026-10-19T10:00:00Z somebody -> else:' "$rigChat" )" 1
rigSceneMake blocks rig-chat-11
rigSend keeper-rig magic-team '[{"type":"section","text":{"type":"mrkdwn","text":"RIG-BLOCK"}}]' --format blocks --message-text "RIG-TEXT-VERSION"
rigAssert "a blocks send records its text version"              "$( LC_ALL=C sed -n '2p' "$rigChat" )" "RIG-TEXT-VERSION"
rigSceneMake edit rig-chat-12
rigSend keeper-rig magic-team "RIG-EDIT" --update-ts 1760000000.000001
rigAssert "an edit records nothing"                             "$( [ -f "$rigChat" ] && printf 'file' || printf 'none' )" none
rigSceneMake nosession ""
rigBefore="$( find "$rigWs/.local/agents/sessions" -name 'session.chat*' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigSend keeper-rig magic-team "RIG-NO-SESSION"
rigAssert "a call with no session posts as ever"                "$( cat "$rigScene/send.rc" ):$( cat "$rigScene/posts" 2>/dev/null )" "0:1"
rigAssert "and records nothing, in no session folder"           "$( find "$rigWs/.local/agents/sessions" -name 'session.chat*' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "$rigBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CHAT FILE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_FILE: OK (%d assertions, offline)\n' "$rigPassCount"
