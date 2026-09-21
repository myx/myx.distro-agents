#!/usr/bin/env bash
## Behavioural check on the DYNAMIC tool class -- the MCP tools a run enumerates at
## startup. AgentsHarnessSelfCheck.awk beside it cannot see one: it matches declaration,
## announce and dispatch sites in the SOURCES, and a tool built at runtime has none, so
## a ninth tool reaching the wire leaves its report byte-identical to a clean one. This
## proves the four sites by RUNNING them -- rendered declaration, announce arm, dispatch
## arm, server round-trip -- against a fake MCP server and a fake `curl`, both first on
## PATH or named by absolute path in the rig's own mcp.servers.json. Offline by construction:
## no socket is opened, no credential is read, and nothing outlives the EXIT trap.
set -u
rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found beside this check: $rigHarness" >&2 ; exit 1 ; }

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

rigTmp="$( mktemp -d -t AgentsHarnessMcpCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cat > "$rigTmp/bin/curl" <<'RIGFAKECURL'
#!/usr/bin/env bash
## Records this round's request body and replays this round's canned stream. It opens
## no socket, and being first on PATH is the whole of this check's offline guarantee.
set -u
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
RIGFAKECURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A real MCP server, in the only sense that matters here: it speaks the same
## line-per-object stdio transport over the same three requests. It records what it was
## asked for, so the rig can assert that enumeration happened ONCE for the whole run,
## across a summarise-and-restart, and that a refused call never reached it at all.
cat > "$rigTmp/bin/rigmcp" <<'RIGFAKEMCP'
#!/usr/bin/env bash
set -u
[ ! -f "$RIG_SCENARIO/mcp.dead" ] || exit 1
while IFS= read -r rigLine ; do
	case "$rigLine" in
		*'"method":"initialize"'*)
			printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{},"serverInfo":{"name":"rigmcp","version":"1"}}}'
		;;
		*'"method":"tools/list"'*)
			printf 'list\n' >> "$RIG_SCENARIO/mcp.calls"
			printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"ping","description":"RIG-DESC-MARKER","inputSchema":{"type":"object","properties":{"word":{"type":"string","description":"RIG-SCHEMA-MARKER"}},"required":["word"]}}]}}'
			## This server dies after handing over its tools, which is what makes the
			## mid-run death a real one rather than a name that never resolved.
			[ -z "${RIG_MCP_DIE_AFTER_LIST:-}" ] || : > "$RIG_SCENARIO/mcp.dead"
		;;
		*'"method":"tools/call"'*)
			printf 'call\n' >> "$RIG_SCENARIO/mcp.calls"
			rigWord="${rigLine##*\"word\":\"}"
			rigWord="${rigWord%%\"*}"
			printf '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"RIG-MCPRESULT:%s"}]}}\n' "$rigWord"
		;;
	esac
done
RIGFAKEMCP
chmod +x "$rigTmp/bin/rigmcp"

## Denies exactly when the payload carries the rig's argument marker, which reaches a
## hook only through `tool_input`. Silence and exit 0 is the allow every hook in this
## estate uses, so an emptied `tool_input` makes this same hook permit the call.
cat > "$rigTmp/bin/rigdeny" <<'RIGDENYHOOK'
#!/usr/bin/env bash
set -u
case "$( cat )" in
	*RIG-ARG-MARKER*)
		printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"RIG-HOOK-DENIED"}}'
	;;
esac
RIGDENYHOOK
chmod +x "$rigTmp/bin/rigdeny"

## A provider stub's job, done here instead: the core refuses to start without these.
## The host is a reserved .invalid name that can never resolve and the token is a
## literal, so nothing in this rig can reach a service or spend a credential.
export HARNESS_PROVIDER_NAME="mcp-check rig"
export HARNESS_SELF_NAME="AgentsHarnessMcpCheck.sh"
export HARNESS_ENDPOINT="https://harness-mcp-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-mcp-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
	mkdir -p "$rigScenarioDir/.local/agents"
	printf '{"mcpServers":{"rigmcp":{"command":"%s/bin/rigmcp","args":[],"env":{"RIG_MCP_PROBE":"rig-not-a-credential"}}}}\n' "$rigTmp" > "$rigScenarioDir/.local/agents/mcp.servers.json"
}

