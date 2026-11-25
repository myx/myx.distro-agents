#!/usr/bin/env bash
## Behavioural check on a run the provider ends empty at its output limit. The run is continued once in
## the same session, carrying the original task and the run's own state on disk rather than the old
## conversation. A second such end in a row stops it, with the cause kept beside the run record. The
## reply the model sends is never kept empty.
## Run through the real core and both real wires against a fake curl first on PATH, so nothing opens a socket.
## Held:
##   1. a tool round, then an empty `length` answer, then text: the run ends 0 with that text, three requests
##      are made, a CUT: line on stderr names `length`, and the request after the cut carries the original
##      task and the run's CheckList and none of the old conversation's tool result
##   1b. the same run with no CheckList on disk: the request after the cut carries no CheckList paragraph,
##      so the paragraph read in 1 is the file's and not one the harness always writes
##   2. two empty `length` answers back to back: exit 1, two requests, nothing on stdout, and the reason kept
##      beside the run record in <sandbox>/<session>.refused naming the output limit
##   3. the control for 2: two empty `length` answers with a tool round between them are each continued,
##      and the run ends 0 on its answer
##   4. the control for today's two paths, green before and after the build: an empty `stop` answer still
##      pauses and re-asks the same request, and an empty answer of any other reason still ends the run
##   5. on the Messages wire the limit is spelled `max_tokens`: one empty `max_tokens` answer is continued
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHere="$rigOrigin/myx/myx.distro-agents"
rigHarness="$rigHere/sh-lib/harness/AgentsUniversalHarness.sh"
rigFixtures="$rigHere/sh-test/check-fixtures"
rigFixture="$rigFixtures/harness-length-limit-check.curl.stub.sh"
rigMember="rig-a"
rigSession="rig-length-run"
rigRefuse(){ ## why -- a rig that could not reach its subject never reaches a PASS line, which reads like a result
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
[ -f "$rigFixtures/session-address-first.curl.stub.sh" ] || rigRefuse "the Slack-shaped fake curl fixture is missing: $rigFixtures/session-address-first.curl.stub.sh"
. "$rigFixtures/rig-temp.include.sh" || rigRefuse "the rig's own folder maker is missing: $rigFixtures/rig-temp.include.sh"
rigTmp="$( rigTempDir AgentsHarnessLengthLimitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/bin" \
	"$rigWs/.local/agents/sessions/$rigSession" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "cannot place the fake curl"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigScenarioCount=0
rigScenarioPass=0
rigScenarioFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
## yes/no rather than a status, so both directions are values a failure can print. A request that was never
## made gets its own third value: it is not the same finding as one made without the text.
rigHolds(){ ## file, text -- yes, no, or no-such-request
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigCount(){ ## file, text -- how many lines of the file hold the text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C grep -c -F -- "$2" "$1" || :
}
rigPresent(){ ## file -- yes where it exists
	[ -f "$1" ] && printf yes || printf no
}
## The CUT: line itself, and whether that line names the reason: a reason word loose in the log is not the
## same finding as a cut line that says why it was cut.
rigCutSaid(){ ## file -- yes where a CUT: line is there
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C grep -F -- 'CUT:' "$1" > /dev/null 2>&1 && printf yes || printf no
}
rigCutNames(){ ## file, reason -- yes where a CUT: line holds that reason
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C grep -F -- 'CUT:' "$1" 2> /dev/null | LC_ALL=C grep -q -F -- "$2" && printf yes || printf no
}
rigSame(){ ## two files -- same or differs, and no-such-request where either was never made
	[ -f "$1" ] && [ -f "$2" ] || { printf 'no-such-request' ; return 0 ; }
	cmp -s "$1" "$2" 2> /dev/null && printf same || printf differs
}
rigVerdict(){ ## scenario title -- the verdict line states how many assertions the scenario carries
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

rigDir=""
rigStart(){ ## scenario name
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/sandbox"
	printf '0' > "$rigDir/round"
	printf 'RIG-TOOLRESULT-MARKER\n' > "$rigDir/read.txt"
	rm -f "$rigWs/.local/agents/sessions/$rigSession/$rigMember.checklist.md"
}
## THE RUN'S OWN STATE ON DISK, as the tooling keeps it: one completed item, so the run is not a quit with
## its list open, and the line is a marker the request after the cut either carries or does not.
rigCheckListWrite(){
	printf -- '- [x] RIG-CHECKLIST-MARKER a step this run already finished\n' > "$rigWs/.local/agents/sessions/$rigSession/$rigMember.checklist.md"
}
## An answer with no content and no tool call, ended at the provider's output limit on the chat wire.
rigEmptyAtLimit(){ ## request number
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"length"}],"usage":{"prompt_tokens":20,"completion_tokens":0,"total_tokens":20}}\ndata: [DONE]\n' > "$rigDir/res.$1"
}
## The same answer ended for a reason that is not the output limit.
rigEmptyReason(){ ## request number, finish_reason
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"%s"}],"usage":{"prompt_tokens":20,"completion_tokens":0,"total_tokens":20}}\ndata: [DONE]\n' "$2" > "$rigDir/res.$1"
}
rigText(){ ## request number, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\ndata: [DONE]\n' "$2" > "$rigDir/res.$1"
}
rigTool(){ ## request number -- an answer with one Read call, whose result is the rig's own marker
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":100,"completion_tokens":5,"total_tokens":105}}\ndata: [DONE]\n' "$rigDir/read.txt" > "$rigDir/res.$1"
}
## THE WIRE A SECTION DRIVES. The chat leg reads a model name as it stands. The Messages leg judges the
## model's family and requires the maximum output per tier, so a section driving it sets all of these.
rigWire="OpenAiChat"
rigEndpoint="https://harness-length-limit-check.invalid/v1/chat/completions"
rigExtraHeaders=""
rigModelLight="rig-light"
rigModelMain="rig-main"
rigOutLight=""
rigOutMain=""

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## agent name (empty: a run with no team identity, which has no checklist place), then NAME=value assignments for this run
	rigRunStatus=0
	local rigAgentName="${1:-}"
	shift
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT="$rigMember" \
		RIG_SCENARIO="$rigDir" RIG_SLACK_STUB="$rigFixtures/session-address-first.curl.stub.sh" \
		MDAT_WAIT_REMIND=off MDAT_HARNESS_CONTEXT_TOKENS=0 ${@+"$@"} \
		HARNESS_PROVIDER_NAME="length-limit rig" HARNESS_SELF_NAME="AgentsHarnessLengthLimitCheck.test.sh" \
		HARNESS_WIRE="$rigWire" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="$rigEndpoint" HARNESS_HOST="harness-length-limit-check.invalid" \
		${rigExtraHeaders:+HARNESS_EXTRA_HEADERS="$rigExtraHeaders"} \
		HARNESS_MODEL_LIGHT="$rigModelLight" HARNESS_MODEL_MAIN="$rigModelMain" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		${rigOutLight:+HARNESS_OUTPUT_TOKENS_LIGHT="$rigOutLight"} ${rigOutMain:+HARNESS_OUTPUT_TOKENS_MAIN="$rigOutMain"} \
		HARNESS_STREAM_ATTEMPTS=3 HARNESS_RETRY_DELAY=0 MDAT_HARNESS_MAX_RESTARTS=3 \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" ${rigAgentName:+--agent "$rigAgentName"} --access-root "$rigDir" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing -- its stderr: $( head -5 "$rigDir/err" )"
}

