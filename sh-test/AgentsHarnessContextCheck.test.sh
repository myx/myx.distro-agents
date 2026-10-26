#!/usr/bin/env bash
## Behavioural check on the universal harness's kept model context (AgentsHarnessContext.include):
## context.jsonl is the exact array the harness sent; a resume from it appends the corrections
## and keeps the request prefix byte for byte; an ineligible resume refuses before any request
## and the proxy falls back to a new process; the transcript rendered from it matches the lines
## the per-call hooks write and is merged by time with the live lines; the event-track feed
## collects its lines into one open post, sent 7 s after its first line with no further line, and
## sent early by no line (an error, a refusal or a session event waits with the rest), against a fake
## Slack, one send at a time and in order, and keeps on disk only what is not yet posted.
## Offline and self-contained: MMDAPP, the team-data store (a temp git repository), HOME and
## the sandbox are fixtures; the model rounds come from a fake curl first on PATH; every live
## session id, data root and calls log is unset, so nothing reaches the real team data.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigAwk=( -f "$rigHere/harness/AgentsHarnessJsonField.awk" -f "$rigHere/session/AgentsSessionTranscriptFormat.awk" -f "$rigHere/harness/AgentsHarnessContextTranscript.awk" )

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
command -v git > /dev/null || rigRefuse "git is not installed"

## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessContextCheck )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] || rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigStore/board/running" "$rigTmp/home" "$rigTmp/bin"
git -C "$rigStore" init -q && printf 'seed\n' > "$rigStore/README.md" && git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the temp store"
## Nothing live is inherited: no session id, no data root, no calls log, no sandbox.
unset CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_MCP_SERVED_MARKER MDAT_MCP_CALLS_LOG MDAT_SESSION_ID MDAT_SESSION_THREAD \
	MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SANDBOX_ROOT_REAL MDAT_SPAWN_CALLER_WAITS MDAT_HARNESS_RESUME_CONTEXT MDAT_HARNESS_RESUME_MARKER MDAT_SPAWN_LAUNCH_MARKER harnessSessionId
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN HOME="$rigTmp/home"
case "$MDAT_DATA_ROOT" in "$rigTmp"/*) ;; *) rigRefuse "the data root is not the temp store" ;; esac

cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

export HARNESS_PROVIDER_NAME="context-check rig" HARNESS_SELF_NAME="AgentsHarnessContextCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-context-check.invalid/v1/messages" HARNESS_HOST="harness-context-check.invalid"
export HARNESS_WIRE="AnthropicMessages" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" HARNESS_CREDENTIAL_NAMES="none"
export HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, fixed text -- 1 when some line holds it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null | awk '{ print ( $1 > 0 ) ? 1 : 0 }'
}
## A transcript's lines with the timestamp, duration, size and paths taken out, in order.
rigNorm(){ ## file
	LC_ALL=C sed -e "s|$rigS1|DIR|g" -e "s|$rigHook|DIR|g" -e 's| [0-9]*B/| NB/|' -e 's/^[0-9-]*T[0-9:]*Z //' -e '/^START /d' "$1" | LC_ALL=C sed -E -e 's/ ([0-9.]+m?s|[0-9]+m[0-9]{2}s)( \||$)/ DUR\2/'
}

. "$rigHere/session/AgentsTools.SessionTranscript.include"

rigToolStream(){ ## file, scenario dir
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":5000,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"RIG-THINK-MARKER\\n"}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"RIG-SIGNATURE-MARKER"}}\n\n'
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Listing the rig."}}\n\n'
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":1}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"Glob","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\\"pattern\\": \\"*.txt\\", \\"path\\": \\"%s\\"}"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":2}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigTextStream(){ ## file, text
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":200,"cache_read_input_tokens":5100,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}

rigSandbox="$rigWs/.local/agents/spawned/rig-sandbox"
mkdir -p "$rigSandbox"
rigCtx="$rigSandbox/context.jsonl"
## One harness run as a spawned session: scenario dir, session id, then extra env assignments, then argv.
rigRun(){ ## scenario dir, session id, env assignments... -- prompt...
	local runDir="$1" runSid="$2" runEnv=()
	shift 2
	while [ $# -gt 0 ] && [ "$1" != "--" ] ; do runEnv+=( "$1" ) ; shift ; done
	shift
	printf '0' > "$runDir/round"
	rigRunStatus=0
	env RIG_SCENARIO="$runDir" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_SESSION_ID="$runSid" ${runEnv[@]+"${runEnv[@]}"} \
		"$rigHarness" --session-id "$runSid" --access-root "$runDir" "$@" > "$runDir/out" 2> "$runDir/err" || rigRunStatus=$?
	rigRounds="$( cat "$runDir/round" )"
}

echo "-- 1. context.jsonl is the array as sent, byte for byte --"
rigSid1="dddd4444-0000-4000-8000-000000000001"
rigS1="$rigTmp/s1"
mkdir -p "$rigS1"
printf 'rig\n' > "$rigS1/a.txt"
rigToolStream "$rigS1/res.1" "$rigS1"
rigTextStream "$rigS1/res.2" RIG-FINAL-MARKER
AgentsTranscriptStart "$rigSid1" "$rigStore" "audit/2026-10/session-ctx.log" magic-tester
rigT1="$rigStore/audit/2026-10/session-ctx.log"
mkdir -p "$rigWs/.local/agents/sessions/$rigSid1"
printf 'CRIG:1.2\n' > "$rigWs/.local/agents/sessions/$rigSid1/event-track"
rigRun "$rigS1" "$rigSid1" -- RIG-TASK-MARKER
[ "$rigRounds" = 2 ] || { sed 's/^/    /' "$rigS1/err" >&2 ; rigRefuse "the harness did not run its two rounds" ; }
rigAssert "the run ends normally" "$rigRunStatus" 0
rigAssert "context.jsonl is kept in the sandbox" "$( [ -s "$rigCtx" ] && echo yes )" yes
rigAssert "it parses: 4 messages (task, the call, its result, the answer)" "$( LC_ALL=C awk -v mode=validate "${rigAwk[@]}" "$rigCtx" )" 4
mkdir -p "$rigTmp/x1"
LC_ALL=C awk -v mode=extract -v dir="$rigTmp/x1" "${rigAwk[@]}" "$rigCtx" > /dev/null
rigReq2="$( cat "$rigS1/req.2" )"
rigSent="${rigReq2#*\"messages\":}" ; rigSent="${rigSent%\}}"
rigKept="[$( cat "$rigTmp/x1/rec.1" ),$( cat "$rigTmp/x1/rec.2" ),$( cat "$rigTmp/x1/rec.3" )]"
rigAssert "messages 1-3 are request 2's messages array, byte for byte" "$( [ "$rigKept" = "$rigSent" ] && echo same || echo differ )" same
rigSys="$( sed -n 2p "$rigCtx" )" ; rigSys="${rigSys#\{\"type\":\"system\",\"text\":\"}" ; rigSys="${rigSys%\"\}}"
rigReqSys="${rigReq2#*\"system\":\"}" ; rigReqSys="${rigReqSys%%\",\"tools\":*}"
rigAssert "the system text is the request's, byte for byte" "$( [ "$rigSys" = "$rigReqSys" ] && echo same || echo differ )" same
rigReqTools="${rigReq2#*\"tools\":}" ; rigReqTools="${rigReqTools%%,\"tool_choice\":*}"
rigAssert "the tools reference is the cksum of the request's tools" "$( sed -n 3p "$rigCtx" | LC_ALL=C awk -v path=cksum -f "$rigHere/harness/AgentsHarnessJsonField.awk" )" "$( printf '%s' "$rigReqTools" | LC_ALL=C cksum | awk '{ print $1 }' )"
rigAssert "the thinking block and its signature are kept" "$( rigHas "$rigTmp/x1/rec.2" '{"type":"thinking","thinking":"RIG-THINK-MARKER\n","signature":"RIG-SIGNATURE-MARKER"}' )" 1
rigAssert "the tool result keeps its tool_use id" "$( rigHas "$rigTmp/x1/rec.3" '"tool_use_id":"toolu_RIG"' )" 1
rigAssert "the answer is kept as the assistant turn it was" "$( cat "$rigTmp/x1/rec.4" )" '{"role":"assistant","content":[{"type":"text","text":"RIG-FINAL-MARKER"}]}'
rigAssert "the header names session, model, service, API host and wire" \
	"$( head -1 "$rigCtx" | LC_ALL=C grep -c -F "\"session\":\"$rigSid1\",\"member\":\"\",\"service\":\"context-check rig\",\"model\":\"rig-main\",\"api_host\":\"harness-context-check.invalid\",\"wire\":\"AnthropicMessages\"" )" 1
rigCtxBytes="$( wc -c < "$rigCtx" | tr -d ' ' )"
printf '  (context.jsonl: %s bytes for 4 messages)\n' "$rigCtxBytes"
rigAssert "nothing is kept with MDAT_HARNESS_CONTEXT=off" "$( rm -f "$rigCtx.off" ; mkdir -p "$rigTmp/s0" ; cp "$rigS1"/res.* "$rigTmp/s0/" ; rigSandboxWas="$rigSandbox" ; rigSandbox="$rigTmp/sb0" ; mkdir -p "$rigSandbox" ; rigRun "$rigTmp/s0" "eeee5555-0000-4000-8000-000000000000" MDAT_HARNESS_CONTEXT=off -- RIG-TASK-MARKER ; ls "$rigSandbox" | LC_ALL=C grep -c context ; rigSandbox="$rigSandboxWas" )" 0
rigAssert "nor for a --wait spawn (MDAT_SPAWN_CALLER_WAITS=true)" "$( mkdir -p "$rigTmp/sw" ; cp "$rigS1"/res.* "$rigTmp/sw/" ; rigSandbox="$rigTmp/sbw" ; mkdir -p "$rigSandbox" ; rigRun "$rigTmp/sw" "eeee5555-0000-4000-8000-00000000000a" MDAT_SPAWN_CALLER_WAITS=true -- RIG-TASK-MARKER ; ls "$rigSandbox" | LC_ALL=C grep -c context )" 0

echo "-- 2. the transcript's model rounds come from the log --"
rigHook="$rigTmp/hook"
mkdir -p "$rigHook" "$rigTmp/sbh"
cp "$rigS1"/res.* "$rigHook/"
printf 'rig\n' > "$rigHook/a.txt"
rigToolStream "$rigHook/res.1" "$rigHook"
rigSidH="eeee5555-0000-4000-8000-00000000000b"
AgentsTranscriptStart "$rigSidH" "$rigStore" "audit/2026-10/session-hook.log" magic-tester
( rigSandbox="$rigTmp/sbh" ; rigRun "$rigHook" "$rigSidH" MDAT_HARNESS_CONTEXT=off -- RIG-TASK-MARKER )
rigTH="$rigStore/audit/2026-10/session-hook.log"
rigAssert "the per-call hooks wrote the control transcript" "$( rigHas "$rigTH" ' TOOL Glob ' )" 1
rigAssert "the rendered transcript holds the same lines as the per-call hooks wrote" \
	"$( rigNorm "$rigT1" | tr '\n' '|' )" "$( rigNorm "$rigTH" | tr '\n' '|' )"
rigAssert "the ROUND line, with its tokens" "$( rigHas "$rigT1" 'ROUND n=1 in=100 cache-read=0 cache-write=5000 out=40' )" 1
rigAssert "the TOOL line, key args, outcome, size and the round's text" "$( LC_ALL=C grep -c "TOOL Glob pattern=\"\*.txt\" path=$rigS1 -> ok [0-9]*B/1L [0-9.]*m*s | \"Listing the rig.\"" "$rigT1" )" 1
rigAssert "no thinking and no file content" "$( LC_ALL=C grep -c -e RIG-THINK -e RIG-SIGNATURE "$rigT1" )" 0
rigAssert "lines are in time order" "$( LC_ALL=C cut -c1-20 "$rigT1" | LC_ALL=C grep -v '^>' | LC_ALL=C sort -c 2>&1 && echo sorted )" sorted
rigAssert "the final milestone committed it" "$( git -C "$rigStore" status --porcelain -- audit/2026-10/session-ctx.log )" ""
rigAssert "the live feed got the same tool line" "$( rigHas "$rigWs/.local/agents/sessions/$rigSid1/feed" "TOOL Glob pattern=\"*.txt\" path=$rigS1 -> ok" )" 1
rigAssert "and the round" "$( rigHas "$rigWs/.local/agents/sessions/$rigSid1/feed" 'ROUND n=1 in=100' )" 1

## The merge: a hand-made log and live lines, interleaved by time, the live line first on a tie.
rigSidM="ffff6666-0000-4000-8000-000000000001"
rigM="$rigTmp/merge"
mkdir -p "$rigM"
AgentsTranscriptStart "$rigSidM" "$rigStore" "audit/2026-10/session-merge.log" magic-tester
rigTM="$rigStore/audit/2026-10/session-merge.log"
{
	printf '%s\n' '{"type":"context","version":1,"session":"'"$rigSidM"'","leg":1,"from":0}'
	printf '%s\n' '{"type":"system","text":"S"}'
	printf '%s\n' '{"type":"tools","cksum":"1","bytes":2}'
	printf '%s\n' '{"type":"message","n":1,"leg":1,"kind":"system","round":0,"ts":"2030-01-01T00:00:00Z","ms":0,"record":{"role":"system","content":"S"}}'
	printf '%s\n' '{"type":"message","n":2,"leg":1,"kind":"assistant","round":1,"ts":"2030-01-01T00:00:10Z","ms":0,"in":5,"cache_read":0,"cache_write":0,"out":2,"record":{"role":"assistant","content":"Sending.","tool_calls":[{"id":"c1","type":"function","function":{"name":"SendMessage","arguments":"{\"to\":\"C1:2.3\",\"message\":\"hi there\"}"}}]}}'
	printf '%s\n' '{"type":"message","n":3,"leg":1,"kind":"tool","round":1,"ts":"2030-01-01T00:00:30Z","ms":0,"tool":"SendMessage","id":"c1","dur_ms":1500,"outcome":"ok","record":{"role":"tool","tool_call_id":"c1","content":"Sent to C1"}}'
	printf '%s\n' '{"type":"message","n":4,"leg":1,"kind":"tool","round":1,"ts":"2030-01-01T00:00:40Z","ms":0,"tool":"Read","id":"c9","dur_ms":5,"outcome":"error","record":{"role":"tool","tool_call_id":"c9","content":"ERROR: no such file\nsecond line"}}'
} > "$rigM/context.jsonl"
printf '%s\n' "$rigM/context.jsonl" > "$rigWs/.local/agents/sessions/$rigSidM/context"
printf '2030-01-01T00:00:20Z REVIEW item=rig-item\n2030-01-01T00:00:30Z VERDICT item=rig-item\n> live body\n' >> "$rigTM"
AgentsTranscriptMilestone "$rigSidM" "rig merge"
rigAssert "rendered and live lines merged by time, a tie putting the rendered line first" "$( sed -n '2,$p' "$rigTM" | sed 's/^[0-9-]*T[0-9:]*Z //' | tr '\n' '|' )" \
	'ROUND n=1 in=5 cache-read=0 cache-write=0 out=2|> Sending.|REVIEW item=rig-item|TOOL SendMessage to=C1:2.3 message="hi there" -> ok 10B/1L 1.5s | "Sending."|MSG-OUT to=C1:2.3|> hi there|VERDICT item=rig-item|> live body|TOOL Read -> error "ERROR: no such file" 31B/2L 5ms | "Sending."|> ERROR: no such file|> second line|'
printf '2030-01-01T00:00:50Z NOTE by=rig\n' >> "$rigTM"
AgentsTranscriptMilestone "$rigSidM" "rig again"
rigAssert "a later milestone with nothing new in the log renders nothing again" "$( LC_ALL=C grep -c ' ROUND ' "$rigTM" ):$( tail -1 "$rigTM" | sed 's/^[0-9-]*T[0-9:]*Z //' )" "1:NOTE by=rig"

echo "-- 3. a resume appends the corrections and keeps the prefix --"
rigSid2="dddd4444-0000-4000-8000-000000000002"
rigS2="$rigTmp/s2"
mkdir -p "$rigS2"
rigTextStream "$rigS2/res.1" RIG-RESUMED-ANSWER
cp "$rigCtx" "$rigTmp/context.before"
## A child of the resumed session, spawned since the context was kept: its sandbox is a root of this leg, and a root the kept messages cannot name.
rigChild="$rigWs/.local/agents/spawned/rig-child"
mkdir -p "$rigChild/input" "$rigChild/output"
printf -- '---\nspawn-id: rig-child\nparent-spawn-id: %s\n---\n' "$rigSid2" > "$rigChild/rig-child.spawn.md"
rigRun "$rigS2" "$rigSid2" MDAT_HARNESS_RESUME_CONTEXT="$rigCtx" MDAT_HARNESS_RESUME_MARKER="$rigTmp/resume.mark" -- RIG-CORRECTIONS
rm -rf -- "$rigChild"
rigAssert "the resumed run ends normally, in one request" "$rigRunStatus:$rigRounds" 0:1
rigAssert "it marks the resume for the proxy" "$( [ -e "$rigTmp/resume.mark" ] && echo yes )" yes
## This session's results folder and its child's sandbox are roots the kept messages do not name (F10.7): the turn that brings them is the one
## that tells them, ahead of the corrections, and nothing kept is written over. The child's input/ is the one of them that may be written.
rigNewRoot="$rigWs/.local/agents/sessions/$rigSid2/results"
rigWant="${rigReq2%]\}},$( cat "$rigTmp/x1/rec.4" ),{\"role\":\"user\",\"content\":\"Beside the access roots in your system instructions, these are yours for this run alone:\\n$rigNewRoot\\n$rigWs/.local/agents/spawned/rig-child/output\\nWrite and Edit may only write under these of them:\\n$rigWs/.local/agents/spawned/rig-child/input\\nYou may read, list, search and run commands in the others, but not write to them. Do not try to work around that -- report it instead.\\n\\nRIG-CORRECTIONS\"}]}"
rigAssert "the request is the old one, its answer, then the corrections as a new user turn, headed by the roots this session has that the old one does not name" "$( [ "$( cat "$rigS2/req.1" )" = "$rigWant" ] && echo exact || echo differ )" exact
rigAssert "those roots are in the request once each, and a root the old request named (the sandbox's input/) is not told again: once, where it was"  "$( LC_ALL=C grep -o -F "$rigNewRoot" "$rigS2/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F '/spawned/rig-child/output' "$rigS2/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F "$rigSandbox/input" "$rigS2/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F 'these are yours for this run alone' "$rigS2/req.1" | wc -l | tr -d ' ' )" 1:1:1:2
rigPrefix="${rigReq2%]\}}"
rigNewReq="$( cat "$rigS2/req.1" )"
rigAssert "so the old request is its prefix, byte for byte" "$( [ "${rigNewReq:0:${#rigPrefix}}" = "$rigPrefix" ] && echo prefix || echo no )" prefix
rigAssert "the kept context continues: 6 messages, now this session's, the 4 loaded not its own" \
	"$( LC_ALL=C awk -v mode=validate "${rigAwk[@]}" "$rigCtx" ):$( head -1 "$rigCtx" | LC_ALL=C awk -v path=session -f "$rigHere/harness/AgentsHarnessJsonField.awk" ):$( head -1 "$rigCtx" | LC_ALL=C awk -v path=from -f "$rigHere/harness/AgentsHarnessJsonField.awk" )" "6:$rigSid2:4"
rigAssert "a later restart would carry the task and the corrections" "$( head -1 "$rigCtx" | LC_ALL=C awk -v path=task -f "$rigHere/harness/AgentsHarnessJsonField.awk" | tr '\n' '|' )" "RIG-TASK-MARKER||RIG-CORRECTIONS|"

echo "-- 3b. a resume replays the system as the blocks it was sent as --"
## A member's system text is the team layer: two blocks, the team's identity/basic with a cache marker at its end and the harness paragraph
## after it; the member layer is the first block of the first user message (F10.7). The context keeps the system as the one string it also is,
## and the size of the first block's text; the resumed request has the same two blocks and the same marker, so it is the original through the
## team block's marker, byte for byte, and never one string.
rigSk="$rigTmp/skills"
mkdir -p "$rigSk/magic-team" "$rigSk/rig-a"
printf 'RIG-TEAM-COMMON-LINE one two\n' > "$rigSk/magic-team/magic-team.basic.md"
printf 'RIG-A-BASIC own words\n' > "$rigSk/rig-a/rig-a.basic.md"
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSk/magic-team/SKILL.md"
printf -- '---\nname: rig-a\n---\nmember skill\n' > "$rigSk/rig-a/SKILL.md"
rigSandboxWas="$rigSandbox" ; rigSandbox="$rigTmp/sb4" ; mkdir -p "$rigSandbox"
rigS4="$rigTmp/s4a" ; rigS5="$rigTmp/s4b" ; mkdir -p "$rigS4" "$rigS5"
rigTextStream "$rigS4/res.1" RIG-ANSWER-ONE ; rigTextStream "$rigS5/res.1" RIG-ANSWER-TWO
rigRun "$rigS4" "dddd4444-0000-4000-8000-0000000000a1" MDAT_SKILLSET_ROOT="$rigSk" -- --agent rig-a RIG-TASK-MARKER
rigOrigStatus="$rigRunStatus"
rigRun "$rigS5" "dddd4444-0000-4000-8000-0000000000a2" MDAT_SKILLSET_ROOT="$rigSk" MDAT_HARNESS_RESUME_CONTEXT="$rigSandbox/context.jsonl" MDAT_HARNESS_RESUME_MARKER="$rigTmp/resume4.mark" -- --agent rig-a RIG-CORRECTIONS
rigAssert "the original and the resumed run end normally, in one request each"  "$rigOrigStatus:$rigRunStatus:$( cat "$rigS4/round" ):$( cat "$rigS5/round" ):$( [ -e "$rigTmp/resume4.mark" ] && echo marked )" 0:0:1:1:marked
rigBlocks='"system":"## Team-wide -- the same for every member and every session of this team\n\nRIG-TEAM-COMMON-LINE one two'
rigAssert "the original sends the system as one string, the team layer with the paragraph every run carries"  "$( LC_ALL=C grep -c -F -- "$rigBlocks" "$rigS4/req.1" ):$( LC_ALL=C grep -c -F -- 'Use the given tools to accomplish the request' "$rigS4/req.1" ):$( LC_ALL=C grep -c -F -- '"system":[' "$rigS4/req.1" )" 1:1:0
rigAssert "the resumed request sends the same system string"  "$( LC_ALL=C grep -c -F -- "$rigBlocks" "$rigS5/req.1" ):$( LC_ALL=C grep -c -F -- '"system":[' "$rigS5/req.1" )" 1:0
rigSysOf(){ ## request file -- the system field as sent
	LC_ALL=C sed -e 's/.*"system"://' -e 's/,"tools":\[.*//' "$1"
}
rigAssert "the system field of the resumed request is the original's, byte for byte"  "$( [ "$( rigSysOf "$rigS4/req.1" )" = "$( rigSysOf "$rigS5/req.1" )" ] && echo same || echo differ )" same
rigMarkEnd=$(( $( LC_ALL=C awk 'BEGIN { RS = "\001" ; mark = "\"cache_control\":{\"type\":\"ephemeral\"}" } { m = index( $0, "\"role\":\"user\"" ) ; k = index( substr( $0, m ), mark ) ; print m + k - 1 + length( mark ) - 1 }' "$rigS4/req.1" ) ))
head -c "$rigMarkEnd" "$rigS4/req.1" > "$rigTmp/orig.head" ; head -c "$rigMarkEnd" "$rigS5/req.1" > "$rigTmp/resumed.head"
rigAssert "the resumed request is the original through the member block's marker, byte for byte (the body's opening, system, tools and member)"  "$( cmp -s "$rigTmp/orig.head" "$rigTmp/resumed.head" && [ "$rigMarkEnd" -gt 150 ] && echo same || echo differ )" same
rigToolsOf(){ ## request file -- the tools field as sent
	LC_ALL=C sed -e 's/.*,"tools"://' -e 's/,"tool_choice":.*//' "$1"
}
rigAssert "and its tools, which the API caches ahead of the system, are the original's byte for byte"  "$( [ "$( rigToolsOf "$rigS4/req.1" )" = "$( rigToolsOf "$rigS5/req.1" )" ] && echo same || echo differ )" same
rigAssert "and has the same markers: the moving one, the end of the floor, the end of the member block"  "$( LC_ALL=C grep -o '"cache_control":{"type":"ephemeral"}' "$rigS4/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o '"cache_control":{"type":"ephemeral"}' "$rigS5/req.1" | wc -l | tr -d ' ' )" 3:3
rigAssert "the context keeps no split system: system_shared is 0"  "$( head -1 "$rigSandbox/context.jsonl" | LC_ALL=C awk -v path=system_shared -f "$rigHere/harness/AgentsHarnessJsonField.awk" )" 0
## The same with the hour asked of the cache (F10.7): the resumed system carries the same markers, each with its ttl.
rigSandbox="$rigTmp/sb5" ; mkdir -p "$rigSandbox"
rigS6="$rigTmp/s5a" ; rigS7="$rigTmp/s5b" ; mkdir -p "$rigS6" "$rigS7"
rigTextStream "$rigS6/res.1" RIG-ANSWER-ONE ; rigTextStream "$rigS7/res.1" RIG-ANSWER-TWO
rigRun "$rigS6" "dddd4444-0000-4000-8000-0000000000b1" MDAT_SKILLSET_ROOT="$rigSk" HARNESS_INPUT_CACHE_TIME=1h -- --agent rig-a RIG-TASK-MARKER
rigRun "$rigS7" "dddd4444-0000-4000-8000-0000000000b2" MDAT_SKILLSET_ROOT="$rigSk" HARNESS_INPUT_CACHE_TIME=1h MDAT_HARNESS_RESUME_CONTEXT="$rigSandbox/context.jsonl" MDAT_HARNESS_RESUME_MARKER="$rigTmp/resume5.mark" -- --agent rig-a RIG-CORRECTIONS
rigAssert "asked the hour, the original and the resumed request have three markers each, every one with the ttl, none plain"  "$( LC_ALL=C grep -o '"cache_control":{"type":"ephemeral","ttl":"1h"}' "$rigS6/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o '"cache_control":{"type":"ephemeral","ttl":"1h"}' "$rigS7/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o '"cache_control":{"type":"ephemeral"}' "$rigS6/req.1" "$rigS7/req.1" | wc -l | tr -d ' ' )" 3:3:0
rigAssert "and the resumed system field is the original's, byte for byte"                    "$( [ "$( rigSysOf "$rigS6/req.1" )" = "$( rigSysOf "$rigS7/req.1" )" ] && echo same || echo differ )" same
rigSandbox="$rigSandboxWas"

