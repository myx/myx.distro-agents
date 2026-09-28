#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only

## AgentsAnthropicMessagesWire.sh -- the Anthropic Messages wire adapter, sourced by
## AgentsUniversalHarness.sh and never executed, exactly as AgentsOpenAiChatWire.sh is.
## It defines the same AgentsWire* names, so the core sources one or the other without
## knowing which. The contract it meets is recorded in AgentsAnthropicStub.sh (GAP-2).
## What this wire gets that the chat-completions endpoint cannot give: prompt caching.
## THE PREFIX IS REPLAYED, NEVER REGENERATED. `system` is rendered once per leg, `tools`
## once per process, and an assistant turn goes back as the exact blocks the stream
## delivered -- thinking text and signature included -- because a thinking block binds
## everything before it and a changed byte there is a 400 at replay.

## The floor is not a second list. AgentsHarnessMcpMirror.sh derives
## {"name","description","inputSchema"} from AgentsOpenAiChatWire.sh's own literal, and
## this wire's envelope differs from that only in the schema key's spelling.
## The rename is sed, not ${var//}: bash 3.2 substitutes over a string this long slowly
## enough to stall the start by minutes.
agentsWireToolsJson="$( bash "$harnessHere/AgentsHarnessMcpMirror.sh" )" || {
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the tool floor did not render for the Anthropic Messages wire -- the mirror's own error is above" >&2
	exit 1
}
agentsWireToolsJson="$( printf '%s\n' "$agentsWireToolsJson" | sed 's/"inputSchema":/"input_schema":/g' )"
agentsWireSystemJson=""

## JSON string body for any text, trailing newlines kept: the escaper is awk, which
## cannot see a final newline, so a sentinel carries it through and is cut after.
AgentsWireJsonEscape(){ ## raw text
	local escapeOut
	escapeOut="$( printf '%sX' "$1" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	printf '%s' "${escapeOut%X}"
}

AgentsWireToolDeclaration(){ ## declared name, description, input schema JSON
	printf '%s' '{"name":"'"$1"'","description":"'"$( AgentsWireJsonEscape "$2" )"'","input_schema":'"$3"'}'
}

## `system` is a top-level field on this wire, so it is rendered here once per leg and
## replayed by AgentsWireRequestBody rather than rebuilt per round.
AgentsWireInitMessages(){
	agentsWireSystemJson="$( AgentsWireJsonEscape "$harnessSystemText" )"
	harnessMessages=(
		'{"role":"user","content":"'"$( AgentsWireJsonEscape "$harnessPrompt" )"'"}'
	)
}

AgentsWireUserRecord(){
	printf '%s' '{"role":"user","content":"'"$( AgentsWireJsonEscape "$1" )"'"}'
}

## The whole assistant turn goes back as the stream delivered it, in its own block
## order, so the calls the core assembles from AgentsWireToolCallEntry are not used:
## rebuilt from them, the turn would lose its thinking blocks and the next request 400s.
AgentsWireAssistantToolCallsRecord(){
	printf '%s' '{"role":"assistant","content":'"$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=content -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" )"'}'
}

## `input` is the call's own JSON object, placed raw; the stream gives none for a call
## that takes no arguments, and that call's input is the empty object.
AgentsWireToolCallEntry(){ ## id, name, input JSON
	local entryInput="$3"
	[ -n "$entryInput" ] || entryInput='{}'
	printf '%s' '{"type":"tool_use","id":"'"$( AgentsWireJsonEscape "$1" )"'","name":"'"$( AgentsWireJsonEscape "$2" )"'","input":'"$entryInput"'}'
}

## One user turn per result; consecutive user turns are joined into one by the API, so
## several results still reach it as one turn with every tool_result first.
AgentsWireToolResultRecord(){
	printf '%s' '{"role":"user","content":[{"type":"tool_result","tool_use_id":"'"$( AgentsWireJsonEscape "$1" )"'","content":"'"$( AgentsWireJsonEscape "$2" )"'"}]}'
}

