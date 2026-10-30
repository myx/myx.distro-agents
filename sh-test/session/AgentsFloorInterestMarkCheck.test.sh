#!/usr/bin/env bash
## AgentsFloorInterestMarkCheck -- S21.23, gap 2: every tool return keeps the session's own thread of
## interest, so the rig's own pull (AgentsToolsCommsCachePullWatched) keeps it fresh without this call
## ever reaching Slack itself. Offline by construction: no socket, a plain local sandbox, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsTools.SessionTranscript.include" ] || rigRefuse "the transcript reply include is not in the package: $rigHere/session/AgentsTools.SessionTranscript.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsFloorInterestMarkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- a tool return's floor keeps the session's own thread of interest, with no network call --"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-sess"
printf 'CRIGCHAN:1700000000.000100\n' > "$rigWs/.local/agents/sessions/rig-sess/session.thread"
env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-sess bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"
	AgentsTranscriptReplyFloor > /dev/null
'
rigAssert "the interest mark for the session's own thread now exists" \
	"$( [ -f "$rigWs/.local/cache/comms/.interest/slack-CRIGCHAN-1700000000.000100" ] && printf yes || printf no )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ FLOOR INTEREST MARK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'FLOOR_INTEREST_MARK: OK (%d assertions, offline)\n' "$rigPassCount"
