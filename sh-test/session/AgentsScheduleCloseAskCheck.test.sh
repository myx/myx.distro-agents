#!/usr/bin/env bash
## Behavioural check on the ask a session's CLOSE makes of the schedule thread: closing a run changes the running
## registry, so a dead thread is asked for there and the duties go on with no console and no person in the loop.
##
## The close is the real AgentsToolsSpawnProxyCloseSandbox. The steps of the close either side of its ask are stand-ins of
## this rig's own, so what is measured is the ask alone and nothing of it touches a process or a store.
##
## Held, and not read:
##   1. A close beside a dead thread asks the schedule thread once.
##   2. The same close beside a LIVE thread asks for nothing, and leaves that thread alone.
##   3. The same close under MDAT_SCHEDULE_THREAD=off asks for nothing.
## Red recipe: with the ask's block removed from AgentsToolsSpawnProxyCloseSandbox, section 1 fails and sections 2 and 3
## pass.
## Offline: a rig folder of its own, stand-ins of its own, no agent CLI on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/spawn/AgentsTools.SpawnProxyClose.include" ] || rigRefuse "the spawn close's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleCloseAskCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null || :' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigTmpBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/agents/schedule-thread" "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigTmpBin" "$rigTmp/data"
rigRecord="$rigTmp/data/spawned/rig-session/rig-run.md"
mkdir -p "${rigRecord%/*}" ; printf -- '---\nstatus: spawn-started\nowner: rig-member\nsession-id: rig-session\nspawn-id: rig-run\n---\n' > "$rigRecord"

rigCall(){ ## -- how many asks the close made
	: > "$rigTmp/asks"
	env -i HOME="$rigHome" PATH="$rigTmpBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig \
		RIG_ASKS="$rigTmp/asks" RIG_RECORD="$rigRecord" ${rigThreadOff:+MDAT_SCHEDULE_THREAD=off} \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnProxyClose.include" || exit 90
			## Stand-ins for every step of the close but its ask.
			AgentsToolsFrontmatterKey(){ case "$2" in status) printf "spawn-started\n" ;; esac ; }
			AgentsToolsSpawnProxyParkClear(){ return 0 ; }
			AgentsToolsSpawnProxyCloseSettled(){ return 1 ; }
			AgentsToolsSpawnProxyWithdrawAsks(){ return 0 ; }
			AgentsToolsSpawnProxyChildrenDismiss(){ return 0 ; }
			AgentsToolsSpawnProxyCloseSandboxOnce(){ return 0 ; }
			AgentsToolsSpawnProxyRootMarks(){ return 0 ; }
			AgentsToolsSpawnSandboxReleaseCopies(){ return 0 ; }
			AgentsToolsSessionSeatRelease(){ return 0 ; }
			## THE INCLUDE COMES FIRST, because the close sources it lazily inside its ask. A stand-in defined before
			## that load is overwritten by the include own definition, and the row would read zero for that reason alone.
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 92
			AgentsToolsScheduleThreadAsk(){ printf "ask\n" >> "$RIG_ASKS" ; return 0 ; }
			AgentsToolsSpawnProxyCloseSandbox "$RIG_RECORD" ended 0 "rig end" > /dev/null 2>&1
		' rig > /dev/null 2>&1
	printf '%s' "$( LC_ALL=C grep -c '^ask$' "$rigTmp/asks" 2> /dev/null | LC_ALL=C head -1 )"
}

echo "-- 1. a close beside a dead thread asks for it once --"
rigAssert "the close of a run asks the schedule thread once" "$( rigCall )" 1

echo "-- 2. a close beside a live thread asks for nothing, and leaves it alone --"
## A live holder of this rig's own, in the thread's own shape: `<pid> <start of that process>`. The checker's own shell is
## that process, so nothing of the host is read and no thread is started.
rigStart="$( ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )"
printf '%s %s\n' "$$" "$rigStart" > "$rigWs/.local/agents/schedule-thread/thread.lock"
rigAsksLive="$( rigCall )"
rigAssert "a close beside a live thread asks for nothing" "$rigAsksLive" 0
rigAssert "and the live holder's lock is still there" "$( [ -s "$rigWs/.local/agents/schedule-thread/thread.lock" ] && printf held || printf gone )" held
rigAssert "and that holder is still this process" \
	"$( [ "$( cut -d' ' -f1 < "$rigWs/.local/agents/schedule-thread/thread.lock" )" = "$$" ] && printf same || printf other )" same
rm -f "$rigWs/.local/agents/schedule-thread/thread.lock"

echo "-- 3. the same close under MDAT_SCHEDULE_THREAD=off asks for nothing --"
rigThreadOff=yes ; rigAsksOff="$( rigCall )" ; rigThreadOff=""
rigAssert "a close under MDAT_SCHEDULE_THREAD=off asks for nothing" "$rigAsksOff" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE CLOSE ASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_CLOSE_ASK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
