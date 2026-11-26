#!/usr/bin/env bash
## Behavioural check on the polling bound of the message watcher of a tool call (AgentsToolsTaskCall, sh-lib/session/AgentsTools.ToolTask.include).
## The watcher wakes every poll, and a wake that finds the chat unwritten since its last read must cost no read of the floor: the floor read
## is a chain of processes, and a watcher per live call paid it every poll. Held:
##   1. a quiet chat: once the first reads are past, the watcher reads the floor no more in a call that outlasts eight polls
##   2. the control: a post written to the chat while the call runs is read by the watcher, so 1 is a watcher that reads on change and not one
##      that never reads
## The floor is counted by a stand-in that stamps each read with its second and answers nothing, so no call returns early on a message.
## Offline: a rig workspace and a rig session, every call through `env -i`; nothing of this check outlives it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/session/AgentsTools.ToolTask.include" ] || rigRefuse "the tool task include is not in the package: $rigPkg"
[ -f "$rigPkg/sh-lib/session/AgentsTools.SessionChat.include" ] || rigRefuse "the session chat include is not in the package: $rigPkg"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsToolTaskPollBoundCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
rigSession="rig-poll-team"
rigReap(){
	local reapFile reapPid
	for reapFile in "$rigWs/.local/agents/sessions/$rigSession/processes"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	sleep 0.3
	rm -rf -- "$rigTmp"
}
trap 'rigReap' EXIT
mkdir -p "$rigWs/.local/agents/sessions/$rigSession" "$rigTmp/home" "$rigWs/.local/temp" || rigRefuse "the rig could not be made: $rigTmp"
printf '%s\n' "CRIGPOLL01:1793750000.000100" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## A block posted into the session's chat file, through the chat include's own writer, with the rig as the workspace.
rigSay(){ ## ts, body
	( unset MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT harnessAgent ; export MMDAPP="$rigWs" ; . "$rigPkg/sh-lib/session/AgentsTools.SessionChat.include" ; printf '%s' "$2" | AgentsToolsSessionChatAppend "$rigSession" keeper-rig all "$1" "CRIGPOLL01:1793750000.000100" slack > /dev/null ) \
		|| rigRefuse "the rig could not post into the chat of $rigSession"
}
## One call through the tool task as a tool call runs it, a second a poll, with the floor stood in for by a stamp in the file named: the
## seconds the watcher read it at, one a line. The call is the founder of the session, so the floor is the whole thread.
rigCall(){ ## stamps file, body
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT="magic-coordinator" MDAT_TOOL_TASK_POLL=1 MDAT_TOOL_TASK_SECONDS=60 \
		MDAT_TOOL_TASK_CEILING=90 MDAT_COMMS_READER=off RIG_STAMPS="$1" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ; AgentsToolsSessionChatFloor(){ printf "%s\n" "$SECONDS" >> "$RIG_STAMPS" ; } ; rigBody(){ eval "$1" ; } ; AgentsToolsTaskCall "rig poll" "" "" "" rigBody "$2" ; printf "%s|%s\n" "$agentsTaskDetached" "$agentsTaskOut"' \
		rig "$1" "$2" 2>&1
}
## How many stamps a file holds that are of the third second or later.
rigLate(){ ## stamps file
	local lateCount=0 lateStamp
	while IFS= read -r lateStamp ; do
		[ "$lateStamp" -lt 3 ] || lateCount=$(( lateCount + 1 ))
	done < "$1"
	printf '%s' "$lateCount"
}

rigSay 1793750000.000101 "RIG-BEFORE the first call of this session"
## The chat is older than the first read by more than a second, so no write of the rig's own reads as a change.
sleep 2

echo "-- 1. a quiet chat: the floor is not read at every poll --"
: > "$rigTmp/quiet.stamps"
rigOut="$( rigCall "$rigTmp/quiet.stamps" 'sleep 9' )"
rigAssert "the call ended in its own time" "${rigOut%%|*}" "no"
rigAssert "the watcher read the floor no more once the first polls were past" "$( rigLate "$rigTmp/quiet.stamps" )" "0"

echo "-- 2. the control: a post while the call runs is read --"
: > "$rigTmp/post.stamps"
( sleep 5 ; rigSay 1793750000.000201 "RIG-DURING a message written while the call runs" ) &
rigOut="$( rigCall "$rigTmp/post.stamps" 'sleep 10' )" ; wait
rigAssert "the call ended in its own time" "${rigOut%%|*}" "no"
rigAssert "the watcher read the floor again after the post" "$( [ "$( rigLate "$rigTmp/post.stamps" )" -ge 1 ] && printf yes || printf no )" "yes"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TOOL TASK POLL BOUND CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_TASK_POLL_BOUND: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
