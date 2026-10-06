#!/usr/bin/env bash
## Equivalence check on AgentsHarnessToolCallsRead: each tool call's id, name and
## arguments, read once per round from the per-index stream files the wire's consumer
## leaves, must be BYTE FOR BYTE what the wire's own AgentsWireToolCallId/Name/Args
## accessors give from the synthesized response -- which is what the core read before.
## Both real wires are driven: canned streams go through the real AgentsWireStreamConsume
## and AgentsWireSynthesizeResponse, then the files path (proven to be the one taken, by
## blanking the response it must not need) is compared with the accessor path. The
## streams carry escapes, \u pairs, control bytes, trailing newlines, a call with no id,
## a call with no arguments, a sparse index and non-tool blocks between tool_use ones.
## Offline: no request, no host, the scratch is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsHarnessModelRound.include" "$rigHere/AgentsOpenAiChatWire.sh" "$rigHere/AgentsAnthropicMessagesWire.sh" "$rigHere/AgentsHarnessArgTable.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t AgentsHarnessToolCallsReadCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The functions under test, lifted out of the harness and its model-round include by their own names.
rigLift="$( LC_ALL=C awk '
	/^(AgentsHarnessWholeNumber|AgentsHarnessArgParse|AgentsHarnessArgFind|AgentsHarnessFileText|AgentsHarnessToolCallsRead)\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 5 ) exit 1 ; }
' "$rigHarness" "$rigHere/AgentsHarnessModelRound.include" )" || rigRefuse "the five tool-call reading functions were not all found in $rigHarness and AgentsHarnessModelRound.include"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$( printf '%s' "$2" | od -An -c | tr -s ' \n' ' ' )" "$( printf '%s' "$3" | od -An -c | tr -s ' \n' ' ' )"
	fi
}

## One wire, one canned stream: consumed and synthesized by the wire itself, then read both ways.
## Each scenario runs in its own subshell, so the two wires never share a definition.
rigScenario(){ ## wire, stream file, expected call count
	(
		rigPass=0 rigFail=0
		harnessHere="$rigHere" harnessScratch="$rigTmp/scratch" harnessWire="$1"
		harnessSelfName=rig harnessRound=1 harnessDim='' harnessTool='' harnessValue='' harnessWarn='' harnessBad='' harnessOff=''
		harnessArgRaw="" harnessArgParsed=0 harnessArgPaths=() harnessArgEncs=() harnessArgFound=""
		harnessResponseSynthesized=0 harnessCallIds=() harnessCallNames=() harnessCallArgs=() harnessFileText=""
		rm -rf "$harnessScratch" ; mkdir -p "$harnessScratch"
		eval "$rigLift"
		. "$rigHere/Agents${1}Wire.sh"
		AgentsWireStreamConsume < "$2" 2>/dev/null
		AgentsWireSynthesizeResponse
		rigCount="$( AgentsWireToolCallCount )"
		printf 'count\t%s\n' "$rigCount"
		## The accessor path: what the core read before.
		harnessResponseSynthesized=0
		AgentsHarnessToolCallsRead "$rigCount"
		rigWantIds=( ${harnessCallIds[@]+"${harnessCallIds[@]}"} ) rigWantNames=( ${harnessCallNames[@]+"${harnessCallNames[@]}"} ) rigWantArgs=( ${harnessCallArgs[@]+"${harnessCallArgs[@]}"} )
		## The files path, with the response it must not need blanked.
		harnessResponseSynthesized=1
		harnessResponse='{"blanked":true}'
		AgentsHarnessToolCallsRead "$rigCount" 2>/dev/null
		rigIdx=0
		while [ "$rigIdx" -lt "$rigCount" ] ; do
			printf 'pair\t%s\n' "$rigIdx"
			rigAssert "$1 call $rigIdx id"   "${harnessCallIds[$rigIdx]-}x"   "${rigWantIds[$rigIdx]-}x"
			rigAssert "$1 call $rigIdx name" "${harnessCallNames[$rigIdx]-}x" "${rigWantNames[$rigIdx]-}x"
			rigAssert "$1 call $rigIdx args" "${harnessCallArgs[$rigIdx]-}x"  "${rigWantArgs[$rigIdx]-}x"
			rigIdx=$(( rigIdx + 1 ))
		done
		printf 'tally\t%s\t%s\n' "$rigPass" "$rigFail"
	) > "$rigTmp/scenario.out"
	local scenarioLine scenarioCount=""
	while IFS= read -r scenarioLine ; do
		case "$scenarioLine" in
			count$'\t'*) scenarioCount="${scenarioLine#count$'\t'}" ;;
			tally$'\t'*)
				scenarioLine="${scenarioLine#tally$'\t'}"
				rigPass=$(( rigPass + ${scenarioLine%%$'\t'*} ))
				rigFail=$(( rigFail + ${scenarioLine#*$'\t'} ))
			;;
			pair$'\t'*) ;;
			*) printf '%s\n' "$scenarioLine" ;;
		esac
	done < "$rigTmp/scenario.out"
	rigAssert "$1 ${2##*/}: the synthesized response holds every call" "$scenarioCount" "$3"
}

