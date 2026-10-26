#!/usr/bin/env bash
## Behavioural check on our WebSearch (S2.3), run through the real MCP server against a fake `curl` first on PATH that plays DuckDuckGo as it was measured:
## without a named User-Agent every endpoint answers 202, its block page; with one, the Instant Answer API answers its JSON and the HTML endpoint its result page.
## Held:
##   1. both requests carry the named User-Agent myx.distro-agents/1.0
##   2. the result page is read: title, url (the uddg target, percent-decoded), snippet (markup and entities gone), the instant answer on top
##   3. allowed_domains and blocked_domains still filter the web results
##   4. a 202, and a 200 page with no result markup, are reported as BLOCKED, never as a search that found nothing or a complete, successful one
##   5. the no-results page of the endpoint is the one case reported as a complete search that found nothing
##   6. where the wrapper of the service says it has a search of its own (HARNESS_WEB_SEARCH), a running harness uses it: one request carrying the server tool and the
##      domain list, its findings and sources the tool result; a failure of it is reported as an error, and DuckDuckGo answers instead; a service without one never calls it
## Offline: the fake curl is the only network there is.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWebSearchCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
mkdir -p "$rigTmp/bin" "$rigTmp/.local/.agents" "$rigTmp/home" "$rigTmp/data"
: > "$rigTmp/.local/.agents/magic-team.agent.env"

## The fake curl: logs its arguments one line a call, and answers by the endpoint, the User-Agent and RIG_DDG (ok, blocked, bare, none).
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=/dev/null ; agent="" ; url=""
while [ "$#" -gt 0 ] ; do
	case "$1" in
		-o) out="$2" ; shift ;;
		-A) agent="$2" ; shift ;;
	esac
	url="$1"
	shift
done
printf 'CALL agent=[%s] url=[%s]\n' "$agent" "$url" >> "$RIG_CURL_LOG"
status=200 ; body=""
case "$url" in
	*api.duckduckgo.com*) body='{"AbstractText":"RIGABSTRACT about the query","AbstractSource":"RigPedia","AbstractURL":"https://rigpedia.example/q","Results":[],"RelatedTopics":[]}' ; [ "$RIG_DDG" != none ] || body='{"Abstract":"","Results":[],"RelatedTopics":[]}' ;;
	*html.duckduckgo.com*)
		case "$RIG_DDG" in
			bare) body='<html><body><p>nothing we know how to read</p></body></html>' ;;
			none) body='<html><body><div class="no-results">No results.</div></body></html>' ;;
			*) body='<div class="result"><h2 class="result__title"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fa%3Fx%3D1&amp;rut=abc">Example <b>Title</b> One</a></h2><a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fa&amp;rut=abc">First snippet with <b>bold</b> &amp; more</a></div>
<div class="result"><h2 class="result__title"><a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fother.example%2Fb&amp;rut=def">Second Title</a></h2><a class="result__snippet" href="x">Second snippet</a></div>' ;;
		esac
	;;
esac
if [ -z "$agent" ] || [ "$RIG_DDG" = blocked ] ; then status=202 ; body='<html><body>anomaly: please complete the challenge</body></html>' ; fi
printf '%s' "$body" > "$out"
printf '%s' "$status"
EOF
chmod +x "$rigTmp/bin/curl"

rigSearch(){ ## mode, arguments JSON -- the text of the answer, in $rigText (JSON-escaped as the wire carries it)
	rigText=""
	: > "$rigTmp/curl.log"
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"WebSearch","arguments":%s}}\n' "$2" \
		| ( cd "$rigTmp" && RIG_DDG="$1" RIG_CURL_LOG="$rigTmp/curl.log" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="$rigTmp/home/.claude/skills" \
			MDAT_DATA_ROOT="$rigTmp/data" PATH="$rigTmp/bin:$PATH" bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :
	rigText="$( LC_ALL=C grep -m1 '^{"jsonrpc":"2.0","id":2,' "$rigTmp/wire" )"
	[ -n "$rigText" ] || { sed 's/^/    /' "$rigTmp/err" >&2 ; rigRefuse "the server answered no WebSearch call" ; }
}
rigHas(){ ## needle -- yes when the answer holds it
	case "$rigText" in *"$1"*) printf yes ;; *) printf no ;; esac
}

