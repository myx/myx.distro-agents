#!/usr/bin/env bash
## Behavioural check of the dispatcher prelude a served request runs. A request is started by the server for one message: its second
## word is the server's process id, never a member, and the front table holds no internal operation. Held:
##   1. a served Read's request loads neither the front table nor the member bring, and the team-data gate writes no temp file
##   2. the gate still names what it names, and only that
##   3. the Read still answers with the file's text
## Red before the change: each request scanned the front table, brought its server's pid as a member, and walked the gate through a here-string.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpRequestPreludeCheck )" || exit 1
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

echo "-- 1. a served request runs no prelude it cannot use --"
rigWire="$( rigCall 900501 "$rigRead" )"
rigCall 900502 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "front table and member bring loaded by the request" \
	"$( LC_ALL=C grep -cE "^\\++[^ ]+ (\\.|source) .?[^ ]*/(AgentsContext\\.FrontTable|AgentsTools\\.MemberWorkspace)\\.include" "$rigTmp/trace" )" 0
rigAssert "gate lines read from a here-string" \
	"$( LC_ALL=C grep -c "AgentsToolsTeamDataGateWrites: read -r writesPattern" "$rigTmp/trace" )" 0

echo "-- 2. the gate names what it names --"
rigAssert "a listed family, a listed name, an operation it does not list" \
	"$( bash -c '. "$1/sh-lib/team-data/AgentsTools.TeamDataGate.include" || exit 9 ; for w in --grooming-open --intern-op-item-rename --session-floor-remove ; do AgentsToolsTeamDataGateWrites "$w" ; printf "%s " "$?" ; done' rig "$rigPkg" )" "0 0 1 "

echo "-- 3. the Read answers --"
rigAssert "the file's text comes back" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP REQUEST PRELUDE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_REQUEST_PRELUDE: OK (%d assertions, offline)\n' "$rigPass"
