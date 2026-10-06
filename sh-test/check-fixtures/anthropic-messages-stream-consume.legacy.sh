#!/usr/bin/env bash
## The previous AgentsWireStreamConsume of AgentsAnthropicMessagesWire.sh, with its
## AgentsWireEventField, kept ONLY as the reference AgentsWireStreamDiffCheck.test.sh compares
## the single-awk consumer against. It forks AgentsHarnessJsonField.awk per field per event;
## here that reader is the legacy engine at $rigLegacyField. Nothing in sh-lib loads this.

## One field of this SSE event, trailing newlines kept.
AgentsWireEventField(){ ## event JSON, key path
	local eventValue
	eventValue="$( printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -v sentinel=1 -f "$rigLegacyField" 2>/dev/null )" || :
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
