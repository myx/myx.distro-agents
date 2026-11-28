#!/usr/bin/env bash
## Behavioural check of what a reply carries beside its result, read in the shell that sends it. The floor loads the session chat
## include; a capture of it parsed that include inside its own fork, and a thread read forked again for a folder path. Held:
##   1. a served Read's reply captures no floor; a thread read answers with no fork for its folder
##   2. the Read still answers with the file's text, and the date beside it
## Red before the change: the beside part captured the floor, and the thread read forked for its folder.
## Offline: requests answered by this rig's own server scratch; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReplyBesideForkCheck )" || exit 1
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigCall(){ ## seq, message, trace file or empty: one request, its wire on stdout
	if [ -n "${3:-}" ] ; then
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER MDAT_SPAWN_SESSION_ID="" SHELLOPTS=xtrace PS4='+${BASH_SOURCE##*/}:${FUNCNAME[0]:-main}: ' \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> "$3"
	else
		printf '%s\n' "$2" | env -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_MCP_SERVED_MARKER MDAT_SPAWN_SESSION_ID="" \
			"$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-request "$rigServerPid" "$1" 3>&1 > /dev/null 2> /dev/null
	fi
}
rigRead='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$MMDAPP"'/source/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh","limit":3}}}'

echo "-- 1. the reply takes the floor in its own shell --"
rigWire="$( rigCall 900501 "$rigRead" )"
rigCall 900502 "$rigRead" "$rigTmp/trace" > /dev/null
rigAssert "floor captures made by the beside part" \
	"$( LC_ALL=C grep -c "AgentsTranscriptReplyBeside: besideFloor=" "$rigTmp/trace" )" 0
rigThreadProbe="$( env MMDAPP="$rigTmp" bash -c '. "$1/sh-lib/session/AgentsTools.SessionChat.include" || exit 9
	mkdir -p "$MMDAPP/.local/agents/sessions/rig-s" && printf "C1:1.2\n" > "$MMDAPP/.local/agents/sessions/rig-s/session.thread"
	unset MDAT_SESSION_THREAD ; PS4="+ " ; set -x ; AgentsToolsSessionChatThread rig-s ; set +x' rig "$rigPkg" 2> "$rigTmp/thread.trace" )"
rigAssert "a thread read answers the thread, with no fork for its folder" "$rigThreadProbe:$( LC_ALL=C grep -c '^++* AgentsToolsSessionChatDir' "$rigTmp/thread.trace" )" "C1:1.2:0"

echo "-- 2. the Read answers --"
rigAssert "the file's text comes back" "$( case "$rigWire" in (*'for syntax checking in the editor only'*) echo carried ;; (*) echo "other: ${rigWire:0:300}" ;; esac )" carried
rigAssert "the date beside it" "$( case "$rigWire" in (*current-date:*) echo beside ;; (*) echo none ;; esac )" beside

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REPLY BESIDE FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'REPLY_BESIDE_FORK: OK (%d assertions, offline)\n' "$rigPass"
