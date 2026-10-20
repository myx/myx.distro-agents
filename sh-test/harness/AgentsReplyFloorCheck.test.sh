#!/usr/bin/env bash
## Behavioural check on the floor on a tool return (F3.3 and F9.1 of the refactorings epic): every tool that returns delivers
## the floor's new messages with its result, and only the floor. They are read quickly from the session chat file in the
## session's folder, with no network call, from the run's pointer forward, in full. The reply layer carries them as it carries
## the date: beside the result, never inside it, so the result stays exactly as the tool printed it. Held, through the MCP server
## (a native root caller, the executor of its own session) and in the harness's own model loop (a participant of a team session):
##   1. a message appended to the file after the run's pointer comes back with the next tool result, beside it, with the source
##      it came from named, the result itself unchanged; and the one after finds nothing new, though the file is as it was
##   2. the executor is given every message of its session thread but its own; a participant only the ones that name it
##   3. the reply of a run with no session, or with a session that has no chat file, is the reply it always was
##   4. a message is whole, not cut: a long one comes back in full
## Red before the floor: no tool return carries a message (every case fails).
## Offline: MMDAPP and HOME are this rig's own; the loop's model is a fake curl replaying one canned round; no network is used.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] && [ -f "$rigTool" ] || rigRefuse "the harness or the tool is not at the origin this workspace resolves: $MDLT_ORIGIN"
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is missing: $rigHere/session/AgentsTools.SessionChat.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReplyFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/.local/.agents" "$rigTmp/.local/agents/sessions" "$rigTmp/home" "$rigTmp/.local/temp/team/fix"
rigFix="$rigTmp/.local/temp/team/fix"
printf 'RIG-FILE-CONTENT\n' > "$rigFix/small.txt"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Blocks into a session's chat file, through the include's own writer, with the rig as the workspace.
rigAppend(){ ## session, from, to, ts, where, origin, body
	( export MMDAPP="$rigTmp" ; . "$rigHere/session/AgentsTools.SessionChat.include" ; printf '%s' "$7" | AgentsToolsSessionChatAppend "$1" "$2" "$3" "$4" "$5" "$6" > /dev/null )
}
rigPointer(){ ## session, member, value
	( export MMDAPP="$rigTmp" ; . "$rigHere/session/AgentsTools.SessionChat.include" ; AgentsToolsSessionChatPointerSet "$1" "read:$2" "$3" )
}
rigThread(){ ## session, channel:thread
	mkdir -p "$rigTmp/.local/agents/sessions/$1" && printf '%s\n' "$2" > "$rigTmp/.local/agents/sessions/$1/session.thread"
}
## A native root caller: no spawn id, only the client session id its CLI gives it.
rigMcp(){ ## name, client session, tool, arguments JSON -- one tools/call of the MCP server; its raw reply line in <name>.out
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$3" "$4" \
		| ( cd "$rigFix" && env -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD CLAUDE_CODE_SESSION_ID="$2" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		bash "$rigTool" --intern-mcp-server --run ) 2> "$rigTmp/$1.err" | LC_ALL=C grep '^{"jsonrpc":"2.0","id":2,' > "$rigTmp/$1.out"
}
rigHas(){ ## name, text -- how many lines of the reply hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || :
}
rigParts(){ ## name -- how many text items the reply's content holds
	LC_ALL=C awk '{ n = gsub(/"type":"text"/, "&") ; print n ; }' "$rigTmp/$1.out"
}

