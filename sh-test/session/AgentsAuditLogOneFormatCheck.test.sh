#!/usr/bin/env bash
## Behavioural check on S12.5: every harness writes the same audit log. A DeepSeek run keeps its
## model context, and with it kept its ROUND and TOOL lines reach the audit file only at a
## milestone, rendered from context.jsonl; a claude-native run writes each line as it happens.
## The lines belong where the context gains records, so this check drives `AgentsHarnessContextSync`
## with a message array — the same call the model loop makes — and reads the audit file after it.
## Held:
##   1. A round's ROUND line is in the audit file as soon as the round's record is synced. Today the
##      file holds START and MODEL only, and the line waits for the next milestone.
##   2. A tool result's TOOL line is there as soon as the tool record is synced. Today it waits too.
##   3. Both writers name a tool without the `mcp__<server>__` prefix: `Grep`, never
##      `mcp__myx_distro__Grep`. Today the native stream writer's line keeps the prefix.
##   4. A ROUND line carries the round's real output count, never a constant: the number the round's
##      own usage reported, and a round that produced tokens writes a number above zero.
##   5. The same round and the same call, written by both writers, carry the same key form: ROUND's
##      keys in one order, and TOOL's outcome, size and line count in one order.
##   6. The log is append order and each line lands once. A review recorded while a round is open
##      stands before the TOOL line of the handback it answers, and a sync with nothing new beside a
##      second milestone adds no line a second time. This is a guard, not a red case: the pristine
##      tree passes it too, because the merge that could reorder or repeat a line no longer runs.
##      What proves the guard is its own instrument test -- a sample file with the two lines in the
##      wrong order, and one holding a line twice, each read the way the case reads the audit file.
##   8. A message out reaches the same audit file as its TOOL and ROUND lines, in one form, in both
##      harnesses: the native run's stream writer writes the TOOL and ROUND lines, its served call the MSG-OUT.
## Red before S12.5: cases 1 and 2 fail, and case 3 fails for the native writer. Cases 0, 4, 5 and 6
## are the controls that keep a fix from paying for itself out of them. Case 8 is a guard: the format
## holds today, and a scratch copy whose writer respells the line turns it red.
## Offline: the store, the workspace and the session are this rig's own; nothing opens a socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPkg/sh-lib"
rigInclude="$rigHere/session/AgentsTools.SessionTranscript.include"
rigContextInclude="$rigHere/harness/AgentsHarnessContext.include"
rigContextAwk="$rigHere/harness/AgentsHarnessContextTranscript.awk"
rigFormatAwk="$rigHere/session/AgentsSessionTranscriptFormat.awk"
rigStreamAwk="$rigHere/harness/AgentsClaudeStreamJsonTranscript.awk"
rigStreamFormatAwk="$rigHere/harness/AgentsClaudeStreamJsonFormat.awk"
rigProgressAwk="$rigHere/core/AgentsProgressLineSafe.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigInclude" "$rigContextInclude" "$rigContextAwk" "$rigFormatAwk" "$rigStreamAwk" "$rigStreamFormatAwk" "$rigProgressAwk" ; do
	[ -f "$rigFile" ] || rigRefuse "not at the origin this workspace resolves: $rigFile"
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAuditLogOneFormatCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
rigScratch="$rigTmp/scratch"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions" "$rigStore/audit/2026-11" "$rigTmp/home" "$rigScratch" "$rigTmp/sandbox"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$rigOrigin" HOME="$rigTmp/home"
export MDAT_WORKSPACE_MODE=team-rig MDAT_HARNESS_CONTEXT=on MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/sandbox"
unset CLAUDE_CODE_SESSION_ID MDAT_SESSION_ID harnessSessionId
## The harness's own names the context functions read, set before the includes load: the context
## include builds its awk list from `harnessHere` at load time. The check calls the one function the
## model loop calls, not a copy of its body.
harnessHere="$rigHere"
harnessWire="OpenAiChat"
harnessScratch="$rigScratch"
harnessProviderName="DeepSeek" ; harnessModel="rig-main" ; harnessHost="rig.invalid" ; harnessTier=normal
harnessAgent="rig-member" ; harnessToolsJson='[]' ; harnessMcpToolsJson=''
harnessRound=1
set +u
. "$rigInclude"
. "$rigContextInclude"
## The event-track helper's own chain reaches the tooling's dispatch file, which reads a positional
## parameter; loaded here, at the top level and once, so the context init finds it already there.
. "$rigHere/event-track/AgentsTools.EventTrackThread.include"
set -u
rigHas(){ ## file, fixed text -- 1 when some line holds it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null | LC_ALL=C awk '{ print ( $1 > 0 ) ? 1 : 0 }'
}

