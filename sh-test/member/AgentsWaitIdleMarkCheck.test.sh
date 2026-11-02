#!/usr/bin/env bash
## Behavioural check on S27.4: a run that waits on its floor alone reads `idling`, one that waits on a source it named reads `waiting`.
## A Wait writes `idle` over its own `tool Wait` activity mark when every source it waits on is the floor (replies, chat, dms,
## mentions, wake, the scans, the session's own threads). A Wait naming any other source, an ask, a process or a thread leaves the
## mark as it is. A mark that is not `tool Wait`, and a run with no mark, are never touched.
## Offline: the workspace is this rig's own temp tree. No socket.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/member/AgentsTools.MemberWait.include" ] || rigRefuse "the Wait include is not at the origin"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitIdleMarkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigMark="$rigWs/.local/agents/sessions/rig-run/activity"
mkdir -p "$rigWs/.local/agents/sessions/rig-run" "$rigWs/.local/.agents"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWait(){ ## mark line (empty: no mark), the sources of the wait -- the round and the word the mark holds after the call
	rm -f "$rigMark"
	[ -z "$1" ] || printf '%s\n' "$1" > "$rigMark"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-run \
		bash -c '. "$1" ; . "$2" ; AgentsWaitActivityIdle "$3"' rig "$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include" "$rigPkg/sh-lib/member/AgentsTools.MemberWait.include" "$2" > /dev/null 2>&1
	[ -f "$rigMark" ] || { echo "no mark" ; return 0 ; }
	LC_ALL=C awk '{ w = $0 ; sub(/^[^ ]* [^ ]* /, "", w) ; print $1 " " w }' "$rigMark"
}

echo "-- a wait on its floor alone is idle --"
rigAssert "the floor of a session (chat, dms, mentions, wake) and the work-duty scan: idle, the round kept" "$( rigWait '7 100 tool Wait' 'chat:rig-run dms:keeper-x mentions:keeper-x wake:keeper-x scan:work-duty ' )" "7 idle"
rigAssert "the two team conversations of a run with no session thread: idle" "$( rigWait '8 100 tool Wait' 'slack:magic-team slack:human-owner dms:keeper-x ' )" "8 idle"
echo "-- a wait on a named source is waiting --"
rigAssert "a thread that is not the session's own stays tool Wait" "$( rigWait '7 100 tool Wait' 'chat:rig-run slack:C0RIG00001:1700000000.000100:conversation dms:keeper-x ' )" "7 tool Wait"
rigAssert "an ask stays tool Wait" "$( rigWait '7 100 tool Wait' 'chat:rig-run ask:rig-pending-1 dms:keeper-x ' )" "7 tool Wait"
rigAssert "a process stays tool Wait" "$( rigWait '7 100 tool Wait' 'chat:rig-run process:process-3 ' )" "7 tool Wait"
echo "-- a mark that is not a Wait's is never touched --"
rigAssert "a run in another tool keeps its mark" "$( rigWait '7 100 tool Read' 'chat:rig-run ' )" "7 tool Read"
rigAssert "a thinking run keeps its mark" "$( rigWait '7 100 thinking' 'chat:rig-run ' )" "7 thinking"
rigAssert "a run with no mark gets none" "$( rigWait '' 'chat:rig-run ' )" "no mark"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WAIT IDLE MARK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_IDLE_MARK: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
