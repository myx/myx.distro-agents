#!/usr/bin/env bash
## Behavioural check of what a served call's harness loads. A served Read whose roots the index vouches for computes none, prefetches
## nothing and takes no lock, so it loads neither the access-root producer, nor the prefetch, nor the local lock. Held:
##   1. the harness of a served Read loads none of those three includes
##   2. the Read still answers with the file's text
## Red before the change: each was loaded at the harness's top level on every call.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessServedLoadsCheck )" || exit 1
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
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER -u MDAT_SPAWN_AGENT MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}:${FUNCNAME[0]:-main}: ' \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> "$3"
	else
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER -u MDAT_SPAWN_AGENT MDAT_SPAWN_SESSION_ID="" \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
	fi
}
rigRead='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'

echo "-- 1. the harness loads nothing a served Read does not use --"
rigWire="$( rigCall 900501 "$rigRead" )"
rigCall 900502 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "producer, prefetch and lock includes loaded" \
	"$( LC_ALL=C grep -cE "^\\++[^ ]+ (\\.|source) .?[^ ]*/(AgentsTools\\.ClientAccessRoots|AgentsTools\\.PrefetchRoutine|AgentsTools\\.LocalLock)\\.include" "$rigTmp/trace" )" 0

echo "-- 2. the Read answers --"
rigAssert "the file's text comes back" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS SERVED LOADS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_SERVED_LOADS: OK (%d assertions, offline)\n' "$rigPass"