## Appends in a fixed order, for the prompt cache. The top-level cache_control caches
## the whole prefix up to the last message and moves with it, round after round.
## max_tokens is required on this wire, so a stub declaring none is refused rather than
## given a number nobody chose. An empty $harnessReasoningEffort omits output_config
## entirely, and an empty $harnessToolChoice is `auto`.
AgentsWireRequestBody(){
	local bodyMessagesJson bodyOut
	if [ -z "$harnessOutputTokens" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: this wire requires max_tokens, and the stub declares no HARNESS_OUTPUT_TOKENS_* for the $harnessTier tier -- set it to $harnessModel's own maximum output" >&2
		exit 1
	fi
	bodyMessagesJson="$( IFS=, ; echo "[${harnessMessages[*]}]" )"
	bodyOut='{"model":"'"$harnessModel"'","max_tokens":'"$harnessOutputTokens"',"stream":true,"cache_control":{"type":"ephemeral"},"system":"'"$agentsWireSystemJson"'","tools":'"${agentsWireToolsJson%]}${harnessMcpToolsJson:-}"'],"tool_choice":{"type":"'"${harnessToolChoice:-auto}"'"},"messages":'"$bodyMessagesJson"
	[ -z "$harnessReasoningEffort" ] || bodyOut="$bodyOut"',"output_config":{"effort":"'"$harnessReasoningEffort"'"}'
	printf '%s' "$bodyOut}"
}

## A stated, loud failure in place of the bare set -e kill an unguarded assignment
## produces when the reader's own rc is non-zero. Internal to this adapter.
AgentsWireResponseField(){
	local fieldPath="$1" fieldRc=0 fieldValue
	fieldValue="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path="$fieldPath" -v optional=1 -v sentinel=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || fieldRc=$?
	if [ "$fieldRc" != "0" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: round $harnessRound: response is missing required field '$fieldPath' (rc=$fieldRc) -- the model/API returned a tool_use shape this harness cannot use" >&2
		exit 1
	fi
	printf '%s' "${fieldValue%X}"
}

AgentsWireToolCallId(){
	AgentsWireResponseField "tool_calls.$1.id"
}

AgentsWireToolCallName(){
	AgentsWireResponseField "tool_calls.$1.name"
}

AgentsWireToolCallArgs(){
	AgentsWireResponseField "tool_calls.$1.arguments"
}

AgentsWireFinishReason(){
	printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=stop_reason -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## One field of this SSE event, trailing newlines kept.
AgentsWireEventField(){ ## event JSON, key path
	local eventValue
	eventValue="$( printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -v sentinel=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
	printf '%s' "${eventValue%X}"
}

## Reads SSE off stdin and, on `message_stop`, leaves this round's blocks in
## $harnessScratch for AgentsWireSynthesizeResponse. Each block keeps its own files,
## keyed by the index the stream gives it, because `curl | while read` runs this loop
## in a subshell and bash 3.2 cannot avoid that.
AgentsWireStreamConsume(){
	local streamLine streamPayload eventType blockIndex blockType deltaType deltaText blockSeen
	local usageInput="" usageWrite="" usageRead="" usageOutput="" usagePrompt
	: > "$harnessScratch/stream.content"
	## A refusal body ends without a newline, and a bare `read` drops that last line --
	## the refusal then reads as a stream that disconnected, three times over.
	while IFS= read -r streamLine || [ -n "$streamLine" ] ; do
		streamLine="${streamLine%$'\r'}"
		case "$streamLine" in
			""|:*|event:*|id:*|retry:*)
				: ## the `data:` line carries its own type, so the event name adds nothing
			;;
			"data:"*)
				streamPayload="${streamLine#data:}"
				streamPayload="${streamPayload# }"
				eventType="$( AgentsWireEventField "$streamPayload" type )"
				case "$eventType" in
					message_start)
						usageInput="$( AgentsWireEventField "$streamPayload" message.usage.input_tokens )"
						usageWrite="$( AgentsWireEventField "$streamPayload" message.usage.cache_creation_input_tokens )"
						usageRead="$( AgentsWireEventField "$streamPayload" message.usage.cache_read_input_tokens )"
					;;
					content_block_start)
						blockIndex="$( AgentsWireEventField "$streamPayload" index )"
						printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=content_block -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" > "$harnessScratch/stream.block.$blockIndex.raw" 2>/dev/null || :
						blockType="$( AgentsWireEventField "$streamPayload" content_block.type )"
						printf '%s' "$blockType" > "$harnessScratch/stream.block.$blockIndex.type"
						blockSeen="$( cat "$harnessScratch/stream.block.count" 2>/dev/null )" || blockSeen=0
						[ "$blockIndex" -lt "${blockSeen:-0}" ] 2>/dev/null || printf '%s' "$(( blockIndex + 1 ))" > "$harnessScratch/stream.block.count"
						case "$blockType" in
							thinking|redacted_thinking) printf '   🧠 %s%s%s\n' "$harnessTool" "thinking" "$harnessOff" >&2 ;;
						esac
					;;
					content_block_delta)
						blockIndex="$( AgentsWireEventField "$streamPayload" index )"
						deltaType="$( AgentsWireEventField "$streamPayload" delta.type )"
						case "$deltaType" in
							text_delta)
								deltaText="$( AgentsWireEventField "$streamPayload" delta.text )"
								printf '%s' "$deltaText" >> "$harnessScratch/stream.block.$blockIndex.text"
								printf '%s' "$deltaText" >> "$harnessScratch/stream.content"
								## Live prose echo; ESC, CR and BS dropped so it cannot forge our chrome.
								printf '%s' "${deltaText//[$'\033'$'\r'$'\b']/ }" >&2
							;;
							thinking_delta)
								AgentsWireEventField "$streamPayload" delta.thinking >> "$harnessScratch/stream.block.$blockIndex.thinking"
							;;
							signature_delta)
								AgentsWireEventField "$streamPayload" delta.signature >> "$harnessScratch/stream.block.$blockIndex.signature"
							;;
							input_json_delta)
								AgentsWireEventField "$streamPayload" delta.partial_json >> "$harnessScratch/stream.block.$blockIndex.json"
							;;
						esac
					;;
					message_delta)
						deltaText="$( AgentsWireEventField "$streamPayload" delta.stop_reason )"
						[ -z "$deltaText" ] || printf '%s' "$deltaText" > "$harnessScratch/stream.finish_reason"
						usageOutput="$( AgentsWireEventField "$streamPayload" usage.output_tokens )"
					;;
					message_stop)
						## Every prompt token this round, whichever of the three counts it landed in.
						usagePrompt=$(( ${usageInput:-0} + ${usageWrite:-0} + ${usageRead:-0} ))
						printf '%s %s %s\n' "$usagePrompt" "${usageOutput:-0}" "$(( usagePrompt + ${usageOutput:-0} ))" > "$harnessScratch/stream.usage"
						printf '\n%s\n' "   💾 ${harnessDim}prompt cache -- $usagePrompt prompt tokens this round, cached:${harnessOff} ${harnessValue}${usageRead:-absent}${harnessOff}${harnessDim}, written: ${usageWrite:-absent}${harnessOff}" >&2
						: > "$harnessScratch/stream.done"
					;;
					error)
						## An error event mid-stream is the whole answer for this round.
						printf '%s\n' "$streamPayload" >> "$harnessScratch/stream.rawother"
					;;
				esac
			;;
			*)
				## Not an SSE line at all: a plain non-streaming error body, kept verbatim.
				printf '%s\n' "$streamLine" >> "$harnessScratch/stream.rawother"
			;;
		esac
	done
}

