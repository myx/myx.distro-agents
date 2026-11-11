#!/usr/bin/env bash
## Behavioural check on S27.2: a run that handed back with nothing pending parks. Its model loop
## ends, and its record reads `awaiting-review`, never `started` or `running`. A `resume` or `fresh`
## verdict starts it again from its session state.
## Red before S27.2: after a delivered handback with an empty CheckList the harness asks the model
## again, and no park marker is written.
## Offline by construction: one fake curl answers the model and the send, and opens no socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigHarness="$rigPkg/sh-lib/harness/AgentsUniversalHarness.sh"
rigExec="$rigPkg/sh-test/check-fixtures/rig-exec.py"
rigRoutine="$rigPkg/skillset/magic-team/magic-team/magic-team.standalone.routine.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin: $rigHarness"
[ -f "$rigExec" ] || rigRefuse "the rig's process helper is missing: $rigExec"
[ -f "$rigRoutine" ] || rigRefuse "the standalone routine is not in the package: $rigRoutine"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsParkHandbackCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/human-owner" "$rigTmp/skills/magic-coordinator"
printf -- '---\nname: human-owner\nstatus: reference-only\n---\nrig owner\n' > "$rigTmp/skills/human-owner/SKILL.md"
## The coordinator is a member of every team: a person-routed handback is addressed to it (AgentsHarnessReports.include).
printf -- '---\nname: magic-coordinator\n---\nrig coordinator\n' > "$rigTmp/skills/magic-coordinator/SKILL.md"

cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/usr/bin/env bash
## Answers the model from $RIG_SCENARIO/res.<round>, and every Slack call with ok. No socket.
set -u
rigBody="" rigPrev=""
for rigArg in "$@" ; do
	[ "$rigPrev" != "--data-binary" ] || rigBody="${rigArg#@}"
	rigPrev="$rigArg"
done
case " $* " in
	*"harness-park.invalid/"*)
		rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
		printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
		[ ! -f "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/req.$rigRound"
		[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
		cat "$RIG_SCENARIO/res.$rigRound"
		exit 0
	;;
	*"slack.com/api/"*)
		printf 'chat.postMessage\n' >> "$RIG_SCENARIO/slack.calls"
		case "$*" in
			*"auth.test"*) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ; exit 0 ;;
			*"conversations.open"*) printf '{"ok":true,"channel":{"id":"DPARK0001"}}\n' ; exit 0 ;;
			*"users.lookupByEmail"*|*"users.info"*) printf '{"ok":true,"user":{"id":"URIGSELF1"}}\n' ; exit 0 ;;
			*"conversations.replies"*) printf '{"ok":true,"messages":[],"has_more":false}\n' ; exit 0 ;;
			*"conversations.history"*) printf '{"ok":true,"messages":[],"has_more":false}\n' ; exit 0 ;;
			*"conversations.list"*) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ; exit 0 ;;
		esac
		printf '{"ok":true,"channel":"CPARK0001","ts":"1700000001.000900","message":{"ts":"1700000001.000900","user":"URIGSELF1"}}\n'
		exit 0
	;;
esac
cat > /dev/null
exit 7
RIGCURL
chmod +x "$rigTmp/bin/curl"

printf -- '---\nmaintainers: rig\n---\nrig team\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig armed\n' > "$rigTmp/skills/magic-team/magic-team.armed.md"
printf -- '---\nname: magic-team\n---\nrig\n' > "$rigTmp/skills/magic-team/SKILL.md"
cp "$rigRoutine" "$rigTmp/skills/magic-team/" || rigRefuse "the standalone routine could not be copied into the rig"
mkdir -p "$rigTmp/skills/rig-a"
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC\n' > "$rigTmp/skills/rig-a/rig-a.basic.md"
printf -- '---\nstatus: rig\n---\nRIG-A-ARMED\n' > "$rigTmp/skills/rig-a/rig-a.armed.md"
printf -- '---\nname: rig-a\n---\nrig member\n' > "$rigTmp/skills/rig-a/SKILL.md"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigStream(){ ## file, then a JSON body for each text part
	local rigOut="$1" rigPart
	shift
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig","type":"message","role":"assistant","content":[],"usage":{"input_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		for rigPart in "$@" ; do
			printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
			printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$rigPart"
			printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		done
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$rigOut"
}
rigEsc(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' ; }
rigToolStream(){ ## file, tool name, its arguments JSON
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rigt","type":"message","role":"assistant","content":[],"usage":{"input_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_RIG0","name":"%s","input":{}}}\n\n' "$2"
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"%s"}}\n\n' "$( rigEsc "$3" )"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":30}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}