## OpenAiChat (Copilot, Grok, Scaleway): fragments, escapes, a trailing newline inside the
## arguments, a call with no id and no arguments.
{
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{"content":null,"tool_calls":[{"index":0,"id":"call_A","type":"function","function":{"name":"Grep","arguments":"{\"pattern\":\"a\\\\nb\","}}]}}]}'
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"path\":\"/x y\"}\n"}}]}}]}'
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"cé \"q\"","type":"function","function":{"name":"Write","arguments":"{\"content\":\"t\\tab\\r\\n\\\\ \\u00e9\\ud83d\\ude00\",\"path\":\"/w\"}\n\n"}}]}}]}'
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":2,"type":"function","function":{"name":"Read"}}]}}]}'
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}'
	printf '%s\n' 'data: [DONE]'
} > "$rigTmp/openai.calls"
rigScenario OpenAiChat "$rigTmp/openai.calls" 3

## A sparse index: call 1 arrives and call 0 never does.
{
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"call_only","type":"function","function":{"name":"Glob","arguments":"{\"pattern\":\"*\"}"}}]}}]}'
	printf '%s\n' 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}'
	printf '%s\n' 'data: [DONE]'
} > "$rigTmp/openai.sparse"
rigScenario OpenAiChat "$rigTmp/openai.sparse" 2

## AnthropicMessages: thinking, text and redacted_thinking blocks between tool_use ones,
## an id with a trailing newline, input arriving in fragments, and a call with no input.
{
	printf '%s\n\n' 'data: {"type":"message_start","message":{"id":"m","type":"message","role":"assistant","content":[],"usage":{"input_tokens":1,"output_tokens":1}}}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"think \"hard\"\n"}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"SIG"}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":0}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_é\n","name":"Grep","input":{}}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"pattern\": \"a\\\\tb\", "}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"-n\": true}\n"}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":1}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":2,"content_block":{"type":"redacted_thinking","data":"REDACTED"}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":2}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":3,"content_block":{"type":"text","text":""}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":3,"delta":{"type":"text_delta","text":"between"}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":3}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":4,"content_block":{"type":"tool_use","id":"toolu_B","name":"Na\"me","input":{}}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":4}'
	printf '%s\n\n' 'data: {"type":"content_block_start","index":5,"content_block":{"type":"tool_use","id":"toolu_C","name":"Write","input":{}}}'
	printf '%s\n\n' 'data: {"type":"content_block_delta","index":5,"delta":{"type":"input_json_delta","partial_json":"{\"content\":\"x\\n\\n\",\"path\":\"/p\"}"}}'
	printf '%s\n\n' 'data: {"type":"content_block_stop","index":5}'
	printf '%s\n\n' 'data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":4}}'
	printf '%s\n\n' 'data: {"type":"message_stop"}'
} > "$rigTmp/anthropic.calls"
rigScenario AnthropicMessages "$rigTmp/anthropic.calls" 3

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TOOL CALLS READ CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsHarnessToolCallsRead in sh-lib/AgentsUniversalHarness.sh -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_TOOL_CALLS_READ: OK (OpenAiChat and AnthropicMessages, %d assertions, files path byte-identical to the accessors, offline)\n' "$rigPass"
