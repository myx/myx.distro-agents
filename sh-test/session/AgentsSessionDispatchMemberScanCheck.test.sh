#!/usr/bin/env bash
## Behavioural check on S21.20: a run reads its OWN input scan, where its sandbox holds one.
## A session's sandbox holds one scan per member (input-scan.md for the session's first start,
## input-scan.<member>.md for each member after it). A run given another member's scan reads
## someone else's work and never notices, so --get-dispatch-text takes its own member's scan
## where the sandbox holds one, and the session's only where it holds none.
##   1. both scans present: the run reads its own, and the other member's does not appear.
##   2. control: only the session's scan present, and it is read -- so the instrument is not
##      passing by printing nothing.
##   3. control: no scan at all, and no scan section is printed.
## Offline: every workspace and sandbox here is a folder of this rig's own; no Slack, no model.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigSessionFn="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSessionFn" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSessionFn"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSessionDispatchMemberScanCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSandbox="$rigWs/.local/agents/spawned/rig-session"
mkdir -p "$rigSandbox/input" "$rigWs/.local" "$rigTmp/home"
rigMember="rig-second"
rigOther="rig-first"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The dispatch text this run is given, as the member named. A fresh environment every call.
rigDispatch(){ ## member
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" \
		MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID=rig-session MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-}" \
		bash "$rigSessionFn" --get-dispatch-text ) 2> "$rigTmp/err"
}

printf '# Brief\n\nRIG-BRIEF the task as given.\n' > "$rigSandbox/input/dispatch.md"

echo "-- 1. both scans in the sandbox: the run reads its own --"
printf '# Scan\n\nRIG-SCAN-SESSION the session scan.\n' > "$rigSandbox/input/input-scan.md"
printf '# Scan\n\nRIG-SCAN-OWN this member scan.\n' > "$rigSandbox/input/input-scan.$rigMember.md"
printf '# Scan\n\nRIG-SCAN-OTHER another member scan.\n' > "$rigSandbox/input/input-scan.$rigOther.md"
rigOut="$( rigDispatch "$rigMember" )"
rigAssert "its own member's scan is the one shown" "$( LC_ALL=C grep -c 'RIG-SCAN-OWN' <<< "$rigOut" )" 1
rigAssert "the session's scan and another member's are not" "$( LC_ALL=C grep -c -e 'RIG-SCAN-SESSION' -e 'RIG-SCAN-OTHER' <<< "$rigOut" )" 0
rigAssert "the rest of the dispatch still stands: the brief, then the scan, each its own section" \
	"$( LC_ALL=C grep -c -x -e '# Dispatch' -e '# Input scan' <<< "$rigOut" ):$( LC_ALL=C grep -c 'RIG-BRIEF' <<< "$rigOut" )" "2:1"

echo "-- 2. control: only the session's scan, and it is read --"
rm -f "$rigSandbox/input/input-scan.$rigMember.md" "$rigSandbox/input/input-scan.$rigOther.md"
rigOut="$( rigDispatch "$rigMember" )"
rigAssert "the session's scan is read where the member has none of its own" "$( LC_ALL=C grep -c 'RIG-SCAN-SESSION' <<< "$rigOut" )" 1

echo "-- 3. control: no scan at all, and no scan section --"
rm -f "$rigSandbox/input/input-scan.md"
rigOut="$( rigDispatch "$rigMember" )"
rigAssert "no scan section is printed" "$( LC_ALL=C grep -c -x '# Input scan' <<< "$rigOut" )" 0
rigAssert "and the brief is still printed" "$( LC_ALL=C grep -c 'RIG-BRIEF' <<< "$rigOut" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISPATCH MEMBER SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a run reads another member's input scan, or none, where its sandbox holds its own" >&2
	echo "  fix:  AgentsToolsThisSessionDispatchText in sh-lib/session/AgentsTools.ThisSession.include -- never the assertion" >&2
	exit 1
fi
printf 'DISPATCH_MEMBER_SCAN: OK (%d assertions, offline)\n' "$rigPassCount"