echo "-- 4. an ineligible resume refuses before any request, and the proxy falls back --"
rigS3="$rigTmp/s3"
mkdir -p "$rigS3"
rigTextStream "$rigS3/res.1" NEVER
rm -f "$rigTmp/resume.mark"
rigRun "$rigS3" "dddd4444-0000-4000-8000-000000000003" HARNESS_MODEL_MAIN=rig-other MDAT_HARNESS_RESUME_CONTEXT="$rigCtx" MDAT_HARNESS_RESUME_MARKER="$rigTmp/resume.mark" -- RIG-CORRECTIONS
rigAssert "another model: rc 7, no request, no mark" "$rigRunStatus:$rigRounds:$( [ -e "$rigTmp/resume.mark" ] && echo marked || echo none )" 7:0:none
rigAssert "and it says why" "$( rigHas "$rigS3/err" 'the context was kept for model rig-main, this run is rig-other' )" 1
printf '{"type":"context"\n' > "$rigTmp/broken.jsonl"
rigRun "$rigS3" "dddd4444-0000-4000-8000-000000000004" MDAT_HARNESS_RESUME_CONTEXT="$rigTmp/broken.jsonl" -- RIG-CORRECTIONS
rigAssert "a file that does not parse: rc 7, no request" "$rigRunStatus:$rigRounds" 7:0