echo "-- 1. a round's ROUND line is in the audit file as soon as the round is synced (S12.5) --"
rigKeptSid="dddd1111-0000-4000-8000-000000000001"
AgentsTranscriptStart "$rigKeptSid" "$rigStore" "audit/2026-11/session-kept.log" rig-member
rigT="$rigStore/audit/2026-11/session-kept.log"
export MDAT_SPAWN_SESSION_ID="$rigKeptSid"
AgentsHarnessContextInit
rigAssert "control: the run keeps its context, so its lines are the rendered ones" "${agentsTranscriptFromLog:-none}" 1
harnessMessages=( '{"role":"system","content":"RIG-SYSTEM"}' '{"role":"user","content":"RIG-TASK"}' )
AgentsHarnessContextBegin 0
AgentsTranscriptHarnessStart
rigAssert "control: the run's audit file exists and holds its START line" "$( rigHas "$rigT" ' START session=' )" 1
printf '1234 300 0 7\n' > "$rigScratch/stream.usage.detail"
printf 'Reading the rig file.\n' > "$rigScratch/stream.content"
harnessMessages+=( '{"role":"assistant","content":"Reading the rig file."}' )
AgentsHarnessContextSync assistant "$( AgentsHarnessContextAssistantMeta )"
rigAssert "1. the ROUND line is in the audit file after the round's record is synced" "$( rigHas "$rigT" ' ROUND n=1 ' )" 1

echo "-- 2. a tool result's TOOL line is in the audit file as soon as the tool record is synced --"
AgentsTranscriptToolStart 'mcp__myx_distro__Grep'
harnessMessages+=( '{"role":"tool","tool_call_id":"rig-call-1","content":"a\nb"}' )
AgentsHarnessContextSync tool "$( AgentsHarnessContextToolMeta 'mcp__myx_distro__Grep' 'rig-call-1' $'a\nb' '' )"
rigAssert "2. the TOOL line is in the audit file after the tool record is synced" "$( rigHas "$rigT" ' TOOL ' )" 1

echo "-- 3. both writers name the tool without the mcp__<server>__ prefix --"
rigPrefixed(){ LC_ALL=C grep -c ' TOOL mcp__' "$1" 2> /dev/null || : ; }
rigToolLines(){ LC_ALL=C grep -c ' TOOL ' "$1" 2> /dev/null || : ; }
rigAssert "3. the kept-context writer wrote its TOOL line (the line this case reads)" "$( rigToolLines "$rigT" )" 1
rigAssert "3. and it names Grep, not mcp__myx_distro__Grep" "$( rigPrefixed "$rigT" )" 0
## The same call, written by the native stream writer, from the stream-json shape a claude run gives.
rigNativeSid="nnnn2222-0000-4000-8000-000000000002"
AgentsTranscriptStart "$rigNativeSid" "$rigStore" "audit/2026-11/session-native.log" rig-member
rigNativeT="$rigStore/audit/2026-11/session-native.log"
{
	printf '%s\n' '{"type":"system","subtype":"init","cwd":"/x","session_id":"cli-1","tools":["Grep"],"model":"rig-native-model"}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Reading the rig file."}],"usage":{"input_tokens":1234,"cache_creation_input_tokens":0,"cache_read_input_tokens":300,"output_tokens":7}}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"tool_use","id":"tu_1","name":"mcp__myx_distro__Grep","input":{"pattern":"rig-pattern","path":"/rig/path"}}],"usage":{"input_tokens":1234,"cache_creation_input_tokens":0,"cache_read_input_tokens":300,"output_tokens":7}}}'
	printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"tu_1","type":"tool_result","content":[{"type":"text","text":"a\nb"}]}]}}'
	printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"rig done","session_id":"cli-1","total_cost_usd":0,"usage":{"input_tokens":1234,"cache_creation_input_tokens":0,"cache_read_input_tokens":300,"output_tokens":7}}'
} > "$rigTmp/stream.jsonl"
MDAT_SPAWN_SESSION_ID="$rigNativeSid" LC_ALL=C awk -f "$rigProgressAwk" -f "$rigFormatAwk" -f "$rigStreamAwk" -f "$rigStreamFormatAwk" \
	< "$rigTmp/stream.jsonl" > /dev/null 2>&1 || rigRefuse "the native stream writer did not run"
