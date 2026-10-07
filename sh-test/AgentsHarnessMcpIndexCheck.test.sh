#!/usr/bin/env bash
## Check on the installer-written MCP server index, .local/agents/mcp.servers.index, and
## the harness reading it (AgentsHarnessMcpConfig.include). Our harness reads only our own
## registration -- the index, or the same composed from our primary sources -- and never
## mcp.servers.json, .mcp.json or .vscode/mcp.json, which are outputs for external tools:
##   1. the primary composition: a workspace with myx.common and myx.distro installed
##      registers both, with the installer's paths, args and env; one with neither, none;
##      the index the installer writes resolves every server BYTE FOR BYTE as the
##      composition does, and is proven taken by making the composition unreachable;
##   2. awkward values -- spaces, quotes, TABs, newlines, backslashes, an empty arg, `=`
##      in env -- survive the index whole;
##   3. an index of another workspace, another writer, another version or cut short is
##      never used, and the composition answers instead; a mcp.servers.json is never read;
##   4. through the real harness, a server is launched with the same argv and env, and
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
rigTmp="$( cd "$rigTmp" && pwd )"

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
## Every registered server of $MMDAPP, resolved, plus a name nobody registers.
rigAll(){
	local allName allOut=""
	AgentsHarnessMcpKeys
	allOut="keys[$harnessMcpResKeysRc]=<$harnessMcpResKeys>"
	while IFS= read -r allName ; do
		[ -n "$allName" ] || continue
		AgentsHarnessMcpResolve "$allName"
		allOut="$allOut|$allName:$( rigResolved )"
	done <<< "$harnessMcpResKeys"
	AgentsHarnessMcpResolve "not-registered"
	printf '%s|not-registered:%s' "$allOut" "$( rigResolved )"
}
rigInstall(){ ## workspace, executable for both server scripts (or empty for none)
	local installCommon="$1/.local/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib"
	local installDistro="$1/.local/myx/myx.distro-agents/sh-scripts"
	mkdir -p "$1/.local/agents" "$installCommon" "$installDistro"
	[ -n "$2" ] || return 0
	cp "$2" "$installCommon/agentMcpServer.Common" && cp "$2" "$installDistro/DistroAgentsTools.fn.sh" || rigRefuse "the rig's server stand-ins could not be installed"
	chmod +x "$installCommon/agentMcpServer.Common" "$installDistro/DistroAgentsTools.fn.sh"
}

echo "-- the primary composition, and the index the installer writes from it --"
rigWs="$rigTmp/unit ws"
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/stand-in"
rigInstall "$rigWs" "$rigTmp/stand-in"
MMDAPP="$rigWs" ; harnessMcpLoadedFor=""
rigComputed="$( rigAll )"
AgentsHarnessMcpKeys
rigAssert "with nothing indexed, the servers are computed" "$harnessMcpFrom" "the servers this workspace's installer registers, computed"
rigAssert "both servers, as the installer registers them" "$rigComputed" \
	"keys[0]=<myx.distro