echo "-- a search that is answered --"
rigSearch ok '{"query":"rigquery"}'
rigAssert "both requests carry the named User-Agent" "$( LC_ALL=C grep -c 'agent=\[myx.distro-agents/1.0\]' "$rigTmp/curl.log" ) of $( LC_ALL=C grep -c '^CALL' "$rigTmp/curl.log" )" "2 of 2"
rigAssert "the instant answer is on top" "$( rigHas 'RIGABSTRACT about the query' )" yes
rigAssert "the web results are read: title, url, snippet, markup and entities gone" "$( rigHas '1. Example Title One' ) $( rigHas 'https://example.org/a?x=1' ) $( rigHas 'First snippet with bold & more' ) $( rigHas '2. Second Title' )" "yes yes yes yes"
rigBefore=no
case "$rigText" in
	*RIGABSTRACT*'web results for'*) rigBefore=yes ;;
esac
rigAssert "the instant answer comes before the results" "$rigBefore" yes
rigAssert "it is not reported as blocked or as empty" "$( rigHas 'BLOCKED' ) $( rigHas 'FOUND NOTHING' )" "no no"

echo "-- the domain lists --"
rigSearch ok '{"query":"rigquery","allowed_domains":["other.example"]}'
rigAssert "allowed_domains keeps only that domain" "$( rigHas 'Second Title' ) $( rigHas 'Example Title One' )" "yes no"
rigSearch ok '{"query":"rigquery","blocked_domains":["other.example"]}'
rigAssert "blocked_domains drops that domain" "$( rigHas 'Second Title' ) $( rigHas 'Example Title One' )" "no yes"

echo "-- a refusal is a refusal --"
rigSearch blocked '{"query":"rigquery"}'
rigAssert "a 202 is reported as BLOCKED, naming the status" "$( rigHas 'BLOCKED' ) $( rigHas 'HTTP 202' )" "yes yes"
rigAssert "and never as a complete, successful search" "$( rigHas 'SUCCESSFUL SEARCH' ) $( rigHas 'FOUND NOTHING' )" "no no"
rigSearch bare '{"query":"rigquery"}'
rigAssert "a 200 page with no result markup is reported as BLOCKED too" "$( rigHas 'BLOCKED' ) $( rigHas 'no result markup' ) $( rigHas 'SUCCESSFUL SEARCH' )" "yes yes no"
rigAssert "the instant answer that did come is still given" "$( rigHas 'RIGABSTRACT about the query' )" yes

echo "-- the one empty search --"
rigSearch none '{"query":"rigquery"}'
rigAssert "the no-results page is a complete search that found nothing, not blocked" "$( rigHas 'FOUND NOTHING' ) $( rigHas 'BLOCKED' )" "yes no"

echo "-- the service's own search, in a running harness --"
## A second fake curl: the model's rounds and the service search are both POSTs to the Messages endpoint, answered in order from res.<n> (a stream for a round,
## a plain body for the search, which asks for a status and a body file); DuckDuckGo is answered as above.
mkdir -p "$rigTmp/bin2"
cat > "$rigTmp/bin2/curl" <<'EOF'
#!/usr/bin/env bash
out=/dev/null ; agent="" ; url="" ; data="" ; stream="" ; ARGS="$*"
while [ "$#" -gt 0 ] ; do
	case "$1" in
		-o) out="$2" ; shift ;;
		-A) agent="$2" ; shift ;;
		-N) stream=1 ;;
		--data-binary) data="${2#@}" ; shift ;;
	esac
	url="$1"
	shift
done
cat > /dev/null
case "$url" in
	*duckduckgo*) printf 'DDG %s\n' "$url" >> "$RIG_SCENARIO/ddg.log" ; printf '{"AbstractText":"RIGDDGFALLBACK"}' > "$out" ; printf '200' ; exit 0 ;;
