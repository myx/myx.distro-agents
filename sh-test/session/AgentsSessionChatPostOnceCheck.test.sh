#!/usr/bin/env bash
## Behavioural check: one post is one block of the session chat file (AgentsToolsSessionChatImportDirect, AgentsSessionChatImport.awk).
## The run's own post is recorded before Slack is called, and stamped beside the index with the ts Slack gave it. A read of the
## thread then brings it twice: the comms cache's own line of the post (`[local: <id>]`, its ts the epoch it was stored at, .000000),
## and Slack's copy under the real ts. Held, over a session folder of the rig's own:
##   1. the own post stays one block, and the session thread reader gives it once; the same read again adds nothing
##   2. the controls: a person's message, and a post of ours the file does not hold read with its Slack ts, each become one block
##   3. the kept view of the index (AgentsToolsSessionChatReadPath) asked for again after an append in its own second holds the append:
##      a stale view ends its last block at the end of the file, and so shows the newer messages inside it a second time
## Offline: no Slack, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is not at the origin this workspace resolves: $rigHere/session/AgentsTools.SessionChat.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatPostOnceCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export MMDAPP="$rigTmp/ws"
## The direct write is what the chat writer thread runs as well; with it off, no thread outlives the rig.
export MDAT_SESSION_CHAT_WRITER=off
rigDir="$MMDAPP/.local/agents/sessions/rig-post-once"
mkdir -p "$MMDAPP/.local/.agents" "$MMDAPP/.local/temp" "$rigDir"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD CLAUDE_CODE_SESSION_ID harnessSessionId MDAT_SPAWN_LAUNCH_MARKER
. "$rigHere/session/AgentsTools.SessionChat.include"

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
rigThread="CRIGONE01:1760000000.000010"
printf '%s\n' "$rigThread" > "$rigDir/session.thread"
## A thread read before: what a read brings is news, never history.
AgentsToolsSessionChatPointerSet rig-post-once "import:$rigThread" 1760000000
rigOwnNo="$( printf 'RIG-OWN the run posted this' | AgentsToolsSessionChatAppend rig-post-once keeper-rig all - - own )"
[ -n "$rigOwnNo" ] || rigRefuse "the run's own post was not recorded in the chat file"
AgentsToolsSessionChatStamp rig-post-once "$rigOwnNo" 1760000100.123456 "$rigThread" || rigRefuse "the run's own post was not stamped"
printf '%s\n' \
	"1760000090.000000 | keeper-rig | [local: 20251009T000130000Z-000000E9A] RIG-OWN the run posted this" \
	"1760000100.123456 | URIGBOT01 | [sender: keeper-rig] 🔏 *_keeper-rig_* → @here." "RIG-OWN the run posted this" \
	"1760000110.000200 | URIGFRIEND | RIG-PERSON a person answers" \
	"1760000120.000300 | keeper-rig | [local: 20251009T000200000Z-000000E9A] RIG-LINKED a post of ours the file does not hold" > "$rigTmp/render"

echo "-- 1. the run's own post is one block --"
AgentsToolsSessionChatImport rig-post-once "$rigThread" "$rigTmp/render" slack
rigAssert "the chat file holds the own post once, beside its cache line and Slack's copy of it" "$( LC_ALL=C grep -c 'RIG-OWN' "$rigDir/session.chat" )" 1
rigAssert "the session thread reader gives it once" "$( AgentsToolsSessionChatThreadMessages rig-post-once "$rigThread" keeper-other "" 20 | LC_ALL=C grep -c 'RIG-OWN' )" 1
rigBlocks="$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )"
AgentsToolsSessionChatImport rig-post-once "$rigThread" "$rigTmp/render" slack
rigAssert "the same read again adds nothing" "$( LC_ALL=C wc -l < "$rigDir/session.chat.index" | LC_ALL=C tr -d ' ' )" "$rigBlocks"

echo "-- 2. the controls --"
rigAssert "a person's message is one block" "$( LC_ALL=C grep -c 'RIG-PERSON' "$rigDir/session.chat" )" 1
rigAssert "a post of ours the file does not hold, read with its Slack ts, is one block" "$( LC_ALL=C grep -c 'RIG-LINKED' "$rigDir/session.chat" )" 1

echo "-- 3. the kept view holds a write made in its own second --"
rigStaleCount=0
for (( rigRound = 1 ; rigRound <= 30 ; rigRound++ )) ; do
	AgentsToolsSessionChatReadPath rig-post-once || rigRefuse "the session has no view to read"
	printf 'RIG-VIEW-%s' "$rigRound" | AgentsToolsSessionChatAppend rig-post-once keeper-rig all "$(( 1760000200 + rigRound )).000001" "$rigThread" slack > /dev/null
	AgentsToolsSessionChatReadPath rig-post-once || rigRefuse "the session has no view to read"
	[ "$( LC_ALL=C wc -l < "$agentsSessionChatReadPath" )" = "$( LC_ALL=C wc -l < "$rigDir/session.chat.index" )" ] || rigStaleCount=$(( rigStaleCount + 1 ))
done
rigAssert "a view asked for again after an append holds it, in 30 rounds" "$rigStaleCount" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CHAT POST ONCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_POST_ONCE: OK (%d assertions, offline)\n' "$rigPassCount"
