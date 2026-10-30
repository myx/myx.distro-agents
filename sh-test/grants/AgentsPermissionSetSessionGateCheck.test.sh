#!/usr/bin/env bash
## Behavioural check on AgentsToolsPermissionSetApply's session gate (S21.20, the tester's own
## incident: retest batch `0d4f5aaf`'s own kind closed as allowed, GRANT: set 0 entries, with
## nothing stored). Held, run and not read:
##   1. A session-id that fails the bare-name assert (not a bare name) is never silently treated
##      as success: the apply refuses, and nothing is written for it.
##   2. A valid session-id still applies as before: the grant is written, and the count is real.
## Offline: no Slack, no network, the function called directly against a scratch workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigInclude="$rigHere/grants/AgentsTools.InternOpPermission.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the include is not at the origin this workspace resolves: $rigInclude"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPermissionSetSessionGateCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigApply(){ ## pending-id, approver
	( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		MDSC_CMD=rig
		. "'"$rigInclude"'"
		AgentsToolsPermissionSetApply "$1" "$2"
	' rig "$1" "$2" ) 2>&1
}

echo "-- 1. a session-id that fails the bare-name assert is never silently treated as success --"
rm -rf "$rigWs" ; mkdir -p "$rigWs/.local/agents/pending" "$rigWs/.local/agents/sessions"
printf -- 'scope: session\nsession-id: bad/session\nparticipants: rig-member\nentry: Read:/tmp/rig/**\n' > "$rigWs/.local/agents/pending/rig-set-bad.set"
rigOut="$( rigApply rig-set-bad rig-approver )" ; rigRc=$?
rigAssert "the apply fails rather than reporting a success with 0 entries" "$( [ "$rigRc" != 0 ] && printf failed )" failed
rigAssert "it names the session-id that could not be used" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F 'bad/session' )" 1
rigAssert "and GRANT: set 0 is never printed" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F 'GRANT: set 0' )" 0
rigAssert "nothing was written to any session's grants" "$( find "$rigWs/.local/agents/sessions" -name grants 2>/dev/null | wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 2. a valid session-id still applies, and the grant is written --"
rm -rf "$rigWs" ; mkdir -p "$rigWs/.local/agents/pending" "$rigWs/.local/agents/sessions/rig-session-good"
printf -- 'scope: session\nsession-id: rig-session-good\nparticipants: rig-member\nentry: Read:/tmp/rig/**\n' > "$rigWs/.local/agents/pending/rig-set-good.set"
rigOut="$( rigApply rig-set-good rig-approver )" ; rigRc=$?
rigAssert "the apply succeeds" "$rigRc" 0
rigAssert "with a real, non-zero count" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F 'GRANT: set 1 entries for rig-member' )" 1
rigAssert "and the grant is on disk" "$( find "$rigWs/.local/agents/sessions/rig-session-good" -name grants 2>/dev/null | wc -l | LC_ALL=C tr -d ' ' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION SET SESSION GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a malformed session-id in a permission set is reported as a success with nothing stored" >&2
	echo "  fix:  repair AgentsToolsPermissionSetApply in sh-lib/grants/AgentsTools.InternOpPermission.include -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_SET_SESSION_GATE: OK (%d assertions, offline)\n' "$rigPassCount"
