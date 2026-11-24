#!/usr/bin/env bash
## Behavioural check on the control threads the schedule thread's pass keeps (S12.12). A rig running the schedule thread
## alone has no main loop, so a session whose control thread died stayed unwatched and never asked for the schedule again.
## The pass makes the main loop's own check, in a subshell, and says what it started.
##
## Held, and not read:
##   1. A running session with no live control thread has one started, and the check names it.
##   2. A finished session is given none.
##   3. A session whose run ended unclosed is still watched: it is given one.
##   4. A start that fails is named, and the check itself still reads 0.
## Red recipe: with the AgentsToolsScheduleThreadControlKeep call removed from AgentsToolsScheduleThreadPass, sections 1
## and 3 fail and sections 2 and 4 pass.
## Offline: a rig workspace of its own, its own measured rows, a stand-in control-start of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
[ -f "$rigPackage/sh-lib/session/AgentsTools.SessionControlStart.include" ] || rigRefuse "the session control include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleControlKeepCheck )" || exit 1
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
mkdir -p "$rigWs/.local/agents" "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions" "$rigHome" "$rigTmpBin"

## THE MEASURED ROWS, in the registry's own thirteen fields, one tab between each. The register is :12 (running, gone,
## remote) and the run's own activity word is :13 (thinking, tool, waiting, idling, paused, failed, finished, unclosed).
## The judged reader admits only those eight words at :13, so a live run is `running` at :12 and one of them at :13.
rigRows="$rigTmp/rows"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
	"rig-run-1" "rig-session-run"     "spawn" "rig-host" "rig" "owner" "started" "2026-11-24T01:00:00Z" 1 0 0 "running" "thinking"  > "$rigRows"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
	"rig-run-2" "rig-session-done"    "spawn" "rig-host" "rig" "owner" "started" "2026-11-24T00:00:00Z" 1 0 0 "gone"    "finished" >> "$rigRows"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
	"rig-run-3" "rig-session-deadRun" "spawn" "rig-host" "rig" "owner" "started" "2026-11-24T00:30:00Z" 1 0 0 "gone"    "unclosed" >> "$rigRows"
printf '== the rig rows, %s of them, with %s fields the first:\n' \
	"$( grep -c . "$rigRows" )" "$( head -1 "$rigRows" | LC_ALL=C awk -F'\t' '{ print NF ; }' )"

rigCheck(){ ## start-mode -- the check's own output, with its starts kept
	: > "$rigTmp/started"
	env -i HOME="$rigHome" PATH="$rigTmpBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig \
		RIG_STARTED="$rigTmp/started" RIG_ROWS="$rigRows" RIG_MODE="$1" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionControlStart.include" || exit 91
			if [ "$RIG_MODE" = failing ] ; then
				AgentsToolsSessionControlStart(){ printf "failed - the rig refused this start\n" ; return 1 ; }
			else
				AgentsToolsSessionControlStart(){ printf "start %s\n" "$1" >> "$RIG_STARTED" ; printf "started %s\n" "$1" ; }
			fi
			cat "$RIG_ROWS" | AgentsToolsSessionControlCheck
			printf "rc %s\n" "$?"
		' rig 2>&1
}

echo "-- 1. a running session with no live control thread is given one --"
rigOut="$( rigCheck normal )"
rigAssert "the running session's thread was started" "$( LC_ALL=C grep -c '^start rig-session-run$' "$rigTmp/started" 2> /dev/null | LC_ALL=C head -1 )" 1
rigAssert "and the check named it as started" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^rig-session-run started' )" 1

echo "-- 2. a finished session is given none --"
rigAssert "the finished session was started not at all" "$( LC_ALL=C grep -c 'rig-session-done' "$rigTmp/started" 2> /dev/null | LC_ALL=C head -1 )" 0

echo "-- 3. a session whose run ended unclosed is still watched, and is given one --"
rigAssert "the unclosed session's thread was started" "$( LC_ALL=C grep -c '^start rig-session-deadRun$' "$rigTmp/started" 2> /dev/null | LC_ALL=C head -1 )" 1

echo "-- 4. a start that fails is named, and the check itself still reads 0 --"
rigOut="$( rigCheck failing )"
rigAssert "the failed start is named beside its session" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^rig-session-run failed' )" 1
rigAssert "and the check's own status is 0" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^rc 0$' )" 1

echo "-- 5. the pass itself makes this check, so a rig with no main loop keeps them --"
## The first four sections prove what the keep does with its rows. This one proves the pass reaches it at all, which is
## the behaviour the dispatch names: a check of the keep alone would stay green with the pass never calling it.
: > "$rigTmp/kept"
rigPassOut="$( env -i HOME="$rigHome" PATH="$rigTmpBin:/usr/bin:/bin" MMDAPP="$rigWs" \
	MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig \
	MDAT_SCHEDULE_THREAD=off RIG_KEPT="$rigTmp/kept" \
	bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 90
		## Every other step of the pass is a stand-in, so the one measured is the control keep.
		AgentsToolsScheduleLoop(){ return 0 ; }
		AgentsToolsBoardDependencies(){ return 0 ; }
		AgentsToolsScheduleThreadChildrenKeep(){ return 0 ; }
		AgentsToolsScheduleThreadKnowledgeKeep(){ return 0 ; }
		AgentsToolsCleanupSweepDetached(){ return 0 ; }
		AgentsToolsScheduleThreadWantedInto(){ agentsScheduleThreadKeep=no ; return 0 ; }
		AgentsToolsScheduleThreadControlKeep(){ printf "kept\n" >> "$RIG_KEPT" ; return 0 ; }
		agentsScheduleThreadGap=0
		AgentsToolsScheduleThreadPass
	' rig 2>&1 )"
rigAssert "one pass reaches the control keep" "$( LC_ALL=C grep -c '^kept$' "$rigTmp/kept" 2> /dev/null | LC_ALL=C head -1 )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE CONTROL KEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_CONTROL_KEEP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
