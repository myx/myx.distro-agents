#!/usr/bin/env bash
## Behavioural check of a served call's own processes (code-craft: no process per call where a builtin answers). One request of a
## served Read, the second on the same server scratch so the tool list is the kept one, through --intern-mcp-request; cat, tr and rm
## counted by the file that calls them, as shell functions exported to the request, so the count costs no fork:
##   1. the request reads its message and the kept list, and joins names, with no cat and no tr
##   2. control: the answer carries the file's text
## Red before the change: four cat and a tr a call: the message, and the three pieces of the kept list.
## Offline: a rig file read through the real request; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpRequestForkCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigMsg='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh"}}}'
rigCall(){ ## seq: one served Read, its wire on stdout
	printf '%s\n' "$rigMsg" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" \
		"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
}
rigCall 900091 > /dev/null
rigCount="$rigTmp/count.log" ; : > "$rigCount"
cat(){ printf '%s cat\n' "${BASH_SOURCE[1]##*/}" >> "$RIG_COUNT" ; command cat "$@" ; }
tr(){ printf '%s tr\n' "${BASH_SOURCE[1]##*/}" >> "$RIG_COUNT" ; command tr "$@" ; }
rm(){ printf '%s rm\n' "${BASH_SOURCE[1]##*/}" >> "$RIG_COUNT" ; command rm "$@" ; }
export -f cat tr rm ; export RIG_COUNT="$rigCount"
rigWire="$( rigCall 900092 )"
unset -f cat tr rm
rigOf(){ LC_ALL=C grep -cE "^AgentsTools\.(InternMcpRequest|McpToolList)\.include $1\$" "$rigCount" ; }

echo "-- 1. no cat and no tr --"
rigAssert "cat and tr of the request and its tool list" "$( rigOf cat ) $( rigOf tr )" "0 0"
echo "-- 2. control: the answer --"
rigAssert "the answer carries the file's text" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:900}" ;; esac )" carried

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP REQUEST FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_REQUEST_FORK: OK (%d assertions, offline)\n' "$rigPass"
