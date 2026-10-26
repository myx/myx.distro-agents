#!/usr/bin/env bash
## AgentsSessionPrintbackCheck — behavioural check on the root-native printback channel of the root-harness epic
## (F2.2): a session's own channel kind, named by its communication-channel-id, whose message prints to the
## tool's output and is recorded in the session's one chat file, and which opens no Slack call and no thread.
## Held, one case per statement:
##
##   S1. The kind EXISTS and is NAMED BY ITS communication-channel-id. `printback` is a service of the
##       communication-channel-id abstraction beside slack, email and telegram; `printback:<session>` splits
##       into that service and the session it names; the canonical channel-id of a session is
##       `printback:<session>`; and a channel declared on the kind resolves to that same value. The served call
##       that carries the minted root session is the one that sends on it.
##
##   S2. A MESSAGE ON IT PRINTS TO THE TOOL'S OUTPUT and is recorded in the session's one chat file. A real
##       `--intern-mcp-server --run` process mints the root session; a second one adopts it with the id and
##       token mint printed (so it CARRIES the root session) and serves
##       `DistroAgentsSlack --slack-send-message magic-tester printback:<session> --address-to magic-coordinator`
##       with the body: the served result carries the message printed, the channel-id and the block number, and
##       beside it the session's new floor names the kind (`# via printback`); the session folder the mint made
##       holds `session.chat` with that one block, header, body and the index line whose conversation is the
##       channel-id. In a second workspace, the message is put there by a direct send and the session's own Wait
##       (`chat:<session>`) returns it RECEIVED, `# arrived on: printback`, from that file, once.
##
##   S3. It opens NO SLACK CALL AND NO THREAD. The fake curl is never reached (there is no `calls` file at all),
##       no `session.thread` is opened, no outbox or inbox is left, no Slack send log is written, exactly one
##       `session.chat` exists in the workspace, and the message body is in that file and nowhere else in it.
##
## THE RIG ORIGIN. The server and the direct calls run the package COPY in this rig (never the tree under test):
## `origin/myx/myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked READ-ONLY
## beside it -- never a mute stand-in. The workspace is the rig's own folder.
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee), an `id` stub
## names the person at the console, every workspace is a folder of the rig's own, and no model CLI is started.
##
## Red recipe: run this check against a COPY of the RECEIVED tree -- the tree before F2.2 -- with only this check
## added to its `sh-test`. Nothing else is changed. The `printback` service does not exist, so S1's kind
## assertions fail (the driver list, the known service, the split, the canonical id, the declared resolution);
## `printback:<session>` is then an address the send operation refuses as no Slack conversation, so the served
## send is an error, no session chat file is made and the direct send is refused too -- S2 fails at the print,
## the record and the read. S3's no-Slack/no-thread assertions pass trivially there, as they must: the red is
## the KIND ABSENT (or the print path posting instead of printing), never a check that did not run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigChatInclude="$rigHere/session/AgentsTools.SessionChat.include"
rigChannelsInclude="$rigHere/comms/AgentsTools.CommsChannel.include"
rigPrintbackInclude="$rigHere/comms/AgentsTools.CommsPrintback.include"
rigFixtures="$rigPackage/sh-test/check-fixtures"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigChatInclude" "$rigChannelsInclude" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionPrintbackCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigBin="$rigTmp/bin"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigOrigin/myx" "$rigBin" "$rigHome" "$rigSkills/magic-coordinator" "$rigSkills/magic-tester" \
	|| rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
rigRigPackage="$rigOrigin/myx/myx.distro-agents"
rigRigTool="$rigRigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRigChannelsInclude="$rigRigPackage/sh-lib/comms/AgentsTools.CommsChannel.include"
rigRigPrintbackInclude="$rigRigPackage/sh-lib/comms/AgentsTools.CommsPrintback.include"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
## The person at the console, fixed: the same account on every host this check runs on, so a message's `from`
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
printf -- '---\nname: magic-tester\n---\nrig sending member\n' > "$rigSkills/magic-tester/magic-tester.basic.md"

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
	[ -s "$rigStartedAnswer" ] || {
		echo "-- $2: the server answered no initialize, so its stderr follows --" >&2
		sed 's/^/    /' "$1.err" >&2
		rigRefuse "$2: the server never started"
	}
}
rigRootCall(){ ## id, operation -- one RootSession request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}\n' "$1" "$2"
}
rigRootAdopt(){ ## id, session, token -- the RootSession adopt that makes a new server carry the minted session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"adopt","session":"%s","token":"%s"}}}\n' "$1" "$2" "$3"
}
rigPrintbackCall(){ ## id, session, body -- one served printback send, from magic-tester to magic-coordinator
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"DistroAgentsSlack","arguments":{"operation":"--slack-send-message","args":["magic-tester","printback:%s","--address-to","magic-coordinator","%s"]}}}\n' "$1" "$2" "$3"
}

