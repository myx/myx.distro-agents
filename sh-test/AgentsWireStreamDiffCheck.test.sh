#!/usr/bin/env bash
## Differential check on both wires' AgentsWireStreamConsume: the single-awk consumers
## (AgentsOpenAiChatStream.awk, AgentsAnthropicMessagesStream.awk) leave exactly the
## stream.* files the previous per-event shell loops left -- every name, every byte --
## and write exactly the same live display to stderr, byte for byte, thinking-line
## wrapping included. The previous loops are kept ONLY here, as
## check-fixtures/*-stream-consume.legacy.sh, reading through the legacy field engine.
## The canned streams carry what the display and the files are sensitive to: reasoning
## split across deltas and newlines, control bytes and ESC in text, \u pairs, tool-call
## fragments with sparse, missing and odd indices, usage with and without cache fields,
## error objects, a non-SSE body without its final newline, CRLF, comments, and
## malformed payloads. Offline by construction: no request, no host, the scratch is
## this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsOpenAiChatWire.sh" "$rigHere/AgentsAnthropicMessagesWire.sh" \
	"$rigHere/AgentsOpenAiChatStream.awk" "$rigHere/AgentsAnthropicMessagesStream.awk" \
	"$rigTest/check-fixtures/AgentsHarnessJsonField.legacy.awk" \
	"$rigTest/check-fixtures/openai-chat-stream-consume.legacy.sh" \
	"$rigTest/check-fixtures/anthropic-messages-stream-consume.legacy.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsWireStreamDiffCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The one core helper the thinking-line wrap calls, lifted out of the harness by name.
rigLift="$( LC_ALL=C awk '
	/^AgentsHarnessWholeNumber\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 1 ) exit 1 ; }
' "$rigHarness" )" || rigRefuse "AgentsHarnessWholeNumber was not found in $rigHarness"

rigPass=0
rigFail=0

## One consumer over one stream, into its own directory: the scratch it leaves, its
## stderr, its status, and a listing of every file with its checksum.
rigConsume(){ ## OpenAiChat|AnthropicMessages, legacy|current, stream file, out dir, set -u or +u
	mkdir -p "$4/scratch"
	(
		set "${5:--u}"
		harnessHere="$rigHere" harnessScratch="$4/scratch" harnessSelfName=rig harnessRound=1
		harnessDim='<dim>' harnessTool='<tool>' harnessValue='<value>' harnessWarn='<warn>' harnessBad='<bad>' harnessOff='<off>'
		harnessReadCap=100000
		COLUMNS=60
		rigLegacyField="$rigTest/check-fixtures/AgentsHarnessJsonField.legacy.awk"
		eval "$rigLift"
		if [ "$2" = legacy ] ; then
			case "$1" in
				OpenAiChat) . "$rigTest/check-fixtures/openai-chat-stream-consume.legacy.sh" ;;
				*) . "$rigTest/check-fixtures/anthropic-messages-stream-consume.legacy.sh" ;;
			esac
		else
			. "$rigHere/Agents${1}Wire.sh"
		fi
		set +e
		AgentsWireStreamConsume < "$3" 2> "$4/err"
		printf '%s' "$?" > "$4/rc"
	)
	## No status at all: bash's own arithmetic stopped the whole subshell, which is
	## itself an answer both consumers must give.
	[ -f "$4/rc" ] || printf 'stopped' > "$4/rc"
	rigStderrNormal < "$4/err" > "$4/err.normal"
	## stream.usage.detail is the current consumers' own addition (the session token totals
	## read it); the previous loops never wrote it, so it has no counterpart to compare.
	( cd "$4/scratch" && for rigEach in * ; do [ -e "$rigEach" ] || continue ; [ "$2" = current ] && [ "$rigEach" = stream.usage.detail ] && continue ; printf '%s %s\n' "$( cksum < "$rigEach" )" "$rigEach" ; done ) > "$4/listing"
}

## Where bash's own arithmetic stopped the previous loop, bash said so on stderr, naming
## that file and line; the new consumer's probe says the same thing under its own
## name, and not necessarily at the same point in the display. So each such message
## is cut out, with its newline, and its presence compared on its own.
rigStderrNormal(){
	LC_ALL=C awk '
		{ allText = allText $0 "\n" ; }
		END {
			bashErrors = gsub(/(\/[^ :\n]*: line [0-9]+|AgentsWireStream): [^\n]*(unbound variable|syntax error|value too great|operand expected)[^\n]*\n/, "", allText)
			printf("bash-errors:%d\n%s", bashErrors > 0, allText)
		}
	'
}

