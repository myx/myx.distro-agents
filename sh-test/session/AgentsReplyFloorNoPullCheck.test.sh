#!/usr/bin/env bash
## Behavioural check of the floor on a tool return (AgentsTranscriptReplyFloor), against the standing ruling: a reader never starts
## a refresh; a stale read registers interest and the comms thread fills the entry; the detached-pull branch is deleted. Held:
##   1. a tool return whose thread cache is missing or stale starts no pull of its own, now or detached
##   2. control: where the cache holds news the session has not got, the return still brings it into the chat file
##   3. and it still registers the thread as of interest, the one thing a reader does for a stale read
## Red before the change: the return detaches a pull of the thread (AgentsToolsCommsCacheSlackThread) whenever its cache is stale.
## Offline: a rig workspace of this check's own, the comms cache stubbed; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReplyFloorNoPullCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-session" || exit 1
printf '%s\n' 'CRIGFLOOR1:1795000000.000001' > "$rigWs/.local/agents/sessions/rig-session/session.thread" || exit 1

## One tool return's floor in the rig. The cache answers as the case says: `stale` holds nothing the session lacks, `news` holds one
## block past what the session has. Prints which of pulled, imported and interest the return did.
rigReturn(){ ## stale | news
	rm -f "$rigTmp/pulled" "$rigTmp/imported" "$rigTmp/interest"
	MMDAPP="$rigWs" MDAT_SESSION_ID=rig-session harnessAgent=rig-member MDAT_COMMS_READER= RIG_CASE="$1" RIG_TMP="$rigTmp" bash -c '
		. "$1/sh-lib/session/AgentsTools.SessionChat.include" > /dev/null 2>&1 || exit 1
		. "$1/sh-lib/session/AgentsTools.SessionTranscript.include" > /dev/null 2>&1 || exit 1
		AgentsToolsCommsCacheInterest(){ : > "$RIG_TMP/interest" ; }
		AgentsToolsCommsCacheSlackDir(){ agentsCommsCacheDir="$RIG_TMP/cache" ; agentsCommsCacheAt=0 ; agentsCommsCacheNewest=5 ; [ "$RIG_CASE" != news ] || mkdir -p "$agentsCommsCacheDir" ; return 0 ; }
		AgentsToolsCommsCacheState(){ [ "$RIG_CASE" = news ] ; }
		AgentsToolsCommsCacheServe(){ printf "rendered\n" ; }
		AgentsToolsSessionChatImport(){ : > "$RIG_TMP/imported" ; }
		AgentsToolsCommsCacheSlackThread(){ : > "$RIG_TMP/pulled" ; }
		AgentsTranscriptReplyFloor > /dev/null 2>&1
	' rig "$rigPkg"
	## A detached pull lands after the return: the folder is read once the time it would take has passed.
	sleep 2
	printf '%s %s %s' "$( [ -e "$rigTmp/pulled" ] && echo pulled || echo no-pull )" "$( [ -e "$rigTmp/imported" ] && echo imported || echo no-import )" "$( [ -e "$rigTmp/interest" ] && echo interest || echo no-interest )"
}

echo "-- 1. a stale cache: no pull from the return --"
rigStale="$( rigReturn stale )"
rigAssert "a tool return with a stale thread cache starts no pull" "${rigStale%% *}" no-pull
echo "-- 2. control: news in the cache still reaches the chat file --"
rigNews="$( rigReturn news )"
rigAssert "a tool return with news in the cache imports it" "$( printf '%s' "$rigNews" | LC_ALL=C awk '{ print $2 }' )" imported
echo "-- 3. the thread is registered as of interest --"
rigAssert "the stale return registers interest in its thread" "${rigStale##* }" interest

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REPLY FLOOR NO PULL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'REPLY_FLOOR_NO_PULL: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