rigAssert "control: the native writer wrote its TOOL and ROUND lines" \
	"$( rigToolLines "$rigNativeT" )$( LC_ALL=C grep -c ' ROUND n=1 ' "$rigNativeT" 2> /dev/null || : )" 11
rigAssert "3. the native writer's TOOL line names Grep, not mcp__myx_distro__Grep" "$( rigPrefixed "$rigNativeT" )" 0

echo "-- 4. a ROUND line carries the round's real output count, never a constant --"
rigAssert "4. the kept-context writer's ROUND carries the round's own out=7" \
	"$( LC_ALL=C grep -c ' ROUND n=1 in=1234 cache-read=300 cache-write=0 out=7$' "$rigT" 2> /dev/null || : )" 1
rigAssert "4. the native writer's ROUND carries the same out=7" \
	"$( LC_ALL=C grep -c ' ROUND n=1 in=1234 cache-read=300 cache-write=0 out=7$' "$rigNativeT" 2> /dev/null || : )" 1

echo "-- 5. the same round and the same call, written by both writers, carry the same key form --"
rigKeys(){ ## file, kind word -- the key words of that kind's first line, in order
	LC_ALL=C grep -m1 " $2 " "$1" 2> /dev/null | LC_ALL=C grep -o -E '(^| )[a-z-]+=' | LC_ALL=C tr -d ' ' | LC_ALL=C tr '\n' ',' || :
}
rigAssert "5. the two ROUND lines hold the same keys, in the same order" \
	"$( rigKeys "$rigT" ROUND )" "$( rigKeys "$rigNativeT" ROUND )"
rigToolShape(){ ## file -- the outcome, size and line count of its first TOOL line
	LC_ALL=C grep -m1 ' TOOL ' "$1" 2> /dev/null | LC_ALL=C sed -E 's/.*(-> [a-z]+) ([0-9]+B\/[0-9]+L).*/\1 \2/' || :
}
rigAssert "5. the two TOOL lines hold the same outcome, size and line count" \
	"$( rigToolShape "$rigT" )" "$( rigToolShape "$rigNativeT" )"

