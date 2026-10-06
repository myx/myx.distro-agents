#!/usr/bin/env bash
## The previous AgentsWireStreamConsume of AgentsOpenAiChatWire.sh, with its thinking-line
## helpers, kept ONLY as the reference AgentsWireStreamDiffCheck.test.sh compares the
## single-awk consumer against. It forks AgentsHarnessJsonField.awk per field per event;
## here that reader is the legacy engine at $rigLegacyField. Nothing in sh-lib loads this.

## Column this block has reached, owned here rather than passed in and out across a
## function boundary. Set to the gutter where a block opens, advanced by the wrap, and
## meaningless outside one thinking block.
agentsWireThinkCol=0
agentsWireThinkGutter="${harnessProgressGutter:-18}"

## Lays out an already-sanitised thinking fragment: whole words only, wrapped to the
## terminal and indented to the gutter so a continuation reads as thinking rather than
## as the harness speaking. Forks nothing -- this runs per streamed delta.
AgentsWireThinkingWrap(){ ## sanitised text
	local wrapWord wrapGlobWasOff wrapWidth="${COLUMNS:-100}"
	AgentsHarnessWholeNumber "$wrapWidth" || wrapWidth=100
	[ "$wrapWidth" -ge 40 ] || wrapWidth=100
	## Word-splitting is wanted here; pathname expansion is not. An unquoted $1
	## would glob a model's `*` or `?` against the filesystem and print filenames
	## in place of its words. Restored exactly as found, never forced back on.
	case "$-" in *f*) wrapGlobWasOff=1 ;; *) wrapGlobWasOff="" ; set -f ;; esac
	for wrapWord in $1 ; do
		if [ $(( agentsWireThinkCol + ${#wrapWord} + 1 )) -gt "$wrapWidth" ] ; then
			printf '\n%*s' "$agentsWireThinkGutter" '' >&2
			agentsWireThinkCol="$agentsWireThinkGutter"
		fi
		printf '%s%s %s' "$harnessDim" "$wrapWord" "$harnessOff" >&2
		agentsWireThinkCol=$(( agentsWireThinkCol + ${#wrapWord} + 1 ))
	done
	[ -n "$wrapGlobWasOff" ] || set +f
}

## Ends the current thinking line and starts the next one in the gutter. This is what
## keeps a model's own paragraphs and lists intact: the sanitiser folds every C0 byte
## to a space, newlines included, so without this the reasoning arrives as one blob no
## amount of wrapping can restore. Re-indenting each line into the gutter is also what
## keeps the guard's intent -- nothing the model emits reaches column zero, so it still
## cannot forge this harness's own chrome.
AgentsWireThinkingBreak(){
	if [ -n "$thinkingBuf" ] ; then
		AgentsWireThinkingWrap "$thinkingBuf"
		thinkingBuf=""
	fi
	printf '\n%*s' "$agentsWireThinkGutter" '' >&2
	agentsWireThinkCol="$agentsWireThinkGutter"
}

## Takes one raw reasoning delta and feeds it through, splitting on real newlines so
## they survive as line breaks rather than being folded into spaces. Each segment is
## sanitised on its own, so the control-byte guard still runs over every byte.
AgentsWireThinkingFeed(){ ## raw reasoning delta
	local feedRest="$1" feedSeg feedSafe feedBreak
	while : ; do
		case "$feedRest" in
			*$'\n'*)
				feedSeg="${feedRest%%$'\n'*}"
				feedRest="${feedRest#*$'\n'}"
				feedBreak=1
			;;
			*)
				feedSeg="$feedRest"
				feedRest=""
				feedBreak=""
			;;
		esac
		if [ -n "$feedSeg" ] ; then
			feedSafe="$( printf '%s' "$feedSeg" | LC_ALL=C awk -v progressLineCap=1000000 -f "$harnessHere/AgentsProgressLineSafe.awk" )"
			thinkingBuf="$thinkingBuf$feedSafe"
			case "$thinkingBuf" in
				*\ *)
					thinkingEmit="${thinkingBuf% *}"
					thinkingBuf="${thinkingBuf##* }"
					AgentsWireThinkingWrap "$thinkingEmit"
				;;
			esac
		fi
		[ -n "$feedBreak" ] || break
		AgentsWireThinkingBreak
	done
}

## Closes an open thinking block: flushes the partial word still buffered, then ends
## the line. Written once because both the content arm and the tool-call arm close it,
## and two copies of the same compound condition drift.
AgentsWireThinkingClose(){ ## buffer-variable name is this wire's own $thinkingBuf
	[ -n "$thinkingOpen" ] || return 0
	if [ -n "$thinkingBuf" ] ; then
		AgentsWireThinkingWrap "$thinkingBuf"
		thinkingBuf=""
	fi
	thinkingOpen=""
	printf '\n' >&2
}

## Reads SSE off stdin and, on a clean `[DONE]`, leaves this round's accumulators in
## $harnessScratch for AgentsWireSynthesizeResponse below. That state lives in files
## because `curl | while read` runs the loop in a subshell, which bash 3.2 cannot avoid.
AgentsWireStreamConsume(){
	local streamLine streamPayload streamError deltaContent deltaReasoning thinkingOpen deltaToolCount tcIdx tcIndexField tcId tcName tcArgsFrag finishReason tcSeen
	local thinkingBuf="" thinkingEmit="" thinkingSafe=""
	local usagePrompt usageCompletion usageTotal
	: > "$harnessScratch/stream.content"
	## A refusal body ends without a newline, and a bare `read` drops that last line --
	## the refusal then reads as a stream that disconnected, three times over.
	while IFS= read -r streamLine || [ -n "$streamLine" ] ; do
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
					## A thinking line with no answer behind it still ends here.
					AgentsWireThinkingClose
					continue
				fi

				## An error object on a data line is the round's whole answer, kept as a
				## non-streaming error body is, so the core reports it once and never retries.
				case "$streamPayload" in
					*'"error":'*)
						streamError="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=error -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" 2>/dev/null )" || streamError=""
						if [ -n "$streamError" ] && [ "$streamError" != null ] ; then
							printf '%s\n' "$streamPayload" >> "$harnessScratch/stream.rawother"
							continue
						fi
					;;
				esac

				## Gated on the object, not the key: every delta chunk carries a null usage, and the last real one wins.
				case "$streamPayload" in
					*'"usage":{'*|*'"usage": {'*)
						usagePrompt="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=usage.prompt_tokens -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
						usageCompletion="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=usage.completion_tokens -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
						usageTotal="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=usage.total_tokens -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
						[ -z "$usageTotal" ] || printf '%s %s %s\n' "$usagePrompt" "$usageCompletion" "$usageTotal" > "$harnessScratch/stream.usage"
						## `absent` and `0` are two different answers here: no cached_tokens field at all, against a round that cached nothing.
						[ -z "$usageTotal" ] || printf '\n%s\n' "   💾 ${harnessDim}prompt cache -- $usagePrompt prompt tokens this round, cached:${harnessOff} ${harnessValue}$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=usage.prompt_tokens_details.cached_tokens -v optional=1 -f "$rigLegacyField" 2>/dev/null || printf absent )${harnessOff}" >&2
					;;
				esac

				## This model family carries its chain of thought here, beside content rather than inside it.
				deltaReasoning="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.delta.reasoning -v optional=1 -v sentinel=1 -f "$rigLegacyField" 2>/dev/null )" || :
				deltaReasoning="${deltaReasoning%X}"
				if [ -n "$deltaReasoning" ] ; then
					## Opened by the first fragment, so a model emitting none shows no block at all.
					if [ -z "$thinkingOpen" ] ; then
						thinkingOpen=1
						thinkingBuf=""
						agentsWireThinkCol="$agentsWireThinkGutter"
						printf '   🧠 %s%-*s%s ' "$harnessTool" "${harnessLabelWidth:-11}" "thinking" "$harnessOff" >&2
					fi
					## Wrapped to the gutter rather than run as one long line. The text is
					## already sanitised by the renderer -- every C0 byte and DEL is a space
					## by the time it arrives -- so this decides line breaks and nothing else,
					## and the ANSI guard above is untouched.
					## Buffered to whitespace first: a delta arrives mid-word, so emitting
					## each one as its own words would split `think` and `ing` into two.
					AgentsWireThinkingFeed "$deltaReasoning"
				fi

				deltaContent="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.delta.content -v optional=1 -v sentinel=1 -f "$rigLegacyField" 2>/dev/null )" || :
				deltaContent="${deltaContent%X}"
				if [ -n "$deltaContent" ] ; then
					## The answer starts on its own line, never continuing an open thinking one.
					AgentsWireThinkingClose
					## Live prose echo; ESC, CR and BS dropped so it cannot forge our chrome.
					printf '%s' "$deltaContent" >> "$harnessScratch/stream.content"
					printf '%s' "${deltaContent//[$'\033'$'\r'$'\b']/ }" >&2
				fi

				finishReason="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.finish_reason -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
				[ -z "$finishReason" ] || printf '%s' "$finishReason" > "$harnessScratch/stream.finish_reason"

				deltaToolCount="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path=choices.0.delta.tool_calls.__count -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || deltaToolCount=0
				[ -n "$deltaToolCount" ] || deltaToolCount=0
				tcIdx=0
				## `function.arguments` arrives as fragments keyed by the call's own index.
				while [ "$tcIdx" -lt "$deltaToolCount" ] 2>/dev/null ; do
					tcIndexField="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.index" -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
					[ -n "$tcIndexField" ] || tcIndexField="$tcIdx"
					tcId="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.id" -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
					tcName="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.name" -v optional=1 -f "$rigLegacyField" 2>/dev/null )" || :
					tcArgsFrag="$( printf '%s\n' "$streamPayload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.arguments" -v optional=1 -v sentinel=1 -f "$rigLegacyField" 2>/dev/null )" || :
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
