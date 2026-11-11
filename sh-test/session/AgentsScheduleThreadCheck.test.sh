#!/usr/bin/env bash
## Behavioural check on the schedule as one service thread (S12.12 of the refactorings epic): the schedule's steps and the board's dependencies run
## in a process of the tooling, asked for by the periodic places that already look at a workspace, and the main loop only makes sure it runs.
## The real operation (--intern-schedule), the real ask, the real spawner and one iteration of --intern-main-loop run. The console, curl, ps, date
## and every setting are this rig's own. GUARD: every tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and
## MDAT_DATA_ROOT sit under this rig's tree and PATH holds no agent CLI.
## Held:
##   1. THE OPERATION. A bare call prints its contract and starts nothing. `--one` makes one pass and ends, holding no lock.
##   2. THE PASS IS THE SCHEDULE'S STEPS. A routine due at 09:00, asked at 13:00 on a workday, is started by the pass through the spawner, with its
##      record; and its successor, which runs after it, waits quietly.
##   3. THE PASS IS THE BOARD'S DEPENDENCIES TOO: the report of the board's edges is recomputed by the pass.
##   4. ONE ASK STARTS IT AND A SECOND DOES NOTHING. The first says `started <pid>` and the thread takes the lock. A second inside the ask interval
##      says `waiting`. One after the interval, with the thread alive, says `alive <pid>` and starts no second one.
##   5. A KILLED THREAD IS PUT BACK by the next ask, under a new pid.
##   6. THE PASSES ARE MINUTES APART: two ticks a second apart make one pass between them.
##   7. `MDAT_SCHEDULE_THREAD=off` says `off` and starts nothing.
##   8. THE MAIN LOOP ONLY MAKES SURE IT RUNS: with the thread on, one iteration asks for it and starts no routine in its own process. With the thread
##      off, the same iteration runs the steps itself, as it always did.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found"
[ -f "$rigPackage/sh-lib/session/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's control-thread fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
## The thread this check is about is started here, whatever the runner has switched off for the other threads of the tooling.
unset MDAT_SCHEDULE_THREAD
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
## The schedule's thread is a detached process of the tooling: the check that started it ends it before its tree goes.
rigThreadEnd(){
	local endLine endPid
	[ -f "$rigWs/.local/agents/schedule-thread/thread.lock" ] || return 0
	endLine="$( cat "$rigWs/.local/agents/schedule-thread/thread.lock" 2> /dev/null )" || return 0
	endPid="${endLine%% *}"
	case "$endPid" in ''|*[!0123456789]*) return 0 ;; esac
	rigProcSignalWithChildren KILL "$endPid" 2> /dev/null || :
	return 0
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigThreadEnd ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; [ -n "${RIG_KEEP_TREE:-}" ] || rigRemoveTree' EXIT
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
rigScheduleSetup 2
## Monday 2026-10-19 in Etc/GMT-3, 13:00: inside worktime, past every runs-at of the rig.
rigMon13=1792404000
rigAt "$rigMon13"
## A routine of a second member, made when its own section wants one: a routine that already ran today is no longer due, so each section that
## counts a start gets a routine nobody has started yet.
rigBody="# Opening steps\n\nNone.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\nNone.\n\n# Routine's local procedures\n\nNone.\n"
rigRoutine(){ ## name -- one routine of keeper-rig-02, due at 09:00, that has not run
	printf -- "---\ntype: routine\nexecutors: keeper-rig-02\nmaintainers: rig\nrequires-session-kind: standalone\nruns-at: daily 09:00\n---\n# keeper-rig-02.$1.routine\n\n$rigBody" > "$rigSkills/keeper-rig-02/keeper-rig-02.$1.routine.md"
}

## One call inside the rig. Every call is one `env -i`, and the first thing the child does is refuse a workspace outside the rig: a probe once
## reached a real workspace without such a guard. Its output is kept in $rigDir/<name>.out and .err.
rigIn(){ ## name, assignments (one word each), the command and its words
	local inName="$1"
	shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" PKG="$rigPackage" "$@" ) \
		> "$rigDir/$inName.out" 2> "$rigDir/$inName.err" < /dev/null
	rigInRc=$?
}
## The tooling's own call: one operation of DistroAgentsTools.fn.sh, in the rig.
rigTool(){ ## name, the operation and its words
	local toolName="$1"
	shift
	rigIn "$toolName" bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
		case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
		! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
		cd "$MMDAPP" && exec bash "$PKG/sh-scripts/DistroAgentsTools.fn.sh" "$@"
	' rig "$@"
}
rigAsk(){ ## name, [assignments...]
	local askName="$1"
	shift
	rigIn "$askName" "$@" bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
		! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
		. "$PKG/sh-lib/session/AgentsTools.ScheduleThread.include" || exit 98
		cd "$MMDAPP" && AgentsToolsScheduleThreadAsk
	' rig
}
rigPass(){ ## name -- the thread's own pass, in a process of its own
	rigIn "$1" bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
		! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
		. "$PKG/sh-lib/session/AgentsTools.ScheduleThread.include" || exit 98
		cd "$MMDAPP" && AgentsToolsScheduleThreadPass
	' rig
}
rigOut(){ LC_ALL=C tr -d '\r' < "$rigDir/$1.out" 2> /dev/null | LC_ALL=C sed -n '1p' ; }
rigSaidOut(){ ## name, fixed text
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.out" 2> /dev/null || :
}
rigSaidErr(){ ## name, fixed text
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.err" 2> /dev/null || :
}
## The pid of the thread, once it holds the lock and is still that process.
rigThreadPid(){
	local pidLine pidNow
	[ -f "$rigWs/.local/agents/schedule-thread/thread.lock" ] || return 0
	pidLine="$( cat "$rigWs/.local/agents/schedule-thread/thread.lock" 2> /dev/null )" || return 0
	pidNow="${pidLine%% *}"
	case "$pidNow" in ''|*[!0123456789]*) return 0 ;; esac
	kill -0 "$pidNow" 2> /dev/null || return 0
	printf '%s\n' "$pidNow"
}
## The thread says in its own log that it holds its lock, which is the moment it may be asked a second time.
rigThreadUp(){
	local upLeft=150
	while [ "$upLeft" -gt 0 ] ; do
		LC_ALL=C grep -q 'the thread runs as pid' "$rigWs/.local/agents/schedule-thread/thread.log" 2> /dev/null && return 0
		sleep 0.1 ; upLeft=$(( upLeft - 1 ))
	done
	return 1
}
## Wait, at most a few seconds, for a routine's record to stand: the thread's pass comes at its first tick, a second after it takes its lock.
rigRecordUp(){ ## routine file name
	local upLeft=100
	while [ "$upLeft" -gt 0 ] ; do
		[ "$( rigRecordsOf "$1" )" = 0 ] || return 0
		sleep 0.1 ; upLeft=$(( upLeft - 1 ))
	done
	return 1
}
rigStartsSaid(){ ## name -- how many starts the pass reported, in either stream
	LC_ALL=C grep -c -F 'autorun: started' "$rigDir/$1.out" "$rigDir/$1.err" 2> /dev/null | LC_ALL=C awk -F: '{ s += $2 } END { print s + 0 }'
}

