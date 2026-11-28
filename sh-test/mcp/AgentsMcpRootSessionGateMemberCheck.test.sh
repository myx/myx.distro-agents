#!/usr/bin/env bash
## Behavioural check of the member a root session's tool calls are gated for. A server that carries a root session reads the member
## that session recorded from its folder, and the deny gate of every call decides for that member; only the RootSession tool
## itself takes a member of its own, as an argument. Held:
##   1. a served Read under a root session that recorded magic-tester is gated for magic-tester
##   2. the Read still answers with the file's text
## Red before the change: the RootSession tool's own member argument, empty on every other call, overwrote the recorded member.
## Offline: a rig root session of this check alone, under this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpRequestPreludeCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
rigRoot="rig-root-gate-$$"
rigRootDir="$MMDAPP/.local/agents/sessions/$rigRoot"
trap 'rm -rf -- "$rigTmp" "$rigScratch" "$rigRootDir" "$MMDAPP/.local/agents/spawned/$rigRoot"' EXIT
mkdir -p "$rigRootDir" && printf 'magic-tester\n' > "$rigRootDir/root-session.member" && printf '%s rig-token\n' "$rigRoot" > "$rigScratch/root-session" || exit 1
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

echo "-- 1. a served Read is gated for the member the root session recorded --"
rigWire="$( rigCall 900501 "$rigRead" )"
rigCall 900502 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "the member the gate decides for" \
	"$( LC_ALL=C grep -E '^\++[^ ]+ mcpGateMember=' "$rigTmp/trace" | tail -1 | sed 's/.*mcpGateMember=//; s/ .*//' )" magic-tester

echo "-- 2. the Read answers --"
rigAssert "the file's text comes back" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP ROOT SESSION GATE MEMBER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_ROOT_SESSION_GATE_MEMBER: OK (%d assertions, offline)\n' "$rigPass"