## A round answering with one MCP tool call, then the usage chunk the threshold reads.
rigMcpStream(){ ## canned-stream file, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-mcp-call","type":"function","function":{"name":"mcp__rigmcp__ping","arguments":"{\\"word\\":\\"RIG-ARG-MARKER\\"}"}}]}}]}\n' > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with plain text and no tool call.
rigTextStream(){ ## canned-stream file, content, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" "$3" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## MDAT_HARNESS_CONTEXT_TOKENS, then the harness arguments this scenario adds
	local runContextTokens="$1"
	shift
	rigRunStatus=0
	## MMDAPP points at the scenario, so .local/agents/mcp.servers.json and .claude/settings.json are both
	## this scenario's own and no file of the real workspace is read.
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		MDAT_HARNESS_CONTEXT_TOKENS="$runContextTokens" MDAT_HARNESS_MAX_RESTARTS=3 \
		"$rigHarness" --access-root "$rigScenarioDir" "$@" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing"
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

## yes/no rather than a status, so both directions are values a failure can print.
## A request that was never made gets its own third value: it is not the same finding
## as one made without the text, and a bare `no` would read as though it were.
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## Counts whole recorded lines rather than substrings, so `list` and `call` can never
## be read off one another, and an absent file counts 0 rather than erroring.
rigServerSaw(){ ## exchange kind
	LC_ALL=C awk -v wantKind="$1" '$0 == wantKind { seenCount++ ; } END { print seenCount + 0 ; }' "$rigScenarioDir/mcp.calls" 2>/dev/null || printf '0'
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

## All four sites at once, plus the freeze: the restart re-offers the same declaration
## without the server being enumerated a second time.
rigStart declared-called-restarted
rigMcpStream "$rigScenarioDir/res.1" 5000
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER 20
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER 20
rigRun 1000 --mcp-server rigmcp
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "three rounds were requested"                     "$rigRoundCount" 3
rigAssert "the declaration reached the wire"                "$( rigHolds "$rigScenarioDir/req.1" '"name":"mcp__rigmcp__ping"' )" yes
rigAssert "it carries the server's own description"         "$( rigHolds "$rigScenarioDir/req.1" 'RIG-DESC-MARKER' )" yes
rigAssert "it carries the server's own input schema"        "$( rigHolds "$rigScenarioDir/req.1" 'RIG-SCHEMA-MARKER' )" yes
rigAssert "the built-in tools are still declared"           "$( rigHolds "$rigScenarioDir/req.1" '"name":"WebFetch"' )" yes
rigAssert "the announce arm stated this call's arguments"   "$( rigHolds "$rigScenarioDir/err" 'RIG-ARG-MARKER' )" yes
rigAssert "the dispatch arm did not fall through"           "$( rigHolds "$rigScenarioDir/req.2" 'unknown tool' )" no
rigAssert "the server answered, and got the arguments"      "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT:RIG-ARG-MARKER' )" yes
rigAssert "the fresh leg re-offers the same declaration"    "$( rigHolds "$rigScenarioDir/req.3" '"name":"mcp__rigmcp__ping"' )" yes
rigAssert "the server was enumerated once for the whole run" "$( rigServerSaw list )" 1
rigAssert "the server was called once"                      "$( rigServerSaw call )" 1
rigAssert "the fresh leg's own answer is the result"        "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "declaration, announce, dispatch and round-trip -- frozen across a restart"

## The negative control, and the reason a green run above cannot be a vacuous one: the
## same canned rounds with no server named, where every probe answers the other way.
rigStart no-server-named
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun 0
rigAssert "the run ends normally"                     "$rigRunStatus" 0
rigAssert "two rounds were requested"                 "$rigRoundCount" 2
rigAssert "nothing was declared"                      "$( rigHolds "$rigScenarioDir/req.1" 'mcp__rigmcp__ping' )" no
rigAssert "the built-in tools are still declared"     "$( rigHolds "$rigScenarioDir/req.1" '"name":"WebFetch"' )" yes
rigAssert "nothing was enumerated"                    "$( rigHolds "$rigScenarioDir/err" 'tool(s) enumerated' )" no
rigAssert "no server process was started at all"      "$( rigServerSaw list )" 0
rigAssert "the call is refused as an unknown tool"    "$( rigHolds "$rigScenarioDir/req.2" 'no MCP server this run enumerated declares it' )" yes
rigAssert "the answer still comes back"               "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "no server named -- nothing declared, nothing spawned, the call refused"

## A server that hands over its tools and then dies: the call becomes an ERROR the model
## reads, and the round carries on rather than the leg restarting or exiting.
rigStart server-dies-mid-run
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
export RIG_MCP_DIE_AFTER_LIST=1
rigRun 0 --mcp-server rigmcp
unset RIG_MCP_DIE_AFTER_LIST
rigAssert "the run ends normally"                      "$rigRunStatus" 0
rigAssert "two rounds were requested"                  "$rigRoundCount" 2
rigAssert "the declaration still reached the wire"     "$( rigHolds "$rigScenarioDir/req.1" '"name":"mcp__rigmcp__ping"' )" yes
rigAssert "the tool result is an ERROR"                "$( rigHolds "$rigScenarioDir/req.2" 'ERROR: mcp__rigmcp__ping' )" yes
rigAssert "the ERROR names what went wrong"            "$( rigHolds "$rigScenarioDir/req.2" 'returned no answer to this call' )" yes
rigAssert "the dead server produced no result"         "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT' )" no
rigAssert "the round carried on to an answer"          "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the server dies mid-run -- ERROR as the tool result, the round continues"

## The payload, which is the whole reason a deny hook can decide anything about an MCP
## call: the hook denies on a value that reaches it ONLY through `tool_input`.
rigStart hook-denies-the-call
mkdir -p "$rigScenarioDir/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"%s/bin/rigdeny"}]}]}}\n' "$rigTmp" > "$rigScenarioDir/.claude/settings.json"
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun 0 --mcp-server rigmcp
rigAssert "the run ends normally"                   "$rigRunStatus" 0
rigAssert "two rounds were requested"               "$rigRoundCount" 2
rigAssert "the hook's own reason is the result"     "$( rigHolds "$rigScenarioDir/req.2" 'RIG-HOOK-DENIED' )" yes
rigAssert "it is stated as a hook refusal"          "$( rigHolds "$rigScenarioDir/req.2" 'blocked by a PreToolUse hook' )" yes
rigAssert "the server was never called"             "$( rigServerSaw call )" 0
rigAssert "no result came back from the server"     "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT' )" no
rigAssert "the round carried on to an answer"       "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a PreToolUse hook denies an MCP call -- it reads tool_input and the tool never runs"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_MCP: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
