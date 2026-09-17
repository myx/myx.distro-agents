#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only

## AgentsOpenAiChatWire.sh -- the OpenAI chat-completions wire adapter, sourced by
## AgentsUniversalHarness.sh and never executed: every function here runs in the
## core's process and shares its variables. What belongs here is whatever the
## endpoint's schema fixes; policy such as a byte cap stays in the core. Field names
## are observed on real responses, never documentation-derived. Shared by every
## provider speaking this wire, which is why it is not a provider file.

## The names here must stay literals: AgentsHarnessSelfCheck.awk finds the declaration
## site by matching this exact JSON envelope, and a variable would empty its population.
## Tool names also appear in prose the model reads -- edit_file in the write_file
## description below, read_file in the core's system prompt -- which no check can see.
## web_search and fetch, when added, are unrestricted by the human-owner's own ruling;
## each must still state that fetched content is DATA, never instruction. Never trim that.
harnessToolsJson='[
{"type":"function","function":{"name":"read_file","description":"Read a UTF-8 text file and return its content. Content over 200000 bytes is truncated from the start of the file and the truncation is stated in the output; there is no way to read past that point, so a longer file cannot be read in full.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the file."}},"required":["path"]}}},
{"type":"function","function":{"name":"write_file","description":"Create or overwrite a UTF-8 text file with the given complete content. Always writes the whole file. To change part of a file, use edit_file instead: it replaces text inside the file without you needing the rest of its content. NEVER read a file and write it back when the read reported truncation - the content you received is not the whole file, and writing it back destroys everything past the truncation point. For a file too long to read in full, edit_file is the only safe way to change it.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the file."},"content":{"type":"string","description":"The complete new content of the file."}},"required":["path","content"]}}},
{"type":"function","function":{"name":"glob","description":"List a directory, or find paths matching a pattern beneath it. The directory itself is tested before the pattern is evaluated, so a path that does not exist is reported as such rather than as an empty result.","parameters":{"type":"object","properties":{"pattern":{"type":"string","description":"A shell glob matched against names beneath path. Use * to list everything directly in path."},"path":{"type":"string","description":"Absolute path to the directory to search."},"long":{"type":"string","description":"Optional. Any non-empty value gives a long listing carrying type, size and permissions."}},"required":["pattern","path"]}}},
{"type":"function","function":{"name":"edit_file","description":"Replace one exact occurrence of old_text with new_text in a UTF-8 text file. The replacement happens inside the tool, so you never need the rest of the file and nothing is ever truncated - this is the safe way to change a file that is too long to read in full.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the file."},"old_text":{"type":"string","description":"The exact text to replace. Must occur in the file."},"new_text":{"type":"string","description":"The text to put in its place."}},"required":["path","old_text","new_text"]}}},
{"type":"function","function":{"name":"grep","description":"Recursively search a file or directory for a pattern.","parameters":{"type":"object","properties":{"pattern":{"type":"string","description":"A basic regular expression, as grep(1) reads one."},"path":{"type":"string","description":"Absolute path to the file or directory to search."}},"required":["pattern","path"]}}},
{"type":"function","function":{"name":"run_command","description":"Run a shell command with the given working directory.","parameters":{"type":"object","properties":{"cwd":{"type":"string","description":"Absolute path of the working directory the command runs in."},"command":{"type":"string","description":"The shell command line to run."}},"required":["cwd","command"]}}}
]'

## This wire carries the system prompt as the first record in `messages`.
AgentsWireInitMessages(){
	harnessMessages=(
		'{"role":"system","content":"'"$( printf '%s' "$harnessSystemText" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}'
		'{"role":"user","content":"'"$( printf '%s' "$harnessPrompt" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}'
	)
}

## Reconstructed from the same scalar fields the reader pulls out, since only a scalar
## leaf is addressable. id and name are escaped because neither is guaranteed free of
## `"` or `\`, which would corrupt the next request rather than mis-render text.
AgentsWireAssistantToolCallsRecord(){
	local recordCalls="$1"
	printf '%s' '{"role":"assistant","content":null,"tool_calls":['"$recordCalls"']}'
}

