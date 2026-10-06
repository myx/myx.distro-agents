#!/usr/bin/env bash
## Check on the installer-written MCP server index, .local/agents/mcp.servers.index, and
## the harness reading it (AgentsHarnessMcpConfig.include):
##   1. written from a registration full of awkward values -- spaces, quotes, TABs,
##      escaped newlines, backslashes, \u, an empty arg, a number, `=` in env -- every
##      server resolves from the index BYTE FOR BYTE as it resolves from the JSON, read
##      statuses included, and the index path is proven taken by making the JSON readers
##      unreachable while it answers;
##   2. a JSON changed since the index was written is read from the JSON, never wrongly;
##      one that does not read cleanly (a duplicate key, unparseable) gets no index;
##   3. through the real harness, a server is launched with the same argv and env, and
##      its tool answers the same, with the index present and with it absent.
## Offline: a fake curl and a fake stdio server, everything under this rig's own mktemp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsHarnessMcpConfig.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t AgentsHarnessMcpIndexCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

harnessHere="$rigHere"
. "$rigHere/AgentsHarnessMcpConfig.include"

## Everything one resolution published, as one string a comparison can print.
rigResolved(){
	local resolvedIdx=0 resolvedOut
	resolvedOut="cmd[$harnessMcpResCmdRc]=<$harnessMcpResCmd> args[$harnessMcpResArgsRc]"
	while [ "$resolvedIdx" -lt "${#harnessMcpResArgs[@]}" ] ; do
		resolvedOut="$resolvedOut <${harnessMcpResArgs[$resolvedIdx]}>"
		resolvedIdx=$(( resolvedIdx + 1 ))
	done
	resolvedOut="$resolvedOut env[$harnessMcpResEnvRc]"
	resolvedIdx=0
	while [ "$resolvedIdx" -lt "${#harnessMcpResEnvKeys[@]}" ] ; do
		resolvedOut="$resolvedOut <${harnessMcpResEnvKeys[$resolvedIdx]}>=<${harnessMcpResEnvVals[$resolvedIdx]}>"
		resolvedIdx=$(( resolvedIdx + 1 ))
	done
	printf '%sX' "$resolvedOut"
}

echo "-- the index answers as the JSON does --"
rigJson="$rigTmp/unit/mcp.servers.json"
rigIndex="$rigTmp/unit/mcp.servers.index"
mkdir -p "$rigTmp/unit"
printf '%s\n' '{"mcpServers":{' \
	'"tricky":{"command":"/opt/x y/srv\"q","args":["--a b","it'"'"'s \"quoted\"","tab\there","line\nbreak\n","back\\slash \\n","\u00e9\ud83d\ude00","",5,true,null],"env":{"K1":"v = 1","K2":"trail\n\n","BAD-NAME":"x","K3":""}},' \
	'"bare":{"command":"/bin/bare"},' \
	'"argsobj":{"command":"/bin/a","args":{"x":1}},' \
	'"envstr":{"command":"/bin/e","args":[],"env":"nope"},' \
	'"nocmd":{"args":["x"]},' \
	'"relative":{"command":"srv","args":["1"]},' \
	'"x.y":{"command":"/bin/dotted"},' \
	'"myx.distro":{"command":"/bin/self","args":["--intern-mcp-server","--run"],"env":{"MMDAPP":"/w"}}' \
	'}}' > "$rigJson"
AgentsHarnessMcpIndexWrite "$rigJson" "$rigIndex" || rigRefuse "the index writer failed outright"
rigAssert "an index is written for a clean registration" "$( [ -f "$rigIndex" ] && printf yes || printf no )" yes
rigAssert "it carries mode 0644" "$( ls -l "$rigIndex" | cut -c1-10 )" "-rw-r--r--"
rigAssert "no temp is left beside it" "$( ls "$rigTmp/unit" | LC_ALL=C grep -c 'tmp\|err' )" 0
rigAssert "it is usable against that JSON" "$( AgentsHarnessMcpIndexUsable "$rigJson" && printf yes || printf no )" yes

