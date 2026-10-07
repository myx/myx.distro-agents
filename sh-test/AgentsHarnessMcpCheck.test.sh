#!/usr/bin/env bash
## Behavioural check on the DYNAMIC tool class -- the MCP tools a run enumerates at
## startup. AgentsHarnessSelfCheck.test.awk beside it cannot see one: it matches declaration,
## announce and dispatch sites in the SOURCES, and a tool built at runtime has none, so
## a ninth tool reaching the wire leaves its report byte-identical to a clean one. This
## proves the four sites by RUNNING them -- rendered declaration, announce arm, dispatch
## arm, server round-trip -- against a fake MCP server and a fake `curl`, both first on
## PATH or named by absolute path in the rig's own mcp.servers.index -- the harness's own
## registration, written here with the installer's own index writer. Offline by construction:
## no socket is opened, no credential is read, and nothing outlives the EXIT trap.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

rigTmp="$( mktemp -d -t AgentsHarnessMcpCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The fake binaries this rig puts on PATH are REAL FILES under sh-test/check-fixtures
## and are copied, never carried here in a heredoc: a delimiter lost inside a body
## that is itself shell takes the rest of this check with it, and a check that stops
## checking still prints its PASS lines. A missing fixture refuses instead.
rigFixtures="$rigTest/check-fixtures"
rigInstallFixture(){
	cp "$rigFixtures/$1" "$2" || rigRefuse "a fixture is missing from the package: $rigFixtures/$1"
	chmod +x "$2"
}
rigInstallFixture harness-mcp-check.curl.test.sh "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A real MCP server, in the only sense that matters here: it speaks the same
## line-per-object stdio transport over the same three requests. It records what it was
## asked for, so the rig can assert that enumeration happened once per round, across a
## summarise-and-restart, and that a refused call never reached it at all.
rigInstallFixture harness-mcp-check.mcp-server.test.sh "$rigTmp/bin/rigmcp"

## Denies exactly when the payload carries the rig's argument marker, which reaches a
## hook only through `tool_input`. Silence and exit 0 is the allow every hook in this
## estate uses, so an emptied `tool_input` makes this same hook permit the call.
## Shared with AgentsHarnessCopilotLegCheck.test.sh, which asserts the same thing about the
## same marker -- one fixture, because the two bodies were byte-identical copies.
rigInstallFixture pre-tool-use-deny-on-marker.test.sh "$rigTmp/bin/rigdeny"

## A provider stub's job, done here instead: the core refuses to start without these.
## The host is a reserved .invalid name that can never resolve and the token is a
## literal, so nothing in this rig can reach a service or spend a credential.
export HARNESS_PROVIDER_NAME="mcp-check rig"
export HARNESS_SELF_NAME="AgentsHarnessMcpCheck.test.sh"
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
	rigRegister "$rigScenarioDir" > "$rigScenarioDir/.local/agents/mcp.servers.index" || rigRefuse "the rig's MCP index could not be written"
}
## The rig server registered in a workspace's harness index, with the installer's own
## writer; given an extra env value, the same server with a changed registration.
rigRegister(){ ## workspace [extra env value]
	(
		harnessHere="$rigHere" ; . "$rigHere/AgentsHarnessMcpConfig.include" || exit 1
		AgentsHarnessMcpSpecReset
		if [ -n "${2:-}" ] ; then
			AgentsHarnessMcpSpecAdd rigmcp "$rigTmp/bin/rigmcp" 2 RIG_MCP_PROBE rig-not-a-credential RIG_MCP_EXTRA "$2"
		else
			AgentsHarnessMcpSpecAdd rigmcp "$rigTmp/bin/rigmcp" 1 RIG_MCP_PROBE rig-not-a-credential
		fi
		AgentsHarnessMcpIndexText "$1" use-spec
	)
}
## A hook in a workspace's harness hook index: our policy's records plus one rig record.
rigHookIndex(){ ## workspace, matcher, absolute script
	mkdir -p "$1/.local/agents"
	(
		harnessHere="$rigHere" ; . "$rigHere/AgentsHarnessHooksLoad.include" && AgentsHarnessHooksRecordsComputed \
			&& AgentsHarnessHooksIndexText "$agentsHooksRecords"$'PreToolUse\tall\trig-record\t'"$2"$'\t'"$3"$'\t\n'
	) > "$1/.local/agents/harness.hooks.index" || rigRefuse "the rig's hook index could not be written"
}

