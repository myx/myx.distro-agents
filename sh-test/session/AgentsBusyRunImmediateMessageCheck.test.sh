#!/usr/bin/env bash
## Behavioural check on S13.11 of `20261102-refactorings.epic.md`: "A run busy in tool calls, such as a test poll, learns of an
## immediate message for it at its next tool result, not only at its next Wait." Run rather than read, through
## `AgentsToolsTaskCall` (sh-lib/session/AgentsTools.ToolTask.include) on a rig session of its own. Held:
##   1. a run that founds its session learns of a message posted to that session's thread while it is inside one long call:
##      the call returns early and says why, the thread being the executor's own floor whatever the message is addressed to
##   2. the control a participant gives: the same message, in a session the run only takes part in, does not return its call
##      early, since nothing of it is that run's floor
##   3. the control a mention gives: a participant is returned early by a message that names it, so 2 is the rule and not a
##      probe that never fires
##   4. nothing is consumed: the message is still the member's floor afterwards, so the next tool result and the next Wait
##      each carry it once
## Red before S13.11: the probe reads the thread with the filter `me` alone, so a message addressed to `all` in the executor's
## own session thread never returns its call early, and 1 fails.
## Offline: a rig workspace and a rig session, every call through `env -i`; nothing of this check outlives it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPkg/sh-lib/session/AgentsTools.ToolTask.include"
rigChatInclude="$rigPkg/sh-lib/session/AgentsTools.SessionChat.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the tool task include is not in the package: $rigInclude"
[ -f "$rigChatInclude" ] || rigRefuse "the session chat include is not in the package: $rigChatInclude"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBusyRunImmediateMessageCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
rigThread="CRIGBUSY01:1793750000.000100"
rigTeam="rig-busy-team"
rigSolo="rig-busy-solo"
rigProc="$rigWs/.local/agents/sessions/$rigTeam/processes"
rigPids=""
rigReap(){
	local reapOne reapFile reapPid
	for reapFile in "$rigProc"/*.pid "$rigWs/.local/agents/sessions/$rigSolo/processes"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	sleep 0.3
	for reapOne in $rigPids ; do kill -KILL "$reapOne" 2> /dev/null ; done
	rm -rf -- "$rigTmp"
}
trap 'rigReap' EXIT
mkdir -p "$rigWs/.local/agents/sessions/$rigTeam" "$rigWs/.local/agents/sessions/$rigSolo" "$rigTmp/home" "$rigWs/.local/temp" \
	|| rigRefuse "the rig could not be made: $rigTmp"
printf '%s\n' "$rigThread" > "$rigWs/.local/agents/sessions/$rigTeam/session.thread"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## A block posted into a session's chat file, through the chat include's own writer, with the rig as the workspace.
rigSay(){ ## session, from, to, ts, body
	( unset MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT harnessAgent ; export MMDAPP="$rigWs" ; . "$rigChatInclude" ; printf '%s' "$5" | AgentsToolsSessionChatAppend "$1" "$2" "$3" "$4" "$rigThread" slack > /dev/null ) \
		|| rigRefuse "the rig could not post into the chat of $1"
}
## What a member's floor holds now, read and not delivered. The check's own session is not this rig's, so nothing of it is read.
rigFloor(){ ## session, member
	( unset MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT harnessAgent ; export MMDAPP="$rigWs" ; . "$rigChatInclude" ; AgentsToolsSessionChatFloor "$1" "$2" 2> /dev/null ) || :
}
## A member's floor started where the file stands now: what is there already is not new to it, as a run's own start is.
rigFloorStart(){ ## session, member
	( unset MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT harnessAgent ; export MMDAPP="$rigWs" ; . "$rigChatInclude" ; AgentsToolsSessionChatReaderInit "$1" "$2" ) || rigRefuse "the floor of $2 in $1 could not be started"
}
## One call through the tool task, exactly as a tool call runs: label, background, timeout, action, session, run id, member, body. The run
## id is the run's own, and the session is the one it works in: a run whose id is the session's founds it, and any other is a participant.
rigCall(){ ## label, background, timeout, action, session, run id, member, body
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$5" MDAT_SPAWN_SESSION_ID="$6" MDAT_SPAWN_AGENT="$7" MDAT_TOOL_TASK_POLL=1 MDAT_TOOL_TASK_SECONDS=60 \
		MDAT_TOOL_TASK_CEILING=90 MDAT_COMMS_READER=off \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ; rigBody(){ eval "$1" ; } ; AgentsToolsTaskCall "$1" "$2" "$3" "$4" rigBody "$5" ; printf "%s|%s\n%s\n" "$agentsTaskDetached" "$agentsTaskHandle" "$agentsTaskOut"' \
		rig "$1" "$2" "$3" "$4" "$8" 2>&1
}
rigHead(){ printf '%s\n' "$1" | LC_ALL=C sed -n 1p ; }
## A call left running is ended, so no polling helper outlives this check.
rigEndCall(){ ## handle, session
	local endPid
	[ -f "$rigWs/.local/agents/sessions/$2/processes/$1.pid" ] || return 0
	endPid="$( head -1 "$rigWs/.local/agents/sessions/$2/processes/$1.pid" )"
	[ -z "$endPid" ] || kill -TERM -- "-$endPid" 2> /dev/null || kill -TERM "$endPid" 2> /dev/null || :
	return 0
}
## The helper a returned call left polling its message source is told to go, and a moment is given it, so the rig's tree can go whole.

## THE RIG'S FIRST MESSAGE, posted before any call: what a member's floor holds at its own start is not new to it.
rigSay "$rigTeam" keeper-rig all 1793750000.000101 "RIG-BEFORE the first call of this session"
rigFloorStart "$rigTeam" magic-coordinator
rigFloorStart "$rigTeam" keeper-myx

echo "-- 1. a busy executor learns of a message in its own session thread --"
( sleep 2 ; rigSay "$rigTeam" keeper-rig all 1793750000.000201 "RIG-TO-ALL a message of the session thread" ) &
rigOut="$( rigCall "rig busy" "" "" "" "$rigTeam" "$rigTeam" magic-coordinator 'sleep 30' )" ; wait
rigAssert "the call of the session's own founder returns early" "$( rigHead "$rigOut" | cut -d'|' -f1 )" "yes"
rigAssert "and it says a message arrived for it" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'a message for you arrived in the session chat' )" "1"
rigEndCall "$( rigHead "$rigOut" | cut -d'|' -f2 )" "$rigTeam"

echo "-- 2. nothing is consumed: the message is still the member's floor --"
rigAssert "the message the call returned on is still the floor of the run" "$( rigFloor "$rigTeam" magic-coordinator | LC_ALL=C grep -c 'RIG-TO-ALL' )" "1"

echo "-- 3. the control a participant gives: a message naming nobody is not its floor --"
( sleep 2 ; rigSay "$rigTeam" keeper-rig all 1793750000.000301 "RIG-TO-ALL-AGAIN for the session, naming nobody" ) &
rigOut="$( rigCall "rig busy" "" "" "" "$rigTeam" rig-part-1 keeper-myx 'sleep 12' )" ; wait
rigAssert "a participant's call that outlasts the message is not returned by it" "$( rigHead "$rigOut" | cut -d'|' -f1 )" "no"
rigAssert "and it says nothing of a message" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'a message for you arrived' )" "0"

echo "-- 4. the control a mention gives: a participant is returned by a message that names it --"
( sleep 2 ; rigSay "$rigTeam" keeper-rig keeper-myx 1793750000.000401 "RIG-FOR-YOU @keeper-myx please look" ) &
rigOut="$( rigCall "rig busy" "" "" "" "$rigTeam" rig-part-2 keeper-myx 'sleep 30' )" ; wait
rigAssert "the participant's call returns early on a message that names it" "$( rigHead "$rigOut" | cut -d'|' -f1 )" "yes"
rigEndCall "$( rigHead "$rigOut" | cut -d'|' -f2 )" "$rigTeam"
rigAssert "and that message is still its floor too" "$( rigFloor "$rigTeam" keeper-myx | LC_ALL=C grep -c 'RIG-FOR-YOU' )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ BUSY RUN IMMEDIATE MESSAGE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'BUSY_RUN_IMMEDIATE_MESSAGE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