## Builds this adapter's own response document: the assistant `content` exactly as it
## will be replayed, the stop reason, the answer text, and the calls indexed the way the
## core asks for them. File contents are read with a sentinel, because a `$( )` that
## drops a thinking block's trailing newline breaks its signature.
AgentsWireSynthesizeResponse(){
	local synthCount synthIdx=0 synthType synthBlocks="" synthCalls="" synthText="" synthBlock
	local synthThinking synthSignature synthPart synthInput synthId synthName synthStop
	synthCount="$( cat "$harnessScratch/stream.block.count" 2>/dev/null )" || synthCount=0
	while [ "$synthIdx" -lt "${synthCount:-0}" ] 2>/dev/null ; do
		synthType="$( cat "$harnessScratch/stream.block.$synthIdx.type" 2>/dev/null )" || synthType=""
		synthBlock=""
		case "$synthType" in
			thinking)
				synthThinking="$( cat "$harnessScratch/stream.block.$synthIdx.thinking" 2>/dev/null ; printf X )"
				synthSignature="$( cat "$harnessScratch/stream.block.$synthIdx.signature" 2>/dev/null ; printf X )"
				synthBlock='{"type":"thinking","thinking":"'"$( AgentsWireJsonEscape "${synthThinking%X}" )"'","signature":"'"$( AgentsWireJsonEscape "${synthSignature%X}" )"'"}'
			;;
			text)
				## An empty text block is refused on replay, so it is not carried.
				synthPart="$( cat "$harnessScratch/stream.block.$synthIdx.text" 2>/dev/null ; printf X )"
				synthPart="${synthPart%X}"
				synthText="$synthText$synthPart"
				[ -z "$synthPart" ] || synthBlock='{"type":"text","text":"'"$( AgentsWireJsonEscape "$synthPart" )"'"}'
			;;
			tool_use)
				synthInput="$( cat "$harnessScratch/stream.block.$synthIdx.json" 2>/dev/null )" || synthInput=""
				[ -n "$synthInput" ] || synthInput='{}'
				synthId="$( AgentsWireEventField "$( cat "$harnessScratch/stream.block.$synthIdx.raw" )" id )"
				synthName="$( AgentsWireEventField "$( cat "$harnessScratch/stream.block.$synthIdx.raw" )" name )"
				synthBlock="$( AgentsWireToolCallEntry "$synthId" "$synthName" "$synthInput" )"
				synthCalls="${synthCalls}${synthCalls:+,}"'{"id":"'"$( AgentsWireJsonEscape "$synthId" )"'","name":"'"$( AgentsWireJsonEscape "$synthName" )"'","arguments":"'"$( AgentsWireJsonEscape "$synthInput" )"'"}'
			;;
			*)
				## redacted_thinking and anything newer arrive whole in their start event.
				synthBlock="$( cat "$harnessScratch/stream.block.$synthIdx.raw" 2>/dev/null )"
			;;
		esac
		[ -z "$synthBlock" ] || synthBlocks="${synthBlocks}${synthBlocks:+,}$synthBlock"
		synthIdx=$(( synthIdx + 1 ))
	done
	synthStop="$( cat "$harnessScratch/stream.finish_reason" 2>/dev/null )" || synthStop=""
	harnessResponse='{"content":['"$synthBlocks"'],"stop_reason":"'"$synthStop"'","text":"'"$( AgentsWireJsonEscape "$synthText" )"'","tool_calls":['"$synthCalls"']}'
}

## The body decides success or failure, never curl's exit status. This wire's error
## envelope is {"type":"error","error":{"type":...,"message":...}}, and a synthesized
## document carries no `error` at all. Prints the code and returns: 0 an error body,
## 3 the success case, anything else unparseable.
AgentsWireErrorCode(){
	local errRc=0 errType
	errType="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=error.type -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || errRc=$?
	[ "$errRc" != "0" ] || errType="$errType -- $( AgentsHarnessArgValue "$harnessResponse" error.message )"
	printf '%s' "$errType"
	return "$errRc"
}

AgentsWireToolCallCount(){
	local countRc=0 countValue
	countValue="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=tool_calls.__count -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || countRc=$?
	[ "$countRc" = "0" ] || countValue=0
	printf '%s' "$countValue"
}

AgentsWireFinalContent(){
	AgentsWireEventField "$harnessResponse" text
}