rigSpawn="rig-park-run"
rigScene(){ ## scene name
	rigDir="$rigTmp/$1"
	rigWs="$rigTmp/ws-$1"
	rigSandbox="$rigDir/sandbox"
	rigStore="$rigWs/.local/agents/sessions/$rigSpawn"
	mkdir -p "$rigDir" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigWs/.local/agents/members/magic-coordinator" "$rigDir/data/board/running" "$rigSandbox/input" "$rigSandbox/output"
	printf '0' > "$rigDir/round"
	: > "$rigDir/slack.calls"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	## A person-routed run hands back to magic-coordinator's own conversation (the human-owner's ruling, AgentsHarnessReports.include),
	## so the rig's coordinator needs a Slack account: its mention id is seeded in the cache the send reads, under the lock
	## generation of a rig with no advance and heartbeat notes (the cksum of empty input). The fake curl opens the DM.
	printf '%s\nmagic-coordinator=URIGCOORD1\n' "$( printf '' | cksum )" > "$rigWs/.local/.agents/slack-mention-ids.cache"
	for rigMember in magic-coordinator human-owner ; do
		mkdir -p "$rigWs/.local/agents/members/$rigMember"
		printf -- '---\nname: %s\n---\nrig member\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	done
	## The item this run works: its reviewer is who could give the verdict, so a park is possible.
	printf -- '---\ntype: dispatch\nowner: rig-a\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
		"$rigSpawn" > "$rigDir/data/board/running/dispatch-20261102T0200Z-park.md"
	printf -- '---\nspawn-id: %s\nsession-id: %s\nparent-spawn-id: none\nhost: %s\nowner: rig-a\nstatus: spawn-started\nroutine: magic-team.standalone.routine.md\nspawns: dispatch-20261102T0200Z-park\nsession-thread: CPARK0001:1700000000.000800\n---\n\n# Spawn session: %s\n' \
		"$rigSpawn" "$rigSpawn" "$( hostname -s 2> /dev/null || printf unknown )" "$rigSpawn" > "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md"
	cp "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md" "$rigSandbox/$rigSpawn.spawn.md"
}
rigRun(){ ## further harness arguments -- one harness run, offline
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigDir/data" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" RIG_SCENARIO="$rigDir" \
		HARNESS_PROVIDER_NAME="park rig" HARNESS_SELF_NAME="AgentsParkHandbackCheck.test.sh" HARNESS_WIRE="AnthropicMessages" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-park.invalid/v1/messages" HARNESS_HOST="harness-park.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=0 \
		python3 -I -B "$rigExec" --alarm 240 -- bash "$rigHarness" --agent rig-a --access-root "$rigDir" "$@" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
}

echo "-- 1. a delivered handback with nothing pending parks the run (S27.2) --"
rigScene handover
## Round 1 hands back; round 2 is the model asked again, which a parked run never sees.
rigToolStream "$rigDir/res.1" SubagentHandback '{"outcome":"rig work done","task":"rig"}'
rigStream "$rigDir/res.2" RIG-ASKED-AGAIN
rigRun
rigAssert "the run ended"                                "$rigRunStatus" 0
rigAssert "the handback was posted at least once"      "$( LC_ALL=C awk 'index( $0, "chat.postMessage" ) { posted++ } END { print ( posted > 0 ? 1 : 0 ) }' "$rigDir/slack.calls" )" 1
rigAssert "the model was asked once, and asked no more"  "$( cat "$rigDir/round" )" 1
rigAssert "the run left a park mark"                     "$( [ -f "$rigStore/parked" ] && printf yes || printf no )" yes

echo "-- 2. a control: a handback with a pending item does not park --"
rigScene pending
printf -- '- [ ] rig item still open\n' > "$rigDir/checklist.md"
rigToolStream "$rigDir/res.1" SubagentHandback '{"outcome":"rig work done","task":"rig","checklist_pending_count":1}'
rigStream "$rigDir/res.2" RIG-ASKED-AGAIN
rigRun
rigAssert "the model was asked again"                    "$( cat "$rigDir/round" )" 2
rigAssert "and no park mark was written"                 "$( [ -f "$rigStore/parked" ] && printf yes || printf no )" no

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PARK HANDBACK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PARK_HANDBACK: OK (%d assertions, offline)\n' "$rigPass"
