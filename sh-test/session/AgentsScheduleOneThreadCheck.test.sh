#!/usr/bin/env bash
## Behavioural check on the two faults that let more than one schedule thread serve one rig (owner's measurement of 2026-11-04, 15 `--intern-schedule
## --run` processes alive at 3 to 32 minutes of age):
##   1. A SECOND SERVE OF THE SAME FOLDER ENDS AT ONCE. `AgentsToolsOnDemandThreadServe` takes the lock for the life of its process, and a serve that
##      finds another live holder says so and returns 1. The check drives the real function twice against one folder and counts what runs.
##      The pid a row signals is always the one the folder's lock names: a started thread is a process of its own, and the shell that started it is
##      only that process's parent, so a TERM to the parent ends the parent and leaves the thread holding the lock.
##   2. A TERM ENDS A SERVING THREAD. The serve loop's TERM trap sets the end flag, and the loop leaves at its next pass. The check sends TERM to a
##      real serve and waits for it to be gone.
## 3. AND THE SCHEDULE'S OWN OPERATION CARRIES BOTH: a second `--intern-schedule --run` on a folder where one serves exits 1 at once, and a TERM to
##    that serve ends it. The real operation runs, over a rig of this check's own.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found"
[ -f "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" ] || rigRefuse "the shared thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleOneThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
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
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/store/board" || exit 1
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/store" MDLT_ORIGIN="$MDLT_ORIGIN"
cd "$rigWs" || exit 1
set -- check
. "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" || rigRefuse "the shared thread's include would not load"

echo "-- 1. a second serve of one folder ends at once --"
rigFolder="$rigTmp/folder"
mkdir -p "$rigFolder" || exit 1
## A handler that says it was called, and a tick that does nothing: the serve's own life is what is measured.
rigHandler(){ : ; }
## The first serve, detached, in a process of its own.
(
	. "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" 2> /dev/null || exit 9
	rigHandler(){ : ; }
	AgentsToolsOnDemandThreadServe "$rigFolder" 600 rigHandler - no
) > "$rigTmp/serve1.log" 2>&1 &
rigServe1=$!
rigStarted="$rigStarted $rigServe1"
rigLeft=100
while [ "$rigLeft" -gt 0 ] && [ ! -f "$rigFolder/thread.lock" ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the first serve holds the folder's lock" "$( [ -s "$rigFolder/thread.lock" ] && printf held )" "held"
## The second serve, in the foreground: it must say why and return 1.
(
	. "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" 2> /dev/null || exit 9
	rigHandler(){ : ; }
	AgentsToolsOnDemandThreadServe "$rigFolder" 600 rigHandler - no
) > "$rigTmp/serve2.out" 2> "$rigTmp/serve2.err"
rigSecondRc=$?
rigAssert "a second serve of the same folder returns 1 at once, and says a thread already runs" \
	"$rigSecondRc:$( LC_ALL=C grep -c -F 'a second one is not started' "$rigTmp/serve2.err" 2> /dev/null || : )" "1:1"
rigAssert "and the first serve still runs" "$( kill -0 "$rigServe1" 2> /dev/null && printf alive )" "alive"

echo "-- 2. a TERM ends a serving thread --"
kill -TERM "$rigServe1" 2> /dev/null || :
rigLeft=100
while [ "$rigLeft" -gt 0 ] && kill -0 "$rigServe1" 2> /dev/null ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the serving thread is gone within ten seconds of its TERM" "$( kill -0 "$rigServe1" 2> /dev/null && printf alive || printf gone )" "gone"
wait "$rigServe1" 2> /dev/null || :
rigAssert "and it gave its lock back" "$( [ -s "$rigFolder/thread.lock" ] && printf held )" ""

echo "-- 3. the schedule's own operation carries both --"
rigSch="$rigWs/.local/agents/schedule-thread"
(
	cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/store" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" --intern-schedule --run
) > "$rigTmp/sch1.log" 2>&1 &
rigStarted="$rigStarted $!"
## THE THREAD IS THE PROCESS ITS LOCK NAMES, and the shell that started it is only that process's parent: a TERM to the parent leaves the thread
## serving with the lock still held, which is measured in this check's own comment below. So the pid to signal is read from the lock, and the start
## line that follows the lock by a moment is waited for, never asserted on the instant.
rigLeft=150
while [ "$rigLeft" -gt 0 ] && [ ! -s "$rigSch/thread.lock" ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigSchThread="$( LC_ALL=C awk '{ print $1 }' "$rigSch/thread.lock" 2> /dev/null )"
rigStarted="$rigStarted $rigSchThread"
rigLeft=150
while [ "$rigLeft" -gt 0 ] && ! LC_ALL=C grep -q -F 'the thread runs as pid' "$rigSch/thread.log" 2> /dev/null ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "a first --intern-schedule --run takes the lock, and its own log says it serves" \
	"$( [ -s "$rigSch/thread.lock" ] && printf held ):$( LC_ALL=C grep -c -F 'the thread runs as pid' "$rigSch/thread.log" 2> /dev/null || : )" "held:1"
(
	cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/store" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" --intern-schedule --run
) > "$rigTmp/sch2.log" 2> "$rigTmp/sch2.err"
rigSch2Rc=$?
rigAssert "a second --intern-schedule --run on that folder ends at once with 1, and the log names the holder" \
	"$rigSch2Rc:$( LC_ALL=C grep -c -F 'a second one is not started' "$rigSch/thread.log" 2> /dev/null || : )" "1:1"
kill -TERM "$rigSchThread" 2> /dev/null || :
rigLeft=200
while [ "$rigLeft" -gt 0 ] && kill -0 "$rigSchThread" 2> /dev/null ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "a TERM ends that serving thread, and its log says how it ended" \
	"$( kill -0 "$rigSchThread" 2> /dev/null && printf alive || printf gone ):$( LC_ALL=C grep -c -F 'ends: it was ended by TERM' "$rigSch/thread.log" 2> /dev/null || : )" "gone:1"
rigAssert "and it gave its lock back" "$( [ -s "$rigSch/thread.lock" ] && printf held )" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE ONE THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_ONE_THREAD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
