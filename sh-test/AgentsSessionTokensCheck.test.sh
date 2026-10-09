#!/usr/bin/env bash
## Behavioural check on session token totals (T6): the `tokens:` header a session writes on
## its dispatch item (token counts only), written only when it changed; the roll-up summed when
## shown over tracks:, follows-up: and child sessions; the closing-message line; the board
## scan and heartbeat lines; the to-processed closing line; and a whole spawn through the
## real proxy, whose fake console streams canned stream-json through the real writer.
## Offline: a temp git store and workspace; nothing is posted and the real store is never reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"

rigTmp="$( mktemp -d -t AgentsSessionTokensCheck )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] || rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigStore/board/running" "$rigStore/board/review" "$rigStore/board/backlog"
git -C "$rigStore" init -q || rigRefuse "could not init the temp store"
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the temp store"
unset CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_MCP_SERVED_MARKER MDAT_SESSION_ID CLAUDE_CODE_ENTRYPOINT harnessSessionId
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN HOME="$rigTmp/home"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCommits(){ git -C "$rigStore" rev-list --count HEAD ; }
rigHeader(){ ## item path, header name
	LC_ALL=C awk -v want="$2: " 'NR > 1 && $0 == "---" { exit } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit }' "$1"
}
rigItem(){ ## state, name, header lines...
	local itemState="$1" itemName="$2"
	shift 2
	{ printf -- '---\n' ; printf '%s\n' "$@" ; printf -- '---\n\nbody\n' ; } > "$rigStore/board/$itemState/$itemName"
}
rigSession(){ ## session id, tokens line, model, item
	mkdir -p "$rigWs/.local/agents/sessions/$1"
	printf '%s\n' "$2" > "$rigWs/.local/agents/sessions/$1/tokens"
	[ -z "$3" ] || printf '%s\n' "$3" > "$rigWs/.local/agents/sessions/$1/model"
	[ -z "$4" ] || printf '%s\n' "$4" > "$rigWs/.local/agents/sessions/$1/dispatch-item"
}

. "$rigHere/AgentsTools.SessionTranscript.include"

echo "-- the tokens header value --"
rigSession s-plain "10 20 30 40" claude-opus-5-5 ""
rigAssert "the header value is the four token counts" "$( AgentsSessionTokensHeaderValue s-plain )" 'in=10 cache-read=20 cache-write=30 out=40'
rigSession s-extra "10 20 30 40 0.5" claude-opus-5-5 ""
rigAssert "a stray fifth field in an older tokens file is ignored" "$( AgentsSessionTokensHeaderValue s-extra )" 'in=10 cache-read=20 cache-write=30 out=40'
rigAssert "a session with no tokens file has no value" "$( AgentsSessionTokensHeaderValue s-none )" ''

echo "-- the header on the session's dispatch item, written only when it changed --"
rigItem running dispatch-20261008T1000Z-rig-a.md "owner: magic-tester" "spawn-id: s-a" "tracks: task-20261008T1000Z-rig"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m items
rigSession s-a "100 200 300 400" claude-opus-5-5 dispatch-20261008T1000Z-rig-a.md
rigBefore="$( rigCommits )"
AgentsSessionTokensHeaderUpdate s-a
rigAssert "the header is written" "$( rigHeader "$rigStore/board/running/dispatch-20261008T1000Z-rig-a.md" tokens )" 'in=100 cache-read=200 cache-write=300 out=400'
rigAssert "in one commit" "$(( $( rigCommits ) - rigBefore ))" 1
AgentsSessionTokensHeaderUpdate s-a
rigAssert "the same value again is no commit" "$(( $( rigCommits ) - rigBefore ))" 1

echo "-- totals summed when shown, over what sits under an item --"
rigItem backlog task-20261008T1000Z-rig.md "type: task" "tokens: in=1 cache-read=2 cache-write=3 out=4"
rigItem review dispatch-20261008T1001Z-rig-b.md "follows-up: task-20261008T1000Z-rig" "tokens: in=10 cache-read=20 cache-write=30 out=40"
rigItem review dispatch-20261008T1002Z-rig-c.md "spawn-id: s-c" "tokens: in=1000 cache-read=0 cache-write=0 out=1000"
mkdir -p "$rigWs/.local/agents/spawned/s-c"
printf -- '---\nspawn-id: s-c\nparent-session-id: s-a\nspawns: dispatch-20261008T1002Z-rig-c\n---\n' > "$rigWs/.local/agents/spawned/s-c/s-c.md"
rigItem backlog task-20261008T1003Z-other.md "type: task"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "rollup items"
rigRows="$( AgentsSessionTokensRollupRows task-20261008T1000Z-rig.md dispatch-20261008T1000Z-rig-a task-20261008T1003Z-other.md )"
rigAssert "the task: itself, its tracking dispatch, its follow-up and that dispatch's child session" \
	"$( AgentsSessionTokensRollupRowOf "$rigRows" task-20261008T1000Z-rig )" "$( printf 'task-20261008T1000Z-rig\t1111\t222\t333\t1444\t3' )"