esac
round=$(( $( cat "$RIG_SCENARIO/round" ) + 1 )) ; printf '%s' "$round" > "$RIG_SCENARIO/round"
[ -z "$data" ] || cp "$data" "$RIG_SCENARIO/req.$round"
printf '%s\n' "$ARGS" > "$RIG_SCENARIO/args.$round"
[ -f "$RIG_SCENARIO/res.$round" ] || { printf 'rig: no canned answer for call %s\n' "$round" >&2 ; exit 1 ; }
if [ -n "$stream" ] ; then
	cat "$RIG_SCENARIO/res.$round"
else
	cp "$RIG_SCENARIO/res.$round" "$out" ; printf '%s' "$(cat "$RIG_SCENARIO/status.$round" 2> /dev/null || printf 200)"
fi
EOF
chmod +x "$rigTmp/bin2/curl"
rigToolStream(){ ## file, tool arguments JSON (escaped for the stream)
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"WebSearch","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigTextStream(){ ## file, text
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigNativeOk='{"id":"msg_s","type":"message","role":"assistant","content":[{"type":"text","text":"RIGNATIVETEXT the findings"},{"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{"query":"rigq"}},{"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[{"type":"web_search_result","url":"https://example.org/native","title":"Native One","page_age":"1 day"},{"type":"web_search_result","url":"https://blocked.example/x","title":"Native Blocked"}]}],"stop_reason":"end_turn"}'
rigHarnessRun(){ ## scenario name, HARNESS_WEB_SEARCH value -- a whole run with the model calling WebSearch once
	rigDir="$rigTmp/$1" ; mkdir -p "$rigDir/.local/.agents" ; printf '0' > "$rigDir/round" ; : > "$rigDir/ddg.log"
	( cd "$rigDir" && RIG_SCENARIO="$rigDir" MMDAPP="$rigDir" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" PATH="$rigTmp/bin2:$PATH" \
		HARNESS_PROVIDER_NAME="Rig" HARNESS_SELF_NAME="AgentsWebSearchCheck.test.sh" HARNESS_ENDPOINT="${3:-https://rig.invalid/v1/messages}" HARNESS_HOST="rig.invalid" HARNESS_WIRE="${4:-AnthropicMessages}" \
		HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" HARNESS_CREDENTIAL_NAMES="none -- this check reads none" HARNESS_MODEL_LIGHT="rig-model" HARNESS_MODEL_MAIN="rig-model" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" HARNESS_OUTPUT_TOKENS_LIGHT=4096 HARNESS_OUTPUT_TOKENS_MAIN=4096 HARNESS_WEB_SEARCH="$2" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" --access-root "$rigDir" RIG-TASK ) > "$rigDir/out" 2> "$rigDir/err" || :
}
rigHeld(){ ## file, text -- yes when the file holds it
	case "$( cat "$1" 2> /dev/null )" in *"$2"*) printf yes ;; *) printf no ;; esac
}
rigDir="$rigTmp/native-ok" ; mkdir -p "$rigDir"
rigToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"allowed_domains\": [\"example.org\", \"blocked.example\"]}'
printf '%s' "$rigNativeOk" > "$rigDir/res.2"
rigTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun native-ok anthropic:web_search_20250305
rigAssert "the run ends with the model's answer" "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "the service search was one request carrying the server tool, the domain list and the query" "$( rigHeld "$rigDir/req.2" '"type":"web_search_20250305"' ) $( rigHeld "$rigDir/req.2" '"allowed_domains":["example.org","blocked.example"]' ) $( rigHeld "$rigDir/req.2" 'Search the web for: rigq' )" "yes yes yes"
rigAssert "its findings and its sources are the tool result the model gets next" "$( rigHeld "$rigDir/req.3" 'RIGNATIVETEXT the findings' ) $( rigHeld "$rigDir/req.3" 'https://example.org/native' )" "yes yes"
rigAssert "DuckDuckGo was not called" "$( LC_ALL=C grep -c . "$rigDir/ddg.log" )" 0
rigDir="$rigTmp/native-fail" ; mkdir -p "$rigDir"
rigToolStream "$rigDir/res.1" '{\"query\": \"rigq\"}'
printf '%s' '{"type":"error","error":{"type":"rate_limit_error","message":"RIGLIMIT too many"}}' > "$rigDir/res.2" ; printf '429' > "$rigDir/status.2"
rigTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun native-fail anthropic:web_search_20250305
rigAssert "a refusal of the service search is reported as an error, with its status and reason" "$( rigHeld "$rigDir/req.3" 'ERROR: the service search answered HTTP 429' ) $( rigHeld "$rigDir/req.3" 'RIGLIMIT too many' )" "yes yes"
rigAssert "and DuckDuckGo answers instead" "$( LC_ALL=C grep -c 'duckduckgo' "$rigDir/ddg.log" | LC_ALL=C tr -d ' ' | LC_ALL=C sed 's/^[1-9][0-9]*$/called/' ) $( rigHeld "$rigDir/req.3" 'RIGDDGFALLBACK' )" "called yes"
rigDir="$rigTmp/native-none" ; mkdir -p "$rigDir"
rigToolStream "$rigDir/res.1" '{\"query\": \"rigq\"}'
rigTextStream "$rigDir/res.2" RIG-FINAL-MARKER
rigHarnessRun native-none none
rigAssert "a service without a search of its own makes no service request: only the two rounds, DuckDuckGo answering" "$( cat "$rigDir/round" ) $( rigHeld "$rigDir/req.2" 'RIGDDGFALLBACK' )" "2 yes"

## The same two streams on the OpenAI chat wire, which DeepSeek and xAI speak (the Messages wire alone once hid a helper the chat wire does not define).
rigChatToolStream(){ ## file, tool arguments JSON (escaped for the stream)
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"WebSearch","arguments":"%s"}}]}}]}\n' "$2" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}\ndata: [DONE]\n' >> "$1"
}
rigChatTextStream(){ ## file, text
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}\ndata: [DONE]\n' "$2" > "$1"
}
echo "-- DeepSeek's Search API and xAI's web_search tool, in a running harness --"
rigChat=https://rig.invalid/v1/chat/completions
rigDir="$rigTmp/ds-ok" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"blocked_domains\": [\"blocked.example\"]}'
printf '%s' '{"results":[{"rerank_score":2.4,"title":"DS One","url":"https://example.org/ds","snippet":"RIGDSSNIP"},{"title":"DS Blocked","url":"https://blocked.example/x","snippet":"s"}]}' > "$rigDir/res.2"
rigChatTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun ds-ok deepseek:search "$rigChat" OpenAiChat
rigAssert "DeepSeek: the request goes to /v1/tools/search with the query, the -site: operator and a count" "$( rigHeld "$rigDir/args.2" 'rig.invalid/v1/tools/search' ) $( rigHeld "$rigDir/req.2" '"query":"rigq -site:blocked.example"' ) $( rigHeld "$rigDir/req.2" '"count":10' )" "yes yes yes"
rigAssert "DeepSeek: its results are the tool result, a blocked domain dropped, DuckDuckGo not called" "$( rigHeld "$rigDir/req.3" 'RIGDSSNIP' ) $( rigHeld "$rigDir/req.3" 'https://example.org/ds' ) $( rigHeld "$rigDir/req.3" 'DS Blocked' ) $( LC_ALL=C grep -c . "$rigDir/ddg.log" )" "yes yes no 0"
rigDir="$rigTmp/ds-empty" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"allowed_domains\": [\"a.example\", \"b.example\"]}'
printf '%s' '{"results":[]}' > "$rigDir/res.2"
rigChatTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun ds-empty deepseek:search "$rigChat" OpenAiChat
rigAssert "DeepSeek: allowed_domains become site: clauses joined with OR; an empty list is a complete search that found nothing, DuckDuckGo not called" "$( rigHeld "$rigDir/req.2" '"query":"rigq site:a.example OR site:b.example"' ) $( rigHeld "$rigDir/req.3" 'FOUND NOTHING' ) $( LC_ALL=C grep -c . "$rigDir/ddg.log" )" "yes yes 0"
rigDir="$rigTmp/ds-fail" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\"}'
printf '%s' '{"error":{"message":"RIGDSAUTH bad key"}}' > "$rigDir/res.2" ; printf '401' > "$rigDir/status.2"
rigChatTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun ds-fail deepseek:search "$rigChat" OpenAiChat
rigAssert "DeepSeek: a refusal is reported as an error with its status and reason, and DuckDuckGo answers instead" "$( rigHeld "$rigDir/req.3" 'ERROR: the service search answered HTTP 401' ) $( rigHeld "$rigDir/req.3" 'RIGDSAUTH bad key' ) $( rigHeld "$rigDir/req.3" 'RIGDDGFALLBACK' )" "yes yes yes"
rigDir="$rigTmp/xai-ok" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"allowed_domains\": [\"example.org\"]}'
printf '%s' '{"output":[{"type":"web_search_call","id":"ws_1"},{"type":"message","content":[{"type":"output_text","text":"RIGXAITEXT findings","annotations":[]}]}],"citations":["https://example.org/x","https://blocked.example/y"]}' > "$rigDir/res.2"
rigChatTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun xai-ok xai:web_search "$rigChat" OpenAiChat
rigAssert "xAI: the request goes to /v1/responses with the web_search tool and the allowed_domains filter" "$( rigHeld "$rigDir/args.2" 'rig.invalid/v1/responses' ) $( rigHeld "$rigDir/req.2" '"tools":[{"type":"web_search","filters":{"allowed_domains":["example.org"]}}]' ) $( rigHeld "$rigDir/req.2" 'Search the web for: rigq' )" "yes yes yes"
rigAssert "xAI: the text and the kept citations are the tool result, a citation outside allowed_domains dropped, DuckDuckGo not called" "$( rigHeld "$rigDir/req.3" 'RIGXAITEXT findings' ) $( rigHeld "$rigDir/req.3" 'https://example.org/x' ) $( rigHeld "$rigDir/req.3" 'blocked.example/y' ) $( LC_ALL=C grep -c . "$rigDir/ddg.log" )" "yes yes no 0"
rigDir="$rigTmp/xai-blocked" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"blocked_domains\": [\"blocked.example\"]}'
printf '%s' '{"output":[{"type":"message","content":[{"type":"output_text","text":"RIGXAITEXT"}]}],"citations":[]}' > "$rigDir/res.2"
rigChatTextStream "$rigDir/res.3" RIG-FINAL-MARKER
rigHarnessRun xai-blocked xai:web_search "$rigChat" OpenAiChat
rigAssert "xAI: blocked_domains go as excluded_domains" "$( rigHeld "$rigDir/req.2" '"filters":{"excluded_domains":["blocked.example"]}' )" yes
rigDir="$rigTmp/xai-six" ; mkdir -p "$rigDir"
rigChatToolStream "$rigDir/res.1" '{\"query\": \"rigq\", \"allowed_domains\": [\"a.x\",\"b.x\",\"c.x\",\"d.x\",\"e.x\",\"f.x\"]}'
rigChatTextStream "$rigDir/res.2" RIG-FINAL-MARKER
rigHarnessRun xai-six xai:web_search "$rigChat" OpenAiChat
rigAssert "xAI: more than 5 domains is an error, the service is not called, DuckDuckGo answers" "$( rigHeld "$rigDir/req.2" 'at most 5 domains' ) $( cat "$rigDir/round" ) $( rigHeld "$rigDir/req.2" 'RIGDDGFALLBACK' )" "yes 2 yes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WEB SEARCH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WEB_SEARCH: OK (%d assertions, offline, a fake curl)\n' "$rigPasses"
