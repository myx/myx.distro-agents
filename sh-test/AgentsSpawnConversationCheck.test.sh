#!/usr/bin/env bash
## Behavioural check on a spawn that continues a conversation (--conversation, the Agent
## tool's `conversation`, or a brief relaying a thread): the brief names the thread, the
## spawn record carries `conversation-threads:`, the console gets MDAT_CONVERSATION_THREADS,
## a bare Wait's default sources (AgentsToolsWaitDefaultSources) hold it beside the session
## thread, input/conversation.md holds its capped history oldest first with own/team posts
## marked, and a thread that is a known session's own thread joins that session. Offline:
## a fake curl answers Slack, a fake console records what it gets; every run is an `env -i`
## child refusing to run outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSpawnConversationCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigSkills/magic-team" "$rigData/board/running"

## Fake Slack: auth.test, chat.postMessage, and conversations.replies -- 60 messages in
## thread DRIGCONV:100.000001 (the last two tagged as team posts), 2 in any other thread.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/usr/bin/env bash
set -u
rigHeader="$( cat )"
rigMethod="" rigTs=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" )" ;;
	esac
done
printf '%s %s\n' "$rigMethod" "$rigTs" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"DRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"URIGBOT01"}}\n' ;;
	conversations.replies)
		rigN=2 ; [ "$rigTs" != "100.000001" ] || rigN=60
		rigSec="${rigTs%%.*}"
		printf '{"ok":true,"messages":['
		for (( rigI = 1 ; rigI <= rigN ; rigI++ )) ; do
			[ "$rigI" = 1 ] || printf ','
			rigMeta=""
			[ "$rigI" != "$(( rigN - 1 ))" ] || [ "$rigN" != 60 ] || rigMeta=',"metadata":{"event_type":"rig","event_payload":{"sender":"keeper-myx"}}'
			[ "$rigI" != "$rigN" ] || [ "$rigN" != 60 ] || rigMeta=',"metadata":{"event_type":"rig","event_payload":{"sender":"magic-coordinator"}}'
			printf '{"type":"message","ts":"%s.%06d","user":"UHUMAN01","text":"rig message %02d"%s}' "$rigSec" "$rigI" "$rigI" "$rigMeta"
		done
		printf '],"has_more":false}\n'
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console: records the brief, the env value, the history file (input/ is emptied
## at close), and what a bare Wait would default to -- from the env and from the record.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.
[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }
cat > "$RIG_SCENARIO/brief.part"
printf '%s\n' "${MDAT_CONVERSATION_THREADS:-}" > "$RIG_SCENARIO/env"
cp "$MDAT_SPAWN_SANDBOX_ROOT/input/conversation.md" "$RIG_SCENARIO/conversation.md" 2>/dev/null || : > "$RIG_SCENARIO/conversation.md"
( . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" ; AgentsToolsWaitDefaultSources ) > "$RIG_SCENARIO/wait-default" 2>&1
( unset MDAT_CONVERSATION_THREADS ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" ; AgentsToolsConversationThreadsFind ) > "$RIG_SCENARIO/record-threads" 2>&1
printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"
mv "$RIG_SCENARIO/brief.part" "$RIG_SCENARIO/brief"
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh"

printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_USER_TOKEN=rig-user-token-KMYX\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigReset(){
	rm -f "$rigTmp/brief" "$rigTmp/env" "$rigTmp/conversation.md" "$rigTmp/wait-default" "$rigTmp/record-threads"
	: > "$rigTmp/calls"
}
rigSpawn(){ ## stdin content, proxy args...
	local rigIn="$1" ; shift
	rigReset
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --wait --context rig-conversation "$@"
		' rig-spawn "$@" <<< "$rigIn" 2>&1
}
rigAgent(){ ## tool argument JSON
	rigReset
	printf '%s' "$1" | env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool Agent --access-read-root "$RIG_TMP"
		' 2>&1
	local rigWaited=0
	while [ ! -s "$rigTmp/brief" ] && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
	sleep 1
}
rigRecord(){ ## spawn session id -> its record's conversation-threads value
	LC_ALL=C awk '/^conversation-threads: /{ print substr( $0, 23 ) ; exit ; }' "$rigWs"/.local/agents/spawned/*/"$1".md 2>/dev/null
}
rigSpawnId(){ ## proxy output -> the spawn id of the newest record
	ls -t "$rigWs"/.local/agents/spawned/*/*.md 2>/dev/null | head -1 | sed 's|.*/||; s|\.md$||'
}

echo "-- --conversation: brief, record, env, default Wait, capped history --"
rigOut="$( rigSpawn "RIG-REPLACEMENT-TASK" --conversation DRIGCONV:100.000001 )"
[ -s "$rigTmp/brief" ] || rigRefuse "the fake console never received the brief: $( printf '%s\n' "$rigOut" | grep -m1 ERROR )"
rigAssert "the launch succeeded"                          "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the session thread is a new one"               "$( printf '%s\n' "$rigOut" | grep '^SESSION_THREAD=' )" "SESSION_THREAD=DRIG00001:1.000001"
rigAssert "the brief names the conversation thread"       "$( grep -c -x 'conversation_thread_ts: DRIGCONV:100.000001' "$rigTmp/brief" )" 1
rigAssert "and the history file"                          "$( grep -c 'input/conversation.md -- read it first' "$rigTmp/brief" )" 1
rigAssert "the record carries conversation-threads"       "$( rigRecord "$( rigSpawnId )" )" "DRIGCONV:100.000001"
rigAssert "the console gets MDAT_CONVERSATION_THREADS"    "$( cat "$rigTmp/env" )" "DRIGCONV:100.000001"
rigAssert "a bare Wait defaults to session + conversation" "$( cat "$rigTmp/wait-default" )" "slack:DRIG00001:1.000001:conversation slack:DRIGCONV:100.000001:conversation"
rigAssert "the record alone gives the same threads"       "$( cat "$rigTmp/record-threads" )" "DRIGCONV:100.000001"
rigAssert "history: 50 message heads, capped"             "$( grep -c -E '^(\((own|team: [a-z-]+)\) )?100\.[0-9]+ \| ' "$rigTmp/conversation.md" )" 50
rigAssert "history: the cut is said"                      "$( grep -c -x '(10 older messages not shown)' "$rigTmp/conversation.md" )" 1
rigAssert "history: oldest kept first, newest last" \
	"$( grep -E '100\.[0-9]+ \| ' "$rigTmp/conversation.md" | sed -n '1p;$p' | sed 's/.*rig message //' | tr '\n' ' ' )" "11 60 "
rigAssert "history: own post marked"                      "$( grep -c '^(own) 100.000059 | ' "$rigTmp/conversation.md" )" 1
rigAssert "history: team post marked"                     "$( grep -c '^(team: magic-coordinator) 100.000060 | ' "$rigTmp/conversation.md" )" 1

echo "-- no conversation: nothing added --"
rigOut="$( rigSpawn "RIG-PLAIN-TASK" )"
rigAssert "no conversation section"                       "$( grep -c 'conversation_thread_ts' "$rigTmp/brief" )" 0
rigAssert "no history file"                               "$( wc -c < "$rigTmp/conversation.md" | tr -d ' ' )" 0
rigAssert "a bare Wait keeps the session thread only"     "$( cat "$rigTmp/wait-default" )" "slack:DRIG00001:1.000001:conversation"

echo "-- derived from a brief that relays a thread --"
rigOut="$( rigSpawn "$( printf '%s\n' 'RIG-RELAY-TASK' '# arrived on: slack:DRIGREL:300.000001:conversation' '300.000002 | UHUMAN01 | please go on' 'see https://rig.slack.com/archives/DRIGLNK/p400000002?thread_ts=400.000001&cid=DRIGLNK' )" )"
rigAssert "both relayed threads are recorded"             "$( rigRecord "$( rigSpawnId )" )" "DRIGREL:300.000001 DRIGLNK:400.000001"
rigAssert "and both histories are there"                  "$( grep -c -E '^## Thread (DRIGREL:300.000001|DRIGLNK:400.000001)$' "$rigTmp/conversation.md" )" 2

echo "-- a thread that is a known session's own joins that session --"
mkdir -p "$rigWs/.local/agents/spawned/rig-old-session"
printf '%s\n' '---' 'session-id: rig-old-session' 'spawn-id: rig-old-session' 'parent-session-id: none' 'tracking-name: rig-old-session' \
	"host: $( hostname -s )" 'workspace: ws' 'owner: keeper-myx' 'status: spawn-failed' 'session-thread: DRIGOLD:200.000001' '---' \
	> "$rigWs/.local/agents/spawned/rig-old-session/rig-old-session.md"
rigOut="$( rigSpawn "RIG-JOIN-TASK" --conversation DRIGOLD:200.000001 )"
rigAssert "joins the replaced session"                    "$( printf '%s\n' "$rigOut" | grep '^SESSION_ID=' )" "SESSION_ID=rig-old-session"
rigAssert "in its own thread"                             "$( printf '%s\n' "$rigOut" | grep '^SESSION_THREAD=' )" "SESSION_THREAD=DRIGOLD:200.000001"
rigAssert "a bare Wait watches it once"                   "$( cat "$rigTmp/wait-default" )" "slack:DRIGOLD:200.000001:conversation"
rigOut="$( rigSpawn "RIG-EXPLICIT-TASK" --session-id rig-old-session --conversation DRIGCONV:100.000001 )"
rigAssert "--session-id still wins"                       "$( printf '%s\n' "$rigOut" | grep '^SESSION_ID=' )" "SESSION_ID=rig-old-session"

echo "-- refused input --"
rigOut="$( rigSpawn "RIG-BAD" --conversation 'not a thread' )"
rigAssert "a malformed thread is refused"                 "$( printf '%s\n' "$rigOut" | grep -c 'conversation requires <channel>:<thread-ts>' )" 1

echo "-- the harness Agent tool passes conversation --"
rigOut="$( rigAgent '{"agent":"keeper-myx","prompt":"RIG-AGENT-TASK","conversation":"DRIGCONV:100.000001"}' )"
rigAssert "the Agent spawn's brief names the thread"      "$( grep -c -x 'conversation_thread_ts: DRIGCONV:100.000001' "$rigTmp/brief" 2>/dev/null )" 1
rigAssert "the Agent tool declares conversation" \
	"$( LC_ALL=C grep -c -F '"conversation":{"type":"string","description":"Optional. The conversation threads the helper continues' "$rigHere/AgentsOpenAiChatWire.sh" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN CONVERSATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_CONVERSATION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