rigScenario(){ ## OpenAiChat|AnthropicMessages, title, stream file, set -u or +u (default -u)
	local scenarioDir="$rigTmp/run.$rigPass.$rigFail"
	rm -rf "$scenarioDir"
	rigConsume "$1" legacy "$3" "$scenarioDir/old" "${4:--u}"
	rigConsume "$1" current "$3" "$scenarioDir/new" "${4:--u}"
	if cmp -s "$scenarioDir/old/listing" "$scenarioDir/new/listing" \
		&& cmp -s "$scenarioDir/old/err.normal" "$scenarioDir/new/err.normal" \
		&& cmp -s "$scenarioDir/old/rc" "$scenarioDir/new/rc" ; then
		## A scenario whose files are all empty would compare equal and prove nothing.
		if [ -s "$scenarioDir/old/listing" ] ; then
			rigPass=$(( rigPass + 1 ))
			printf '  PASS  %s -- %s\n' "$1" "$2"
			return 0
		fi
	fi
	rigFail=$(( rigFail + 1 ))
	printf '  FAIL  %s -- %s\n' "$1" "$2"
	diff "$scenarioDir/old/listing" "$scenarioDir/new/listing" | sed 's/^/        /' | head -20
	cmp "$scenarioDir/old/err.normal" "$scenarioDir/new/err.normal" 2>&1 | sed 's/^/        stderr: /'
}

## ---- OpenAI chat-completions streams ----------------------------------------------
{
	printf ': keep-alive\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{"role":"assistant","reasoning":"Let me think about this carefully, wrapping words across a narrow"},"finish_reason":null}],"usage":null}\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{"reasoning":" terminal so that think"},"finish_reason":null}]}\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{"reasoning":"ing stays one word.\\nNew paragraph\\u0007 with \\u001b[31m escape\\n\\n- a list item\\n"},"finish_reason":null}]}\n\n'
	printf 'data:{"id":"c1","choices":[{"index":0,"delta":{"reasoning":"no-space data line, \\u00e9\\ud83d\\ude00 *glob* ?chars"},"finish_reason":null}]}\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{"content":"Answer line one\\r\\nline \\u001b two\\b and\\ttab\\n\\n"},"finish_reason":null}]}\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{"content":"tail without newline"},"finish_reason":null}]}\n\n'
	printf 'data: {"id":"c1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
	printf 'data: {"id":"c1","choices":[],"usage":{"prompt_tokens":120,"completion_tokens":30,"total_tokens":150,"prompt_tokens_details":{"cached_tokens":64}}}\n\n'
	printf 'data: [DONE]\n\n'
} > "$rigTmp/oa.thinking-content.sse"
rigScenario OpenAiChat "reasoning wrapped across deltas and newlines, then content, usage with cache" "$rigTmp/oa.thinking-content.sse"

{
	printf 'event: ignored\r\nid: 7\r\nretry: 100\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"reasoning":"brief"}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_A","type":"function","function":{"name":"Read","arguments":""}}]}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"file_path\\": \\"/x/\\u00e9 \\\\\\"q\\\\\\"\\""}}]}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":", \\"limit\\": 3}\\n"}}]}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":2,"id":"call_C","function":{"name":"Glob","arguments":"{}"}},{"id":"call_noindex","function":{"name":"Bash"}}]}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":"abc","id":"odd","function":{"arguments":"x"}},{"index":"007","id":"octal"},{"index":-1,"id":"neg"}]}}]}\r\n\r\n'
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}\r\n\r\n'
	printf 'data: [DONE]\r\n\r\n'
} > "$rigTmp/oa.tool-calls.sse"
rigScenario OpenAiChat "tool-call fragments, sparse/missing/odd indices, CRLF, usage without cache" "$rigTmp/oa.tool-calls.sse"

{
	printf 'data: {"choices":[{"index":0,"delta":{"content":"partial"}}]}\n\n'
	printf 'data: {"error":null,"choices":[{"index":0,"delta":{"content":" error-null is not an error"}}]}\n\n'
	printf 'data: {"error":{"message":"Rate limit reached","type":"rate_limit","code":"429"}}\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"content":"after"}}]}\n\n'
} > "$rigTmp/oa.error.sse"
rigScenario OpenAiChat "an error object mid-stream, an error:null beside it, no [DONE]" "$rigTmp/oa.error.sse"

printf '{"error":{"message":"Incorrect API key","type":"invalid_request_error","code":"invalid_api_key"}}\n<html>\n  body</html>' > "$rigTmp/oa.refusal.body"
rigScenario OpenAiChat "a non-SSE refusal body, last line without its newline" "$rigTmp/oa.refusal.body"

{
	printf 'data: {"choices":[{"index":0,"delta":{"content":"ok"}}]\n\n'
	printf 'data: not json at all\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"content":"bad \\uZZZZ escape"}}]}\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":{"__count":"2"}}}]}\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":{"__count":"1e3"}}}]}\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"content":"dup"},"delta":{"content":"second"}}]}\n\n'
	printf 'data: {"choices":[{"index":0,"delta":{"reasoning":"\\n\\nleading breaks","content":"both in one"}}]}\n\n'
	printf 'data: {"usage": {"prompt_tokens":1,"total_tokens":""}}\n\n'
	printf 'data: {"usage": {"prompt_tokens":"7\\n","completion_tokens":2,"total_tokens":9,"prompt_tokens_details":{"cached_tokens":null}}}\n\n'
	printf 'data:  [DONE]\n\n'
	printf 'data: [DONE]'
} > "$rigTmp/oa.malformed.sse"
rigScenario OpenAiChat "malformed payloads, a literal __count, duplicates, odd usage, final line unterminated" "$rigTmp/oa.malformed.sse"

