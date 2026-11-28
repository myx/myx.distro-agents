#!/usr/bin/env bash
## Behavioural check of the session chat floor on a tool return (AgentsToolsSessionChatFloor, AgentsToolsSessionChatPointer): every
## tool return of every run asks it, so with nothing new it starts no process; its pointers and its block count are read by builtins.
## Held:
##   1. nothing new: the floor starts no process
##   2. control: a new block does start the floor's own read, so the trace sees a process where one runs
##   3. the pointer reads answer as before: a missing reader is rc 1, the last line kept for a reader wins, a member's reader is read
##      from the member's own pointers, and a line with no value answers an empty one
## Red before the change: each floor runs an awk for every pointer it reads, and wc and tr to count the blocks.
## Offline: a rig workspace of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChatFloorForkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
rigSession="rig-session-1"
mkdir -p "$rigWs/.local/agents/sessions/$rigSession" "$rigWs/.local/agents/member-pointers" || exit 1
printf 'one\ntwo\n' > "$rigWs/.local/agents/sessions/$rigSession/session.chat.index" || exit 1
: > "$rigWs/.local/agents/sessions/$rigSession/session.chat" || exit 1
printf 'dms:alpha\t5\ndms:alpha\t7\nbare:alpha\n' > "$rigWs/.local/agents/member-pointers/alpha.pointers" || exit 1

## One floor read, traced: prints the processes the floor started.
rigFloor(){ ## the read pointer of the rig member
	printf 'read:alpha\t%s\n' "$1" > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers" || exit 1
	MMDAPP="$rigWs" bash -c '
		. "$1/sh-lib/session/AgentsTools.SessionChat.include" > /dev/null 2>&1 || exit 1
		type AgentsToolsSessionChatFloor > /dev/null 2>&1 || exit 1
		PS4="+\${FUNCNAME[0]}: " ; set -x
		AgentsToolsSessionChatFloor "$2" alpha > /dev/null
		set +x
	' rig "$rigPkg" "$rigSession" 2>&1 | LC_ALL=C awk '/^\++[A-Za-z]*: (LC_ALL=C )?(awk|wc|tr|sed|head|date|cat|mktemp|rm|grep)( |$)/ { n++ } END { print n + 0 }'
}

echo "-- 1. nothing new: no process --"
rigAssert "the floor with its pointer at the last block starts no process" "$( rigFloor 2 )" 0
echo "-- 2. control: a new block starts the floor's own read --"
rigAssert "the floor with a block past its pointer starts its read" "$( [ "$( rigFloor 1 )" -gt 0 ] && echo started || echo none )" started

echo "-- 3. the pointer reads answer as before --"
rigPointers="$( MMDAPP="$rigWs" bash -c '
	. "$1/sh-lib/session/AgentsTools.SessionChat.include" > /dev/null 2>&1 || exit 1
	printf "read:alpha\t3\nread:alpha\t4\n" > "$MMDAPP/.local/agents/sessions/$2/session.chat.pointers"
	printf "last=%s\n" "$( AgentsToolsSessionChatPointer "$2" read:alpha )"
	AgentsToolsSessionChatPointer "$2" read:nobody > /dev/null ; printf "missing=%s\n" "$?"
	printf "member=%s\n" "$( AgentsToolsSessionChatPointer "$2" dms:alpha )"
	printf "bare=[%s] rc=" "$( AgentsToolsSessionChatPointer "$2" bare:alpha )" ; AgentsToolsSessionChatPointer "$2" bare:alpha > /dev/null ; printf "%s\n" "$?"
' rig "$rigPkg" "$rigSession" 2>&1 )"
rigAssert "the last line kept for a reader wins" "$( printf '%s\n' "$rigPointers" | LC_ALL=C sed -n 's/^last=//p' )" 4
rigAssert "a reader with no line is rc 1" "$( printf '%s\n' "$rigPointers" | LC_ALL=C sed -n 's/^missing=//p' )" 1
rigAssert "a member's reader is read from the member's pointers" "$( printf '%s\n' "$rigPointers" | LC_ALL=C sed -n 's/^member=//p' )" 7
rigAssert "a line with no value answers an empty value, found" "$( printf '%s\n' "$rigPointers" | LC_ALL=C sed -n 's/^bare=//p' )" "[] rc=0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION CHAT FLOOR FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_FLOOR_FORK: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
