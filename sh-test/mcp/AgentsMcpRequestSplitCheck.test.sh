#!/usr/bin/env bash
## Behavioural check of the request's operations as files of their own (code-craft: one operation, one file; a multi-operation file is a
## compact dispatcher whose branch sources the operation's own file). The request include is parsed by every served call; the execute
## tool and the secondary tools are operations of their own, parsed only by the call that runs them. Held:
##   1. the request include holds neither operation's code, and loads each in its own branch
##   2. a served Read parses neither operation's file
##   3. an execute call still answers, through its own file
##   4. a secondary call still answers, through its own file
## Red before the change: both operations were the request include's, parsed by every served call.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpRequestSplitCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigMcp="$rigPkg/sh-lib/mcp"
rigCall(){ ## seq, message, trace file or empty: one request, its wire on stdout
	if [ -n "${3:-}" ] ; then
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}: ' \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> "$3"
	else
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
	fi
}

echo "-- 1. the request include is a dispatcher of these two --"
rigAssert "operation code the request include holds" \
	"$( LC_ALL=C grep -cE '^[[:space:]]*(AgentsMcpExecuteRun|AgentsMcpSecondaryRun|AgentsMcpMemberOptionSet)\(\)|^[[:space:]]*elif \[ -n "\$mcpJob" \]' "$rigMcp/AgentsTools.InternMcpRequest.include" )" 0
rigAssert "and loads each operation's file" \
	"$( LC_ALL=C grep -cE 'AgentsTools\.InternMcpRequest(Execute|Secondary)\.include' "$rigMcp/AgentsTools.InternMcpRequest.include" )" 2

echo "-- 2. a served Read parses neither --"
rigRead='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'
rigCall 900101 "$rigRead" > /dev/null
rigCall 900102 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "operation files a Read parses" "$( LC_ALL=C grep -cE "^\++[^ ]+ (\.|source) '?[^ ]*/AgentsTools\.InternMcpRequest(Execute|Secondary)\.include" "$rigTmp/trace" )" 0

echo "-- 3. an execute call answers --"
rigWire="$( rigCall 900103 '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"execute","arguments":{"command":"echo rig-split-echo"}}}' )"
rigAssert "the script's output comes back" "$( case "$rigWire" in (*rig-split-echo*) echo back ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" back

echo "-- 4. a secondary call answers --"
rigWire="$( rigCall 900104 '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"DistroAgentsTesting","arguments":{"operation":"--help-syntax"}}}' )"
rigAssert "the operation's syntax comes back" "$( case "$rigWire" in (*'syntax: DistroAgentsTesting'*) echo back ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" back

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP REQUEST SPLIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_REQUEST_SPLIT: OK (%d assertions, offline)\n' "$rigPass"