## ---- Anthropic Messages streams -----------------------------------------------------
{
	printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":5000,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
	printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"THINK, then \\"quoted\\"\\n"}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"more \\u00e9\\ud83d\\ude00\\n\\n"}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"SIG=="}}\n\n'
	printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
	printf 'event: content_block_start\ndata: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"TEXT \\u001b[1m with\\r CR\\b and\\nnewline"}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":""}}\n\n'
	printf 'event: content_block_start\ndata: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_1","name":"Glob","input":{}}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\\"pattern\\": \\"*\\", "}}\n\n'
	printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"\\"path\\": \\"/tmp\\"}"}}\n\n'
	printf 'event: content_block_start\ndata: {"type":"content_block_start","index":3,"content_block":{"type":"redacted_thinking","data":"opaque\\u0041"}}\n\n'
	printf 'event: ping\ndata: {"type":"ping"}\n\n'
	printf ': comment\n'
	printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
	printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
} > "$rigTmp/an.thinking-tool.sse"
rigScenario AnthropicMessages "thinking, signature, text with control bytes, tool_use json, redacted block, usage" "$rigTmp/an.thinking-tool.sse"

{
	printf 'data: {"type":"message_start","message":{"usage":{"input_tokens":60}}}\r\n\r\n'
	printf 'data:{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\r\n'
	printf 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"answer\\n"}}\r\n'
	printf 'data: {"type":"content_block_start","index":"x","content_block":{"type":"text"}}\n'
	printf 'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"again"}}\n'
	printf 'data: {"type":"content_block_start","index":5,"content_block":{"type":"tool_use","id":"t5","name":"Read","input":{"a":[1,{"b":"\\""}]}}}\n'
	printf 'data: {"type":"content_block_start","index":4}\n'
	printf 'data: {"type":"content_block_delta","index":5,"delta":{"type":"unknown_delta","x":1}}\n'
	printf 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"bad \\uZZ"}}\n'
	printf 'data: not json\n'
	printf 'data: {"type":"message_delta","delta":{"stop_reason":""},"usage":{"output_tokens":5}}\n'
	printf 'data: {"type":"message_stop"}\n'
	printf 'data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}\n'
	printf 'data: {"type":"message_stop"}\n'
} > "$rigTmp/an.odd.sse"
rigScenario AnthropicMessages "CRLF, no cache fields, odd and repeated indices, unknown deltas, malformed, error event" "$rigTmp/an.odd.sse"
rigScenario AnthropicMessages "the same under set +u, where an unset name in the index is 0" "$rigTmp/an.odd.sse" +u

## Where bash's arithmetic itself refuses a value, the previous loop died on the spot:
## everything before it written and shown, nothing after. The same point, here.
{
	printf 'data: {"type":"message_start","message":{"usage":{"input_tokens":"1.5","cache_read_input_tokens":3}}}\n'
	printf 'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n'
	printf 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"shown"}}\n'
	printf 'data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}\n'
	printf 'data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":"again, lower than seen"}}\n'
	printf 'data: {"type":"content_block_start","index":"010","content_block":{"type":"text","text":"octal"}}\n'
	printf 'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":"2"}}\n'
	printf 'data: {"type":"message_stop"}\n'
	printf 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"never written"}}\n'
} > "$rigTmp/an.usage-abort.sse"
rigScenario AnthropicMessages "an input_tokens of 1.5 stops the loop at message_stop" "$rigTmp/an.usage-abort.sse" +u
{
	printf 'data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}\n'
	printf 'data: {"type":"content_block_start","index":"08","content_block":{"type":"text","text":""}}\n'
	printf 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"never written"}}\n'
} > "$rigTmp/an.index-abort.sse"
rigScenario AnthropicMessages "an index of 08 stops the loop at its content_block_start" "$rigTmp/an.index-abort.sse" +u
{
	printf 'data: {"choices":[{"index":0,"delta":{"content":"shown","tool_calls":[{"index":0,"id":"a","function":{"name":"Read","arguments":"{}"}},{"index":"+1","id":"b"},{"index":"09","id":"c","function":{"arguments":"x"}},{"index":3,"id":"d"}]}}]}\n'
	printf 'data: {"choices":[{"index":0,"delta":{"content":"never shown"}}]}\n'
	printf 'data: [DONE]\n'
} > "$rigTmp/oa.index-abort.sse"
rigScenario OpenAiChat "a tool-call index of 09 stops the loop at its count step" "$rigTmp/oa.index-abort.sse" +u

printf '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}' > "$rigTmp/an.refusal.body"
rigScenario AnthropicMessages "a non-SSE refusal body without its final newline" "$rigTmp/an.refusal.body"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ WIRE STREAM DIFF CHECK FAILED: $rigFail of $(( rigPass + rigFail )) scenario(s)" >&2 ; exit 1
fi
printf 'WIRE_STREAM_DIFF: OK (%d scenarios, files and live display byte for byte against the previous consumers, offline)\n' "$rigPass"