echo "-- 1. the operation --"
rigTool bare --intern-schedule
rigAssert "a bare call prints its contract and starts nothing" "$rigInRc:$( rigSaidErr bare '--intern-schedule --run' ):$( [ -e "$rigWs/.local/agents/schedule-thread/thread.lock" ] && printf lock )" "1:1:"
## The pass starts a routine due (the rig's auto routine), and a start asks the thread, which takes the lock: so with the thread off for this call, the lock
## can only be one this call took itself.
rigIn one MDAT_SCHEDULE_THREAD=off bash -c '
	case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
	! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
	cd "$MMDAPP" && exec bash "$PKG/sh-scripts/DistroAgentsTools.fn.sh" "$@"
' rig --intern-schedule --one
rigAssert "--one makes one pass and ends, and holds no lock" "$rigInRc:$( [ -e "$rigWs/.local/agents/schedule-thread/thread.lock" ] && printf lock )" "0:"

echo "-- 2. the pass is the schedule's steps --"
rigWaitStarts
rigAssert "a routine due at 09:00, asked at 13:00, is started by the pass through the spawner" "$( rigStartsSaid one ):$( rigSaidOut one 'autorun: started keeper-rig-01.auto.routine.md' )" "1:1"
rigAssert "...and its record stands, owned by its executor" "$( rigRecordsOf keeper-rig-01.auto.routine.md ):$( LC_ALL=C grep -l -x 'owner: keeper-rig-01' $( LC_ALL=C grep -l -x 'routine: keeper-rig-01.auto.routine.md' "$rigSp"/*/*.spawn.md ) | wc -l | tr -d ' ' )" "1:1"
rigAssert "its successor, which follows it, waits quietly: not started, and no line of it" "$( rigRecordsOf keeper-rig-01.chain.routine.md ):$( rigSaidOut one 'keeper-rig-01.chain' )" "0:0"
rigWaitStarts

