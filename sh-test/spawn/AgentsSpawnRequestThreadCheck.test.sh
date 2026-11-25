#!/usr/bin/env bash
## Behavioural check on the REQUEST THREAD of a start: the thread of the person's Slack message the session is for. Run rather than read, against
## the real proxy in a rig tree, a fake console and a fake curl. Every row is an assertion, so one failure never hides another. Held:
##   1. One conversation: the session thread opens as a reply inside it, no conversation is opened, and the brief, the record, session.thread and
##      the dispatch item's `request-thread` all hold it. The item never carries `communication-channel-id`, which the sweeps read as a thread of its own.
##   2. A reply ts is turned into its root by the answer's own message.thread_ts, in the brief, the record, session.thread and the item.
##   3. A post that landed at the top is deleted by its own channel and ts, said, and the thread opens where it did. One root stays, and the item names no request.
##      A delete Slack refuses is said as well, and the stray post stays.
##   4. A token Slack refuses is retried once with the team's, the first post carrying the member's token and the second the team's.
##      A refusal of both makes two posts to the request thread, then falls back loudly. An answer that names no thread is proved by conversations.replies.
##   5. No bot token is said on stderr, and the brief says the request was not used.
##   6. Several threads name no request. A thread of the event-track channel is dropped.
##   7. The item carries the address: its header is the request where none is named, and an explicit word wins. A header with no thread, and an item of a
##      Slack inbox item with no header, are said. An `# arrived on:` line is the request, a permalink and a `[reply-to:]` mark are not.
##   8. A start that joins a session keeps its thread, says so, and the brief marks the request as not used.
##   9. A member that owes a reply and spawns for no conversation is told once, for a spawn made by a run and a young line alone.
## Offline: a fake console runs no model, a fake curl opens no socket, and every run is an `env -i` child of this rig's own trees.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnRequestThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rigSpawnLeftEnd ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/keeper-myx" "$rigWs/WORK"
cp "$rigTest/check-fixtures/spawn-request-thread.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: sh-test/check-fixtures/spawn-request-thread.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigEnvFile="$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_CHANNEL_EVENT_ALERT=CRIGALERT\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigEnvFile"
printf -- '---\nname: keeper-myx\ndescription: rig member\n---\n' > "$rigSkills/keeper-myx/SKILL.md"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/keeper-myx/keeper-myx.basic.md"
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.
cat > "$RIG_SCENARIO/brief"
printf 'rig-cli\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_SCENARIO/last-spawn"
printf '   📦 SubagentHandback rig-outcome\n'
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigBrief="RIG-TASK-TEXT"
rigExtraEnv=()
rigSpawn(){ ## member, extra proxy arguments...
	local spawnMember="$1"
	shift
	rm -f "$rigTmp/brief" "$rigTmp/last-spawn" "$rigTmp/spawn.out"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigExtraEnv[@]+"${rigExtraEnv[@]}"} \
		bash -c '
			case "$MMDAPP" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$0" --intern-op-agent-spawn-proxy "$@" --dispatch-doc:create --wait --context rig-request-thread
		' "$rigTool" "$spawnMember" "$@" <<< "$rigBrief" > "$rigTmp/spawn.out" 2>&1 ) || :
	rigSettle
	rigOut="$( cat "$rigTmp/spawn.out" )"
	rigItem="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' | head -1 )"
}
rigSpawnRunning(){ ## -- the pids of this check's own spawn proxies still running, one a line
	ps -A -ww -o pid=,args= 2> /dev/null | LC_ALL=C awk -v self="$$" '$1 != self && /DistroAgentsTools.fn.sh --intern-op-agent-spawn-proxy/ && /--context rig-request-thread/ { print $1 ; }'
}
rigSettle(){
	local settleLeft=450
	while [ "$settleLeft" -gt 0 ] ; do
		if [ -z "$( rigSpawnRunning )" ] ; then return 0 ; fi
		sleep 0.2 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 0
}
rigSpawnLeftEnd(){
	local leftPids="$( rigSpawnRunning )"
	[ -z "$leftPids" ] || rigProcSignalWithChildren KILL $leftPids
	return 0
}
rigItemPath(){ ## item name
	local itemFound="" itemStateDir
	for itemStateDir in "$rigData"/board/* ; do
		[ -f "$itemStateDir/${1%.md}.md" ] || continue
		itemFound="$itemStateDir/${1%.md}.md"
		break
	done
	printf '%s' "${itemFound:-/dev/null}"
}
rigHeader(){ ## item path, header -- its value, or `-`
	LC_ALL=C awk -v wantField="$2" '
		NR == 1 && $0 != "---" { exit ; }
		$0 == "---" { dashes++ ; if ( dashes == 2 ) { exit ; } ; next ; }
		index( $0, wantField ": " ) == 1 { print substr( $0, length( wantField ) + 3 ) ; found = 1 ; exit ; }
		END { if ( ! found ) { print "-" ; } ; }
	' "$1" 2> /dev/null || printf -- '-'
}
rigItemHeader(){ ## header -- of the last spawn's dispatch item
	local headerValue
	headerValue="$( rigHeader "$( rigItemPath "$rigItem" )" "$1" )"
	printf '%s' "${headerValue:--}"
}
rigRecord(){ ## header -- of the newest spawn record
	local recordFile recordValue
	recordFile="$( ls -t "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
	[ -n "$recordFile" ] || { printf '%s' "-" ; return 0 ; }
	recordValue="$( LC_ALL=C sed -n "s/^$1: //p" "$recordFile" | head -1 )"
	printf '%s' "${recordValue:--}"
}
rigSessionThread(){ ## -- session.thread of the last spawn's session
	local threadFile="$rigWs/.local/agents/sessions/$( cat "$rigTmp/last-spawn" 2> /dev/null )/session.thread" threadValue=""
	[ ! -f "$threadFile" ] || IFS= read -r threadValue < "$threadFile" || :
	printf '%s' "${threadValue:--}"
}
rigSendLog(){ ## -- the rows of the monthly send log
	cat "$rigWs"/.local/agents/comms-slack-send.*.log 2> /dev/null || :
}
rigRequestInto(){ ## -- the request thread of the last spawn's run, as a tool of that run reads it, or `none`
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID="$( cat "$rigTmp/last-spawn" 2> /dev/null )" \
		bash -c 'rigGot="" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.SessionThreads.include" && AgentsToolsRequestThreadInto rigGot && printf "%s" "$rigGot" || printf none' 2> /dev/null
}
rigReset(){ ## clears what a scenario of the fake curl keeps
	rm -f "$rigWs"/.local/agents/comms-slack-send.*.log
	rm -f "$rigTmp"/landed.* "$rigTmp"/omit-thread
	rm -f "$rigTmp"/calls "$rigTmp"/posts "$rigTmp"/posts.log "$rigTmp"/post.* "$rigTmp"/post-errors "$rigTmp"/topless "$rigTmp"/reply-root "$rigTmp"/deletes "$rigTmp"/delete-error
	: > "$rigTmp/calls" ; : > "$rigTmp/posts.log"
	## A session an earlier scenario left stands no more: a conversation word that is a session's own thread joins that session.
	rm -rf "$rigWs"/.local/agents/spawned/* "$rigWs"/.local/agents/sessions/* "$rigWs"/.local/agents/live/*
}
rigRoots(){ ## -- how many session roots stand after the last spawn
	LC_ALL=C grep -c ' session-root$' "$rigTmp/posts.log" 2> /dev/null || :
}
rigRootsIn(){ ## conversation, thread or `top` -- how many roots stand there
	LC_ALL=C grep -c "^[0-9]* $1 $2 session-root\$" "$rigTmp/posts.log" 2> /dev/null || :
}
rigCalls(){ ## method -- how many calls of it the last spawn made
	LC_ALL=C grep -c "^$1 " "$rigTmp/calls" 2> /dev/null || :
}
rigSaid(){ ## text -- how many lines of the last spawn's output hold it
	printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "$1" || :
}
rigThreadLine(){ LC_ALL=C sed -n 's/^session_thread_ts: //p' "$rigTmp/brief" 2> /dev/null | head -1 ; }
rigMark(){ LC_ALL=C grep -c '^request_thread_not_used: ' "$rigTmp/brief" 2> /dev/null || : ; }
rigTask(){ ## item name, extra header line (may be empty)
	{ printf -- '---\ntype: task\nowner: keeper-myx\n' ; [ -z "$2" ] || printf '%s\n' "$2" ; printf -- '---\n\n# Rig task\n' ; } | rigOwnerBoardPut running "$1.md"
}

echo "-- 1. one conversation: the session thread opens as a reply inside it --"
rigReset
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "the spawn wrote its dispatch item" "$( [ -n "$rigItem" ] && printf yes || printf no )" "yes"
rigAssert "the root post is a reply in the request thread, in its own conversation" "$( rigRootsIn CRIGREQ01 1700000000.000500 )" "1"
rigAssert "no direct conversation is opened for it, and one root is posted" "$( rigCalls conversations.open ):$( rigRoots )" "0:1"
rigAssert "the brief hands over the request thread as the session thread" "$( rigThreadLine )" "CRIGREQ01:1700000000.000500"
rigAssert "session.thread holds it, which is what every later post reads" "$( rigSessionThread )" "CRIGREQ01:1700000000.000500"
rigAssert "the record keeps the word as its conversation thread" "$( rigRecord conversation-threads )" "CRIGREQ01:1700000000.000500"
rigAssert "a tool of the run reads the same request thread" "$( rigRequestInto )" "CRIGREQ01:1700000000.000500"
rigAssert "the dispatch item carries the address from its first write, as request-thread" "$( rigItemHeader request-thread )" "slack:CRIGREQ01:1700000000.000500"
rigAssert "and never as communication-channel-id, which the sweeps read as a thread of the item's own" "$( rigItemHeader communication-channel-id )" "-"

echo "-- 2. a reply ts is turned into its root --"
rigReset
printf '1700000000.000400\n' > "$rigTmp/reply-root"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "the brief names the root the answer names" "$( rigThreadLine )" "CRIGREQ01:1700000000.000400"
rigAssert "session.thread holds the root" "$( rigSessionThread )" "CRIGREQ01:1700000000.000400"
rigAssert "the record's word is rewritten to it, so the record and the thread are one value" "$( rigRecord conversation-threads )" "CRIGREQ01:1700000000.000400"
rigAssert "the dispatch item is rewritten to it after the open" "$( rigItemHeader request-thread )" "slack:CRIGREQ01:1700000000.000400"
rigAssert "and the normalisation is said" "$( rigSaid 'is a reply, so its root CRIGREQ01:1700000000.000400 is the thread used' )" "1"

echo "-- 3. a post that landed at the top is deleted by its own ts, said, and the thread opens where it did --"
rigReset
: > "$rigTmp/topless"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "the stray post is deleted by its own channel and ts, and nothing else is" "$( cat "$rigTmp/deletes" 2> /dev/null )" "CRIGREQ01 1700000001.000100"
rigAssert "the delete is said, naming the post" "$( rigSaid 'CRIGREQ01:1700000001.000100 landed at the top of the conversation' )" "1"
rigAssert "the send log holds one row naming the channel and ts and the delete" "$( rigSendLog | LC_ALL=C grep -F 'CRIGREQ01:1700000001.000100' | LC_ALL=C grep -c 'and was deleted' )" "1"
rigAssert "the warning names the request" "$( rigSaid 'request thread CRIGREQ01:1700000000.000500 not used' )" "1"
rigAssert "exactly one root stands, at the top of the team channel" "$( rigRoots ):$( rigRootsIn CRIGTEAM1 top ):$( rigRootsIn CRIGREQ01 1700000000.000500 )" "1:1:0"
rigAssert "the session thread is the team channel's, never empty" "$( rigThreadLine | LC_ALL=C cut -c1-10 )" "CRIGTEAM1:"
rigAssert "the brief says the request was not used" "$( LC_ALL=C grep -c '^request_thread_not_used: CRIGREQ01:1700000000.000500 -- ' "$rigTmp/brief" 2> /dev/null || : )" "1"
rigAssert "the dispatch item names no request after it" "$( rigItemHeader request-thread )" "-"
rigReset
: > "$rigTmp/topless"
printf 'cant_delete_message\n' > "$rigTmp/delete-error"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "a delete Slack refuses is said" "$( rigSaid 'could not be deleted' )" "1"
rigAssert "and the send log says the post could not be deleted" "$( rigSendLog | LC_ALL=C grep -F 'CRIGREQ01:1700000001.000100' | LC_ALL=C grep -c 'could not be deleted' )" "1"
rigAssert "and the stray post stays, beside the fallback root" "$( rigRoots ):$( rigRootsIn CRIGREQ01 1700000000.000500 )" "2:1"

echo "-- 4. a token Slack refuses is retried once with the team's --"
printf 'SLACK_BOT_TOKEN=rig-bot-token-MEMBER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
rm -f "$rigWs/.local/cache/comms/slack/".resolve-*.txt
rigReset
printf 'channel_not_found\nok\n' > "$rigTmp/post-errors"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "the retry lands in the request thread, and one root stands" "$( rigThreadLine ):$( rigRoots )" "CRIGREQ01:1700000000.000500:1"
rigAssert "the first post carried the member's token and the second the team's" "$( LC_ALL=C grep '^chat.postMessage ' "$rigTmp/calls" | head -2 | tr '\n' ',' )" "chat.postMessage rig-bot-token-MEMBER,chat.postMessage rig-bot-token-TEAM,"
rigReset
printf 'channel_not_found\nchannel_not_found\nok\n' > "$rigTmp/post-errors"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "a refusal of both falls back loudly to the team channel" "$( rigThreadLine | LC_ALL=C cut -c1-10 ):$( rigSaid 'request thread CRIGREQ01:1700000000.000500 not used' )" "CRIGTEAM1::1"
rigAssert "and it made two refused posts, the member's and the team's, before the fallback root" "$( LC_ALL=C grep '^chat.postMessage ' "$rigTmp/calls" | head -3 | tr '\n' ',' ):$( rigRoots )" "chat.postMessage rig-bot-token-MEMBER,chat.postMessage rig-bot-token-TEAM,chat.postMessage rig-bot-token-MEMBER,:1"
rm -f "$rigWs/.local/.agents/keeper-myx.agent.env" "$rigWs/.local/cache/comms/slack/".resolve-*.txt
echo "-- 4b. an answer that names no thread is proved by conversations.replies --"
rigReset
: > "$rigTmp/omit-thread"
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "a post found in its thread is kept, and nothing is deleted" "$( rigThreadLine ):$( rigRootsIn CRIGREQ01 1700000000.000500 ):$( cat "$rigTmp/deletes" 2> /dev/null | wc -l | tr -d ' ' )" "CRIGREQ01:1700000000.000500:1:0"
rigAssert "and conversations.replies was read twice: the history of the thread for the brief, and the proof that the post is in it" "$( rigCalls conversations.replies )" "2"

echo "-- 5. no bot token: said, and the spawn still starts --"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigEnvFile"
rm -f "$rigWs/.local/cache/comms/slack/".resolve-*.txt
rigReset
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "it is said on stderr, and the spawn started" "$( [ "$( rigSaid 'no bot token resolves for keeper-myx' )" -ge 1 ] && printf said || printf silent ):$( rigSaid 'LAUNCHED=true' )" "said:1"
rigAssert "the brief says the request was not used" "$( rigMark )" "1"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_CHANNEL_EVENT_ALERT=CRIGALERT\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigEnvFile"
rm -f "$rigWs/.local/cache/comms/slack/".resolve-*.txt

echo "-- 6. several conversations name no request, and an event-track thread is dropped --"
rigReset
rigSpawn keeper-myx --conversation CRIGREQ01:1700000000.000500 --conversation CRIGREQ02:1700000000.000600
rigAssert "it is said, and the thread opens at the top of the team channel" "$( rigSaid 'several request threads are named' ):$( rigRootsIn CRIGTEAM1 top )" "1:1"
rigReset
rigSpawn keeper-myx --conversation CRIGTRACK1:1700000000.000800
rigAssert "a thread of the event-track channel is dropped loudly, and the thread opens in the team channel" "$( rigSaid 'is a thread of the event-track channel' ):$( rigRootsIn CRIGTEAM1 top )" "1:1"
rigAssert "and the record does not keep it as a conversation" "$( rigRecord conversation-threads )" "-"

echo "-- 7. the item carries the address --"
rigTask task-20261124T0000Z-rig-carrier "communication-channel-id: slack:CRIGREQ01:1700000000.000600"
rigReset
rigSpawn keeper-myx --tracked-item task-20261124T0000Z-rig-carrier
rigAssert "no conversation named: the item's header is the request thread" "$( rigThreadLine )" "CRIGREQ01:1700000000.000600"
rigReset
rigSpawn keeper-myx --tracked-item task-20261124T0000Z-rig-carrier --conversation CRIGREQ01:1700000000.000650
rigAssert "an explicit conversation wins over the header" "$( rigThreadLine )" "CRIGREQ01:1700000000.000650"
rigTask task-20261124T0001Z-rig-nothread "communication-channel-id: slack:CRIGREQ01"
rigReset
rigSpawn keeper-myx --tracked-item task-20261124T0001Z-rig-nothread
rigAssert "a header with no thread is said, and the thread opens at the top of the team channel" "$( rigSaid 'which is no <channel>:<thread ts>' ):$( rigRootsIn CRIGTEAM1 top )" "1:1"
rigTask task-20261124T0002Z-rig-lost "references: note-20261124T0900Z-slack-1700000000.000900"
rigReset
rigSpawn keeper-myx --tracked-item task-20261124T0002Z-rig-lost
rigAssert "an item of a Slack inbox item with no header is said" "$( rigSaid 'carries no communication-channel-id, so this start has no request thread' )" "1"
rigTask task-20261124T0003Z-rig-plain ""
rigReset
rigSpawn keeper-myx --tracked-item task-20261124T0003Z-rig-plain
rigAssert "an item with no Slack origin says nothing about a request" "$( rigSaid 'no request thread' ):$( rigSaid LAUNCHED=true )" "0:1"
rigBrief="$( printf '%s\n' 'RIG-RELAY' '# arrived on: slack:CRIGREQ01:1700000000.000700:conversation' '1700000000.000701 | UPERSON1 | where does it go?' )"
rigReset
rigSpawn keeper-myx
rigAssert "the arrival line of a relayed Wait result is the request thread" "$( rigThreadLine )" "CRIGREQ01:1700000000.000700"
rigBrief="$( printf '%s\n' 'RIG-LINK' 'see https://rig.slack.com/archives/CRIGLNK1/p1700000000000800?thread_ts=1700000000.000800&cid=CRIGLNK1' )"
rigReset
rigSpawn keeper-myx
rigAssert "a permalink keeps its join meaning alone: the record holds it, the thread opens in the team channel" "$( rigRecord conversation-threads ):$( rigRootsIn CRIGTEAM1 top )" "CRIGLNK1:1700000000.000800:1"
rigAssert "and no tool of the run takes the permalink as its request thread" "$( rigRequestInto )" "none"
rigBrief="$( printf '%s\n' 'RIG-MARK' '1700000000.000900 | UPERSON1 | [reply-to: slack:CRIGREQ01:1700000000.000900] where does it go?' )"
rigReset
rigSpawn keeper-myx
rigAssert "a reply-to mark in a brief is no request: the thread opens in the team channel" "$( rigRootsIn CRIGTEAM1 top ):$( rigRecord conversation-threads )" "1:-"
rigBrief="RIG-TASK-TEXT"

echo "-- 8. a start that joins a session keeps its thread, and says the request is not used --"
rigReset
mkdir -p "$rigWs/.local/agents/spawned/rig-old-session"
printf '%s\n' '---' 'session-id: rig-old-session' 'spawn-id: rig-old-session' 'parent-spawn-id: none' 'tracking-name: rig-old-session' \
	"host: $( hostname -s )" 'workspace: ws' 'owner: keeper-myx' 'status: spawn-failed' 'session-thread: CRIGOLD01:1700000000.000100' '---' \
	> "$rigWs/.local/agents/spawned/rig-old-session/rig-old-session.spawn.md"
rigSpawn keeper-myx --session-id rig-old-session --conversation CRIGREQ01:1700000000.000500
rigAssert "it keeps the session's thread" "$( rigThreadLine )" "CRIGOLD01:1700000000.000100"
rigAssert "a loud line names both threads" "$( rigSaid 'request thread CRIGREQ01:1700000000.000500 is not used: this start keeps CRIGOLD01:1700000000.000100' )" "1"
rigAssert "the brief marks the request as not used" "$( rigMark )" "1"
rigAssert "no root is posted for it" "$( rigRoots )" "0"
rigAssert "and no tool of the run takes the unused request as its own" "$( rigRequestInto )" "none"

echo "-- 9. an owed reply is told once, for a spawn made by a run --"
rigNow="$( date +%s )"
mkdir -p "$rigWs/.local/agents/schedule/owed"
printf '%s\tslack:CRIGOWED1:1700000000.000300\tUPERSON1\twhere does it go?\n' "$rigNow" > "$rigWs/.local/agents/schedule/owed/keeper-myx"
rigExtraEnv=( MDAT_SPAWN_SESSION_ID=rig-parent-run MDAT_SPAWN_AGENT=keeper-myx )
rigReset
rigSpawn keeper-myx --session-new --calling-member keeper-myx
rigAssert "a spawn made by a run, with no conversation, is told what the member owes" "$( rigSaid 'keeper-myx owes a reply at CRIGOWED1:1700000000.000300' ):$( rigSaid LAUNCHED=true )" "1:1"
rigReset
rigSpawn keeper-myx --session-new --calling-member keeper-myx --conversation CRIGREQ01:1700000000.000500
rigAssert "a spawn that names a conversation is told nothing" "$( rigSaid 'owes a reply' ):$( rigSaid LAUNCHED=true )" "0:1"
rigExtraEnv=()
rigReset
rigSpawn keeper-myx --session-new --calling-member keeper-myx
rigAssert "a start made by no run, as the schedule's is, is told nothing" "$( rigSaid 'owes a reply' ):$( rigSaid LAUNCHED=true )" "0:1"
rigExtraEnv=( CLAUDE_CODE_SESSION_ID=rig-client-session )
rigReset
rigSpawn keeper-myx --session-new --calling-member keeper-myx
rigAssert "a start from a client shell that has only CLAUDE_CODE_SESSION_ID is told nothing" "$( rigSaid 'owes a reply' ):$( rigSaid LAUNCHED=true )" "0:1"
rigExtraEnv=()
printf '%s\tslack:CRIGOWED1:1700000000.000300\tUPERSON1\twhere does it go?\n' "$(( rigNow - 20000 ))" > "$rigWs/.local/agents/schedule/owed/keeper-myx"
rigExtraEnv=( MDAT_SPAWN_SESSION_ID=rig-parent-run MDAT_SPAWN_AGENT=keeper-myx )
rigReset
rigSpawn keeper-myx --session-new --calling-member keeper-myx
rigAssert "a line older than three owed periods is told nothing" "$( rigSaid 'owes a reply' ):$( rigSaid LAUNCHED=true )" "0:1"
rigExtraEnv=()

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN REQUEST THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_REQUEST_THREAD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