echo "-- 6. append order holds, and no line is written twice (S12.5) --"
## The review is recorded while the round is open, as the handback's own handling records it, and the
## call's tool record is synced after it. The audit file must then hold REVIEW before TOOL, each of
## them once, and a second sync and a second milestone must add nothing.
rigOrderSid="eeee5555-0000-4000-8000-000000000005"
AgentsTranscriptStart "$rigOrderSid" "$rigStore" "audit/2026-11/session-order.log" rig-member
rigOrderT="$rigStore/audit/2026-11/session-order.log"
export MDAT_SPAWN_SESSION_ID="$rigOrderSid"
AgentsHarnessContextInit
harnessMessages=( '{"role":"system","content":"RIG-ORDER-SYSTEM"}' '{"role":"user","content":"RIG-ORDER-TASK"}' )
AgentsHarnessContextBegin 0
AgentsTranscriptHarnessStart
printf '10 0 0 3\n' > "$rigScratch/stream.usage.detail"
printf 'RIG-ORDER-TEXT\n' > "$rigScratch/stream.content"
harnessMessages+=( '{"role":"assistant","content":"RIG-ORDER-TEXT"}' )
AgentsHarnessContextSync assistant "$( AgentsHarnessContextAssistantMeta )"
AgentsTranscriptEvent "$rigOrderSid" REVIEW "" 0 item note-rig-order.md kind review by rig-member text "the handback's own review"
AgentsTranscriptToolStart 'SubagentHandback'
harnessMessages+=( '{"role":"tool","tool_call_id":"rig-order-call","content":"rig handed back"}' )
AgentsHarnessContextSync tool "$( AgentsHarnessContextToolMeta 'SubagentHandback' 'rig-order-call' 'rig handed back' '' )"
AgentsHarnessContextSync tool "$( AgentsHarnessContextToolMeta 'SubagentHandback' 'rig-order-call' 'rig handed back' '' )"
AgentsTranscriptMilestone "$rigOrderSid" "rig order, nothing new"
rigOrderOf(){ ## file, kind word -- the line number of that kind's first line, 0 for none
	LC_ALL=C awk -v kind="$2" 'index( $0, " " kind " " ) > 0 { print NR ; found = 1 ; exit } END { if ( ! found ) print 0 }' "$1" 2> /dev/null || printf '0'
}
rigKindCount(){ ## file, kind word -- how many lines hold it
	LC_ALL=C awk -v kind="$2" 'index( $0, " " kind " " ) > 0 { n++ } END { print n + 0 }' "$1" 2> /dev/null || printf '0'
}
rigOrderVerdict(){ ## file -- first-tool-after-review | first-review-after-tool | review-missing | tool-missing
	local vReview vTool
	vReview="$( rigOrderOf "$1" REVIEW )" ; vTool="$( rigOrderOf "$1" TOOL )"
	[ "$vReview" != 0 ] || { printf 'review-missing' ; return 0 ; }
	[ "$vTool" != 0 ] || { printf 'tool-missing' ; return 0 ; }
	[ "$vReview" -lt "$vTool" ] && printf 'first-tool-after-review' || printf 'first-review-after-tool'
}
rigOnceVerdict(){ ## file, kind word -- once | twice
	if [ "$( rigKindCount "$1" "$2" )" = 1 ] ; then printf once ; else printf twice ; fi
}
## The instrument's own positive and negative: samples read the way the case reads the file.
rigOrderSample="$rigTmp/order-sample.log"
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z REVIEW item=i kind=review\n2026-11-03T00:00:02Z TOOL SubagentHandback -> ok\n' > "$rigOrderSample"
rigAssert "6. self-test: a sample with REVIEW before TOOL reads that way" "$( rigOrderVerdict "$rigOrderSample" )" first-tool-after-review
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z TOOL SubagentHandback -> ok\n2026-11-03T00:00:02Z REVIEW item=i kind=review\n' > "$rigOrderSample"
rigAssert "6. self-test: and a sample with the two the other way reads that way" "$( rigOrderVerdict "$rigOrderSample" )" first-review-after-tool
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z TOOL Grep -> ok\n2026-11-03T00:00:02Z TOOL Grep -> ok\n' > "$rigOrderSample"
rigAssert "6. self-test: and a sample holding a line twice reads twice" "$( rigOnceVerdict "$rigOrderSample" TOOL )" twice
rigAssert "6. self-test: and a sample holding it once reads once" "$( rigOnceVerdict "$rigOrderSample" START )" once
rigAssert "6. the audit file holds a REVIEW line and a TOOL line at all" \
	"$([ "$( rigKindCount "$rigOrderT" REVIEW )" -ge 1 ] && [ "$( rigKindCount "$rigOrderT" TOOL )" -ge 1 ] && printf both || printf missing )" both
rigAssert "6. the REVIEW line stands before the handback's TOOL line" "$( rigOrderVerdict "$rigOrderT" )" first-tool-after-review
rigAssert "6. the REVIEW line is written once" "$( rigOnceVerdict "$rigOrderT" REVIEW )" once
rigAssert "6. the TOOL line is written once" "$( rigOnceVerdict "$rigOrderT" TOOL )" once
rigAssert "6. the ROUND line is written once" "$( rigOnceVerdict "$rigOrderT" ROUND )" once
rigAssert "6. the START line is written once" "$( rigOnceVerdict "$rigOrderT" START )" once

echo "-- 7. a run spawned from inside another writes its own model; a harness nested in a run writes none --"
## The spawned run inherits its spawner's harness pid, live, under the spawner's session key.
sleep 300 & rigLivePid=$!
rigSpawnedSid="ffff6666-0000-4000-8000-000000000006"
AgentsTranscriptStart "$rigSpawnedSid" "$rigStore" "audit/2026-11/session-spawned.log" rig-member
rigModelOf(){ cat "$MMDAPP/.local/agents/sessions/$1/model" 2> /dev/null || printf 'none' ; }
harnessSessionId="$rigSpawnedSid" ; harnessModel="rig-spawned-model"
export MDAT_SPAWN_SESSION_ID="$rigSpawnedSid" MDAT_HARNESS_RUN_PID="$rigLivePid" MDAT_HARNESS_RUN_KEY="$rigOrderSid"
AgentsTranscriptHarnessStart
rigAssert "7. a run spawned from inside another writes its own model" "$( rigModelOf "$rigSpawnedSid" )" rig-spawned-model
## A harness started inside that run: the same session key, another live pid.
harnessModel="rig-nested-model"
export MDAT_HARNESS_RUN_PID="$rigLivePid" MDAT_HARNESS_RUN_KEY="$rigSpawnedSid"
AgentsTranscriptHarnessStart
rigAssert "7. a harness nested in the run leaves the run's model as it was" "$( rigModelOf "$rigSpawnedSid" )" rig-spawned-model
kill "$rigLivePid" 2> /dev/null || :
wait "$rigLivePid" 2> /dev/null || :

