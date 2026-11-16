#!/usr/bin/env bash
## Behavioural check on a Read of an image reaching the model (the board item harness-loop-image-to-model):
## the model loop stages the image the Read returned into the run's scratch, and the wire sends it as an
## image part when the preset says its model takes images (HARNESS_MODEL_TAKES_IMAGES=on), never otherwise.
## Both wires are driven offline against a fake `curl` replaying canned streams, as AgentsHarnessMcpCheck.test.sh
## and AgentsHarnessAnthropicWireCheck.test.sh drive their own: no socket, no credential. A 1x1 PNG fixture is
## the image, written here as a base64 literal, so the rig depends on no image file outside the package.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessImageCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/harness-mcp-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A 1x1 PNG, the bytes held as a base64 literal: the rig depends on no image file beside it, and the file
## the model loop reads it back from is written into each scenario's own access root, so the Read the loop
## runs stages exactly this image.
rigImageB64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
rigImageFile=""

export HARNESS_PROVIDER_NAME="harness-image-check rig"
export HARNESS_SELF_NAME="AgentsHarnessImageCheck.test.sh"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_OUTPUT_TOKENS_LIGHT="4101"
export HARNESS_OUTPUT_TOKENS_MAIN="4202"
export HARNESS_STREAM_ATTEMPTS=3 HARNESS_RETRY_DELAY=0
## The check is self-contained: a parent session that is itself a harness leg leaks its own family table into
## the runner, so the leg's table is dropped here and the rig models take the fallback pair, as the rig wants.
unset HARNESS_MODEL_TABLE HARNESS_NONE_FORM HARNESS_ENDPOINT_URL HARNESS_WEB_SEARCH

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
	## The image the Read targets lives INSIDE the scenario, under the harness's own access root, so the Read is
	## admitted and actually stages it: a path outside the root would be refused and stage nothing.
	printf '%s' "$rigImageB64" | base64 -d > "$rigScenarioDir/rig-image.png" 2> /dev/null \
		|| rigRefuse "base64 is not on PATH, so the rig's own image cannot be written"
	rigImageFile="$rigScenarioDir/rig-image.png"
}

## The chat-completions stream shape: one round answering with a Read of the rig's image, then the text answer.
rigImageStream(){ ## canned-stream file
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-img-call","type":"function","function":{"name":"Read","arguments":"{\\"file_path\\": \\"%s\\"}"}}]}}]}\n' "$rigImageFile" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}
rigTextStream(){ ## canned-stream file, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' "$2" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## The Messages stream shape (AgentsAnthropicMessagesStream.awk): a Read tool_use round, then the text answer.
rigImageStreamAnthropic(){ ## canned-stream file
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":200,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_rig","name":"Read","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"file_path\\": \\"%s\\"}"}}\n\n' "$rigImageFile"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":9}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigTextStreamAnthropic(){ ## canned-stream file, content
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":5100,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## wire, takes-images value, then harness arguments
	local runWire="$1" runImages="$2"
	shift 2
	rigRunStatus=0
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		HARNESS_WIRE="$runWire" HARNESS_ENDPOINT="https://harness-image-check.invalid/v1/chat/completions" \
		HARNESS_HOST="harness-image-check.invalid" \
		HARNESS_MODEL_TAKES_IMAGES="$runImages" \
		"$rigHarness" --access-root "$rigScenarioDir" "$@" RIG-TASK-MARKER \
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

## The OpenAI-shaped wire, preset takes images: round 2 carries the image_url part in a user message right after the tool result.
rigStart openai-images-on
rigImageStream "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun OpenAiChat on
rigAssert "the run ends normally"                             "$rigRunStatus" 0
rigAssert "two rounds were requested"                         "$rigRoundCount" 2
rigAssert "the image_url part reaches the request"            "$( rigHolds "$rigScenarioDir/req.2" '"type":"image_url","image_url":{"url":"data:image/png;base64,' )" yes
rigAssert "it carries the rig's base64 bytes"                 "$( rigHolds "$rigScenarioDir/req.2" "$rigImageB64" )" yes
rigAssert "the image is in a user message after the tool result" "$( rigHolds "$rigScenarioDir/req.2" '"role":"tool","tool_call_id":"rig-img-call"' )" yes
rigAssert "the answer is the second round's text"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "OpenAI wire, preset takes images -- the image_url part rides a user message after the tool result"

## The OpenAI-shaped wire, preset does not take images: today's text answer, no image part anywhere.
rigStart openai-images-off
rigImageStream "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun OpenAiChat off
rigAssert "the run ends normally"                             "$rigRunStatus" 0
rigAssert "two rounds were requested"                         "$rigRoundCount" 2
rigAssert "no image_url part reaches the request"             "$( rigHolds "$rigScenarioDir/req.2" '"type":"image_url"' )" no
rigAssert "today's text answer of the Read is what the model got" "$( rigHolds "$rigScenarioDir/req.2" 'cannot be shown on this path' )" yes
rigAssert "the answer is the second round's text"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "OpenAI wire, preset without images -- the text answer stays, no image part"

## The Anthropic wire, preset takes images: the image block rides the tool_result's content.
rigStart anthropic-images-on
rigImageStreamAnthropic "$rigScenarioDir/res.1"
rigTextStreamAnthropic "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun AnthropicMessages on
rigAssert "the run ends normally"                             "$rigRunStatus" 0
rigAssert "two rounds were requested"                         "$rigRoundCount" 2
rigAssert "the image block reaches the tool_result"           "$( rigHolds "$rigScenarioDir/req.2" '{"type":"image","source":{"type":"base64","media_type":"image/png","data":"' )" yes
rigAssert "it carries the rig's base64 bytes"                 "$( rigHolds "$rigScenarioDir/req.2" "$rigImageB64" )" yes
rigAssert "the answer is the second round's text"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "Anthropic wire, preset takes images -- the image block rides the tool_result"

## The Anthropic wire, preset does not take images: text answer, no image block.
rigStart anthropic-images-off
rigImageStreamAnthropic "$rigScenarioDir/res.1"
rigTextStreamAnthropic "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun AnthropicMessages off
rigAssert "the run ends normally"                             "$rigRunStatus" 0
rigAssert "two rounds were requested"                         "$rigRoundCount" 2
rigAssert "no image block reaches the request"                "$( rigHolds "$rigScenarioDir/req.2" '"type":"image","source"' )" no
rigAssert "today's text answer of the Read is what the model got" "$( rigHolds "$rigScenarioDir/req.2" 'cannot be shown on this path' )" yes
rigAssert "the answer is the second round's text"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "Anthropic wire, preset without images -- the text answer stays, no image block"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS IMAGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_IMAGE: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