echo "-- 1. through MCP, a native root caller, the executor of its own session --"
rigClient="rig-floor-client"
rigThread "$rigClient" "CRIGFLR01:1760000000.000010"
rigAppend "$rigClient" keeper-old all 1760000000.000001 "CRIGFLR01:1760000000.000010" slack "RIG-BEFORE the caller's first call"
rigMcp m1 "$rigClient" execute '{"command":"echo RIG-RESULT-ONE"}'
[ -s "$rigTmp/m1.out" ] || rigRefuse "the MCP server gave no reply, so nothing below would be measured: $( head -3 "$rigTmp/m1.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the first call: the result, and nothing of the file (what was there is not new to it)" "$( rigHas m1 RIG-RESULT-ONE ):$( rigHas m1 RIG-BEFORE )" "1:0"
rigAppend "$rigClient" keeper-old all 1760000000.000101 "CRIGFLR01:1760000000.000010" slack "RIG-NEW-ONE a message of the thread"
rigMcp m2 "$rigClient" execute '{"command":"echo RIG-RESULT-TWO"}'
rigAssert "the next result carries the message"                  "$( rigHas m2 RIG-NEW-ONE ):$( rigHas m2 RIG-RESULT-TWO )" "1:1"
rigAssert "beside the result: a text item of its own, after it, with the date" "$( rigParts m2 ):$( LC_ALL=C grep -c -E '"text":"current-date: [^"]*\\n[^"]*RIG-NEW-ONE' "$rigTmp/m2.out" )" "2:1"
rigAssert "the source it came from is named"                     "$( rigHas m2 '# via slack:CRIGFLR01:1760000000.000010' )" 1
rigAssert "the result item is as the tool printed it"            "$( LC_ALL=C grep -c -E '"content":\[\{"type":"text","text":"[^"]*RIG-RESULT-TWO[^"]*"\},\{"type":"text","text":"current-date' "$rigTmp/m2.out" )" 1
rigMcp m3 "$rigClient" execute '{"command":"echo RIG-RESULT-THREE"}'
rigAssert "the one after finds nothing new: only the date beside the result" "$( rigHas m3 RIG-NEW-ONE ):$( rigParts m3 )" "0:2"
rigAppend "$rigClient" keeper-old all 1760000000.000102 "CRIGFLR01:1760000000.000010" slack "RIG-NEW-TWO"
rigAppend "$rigClient" magic-coordinator all 1760000000.000103 "CRIGFLR01:1760000000.000010" own "RIG-OWN the caller's own"
LC_ALL=C awk 'BEGIN { printf "RIG-LONG-START " ; for ( n = 1 ; n <= 600 ; n++ ) printf "word%04d ", n ; printf "RIG-LONG-END" }' > "$rigTmp/long.txt"
rigAppend "$rigClient" keeper-old all 1760000000.000104 "CRIGFLR01:1760000000.000010" slack "$( cat "$rigTmp/long.txt" )"
rigMcp m4 "$rigClient" execute '{"command":"echo RIG-RESULT-FOUR"}'
rigAssert "the executor: every message of the thread, but not its own (magic-coordinator is the caller)" "$( rigHas m4 RIG-NEW-TWO ):$( rigHas m4 'RIG-OWN' )" "1:0"
rigAssert "and a long message comes whole, from its first word to its last" "$( rigHas m4 RIG-LONG-START ):$( LC_ALL=C grep -c -F 'word0600 RIG-LONG-END' "$rigTmp/m4.out" || : )" "1:1"

