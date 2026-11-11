#!/usr/bin/env bash
## AgentsPinnedOriginRefusalCheck -- a caller that exports both MDLT_ORIGIN and MDLT_OPTION gets a refusal when the pinned
## tree carries no tooling (the guard at the head of sh-scripts/DistroAgentsTools.fn.sh, MAGIC.md "MDLT_OPTION").
## Without the guard the same launch dies on a bare file-not-found, which no MCP host can explain.
## Guards: the served launch ends 1; exactly one stderr line names MDLT_OPTION as the reason, and one names the two
## includes the launch loads, AgentsContext.include and AgentsContext.FrontTable.include; the pin is named; no stderr
## line reads `No such file or directory`; nothing reaches the protocol wire.
## The control in the same run: the same launch against a pin carrying the tooling ends 0, writes its initialize frame,
## and names no refusal.
## Red: a copy of this tree whose guard tests another variable, so it never fires, fails `one line names MDLT_OPTION as
## the reason`, `one line names the two includes the launch loads`, `the refusal names the pin` and `nothing reads as a
## bare file-not-found`. Its exit status stays 1 there, on the bare file-not-found alone, so the status assertion alone
## is no measure of the guard.
## Offline: a rig of this check alone, removed at its end; the frame is the front door's own server answering one
## initialize message on stdin.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigBound="$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the front door is not at the origin this workspace resolves: $rigTool"
[ -f "$rigBound" ] || rigRefuse "the run bound is not at the origin this workspace resolves: $rigBound"
command -v python3 > /dev/null || rigRefuse "python3 is not installed"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPinnedOriginRefusalCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The pin is a tree of the rig's own that carries no tooling, and the workspace is one whose `.local` is there.
mkdir -p "$rigTmp/bare" "$rigTmp/ws/.local" "$rigTmp/home" || exit 1
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigLines(){ ## stream file, fixed text -- how many of its lines hold that text
	LC_ALL=C grep -c -F -- "$2" "$1"
}
## The served front door, exactly as an MCP host launches it, with the pin given: its streams and its status are left in
## files of the rig, and the bound ends a launch that stands still.
rigLaunch(){ ## pin, call name
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' > "$rigTmp/$2.in"
	( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" \
		MDLT_ORIGIN="$1" MDLT_OPTION="--run-from-path $1" \
		python3 -I -B "$rigBound" --alarm 120 -- bash "$rigTool" --intern-mcp-server --run < "$rigTmp/$2.in" ) \
		> "$rigTmp/$2.out" 2> "$rigTmp/$2.err"
	printf '%s\n' "$?" > "$rigTmp/$2.rc"
}

echo "-- 1. a pin that carries no tooling is refused, with a message a reader can act on --"
rigLaunch "$rigTmp/bare" pinned-bare
rigAssert "the launch refuses"                              "$( cat "$rigTmp/pinned-bare.rc" )" 1
rigAssert "one line names MDLT_OPTION as the reason"        "$( rigLines "$rigTmp/pinned-bare.err" 'MDLT_OPTION is set, so no origin resolution runs' )" 1
rigAssert "one line names the two includes the launch loads" "$( rigLines "$rigTmp/pinned-bare.err" 'AgentsContext.include and AgentsContext.FrontTable.include' )" 1
rigAssert "the refusal names the pin"                       "$( rigLines "$rigTmp/pinned-bare.err" "origin: $rigTmp/bare" )" 1
rigAssert "nothing reads as a bare file-not-found"          "$( rigLines "$rigTmp/pinned-bare.err" 'No such file or directory' )" 0
rigAssert "nothing reaches the protocol wire"               "$( wc -c < "$rigTmp/pinned-bare.out" | LC_ALL=C tr -d ' ' )" 0

echo "-- 2. the control: the same launch against a pin that carries the tooling serves --"
rigLaunch "$rigOrigin" pinned-tooled
rigAssert "the launch serves"                               "$( cat "$rigTmp/pinned-tooled.rc" )" 0
rigAssert "it writes its initialize frame"                  "$( rigLines "$rigTmp/pinned-tooled.out" '"jsonrpc":"2.0","id":1,"result"' )" 1
rigAssert "the frame names the protocol it speaks"          "$( rigLines "$rigTmp/pinned-tooled.out" '"protocolVersion"' )" 1
rigAssert "the control refuses nothing"                     "$( rigLines "$rigTmp/pinned-tooled.err" 'MDLT_OPTION is set' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PINNED ORIGIN REFUSAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a launch exporting both MDLT_ORIGIN and MDLT_OPTION dies on a bare file-not-found, or serves from a tree nothing verified" >&2
	echo "  fix:  the MDLT_OPTION guard in the executed arm of sh-scripts/DistroAgentsTools.fn.sh" >&2
	exit 1
fi
echo "PINNED_ORIGIN_REFUSAL: OK ($rigPassCount assertions, offline)"