echo "-- 8. TOOL, ROUND and MSG-OUT reach one audit file, in one form, in both harnesses (S12.5) --"
## Case 7 leaves its run-local model names set; this case reads the exported session variable alone.
unset harnessSessionId
## The line's own word: the format spells it `MSG-OUT`, and a search for `MSG ` finds none of them.
rigMsgSample="$rigTmp/msgout-sample.log"
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z MSG-OUT to=C1:1.2\n> hello\n' > "$rigMsgSample"
rigAssert "8. self-test: the reader finds a message-out line the format writes" "$( rigKindCount "$rigMsgSample" MSG-OUT )" 1
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z MSG to=C1:1.2\n' > "$rigMsgSample"
rigAssert "8. self-test: and finds none where the word is MSG, the word a word-search looks for" "$( rigKindCount "$rigMsgSample" MSG-OUT )" 0
printf '2026-11-03T00:00:00Z START session=x\n2026-11-03T00:00:01Z MSG-OUTX to=C1:1.2\n' > "$rigMsgSample"
rigAssert "8. self-test: and finds none where the word carries a tail" "$( rigKindCount "$rigMsgSample" MSG-OUT )" 0
## A DeepSeek run writes all three kinds from its kept context: the round's ROUND line, the call's
## TOOL line and the message it carried, each rendered by the context reader as the record is synced.
rigServedSid="iiii9999-0000-4000-8000-000000000009"
AgentsTranscriptStart "$rigServedSid" "$rigStore" "audit/2026-11/session-served.log" rig-member
rigServedT="$rigStore/audit/2026-11/session-served.log"
export MDAT_SPAWN_SESSION_ID="$rigServedSid"
AgentsHarnessContextInit
harnessMessages=( '{"role":"system","content":"RIG-SERVED-SYSTEM"}' '{"role":"user","content":"RIG-SERVED-TASK"}' )
AgentsHarnessContextBegin 0
AgentsTranscriptHarnessStart
printf '21 0 0 6\n' > "$rigScratch/stream.usage.detail"
printf 'RIG-SERVED-TEXT\n' > "$rigScratch/stream.content"
harnessMessages+=( '{"role":"assistant","content":null,"tool_calls":[{"id":"rig-served-call","type":"function","function":{"name":"SendMessage","arguments":"{\"to\":\"session-current\",\"message\":\"rig served hello\"}"}}]}' )
AgentsHarnessContextSync assistant "$( AgentsHarnessContextAssistantMeta )"
AgentsTranscriptToolStart 'SendMessage'
harnessMessages+=( '{"role":"tool","tool_call_id":"rig-served-call","content":"SENT_MESSAGE_TS C1:1.2"}' )
AgentsHarnessContextSync tool "$( AgentsHarnessContextToolMeta 'SendMessage' 'rig-served-call' 'SENT_MESSAGE_TS C1:1.2' '' )"
rigAssert "8. the kept-context run's log holds the TOOL line of the call it made" "$( rigKindCount "$rigServedT" TOOL )" 1
rigAssert "8. and its ROUND line, from the round it synced" "$( rigKindCount "$rigServedT" ROUND )" 1
rigAssert "8. and its MSG-OUT line, from the message the call carried" "$( rigKindCount "$rigServedT" MSG-OUT )" 1
rigAssert "8. the MSG-OUT line carries the message itself, as quoted lines" "$( rigHas "$rigServedT" '> rig served hello' )" 1
rigSessLog=""
type AgentsSessionLogAppend > /dev/null 2>&1 || . "$rigHere/session/AgentsTools.SessionStore.include"
AgentsSessionLogAppend "$rigServedSid" "rig debug line"
AgentsSessionPartInto rigSessLog "$MMDAPP" "$rigServedSid" "session.log" || rigRefuse "the session store names no log for the rig session"
rigAssert "8. the run's own session.log gains no audit line of its own, for either harness" "$( rigKindCount "$rigSessLog" TOOL )$( rigKindCount "$rigSessLog" ROUND )$( rigKindCount "$rigSessLog" MSG-OUT )" 000
## The same three kinds in a claude-native run's log: its stream writer writes the TOOL and ROUND
## lines and no MSG-OUT, and the served call of that same session writes the MSG-OUT line alone.
rigServedNativeSid="jjjjaaaa-0000-4000-8000-00000000000a"
AgentsTranscriptStart "$rigServedNativeSid" "$rigStore" "audit/2026-11/session-served-native.log" rig-member
rigServedNativeT="$rigStore/audit/2026-11/session-served-native.log"
{
	printf '%s\n' '{"type":"system","subtype":"init","cwd":"/x","session_id":"cli-2","tools":["SendMessage"],"model":"rig-native-model"}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"text","text":"RIG-SERVED-NATIVE"}],"usage":{"input_tokens":21,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":6}}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"tool_use","id":"tu_2","name":"SendMessage","input":{"to":"session-current","message":"rig native hello"}}],"usage":{"input_tokens":21,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":6}}}'
	printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"tu_2","type":"tool_result","content":[{"type":"text","text":"SENT_MESSAGE_TS C1:1.2"}]}]}}'
	printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"rig done","session_id":"cli-2","total_cost_usd":0,"usage":{"input_tokens":21,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":6}}'
} > "$rigTmp/stream-served.jsonl"
MDAT_SPAWN_SESSION_ID="$rigServedNativeSid" LC_ALL=C awk -f "$rigProgressAwk" -f "$rigFormatAwk" -f "$rigStreamAwk" -f "$rigStreamFormatAwk" \
	< "$rigTmp/stream-served.jsonl" > /dev/null 2>&1 || rigRefuse "the native stream writer did not run for the served case"