echo "-- 1. an empty answer at the output limit is continued, carrying the task and the run's own state --"
rigStart limit-continued
rigCheckListWrite
rigTool 1
rigEmptyAtLimit 2
rigText 3 RIG-FINAL-MARKER
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run ends normally"                                       "$rigRunStatus" 0
rigAssert "three requests: a tool round, the cut, the answer"           "$rigRoundCount" 3
rigAssert "the printed result is the answer"                            "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "nothing empty is printed in its place"                       "$( LC_ALL=C wc -l < "$rigDir/out" | LC_ALL=C tr -d ' ' )" 1
rigAssert "the log says the answer was cut at the output limit"         "$( rigCutSaid "$rigDir/err" )" yes
rigAssert "it says so once for the round"                             "$( rigCount "$rigDir/err" 'CUT:' )" 1
rigAssert "and the cut line names the reason the provider gave"        "$( rigCutNames "$rigDir/err" 'length' )" yes
rigAssert "the run is not ended refused"                               "$( rigPresent "$rigDir/sandbox/$rigSession.refused" )" no
rigAssert "the request after the cut carries the original task"         "$( rigHolds "$rigDir/req.3" 'RIG-TASK-MARKER' )" yes
rigAssert "the request after the cut drops the old conversation"        "$( rigHolds "$rigDir/req.3" 'RIG-TOOLRESULT-MARKER' )" no
rigAssert "the request after the cut carries the run's CheckList"       "$( rigHolds "$rigDir/req.3" 'RIG-CHECKLIST-MARKER' )" yes
rigAssert "the request that was cut held the tool result"               "$( rigHolds "$rigDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigVerdict "an empty answer at the limit is continued with the state on disk"

