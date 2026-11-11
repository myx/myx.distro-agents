#!/usr/bin/env bash
## AgentsMcpServerEndsRequestsCheck -- no request outlives the myx.distro MCP server (epic S12.3): a request handler still in
## flight, and what it started, ends with the server (AgentsToolsMcpServerEndInflight, AgentsTools.InternMcpServer.include), as
## the myx.common server ends its own (AgentsMcpServerEndsHandlersCheck). Run rather than read: a real server is started on a
## fifo, given `initialize` and one `execute` call that sleeps, then given TERM, and the sleeping process is counted either side.
## Held:
##   1. the server answers `initialize` and the sleeping command runs, so the run is a real one and not an empty pass
##   2. after TERM the sleeping command is gone and so is the server
##   3. the in-flight record names the sleeping handler with when it began, the form the end reads, and the finished
##      initialize handler took its own record with it
##   4. control: a second server killed outright (KILL, so its end never runs) leaves its sleeping command running, which is
##      what the end is for; that leftover is then ended by this check, by the pid read from the process list and noted first
## Red: a server whose end removes its scratch alone leaves the handler and its sleep running after TERM.
## Offline: one temp tree under the workspace's temp folder, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigPasses=0 ; rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsMcpServerEndsRequestsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
mkdir -p "$rigTmp/ws/.local/temp" "$rigTmp/ws/.local/agents" || exit 1
rigMark=617
## The sleep is the marker: counted by its command line, the one reading, and ended by the server's end, never by this check.
rigCount(){ ps -ax -o command= 2> /dev/null | LC_ALL=C grep -F "sleep $rigMark" | LC_ALL=C grep -v -F 'grep -F' | wc -l | tr -d ' ' ; }
trap 'rm -rf -- "$rigTmp"' EXIT

echo "-- 1. a real run: initialize answered, the sleeping command running --"
mkfifo "$rigTmp/in" || exit 1
## The server is exec'd in the subshell, so the pid kept is the server's own and the TERM below reaches it, not a shell around it.
( cd "$rigTmp/ws" && exec env -u MDAT_DATA_ROOT MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=just-agents bash "$rigTool" --intern-mcp-server --run ) < "$rigTmp/in" > "$rigTmp/out" 2> "$rigTmp/err" &
rigServer=$!
rigProcNote "$rigServer"
exec 3> "$rigTmp/in"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' >&3
printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"execute\",\"arguments\":{\"command\":\"sleep $rigMark\"}}}" >&3
rigWaited=0
while [ "$rigWaited" -lt 20 ] && [ "$( rigCount )" = 0 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "the server answered initialize"                 "$( LC_ALL=C grep -c -F '"id":1,"result"' "$rigTmp/out" )" 1
rigAssert "the sleeping command runs under a request"       "$( rigCount )" 1
rigInflight="$( ls "$rigTmp"/ws/.local/temp/agent-mcp.*/inflight/ 2> /dev/null | wc -l | tr -d ' ' )"
rigAssert "the sleeping request alone is in flight, pid and start" "$rigInflight:$( cat "$rigTmp"/ws/.local/temp/agent-mcp.*/inflight/2 2> /dev/null | LC_ALL=C awk '{ print ( $1 ~ /^[0-9]+$/ && $2 != "" ) ? "pid-and-start" : "other" }' )" "1:pid-and-start"

echo "-- 2. the server ends: the handler and its sleep end with it --"
rigProcSignal TERM "$rigServer"
rigWaited=0
while [ "$rigWaited" -lt 10 ] && kill -0 "$rigServer" 2> /dev/null ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
exec 3>&-
sleep 1
rigAssert "the server is gone"                              "$( kill -0 "$rigServer" 2> /dev/null && printf alive || printf gone )" gone
rigAssert "the sleeping command is gone with it"            "$( rigCount )" 0
rigAssert "the scratch root is gone"                        "$( ls -d "$rigTmp"/ws/.local/temp/agent-mcp.* 2> /dev/null | wc -l | tr -d ' ' )" 0

echo "-- 3. control: a server killed without its end leaves its sleeping command running --"
## The same run with another marker, and KILL instead of TERM: no trap runs, so the end never does, and the handler's sleep is
## left. That is the red this check would show without AgentsToolsMcpServerEndInflight, made visible once. The leftover is ended
## here, by the pid the process list gives now, noted with its start first (rig-processes), never by a number kept from before.
rigMark2=623
rigCount2(){ ps -ax -o command= 2> /dev/null | LC_ALL=C grep -F "sleep $rigMark2" | LC_ALL=C grep -v -F 'grep -F' | wc -l | tr -d ' ' ; }
mkfifo "$rigTmp/in2" || exit 1
( cd "$rigTmp/ws" && exec env -u MDAT_DATA_ROOT MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=just-agents bash "$rigTool" --intern-mcp-server --run ) < "$rigTmp/in2" > "$rigTmp/out2" 2> "$rigTmp/err2" &
rigServer2=$!
rigProcNote "$rigServer2"
exec 3> "$rigTmp/in2"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' >&3
printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"execute\",\"arguments\":{\"command\":\"sleep $rigMark2\"}}}" >&3
rigWaited=0
while [ "$rigWaited" -lt 20 ] && [ "$( rigCount2 )" = 0 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "control: the second server's sleeping command runs"   "$( rigCount2 )" 1
rigProcSignal KILL "$rigServer2"
rigWaited=0
while [ "$rigWaited" -lt 10 ] && kill -0 "$rigServer2" 2> /dev/null ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
exec 3>&-
sleep 1
rigAssert "control: the second server is gone"                   "$( kill -0 "$rigServer2" 2> /dev/null && printf alive || printf gone )" gone
rigAssert "control: without the end, the sleeping command is left running" "$( rigCount2 )" 1
rigLeft="$( ps -ax -o pid=,command= 2> /dev/null | LC_ALL=C grep -F "sleep $rigMark2" | LC_ALL=C grep -v -F 'grep -F' | LC_ALL=C awk '{ print $1 }' )"
[ -z "$rigLeft" ] || { rigProcNote $rigLeft ; rigProcSignal TERM $rigLeft ; }
sleep 1
rigAssert "control: the leftover is ended by this check"         "$( rigCount2 )" 0

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MCP SERVER ENDS REQUESTS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a request handler, and what it runs, outlives the MCP server that started it" >&2
	echo "  fix:  AgentsToolsMcpServerEndInflight and the inflight record in sh-lib/mcp/AgentsTools.InternMcpServer.include" >&2
	exit 1
fi
echo "MCP_SERVER_ENDS_REQUESTS: OK ($rigPasses assertions, offline)"
