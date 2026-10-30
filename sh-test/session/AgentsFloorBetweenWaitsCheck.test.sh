#!/usr/bin/env bash
## AgentsFloorBetweenWaitsCheck -- S21.23, gap 2: a session the communications reader is not serving has its floor
## filled between two Waits. A message the chat file does not hold yet, and the thread's comms cache does, arrives on
## the next tool return, with no Wait in between. Offline by construction: the cache is a folder of this rig, no socket,
## no credential, and the cache's own pull is kept out twice over, by its state's moment and by a cache TTL of 0.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsTools.SessionTranscript.include" ] || rigRefuse "the transcript reply include is not in the package: $rigHere/session/AgentsTools.SessionTranscript.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsFloorBetweenWaitsCheck )" || exit 1
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

echo "-- a message the thread's cache holds, and the chat file does not, arrives on a tool return with no Wait --"
rigWs="$rigTmp/ws"
rigSession="rig-b"
rigThread="CRIGCHAN:1700000000.000100"
rigCache="$rigWs/.local/cache/comms/slack/slack-CRIGCHAN-1700000000.000100"
rigRead='
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"
	AgentsTranscriptReplyFloor
'
## The session's own folder: its thread, and an import that happened before the handback was posted.
mkdir -p "$rigWs/.local/agents/sessions/$rigSession"
printf '%s\n' "$rigThread" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
printf 'import:%s\t1695000000\n' "$rigThread" > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"
## The thread's cache: an older message the session imported long ago, and the handback posted after that import.
mkdir -p "$rigCache/202311"
{
	printf '%s | U0RIG | [sender: magic-librarian] OLDER-LINE already imported by this session\n' "1690000000.000050"
	printf '%s | U0RIG | [sender: magic-coordinator] GREEN-HANDBACK-LINE\n' "1700000000.000200"
} > "$rigCache/202311/messages.txt"
printf '%s 1690000000.000050 1700000000.000200\n\nslack-thread %s rig-member false\n' "$( date +%s )" "$rigThread" > "$rigCache/.state.txt"

rigFloor="$(
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT=rig-member MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		bash -c "$rigRead" 2> /dev/null
)"
case "$rigFloor" in
	*GREEN-HANDBACK-LINE*) rigAssert "the handback the cache holds arrives on the tool return" yes yes ;;
	*) rigAssert "the handback the cache holds arrives on the tool return" "$rigFloor" "a floor carrying GREEN-HANDBACK-LINE" ;;
esac
case "$rigFloor" in
	*OLDER-LINE*) rigAssert "a message from before the session's own import is not delivered as new" yes no ;;
	*) rigAssert "a message from before the session's own import is not delivered as new" no no ;;
esac

## The same return again: what was delivered once is not delivered twice.
rigAgain="$(
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT=rig-member MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		bash -c "$rigRead" 2> /dev/null
)"
rigAssert "the next return carries the handback no more" "$( printf '%s' "$rigAgain" | LC_ALL=C grep -c 'GREEN-HANDBACK-LINE' )" "0"

## A session whose thread has no cache at all: the return is empty rather than broken, and it writes nothing.
mkdir -p "$rigWs/.local/agents/sessions/rig-c"
printf 'CRIGCHAN:1700000000.000900\n' > "$rigWs/.local/agents/sessions/rig-c/session.thread"
rigNone="$(
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_SESSION_ID=rig-c MDAT_SPAWN_AGENT=rig-member MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		bash -c "$rigRead" 2> /dev/null
)"
rigAssert "a session whose thread has no cache gets an empty floor" "$rigNone" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ FLOOR BETWEEN WAITS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'FLOOR_BETWEEN_WAITS: OK (%d assertions, offline)\n' "$rigPassCount"
