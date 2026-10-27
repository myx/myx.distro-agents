#!/usr/bin/env bash
## AgentsSessionAddressFirstCheck — behavioural check on address first (F3.2 of the root-harness epic),
## run rather than read. Held, one case per statement and per channel kind:
##
##   S1. A MESSAGE THAT NAMES AN ADDRESS GOES TO THAT ADDRESS, WHATEVER THE SESSION'S KIND, AND IS
##       RECORDED. In each of the three workspaces -- a root session minted under `none`, `track` and
##       `full` -- the same two addressed messages go where they name and nowhere else: to
##       `human-owner` (a team conversation that is not the session's own channel; posted top-level
##       there) and to `printback:<session>` (the root-native printback channel, which prints and
##       records and makes no Slack call). Each message's block is in the session's one chat file and
##       its index line names that route.
##
##   S2. A MESSAGE THAT NAMES NO ADDRESS IS RECORDED ON THE SESSION'S OWN CHANNEL -- printback for
##       `none`, the session's tooling thread for `track`, the session thread for `full` -- AND NOT
##       ONLY IN THE MODEL'S CONTEXT. With no `to` the served SendMessage of the root is sent, not
##       refused: `none` prints it and records it as a printback block, `track` posts it into the
##       session's recorded tooling thread and records it, `full` posts it into the session thread and
##       records it. The body is read back from the chat file, not from the result.
##
##   S3. THE RECORD SAYS WHICH WAY THE MESSAGE WENT. Each block's index line carries the conversation
##       it went to and its origin (`printback` for the printback channel, `own` for a Slack send),
##       and each Slack send's own log line names the target and the channel. The printback send
##       writes no Slack send log (F2.2): its block is the record that says where it went.
##
## THE RIG ORIGIN. Every call runs the package COPY in this rig (never the tree under test):
## `origin/myx/myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked
## READ-ONLY beside it -- never a mute stand-in. Each of the three workspaces is the rig's own folder,
## its one session is minted by a real `--intern-mcp-server --run` process (RootSession) and served
## by a second process that adopts it, as the root's own session env makes it; `track` and `full` get
## their session's channel from a real spawn proxy run (a fake console records the dispatch and starts
## no model), exactly as a helper's arrival opens it.
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee; it
## logs every call with the channel and the thread of a post and answers a top-level post with no
## thread_ts, as Slack does), every workspace is a folder of the rig's own, and no model CLI is
## started.
##
## Red recipe: run this check against a COPY of the RECEIVED tree -- everything before F3.2 -- with
## only this check and its curl fixture added to it. Nothing else is changed.
##
##   cp -Rp pristine/myx.distro-agents red/origin/myx/myx.distro-agents
##   ln -s <real myx.distro-system> red/origin/myx/myx.distro-system        # and myx.distro-.local
##   cp origin/.../sh-test/comms/AgentsSessionAddressFirstCheck.test.sh red/origin/.../sh-test/
##   cp origin/.../sh-test/check-fixtures/session-address-first.curl.stub.sh red/origin/.../sh-test/check-fixtures/
##   MDLT_ORIGIN=$PWD/red/origin MMDAPP=$PWD/workspace MDAT_SKILLSET_ROOT=<skillset> \
##     bash red/origin/myx/myx.distro-agents/sh-test/comms/AgentsSessionAddressFirstCheck.test.sh
##
## Red is S2 first, on the received tree's own reason: a served SendMessage with no `to` only knew the
## session thread, and a `none` or `track` session has none, so the call is refused with
## `ERROR: both to and message are required, and one of them was empty. Nothing was sent.` -- the
## message is recorded nowhere, and every S2/S3 assertion for those two kinds fails. `full` already
## defaults to its session thread, and S1's addressed messages already reach their addresses, so those
## cases pass on the received tree as the guards they are. Recorded run: 18 of 86 assertions fail, in
## that order.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigRootMember="magic-coordinator"
rigHelperMember="rig-helper"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigFixtures/session-address-first.curl.stub.sh" "$rigFixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionAddressFirstCheck )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigBin="$rigTmp/bin"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigOrigin/myx" "$rigBin" "$rigHome" "$rigSkills" || rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
rigRigPackage="$rigOrigin/myx/myx.distro-agents"
rigRigTool="$rigRigPackage/sh-scripts/DistroAgentsTools.fn.sh"
for rigMember in "$rigRootMember" "$rigHelperMember" ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
done
cp "$rigFixtures/session-address-first.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"

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
rigTextCount(){ ## text, then the grep options and the pattern -- matching lines, 0 when none
	local rigTextCountText="$1"
	shift
	rigTextCountText="$( printf '%s\n' "$rigTextCountText" | LC_ALL=C grep -c "$@" 2> /dev/null )" || :
	printf '%s' "${rigTextCountText:-0}"
}
rigDash(){ ## value -- `dash` when it is the index's no-value mark, `value` otherwise
	case "$1" in -) printf dash ;; *) printf value ;; esac
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
rigFirstLine(){ ## text -- its first line
	printf '%s\n' "$1" | LC_ALL=C sed -n '1p'
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
}
## One real server process: its stdin read to the end, its wire kept. The root process carries no run of
## its own: it has no MDAT_SESSION_THREAD, no MDAT_SESSION_ID and no spawn agent, and a served call adopts
## the minted session, as the root's own server does.
rigServer(){ ## wire file, workspace, scenario
	mkdir -p "$2/.local/temp" "$2/.local/.agents" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN -u MDAT_SESSION_THREAD \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" PATH="$rigBin:$PATH" \
		bash "$rigRigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigSend(){ ## json line, id -- write it to the server, wait until that request is answered
	printf '%s\n' "$1"
	rigWaitAt=0
	while ! LC_ALL=C grep -q "\"id\":$2," "$rigServerWire" 2> /dev/null && [ "$rigWaitAt" -lt 4000 ] ; do
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
rigInit(){ printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' ; }
rigRootCall(){ ## id, operation -- one RootSession request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}' "$1" "$2"
}
rigRootAdopt(){ ## id, session, token -- the RootSession adopt that makes a new server carry the minted session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"adopt","session":"%s","token":"%s"}}}' "$1" "$2" "$3"
}
rigSendMessageCall(){ ## id, arguments json -- one served SendMessage
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"SendMessage","arguments":%s}}' "$1" "$2"
}

## ---- the session's own records and the chat file, as the check reads them ----
rigSessionDir(){ printf '%s' "$1/.local/agents/sessions/$2" ; }
rigChatFile(){ printf '%s/session.chat' "$( rigSessionDir "$1" "$2" )" ; }
rigKindOf(){ ## workspace, session -- the recorded kind, `none` when no record
	local rigKindValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/root-session.kind" ] || IFS= read -r rigKindValue < "$( rigSessionDir "$1" "$2" )/root-session.kind" || :
	printf '%s' "${rigKindValue:-none}"
}
rigThreadOf(){ ## workspace, session, record name -- the recorded thread, `none` when absent
	local rigThreadValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/$3" ] || IFS= read -r rigThreadValue < "$( rigSessionDir "$1" "$2" )/$3" || :
	printf '%s' "${rigThreadValue:-none}"
}
rigHeaders(){ ## chat file -- how many header lines it holds, `no-file` when there is none
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$1"
}
rigBody(){ ## chat file, N -- the body of the Nth block, blank lines trimmed at its end
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; inBlock = ( count == want ) ; if ( inBlock ) { next ; } }
		inBlock { lines[++n] = $0 }
		END { while ( n > 0 && lines[n] == "" ) { n-- ; } for ( i = 1 ; i <= n ; i++ ) { print lines[i] ; } }' "$1"
}
rigBlockOf(){ ## chat file, fixed text -- the number of the one block whose body holds it
	[ -f "$1" ] || return 0
	LC_ALL=C awk -v marker="$2" '
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; next }
		count > 0 && index($0, marker) > 0 { print count ; exit }' "$1"
}
rigIndexField(){ ## chat file, N, field 1..6 -- that field of the block's index line
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$2" -v field="$3" '$1 == want { print $field ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigChats(){ ## workspace -- every session chat file in it, one a line
	find "$1/.local/agents/sessions" -name 'session.chat' -type f 2> /dev/null | LC_ALL=C sort || :
}
rigChatFilesWith(){ ## workspace, fixed text -- how many session chat files hold it
	local rigWithFound=0 rigWithFile
	for rigWithFile in "$1"/.local/agents/sessions/*/session.chat ; do
		[ -f "$rigWithFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigWithFile" && rigWithFound=$(( rigWithFound + 1 ))
	done
	printf '%s' "$rigWithFound"
}

## ---- the fake Slack, as the offline copy of every Slack call ----
rigCalls(){ ## scenario -- how many calls the fake curl was given, 0 when none
	[ -f "$1/calls" ] && LC_ALL=C grep -c . "$1/calls" 2> /dev/null || printf 0
}
rigPostCount(){ ## scenario, fixed text -- how many posted payloads hold the text
	local rigPostFile="" rigPostSeen=0
	for rigPostFile in "$1"/post.* ; do
		[ -f "$rigPostFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigPostFile" && rigPostSeen=$(( rigPostSeen + 1 ))
	done
	printf '%s' "$rigPostSeen"
}
rigPostBody(){ ## scenario, fixed text -- the first posted payload holding the text, `no-post` for none
	local rigPostFile=""
	for rigPostFile in "$1"/post.* ; do
		[ -f "$rigPostFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigPostFile" && { printf '%s' "$rigPostFile" ; return 0 ; }
	done
	printf 'no-post'
}
rigPostField(){ ## scenario, fixed text, json key -- the first value of that key in the payload holding the text
	local rigPostHit=""
	rigPostHit="$( rigPostBody "$1" "$2" )"
	[ "$rigPostHit" != "no-post" ] || { printf 'no-post' ; return 0 ; }
	LC_ALL=C sed -n 's/.*"'"$3"'":"\([^"]*\)".*/\1/p' "$rigPostHit" | head -1
}
rigLogFile(){ ## workspace -- the one monthly Slack send log, empty when there is none
	local rigLogFound=""
	for rigLogFound in "$1"/.local/agents/comms-slack-send.*.log ; do
		[ -f "$rigLogFound" ] && { printf '%s' "$rigLogFound" ; return 0 ; }
	done
	printf ''
}
rigLogCount(){ ## workspace -- how many lines the Slack send log holds, 0 when there is none
	local rigLogFiles=0 rigLogPath=""
	rigLogPath="$( rigLogFile "$1" )"
	[ -n "$rigLogPath" ] || { printf 0 ; return 0 ; }
	LC_ALL=C grep -c . "$rigLogPath" 2> /dev/null || printf 0
}
rigLogLine(){ ## workspace, target, channel, member (optional) -- the send log's line naming them, `none` when absent
	local rigLogPath=""
	rigLogPath="$( rigLogFile "$1" )"
	[ -n "$rigLogPath" ] || { printf 'no-log' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v wantTarget="$2" -v wantChannel="$3" -v wantMember="${4:-}" '($3 == wantTarget && $4 == wantChannel) && (wantMember == "" || $2 == wantMember) { print ; found = 1 ; exit } END { if ( ! found ) { print "no-such-line" ; } }' "$rigLogPath"
}

## ---- the rig's own workspaces, mint and spawn ----
rigMakeWorkspace(){ ## kind -- makes the workspace, its settings and its fake console
	local rigMakeKind="$1"
	rigWs="$rigTmp/ws-$rigMakeKind"
	rigScn="$rigTmp/scn-$rigMakeKind"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScn" || rigRefuse "cannot make the $rigMakeKind workspace"
	{
		printf 'ROOT_HARNESS_VERBOSITY=%s\n' "$rigMakeKind"
		printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n'
		## The tooling thread exists only where an event-track conversation is configured. `none` spawns no
		## helper and has no thread of either kind, exactly as F3.1 leaves it.
		[ "$rigMakeKind" = "none" ] || printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n'
	} > "$rigWs/.local/.agents/magic-team.agent.env"
	## The console the spawn proxy launches: --cli-configured and MDAT_SPAWN_LAUNCH_MARKER are the two names
	## it greps for before it launches anything. It records the dispatch and starts no model.
	printf '%s\n' '#!/usr/bin/env bash' '## --cli-configured stand-in: records the dispatch and marks the launch.' \
		'cat > "$RIG_SCENARIO/dispatch"' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
	chmod +x "$rigWs/DistroAgentsConsole.sh"
}
rigMint(){ ## workspace, scenario -- mints one session; keeps rigSession and rigToken
	local rigMintWs="$1" rigMintScn="$2" rigMintText=""
	rigServerWire="$rigTmp/wire-mint-${rigMintWs##*/}"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootCall 2 mint )" 2
	} | rigServer "$rigServerWire" "$rigMintWs" "$rigMintScn"
	rigStarted "$rigServerWire" "the mint server of ${rigMintWs##*/}"
	rigMintText="$( rigText "$( rigReply "$rigServerWire" 2 )" )"
	rigSession="$( rigFieldOf "$rigMintText" SESSION )"
	rigToken="$( rigFieldOf "$rigMintText" TOKEN )"
	[ -n "$rigSession" ] && [ -n "$rigToken" ] || rigRefuse "the RootSession mint printed no session id and token, so nothing below would be measured: $rigMintText"
}
rigSpawn(){ ## workspace, scenario, session -- a real spawn proxy run, fake console, no model
	local rigSpawnWs="$1" rigSpawnScn="$2" rigSpawnSession="$3" rigSpawnOut="$rigTmp/spawn-${rigSpawnWs##*/}.out"
	( cd "$rigSpawnWs" && env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigHome" MMDAPP="$rigSpawnWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigSpawnScn" RIG_CHAT="$rigSpawnScn/chat" \
		MDAT_SPAWN_SESSION_ID="$rigSpawnSession" MDAT_SPAWN_AGENT="$rigRootMember" \
		bash "$rigRigTool" --intern-op-agent-spawn-proxy "$rigHelperMember" --from-stdin --dispatch-doc:none \
			--context Agent --calling-member "$rigRootMember" --wait ) > "$rigSpawnOut" 2> "$rigSpawnOut.err" <<< "RIG-TASK dispatch a helper into the $rigSpawnSession session"
	rigSpawnRc=$?
	[ -f "$rigSpawnScn/dispatch" ] || rigRefuse "the fake console never received a dispatch in ${rigSpawnWs##*/}, so the session's channel was never opened: $( LC_ALL=C grep 'ERROR' "$rigSpawnOut" "$rigSpawnOut.err" 2> /dev/null | head -2 | LC_ALL=C tr '\n' ' ' )"
	rigSpawnSessionOut="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigSpawnOut" | head -1 )"
}
rigSendMessage(){ ## workspace, scenario, session, token, arguments json, label -- one served SendMessage from the root
	local rigSendWs="$1" rigSendScn="$2" rigSendSession="$3" rigSendToken="$4" rigSendArgs="$5" rigSendLabel="$6"
	rigServerWire="$rigTmp/wire-send-$rigSendLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootAdopt 2 "$rigSendSession" "$rigSendToken" )" 2
		rigSend "$( rigSendMessageCall 3 "$rigSendArgs" )" 3
	} | rigServer "$rigServerWire" "$rigSendWs" "$rigSendScn"
	rigStarted "$rigServerWire" "the root's $rigSendLabel send server"
	rigSendAnswer="$( rigReply "$rigServerWire" 3 )"
	rigSendText="$( rigText "$rigSendAnswer" )"
	rigSendErr="$( rigIsError "$rigSendAnswer" )"
}
rigOpDefaultSend(){ ## workspace, scenario, session, marker, label -- the send operation's own default, target `""`
	local rigOpWs="$1" rigOpScn="$2" rigOpSession="$3" rigOpMarker="$4" rigOpLabel="$5"
	( cd "$rigOpWs" && env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigHome" MMDAPP="$rigOpWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigOpScn" MDAT_SPAWN_SESSION_ID="$rigOpSession" \
		bash "$rigRigTool" --slack-send-message "$rigRootMember" "" --address-to "$rigHelperMember" --from-stdin ) \
		> "$rigTmp/op-default-$rigOpLabel.out" 2> "$rigTmp/op-default-$rigOpLabel.err" <<< "$rigOpMarker"
	rigOpRc=$?
	## The operation's own copy and its named fields are on its two streams: the Slack fields go to stderr
	## beside the rest of the send's diagnostics, and the printback copy is stdout.
	rigOpText="$( cat "$rigTmp/op-default-$rigOpLabel.out" "$rigTmp/op-default-$rigOpLabel.err" )"
}

## ============================== the three workspaces ==============================
## One loop, one case per kind, each held independently: the same four messages in every workspace, so
## S1 and S3 are shown whatever the kind, and S2 is shown against that kind's own channel.
for rigKind in none track full ; do
	echo "-- $rigKind: the session's own channel, an addressed message, and the record's route --"
	rigMakeWorkspace "$rigKind"
	rigMint "$rigWs" "$rigScn"
	rigKindSession="$rigSession"
	rigKindToken="$rigToken"
	rigKindChat="$( rigChatFile "$rigWs" "$rigKindSession" )"
	rigAssert "$rigKind: the mint records the channel kind" "$( rigKindOf "$rigWs" "$rigKindSession" )" "$rigKind"

	## THE SESSION'S OWN CHANNEL, as the kind names it: the printback channel-id for `none`, the recorded
	## tooling thread for `track`, the recorded session thread for `full`. `track` and `full` get theirs from
	## the spawn, exactly as a helper's arrival opens it; `none` opens no thread at all.
	case "$rigKind" in
		none)
			rigOwnChannel="printback:$rigKindSession"
			rigAssert "$rigKind: no session thread and no tooling thread were created" \
				"$( rigThreadOf "$rigWs" "$rigKindSession" session.thread )/$( rigThreadOf "$rigWs" "$rigKindSession" event-track.thread )" "none/none"
		;;
		track)
			rigSpawn "$rigWs" "$rigScn" "$rigKindSession"
			rigAssert "$rigKind: the spawn succeeds and opens the session's tooling thread" \
				"$rigSpawnRc:$( rigThreadOf "$rigWs" "$rigKindSession" event-track.thread | LC_ALL=C sed 's/:.*//' )" "0:CRIGTRACK"
			rigOwnChannel="$( rigThreadOf "$rigWs" "$rigKindSession" event-track.thread )"
			rigAssert "$rigKind: no session thread was created" "$( rigThreadOf "$rigWs" "$rigKindSession" session.thread )" "none"
		;;
		full)
			rigSpawn "$rigWs" "$rigScn" "$rigKindSession"
			rigAssert "$rigKind: the spawn succeeds and opens the session's team-channel thread" \
				"$rigSpawnRc:$( rigThreadOf "$rigWs" "$rigKindSession" session.thread | LC_ALL=C sed 's/:.*//' )" "0:CRIG00001"
			rigOwnChannel="$( rigThreadOf "$rigWs" "$rigKindSession" session.thread )"
		;;
	esac
	[ "$rigOwnChannel" != "none" ] && [ -n "$rigOwnChannel" ] || rigRefuse "the $rigKind session's own channel is not there, so nothing below would be measured"

	## ---- S2: a message that names no address goes on the session's own channel and is recorded ----
	rigSendMessage "$rigWs" "$rigScn" "$rigKindSession" "$rigKindToken" \
		"{\"message\":\"RIG-UNADDRESSED-$rigKind\"}" "unaddressed-$rigKind"
	rigAssert "$rigKind S2: an unaddressed message is sent, never refused" "$rigSendErr" "no"
	rigAssert "$rigKind S2: it goes to the session's own channel" \
		"$( rigFirstLine "$rigSendText" )" "Sent to $rigOwnChannel as $rigRootMember. What the operation reported follows:"
	rigBareBlock="$( rigBlockOf "$rigKindChat" "RIG-UNADDRESSED-$rigKind" )"
	rigAssert "$rigKind S2: it is recorded in the session's one chat file, and in no other" \
		"$( rigChatFilesWith "$rigWs" "RIG-UNADDRESSED-$rigKind" )" "1"
	rigBareTs="$( rigIndexField "$rigKindChat" "$rigBareBlock" 2 )"
	rigAssert "$rigKind S2: the record is a real block with the message's body" \
		"$( rigHeaders "$rigKindChat" ):$( rigTextCount "$( rigBody "$rigKindChat" "$rigBareBlock" )" -F -- "RIG-UNADDRESSED-$rigKind" )" "1:1"
	rigAssert "$rigKind S2/S3: the record's conversation is that channel, and its origin says how it got there" \
		"$( rigIndexField "$rigKindChat" "$rigBareBlock" 3 ):$( rigIndexField "$rigKindChat" "$rigBareBlock" 4 )" \
		"$rigOwnChannel:$( [ "$rigKind" = "none" ] && printf printback || printf own )"
	if [ "$rigKind" = "none" ] ; then
		rigAssert "$rigKind S2/S3: the printback block has no ts, and its own output names the channel and block" \
			"$( rigDash "$rigBareTs" ):$( rigTextCount "$rigSendText" -F -- "# printback: $rigOwnChannel -- block $rigBareBlock of the session chat file" )" "dash:1"
	else
		rigAssert "$rigKind S2/S3: the Slack block carries the ts of its post" "$( rigDash "$rigBareTs" )" "value"
		rigAssert "$rigKind S2/S3: the result names the channel and the thread it went to" \
			"$( rigTextCount "$rigSendText" -x -F -- "SENT_MESSAGE_CHANNEL=${rigOwnChannel%%:*}" ):$( rigTextCount "$rigSendText" -x -F -- "SENT_MESSAGE_THREAD_TS=${rigOwnChannel#*:}" )" "1:1"
		rigAssert "$rigKind S3: the send log's own line names the target and the channel it went to" \
			"$( rigTextCount "$( rigLogLine "$rigWs" "$rigOwnChannel" "${rigOwnChannel%%:*}" "$rigRootMember" )" -F -- "$rigOwnChannel" )" "1"
	fi

	## ---- S2 at the operation's own layer: a direct send with no target takes the same rule ----
	rigOpDefaultSend "$rigWs" "$rigScn" "$rigKindSession" "RIG-OPDEFAULT-$rigKind" "$rigKind"
	rigAssert "$rigKind S2: the send operation with no target is sent, never refused" "$rigOpRc" "0"
	rigOpBlock="$( rigBlockOf "$rigKindChat" "RIG-OPDEFAULT-$rigKind" )"
	rigAssert "$rigKind S2/S3: its record is on the session's own channel, with the body and the origin" \
		"$( rigIndexField "$rigKindChat" "$rigOpBlock" 3 ):$( rigIndexField "$rigKindChat" "$rigOpBlock" 4 ):$( rigTextCount "$( rigBody "$rigKindChat" "$rigOpBlock" )" -F -- "RIG-OPDEFAULT-$rigKind" )" \
		"$rigOwnChannel:$( [ "$rigKind" = "none" ] && printf printback || printf own ):1"
	rigAssert "$rigKind S2: the operation's own output names the channel it went to" \
		"$( if [ "$rigKind" = "none" ] ; then
			rigTextCount "$rigOpText" -F -- "# printback: $rigOwnChannel"
		else
			printf '%s:%s' "$( rigTextCount "$rigOpText" -x -F -- "SENT_MESSAGE_CHANNEL=${rigOwnChannel%%:*}" )" "$( rigTextCount "$rigOpText" -x -F -- "SENT_MESSAGE_THREAD_TS=${rigOwnChannel#*:}" )"
		fi )" "$( [ "$rigKind" = "none" ] && printf 1 || printf 1:1 )"

	## ---- S1: an addressed message goes where it names, whatever the kind -- here a team conversation ----
	rigLogBeforeAddressed="$( rigLogCount "$rigWs" )"
	rigSendMessage "$rigWs" "$rigScn" "$rigKindSession" "$rigKindToken" \
		"{\"to\":\"human-owner\",\"address_to\":\"$rigHelperMember\",\"message\":\"RIG-ADDRESSED-$rigKind\"}" "addressed-$rigKind"
	rigAssert "$rigKind S1: the addressed message is sent, never gated by the kind" "$rigSendErr" "no"
	rigAssert "$rigKind S1: the result names its address" \
		"$( rigFirstLine "$rigSendText" )" "Sent to human-owner as $rigRootMember. What the operation reported follows:"
	rigAssert "$rigKind S1: the address receives it, once" \
		"$( rigPostCount "$rigScn" "RIG-ADDRESSED-$rigKind" )" "1"
	rigAssert "$rigKind S1: it is a top-level post in that conversation, and no thread" \
		"$( rigPostField "$rigScn" "RIG-ADDRESSED-$rigKind" channel ):$( rigTextCount "$( cat "$( rigPostBody "$rigScn" "RIG-ADDRESSED-$rigKind" )" 2> /dev/null )" -F -- '"thread_ts"' )" "URIGOWNER:0"
	rigAddressedBlock="$( rigBlockOf "$rigKindChat" "RIG-ADDRESSED-$rigKind" )"
	rigAddressedTs="$( rigIndexField "$rigKindChat" "$rigAddressedBlock" 2 )"
	rigAssert "$rigKind S1: it is recorded in the session's one chat file, and in no other" \
		"$( rigChatFilesWith "$rigWs" "RIG-ADDRESSED-$rigKind" )" "1"
	rigAssert "$rigKind S1/S3: the record names the address, and never the session's own channel" \
		"$( rigIndexField "$rigKindChat" "$rigAddressedBlock" 3 ):$( rigIndexField "$rigKindChat" "$rigAddressedBlock" 4 )" \
		"URIGOWNER:$rigAddressedTs:own"
	rigAssert "$rigKind S1/S3: the send log names the same target and channel, and the send appended its one line" \
		"$( rigTextCount "$( rigLogLine "$rigWs" human-owner URIGOWNER "$rigRootMember" )" -F -- human-owner ):$(( $( rigLogCount "$rigWs" ) - rigLogBeforeAddressed ))" "1:1"

	## ---- S1/S3: printback is an address, not only the fallback of an unaddressed message ----
	rigLogBeforePrintback="$( rigLogCount "$rigWs" )"
	rigSendMessage "$rigWs" "$rigScn" "$rigKindSession" "$rigKindToken" \
		"{\"to\":\"printback:$rigKindSession\",\"address_to\":\"$rigHelperMember\",\"message\":\"RIG-PRINTBACK-$rigKind\"}" "printback-$rigKind"
	rigAssert "$rigKind S1: an explicit printback address is honoured, whatever the kind" "$rigSendErr" "no"
	rigAssert "$rigKind S1: the result names the printback channel" \
		"$( rigFirstLine "$rigSendText" )" "Sent to printback:$rigKindSession as $rigRootMember. What the operation reported follows:"
	rigAssert "$rigKind S1: the printback address makes no Slack call of its own" \
		"$( rigPostCount "$rigScn" "RIG-PRINTBACK-$rigKind" ):$( rigLogCount "$rigWs" )" "0:$rigLogBeforePrintback"
	rigPrintbackBlock="$( rigBlockOf "$rigKindChat" "RIG-PRINTBACK-$rigKind" )"
	rigAssert "$rigKind S1/S3: the record is a printback block of that channel, with its origin and no ts" \
		"$( rigIndexField "$rigKindChat" "$rigPrintbackBlock" 2 ):$( rigIndexField "$rigKindChat" "$rigPrintbackBlock" 3 ):$( rigIndexField "$rigKindChat" "$rigPrintbackBlock" 4 )" \
		"-:printback:$rigKindSession:printback"
	rigAssert "$rigKind S1: the printed copy names the channel and the block the record holds" \
		"$( rigTextCount "$rigSendText" -F -- "# printback: printback:$rigKindSession -- block $rigPrintbackBlock of the session chat file" )" "1"
	rigAssert "$rigKind S1/S3: that record is the session's, and in no other chat file" \
		"$( rigChatFilesWith "$rigWs" "RIG-PRINTBACK-$rigKind" )" "1"

	## ---- the floor of this kind: one chat file a session, no second record, nothing of the channel in a result ----
	rigAssert "$rigKind: the session's own chat file holds all four records" \
		"$( rigHeaders "$rigKindChat" )" "4"
	if [ "$rigKind" != "full" ] ; then
		rigAssert "$rigKind: the workspace holds exactly one chat file, the session's own" \
			"$( rigChats "$rigWs" )" "$rigKindChat"
	fi
	if [ "$rigKind" = "none" ] ; then
		rigAssert "none: the printback messages made no Slack call -- the addressed one is the only call" \
			"$( rigCalls "$rigScn" ):$( rigTextCount "$( cat "$rigScn/calls" 2> /dev/null )" -F -- 'URIGOWNER' )" "1:1"
	fi
	rigAssert "$rigKind: no result carried the settings file or a session-folder path" \
		"$( LC_ALL=C cat "$rigTmp"/wire-send-*-"$rigKind" 2> /dev/null | LC_ALL=C grep -c -e 'magic-team.agent.env' -e '/sessions/' )" "0"
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION ADDRESS FIRST (F3.2) CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_ADDRESS_FIRST: OK (%d assertions, offline)\n' "$rigPassCount"