## ---- the chat file and the printback kind as the check reads them ----
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
rigTextCount(){ ## text, then the grep options and the pattern -- matching lines, 0 when none
	local rigTextCountText="$1"
	shift
	rigTextCountText="$( printf '%s\n' "$rigTextCountText" | LC_ALL=C grep -c "$@" 2> /dev/null )" || :
	printf '%s' "${rigTextCountText:-0}"
}
rigThreadFile(){ ## workspace, session id -- `thread` when it has a session.thread, `none` otherwise
	[ ! -f "$( rigSessionDir "$1" "$2" )/session.thread" ] && printf none || printf thread
}
rigExists(){ ## path -- `yes` when it is there, `no` otherwise
	[ -e "$1" ] && printf yes || printf no
}
rigSlackReached(){ ## scenario -- `file` when the fake curl was reached at all, `none` when it never was
	[ -f "$1/calls" ] && printf file || printf none
}
rigDirectIn(){ ## workspace, scenario, session id (empty: none), then the tool's arguments -- one call from that workspace
	local rigDirectWs="$1" rigDirectSc="$2" rigDirectId="$3"
	shift 3
	( cd "$rigDirectWs" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" MMDAPP="$rigDirectWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_READER=off RIG_SCENARIO="$rigDirectSc" ${rigDirectId:+MDAT_SESSION_ID=$rigDirectId} \
		bash "$rigRigTool" "$@" )
}