echo "-- 3. the pass is the board's dependencies too --"
mkdir -p "$rigData/board/backlog" "$rigData/board/pending" "$rigData/board/running" "$rigData/board/review" "$rigData/board/blocked" "$rigData/board/parked"
printf -- '---\ntype: task\nblocks: task-20261019T0900Z-rig-a.md\n---\n\n# rig B\n' > "$rigData/board/backlog/task-20261019T0900Z-rig-b.md"
printf -- '---\ntype: task\n---\n\n# rig A\n' > "$rigData/board/backlog/task-20261019T0900Z-rig-a.md"
rm -f "$rigWs/.local/agents/board-dependencies.last"
rigPass deps
rigAssert "the board's dependencies are recomputed by the pass, and its report names the edge it found" "$( [ -s "$rigWs/.local/agents/board-dependencies.last" ] && printf report ):$( LC_ALL=C grep -q -F 'rig-a <- task-20261019T0900Z-rig-b' "$rigWs/.local/agents/board-dependencies.last" && printf waiting )" "report:waiting"

echo "-- 4. one ask starts it and a second does nothing --"
rm -rf "$rigWs/.local/agents/schedule-thread"
rigAsk ask1
rigThreadUp ; rigPid1="$( rigThreadPid )"
rigAssert "the first ask starts the thread, and its lock names a process that lives" "$( rigOut ask1 | LC_ALL=C sed -n 's/^started [0-9][0-9]*$/started/p' ):$( [ -n "$rigPid1" ] && printf held )" "started:held"
rigAssert "the thread's own log says what it serves, and when it ends" "$( LC_ALL=C grep -c -F 'it serves' "$rigWs/.local/agents/schedule-thread/thread.log" ):$( LC_ALL=C grep -c -F 'ends after' "$rigWs/.local/agents/schedule-thread/thread.log" )" "1:1"
rigAsk ask2
rigAssert "a second ask inside the interval says waiting, and reads nothing else" "$( rigOut ask2 ):$( rigThreadPid )" "waiting:$rigPid1"
rm -f "$rigWs/.local/agents/schedule-thread/thread.asked"
rigAsk ask3
rigAssert "once the interval has passed, an ask with the thread alive says so and starts no second one" "$( rigOut ask3 ):$( rigThreadPid )" "alive $rigPid1:$rigPid1"

echo "-- 5. a killed thread is put back --"
kill -9 "$rigPid1" 2> /dev/null || :
sleep 0.5
rm -f "$rigWs/.local/agents/schedule-thread/thread.asked"
rigAsk ask4
rigThreadUp ; sleep 0.3 ; rigPid2="$( rigThreadPid )"
rigAssert "the ask after a kill starts it again, under a new pid" "$( rigOut ask4 | LC_ALL=C sed -n 's/^started [0-9][0-9]*$/started/p' ):$( [ -n "$rigPid2" ] && [ "$rigPid2" != "$rigPid1" ] && printf new )" "started:new"
rigThreadEnd

