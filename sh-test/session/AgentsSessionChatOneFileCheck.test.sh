#!/usr/bin/env bash
## AgentsSessionChatOneFileCheck — behavioural check on the session chat file of the root-harness epic (F2.1): every session keeps ONE chat file,
## and the external side of its channel never adds a second record. Held, one case per statement:
##
##   S1. A session created by `RootSession` has its chat file from its FIRST message. A real `--intern-mcp-server
##       --run` process mints the session through the tool; a served `DistroAgentsSlack --slack-send-message` call
##       is that session's first message; the session folder the mint made then holds `session.chat` with that one
##       block -- the first content of the session's one record -- and the ts and conversation the copy got are
##       stamped into its index line. Nothing else in the workspace is a second record.
##
##   S2. The chat file is the ONE record, whatever the channel kind. One session, two kinds: a console message
##       with no external channel (recorded `local`, nothing posted) and the member's own Slack send (recorded
##       `own`, the block stamped with the channel:thread the copy went to). Both blocks are in the SAME
##       `session.chat` of the same session; the index has one line each, differing only in ts / conversation /
##       origin. Exactly one `session.chat` exists in the workspace, and each body appears in no other file of it
##       -- not the send log, not a per-kind file.
##
##   S3. A message with NO external channel is recorded there and nowhere else. The console message above is that
##       message: no Slack call is made, no inbox file is left, it is in the chat file alone, and the session's own
##       Wait reads it from there (`chat:<session>`, the one reader) and returns it once. The root-native printback
##       kind is F2.2 and is NOT built or invented here; this is the no-external-channel rule the printback kind
##       will use, pinned on the console's `local` message, which exists today.
##
## Also held, because F2.1 must not move them: the root session's folder is the one the mint registered and its
## token stays beside the chat file; the served Slack send still posts (the external copy is unchanged) while the
## chat header never enters the payload; a root session gets no spawn record and no session.thread.
##
## THE RIG ORIGIN. The server and the direct calls run the package COPY in this rig (never the tree under test):
## `origin/myx/myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked READ-ONLY
## beside it -- never a mute stand-in. The workspace is the rig's own folder.
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee), an `id` stub
## names the person at the console, every workspace is a folder of the rig's own, and no model CLI is started.
##
## Red recipe: point MDLT_ORIGIN at a COPY of the received tree in which `AgentsToolsSessionChatAppend`
## (sh-lib/session/AgentsTools.SessionChat.include) returns before it appends anything -- the one place a session's
## chat block is written, for BOTH the send path and the console's. The Slack posts still go out (the external
## copy is not what is planted away), but no session has a chat file: S1's first message leaves no record, S2's
## one file never holds either kind, S3's console message is refused and its Wait reads nothing. Those are exactly
## the assertions that fail; the "the post was made" ones stay green, showing the failure is the record and not
## the copy. Green is the received tree unmodified plus this check. No git, and the real tree is never written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigChatInclude="$rigHere/session/AgentsTools.SessionChat.include"
rigFixtures="$rigPackage/sh-test/check-fixtures"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigChatInclude" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatOneFileCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigBin="$rigTmp/bin"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigOrigin/myx" "$rigBin" "$rigHome" "$rigSkills/magic-coordinator" \
	|| rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