rigAssert "a dispatch: itself and its child session" \
	"$( AgentsSessionTokensRollupRowOf "$rigRows" dispatch-20261008T1000Z-rig-a )" "$( printf 'dispatch-20261008T1000Z-rig-a\t1100\t200\t300\t1400\t1' )"
rigAssert "an item with no tokens under it shows nothing" "$( AgentsSessionTokensRollupRowOf "$rigRows" task-20261008T1003Z-other )" ""
rigAssert "the display line: token totals, sub-sessions counted" \
	"$( AgentsSessionTokensRollupText "$( AgentsSessionTokensRollupRowOf "$rigRows" task-20261008T1000Z-rig )" )" \
	'tokens: in=1111 cache-read=222 cache-write=333 out=1444 (incl. 3 sub-sessions)'
rigAssert "nothing was written up the chain" "$( rigHeader "$rigStore/board/backlog/task-20261008T1000Z-rig.md" tokens )" 'in=1 cache-read=2 cache-write=3 out=4'

echo "-- the closing message --"
rigClose="$(
	set +u
	DistroAgentsTools(){ if [ "$1" = --intern-op-event-track-post ] ; then printf '%s\n' "$@" > "$rigTmp/close.args" ; cat > /dev/null ; fi ; return 0 ; }
	set -- --rig-none
	. "$rigHere/AgentsTools.InternOpAgentSpawnProxy.include" 2>/dev/null
	MDAT_SPAWN_SESSION_ID=s-a AgentsToolsSpawnProxyEventTrackClose "C1:1.2" magic-tester succeeded 0 "" "" 0 0
	cat "$rigTmp/close.args"
)"
rigAssert "the event-track closing post, the end kind, carries the session's totals" \
	"$( printf '%s\n' "$rigClose" | LC_ALL=C grep -c -x -e 'end' -e 'tokens=in=1100 cache-read=200 cache-write=300 out=1400 (incl. 1 sub-session)' )" 2

echo "-- board lines: the scan, the heartbeat, the to-processed close --"
rigScan="$( "$rigFn" --intern-op-session-context-scan magic-tester --state backlog --state review --state running --all-types \
	--no-inbox-inquiry --no-inbox-reflections --no-inbox-notes --no-inbox-other --no-slack --no-email --no-trello --no-board-related --context rig 2>/dev/null )"
rigAssert "a scanned item carries its totals" "$( printf '%s\n' "$rigScan" | LC_ALL=C awk '/^## backlog\/task-20261008T1000Z-rig.md$/ { on = 1 } on && /^tokens-total: / { print ; exit }' )" \
	'tokens-total: in=1111 cache-read=222 cache-write=333 out=1444 (incl. 3 sub-sessions)'
rigAssert "an item with none carries no line" "$( printf '%s\n' "$rigScan" | LC_ALL=C awk '/^## backlog\/task-20261008T1003Z-other.md$/ { on = 1 ; next } /^## / { on = 0 } on && /^tokens-total: / { print "line" }' )" ""
rigBeat="$( set +u ; MDSC_CMD=rig ; set -- --rig-none ; . "$rigHere/AgentsTools.MagicHeartbeat.include" 2>/dev/null ; AgentsToolsHeartbeatBoardActiveItems )"
rigAssert "a heartbeat active-item line carries its totals" "$( printf '%s\n' "$rigBeat" | LC_ALL=C grep '^running/dispatch-20261008T1000Z-rig-a.md' )" \
	'running/dispatch-20261008T1000Z-rig-a.md -- tokens: in=1100 cache-read=200 cache-write=300 out=1400 (incl. 1 sub-session)'