AgentsHarnessMcpKeysJson "$rigJson"
rigWantKeys="$harnessMcpResKeysRc:$harnessMcpResKeys"
rigNames=()
while IFS= read -r rigName ; do rigNames+=( "$rigName" ) ; done <<< "$harnessMcpResKeys"
rigNames+=( "not-registered" )
rigWant=()
for rigName in "${rigNames[@]}" ; do
	AgentsHarnessMcpResolveJson "$rigName" "$rigJson" 2>/dev/null
	rigWant+=( "$( rigResolved )" )
done
## The JSON readers made unreachable: an answer now can only have come from the index.
agentsMcpConfigHere="$rigTmp/no-readers-here"
AgentsHarnessMcpKeys "$rigJson"
rigAssert "the server names, from the index" "$harnessMcpResKeysRc:$harnessMcpResKeys" "$rigWantKeys"
rigIdx=0
for rigName in "${rigNames[@]}" ; do
	if [ "$rigName" != "not-registered" ] ; then
		AgentsHarnessMcpResolve "$rigName" "$rigJson" 2>/dev/null
		rigAssert "[$rigName] from the index" "$( rigResolved )" "${rigWant[$rigIdx]}"
	fi
	rigIdx=$(( rigIdx + 1 ))
done
agentsMcpConfigHere="$rigHere"
## A name the index does not hold is the JSON's to answer, rc 3 included.
AgentsHarnessMcpResolve "not-registered" "$rigJson" 2>/dev/null
rigAssert "[not-registered] falls to the JSON" "$( rigResolved )" "${rigWant[$(( ${#rigNames[@]} - 1 ))]}"
rigAssert "the tricky args survive whole" "$( AgentsHarnessMcpResolve tricky "$rigJson" ; printf '%s|' "${harnessMcpResArgs[@]}" )" "--a b|it's \"quoted\"|tab	here|line
break|back\\slash \\n|é😀||5|true||"

echo "-- a changed or unclean JSON is never read from a stale index --"
printf '%s\n' '{"mcpServers":{"tricky":{"command":"/changed","args":["new"]}}}' > "$rigJson"
rigAssert "a JSON changed since makes the index unusable" "$( AgentsHarnessMcpIndexUsable "$rigJson" && printf yes || printf no )" no
AgentsHarnessMcpResolve tricky "$rigJson" 2>/dev/null
rigAssert "and the JSON's own new value is what resolves" "$harnessMcpResCmd|${harnessMcpResArgs[*]}" "/changed|new"
rm -f "$rigJson"
rigAssert "a JSON removed makes it unusable too" "$( AgentsHarnessMcpIndexUsable "$rigJson" && printf yes || printf no )" no
AgentsHarnessMcpIndexWrite "$rigJson" "$rigIndex"
rigAssert "no JSON leaves no index" "$( [ -f "$rigIndex" ] && printf yes || printf no )" no
printf '%s\n' '{"mcpServers":{"a":{"command":"/one"},"a":{"command":"/two"}}}' > "$rigJson"
AgentsHarnessMcpIndexWrite "$rigJson" "$rigIndex"
rigAssert "a duplicate key -- the reader warns -- leaves no index" "$( [ -f "$rigIndex" ] && printf yes || printf no )" no
printf '%s\n' '{"mcpServers":{"a":' > "$rigJson"
AgentsHarnessMcpIndexWrite "$rigJson" "$rigIndex"
rigAssert "an unparseable JSON leaves no index" "$( [ -f "$rigIndex" ] && printf yes || printf no )" no
printf '%s\n' '{"mcpServers":{"a":{"command":"/one"}}}' > "$rigJson"
AgentsHarnessMcpIndexWrite "$rigJson" "$rigIndex"
printf 'myx.distro mcp.servers.index 1\nsource\tpresent:x\n' > "$rigIndex"
rigAssert "an index cut short is never used" "$( AgentsHarnessMcpIndexUsable "$rigJson" && printf yes || printf no )" no

