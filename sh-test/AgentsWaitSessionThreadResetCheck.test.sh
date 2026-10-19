#!/usr/bin/env bash
## Covers one of the human-owner's four Wait-session-thread asks: "clear / reset
## returns Waiting on session thread back". A bare default wait already watches the
## session's own thread when one is known (AgentsToolsWaitDefaultSources, driven here
## by MDAT_SESSION_THREAD, the same env var AgentsHarnessWaitCheck.test.sh's own 10o
## scenario uses). This checks that property survives --wait-close: closing the
## stored wait and asking a bare default one again recomputes the session thread as
## its source, exactly as a session with nothing stored yet would get it.
## Offline: the only source ever named is a plain slack:<channel>:<ts>:conversation
## one, read with since_utime set, so this never needs a real Slack read; no curl call
## is expected at all.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "DistroAgentsTools.fn.sh not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to act under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitSessionThreadResetCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

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
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigSourcesLine(){ ## file
	LC_ALL=C sed -n 's/^# sources: //p' "$1" | head -1
}

rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigSession="rig-wait-session-thread-reset"
rigSessionThread="CRIGSESSION:1700000001.000101"

rigOp(){ ## operation and its arguments
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		MDAT_SESSION_THREAD="$rigSessionThread" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTools" "$@" ) > "$rigWs/out" 2> "$rigWs/err"
}

echo "-- a bare default wait, nothing stored yet, watches the session's own thread --"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-since-utime 1700000000 --wait-timeout 2 --wait-poll-interval 1
rigAssert "it times out (nothing posted there)" "$( rigFirstLine "$rigWs/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
rigAssert "the session thread is the source" "$( rigSourcesLine "$rigWs/out" )" "slack:$rigSessionThread:conversation"

echo "-- --wait-close ends the stored wait --"
rigOp --member-wait-for-input "$rigMember" --wait-close --wait-session-id "$rigSession"
rigAssert "it reports CLOSED" "$( rigFirstLine "$rigWs/out" )" "WAIT-RESULT: CLOSED"

echo "-- a later bare default wait recomputes the session thread as its source again --"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-since-utime 1700000000 --wait-timeout 2 --wait-poll-interval 1
rigAssert "it times out, same as before" "$( rigFirstLine "$rigWs/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
rigAssert "the session thread is the source again, after the close" "$( rigSourcesLine "$rigWs/out" )" "slack:$rigSessionThread:conversation"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SESSION THREAD RESET CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SESSION_THREAD_RESET: OK (%d assertions, offline)\n' "$rigPassCount"