rigProc="$( "$rigFn" --magic-board-to-processed magic-tester task-20261008T1000Z-rig.md --from-state:backlog 2>/dev/null )"
rigAssert "closing a task reports its totals" "$( printf '%s\n' "$rigProc" | LC_ALL=C grep '^tokens: ' )" \
	'tokens: in=1111 cache-read=222 cache-write=333 out=1444 (incl. 3 sub-sessions)'

echo "-- a whole native spawn through the real proxy --"
cat > "$rigTmp/stream.jsonl" <<'RIG_STREAM_EOF'
{"type":"system","subtype":"init","session_id":"cli-1","model":"claude-opus-5-5"}
{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Checking."},{"type":"tool_use","id":"tu_1","name":"mcp__myx_distro__Glob","input":{"pattern":"*.md","path":"/p"}}],"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":40}}}
{"type":"user","message":{"role":"user","content":[{"tool_use_id":"tu_1","type":"tool_result","content":"a.md\nb.md"}]}}
{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"Spawn done.","total_cost_usd":0.0123,"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":40}}
RIG_STREAM_EOF
{
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\n'
	printf '[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf "claude-native\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"\n'
	printf 'L="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"\n'
	printf 'LC_ALL=C awk -f "$L/AgentsProgressLineSafe.awk" -f "$L/AgentsSessionTranscriptFormat.awk" -f "$L/AgentsClaudeStreamJsonTranscript.awk" -f "$L/AgentsClaudeStreamJsonFormat.awk" < "$RIG_STREAM"\n'
} > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigBefore="$( rigCommits )"
printf 'rig brief' | ( cd "$rigWs" && RIG_STREAM="$rigTmp/stream.jsonl" bash "$rigFn" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:create --wait ) > "$rigTmp/proxy.out" 2> "$rigTmp/proxy.err"
rigSpawn="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigTmp/proxy.out" | head -1 )"
rigDispatch="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/proxy.out" | head -1 )"
[ -n "$rigSpawn" ] && [ -n "$rigDispatch" ] || { sed 's/^/    /' "$rigTmp/proxy.err" >&2 ; rigRefuse "the proxy did not report its session and dispatch item" ; }
rigAssert "the spawn succeeded" "$( LC_ALL=C grep -c '^STATUS=succeeded$' "$rigTmp/proxy.out" )" 1
rigRel="$( rigHeader "$rigStore/board/review/$rigDispatch" transcript )"
case "$rigRel" in
	audit/*/session-*-magic-tester-"${rigSpawn:0:8}".log) rigAssert "the dispatch item names its transcript" ok ok ;;
	*) rigAssert "the dispatch item names its transcript" "$rigRel" "audit/YYYY-MM/session-<startUTC>-magic-tester-${rigSpawn:0:8}.log" ;;
esac
rigAssert "so does the spawn tracking file" "$( rigHeader "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.md" transcript )" "$rigRel"
rigAssert "and sessions/<sid>/transcript" "$( cat "$rigWs/.local/agents/sessions/$rigSpawn/transcript" )" "$rigStore/$rigRel"
rigT="$rigStore/$rigRel"
rigAssert "START names member, service, parent and item" "$( LC_ALL=C grep -c " START session=$rigSpawn member=magic-tester service=configured parent=none item=$rigDispatch " "$rigT" )" 1
rigAssert "the stream's lines are there" "$( LC_ALL=C grep -c 'TOOL mcp__myx_distro__Glob pattern="\*.md" path=/p -> ok 9B/2L' "$rigT" )$( LC_ALL=C grep -c ' RESULT outcome=ok' "$rigT" )" 11
rigAssert "END carries outcome, exit and the session's tokens" "$( LC_ALL=C grep -c ' END outcome=succeeded exit=0 tokens="in=10 cache-read=1000 cache-write=100 out=40"' "$rigT" )" 1
rigAssert "the dispatch item's tokens header, as the CLI reported its usage" "$( rigHeader "$rigStore/board/review/$rigDispatch" tokens )" 'in=10 cache-read=1000 cache-write=100 out=40'
rigAssert "milestones: start and end" "$( awk '{ $1 = "" ; print }' "$rigWs/.local/agents/sessions/$rigSpawn/milestones" | tr '\n' '|' )" ' start| end|'
rigAssert "two transcript commits, one per milestone" "$( git -C "$rigStore" log --format=%s -n "$(( $( rigCommits ) - rigBefore ))" | LC_ALL=C grep -c "session transcript" )" 2
rigAssert "and the store is clean" "$( git -C "$rigStore" status --porcelain --untracked-files=all )" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION TOKENS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_TOKENS: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
