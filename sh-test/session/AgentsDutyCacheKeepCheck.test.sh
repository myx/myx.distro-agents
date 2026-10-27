#!/usr/bin/env bash
## Behavioural check that a work-duty is NEVER STARTED TO KEEP A CACHE WARM (sketch 7.3, 10.4; it replaces the cache-keep restart of T1 of the
## 20261021 refactorings epic): the cache is kept inside the running session by the keepalive of its --idle-wait. AgentsToolsScheduleWorkDuty, sh-lib/session/AgentsTools.DispatcherLoop.include, taken at each iteration of --intern-main-loop). The real
## loop (--one) and the real spawner run, as in AgentsScheduleLoopCheck; the console, curl, date and every setting are this rig's own.
## GUARD: every tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's
## tree and PATH holds no agent CLI. Held:
##   0. LAZY START STANDS. A member with nothing to work on and no earlier duty holds none, whatever the cache-keep interval.
##   1. THE FIRST ITEM STARTS IT. The item starts the duty (demand), and before the interval, with the item gone, it is not started again.
##   2. NO CACHE-KEEP RESTART. Long after the old cache-keep interval, with no input, an ended duty is not started again, and neither is a member
##      that never held a duty.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRealTemplate="$rigPackage/sh-lib/templates/spawn-brief.document.format.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyCacheKeepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rigRemoveTree' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
## keeper-rig-01 holds the rig's autoruns; keeper-rig-02 is the member of the cases, keeper-rig-03 never holds a duty.
rigScheduleSetup 3
## Monday 2026-10-19 in Etc/GMT-3: 13:00 (worktime).
rigMon13=1792404000
rigAt "$rigMon13"

echo "-- 0. the lazy start stands --"
rigOneRun idle0 ; rigWaitStarts
rigAssert "worktime, no item, never held a duty: no duty of keeper-rig-02, and no cache-keep line for it" "$( rigDutyCount keeper-rig-02 ):$( rigSaid idle0 'work-duty: started the duty of keeper-rig-02' )" "0:0"

echo "-- 1. the first item starts it, and with the item gone it is not started again --"
rigItem keeper-rig-02
rigAt $(( rigMon13 + 20 ))
rigOneRun start0 ; rigWaitStarts
rigAssert "the item arrives: the duty of keeper-rig-02 is started" "$( rigSaid start0 'work-duty: started the duty of keeper-rig-02' )" "1"
rm -f "$rigData/inboxes/keeper-rig-02/incoming/note-20261019T0900Z-rig-work.md"
rigAt $(( rigMon13 + 40 ))
rigOneRun keep0 ; rigWaitStarts
rigAssert "twenty seconds on, the item gone: the ended duty is not warmed again inside the interval" "$( rigSaid keep0 'work-duty: started the duty of keeper-rig-02' )" "0"

echo "-- 2. after the old cache-keep interval, no input: nothing is started --"
rigAt $(( rigMon13 + 20 + 300 ))
rigOneRun keep1 ; rigWaitStarts
rigAssert "the old cache-keep interval has passed: the ended duty is not started again to keep its cache warm" "$( rigSaid keep1 'work-duty: started the duty of keeper-rig-02' )" "0"
rigAssert "keeper-rig-03, which never held a duty, is not started either" "$( rigSaid keep1 'work-duty: started the duty of keeper-rig-03' ):$( rigDutyCount keeper-rig-03 )" "0:0"

echo "-- 3. worktime over: the session the duty kept for its restarts goes --"
mkdir -p "$rigWs/.local/agents/schedule/duty-session" && printf 'rig-kept-session\n' > "$rigWs/.local/agents/schedule/duty-session/keeper-rig-02"
rigAt $(( rigMon13 + 20 + 400 ))
rigOneRun inflags ; rigWaitStarts
rigAssert "within worktime, with no duty running: the kept session stays" "$( cat "$rigWs/.local/agents/schedule/duty-session/keeper-rig-02" 2> /dev/null )" "rig-kept-session"
rigAt $(( rigMon13 + 36000 ))
rigOneRun night ; rigWaitStarts
rigAssert "worktime is over: the kept session is gone, so the next worktime opens a session of its own" "$( [ -e "$rigWs/.local/agents/schedule/duty-session/keeper-rig-02" ] && echo kept || echo gone )" "gone"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY CACHE-KEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_CACHE_KEEP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