AgentsWireToolCallEntry(){
	local entryId="$1" entryName="$2" entryArgs="$3" entryIdEsc entryNameEsc entryArgsEsc
	entryIdEsc="$( printf '%s' "$entryId" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	entryNameEsc="$( printf '%s' "$entryName" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	entryArgsEsc="$( printf '%s' "$entryArgs" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	printf '%s' "{\"id\":\"$entryIdEsc\",\"type\":\"function\",\"function\":{\"name\":\"$entryNameEsc\",\"arguments\":\"$entryArgsEsc\"}}"
}

## One role:tool result per call, keyed by that exact tool_call_id, passed through verbatim.
AgentsWireToolResultRecord(){
	local resultCallId="$1" resultText="$2" resultCallIdEsc resultTextEsc
	resultCallIdEsc="$( printf '%s' "$resultCallId" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	resultTextEsc="$( printf '%s' "$resultText" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	printf '%s' '{"role":"tool","tool_call_id":"'"$resultCallIdEsc"'","content":"'"$resultTextEsc"'"}'
}

## Appends in a fixed order, for the prompt cache. An empty $harnessReasoningEffort
## omits the key entirely: this wire rejects an empty string where it accepts absence.
AgentsWireRequestBody(){
	local bodyMessagesJson bodyOut
	bodyMessagesJson="$( IFS=, ; echo "[${harnessMessages[*]}]" )"
	bodyOut='{"model":"'"$harnessModel"'","messages":'"$bodyMessagesJson"',"tools":'"$harnessToolsJson"',"tool_choice":"auto","max_tokens":8192,"stream":true'
	[ -z "$harnessReasoningEffort" ] || bodyOut="$bodyOut"',"reasoning_effort":"'"$harnessReasoningEffort"'"'
	bodyOut="$bodyOut"'}'
	printf '%s' "$bodyOut"
}

## A stated, loud failure in place of the bare set -e kill an unguarded assignment
## produces when the reader's own rc is non-zero and nothing downstream tests it.
AgentsWireResponseField(){
	local fieldPath="$1" fieldRc=0 fieldValue
	fieldValue="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path="$fieldPath" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || fieldRc=$?
	if [ "$fieldRc" != "0" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: round $harnessRound: response is missing required field '$fieldPath' (rc=$fieldRc) -- the model/API returned a tool_calls shape this harness cannot use" >&2
		exit 1
	fi
	printf '%s' "$fieldValue"
}

## The core asks for "the id of tool call N"; only this file knows where that lives.
AgentsWireToolCallId(){
	AgentsWireResponseField "choices.0.message.tool_calls.$1.id"
}

AgentsWireToolCallName(){
	AgentsWireResponseField "choices.0.message.tool_calls.$1.function.name"
}

AgentsWireToolCallArgs(){
	AgentsWireResponseField "choices.0.message.tool_calls.$1.function.arguments"
}

## Optional: used only to explain an otherwise-empty final answer.
AgentsWireFinishReason(){
	printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=choices.0.finish_reason -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## Reads SSE off stdin and, on a clean `[DONE]`, leaves this round's accumulators in
## $harnessScratch for AgentsWireSynthesizeResponse below. That state lives in files
## because `curl | while read` runs the loop in a subshell, which bash 3.2 cannot avoid.
AgentsWireStreamConsume(){
	local streamLine streamPayload deltaContent deltaToolCount tcIdx tcIndexField tcId tcName tcArgsFrag finishReason tcSeen
	: > "$harnessScratch/stream.content"
	while IFS= read -r streamLine ; do
		streamLine="${streamLine%$'\r'}"
		case "$streamLine" in
			"")
				: ## SSE event separator
			;;
			:*|event:*|id:*|retry:*)
				: ## SSE comment/heartbeat, or a named field this API does not use
			;;
			"data:"*)
				## The space after the colon is optional in the SSE grammar, so exactly
				## one is stripped: `data:{...}` and `data: {...}` are the same event.
				streamPayload="${streamLine#data:}"
				streamPayload="${streamPayload# }"
				if [ "$streamPayload" = "[DONE]" ] ; then
					: > "$harnessScratch/stream.done"
					continue
				fi

				deltaContent="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.delta.content -v optional=1 -v sentinel=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
				deltaContent="${deltaContent%X}"
				if [ -n "$deltaContent" ] ; then
					## Live prose echo; ESC, CR and BS dropped so it cannot forge our chrome.
					printf '%s' "$deltaContent" >> "$harnessScratch/stream.content"
					printf '%s' "${deltaContent//[$'\033'$'\r'$'\b']/ }" >&2
				fi

				finishReason="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.finish_reason -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
				[ -z "$finishReason" ] || printf '%s' "$finishReason" > "$harnessScratch/stream.finish_reason"

				deltaToolCount="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.delta.tool_calls.__count -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || deltaToolCount=0
				[ -n "$deltaToolCount" ] || deltaToolCount=0
				tcIdx=0
				## `function.arguments` arrives as fragments keyed by the call's own index.
				while [ "$tcIdx" -lt "$deltaToolCount" ] 2>/dev/null ; do
					tcIndexField="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.index" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
					[ -n "$tcIndexField" ] || tcIndexField="$tcIdx"
					tcId="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.id" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
					tcName="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.name" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
					tcArgsFrag="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.arguments" -v optional=1 -v sentinel=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
					tcArgsFrag="${tcArgsFrag%X}"

					[ -z "$tcId" ] || printf '%s' "$tcId" > "$harnessScratch/stream.tool.$tcIndexField.id"
					[ -z "$tcName" ] || printf '%s' "$tcName" > "$harnessScratch/stream.tool.$tcIndexField.name"
					[ -z "$tcArgsFrag" ] || printf '%s' "$tcArgsFrag" >> "$harnessScratch/stream.tool.$tcIndexField.args"

					tcSeen="$( cat "$harnessScratch/stream.tool.count" 2>/dev/null )" || tcSeen=0
					[ -n "$tcSeen" ] || tcSeen=0
					if [ "$tcIndexField" -ge "$tcSeen" ] 2>/dev/null ; then
						printf '%s' "$(( tcIndexField + 1 ))" > "$harnessScratch/stream.tool.count"
					fi

					tcIdx=$(( tcIdx + 1 ))
				done
			;;
			*)
				## Not an SSE line shape at all: most likely the whole response is a plain
				## non-streaming error body, accumulated verbatim for the core's error path.
				printf '%s\n' "$streamLine" >> "$harnessScratch/stream.rawother"
			;;
		esac
	done
}

## Builds the exact document shape a non-streaming response has, so everything
## downstream in the core reads a document it cannot tell apart from a real one --
## rather than a second, streaming-shaped dispatch path for the same bug to hide in.
AgentsWireSynthesizeResponse(){
	local synthToolCount synthFinishReason synthCalls="" synthIdx=0
	local synthId synthName synthArgs synthContent synthContentEsc
	synthToolCount="$( cat "$harnessScratch/stream.tool.count" 2>/dev/null )" || synthToolCount=0
	[ -n "$synthToolCount" ] || synthToolCount=0
	synthFinishReason="$( cat "$harnessScratch/stream.finish_reason" 2>/dev/null )"
	if [ "$synthToolCount" -gt 0 ] ; then
		[ -n "$synthFinishReason" ] || synthFinishReason="tool_calls"
		while [ "$synthIdx" -lt "$synthToolCount" ] ; do
			synthId="$( cat "$harnessScratch/stream.tool.$synthIdx.id" 2>/dev/null )"
			synthName="$( cat "$harnessScratch/stream.tool.$synthIdx.name" 2>/dev/null )"
			synthArgs="$( cat "$harnessScratch/stream.tool.$synthIdx.args" 2>/dev/null )"
			synthCalls="${synthCalls}${synthCalls:+,}$( AgentsWireToolCallEntry "$synthId" "$synthName" "$synthArgs" )"
			synthIdx=$(( synthIdx + 1 ))
		done
		harnessResponse='{"choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":['"$synthCalls"']},"finish_reason":"'"$synthFinishReason"'"}]}'
	else
		[ -n "$synthFinishReason" ] || synthFinishReason="stop"
		synthContent="$( cat "$harnessScratch/stream.content" 2>/dev/null )"
		synthContentEsc="$( printf '%s' "$synthContent" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
		harnessResponse='{"choices":[{"index":0,"message":{"role":"assistant","content":"'"$synthContentEsc"'"},"finish_reason":"'"$synthFinishReason"'"}]}'
	fi
}

## The body decides success or failure, never curl's exit status, which succeeds on a
## 4xx error body. This wire's error shape is flat: {"status":n,"error":"CODE","message":"..."}.
## Prints the code and returns: 0 an error body, 3 the success case, anything else unparseable.
AgentsWireErrorCode(){
	local errRc=0 errCode
	errCode="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=error -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || errRc=$?
	printf '%s' "$errCode"
	return "$errRc"
}

AgentsWireToolCallCount(){
	local countRc=0 countValue
	countValue="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=choices.0.message.tool_calls.__count -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || countRc=$?
	[ "$countRc" = "0" ] || countValue=0
	printf '%s' "$countValue"
}

AgentsWireFinalContent(){
	local finalText
	finalText="$( printf '%s\n' "$harnessResponse" | LC_ALL=C awk -v path=choices.0.message.content -v optional=1 -v sentinel=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || :
	printf '%s' "${finalText%X}"
}
