#!/usr/bin/env bash
## Behavioural check on the schedule starting the machine's retest drain by itself (task-20261117T2212Z-retest-queue-never-drains).
## A request that waits in <HOME>/.agents/magic-team/retest-queue/waiting is drained with no person and no agent: the schedule's pass starts
## one detached `--retest-drain`. THE SUBJECT is the pass step `AgentsToolsScheduleRetestDrain` (AgentsTools.DispatcherSchedule.include),
## called from AgentsToolsScheduleLoop. The testing tool is a stand-in on PATH that records its arguments, so "a drain was started" and "no
## drain was started" are told apart. The queue, the lock and the pace line are the rig's own. Held:
##   1. A REQUEST WAITS, no drain holds the lock, the pace allows a start: the pass starts one drain, and names --retest-drain.
##   2. NOTHING WAITS: the pass starts none.
##   3. A DRAIN LIVES on the lock: the pass starts none, so one batch runs at a time on the machine.
##   4. THE PACE IS HELD: the pass starts none.
##   5. A REQUEST WAITS AND THE LOCK IS A DRAIN THAT IS GONE: the pass starts one, so a killed drain never stops the queue.
## THE CHECK'S OWN CONTROL, so its red is a red: `CHECK_STEP_STANDIN=<file>` sources that file in the rig before the step is looked up,
## and a file holding the step done right turns every assertion green. With the live tree and no file the step is missing, and all five fail.
## THE SEAM IT OBSERVES: the step reaches the drain by the console's own path, `DistroAgentsTesting.fn.sh --retest-drain`, which this rig
## points at a stand-in that records the arguments and exits. Where the step calls it another way, this check cannot see the call.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
[ -f "$rigInclude" ] || rigRefuse "the schedule's include is not in the package: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleRetestDrainCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
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

## THE RIG'S HOME AND ITS ONE QUEUE, as the tooling finds them.
rigHome="$rigTmp/home"
rigQueue="$rigHome/.agents/magic-team/retest-queue"
mkdir -p "$rigQueue/waiting" "$rigQueue/running" "$rigQueue/done" "$rigTmp/bin" || exit 1

## THE STAND-IN TOOL records the one call the pass makes and exits at once, so no test of the machine is run by this check.
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$RIG_DRAIN_LOG"' 'exit 0' > "$rigTmp/bin/DistroAgentsTesting.fn.sh" || exit 1
chmod +x "$rigTmp/bin/DistroAgentsTesting.fn.sh"