rigRigPackage="$rigOrigin/myx/myx.distro-agents"
rigRigTool="$rigRigPackage/sh-scripts/DistroAgentsTools.fn.sh"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
## The person at the console, fixed: the same account on every host this check runs on, so the message's `from`
## is asserted whole instead of the machine's own login name.
rigConsoleAccount="Rig.Acct_7"
rigConsole="user-rig-acct-7"
rigIdReal="$( command -v id 2> /dev/null )" || rigIdReal=""
case "$rigIdReal" in
	/*) ln -s "$rigIdReal" "$rigBin/id.real" || rigRefuse "cannot link the real id beside the rig's own" ;;
	*)  rigRefuse "no id on PATH to stand behind the rig's console account" ;;
esac
printf '#!/bin/sh\ncase "$*" in\n\t-un) echo %s ;;\n\t*) exec "%s" "$@" ;;\nesac\n' "$rigConsoleAccount" "$rigBin/id.real" > "$rigBin/id" \
	|| rigRefuse "cannot write the rig's own id"
chmod +x "$rigBin/id"
[ "$( PATH="$rigBin:$PATH" command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
[ "$( PATH="$rigBin:$PATH" id -un )" = "$rigConsoleAccount" ] || rigRefuse "the rig's id stub is not first on its PATH"
printf -- '---\nname: magic-coordinator\n---\nrig root member\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## ---- wire readers, as the root-session checks read their servers ----
rigAnswered(){ ## answer line file -- yes when the server answered that request
	[ -s "$1" ] && printf yes || printf no
}
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2> /dev/null || :
}
rigText(){ ## answer line file -- the first text part of the result
	rigValue "$1" result.content.0.text
}
rigIsError(){ ## answer line file -- yes when the call was refused
	case "$( rigValue "$1" result.isError )" in
		true) printf yes ;;
		*)    [ -n "$( rigValue "$1" error.message )" ] && printf yes || printf no ;;
	esac
}
rigFieldOf(){ ## text, key -- the value of the `<key>: ` line, first one
	printf '%s\n' "$1" | LC_ALL=C sed -n "s/^$2: //p" | head -n 1
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
}
rigServer(){ ## wire file, workspace, scenario -- one real server run, its stdin read to the end
	mkdir -p "$2/.local/temp" "$2/.local/.agents" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" RIG_CHAT="$3/chat" PATH="$rigBin:$PATH" \
		bash "$rigRigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigSend(){ ## json line, id -- write it to the server, wait until that request is answered
	printf '%s\n' "$1"
	rigWaitAt=0
	while ! LC_ALL=C grep -q "\"id\":$2," "$rigServerWire" 2> /dev/null && [ "$rigWaitAt" -lt 2000 ] ; do
		sleep 0.1
		rigWaitAt=$(( rigWaitAt + 1 ))
	done
}
rigStarted(){ ## wire file, label -- refuse when the server never answered initialize
	local rigStartedAnswer=""
	rigStartedAnswer="$( rigReply "$1" 1 )"
	[ "$( rigAnswered "$rigStartedAnswer" )" = yes ] || {
		echo "-- $2: the server answered no initialize, so its stderr follows --" >&2
		sed 's/^/    /' "$1.err" >&2
		rigRefuse "$2: the server never started"
	}
}
rigRootCall(){ ## id, operation -- one RootSession request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}\n' "$1" "$2"
}
rigSlackCall(){ ## id, body -- one served DistroAgentsSlack send to the rig's magic-team channel
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"DistroAgentsSlack","arguments":{"operation":"--slack-send-message","args":["magic-coordinator","magic-team","%s"]}}}\n' "$1" "$2"
}

## ---- the chat file as the check reads it ----
rigSessionDir(){ ## workspace, session id -- the session's own record folder
	printf '%s' "$1/.local/agents/sessions/$2"
}
rigChatFile(){ ## workspace, session id -- the one chat file of that session
	printf '%s' "$( rigSessionDir "$1" "$2" )/session.chat"
}
rigHeaders(){ ## chat file -- how many header lines it holds, `no-file` when there is none
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$1"
}
rigHeader(){ ## chat file, N -- the Nth header line without its time
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; if ( count == want ) { sub(/^[^ ]* /, "") ; print ; exit ; } }' "$1"
}
rigBody(){ ## chat file, N -- the body of the Nth block, blank lines trimmed at its end
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; inBlock = ( count == want ) ; if ( inBlock ) { next ; } }
		inBlock { lines[++n] = $0 }
		END { while ( n > 0 && lines[n] == "" ) { n-- ; } for ( i = 1 ; i <= n ; i++ ) { print lines[i] ; } }' "$1"
}
rigIndex(){ ## chat file, N -- its index line, fields 1..6 tab-separated, space-joined
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { print $1, $2, $3, $4, $5, $6 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigIndexCount(){ ## chat file -- how many index lines it has
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 ; }' "$1.index"
}
rigChats(){ ## workspace -- every session chat file in it, one a line
	find "$1/.local/agents/sessions" -name 'session.chat' -type f 2> /dev/null | LC_ALL=C sort || :
}
rigHolders(){ ## workspace, token -- the files of the workspace that hold the token, one a line
	LC_ALL=C grep -rl -F -- "$2" "$1" 2> /dev/null | LC_ALL=C sort || :
}
rigCount(){ ## file, pattern -- matching lines, 0 when the file is absent
	local rigCountText=""
	rigCountText="$( LC_ALL=C grep -c "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${rigCountText:-0}"
}
rigSlackCalls(){ ## scenario -- chat.postMessage calls it logged
	rigCount "$1/calls" 'chat.postMessage'
}
rigSpawnRecords(){ ## workspace -- how many spawn records it holds
	find "$1/.local/agents/spawned" -name '*.spawn.md' -type f 2> /dev/null | LC_ALL=C grep -c . || :
}
rigThreadFile(){ ## workspace, session id -- `thread` when it has a session.thread, `none` otherwise
	[ ! -f "$( rigSessionDir "$1" "$2" )/session.thread" ] && printf none || printf thread
}

## ---- S1: a RootSession session has its chat file from its first message ----
echo "-- S1: a session minted through RootSession records its first message in its own chat file --"
rigS1="$rigTmp/s1"
rigS1Ws="$rigS1/ws"
rigS1Sc="$rigS1/slack"
rigS1Wire="$rigS1/wire"
rigS1Body="RIG-FIRST-MESSAGE"
mkdir -p "$rigS1Ws/.local/.agents" "$rigS1Sc" || rigRefuse "cannot make the S1 workspace"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigS1Ws/.local/.agents/magic-team.agent.env"

: > "$rigS1Wire"
rigServerWire="$rigS1Wire"
{
	rigSend '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' 1
	rigSend "$( rigRootCall 2 mint )" 2
	rigSend "$( rigSlackCall 3 "$rigS1Body" )" 3
} | rigServer "$rigS1Wire" "$rigS1Ws" "$rigS1Sc"
rigStarted "$rigS1Wire" "S1 server"

rigMintAnswer="$( rigReply "$rigS1Wire" 2 )"
rigMintText="$( rigText "$rigMintAnswer" )"
rigS1Id="$( rigFieldOf "$rigMintText" SESSION )"
rigS1Token="$( rigFieldOf "$rigMintText" TOKEN )"
rigSendAnswer="$( rigReply "$rigS1Wire" 3 )"
rigS1Chat="$( rigChatFile "$rigS1Ws" "$rigS1Id" )"
rigAssert "the RootSession mint is not an error" "$( rigIsError "$rigMintAnswer" )" no
rigAssert "the mint returned the session's id and token" "$( [ -n "$rigS1Id" ] && [ -n "$rigS1Token" ] && printf yes || printf no )" yes
rigAssert "the session's folder is the one the mint registered" "$( [ -d "$( rigSessionDir "$rigS1Ws" "$rigS1Id" )" ] && printf yes || printf no )" yes
rigAssert "the token mint printed stays in that folder, beside the chat file" \
	"$( [ -s "$( rigSessionDir "$rigS1Ws" "$rigS1Id" )/root-session.token" ] && IFS= read -r rigS1Kept < "$( rigSessionDir "$rigS1Ws" "$rigS1Id" )/root-session.token" ; printf '%s' "${rigS1Kept:-}" )" "$rigS1Token"
rigAssert "the served first message is not an error" "$( rigIsError "$rigSendAnswer" )" no
rigAssert "the chat file is in the session's own folder" "$( [ -f "$rigS1Chat" ] && printf yes || printf no )" yes
rigAssert "it holds exactly one block from its first message" "$( rigHeaders "$rigS1Chat" )" 1
rigAssert "the header is <time> <from> -> <to>:, from the member the served call runs as" "$( rigHeader "$rigS1Chat" 1 )" "magic-coordinator -> all:"
rigAssert "the body is the first message, whole" "$( rigBody "$rigS1Chat" 1 )" "$rigS1Body"
rigAssert "the index line carries the ts and conversation Slack gave the copy" "$( rigIndex "$rigS1Chat" 1 )" "1 1760000000.000101 CRIG00001:1760000000.000101 own 1 -"
rigAssert "the external copy was made: Slack was called once" "$( rigSlackCalls "$rigS1Sc" )" 1
rigAssert "the payload holds the message" "$( rigCount "$rigS1Sc/post.1" "$rigS1Body" )" 1
rigAssert "and the author line it always had" "$( rigCount "$rigS1Sc/post.1" '→' )" 1
rigAssert "the payload never carries the chat file's own header" "$( rigCount "$rigS1Sc/post.1" ' -> all:' )" 0
rigAssert "the workspace holds exactly one session chat file" "$( rigChats "$rigS1Ws" | LC_ALL=C grep -c . )" 1
rigAssert "and it is this session's" "$( rigChats "$rigS1Ws" )" "$rigS1Chat"
rigAssert "its body is recorded in that file and nowhere else in the workspace" "$( rigHolders "$rigS1Ws" "$rigS1Body" )" "$rigS1Chat"
rigAssert "the send log is not a second record: it carries no body" "$( rigHolders "$rigS1Ws" "$rigS1Body" | LC_ALL=C grep -c 'comms-slack-send' )" 0
rigAssert "the root session got no spawn record" "$( rigSpawnRecords "$rigS1Ws" )" 0
rigAssert "and opened no session thread" "$( rigThreadFile "$rigS1Ws" "$rigS1Id" )" none

## ---- S2 and S3: one file, two kinds; the no-external-channel message alone in it ----
echo "-- S2/S3: one chat file holds a console message with no channel and the member's own Slack copy --"
rigS2="$rigTmp/s2"
rigS2Ws="$rigS2/ws"
rigS2Sc="$rigS2/slack"
rigS2Session="rig-chat-s2"
rigS2Local="RIG-CONSOLE-MESSAGE"
rigS2Slack="RIG-SLACK-MESSAGE"
rigS2Chat="$( rigChatFile "$rigS2Ws" "$rigS2Session" )"
mkdir -p "$rigS2Ws/.local/.agents" "$rigS2Ws/.local/temp" "$rigS2Ws/.local/agents/sessions/$rigS2Session" \
	"$rigS2Ws/.local/agents/spawned/$rigS2Session" "$rigS2Ws/.local/agents/pending" "$rigS2Sc" \
	|| rigRefuse "cannot make the S2 workspace"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigS2Ws/.local/.agents/magic-team.agent.env"
## A session the console may leave a message for: a recorded run of it, and its own folder with no thread.
printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: rig\nworkspace: rigws\nowner: magic-coordinator\nstatus: spawn-succeeded\nstarted-at: 2026-10-13 10:00 +0300\nresolved-at: 2026-10-13 10:30 +0300\n---\n\n# Spawn session: %s\n' \
	"$rigS2Session" "$rigS2Session" "$rigS2Session" > "$rigS2Ws/.local/agents/spawned/$rigS2Session/$rigS2Session.spawn.md"
printf '%s\n' "$rigS2Local" > "$rigS2/message"

rigPre=()
rigDirect(){ ## scenario, then the tool's arguments -- one call from the rig workspace, no console and no host env
	( cd "$rigS2Ws" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" MMDAPP="$rigS2Ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_READER=off RIG_SCENARIO="$1" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigRigTool" "${@:2}" )
}
rigWaitOut(){ ## output basename -- one chat:-only Wait, in the session, at its own bound of zero
	rigPre=( "MDAT_SESSION_ID=$rigS2Session" )
	rigDirect "$rigS2Sc" --wait-for-input magic-coordinator --wait-source "chat:$rigS2Session" --wait-timeout 0 \
		> "$rigS2/$1.out" 2> "$rigS2/$1.err"
	printf '%s' "$?" > "$rigS2/$1.rc"
	rigPre=()
}

## The reader's pointer starts before the message: first contact with an empty file is block 0, so the message
## that follows is new to the member and its own Wait must return it.
rigWaitOut before
rigAssert "the session's Wait reads its empty chat file and returns TIMEOUT" "$( head -n 1 "$rigS2/before.out" ):$( cat "$rigS2/before.rc" )" "WAIT-RESULT: TIMEOUT:0"

## S3: the console's message, with NO external channel.
rigPre=()
rigDirect "$rigS2Sc" --manager-session-message --session-id "$rigS2Session" < "$rigS2/message" > "$rigS2/local.out" 2> "$rigS2/local.err"
rigS2LocalRc=$?
rigAssert "the console's message succeeds" "$rigS2LocalRc" 0
rigAssert "its row says it was recorded in the chat file, as a block" "$( LC_ALL=C awk -F'\t' '{ print $1, $2, $3, $4, $5, $6 }' "$rigS2/local.out" )" "message $rigS2Session $rigConsole all chat-file 1"
rigAssert "a note says nothing is posted and the members read it there" "$( LC_ALL=C grep -c "session $rigS2Session has no Slack thread, so the message is recorded in its chat file only (block 1) and nothing is posted; its members read it there" "$rigS2/local.err" )" 1
rigAssert "no Slack call is made for a message with no external channel" "$( rigSlackCalls "$rigS2Sc" )" 0
rigAssert "no inbox file is left for a writer" "$( ls "$( rigSessionDir "$rigS2Ws" "$rigS2Session" )/chat.inbox" 2> /dev/null | LC_ALL=C grep -c '\.msg$' || : )" 0
rigAssert "the message is recorded in the session's chat file" "$( [ -f "$rigS2Chat" ] && printf yes || printf no )" yes
rigAssert "one block, from the person at the console, to all" "$( rigHeaders "$rigS2Chat" ):$( rigHeader "$rigS2Chat" 1 )" "1:$rigConsole -> all:"
rigAssert "its body is the message, whole" "$( rigBody "$rigS2Chat" 1 )" "$rigS2Local"
rigAssert "its index line has no ts, the conversation local, and the console as its origin" "$( rigIndex "$rigS2Chat" 1 )" "1 - local console 1 -"
rigAssert "the message body is in the chat file and in no other file of the workspace" "$( rigHolders "$rigS2Ws" "$rigS2Local" )" "$rigS2Chat"

## S3: the session's own reader serves it from that file, once.
rigWaitOut after-local
rigAssert "the session's Wait returns the message RECEIVED" "$( head -n 1 "$rigS2/after-local.out" ):$( cat "$rigS2/after-local.rc" )" "WAIT-RESULT: RECEIVED:0"
rigAssert "it says the message arrived on the local conversation" "$( rigCount "$rigS2/after-local.out" '^# arrived on: local$' )" 1
rigAssert "it carries the message read from the chat file" "$( rigCount "$rigS2/after-local.out" "$rigS2Local" )" 1
rigWaitOut after-local-again
rigAssert "the next Wait returns TIMEOUT: the record is delivered once, never twice" \
	"$( head -n 1 "$rigS2/after-local-again.out" ):$( rigCount "$rigS2/after-local-again.out" "$rigS2Local" )" "WAIT-RESULT: TIMEOUT:0"

## S2: the same session, the member's own Slack send -- the other kind.
rigPre=( "MDAT_SESSION_ID=$rigS2Session" )
rigDirect "$rigS2Sc" --slack-send-message magic-coordinator magic-team "$rigS2Slack" > "$rigS2/slack.out" 2> "$rigS2/slack.err"
rigS2SlackRc=$?
rigPre=()
rigAssert "the member's Slack send succeeds" "$rigS2SlackRc" 0
rigAssert "the external copy is made: Slack was called once" "$( rigSlackCalls "$rigS2Sc" )" 1
rigAssert "the same chat file now holds BOTH kinds, two blocks" "$( rigHeaders "$rigS2Chat" )" 2
rigAssert "block 2 is the member's Slack send, from the member, to all" "$( rigHeader "$rigS2Chat" 2 )" "magic-coordinator -> all:"
rigAssert "its body is the Slack message, whole" "$( rigBody "$rigS2Chat" 2 )" "$rigS2Slack"
rigAssert "its index line carries the ts and the conversation:thread the copy got" "$( rigIndex "$rigS2Chat" 2 )" "2 1760000000.000101 CRIG00001:1760000000.000101 own 4 -"
rigAssert "one index line a block" "$( rigIndexCount "$rigS2Chat" )" 2
rigAssert "the two kinds differ where they must: ts, conversation, origin" \
	"$( LC_ALL=C awk -F'\t' '{ print $2, $3, $4 }' "$rigS2Chat.index" | LC_ALL=C tr '\n\t' '/ ' )" "- local console/1760000000.000101 CRIG00001:1760000000.000101 own/"
rigAssert "one session chat file and no per-kind file" "$( rigChats "$rigS2Ws" | LC_ALL=C grep -c . )" 1
rigAssert "it is the session's one file, whatever the kind" "$( rigChats "$rigS2Ws" )" "$rigS2Chat"
rigAssert "the Slack body is in that file and in no other file of the workspace" "$( rigHolders "$rigS2Ws" "$rigS2Slack" )" "$rigS2Chat"
rigAssert "the send log is not a second record: it carries no body" "$( rigHolders "$rigS2Ws" "$rigS2Slack" | LC_ALL=C grep -c 'comms-slack-send' )" 0
rigAssert "the Slack copy's payload holds the body" "$( rigCount "$rigS2Sc/post.1" "$rigS2Slack" )" 1
rigAssert "and the author line it always had" "$( rigCount "$rigS2Sc/post.1" '→' )" 1
rigAssert "and never the chat file's own header" "$( rigCount "$rigS2Sc/post.1" ' -> all:' )" 0
rigAssert "no session thread was opened: the copy went to the channel named" "$( rigThreadFile "$rigS2Ws" "$rigS2Session" )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CHAT ONE FILE (F2.1) CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_ONE_FILE: OK (%d assertions, offline)\n' "$rigPassCount"