. "$rigHere/board/AgentsTools.ReviewFlow.include"
. "$rigHere/harness/AgentsTools.HarnessResume.include"
rigRecords="$rigTmp/records"
AgentsReviewRecord(){ printf '%s\n' "$3: $4 [$5 $6]" >> "$rigRecords" ; }
rigFakeWs="$rigTmp/fakews"
mkdir -p "$rigFakeWs/.local/temp"
cat > "$rigFakeWs/DistroAgentsConsole.sh" << 'RIGEOF'
#!/usr/bin/env bash
rigIn="$( cat )"
printf '%s|%s\n' "${MDAT_HARNESS_RESUME_CONTEXT:+resume}" "$rigIn" >> "$RIG_CONSOLE_LOG"
if [ -n "${MDAT_HARNESS_RESUME_CONTEXT:-}" ] ; then
	[ "$RIG_CONSOLE_MODE" = ok ] || exit 7
	: > "$MDAT_HARNESS_RESUME_MARKER"
fi
exit 0
RIGEOF
chmod +x "$rigFakeWs/DistroAgentsConsole.sh"
rigProxyRun(){ ## mode
	: > "$rigRecords" ; : > "$rigTmp/console.log"
	## The run starts the console of the workspace it is in, so the fake one is MMDAPP for this call.
	( export RIG_CONSOLE_MODE="$1" RIG_CONSOLE_LOG="$rigTmp/console.log" MDAT_SPAWN_SESSION_ID=rig-new MDAT_SPAWN_LAUNCH_MARKER="$rigFakeWs/.local/temp/rig.launch" MDSC_CMD=rig MMDAPP="$rigFakeWs"
	  AgentsToolsSpawnProxyHarnessResumeRun sess "C1:2.3" "" RIG-FULL-BRIEF "$rigCtx" RIG-CORRECTIONS magic-tester rig-item.md --cli rig 2>/dev/null )
}
rigProxyRun refuse
rigAssert "the proxy falls back once: the resume, then the full brief" "$( tr '\n' '#' < "$rigTmp/console.log" )" "resume|RIG-CORRECTIONS#|RIG-FULL-BRIEF#"
rigAssert "and records the new process with why" "$( cat "$rigRecords" )" "review: restart: new-process (the harness resume from the kept context exited 7 before its first request) [RESTART rig-new]"
rigProxyRun ok
rigAssert "an eligible resume runs once" "$( tr '\n' '#' < "$rigTmp/console.log" )" "resume|RIG-CORRECTIONS#"
rigAssert "and records restart: resumed-context" "$( cat "$rigRecords" )" "review: restart: resumed-context (from $rigSid2) [RESTART rig-new]"
## Eligibility, from the old session's spawn record.
rigRec="$rigSandbox/$rigSid2.spawn.md"
printf -- '---\ncli: rig-leg\ncli-setting: rig+-\nhost: %s\nstatus: spawn-ended\n---\n' "$( hostname -s )" > "$rigRec"
AgentsReviewCliResolved(){ printf 'rig-leg' ; }
AgentsReviewCliSetting(){ printf 'rig+-' ; }
rigAssert "a harness session with its kept context is eligible" "$( AgentsReviewContextResumeEligible "$rigRec" ; echo " rc=$?" )" "$rigCtx rc=0"
printf -- '---\ncli: claude-native\ncli-setting: rig+-\nhost: %s\n---\n' "$( hostname -s )" > "$rigTmp/native.md"
rigAssert "a native session is not" "$( AgentsReviewContextResumeEligible "$rigTmp/native.md" ; echo " rc=$?" )" "the old session ran on claude-native, a native CLI, not the universal harness rc=1"
cp "$rigRec" "$rigSandbox/$rigSid1.spawn.md"
rigAssert "nor a session whose context another session kept since" "$( AgentsReviewContextResumeEligible "$rigSandbox/$rigSid1.spawn.md" ; echo " rc=$?" )" "the kept context belongs to session $rigSid2, not $rigSid1 rc=1"
AgentsReviewCliResolved(){ printf 'other-leg' ; }
rigAssert "nor one whose cli changed" "$( AgentsReviewContextResumeEligible "$rigRec" ; echo " rc=$?" )" "the cli is now other-leg, the old session ran on rig-leg rc=1"