echo "-- through the harness: the same launch, index or not --"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
cp "$rigTest/check-fixtures/harness-mcp-check.mcp-server.test.sh" "$rigTmp/bin/rigmcp" || rigRefuse "the fake server fixture is missing"
cp "$rigTest/check-fixtures/harness-mcp-index-check.launch-recorder.test.sh" "$rigTmp/bin/rigrec" || rigRefuse "the launch recorder fixture is missing"
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/rigmcp" "$rigTmp/bin/rigrec"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
export HARNESS_PROVIDER_NAME="mcp-index-check rig" HARNESS_SELF_NAME="AgentsHarnessMcpIndexCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-mcp-index-check.invalid/v1/chat/completions" HARNESS_HOST="harness-mcp-index-check.invalid"
export HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential"

rigLaunch(){ ## scenario name, with-index|without-index
	local launchDir="$rigTmp/$1"
	mkdir -p "$launchDir/.local/agents"
	printf '0' > "$launchDir/round"
	printf '{"mcpServers":{"rigrec":{"command":"%s/bin/rigrec","args":["--a b","it'"'"'s \\"q\\"","tab\\there","nl\\n","back\\\\slash",""],"env":{"RIG_MCP_PROBE":"v = 1 \\"x\\"","RIG_MCP_OTHER":"trail\\n","BAD-NAME":"dropped"}}}}\n' "$rigTmp" > "$launchDir/.local/agents/mcp.servers.json"
	[ "$2" = without-index ] || AgentsHarnessMcpIndexWrite "$launchDir/.local/agents/mcp.servers.json" "$launchDir/.local/agents/mcp.servers.index"
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"mcp__rigrec__ping","arguments":"{\\"word\\":\\"RIG-ARG-MARKER\\"}"}}]}}]}\n' > "$launchDir/res.1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' >> "$launchDir/res.1"
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-FINAL-MARKER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$launchDir/res.2"
	RIG_SCENARIO="$launchDir" MMDAPP="$launchDir" MDAT_HARNESS_CONTEXT_TOKENS=0 \
		"$rigHarness" --access-root "$launchDir" RIG-TASK-MARKER > "$launchDir/out" 2> "$launchDir/err" || :
}
rigLaunch launch-json without-index
rigLaunch launch-index with-index
rigAssert "the index run had an index to read"          "$( [ -f "$rigTmp/launch-index/.local/agents/mcp.servers.index" ] && printf yes || printf no )" yes
rigAssert "both runs answered"                          "$( cat "$rigTmp/launch-json/out" ):$( cat "$rigTmp/launch-index/out" )" "RIG-FINAL-MARKER:RIG-FINAL-MARKER"
rigAssert "the server was launched twice in each"       "$( LC_ALL=C grep -c '^--$' "$rigTmp/launch-json/launch.log" ):$( LC_ALL=C grep -c '^--$' "$rigTmp/launch-index/launch.log" )" "2:2"
rigAssert "with the same argv and env, byte for byte"   "$( cat "$rigTmp/launch-index/launch.log" )" "$( cat "$rigTmp/launch-json/launch.log" )"
rigAssert "the awkward args arrived whole"              "$( sed -n 2,7p "$rigTmp/launch-index/launch.log" | tr '\n' '|' )" "arg[5]=--a b|arg[8]=it's \"q\"|arg[8]=tab	here|arg[2]=nl|arg[10]=back\\slash|arg[0]=|"
rigAssert "the tool answered the same"                  "$( LC_ALL=C grep -o 'RIG-MCPRESULT:[A-Z-]*' "$rigTmp/launch-index/req.2" )" "$( LC_ALL=C grep -o 'RIG-MCPRESULT:[A-Z-]*' "$rigTmp/launch-json/req.2" )"
rigAssert "the bad env name was dropped, saying so, in both" "$( LC_ALL=C grep -c 'dropped the `env` entry named' "$rigTmp/launch-json/err" ):$( LC_ALL=C grep -c 'dropped the `env` entry named' "$rigTmp/launch-index/err" )" "2:2"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP INDEX CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsHarnessMcpConfig.include or its callers -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_MCP_INDEX: OK (%d assertions: index == JSON for every server, stale or unclean JSON never indexed or read from one, same launch through the harness, offline)\n' "$rigPass"
