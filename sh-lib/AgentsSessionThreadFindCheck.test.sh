#!/usr/bin/env bash
## AgentsSessionThreadFindCheck.test.sh -- exercises AgentsToolsSessionThreadFind
## directly, offline, no Slack calls. Coverage for the Q93 fix: a joining
## coworking participant's own MDAT_SPAWN_SESSION_ID differs from the shared
## session folder, so MDAT_SESSION_THREAD must be read first, with the old
## file lookup kept only as a fallback.
set -u
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigInclude="$rigHere/AgentsTools.SpawnSandbox.include"

rigRefuse(){
	echo "⛔ ERROR: $1" >&2
	exit 1
}
[ -f "$rigInclude" ] || rigRefuse "include not found: $rigInclude"

rigTmp="$( mktemp -d -t AgentsSessionThreadFindCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){
	if [ "$2" = "$3" ]
	then
		printf '  PASS  %s\n' "$1"
		rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- MDAT_SESSION_THREAD set takes priority, even with a mismatched spawn-id --"
(
	MMDAPP="$rigTmp/ws"
	MDAT_SESSION_THREAD="CJOINING:1700000000.000001"
	MDAT_SPAWN_SESSION_ID="not-the-session-folder"
	. "$rigInclude"
	AgentsToolsSessionThreadFind
) > "$rigTmp/out-a" 2>&1
rigAssert "priority case returns the env var" "$( cat "$rigTmp/out-a" )" "CJOINING:1700000000.000001"

echo "-- no env var, falls back to the file lookup --"
mkdir -p "$rigTmp/ws/.local/agents/spawned/founding-id"
printf 'CFOUND:1700000000.000002\n' > "$rigTmp/ws/.local/agents/spawned/founding-id/session.thread"
(
	unset MDAT_SESSION_THREAD
	MMDAPP="$rigTmp/ws"
	MDAT_SPAWN_SESSION_ID="founding-id"
	. "$rigInclude"
	AgentsToolsSessionThreadFind
) > "$rigTmp/out-b" 2>&1
rigAssert "fallback case returns the file's line" "$( cat "$rigTmp/out-b" )" "CFOUND:1700000000.000002"

echo "-- neither present, fails closed --"
rigRc=0
(
	unset MDAT_SESSION_THREAD
	MMDAPP="$rigTmp/ws"
	MDAT_SPAWN_SESSION_ID="no-such-id"
	. "$rigInclude"
	AgentsToolsSessionThreadFind
) > "$rigTmp/out-c" 2>&1 || rigRc=$?
rigAssert "absent case returns empty" "$( cat "$rigTmp/out-c" )" ""
rigAssert "absent case fails" "$rigRc" "1"

if [ "$rigFailCount" -ne 0 ]
then
	echo "⛔ SESSION THREAD FIND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'SESSION_THREAD_FIND_CHECK: OK (%d assertions, offline)\n' "$rigPassCount"