echo "-- 5. event-track: one open post, sent 7 s after its first line and by no line early, against a fake Slack --"
. "$rigHere/session/AgentsTools.EventTrackFeed.include"
rigSlack="$rigTmp/slack"
: > "$rigSlack"
## The post op's own rendering and cutting are AgentsEventTrackPostCheck's: this fake keeps what the feed hands it,
## each send's end marked, so the order and one-at-a-time show.
AgentsEventTrackFeedSend(){ { printf 'POST %s %s %s\n' "$1" "$2" "$3" ; cat ; printf 'SENT\n' ; } >> "$rigSlack" ; }
rigSidF="ffff6666-0000-4000-8000-000000000002"
AgentsTranscriptStart "$rigSidF" "$rigStore" "audit/2026-10/session-feed.log" magic-tester
AgentsTranscriptEvent "$rigSidF" NOTE "" 0 by rig
rigAssert "no feed before the thread is open" "$( [ -e "$rigWs/.local/agents/sessions/$rigSidF/feed" ] && echo yes || echo no )" no
AgentsEventTrackFeedOpen "$rigSidF" "CRIG:9.9"
AgentsTranscriptEvent "$rigSidF" VERDICT "" 0 item rig-item
rigAssert "a transcript event goes to the open feed too" "$( LC_ALL=C grep -c ' VERDICT item=rig-item' "$rigWs/.local/agents/sessions/$rigSidF/feed" )" 1
rigPosts(){ LC_ALL=C grep -c '^POST ' "$rigSlack" ; }
## The removed knobs set, to show they change nothing: the window is fixed in code, and no kind of line sends a post.
( MDAT_EVENT_TRACK_BATCH_SECONDS=1 MDAT_EVENT_TRACK_IMMEDIATE_KINDS=VERDICT AgentsEventTrackFeedRun "$rigSidF" magic-tester "CRIG:9.9" ) &
rigFeedPid=$!
rigProcNote "$rigFeedPid"
sleep 3
rigAssert "an ordinary line waits in the open post, whatever the removed knobs say" "$( rigPosts )" 0
sleep 3
rigAssert "and is still waiting 6 s after its first line, the window being 7 s" "$( rigPosts )" 0
sleep 5
rigAssert "7 s after its first line the open post goes, with no further line, to the thread" "$( rigPosts ):$( sed -n 1p "$rigSlack" ):$( rigHas "$rigSlack" ' VERDICT item=rig-item' )" "1:POST magic-tester CRIG:9.9 $rigSidF:1"
rigFeed="$rigWs/.local/agents/sessions/$rigSidF/feed"
## The feed is a buffer, never a second log: what was posted is no longer in it.
rigAssert "the feed buffer no longer holds what was posted" "$( cat "$rigFeed" "$rigFeed.posting" 2>/dev/null | LC_ALL=C grep -c ' VERDICT item=rig-item' )" 0
printf '2030-01-01T00:01:00Z TOOL Read path=/x -> ok 3B/1L 2ms\n' >> "$rigFeed"
printf '2030-01-01T00:01:01Z TOOL Edit path=/x -> refused "ERROR: refused by a hook"\n> ERROR: refused by a hook\n' >> "$rigFeed"
## The feed is polled every 4 s, fixed in code: a line is read within 4 s and its window then runs 7 s.
sleep 5
rigAssert "a refusal does not send the open post: nothing new went 5 s on" "$( rigPosts )" 1
sleep 8
rigAssert "the window ended: one post, the Read first and the refusal last" \
	"$( rigPosts ):$( LC_ALL=C awk '/^POST /{ n++ ; next } n == 2 && /^2030/ { printf "%s ", $3 }' "$rigSlack" )" "2:Read Edit "
