#!/usr/bin/env bash
## Behavioural check of what a served call parses (code-craft: a load is placed where its call is reached). One served Read, the second
## on the same server scratch, through --intern-mcp-request, traced with every bash it starts (SHELLOPTS=xtrace), where each `. <file>`
## line is a file parsed:
##   1. the grants (and the board states they bring) are not parsed: a Read reaches no function of theirs
##   2. the Slack identities are not parsed: a return with no floor to deliver reaches none of theirs
##   3. control: the untraced call's answer carries the file's text, and the trace reaches the harness
## Red before the change: the harness parsed the grants at its start, and the session chat the Slack identities at its load, on every call.
## Offline: a file of the workspace read through the real request; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsServedReadLoadsCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigMsg='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'
rigCall(){ ## seq, trace file or empty: one served Read, its wire on stdout
	if [ -n "${2:-}" ] ; then
		printf '%s\n' "$rigMsg" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}: ' \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> "$2"
	else
		printf '%s\n' "$rigMsg" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
	fi
}
rigWire="$( rigCall 900093 )"
rigCall 900094 "$rigTmp/trace" > /dev/null
rigLoads(){ LC_ALL=C grep -cE "^\++[^ ]+ (\.|source) '?[^ ]*/$1'?( |\$)" "$rigTmp/trace" ; }

echo "-- 1. and 2. what a Read does not reach is not parsed --"
rigAssert "the grants and the board states parsed" "$( rigLoads AgentsTools.Grants.include ) $( rigLoads AgentsTools.BoardStates.include )" "0 0"
rigAssert "the Slack identities parsed" "$( rigLoads AgentsTools.SlackIdentities.include )" 0
echo "-- 3. control --"
rigAssert "the trace reaches the harness" "$( LC_ALL=C grep -c '^+*AgentsUniversalHarness.sh: ' "$rigTmp/trace" | LC_ALL=C awk '{ print ( $1 > 0 ? "reached" : "none" ) }' )" reached
rigAssert "the answer carries the file's text" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SERVED READ LOADS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SERVED_READ_LOADS: OK (%d assertions, offline)\n' "$rigPass"
