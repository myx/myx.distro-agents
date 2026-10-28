#!/usr/bin/env bash
## Behavioural check on sketch 3.1, "one fixed tool list per run": the tool list of an MCP server run is rendered once, when the server starts
## (AgentsTools.McpToolList.include), and every request reads that copy, so the list is the same for the whole run.
## Held:
##   1. the list is there before any request is answered: the server's scratch holds tools.d with its three pieces, after `initialize` alone
##   2. two tools/list answers of one run are byte for byte the same
##   3. the answer comes from that copy and not from a render of its own: a piece changed in tools.d is what the next answer carries, and nothing else changes
##   4. the list is never announced as changed (sketch 3.1; epic S2.1)
## Read OFF THE WIRE, from a real server, as AgentsMcpSecondaryToolCheck does. Offline, and self-contained in its scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "not found at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpToolListFixedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'exec 3>&- 2> /dev/null ; [ -z "${rigPid:-}" ] || kill "$rigPid" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/.local"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigWait(){ ## seconds, test... -- until the test passes
	local waitLeft="$1" ; shift
	while [ "$waitLeft" -gt 0 ] ; do "$@" && return 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigAnswered(){ LC_ALL=C grep -q "\"id\":$1," "$rigTmp/wire" 2> /dev/null ; }

mkfifo "$rigTmp/in" || rigRefuse "no fifo"
MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig bash "$rigTool" --intern-mcp-server --run < "$rigTmp/in" > "$rigTmp/wire" 2> "$rigTmp/err" &
rigPid=$!
exec 3> "$rigTmp/in"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' >&3
rigWait 60 rigAnswered 1
rigScratch="$( ls -d "$rigTmp"/.local/temp/agent-mcp.* 2> /dev/null | head -1 )"
echo "-- 1. rendered when the server starts --"
rigAssert "after initialize alone the scratch holds the list: its three pieces and the mark" \
	"$( for rigOne in served unserved secondary ready ; do [ -f "$rigScratch/tools.d/$rigOne" ] && printf '%s ' "$rigOne" ; done )" "served unserved secondary ready "
echo "-- 2. the same twice --"
printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' >&3
rigWait 60 rigAnswered 2
printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}' >&3
rigWait 60 rigAnswered 3
LC_ALL=C grep '"id":2,' "$rigTmp/wire" | LC_ALL=C sed 's/"id":2,/"id":N,/' > "$rigTmp/list2"
LC_ALL=C grep '"id":3,' "$rigTmp/wire" | LC_ALL=C sed 's/"id":3,/"id":N,/' > "$rigTmp/list3"
rigAssert "two tools/list answers of one run are byte for byte the same, and not empty" "$( cmp -s "$rigTmp/list2" "$rigTmp/list3" && [ -s "$rigTmp/list2" ] && printf same || printf differ )" same
rigAssert "and they carry the floor, the secondary tools and execute" \
	"$( for rigOne in Read AgentDispatcherTools DistroAgentsItems execute ; do LC_ALL=C grep -c "\"name\":\"$rigOne\"" "$rigTmp/list2" ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 1 "
echo "-- 3. the answer is the copy --"
printf '%s' '{"name":"RigSentinelTool","description":"x","inputSchema":{"type":"object","properties":{}}},' > "$rigScratch/tools.d/served"
printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}' >&3
rigWait 60 rigAnswered 4
LC_ALL=C grep '"id":4,' "$rigTmp/wire" > "$rigTmp/list4"
rigAssert "a piece changed in the copy is what the next answer carries: the sentinel in, the floor's Read out, the secondary tools and execute still there" \
	"$( LC_ALL=C grep -c '"name":"RigSentinelTool"' "$rigTmp/list4" ):$( LC_ALL=C grep -c '"name":"Read"' "$rigTmp/list4" ):$( LC_ALL=C grep -c '"name":"AgentDispatcherTools"' "$rigTmp/list4" ):$( LC_ALL=C grep -c '"name":"execute"' "$rigTmp/list4" )" "1:0:1:1"
rigAssert "the run never announces a change of the list: initialize says listChanged false, and no list_changed notification is on the wire" 	"$( LC_ALL=C grep -c '"listChanged":false' "$rigTmp/wire" ):$( LC_ALL=C grep -c 'list_changed' "$rigTmp/wire" )" "1:0"
exec 3>&-
wait "$rigPid" 2> /dev/null ; rigPid=""
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP TOOL LIST FIXED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_TOOL_LIST_FIXED: OK (%d assertions, offline)\n' "$rigPassCount"