rigAssert "control: the native stream writer wrote its TOOL and ROUND lines" "$( rigKindCount "$rigServedNativeT" TOOL )$( rigKindCount "$rigServedNativeT" ROUND )" 11
rigAssert "8. the native stream writer writes no MSG-OUT line of its own" "$( rigKindCount "$rigServedNativeT" MSG-OUT )" 0
MDAT_SPAWN_SESSION_ID="$rigServedNativeSid" AgentsTranscriptToolStart 'SendMessage'
MDAT_SPAWN_SESSION_ID="$rigServedNativeSid" AgentsTranscriptToolDone 'SendMessage' '{"to":"session-current","message":"rig native hello"}' 'SENT_MESSAGE_TS C1:1.2' mcp ok 2> /dev/null
rigAssert "8. the native run's log holds its MSG-OUT line" "$( rigKindCount "$rigServedNativeT" MSG-OUT )" 1
rigAssert "8. and its TOOL line lands once, the stream writer's own" "$( rigKindCount "$rigServedNativeT" TOOL )" 1
rigAssert "8. the native MSG-OUT line carries the message itself, as quoted lines" "$( rigHas "$rigServedNativeT" '> rig native hello' )" 1
rigAssert "8. both harnesses write the MSG-OUT line in one form, its keys in one order" "$( rigKeys "$rigServedT" MSG-OUT )" "$( rigKeys "$rigServedNativeT" MSG-OUT )"
rigNoStamp(){ ## file, kind word -- that kind's first line without its own stamp
	LC_ALL=C grep -m1 " $2 " "$1" 2> /dev/null | LC_ALL=C sed -E 's/^[^ ]+ //' || :
}
rigAssert "8. and the line itself reads the same in both, once its stamp is taken off" \
	"$( rigNoStamp "$rigServedT" MSG-OUT )" "$( rigNoStamp "$rigServedNativeT" MSG-OUT )"
rigAssert "8. and that one form is the one the ruling names" "$( rigNoStamp "$rigServedNativeT" MSG-OUT )" 'MSG-OUT to=session-current'
rigAssert "8. both harnesses write the TOOL line in one key form, its keys in one order" "$( rigKeys "$rigServedT" TOOL )" "$( rigKeys "$rigServedNativeT" TOOL )"
rigAssert "8. and both write the ROUND line in one key form, its keys in one order" "$( rigKeys "$rigServedT" ROUND )" "$( rigKeys "$rigServedNativeT" ROUND )"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ AUDIT_LOG_ONE_FORMAT CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'AUDIT_LOG_ONE_FORMAT: OK (%d assertions, offline, rig store only)\n' "$rigPassCount"
