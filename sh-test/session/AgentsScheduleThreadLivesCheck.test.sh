#!/usr/bin/env bash
## Behavioural check that the schedule thread LIVES across a pass that has work to do (sketch 10.4: a thread lives until its idle bound, and its first
## pass ends none of it). A thread started in this check's own rig workspace takes its first pass at once, and the pass starts a routine that is due.
## The thread is then read for as long as it takes to say it ended: its log holds no end line, its lock still names the process that took it, and
## that process lives. The same readers are then put on a thread that was ended by TERM, so a green is a measurement.
## Held:
##   1. THE PASS HAD WORK: the due routine of the rig stands as a record the pass made, and the pass has ended (last-pass.times).
##   2. THE THREAD LIVED THROUGH IT: no `ends:` line in its log, the lock names the process it began with, and that process lives.
##   3. THE CONTROL: a thread ended by TERM reads as ended with the same readers: one `ends:` line, no lock, no live process.
## Offline, rig tree only. The thread is the real one (--intern-schedule --run), asked for the way the tooling asks; the console, curl, ps and date
## are the rig's own, and this check ends the thread it started through rig-control-threads.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's control-thread fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadLivesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
## The thread this check is about is started here, whatever the runner has switched off for the other threads of the tooling.
unset MDAT_SCHEDULE_THREAD
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; [ -n "${RIG_KEEP_TREE:-}" ] || rm -rf -- "$rigTmp"' EXIT
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
rigScheduleSetup 1
## Monday 2026-10-19 in Etc/GMT-3, 13:00: inside worktime, past the 09:00 of the rig's routines, so the auto routine of keeper-rig-01 is due.
rigAt 1792404000
rigThreadDir="$rigWs/.local/agents/schedule-thread"
## The pid the lock names, while that process lives; nothing otherwise.
rigThreadPid(){
	local pidLine="" pidNow
	{ IFS= read -r pidLine < "$rigThreadDir/thread.lock" || [ -n "$pidLine" ] ; } 2> /dev/null || return 0
	pidNow="${pidLine%% *}"
	case "$pidNow" in ''|*[!0123456789]*) return 0 ;; esac
	kill -0 "$pidNow" 2> /dev/null || return 0
	printf '%s\n' "$pidNow"
}
## How many lines of the thread's log say it ended, whatever the reason.
rigEndLines(){
	LC_ALL=C grep -c -E 'the thread, pid [0-9]+, ends:' "$rigThreadDir/thread.log" 2> /dev/null || :
}

echo "-- 1. a thread started in the rig takes a pass that has work --"
rigAskSaid="$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" RIG_TMP="$rigTmp" PKG="$rigPackage" bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
		! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
		. "$PKG/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 98
		cd "$MMDAPP" && AgentsToolsScheduleThreadAsk
	' rig < /dev/null 2>&1 )"
case "$rigAskSaid" in
	started\ *) ;;
	*) rigRefuse "the ask did not start the thread, so nothing below would be measured: $rigAskSaid" ;;
esac
rigPid="${rigAskSaid#started }" ; rigPid="${rigPid%% *}"
rigLeft=150
while [ "$rigLeft" -gt 0 ] ; do
	LC_ALL=C grep -q 'the thread runs as pid' "$rigThreadDir/thread.log" 2> /dev/null && break
	sleep 0.1 ; rigLeft=$(( rigLeft - 1 ))
done
[ "$rigLeft" -gt 0 ] || rigRefuse "the thread never said it runs, so nothing below would be measured"
## The pass ends when it writes last-pass.times; a rig on a loaded machine takes minutes over it, so the wait is bounded at two.
rigLeft=600
while [ "$rigLeft" -gt 0 ] && [ ! -s "$rigThreadDir/last-pass.times" ] ; do
	sleep 0.2 ; rigLeft=$(( rigLeft - 1 ))
done
[ -s "$rigThreadDir/last-pass.times" ] || rigRefuse "the thread's first pass never ended, so nothing below would be measured"
## The pass starts a routine in the background; its record stands once that start has ended.
rigWaitStarts
rigAssert "the pass had work: the due routine of the rig stands as a record the pass made" "$( rigRecordsOf keeper-rig-01.auto.routine.md )" "1"

echo "-- 2. the thread lives through it --"
## The serve loop reads its lock once a loop, a second: a thread that lost it says so within a few. The wait ends the moment it does.
rigLeft=60
while [ "$rigLeft" -gt 0 ] && [ "$( rigEndLines )" = 0 ] ; do
	sleep 0.1 ; rigLeft=$(( rigLeft - 1 ))
done
rigAssert "its log holds no end line" "$( rigEndLines )" "0"
rigAssert "its lock names the process it began with, and that process lives" "$( rigThreadPid )" "$rigPid"

echo "-- 3. the control: a thread ended by TERM reads as ended --"
kill -TERM "$rigPid" 2> /dev/null || :
rigLeft=150
while [ "$rigLeft" -gt 0 ] && [ "$( rigEndLines )" = 0 ] ; do
	sleep 0.1 ; rigLeft=$(( rigLeft - 1 ))
done
sleep 0.5
rigAssert "the same readers: one end line, no live process of the lock" "$( rigEndLines ):$( rigThreadPid )" "1:"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "  # the start and end lines of the thread log:" ; LC_ALL=C grep -E "ends:|started|runs as pid" "$rigThreadDir/thread.log" 2> /dev/null | LC_ALL=C cut -c1-200
	echo "⛔ SCHEDULE THREAD LIVES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD_LIVES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
