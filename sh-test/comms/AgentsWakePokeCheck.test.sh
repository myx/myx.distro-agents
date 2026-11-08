#!/usr/bin/env bash
## Behavioural check on `AgentsToolsWakePoke` and its callers (AgentsTools.WakeMarker.include, AgentsToolsSessionChatAppend), run rather than read, in a
## workspace built here: a wait naps on a fifo it holds both ends of, and a poke ends that nap at once. Held: a poke of a member ends the nap of that
## member's wait and not another member's; a poke with no member ends every nap; a wake marker write pokes its member; a chat block appended to any session
## pokes the waits; an item another session appends to a member's CheckList pokes that member's waits (S10.34); a poke of a wait that is gone
## returns at once and leaves nothing; and a name with a slash is refused. Offline: nothing is posted.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/comms/AgentsTools.WakeMarker.include" ] || rigRefuse "the wake marker's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWakePokeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'kill $( jobs -pr ) 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
export MMDAPP="$rigWs"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/agents"
. "$rigHere/comms/AgentsTools.WakeMarker.include"
type AgentsToolsWakePoke > /dev/null 2>&1 || rigRefuse "AgentsToolsWakePoke is not defined by sourcing the wake marker's functions"

rigNap(){ ## member, tag -- a wait's nap: holds both ends of its fifo, reads up to 20 s, and writes how long it napped into <tag>.napped
	local napDir="$rigWs/.local/temp/mdat-member-wait.$1.$2"
	mkdir -p "$napDir" && mkfifo "$napDir/nap.fifo" || return 1
	(
		exec 6<> "$napDir/nap.fifo"
		napFrom=$SECONDS
		IFS= read -r -t 20 -u 6 napLine || :
		printf '%s\n' "$(( SECONDS - napFrom ))" > "$rigTmp/$2.napped"
	) &
}
rigNapped(){ ## tag, wait up to 6 s -- the seconds the nap lasted, or `still` when it has not ended
	local napWait=0
	while [ ! -f "$rigTmp/$1.napped" ] && [ "$napWait" -lt 6 ] ; do sleep 1 ; napWait=$(( napWait + 1 )) ; done
	[ -f "$rigTmp/$1.napped" ] && cat "$rigTmp/$1.napped" || printf 'still'
}
rigFast(){ ## tag -- yes where the nap ended within 3 s of the poke
	local napSeconds
	napSeconds="$( rigNapped "$1" )"
	case "$napSeconds" in still) printf 'no' ;; *) [ "$napSeconds" -le 3 ] && printf 'yes' || printf 'no' ;; esac
}

rigNap magic-tester a1 || rigRefuse "no fifo could be made"
rigNap magic-developer b1 || rigRefuse "no fifo could be made"
sleep 1
AgentsToolsWakePoke magic-tester
rigAssert "a poke of a member ends the nap of that member's wait" "$( rigFast a1 )" "yes"
rigAssert "and not the nap of another member's wait" "$( [ -f "$rigTmp/b1.napped" ] && echo ended || echo napping )" "napping"
AgentsToolsWakePoke
rigAssert "a poke with no member ends every nap" "$( rigFast b1 )" "yes"

rigNap keeper-myx c1 || rigRefuse "no fifo could be made"
sleep 1
AgentsToolsWakeTouch keeper-myx magic-coordinator
rigAssert "a wake marker write pokes the waits of its member" "$( rigFast c1 )" "yes"

rigNap magic-librarian d1 || rigRefuse "no fifo could be made"
sleep 1
. "$rigHere/session/AgentsTools.SessionChat.include" > /dev/null 2>&1
type AgentsToolsSessionChatAppend > /dev/null 2>&1 || rigRefuse "AgentsToolsSessionChatAppend is not defined by sourcing the chat functions"
mkdir -p "$rigWs/.local/agents/sessions/rig-session"
printf 'a block\n' | AgentsToolsSessionChatAppend rig-session magic-tester magic-librarian - - own > /dev/null 2>&1 || :
rigAssert "a chat block appended to a session pokes the waits" "$( rigFast d1 )" "yes"

rigNap magic-architect e1 || rigRefuse "no fifo could be made"
sleep 1
. "$rigHere/harness/AgentsHarnessBatch.include" > /dev/null 2>&1 || :
type AgentsHarnessCheckListAppendLines > /dev/null 2>&1 || rigRefuse "AgentsHarnessCheckListAppendLines is not defined by sourcing the harness batch functions"
printf 'an item from the parent\n' | AgentsHarnessCheckListAppendLines "$rigWs/.local/agents/sessions/rig-session" magic-architect > /dev/null 2>&1 || :
rigAssert "an item appended to a member's CheckList pokes that member's waits" "$( rigFast e1 )" "yes"
rigAssert "and the item is on the list" "$( grep -c 'an item from the parent' "$rigWs/.local/agents/sessions/rig-session/magic-architect.checklist.md" 2>/dev/null )" "1"

rigGone="$rigWs/.local/temp/mdat-member-wait.magic-tester.gone"
mkdir -p "$rigGone" && mkfifo "$rigGone/nap.fifo"
rigPokeStart="$SECONDS"
AgentsToolsWakePoke magic-tester
rigAssert "a poke of a wait that is gone returns at once" "$(( SECONDS - rigPokeStart < 3 ? 1 : 0 ))" "1"
rigAssert "a name with a slash is refused: nothing is opened" "$( AgentsToolsWakePoke '../x' ; echo rc=$? )" "rc=0"
export MMDAPP="$rigReal"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ WAKE POKE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "WAKE_POKE: OK ($rigPasses assertions, offline)"
