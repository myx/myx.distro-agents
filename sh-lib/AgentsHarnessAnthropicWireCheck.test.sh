#!/usr/bin/env bash
## Behavioural check on AgentsAnthropicMessagesWire.sh, run through the real core against
## a fake `curl` replaying canned Messages API streams. What it proves is the replay
## contract the prompt cache and the thinking blocks both depend on: the second request
## begins with the first one byte for byte, and the assistant turn in it carries the
## thinking block exactly as streamed -- text, trailing newline and signature -- before
## the tool call. Offline by construction: no socket, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

rigTmp="$( mktemp -d -t AgentsHarnessAnthropicWireCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The same generic replaying curl AgentsHarnessMcpCheck.test.sh installs.
cp "$rigHere/check-fixtures/harness-mcp-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/harness-mcp-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

export HARNESS_PROVIDER_NAME="anthropic-wire-check rig"
export HARNESS_SELF_NAME="AgentsHarnessAnthropicWireCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-anthropic-wire-check.invalid/v1/messages"
export HARNESS_HOST="harness-anthropic-wire-check.invalid"
export HARNESS_WIRE="AnthropicMessages"
export HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_OUTPUT_TOKENS_LIGHT="4101"
export HARNESS_OUTPUT_TOKENS_MAIN="4202"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
}

## A round answering with thinking, a line of text and one Glob call, the input split
## across two fragments the way the stream sends it.
rigToolStream(){ ## canned-stream file
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":5000,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"RIG-THINK-MARKER, then \\"quoted\\"\\n"}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"RIG-SIGNATURE-MARKER"}}\n\n'
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"RIG-TEXT-MARKER"}}\n\n'
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":1}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"Glob","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\\"pattern\\": \\"*\\", "}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"\\"path\\": \\"%s\\"}"}}\n\n' "$rigScenarioDir"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":2}\n\n'
		printf 'event: ping\ndata: {"type":"ping"}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}

rigTextStream(){ ## canned-stream file, content
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":200,"cache_read_input_tokens":5100,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){
	rigRunStatus=0
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing -- its stderr: $( head -5 "$rigScenarioDir/err" )"
}

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

rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

rigStart thinking-tool-round-then-answer
rigToolStream "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun
rigAssert "the run ends normally"                             "$rigRunStatus" 0
rigAssert "two rounds were requested"                         "$rigRoundCount" 2
rigAssert "the answer is the second round's text"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "the request asks for prompt caching"               "$( rigHolds "$rigScenarioDir/req.1" '"cache_control":{"type":"ephemeral"}' )" yes
rigAssert "system is a top-level field"                       "$( rigHolds "$rigScenarioDir/req.1" '"system":"' )" yes
rigAssert "tools carry input_schema"                          "$( rigHolds "$rigScenarioDir/req.1" '"name":"Glob","description":' )" yes
rigAssert "no chat-completions envelope reaches this wire"    "$( rigHolds "$rigScenarioDir/req.1" '"type":"function"' )" no
rigAssert "the request streams"                               "$( rigHolds "$rigScenarioDir/req.1" '"stream":true' )" yes
rigAssert "max_tokens is the tier's declared maximum"         "$( rigHolds "$rigScenarioDir/req.1" '"max_tokens":4202,' )" yes
## The prefix: request 2 is request 1 with its closing `]}` removed, then more.
rigPrefix="$( cat "$rigScenarioDir/req.1" )"
rigPrefix="${rigPrefix%]\}}"
case "$( cat "$rigScenarioDir/req.2" )" in
	"$rigPrefix",*) rigPrefixHeld=yes ;;
	*)              rigPrefixHeld=no ;;
esac
rigAssert "request 2 begins with request 1, byte for byte"    "$rigPrefixHeld" yes
rigAssert "the thinking block is replayed exactly"            "$( rigHolds "$rigScenarioDir/req.2" '{"type":"thinking","thinking":"RIG-THINK-MARKER, then \"quoted\"\n","signature":"RIG-SIGNATURE-MARKER"}' )" yes
rigAssert "thinking, text and call keep their stream order"   "$( rigHolds "$rigScenarioDir/req.2" '"signature":"RIG-SIGNATURE-MARKER"},{"type":"text","text":"RIG-TEXT-MARKER"},{"type":"tool_use","id":"toolu_RIG","name":"Glob","input":{"pattern": "*", "path": ' )" yes
rigAssert "the result answers that exact call"                "$( rigHolds "$rigScenarioDir/req.2" '{"type":"tool_result","tool_use_id":"toolu_RIG","content":"' )" yes
rigAssert "the Glob call ran and its result went back"        "$( rigHolds "$rigScenarioDir/req.2" 'req.1' )" yes
rigAssert "round 1 reports what it wrote to the cache"        "$( rigHolds "$rigScenarioDir/err" 'cached: 0, written: 5000' )" yes
rigAssert "round 2 reports the cache it read"                 "$( rigHolds "$rigScenarioDir/err" '5360 prompt tokens this round, cached: 5100' )" yes
rigVerdict "thinking plus a tool call, then an answer -- prefix held, block replayed, cache reported"

## The negative control: a refusal body is reported as a refusal, never read as a round.
## It ends with no newline, the way the API sends it.
rigStart refusal-is-reported
printf '%s' '{"type":"error","error":{"type":"invalid_request_error","message":"RIG-REFUSAL-MARKER"},"request_id":"req_rig"}' > "$rigScenarioDir/res.1"
rigRun
rigAssert "the run fails"                                     "$rigRunStatus" 1
rigAssert "one round was requested"                           "$rigRoundCount" 1
rigAssert "the refusal is named, type and message"            "$( rigHolds "$rigScenarioDir/err" 'invalid_request_error -- RIG-REFUSAL-MARKER' )" yes
rigAssert "nothing was printed as an answer"                  "$( cat "$rigScenarioDir/out" )" ""
rigVerdict "a refusal body -- reported loudly, never read as an empty round"

## This wire requires max_tokens, so a tier declaring none is refused before any request.
rigStart output-tokens-undeclared
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
rigRunStatus=0
RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" HARNESS_OUTPUT_TOKENS_MAIN="" \
	"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
	> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
rigAssert "the run fails"                                     "$rigRunStatus" 1
rigAssert "nothing was sent"                                  "$( cat "$rigScenarioDir/round" )" 0
rigAssert "the refusal names the missing declaration"         "$( rigHolds "$rigScenarioDir/err" 'declares no HARNESS_OUTPUT_TOKENS_* for the normal tier' )" yes
rigVerdict "no declared output maximum -- refused, never a number nobody chose"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ANTHROPIC WIRE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ANTHROPIC_WIRE: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"