echo "-- 2. in the model loop, a participant of a team session --"
rigLoopSession="rig-floor-loop"
rigTeam="rig-floor-team"
rigLoopDir="$rigTmp/loop"
mkdir -p "$rigLoopDir/bin" "$rigTmp/skills/magic-tester" "$rigTmp/OUT"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
cp "${rigHere%/sh-lib}/sh-test/check-fixtures/harness-arm-gate.curl.stub.sh" "$rigLoopDir/bin/curl" && chmod +x "$rigLoopDir/bin/curl" || rigRefuse "the fake curl fixture of the model loop is missing from the package"
printf '0' > "$rigLoopDir/round"
: > "$rigLoopDir/curl.log"
rigThread "$rigTeam" "CRIGFLR02:1760000000.000010"
rigAppend "$rigTeam" keeper-old all 1760000000.000001 "CRIGFLR02:1760000000.000010" slack "RIG-P-BEFORE"
rigAppend "$rigTeam" keeper-old magic-tester 1760000000.000201 "CRIGFLR02:1760000000.000010" slack "RIG-P-TAGGED to the participant"
rigAppend "$rigTeam" keeper-old all 1760000000.000202 "CRIGFLR02:1760000000.000010" slack "RIG-P-ALL to everyone, nobody named"
rigAppend "$rigTeam" keeper-old all 1760000000.000203 "CRIGFLR02:1760000000.000010" slack "RIG-P-MENTION @magic-tester please look"
rigPointer "$rigTeam" magic-tester 1
printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-1","type":"function","function":{"name":"Read","arguments":"{\\"file_path\\":\\"%s\\"}"}}]},"finish_reason":null}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' "$rigFix/small.txt" > "$rigLoopDir/res.1"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigLoopDir/res.2"
env -i HOME="$rigTmp/home" PATH="$rigLoopDir/bin:/usr/bin:/bin" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID="$rigLoopSession" MDAT_SESSION_ID="$rigTeam" MDAT_SESSION_THREAD="CRIGFLR02:1760000000.000010" MDAT_SPAWN_AGENT=magic-tester RIG_SCENARIO="$rigLoopDir" RIG_CURL_LOG="$rigLoopDir/curl.log" \
	HARNESS_PROVIDER_NAME="reply-floor rig" HARNESS_SELF_NAME="AgentsReplyFloorCheck.test.sh" \
	HARNESS_ENDPOINT="https://reply-floor-check.invalid/v1/chat/completions" HARNESS_HOST="reply-floor-check.invalid" \
	HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
	HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
	bash -c 'cd "$MMDAPP" && exec bash "$0" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent magic-tester RIG-TASK' "$rigHarness" \
	> "$rigLoopDir/out" 2> "$rigLoopDir/err" < /dev/null || :
[ -s "$rigLoopDir/req.2" ] || rigRefuse "the loop never gave the model the tool's result, so nothing below would be measured: $( tail -3 "$rigLoopDir/err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the tool result the model is given is the file's content, as ever"  "$( LC_ALL=C grep -c -F 'RIG-FILE-CONTENT' "$rigLoopDir/req.2" || : )" 1
rigAssert "a participant is given the messages that name it: in the header, and as @member in the body" "$( LC_ALL=C grep -c -F 'RIG-P-TAGGED' "$rigLoopDir/req.2" || : ):$( LC_ALL=C grep -c -F 'RIG-P-MENTION' "$rigLoopDir/req.2" || : )" "1:1"
rigAssert "and not the one that names nobody, nor the ones before its pointer" "$( LC_ALL=C grep -c -e 'RIG-P-ALL' -e 'RIG-P-BEFORE' "$rigLoopDir/req.2" || : )" 0
rigAssert "the source is named"                                  "$( LC_ALL=C grep -c -F '# via slack:CRIGFLR02:1760000000.000010' "$rigLoopDir/req.2" || : )" 1
rigAssert "the pointer moved to the end of what was read"          "$( LC_ALL=C awk -F'\t' '$1 == "read:magic-tester" { print $2 ; }' "$rigTmp/.local/agents/sessions/$rigTeam/session.chat.pointers" )" 4

echo "-- 3. no session, or a session with no chat file --"
[ ! -d "$rigTmp/.local/agents/sessions/rig-floor-nofile" ] || rigRefuse "the rig's session folder stood before the call that is to make it"
rigMcp m5 "rig-floor-nofile" execute '{"command":"echo RIG-RESULT-FIVE"}'
rigAssert "a session with no chat file: the result and the date alone" "$( rigHas m5 RIG-RESULT-FIVE ):$( rigParts m5 )" "1:2"
rigAssert "the session folder is made by the first return of a selected workspace, where it can (F9.2)" "$( [ -d "$rigTmp/.local/agents/sessions/rig-floor-nofile" ] && printf made || printf none )" made
rigMcp m6 "rig floor spaced" execute '{"command":"echo RIG-RESULT-SIX"}'
rigAssert "an id that is no session folder name: the same reply, and no folder"       "$( rigHas m6 RIG-RESULT-SIX ):$( rigParts m6 ):$( [ -d "$rigTmp/.local/agents/sessions/rig floor spaced" ] && printf made || printf none )" "1:2:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REPLY FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REPLY_FLOOR: OK (%d assertions, offline)\n' "$rigPassCount"