echo "-- 1b. the same run with no CheckList on disk carries no CheckList paragraph --"
rigStart limit-continued-no-checklist
rigTool 1
rigEmptyAtLimit 2
rigText 3 RIG-FINAL-MARKER
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run ends normally"                                       "$rigRunStatus" 0
rigAssert "three requests"                                             "$rigRoundCount" 3
rigAssert "the request after the cut carries the original task"         "$( rigHolds "$rigDir/req.3" 'RIG-TASK-MARKER' )" yes
rigAssert "and no CheckList line, which no file put there"             "$( rigHolds "$rigDir/req.3" 'RIG-CHECKLIST-MARKER' )" no
rigAssert "so the CheckList paragraph in 1 is the file's, not a constant" \
	"$( rigSame "$rigTmp/limit-continued/req.3" "$rigDir/req.3" )" differs
rigVerdict "no state on disk, no CheckList paragraph"

echo "-- 2. two empty answers at the output limit in a row end the run with the cause --"
rigStart limit-twice
rigEmptyAtLimit 1
rigEmptyAtLimit 2
rigText 3 RIG-SHOULD-NEVER-BE-ASKED
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run ends"                                               "$rigRunStatus" 1
rigAssert "two requests, and no third"                                 "$rigRoundCount" 2
rigAssert "nothing is printed as an answer"                            "$( cat "$rigDir/out" )" ""
rigAssert "the reason is kept beside the run record"                   "$( rigPresent "$rigDir/sandbox/$rigSession.refused" )" yes
rigAssert "and names the output limit"                                 "$( rigHolds "$rigDir/sandbox/$rigSession.refused" 'length' )" yes
rigAssert "the log says the cause too"                                 "$( rigHolds "$rigDir/err" 'length' )" yes
rigVerdict "a second empty answer at the limit stops the run and keeps the cause"

echo "-- 3. the control: a tool round between the two cuts means neither ends the run --"
rigStart limit-apart
rigEmptyAtLimit 1
rigTool 2
rigEmptyAtLimit 3
rigText 4 RIG-FINAL-MARKER
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run ends normally"                                       "$rigRunStatus" 0
rigAssert "four requests, one per round"                               "$rigRoundCount" 4
rigAssert "the answer is the result"                                   "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "each cut announced on its own"                              "$( rigCount "$rigDir/err" 'CUT:' )" 2
rigAssert "and the second round's cut says its own reason"             "$( rigCutNames "$rigDir/err" 'length' )" yes
rigAssert "the run is not ended refused"                               "$( rigPresent "$rigDir/sandbox/$rigSession.refused" )" no
rigVerdict "two cuts with a round between them are each continued"