myx.common>|myx.distro:cmd[0]=<$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh> args[0] <--intern-mcp-server> <--run> env[0] <MMDAPP>=<$rigWs>X|myx.common:cmd[0]=<$rigWs/.local/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/agentMcpServer.Common> args[0] <--run> env[0] <MMDAPP>=<$rigWs>X|not-registered:cmd[3]=<> args[0] env[0]X"
AgentsHarnessMcpIndexWrite "$rigWs" || rigRefuse "the index writer failed outright"
rigAssert "an index is written" "$( [ -f "$rigWs/.local/agents/mcp.servers.index" ] && printf yes || printf no )" yes
rigAssert "it carries mode 0644" "$( ls -l "$rigWs/.local/agents/mcp.servers.index" | cut -c1-10 )" "-rw-r--r--"
rigAssert "no temp is left beside it" "$( ls "$rigWs/.local/agents" | LC_ALL=C grep -c 'tmp' )" 0
## The composition made unreachable: an answer now can only have come from the index.
AgentsHarnessMcpServersPrimary(){ AgentsHarnessMcpSpecReset ; AgentsHarnessMcpSpecAdd poisoned /bin/false 0 ; }
harnessMcpLoadedFor=""
rigAssert "the index answers exactly as the composition did" "$( rigAll )" "$rigComputed"
AgentsHarnessMcpKeys
rigAssert "and says it is the index" "$harnessMcpFrom" "$rigWs/.local/agents/mcp.servers.index"
## A mcp.servers.json beside it, naming another server, is never read.
printf '{"mcpServers":{"foreign":{"command":"/bin/foreign"}}}\n' > "$rigWs/.local/agents/mcp.servers.json"
harnessMcpLoadedFor=""
rigAssert "a mcp.servers.json is never read" "$( rigAll )" "$rigComputed"
unset -f AgentsHarnessMcpServersPrimary
. "$rigHere/AgentsHarnessMcpConfig.include"

rigEmpty="$rigTmp/empty"
rigInstall "$rigEmpty" ""
MMDAPP="$rigEmpty" ; harnessMcpLoadedFor=""
rigAssert "a workspace with no server installed registers none" "$( rigAll )" "keys[0]=<>|not-registered:cmd[3]=<> args[0] env[0]X"

echo "-- awkward values survive the index whole --"
MMDAPP="$rigWs" ; harnessMcpLoadedFor=""
AgentsHarnessMcpSpecReset
AgentsHarnessMcpSpecAdd "tricky" "/opt/x y/srv\"q" 4 K1 "v = 1" K2 $'trail\n\n' "BAD-NAME" x K3 "" \
	"--a b" "it's \"quoted\"" $'tab\there' $'line\nbreak\n' 'back\slash \n' "é😀" "" 5
AgentsHarnessMcpSpecAdd "x.y" "/bin/dotted" 0
AgentsHarnessMcpIndexWrite "$rigWs" use-spec || rigRefuse "the index writer failed on the awkward set"
AgentsHarnessMcpResolve tricky
rigAssert "the tricky command" "$harnessMcpResCmd" "/opt/x y/srv\"q"
rigAssert "the tricky args, whole" "$( printf '%s|' "${harnessMcpResArgs[@]}" )" "--a b|it's \"quoted\"|tab	here|line
break
|back\\slash \\n|é😀||5|"
rigTricky="$( rigResolved )"
rigAssert "the tricky env, whole" "env${rigTricky##*env}" "env[0] <K1>=<v = 1> <K2>=<trail

> <BAD-NAME>=<x> <K3>=<>X"
AgentsHarnessMcpKeys
rigAssert "both names, in order" "$harnessMcpResKeys" "tricky
x.y"

echo "-- an index that does not vouch for this workspace and writer is never used --"
AgentsHarnessMcpIndexWrite "$rigWs" || rigRefuse "the index writer failed outright"
rigIndexed="$( harnessMcpLoadedFor="" ; rigAll )"
rigIndexCase(){ ## what, transform (sed program)
	sed "$2" "$rigWs/.local/agents/mcp.servers.index" > "$rigTmp/idx" && cp "$rigTmp/idx" "$rigWs/.local/agents/mcp.servers.index"
	harnessMcpLoadedFor=""
	AgentsHarnessMcpServersPrimary(){ AgentsHarnessMcpSpecReset ; AgentsHarnessMcpSpecAdd computed-instead /bin/true 0 ; }
	AgentsHarnessMcpKeys
	rigAssert "$1: computed instead" "$harnessMcpResKeys" "computed-instead"
	unset -f AgentsHarnessMcpServersPrimary
	. "$rigHere/AgentsHarnessMcpConfig.include"
	AgentsHarnessMcpIndexWrite "$rigWs"
}
rigIndexCase "another workspace's index" 's/workspace=/workspace=\/elsewhere/'
rigIndexCase "another writer's index" 's/code=[0-9]*/code=1/'
rigIndexCase "a version 1 index" '1s/ 2$/ 1/'
rigIndexCase "an index cut short" '$d'
harnessMcpLoadedFor=""
rigAssert "control: rewritten, it is used again" "$( rigAll )" "$rigIndexed"

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