rigAssert "the posted lines are gone from the buffer" "$( cat "$rigFeed" "$rigFeed.posting" 2>/dev/null | LC_ALL=C grep -c 'path=/x' )" 0
printf '2030-01-01T00:01:02Z ROUND n=4 in=1 cache-read=2 cache-write=0 out=3\n' >> "$rigFeed"
printf '2030-01-01T00:01:03Z RESTART n=1 summary=10B\n' >> "$rigFeed"
sleep 5
rigAssert "a ROUND line and a session event (a restart) wait in the open post, as ordinary lines do" "$( rigPosts )" 2
sleep 8
rigAssert "the window ended: the ROUND and the RESTART go in one post" \
	"$( rigPosts ):$( LC_ALL=C awk '/^POST /{ n++ ; next } n == 3 && /^2030/ { printf "%s ", $2 }' "$rigSlack" )" "3:ROUND RESTART "
printf '2030-01-01T00:01:04Z TOOL Glob pattern=* -> ok 1B/1L 1ms\n' >> "$rigFeed"
sleep 5
rigProcSignal TERM "$rigFeedPid" ; wait "$rigFeedPid" 2>/dev/null
rigAssert "what is still open is posted when the poster is stopped" "$( rigPosts ):$( tail -2 "$rigSlack" | LC_ALL=C grep -c 'TOOL Glob' )" 4:1
## The buffer is `feed`, and `feed.posting` while a post of it is out. `feed.open` is the
## feed's switch (AgentsTools.EventTrackThread.include), which stays, and holds no line.
rigAssert "and no feed buffer is left behind once all of it is posted" "$( ls "$rigWs/.local/agents/sessions/$rigSidF" | LC_ALL=C grep -c -x -e 'feed' -e 'feed\.posting' ):$( [ -s "$rigWs/.local/agents/sessions/$rigSidF/feed.open" ] && printf lines || printf empty )" "0:empty"
rigAssert "strict order: every line the feed got was posted once, in the order it came" \
	"$( LC_ALL=C awk '/^2030|^20[0-9][0-9]-/ { printf "%s ", $2 }' "$rigSlack" )" "VERDICT TOOL TOOL ROUND RESTART TOOL "
rigAssert "one at a time: each send ended before the next began" "$( LC_ALL=C grep -e '^POST ' -e '^SENT$' "$rigSlack" | LC_ALL=C awk '{ printf "%s ", $1 }' )" "POST SENT POST SENT POST SENT POST SENT "
: > "$rigSlack"
rigOpenLeft="$( AgentsEventTrackFeedPost magic-tester "CRIG:9.9" "$( for rigI in 1 2 3 4 5 ; do printf '2030-01-01T00:02:0%sZ TOOL Read path=/a/long/enough/path%s -> ok\n' "$rigI" "$rigI" ; done ; printf '2030-01-01T00:02:06Z ERROR boom\n' )" "$rigSidF" 1 )"
rigAssert "the lines, an error among them, go to the post op whole at the window's end, as one post (the op cuts it to size), nothing left open" \
	"$( rigPosts ):$( sed -n 1p "$rigSlack" ):$( LC_ALL=C grep -c -e 'TOOL Read path=/a/long/enough/path' -e 'ERROR boom' "$rigSlack" ):$rigOpenLeft" "1:POST magic-tester CRIG:9.9 $rigSidF:6:"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CONTEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CONTEXT: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
