#!/usr/bin/env bash
## Behavioural check on the MCP server making `execute` a task underneath (epic S20; sh-lib/mcp/AgentsTools.InternMcpRequest.include,
## sh-lib/session/AgentsTools.ToolTask.include). Drives a real `--intern-mcp-server --run` over stdio with a session in its environment. Held:
##   1. a quick execute returns its own output, as ever, with no task left behind
##   2. an execute whose own `timeout` passes returns early with TASK-ID=process-N, the script going on
##   3. `background: true` returns at once with TASK-ID=process-N
##   4. `timeout` with `timeout_action: kill` ends the script and says so, as an error
##   5. a non-zero exit is still an error with its exit code
##   6. `job=process-N` points at the task tools instead of failing as a bad job id
##   7. the tool list declares timeout_action and the other arguments
## Offline: a rig workspace under the scratch of this one; no endpoint, no credential, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
[ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] || { echo "⛔ ERROR: no myx.distro-agents at $rigOrigin -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ] || { echo "⛔ ERROR: the tool task include is not in the package -- refusing to report a result" >&2 ; exit 1 ; }
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpToolTaskCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )"
rigSession="rig-mcp-task"
rigProc="$rigTmp/ws/.local/agents/sessions/$rigSession/processes"
mkdir -p "$rigTmp/ws/.local/temp"
## Whatever a returned task left running is ended on the way out: every pid its handles name, and its group, and anything started under the rig.
rigReap(){
	local reapFile reapPid
	for reapFile in "$rigProc"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	pkill -TERM -f "$rigTmp" 2> /dev/null || :
	sleep 0.3
}
trap 'rigReap ; rm -rf -- "$rigTmp"' EXIT
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## id, arguments JSON of execute
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"execute","arguments":%s}}\n' "$1" "$2"
}
## One server run with every request below, and the replies in files named by id.
{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"rig","version":"1"}}}' \
	'{"jsonrpc":"2.0","method":"notifications/initialized"}' \
	'{"jsonrpc":"2.0","id":9,"method":"tools/list"}'
  rigCall 2 '{"command":"echo hi"}'
  rigCall 3 '{"command":"sleep 20; echo late","timeout":1}'
  rigCall 4 '{"command":"sleep 21","background":true}'
  rigCall 5 '{"command":"echo partial; sleep 22","timeout":1,"timeout_action":"kill"}'
  rigCall 6 '{"command":"exit 3"}'
  rigCall 7 '{"job":"process-1"}'
  sleep 9 ; } \
	| ( cd "$rigTmp/ws" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_TOOL_TASK_CEILING=60 \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-server --run 2> "$rigTmp/server.err" ) \
	> "$rigTmp/replies" || :
rigReply(){ ## id -- the reply line of that request
	LC_ALL=C grep "\"id\":$1[,}]" "$rigTmp/replies" | head -1
}
rigHolds(){ ## id, fixed text
	rigReply "$1" | LC_ALL=C grep -q -F -- "$2" && printf yes || printf no
}
rigIsError(){ rigReply "$1" | LC_ALL=C sed -n 's/.*"isError":\([a-z]*\).*/\1/p' | head -1 ; }
[ -s "$rigTmp/replies" ] || { echo "⛔ ERROR: the server gave no reply -- refusing to report a result" >&2 ; exit 1 ; }

echo "-- 1. a quick execute --"
rigAssert "it returns its output, no task" "$( rigHolds 2 'hi' ):$( rigHolds 2 'TASK-ID' ):$( rigIsError 2 )" "yes:no:false"

echo "-- 2. the caller's timeout --"
rigAssert "it returns early as a task, naming the timeout" "$( rigHolds 3 'TASK-ID=process-' ):$( rigHolds 3 'your timeout of 1s passed' ):$( rigIsError 3 )" "yes:yes:false"

echo "-- 3. background --"
rigAssert "it returns at once as a task" "$( rigHolds 4 'TASK-ID=process-' ):$( rigHolds 4 'you asked for background' )" "yes:yes"

echo "-- 4. timeout_action kill --"
rigAssert "it ends the script at the timeout and says so, as an error" "$( rigHolds 5 'was ended at your timeout of 1s' ):$( rigIsError 5 )" "yes:true"

echo "-- 5. a non-zero exit --"
rigAssert "it is an error with its exit code" "$( rigHolds 6 'exit code: 3' ):$( rigIsError 6 )" "yes:true"

echo "-- 6. a task id as a job --"
rigAssert "job=process-N points at the task tools" "$( rigHolds 7 'TaskOutput handle=process-1' ):$( rigIsError 7 )" "yes:false"

echo "-- 7. the tool list --"
rigAssert "execute declares timeout_action and background" "$( rigHolds 9 '"timeout_action":{"type":"string"' )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP TOOL TASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_TOOL_TASK: OK (%d assertions, offline)\n' "$rigPassCount"