## ---- the kind, as the rig's own tree declares it: S1's names ----
rigKindDrivers(){ ## the driver registry, one line, spaced
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; AgentsToolsCommsChannelServices | LC_ALL=C tr '\n' ' ' )
}
rigKindKnown(){ ## service -- yes when the abstraction names it a service
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; AgentsToolsCommsChannelServiceKnown "$1" && printf yes || printf no )
}
rigKindParse(){ ## channel-id -- `<service>|<address>|`, empty where it is no channel-id
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; AgentsToolsCommsChannelParse "$1" | LC_ALL=C tr '\n' '|' )
}
rigKindChannelId(){ ## session -- the canonical channel-id of its printback channel
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; [ ! -f "$rigRigPrintbackInclude" ] || . "$rigRigPrintbackInclude" ; AgentsToolsCommsPrintbackChannelId "$1" 2> /dev/null )
}
rigKindSession(){ ## channel-id -- the session it names
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; [ ! -f "$rigRigPrintbackInclude" ] || . "$rigRigPrintbackInclude" ; AgentsToolsCommsPrintbackSession "$1" 2> /dev/null )
}
rigKindDeclared(){ ## session -- a declared channel on the kind resolves to its channel-id
	( MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigS1Ws" ; . "$rigRigChannelsInclude" ; printf 'rig-printback\tprintback\t%s\n' "$1" | AgentsToolsCommsChannelOrderDeclares rig-printback )
}

## ---- S1 and S2: the kind, and a message on it from a server that carries the minted root session ----
echo "-- S1/S2: a root session minted through RootSession, adopted, and sent on its printback channel --"
rigS1="$rigTmp/s1"
rigS1Ws="$rigS1/ws"
rigS1Sc="$rigS1/slack"
rigS1Wire="$rigS1/wire"
rigS1Wire2="$rigS1/wire2"
rigS1Body="RIG-PRINTBACK-MESSAGE"
mkdir -p "$rigS1Ws/.local/.agents" "$rigS1Sc" || rigRefuse "cannot make the S1 workspace"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigS1Ws/.local/.agents/magic-team.agent.env"

## The mint: the server that will be gone before the message.
: > "$rigS1Wire"
rigServerWire="$rigS1Wire"
{
	rigSend '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' 1
	rigSend "$( rigRootCall 2 mint )" 2
} | rigServer "$rigS1Wire" "$rigS1Ws" "$rigS1Sc"
rigStarted "$rigS1Wire" "the mint server"

rigMintAnswer="$( rigReply "$rigS1Wire" 2 )"
rigMintText="$( rigText "$rigMintAnswer" )"
rigS1Id="$( rigFieldOf "$rigMintText" SESSION )"
rigS1Token="$( rigFieldOf "$rigMintText" TOKEN )"
rigAssert "the RootSession mint is not an error" "$( rigIsError "$rigMintAnswer" )" no
rigAssert "the mint returned the session's id and token" "$( [ -n "$rigS1Id" ] && [ -n "$rigS1Token" ] && printf yes || printf no )" yes
rigS1Chat="$( rigChatFile "$rigS1Ws" "$rigS1Id" )"

## S1: the kind exists, and the channel-id names it.
rigAssert "the driver registry carries the root-native printback kind" "$( rigKindDrivers )" "slack email telegram printback "
rigAssert "printback is a known service of the channel-id abstraction" "$( rigKindKnown printback )" yes
rigAssert "printback:<session> splits into the kind and the session it names" "$( rigKindParse "printback:$rigS1Id" )" "SERVICE=printback|ADDRESS=$rigS1Id|"
rigAssert "the canonical channel-id of a session's printback channel names the kind" "$( rigKindChannelId "$rigS1Id" )" "printback:$rigS1Id"
rigAssert "and it names that session" "$( rigKindSession "printback:$rigS1Id" )" "$rigS1Id"
rigAssert "a channel declared on the kind resolves to the same channel-id" "$( rigKindDeclared "$rigS1Id" )" "printback:$rigS1Id"

## The send: a second server adopts the minted session, so it CARRIES the root session, and serves the printback
## message as magic-tester, addressed to the session's own member. This member's first contact with the file is
## here, before the message: what follows is new to it, and the served call prints it as the session's new floor.
rigDirectIn "$rigS1Ws" "$rigS1Sc" "$rigS1Id" --wait-for-input magic-coordinator --wait-source "chat:$rigS1Id" --wait-timeout 0 \
	> "$rigS1/before.out" 2> "$rigS1/before.err"
printf '%s' "$?" > "$rigS1/before.rc"
rigAssert "the session's Wait reads its empty chat file and returns TIMEOUT" "$( head -n 1 "$rigS1/before.out" ):$( cat "$rigS1/before.rc" )" "WAIT-RESULT: TIMEOUT:0"

: > "$rigS1Wire2"
rigServerWire="$rigS1Wire2"
{
	rigSend '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' 1
	rigSend "$( rigRootAdopt 2 "$rigS1Id" "$rigS1Token" )" 2
	rigSend "$( rigPrintbackCall 3 "$rigS1Id" "$rigS1Body" )" 3
} | rigServer "$rigS1Wire2" "$rigS1Ws" "$rigS1Sc"
rigStarted "$rigS1Wire2" "the printback server"

rigAdoptAnswer="$( rigReply "$rigS1Wire2" 2 )"
rigSendAnswer="$( rigReply "$rigS1Wire2" 3 )"
rigSendText="$( rigText "$rigSendAnswer" )"
rigSendFloor="$( rigValue "$rigSendAnswer" result.content.1.text )"
rigAssert "the adopting server carries the minted session" "$( rigIsError "$rigAdoptAnswer" )" no
rigAssert "the served printback send is not an error" "$( rigIsError "$rigSendAnswer" )" no
rigAssert "the send prints the message to the tool's output" "$( rigTextCount "$rigSendText" -x -F -- "$rigS1Body" )" 1
rigAssert "the output names the channel-id the kind is named by" "$( rigTextCount "$rigSendText" -F -- "printback:$rigS1Id" )" 1
rigAssert "the output says the block it recorded" "$( rigTextCount "$rigSendText" -- '^# printback: .* block 1 of the session chat file; nothing is posted' )" 1
rigAssert "the output names who the message is from and to" "$( rigTextCount "$rigSendText" -x -F -- 'magic-tester -> magic-coordinator:' )" 1
rigAssert "the output names no path" "$( printf '%s\n' "$rigSendText" | LC_ALL=C grep -c '/.*/.*/' )" 0
rigAssert "the served call also prints the session's new floor behind it" "$( rigTextCount "$rigSendFloor" -F -- '# via printback' )" 1
rigAssert "and that floor line is the message" "$( rigTextCount "$rigSendFloor" -x -F -- "$rigS1Body" )" 1

## S2: the one chat file, the block, and the index line that names the kind's conversation.
rigAssert "the session's chat file is the one the mint registered" "$( [ -f "$rigS1Chat" ] && printf yes || printf no )" yes
rigAssert "it holds exactly one block from the printback message" "$( rigHeaders "$rigS1Chat" )" 1
rigAssert "the header names the sender and the addressee" "$( rigHeader "$rigS1Chat" 1 )" "magic-tester -> magic-coordinator:"
rigAssert "the body is the message, whole" "$( rigBody "$rigS1Chat" 1 )" "$rigS1Body"
rigAssert "the index names the conversation as the channel-id of the kind, with no ts" "$( rigIndex "$rigS1Chat" 1 )" "1 - printback:$rigS1Id printback 1 -"
rigAssert "one index line for the one block" "$( rigIndexCount "$rigS1Chat" )" 1

## S3: no Slack call, no thread, and no second record anywhere.
echo "-- S3: it opens no Slack call and no thread --"
rigAssert "no Slack call is made: the fake curl is never reached at all" "$( rigSlackReached "$rigS1Sc" )" none
rigAssert "the printback kind opened no session thread" "$( rigThreadFile "$rigS1Ws" "$rigS1Id" )" none
rigAssert "it left no outbox: nothing was posted" "$( rigExists "$( rigSessionDir "$rigS1Ws" "$rigS1Id" )/chat.outbox" )" no
rigAssert "it left no inbox: nothing was handed off" "$( rigExists "$( rigSessionDir "$rigS1Ws" "$rigS1Id" )/chat.inbox" )" no
rigAssert "it wrote no Slack send log" "$( find "$rigS1Ws" -name 'comms-slack-send*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "no spawn record was made for the root session" "$( find "$rigS1Ws/.local/agents/spawned" -name '*.spawn.md' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "the workspace holds exactly one session chat file" "$( rigChats "$rigS1Ws" | LC_ALL=C grep -c . )" 1
rigAssert "and it is this session's" "$( rigChats "$rigS1Ws" )" "$rigS1Chat"
rigAssert "the message body is recorded in that file and in no other file of the workspace" "$( rigHolders "$rigS1Ws" "$rigS1Body" )" "$rigS1Chat"

## ---- S2: the session's own reader serves the message from that one file, once ----
echo "-- S2: the session's own Wait reads the printback message from its chat file --"
rigS2="$rigTmp/s2"
rigS2Ws="$rigS2/ws"
rigS2Sc="$rigS2/slack"
rigS2Session="rig-printback-session"
rigS2Body="RIG-PRINTBACK-WAIT"
rigS2Chat="$( rigChatFile "$rigS2Ws" "$rigS2Session" )"
mkdir -p "$rigS2Ws/.local/.agents" "$rigS2Ws/.local/temp" "$rigS2Ws/.local/agents/sessions/$rigS2Session" "$rigS2Sc" \
	|| rigRefuse "cannot make the S2 workspace"
rigWaitOut(){ ## output basename -- one chat:-only Wait, in the session, at its own bound of zero
	rigDirectIn "$rigS2Ws" "$rigS2Sc" "$rigS2Session" --wait-for-input magic-coordinator --wait-source "chat:$rigS2Session" --wait-timeout 0 \
		> "$rigS2/$1.out" 2> "$rigS2/$1.err"
	printf '%s' "$?" > "$rigS2/$1.rc"
}
rigWaitOut before
rigAssert "the session's Wait reads its empty chat file and returns TIMEOUT" "$( head -n 1 "$rigS2/before.out" ):$( cat "$rigS2/before.rc" )" "WAIT-RESULT: TIMEOUT:0"

## The direct send: no server, so no session floor is drained beside it; the record and the Wait are what this case holds.
rigDirectIn "$rigS2Ws" "$rigS2Sc" "" --slack-send-message magic-tester "printback:$rigS2Session" --address-to magic-coordinator "$rigS2Body" \
	> "$rigS2/send.out" 2> "$rigS2/send.err"
rigS2SendRc=$?
rigAssert "the direct printback send succeeds" "$rigS2SendRc" 0
rigAssert "its output prints the message" "$( rigCount "$rigS2/send.out" "^$rigS2Body\$" )" 1
rigAssert "it wrote the block into the session's one chat file" "$( rigHeaders "$rigS2Chat" )" 1
rigAssert "and named the channel as its conversation" "$( rigIndex "$rigS2Chat" 1 )" "1 - printback:$rigS2Session printback 1 -"
rigWaitOut after
rigAssert "the session's Wait returns the printback message RECEIVED" "$( head -n 1 "$rigS2/after.out" ):$( cat "$rigS2/after.rc" )" "WAIT-RESULT: RECEIVED:0"
rigAssert "it says the message arrived on the printback kind" "$( rigCount "$rigS2/after.out" '^# arrived on: printback$' )" 1
rigAssert "it carries the message read from the chat file" "$( rigCount "$rigS2/after.out" "$rigS2Body" )" 1
rigWaitOut after-again
rigAssert "the next Wait returns TIMEOUT: the record is delivered once, never twice" \
	"$( head -n 1 "$rigS2/after-again.out" ):$( rigCount "$rigS2/after-again.out" "$rigS2Body" )" "WAIT-RESULT: TIMEOUT:0"
rigAssert "this send reached no Slack either" "$( rigSlackReached "$rigS2Sc" )" none
rigAssert "and opened no session thread" "$( rigThreadFile "$rigS2Ws" "$rigS2Session" )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION PRINTBACK (F2.2) CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_PRINTBACK: OK (%d assertions, offline)\n' "$rigPassCount"