## One workspace, its myx.common the launch recorder (which then behaves as the rig
## server); the myx.distro stand-in is never spawned -- the harness excludes itself.
rigLaunchWs="$rigTmp/launch"
rigInstall "$rigLaunchWs" "$rigTmp/stand-in"
rigLaunchCommon="$rigLaunchWs/.local/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib"
cp "$rigTmp/bin/rigrec" "$rigLaunchCommon/agentMcpServer.Common" && cp "$rigTmp/bin/rigmcp" "$rigLaunchCommon/rigmcp" || rigRefuse "the launch recorder could not be installed"
chmod +x "$rigLaunchCommon/agentMcpServer.Common" "$rigLaunchCommon/rigmcp"
rigLaunch(){ ## label, with-index|without-index
	rm -f "$rigLaunchWs/launch.log" "$rigLaunchWs/.local/agents/mcp.servers.index"
	printf '0' > "$rigLaunchWs/round"
	[ "$2" = without-index ] || ( MMDAPP="$rigLaunchWs" ; AgentsHarnessMcpIndexWrite "$rigLaunchWs" ) || rigRefuse "the launch index could not be written"
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"mcp__myx_common__ping","arguments":"{\\"word\\":\\"RIG-ARG-MARKER\\"}"}}]}}]}\n' > "$rigLaunchWs/res.1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' >> "$rigLaunchWs/res.1"
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-FINAL-MARKER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigLaunchWs/res.2"
	RIG_SCENARIO="$rigLaunchWs" MMDAPP="$rigLaunchWs" MDAT_HARNESS_CONTEXT_TOKENS=0 \
		"$rigHarness" --access-root "$rigLaunchWs" RIG-TASK-MARKER > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
	cp "$rigLaunchWs/launch.log" "$rigTmp/$1.log" 2>/dev/null || : > "$rigTmp/$1.log"
	cp "$rigLaunchWs/req.2" "$rigTmp/$1.req2" 2>/dev/null || : > "$rigTmp/$1.req2"
}
rigLaunch launch-computed without-index
rigLaunch launch-index with-index
rigAssert "both runs answered"                          "$( cat "$rigTmp/launch-computed.out" ):$( cat "$rigTmp/launch-index.out" )" "RIG-FINAL-MARKER:RIG-FINAL-MARKER"
rigAssert "the server was launched twice in each"       "$( LC_ALL=C grep -c '^--$' "$rigTmp/launch-computed.log" ):$( LC_ALL=C grep -c '^--$' "$rigTmp/launch-index.log" )" "2:2"
rigAssert "with the same argv and env, byte for byte"   "$( cat "$rigTmp/launch-index.log" )" "$( cat "$rigTmp/launch-computed.log" )"
rigAssert "the installer's argv"                        "$( sed -n 1,2p "$rigTmp/launch-index.log" | tr '\n' '|' )" "argc=1|arg[5]=--run|"
rigAssert "the tool answered the same"                  "$( LC_ALL=C grep -o 'RIG-MCPRESULT:[A-Z-]*' "$rigTmp/launch-index.req2" )" "$( LC_ALL=C grep -o 'RIG-MCPRESULT:[A-Z-]*' "$rigTmp/launch-computed.req2" )"
rigAssert "the tool did answer"                         "$( LC_ALL=C grep -c 'RIG-MCPRESULT:RIG-ARG-MARKER' "$rigTmp/launch-index.req2" )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP INDEX CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsHarnessMcpConfig.include or its callers -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_MCP_INDEX: OK (%d assertions: index == primary composition for every server, a foreign or stale index never used, mcp.servers.json never read, same launch through the harness, offline)\n' "$rigPass"
