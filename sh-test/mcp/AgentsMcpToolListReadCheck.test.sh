#!/usr/bin/env bash
## Behavioural check of the tool list read only where it is answered. The list is rendered once as the server starts, into tools.d;
## its served piece alone is 118 KB. tools/list answers with it whole; a tools/call needs only whether its own name is served. Held:
##   1. a served Read loads neither the list's include nor the unserved include, and reads no piece of the list
##   2. the Read still answers with the file's text
##   3. tools/list still names a served tool, an unserved one, a secondary one, RootSession and execute
## Red before the change: every request read all three pieces, byte by byte, and built the whole list.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpToolListReadCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigCall(){ ## seq, message, trace file or empty: one request, its wire on stdout
	if [ -n "${3:-}" ] ; then
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}:${FUNCNAME[0]:-main}: ' \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> "$3"
	else
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER MDAT_SPAWN_SESSION_ID="" \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
	fi
}
rigRead='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'

echo "-- 1. a served Read reads none of the list --"
rigWire="$( rigCall 900501 "$rigRead" )"
rigCall 900502 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "the list's include and the unserved include loaded by the Read" \
	"$( LC_ALL=C grep -cE "^\++[^ ]+ (\.|source) '?[^ ]*/(AgentsTools\.McpToolList|AgentsHarnessUnserved)\.include" "$rigTmp/trace" )" 0
rigAssert "pieces of the list read into the Read" \
	"$( LC_ALL=C grep -cE '^\++[^ ]+ (read -r -d .. )?mcp(ServedTools|UnservedEntries|SecondaryTools)Json=?' "$rigTmp/trace" )" 0

echo "-- 2. the Read answers --"
rigAssert "the file's text comes back" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried

echo "-- 3. tools/list names every kind --"
rigList="$( rigCall 900503 '{"jsonrpc":"2.0","id":8,"method":"tools/list"}' )"
rigNamed=""
for rigName in Read Bash DistroAgentsTesting RootSession execute ; do
	case "$rigList" in (*"{\"name\":\"$rigName\","*) rigNamed="$rigNamed $rigName" ;; esac
done
rigAssert "names the list carries" "$rigNamed" " Read Bash DistroAgentsTesting RootSession execute"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP TOOL LIST READ CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_TOOL_LIST_READ: OK (%d assertions, offline)\n' "$rigPass"