echo "-- 4. the control for today's paths: an empty stop still pauses, any other reason still ends the run --"
rigStart empty-stop-pauses
rigEmptyReason 1 stop
rigText 2 RIG-FINAL-MARKER
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run ends normally"                                       "$rigRunStatus" 0
rigAssert "the empty answer is asked again"                            "$rigRoundCount" 2
rigAssert "the pause is said once, as the busy path says it"            "$( rigCount "$rigDir/err" 'EMPTY:' )" 1
rigAssert "a stop is not called a cut"                                 "$( rigCutSaid "$rigDir/err" )" no
rigAssert "the re-ask is the same request, byte for byte"              "$( rigSame "$rigDir/req.1" "$rigDir/req.2" )" same
rigAssert "and the answer is the result"                               "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigVerdict "an empty stop still takes the pause path"

rigStart empty-other-reason-ends
rigEmptyReason 1 content_filter
rigText 2 RIG-SHOULD-NEVER-BE-ASKED
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "an empty answer of another reason ends the run"             "$rigRunStatus" 1
rigAssert "and is asked once"                                          "$rigRoundCount" 1
rigAssert "nothing is printed as an answer"                            "$( cat "$rigDir/out" )" ""
rigAssert "the reason is kept, naming that reason"                     "$( rigHolds "$rigDir/sandbox/$rigSession.refused" 'content_filter' )" yes
rigAssert "it is not called a cut"                                     "$( rigCutSaid "$rigDir/err" )" no
rigVerdict "an empty answer of any other reason still ends the run"

echo "-- 5. on the Messages wire the limit is spelled max_tokens --"
rigWireWas="$rigWire" ; rigEndpointWas="$rigEndpoint" ; rigHeadersWas="$rigExtraHeaders"
rigLightWas="$rigModelLight" ; rigMainWas="$rigModelMain"
rigWire="AnthropicMessages"
rigEndpoint="https://harness-length-limit-check.invalid/v1/messages"
rigExtraHeaders="anthropic-version: 2023-06-01"
rigModelLight="rig-flash-light"
rigModelMain="rig-flash-main"
rigOutLight="4101"
rigOutMain="4202"
rigMessagesEmptyAtLimit(){ ## file -- a message with no content block, stopped at the output maximum
	printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_riglength_cut","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n' > "$1"
	printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"max_tokens"},"usage":{"output_tokens":1}}\n\n' >> "$1"
	printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n' >> "$1"
}
rigMessagesText(){ ## file, text
	printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_riglength_text","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n' > "$1"
	printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n' >> "$1"
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2" >> "$1"
	printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n' >> "$1"
	printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n' >> "$1"
	printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n' >> "$1"
}
rigStart limit-continued-messages
rigMessagesEmptyAtLimit "$rigDir/res.1"
rigMessagesText "$rigDir/res.2" RIG-FINAL-MARKER
rigRun "$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the Messages leg ends normally after an empty max_tokens answer" "$rigRunStatus" 0
rigAssert "it makes two requests"                                      "$rigRoundCount" 2
rigAssert "the answer is the result"                                   "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "the cut names the limit this wire spells"                   "$( rigCutNames "$rigDir/err" 'max_tokens' )" yes
rigAssert "the run is not ended refused"                               "$( rigPresent "$rigDir/sandbox/$rigSession.refused" )" no
rigVerdict "max_tokens on the Messages wire is the same limit"
rigWire="$rigWireWas" ; rigEndpoint="$rigEndpointWas" ; rigExtraHeaders="$rigHeadersWas"
rigModelLight="$rigLightWas" ; rigModelMain="$rigMainWas"
rigOutLight="" ; rigOutMain=""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ LENGTH LIMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s) in $rigScenarioCount scenario(s)" >&2 ; exit 1
fi
printf 'HARNESS_LENGTH_LIMIT: OK (%d scenarios, %d assertions, offline, a fake curl)\n' "$rigScenarioCount" "$rigPassCount"