echo "-- 5b. a thread that ends on a change of its code is put back by itself --"
## MDAT_SCHEDULE_CODE_EXTRA names a file of the rig that stands for the thread's code: one newer than its lock ends the thread, as the includes do.
rm -rf "$rigWs/.local/agents/schedule-thread"
rigCodeFile="$rigDir/code.stand-in"
rm -f "$rigCodeFile"
rigAsk ask5 MDAT_SCHEDULE_CODE_EXTRA="$rigCodeFile"
rigThreadUp ; sleep 1 ; rigPid5="$( rigThreadPid )"
: > "$rigCodeFile"
rigWaited=0
while [ "$rigWaited" -lt 120 ] ; do
	rigPid6="$( rigThreadPid )"
	{ [ -n "$rigPid6" ] && [ "$rigPid6" != "$rigPid5" ] ; } && break
	sleep 0.5 ; rigWaited=$(( rigWaited + 1 ))
done
rigAssert "the thread ended on its code changing, and a new one holds the lock, started by the first with no ask from outside" "$( LC_ALL=C grep -c -F 'ends: its code changed' "$rigWs/.local/agents/schedule-thread/thread.log" ):$( { [ -n "$rigPid6" ] && [ "$rigPid6" != "$rigPid5" ] ; } && printf new || printf same )" "1:new"
rigThreadEnd

echo "-- 6. the passes are minutes apart --"
rigRoutine ticks
rigIn ticks bash -c '
	case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD" >&2 ; exit 99 ;; esac
	. "$PKG/sh-lib/session/AgentsTools.ScheduleThread.include" || exit 98
	cd "$MMDAPP" && AgentsToolsScheduleThreadPass && AgentsToolsScheduleThreadPass
' rig
rigAssert "two ticks a second apart make one pass between them: the routine made for this section is started once" "$( rigStartsSaid ticks ):$( rigSaidOut ticks 'autorun: started keeper-rig-02.ticks.routine.md' )" "1:1"
rigWaitStarts

echo "-- 7. the thread off --"
rm -rf "$rigWs/.local/agents/schedule-thread"
rigAsk offask MDAT_SCHEDULE_THREAD=off
rigAssert "with the thread off the ask says off and starts nothing" "$( rigOut offask ):$( [ -e "$rigWs/.local/agents/schedule-thread/thread.lock" ] && printf lock )" "off:"

echo "-- 8. the main loop only makes sure it runs --"
rm -rf "$rigWs/.local/agents/schedule-thread"
rigRoutine loop
rigIn loopon bash -c '
	case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD" >&2 ; exit 99 ;; esac
	! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
	cd "$MMDAPP" && exec bash "$PKG/sh-scripts/DistroAgentsTools.fn.sh" --intern-main-loop --one
' rig
rigThreadUp ; rigRecordUp keeper-rig-02.loop.routine.md ; rigWaitStarts ; rigThreadEnd
rigAssert "with the thread on, one iteration asks for the thread and starts no routine in its own process, and the thread's own pass starts it" \
	"$( [ -e "$rigWs/.local/agents/schedule-thread/thread.wanted" ] && printf asked ):$( rigStartsSaid loopon ):$( rigRecordsOf keeper-rig-02.loop.routine.md )" \
	"asked:0:1"
rm -rf "$rigWs/.local/agents/schedule-thread"
## The schedule starts one routine a pass and the rig's clock stands still, so the iteration of the thread-off case is a later one.
rigAt $(( rigMon13 + 600 ))
rigRoutine off
rigIn loopoff MDAT_SCHEDULE_THREAD=off bash -c '
	case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD" >&2 ; exit 99 ;; esac
	! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
	cd "$MMDAPP" && exec bash "$PKG/sh-scripts/DistroAgentsTools.fn.sh" --intern-main-loop --one
' rig
rigWaitStarts
rigAssert "with the thread off, the same iteration runs the steps itself, as it always did, and asks no thread" "$( rigSaidErr loopoff 'autorun: started keeper-rig-02.off.routine.md' ):$( rigSaidErr loopoff "the schedule's service thread" )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_THREAD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
