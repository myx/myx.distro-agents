#!/usr/bin/env bash
## Behavioural check on what the myx.common MCP server ends when its own run ends: a request handler still in flight,
## and everything that handler started, ends with it (agentMcpServer.Common, AgentMcpServerEndInflight and
## AgentMcpEndDescendants). Run rather than read: a real server is started on a FIFO, given `initialize` and one
## `lib_execShStdin` call that sleeps, then given TERM, and its handler processes are counted before and after.
## Held:
##   1. the server answers `initialize` and the sleeping handler runs, so the run is a real one and not an empty pass
##   2. after TERM nothing of the handler is left, and the server itself is gone
##   3. the check is able to fail: a copy whose only change is the direct-children kill it had before leaves the
##      handler running after TERM, and the same count sees it
## Red: with the direct-children kill in place, the sleeping handler is left running after the server ends.
## Offline: one mktemp tree under the workspace's temp folder, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigServer="${MYXROOT:-}/bin/lib/agentMcpServer.Common"
[ -f "$rigServer" ] || rigServer="$MMDAPP/source/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/agentMcpServer.Common"
[ -f "$rigServer" ] || rigRefuse "no myx.common MCP server to run: looked in MYXROOT and in the workspace's own source"
rigShare="${rigServer%/bin/lib/agentMcpServer.Common}"
[ -f "$rigShare/include/data/agentMcpTools.json" ] || rigRefuse "the server's own resources are not beside it: $rigShare/include/data"

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsMcpServerEndsHandlersCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'pkill -f "sleep 612" 2>/dev/null ; pkill -f "sleep 673" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

## The handlers still running for one marker, as a count: the process list is the one reading, by the command line.
rigCount(){ ## sleep seconds
	ps -ax -o command= 2> /dev/null | grep -F "sleep $1" | grep -v -F 'grep -F' | wc -l | tr -d ' '
}
## One server run: initialize, one sleeping call, TERM, and the counts either side. Prints "<answered> <before> <after> <alive>".
rigRun(){ ## server file, tag, sleep seconds
	local runServer="$1" runTag="$2" runMark="$3" runDir runPid runAnswered runBefore runAfter runAlive
	runDir="$rigTmp/$runTag"
	mkdir -p "$runDir" || return 1
	mkfifo "$runDir/in" || return 1
	MYXROOT="$rigShare" TMPDIR="$runDir" bash "$runServer" --run < "$runDir/in" > "$runDir/out" 2> "$runDir/err" &
	runPid=$!
	exec 3> "$runDir/in"
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' >&3
	printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"lib_execShStdin\",\"arguments\":{\"command\":\"lib/execShStdin\",\"stdin\":\"sleep $runMark\\n\"}}}" >&3
	sleep 3
	runBefore="$( rigCount "$runMark" )"
	kill -TERM "$runPid" 2> /dev/null
	sleep 3
	exec 3>&-
	runAfter="$( rigCount "$runMark" )"
	runAlive="no" ; kill -0 "$runPid" 2> /dev/null && runAlive="yes"
	runAnswered="$( grep -c -F '"id":1,"result"' "$runDir/out" 2> /dev/null || : )"
	printf '%s %s %s %s\n' "$runAnswered" "$runBefore" "$runAfter" "$runAlive"
}

## The server as it stands, on a real run.
printf -- '-- 1. the server as it stands --\n'
rigGot="$( rigRun "$rigServer" live 612 )"
printf '        <answered> <before> <after> <alive>: %s\n' "$rigGot"
set -- $rigGot
rigAssert "the server answered initialize, so this was a real run" "$1" 1
rigAssert "the sleeping handler was running before TERM" "$2" 1
rigAssert "after TERM nothing of that handler is left" "$3" 0
rigAssert "after TERM the server itself is gone" "$4" no

## The same server with the direct-children kill it had before: the check must see the handler it leaves.
printf -- '-- 2. the check is able to fail --\n'
mkdir -p "$rigTmp/seeded/myx.common/bin/lib" || exit 1
rigSeeded="$rigTmp/seeded/myx.common/bin/lib/agentMcpServer.Common"
awk '{ if ( $0 == "\t\tAgentMcpEndDescendants \"$endPid\"" ) { print "\t\tpkill -TERM -P \"$endPid\" 2>/dev/null || true" ; print "\t\tkill -TERM \"$endPid\" 2>/dev/null || true" } else print }' "$rigServer" > "$rigSeeded" || exit 1
rigAssert "the seeded copy is not the server as it stands: the descendant walk is gone from it" "$( grep -c -F 'AgentMcpEndDescendants "$endPid"' "$rigSeeded" || : )" 0
sh -n "$rigSeeded" 2> /dev/null && sh -n "$rigServer" 2> /dev/null && rigParses=yes || rigParses=no
rigAssert "both the seeded copy and the server parse as sh" "$rigParses" yes
rigGot="$( rigRun "$rigSeeded" seeded 673 )"
printf '        <answered> <before> <after> <alive>: %s\n' "$rigGot"
set -- $rigGot
rigAssert "seeded: the sleeping handler was running before TERM" "$2" 1
rigAssert "seeded: the handler outlives the server, so the count above can fail" "$3" 1
pkill -f "sleep 673" 2> /dev/null

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MCP SERVER ENDS HANDLERS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_SERVER_ENDS_HANDLERS: OK (%d assertions, offline)\n' "$rigPasses"
