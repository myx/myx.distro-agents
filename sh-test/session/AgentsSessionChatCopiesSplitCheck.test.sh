#!/usr/bin/env bash
## Behavioural check of the session chat copies as a file of their own (code-craft: a file is split per feature; no load on a path
## that does not call into the file). The session chat include is parsed by every served call, for its reply floor; the copies of a
## message sent into another session's thread are a send's feature, parsed only by the send that makes them. Held:
##   1. the session chat include holds none of the copies' functions, and the copies include holds all eight
##   2. the copies include loads on its own, with the chat include it writes through
##   3. every library file that calls a copies function loads the copies include
##   4. a served Read parses no copies include
## Red before the change: the copies were the session chat include's, parsed by every served call.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatCopiesSplitCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigChat="$rigPkg/sh-lib/session/AgentsTools.SessionChat.include"
rigCopies="$rigPkg/sh-lib/session/AgentsTools.SessionChatCopies.include"
rigNames='ThreadRoots|ThreadSessions|LiveRun|SessionMember|WakeCopies|DeliverCopy|DeliverStamp|CopiesKeep'

echo "-- 1. the copies are a file of their own --"
rigAssert "copies functions the session chat include holds" \
	"$( LC_ALL=C grep -cE "^AgentsToolsSessionChat($rigNames)\(\)" "$rigChat" )" 0
rigAssert "copies functions the copies include holds" \
	"$( LC_ALL=C grep -cE "^AgentsToolsSessionChat($rigNames)\(\)" "$rigCopies" 2> /dev/null )" 8

echo "-- 2. the copies include loads on its own --"
rigAssert "functions a fresh shell has after loading it" \
	"$( env -i HOME="$HOME" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" > /dev/null 2>&1 || exit 1
		n=0 ; for f in AgentsToolsSessionChatAppend AgentsToolsSessionChatDeliverCopy AgentsToolsSessionChatDeliverStamp AgentsToolsSessionChatWakeCopies AgentsToolsSessionChatCopiesKeep ; do
			type "$f" > /dev/null 2>&1 && n=$(( n + 1 )) ; done ; echo "$n"' rig "$rigCopies" )" 5

echo "-- 3. each caller loads it --"
rigUnloaded=""
for rigFile in $( LC_ALL=C grep -rlE "^[^#]*AgentsToolsSessionChat(WakeCopies|DeliverCopy|DeliverStamp|CopiesKeep) " "$rigPkg/sh-lib" 2> /dev/null ) ; do
	[ "$rigFile" != "$rigCopies" ] || continue
	LC_ALL=C grep -q 'AgentsTools\.SessionChatCopies\.include' "$rigFile" || rigUnloaded="$rigUnloaded ${rigFile##*/}"
done
rigAssert "callers that never load the copies include" "${rigUnloaded:-none}" none

echo "-- 4. a served Read parses no copies include --"
rigRead='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'
printf '%s\n' "$rigRead" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" \
	"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" 900201 3> /dev/null > /dev/null 2> /dev/null
printf '%s\n' "$rigRead" | env -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}: ' \
	"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" 900202 3> /dev/null > /dev/null 2> "$rigTmp/trace"
rigAssert "session chat include parsed by the Read (the control)" \
	"$( LC_ALL=C grep -cE "^\++[^ ]+ (\.|source) '?[^ ]*/AgentsTools\.SessionChat\.include" "$rigTmp/trace" | awk '{ print ( $1 > 0 ) ? "parsed" : "not parsed" }' )" parsed
rigAssert "copies includes parsed by the Read" \
	"$( LC_ALL=C grep -cE "^\++[^ ]+ (\.|source) '?[^ ]*/AgentsTools\.SessionChatCopies\.include" "$rigTmp/trace" )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION CHAT COPIES SPLIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_COPIES_SPLIT: OK (%d assertions, offline)\n' "$rigPass"