## One pass, in a shell of its own, with the queue and the lock this check laid out. Every other step of the pass is a stand-in, so the step
## under test is the only work of the pass. Prints the number of drain calls the stand-in recorded.
rigPass(){ ## pace line
	local out=""
	out="$( env -i PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigHome" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_DRAIN_LOG="$rigTmp/drained" RIG_PACE="$1" CHECK_STEP_STANDIN="${CHECK_STEP_STANDIN:-}" \
		bash -c '
			AgentsToolsScheduleSpawnReport(){ return 0 ; }
			AgentsToolsScheduleOverrideLeft(){ return 0 ; }
			AgentsToolsScheduleStartingAllowed(){ return 0 ; }
			AgentsToolsScheduleAutorun(){ return 0 ; }
			AgentsToolsScheduleWorkDuty(){ return 0 ; }
			AgentsToolsScheduleStartPending(){ return 0 ; }
			AgentsToolsScheduleSupervision(){ return 0 ; }
			AgentsToolsScheduleImportantEmergency(){ return 0 ; }
			AgentsToolsScheduleLearning(){ return 0 ; }
			AgentsToolsBoardDependencies(){ return 0 ; }
			AgentsToolsScheduleThreadChildrenKeep(){ return 0 ; }
			AgentsToolsScheduleThreadWantedInto(){ agentsScheduleThreadKeep=no ; return 0 ; }
			export -f AgentsToolsScheduleSpawnReport AgentsToolsScheduleOverrideLeft AgentsToolsScheduleStartingAllowed \
				AgentsToolsScheduleAutorun AgentsToolsScheduleWorkDuty AgentsToolsScheduleStartPending AgentsToolsScheduleSupervision \
				AgentsToolsScheduleImportantEmergency AgentsToolsScheduleLearning AgentsToolsBoardDependencies \
				AgentsToolsScheduleThreadChildrenKeep AgentsToolsScheduleThreadWantedInto
			export RIG_DRAIN_LOG RIG_PACE CHECK_STEP_STANDIN
			set +e +u
			mkdir -p "$MMDAPP" 2> /dev/null
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			## The pace is the line this rig hands over: the step reads it through the pass reader, which stands in for the machine here.
			AgentsToolsSchedulePaceText(){ printf "%s\n" "$RIG_PACE" ; return 0 ; }
			[ -z "${CHECK_STEP_STANDIN:-}" ] || . "$CHECK_STEP_STANDIN"
			if ! type AgentsToolsScheduleRetestDrain > /dev/null 2>&1 ; then
				printf "MISSING"
				exit 0
			fi
			AgentsToolsScheduleRetestDrain > /dev/null 2>&1
			printf "%s" "$( { LC_ALL=C grep -c . "$RIG_DRAIN_LOG" 2> /dev/null || : ; } )"
		' 2> /dev/null )"
	printf '%s' "$out"
}
rigWaitRequest(){ ## id -- one request in the queue
	printf 'id: %s\nasked: 2026-11-18T00:00:00Z\npriority: no-wait\nby: magic-tester\nwhy: rig\nabout: live\norigin: %s\nworkspace: %s\ntest: RigOne\n' \
		"$1" "$rigTmp/ws/source" "$rigTmp/ws" > "$rigQueue/waiting/$1.request"
}
rigLock(){ ## pid, started -- the lock as a drain leaves it
	mkdir -p "$rigQueue/drain.lock"
	printf 'pid: %s\nsince: 2026-11-18T00:00:00Z\nstarted: %s\n' "$1" "$2" > "$rigQueue/drain.lock/holder"
}
rigClear(){
	rm -rf "$rigQueue/waiting" "$rigQueue/running" "$rigQueue/done" "$rigQueue/drain.lock"
	mkdir -p "$rigQueue/waiting" "$rigQueue/running" "$rigQueue/done"
	: > "$rigTmp/drained"
}
rigPaceAllows='pace: 0.2s machinery a call, 169 calls in 5 minutes -- under 4s, a duty start is allowed'
rigPaceHeld='pace: 12.4s machinery a call, 40 calls in 5 minutes -- over 4s, a duty start is held'
rigPidStarted="$( LC_ALL=C ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C sed -e 's/^ *//' -e 's/ *$//' )"

echo "-- 1. a request waits, no drain holds the lock, the pace allows a start --"
rigClear ; rigWaitRequest retest-rig-0001
rigAssert "the pass starts one drain, and it asks for --retest-drain" "$( rigPass "$rigPaceAllows" )" "1"

echo "-- 2. nothing waits --"
rigClear
rigAssert "nothing waits: the pass starts no drain" "$( rigPass "$rigPaceAllows" )" "0"

echo "-- 3. a drain lives on the lock --"
rigClear ; rigWaitRequest retest-rig-0002 ; rigLock "$$" "$rigPidStarted"
rigAssert "a drain holds the lock: the pass starts none" "$( rigPass "$rigPaceAllows" )" "0"

echo "-- 4. the pace is held --"
rigClear ; rigWaitRequest retest-rig-0003
rigAssert "the pace is held: the pass starts none" "$( rigPass "$rigPaceHeld" )" "0"

echo "-- 5. the lock is a drain that is gone --"
rigClear ; rigWaitRequest retest-rig-0004 ; mkdir -p "$rigQueue/drain.lock"
printf 'pid: 23186\nsince: 2026-11-13T19:30:03Z\nstarted: Fri Nov 13 21:30:03 2026\n' > "$rigQueue/drain.lock/holder"
rigAssert "the holder is gone: the pass starts one" "$( rigPass "$rigPaceAllows" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE RETEST DRAIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_RETEST_DRAIN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