## A round answering with one MCP tool call, then the usage chunk the threshold reads.
rigMcpStream(){ ## canned-stream file, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-mcp-call","type":"function","function":{"name":"mcp__rigmcp__ping","arguments":"{\\"word\\":\\"RIG-ARG-MARKER\\"}"}}]}}]}\n' > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with one ListMcpResourcesTool call naming the rig server.
rigResourceListStream(){ ## canned-stream file
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-res-call","type":"function","function":{"name":"ListMcpResourcesTool","arguments":"{\\"server\\":\\"rigmcp\\"}"}}]}}]}\n' > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
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
	## MMDAPP points at the scenario, so .local/agents/mcp.servers.index and harness.hooks.index are both
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
## The registration never changes and nothing fails, so the catalogue enumerated at
## start is kept for every round: re-spawning the server each round bought nothing.
rigAssert "the server was enumerated once, not per round"   "$( rigServerSaw list )" 1
rigAssert "an unchanged set is reported as no change"       "$( rigHolds "$rigScenarioDir/err" 'MCP tool set changed' )" no
## The `tools` array alone: the wire writes it after `messages` and right before
## `tool_choice`, so it is the last `"tools":[` ahead of the first `],"tool_choice":`
## -- message text may carry the same key, escaped, earlier in the body.
rigToolsOf(){ ## request file
	LC_ALL=C awk '
		{ body = body $0 ; }
		END {
			endPos = index( body, "],\"tool_choice\":" )
			if ( !endPos ) exit
			head = substr( body, 1, endPos )
			startPos = 0
			while ( ( foundPos = index( substr( head, startPos + 1 ), "\"tools\":[" ) ) > 0 ) startPos = startPos + foundPos
			if ( startPos ) print substr( head, startPos )
		}
	' "$1" 2>/dev/null
}
rigAssert "an unchanged set sends the same tools bytes"      "$( [ -n "$( rigToolsOf "$rigScenarioDir/req.1" )" ] && [ "$( rigToolsOf "$rigScenarioDir/req.1" )" = "$( rigToolsOf "$rigScenarioDir/req.3" )" ] && printf same || printf differ )" same
rigAssert "the server was called once"                      "$( rigServerSaw call )" 1
rigAssert "the fresh leg's own answer is the result"        "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "declaration, announce, dispatch and round-trip -- enumerated once, kept across rounds and a restart"

## The tool set is dynamic: a registration removed between rounds is gone from the next
## request, and one added between rounds is declared in it. No --mcp-server is named, so
## the set is the workspace's own registration, its mcp.servers.index read again before every round.
rigStart unregistered-mid-run
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
RIG_AFTER_ROUND_1="rm -f '$rigScenarioDir/.local/agents/mcp.servers.index'" rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "two rounds were requested"                       "$rigRoundCount" 2
## Read by the declaration's own description: the round-1 call record carries the
## tool's name into every later request, so the name alone cannot tell them apart.
rigAssert "the first round declares the registered server"  "$( rigHolds "$rigScenarioDir/req.1" 'RIG-DESC-MARKER' )" yes
rigAssert "the next round no longer declares it"            "$( rigHolds "$rigScenarioDir/req.2" 'RIG-DESC-MARKER' )" no
rigAssert "the change was reported"                         "$( rigHolds "$rigScenarioDir/err" 'MCP tool set changed' )" yes
rigVerdict "a registration removed mid-run -- gone from the next round"

rigStart registered-mid-run
mv "$rigScenarioDir/.local/agents/mcp.servers.index" "$rigScenarioDir/mcp.servers.index.later"
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
RIG_AFTER_ROUND_1="mv '$rigScenarioDir/mcp.servers.index.later' '$rigScenarioDir/.local/agents/mcp.servers.index'" rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "two rounds were requested"                       "$rigRoundCount" 2
rigAssert "the first round declares no MCP tool"            "$( rigHolds "$rigScenarioDir/req.1" 'mcp__rigmcp__ping' )" no
rigAssert "the next round declares the new registration"    "$( rigHolds "$rigScenarioDir/req.2" 'RIG-DESC-MARKER' )" yes
rigVerdict "a registration added mid-run -- declared from the next round"

## The unavailable note follows the enumeration, both ways. The server dying after the
## first round is told to the model in the next request; one coming back is told too.
rigStart unavailable-mid-run
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
RIG_AFTER_ROUND_1=": > '$rigScenarioDir/mcp.dead'" rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "the first request says nothing is unavailable"   "$( rigHolds "$rigScenarioDir/req.1" 'is unavailable' )" no
rigAssert "the next request tells the model it is"          "$( rigHolds "$rigScenarioDir/req.2" 'have changed since you were last told. As of now' )" yes
rigVerdict "a server lost mid-run -- the model is told in the next round"

rigStart available-again-mid-run
: > "$rigScenarioDir/mcp.dead"
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
RIG_AFTER_ROUND_1="rm -f '$rigScenarioDir/mcp.dead'" rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "the first request says the server is unavailable" "$( rigHolds "$rigScenarioDir/req.1" 'is unavailable' )" yes
rigAssert "the next request declares it again"              "$( rigHolds "$rigScenarioDir/req.2" 'RIG-DESC-MARKER' )" yes
rigAssert "and tells the model the earlier sentence no longer holds" "$( rigHolds "$rigScenarioDir/req.2" 'is now available' )" yes
rigVerdict "a server back mid-run -- declared and told in the next round"

## A failure inside a mid-run enumeration is stated and the run carries on. The rig
## makes one by turning the reply file enumeration writes into a directory; the first
## round calls a built-in tool, so nothing but the enumeration writes that file. The
## registration is rewritten too -- same server, one more env value -- because an
## unchanged one is not enumerated again, and a changed one must be.
rigStart enumeration-fails-mid-run
rigRegister "$rigScenarioDir" changed > "$rigScenarioDir/mcp.servers.index.changed" || rigRefuse "the rig's changed MCP index could not be written"
printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-glob-call","type":"function","function":{"name":"Glob","arguments":"{\\"pattern\\":\\"*\\"}"}}]}}]}\n' > "$rigScenarioDir/res.1"
printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' >> "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
RIG_AFTER_ROUND_1='rigReq="${RIG_REQUEST_FILE%/*}/mcp.reply" ; rm -f "$rigReq" ; mkdir "$rigReq" ; mv "$RIG_SCENARIO/mcp.servers.index.changed" "$RIG_SCENARIO/.local/agents/mcp.servers.index"' rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "two rounds were requested"                       "$rigRoundCount" 2
rigAssert "the failure's own reason is shown"               "$( rigHolds "$rigScenarioDir/err" 'Is a directory' )" yes
rigAssert "the server is degraded, saying why"              "$( rigHolds "$rigScenarioDir/err" 'answer could not be written' )" yes
rigAssert "and the model is told"                           "$( rigHolds "$rigScenarioDir/req.2" 'answer could not be written' )" yes
rigVerdict "an enumeration failing mid-run -- stated, and the run carries on"

## The cache's own boundary, from the other side: built-in calls only, nothing failing and
## nothing edited, across four rounds -- the server is spawned for the first enumeration
## and never again, and every round declares its tool with the same bytes.
rigStart unchanged-not-reenumerated
for rigRoundAt in 1 2 3 ; do
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-glob-%s","type":"function","function":{"name":"Glob","arguments":"{\\"pattern\\":\\"*\\"}"}}]}}]}\n' "$rigRoundAt" > "$rigScenarioDir/res.$rigRoundAt"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' >> "$rigScenarioDir/res.$rigRoundAt"
done
rigTextStream "$rigScenarioDir/res.4" RIG-FINAL-MARKER 20
rigRun 0
rigAssert "the run ends normally"                           "$rigRunStatus" 0
rigAssert "four rounds were requested"                      "$rigRoundCount" 4
rigAssert "the server was enumerated once for the session"  "$( rigServerSaw list )" 1
rigAssert "the last round still declares its tool"          "$( rigHolds "$rigScenarioDir/req.4" 'RIG-DESC-MARKER' )" yes
rigAssert "with the same tools bytes as the first"          "$( [ "$( rigToolsOf "$rigScenarioDir/req.1" )" = "$( rigToolsOf "$rigScenarioDir/req.4" )" ] && printf same || printf differ )" same
rigVerdict "an unchanged registration and no failure -- the catalogue is kept, no server re-spawned"

## The negative control, and the reason a green run above cannot be a vacuous one: the
## same canned rounds with no server named and no registration to default to, where
## every probe answers the other way. A mcp.servers.json naming the server is left in
## place: it is output for external tools, and our harness never reads it.
rigStart no-server-named
rm -f "$rigScenarioDir/.local/agents/mcp.servers.index"
printf '{"mcpServers":{"rigmcp":{"command":"%s/bin/rigmcp","args":[]}}}\n' "$rigTmp" > "$rigScenarioDir/.local/agents/mcp.servers.json"
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
rigVerdict "no server named, none registered (a mcp.servers.json naming one ignored) -- nothing declared, nothing spawned, the call refused"

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

## A server that answers a call from a background job, as myx.common's lib_execShStdin
## does: the answer lands after the request line, so stdin must stay open until it has.
rigStart server-answers-late
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
export RIG_MCP_ANSWER_LATE=1
rigRun 0 --mcp-server rigmcp
unset RIG_MCP_ANSWER_LATE
rigAssert "the run ends normally"                      "$rigRunStatus" 0
rigAssert "the server was called once"                 "$( rigServerSaw call )" 1
rigAssert "its late answer is the tool result"         "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT:RIG-ARG-MARKER' )" yes
rigAssert "it is never reported as no answer"          "$( rigHolds "$rigScenarioDir/req.2" 'returned no answer to this call' )" no
rigVerdict "a server answering after the request line -- its answer is waited for, not dropped"

## The resource tools wait on their own ids. The bound is set only so a regression that
## waits for the wrong id fails in seconds rather than hanging this check.
rigStart resources-listed
rigResourceListStream "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
export MDAT_HARNESS_RUN_TIMEOUT=5
rigRun 0 --mcp-server rigmcp
unset MDAT_HARNESS_RUN_TIMEOUT
rigAssert "the run ends normally"                      "$rigRunStatus" 0
rigAssert "the server's resource is the tool result"   "$( rigHolds "$rigScenarioDir/req.2" 'RIG-RESOURCE-MARKER' )" yes
rigAssert "the list was not refused"                   "$( rigHolds "$rigScenarioDir/req.2" 'could not be asked for its resources' )" no
rigVerdict "ListMcpResourcesTool -- its answer is awaited by its own id"

## No run bound unless one is set: the late answer above, now two seconds against none.
rigStart run-bound-unset
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
export RIG_MCP_ANSWER_LATE=1
rigRun 0 --mcp-server rigmcp
rigAssert "the late answer is the tool result"         "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT:RIG-ARG-MARKER' )" yes
rigAssert "nothing was killed for time"                "$( rigHolds "$rigScenarioDir/req.2" 'did not answer within' )" no

## And a set bound still bounds: one second against the same two-second answer.
rigStart run-bound-set
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
export MDAT_HARNESS_RUN_TIMEOUT=1
rigRun 0 --mcp-server rigmcp
unset MDAT_HARNESS_RUN_TIMEOUT RIG_MCP_ANSWER_LATE
rigAssert "the call was killed at the set bound"       "$( rigHolds "$rigScenarioDir/req.2" 'did not answer within 1 seconds' )" yes
rigAssert "and produced no result"                     "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT' )" no
rigVerdict "MDAT_HARNESS_RUN_TIMEOUT -- no bound unset, a set one still kills"

## The payload, which is the whole reason a deny hook can decide anything about an MCP
## call: the hook denies on a value that reaches it ONLY through `tool_input`.
rigStart hook-denies-the-call
rigHookIndex "$rigScenarioDir" '*' "$rigTmp/bin/rigdeny"
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

## The same deny hook placed only in .claude/settings.json: that file is generated for the
## *-native clients, and our harness applies none of it -- the call goes through.
rigStart settings-json-hook-ignored
mkdir -p "$rigScenarioDir/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"%s/bin/rigdeny"}]}]}}\n' "$rigTmp" > "$rigScenarioDir/.claude/settings.json"
rigMcpStream "$rigScenarioDir/res.1" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun 0 --mcp-server rigmcp
rigAssert "the run ends normally"                   "$rigRunStatus" 0
rigAssert "the settings.json hook did not refuse"   "$( rigHolds "$rigScenarioDir/req.2" 'RIG-HOOK-DENIED' )" no
rigAssert "the server was called"                   "$( rigServerSaw call )" 1
rigAssert "its result came back"                    "$( rigHolds "$rigScenarioDir/req.2" 'RIG-MCPRESULT' )" yes
rigVerdict "a hook only in .claude/settings.json -- never applied by our harness"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_MCP: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
