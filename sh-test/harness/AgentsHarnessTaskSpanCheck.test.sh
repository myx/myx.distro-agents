#!/usr/bin/env bash
## Behavioural check of a wrapped tool's run span reaching its call's record (the owner's pace ruling): the pace counts machinery
## only, never what the call itself ran. A wrapped tool runs in a task with a scratch folder of its own (AgentsHarnessTaskBody,
## AgentsHarnessRun.include), and the record is written from the caller's scratch (AgentsHarnessContextToolMeta,
## AgentsHarnessContext.include). Held:
##   1. a task whose tool kept a 3000 ms run leaves its record's mach_ms 3000 below its dur_ms.
##   2. a span left under another call's id marks no later call, and is taken away.
##   3. the task's own folder is gone once the task ends.
## Offline: the real task body read from its include, the context include, and a stand-in tool that keeps its span.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigRunLib="$rigPkg/sh-lib/harness/AgentsHarnessRun.include"
rigContextLib="$rigPkg/sh-lib/harness/AgentsHarnessContext.include"
[ -f "$rigRunLib" ] && [ -f "$rigContextLib" ] || rigRefuse "the run or the context include is not at MDLT_ORIGIN: $MDLT_ORIGIN"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessTaskSpanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The harness sets these before it loads the include; a check that loads it alone sets them the same way.
harnessHere="$rigPkg/sh-lib"
. "$rigContextLib" > /dev/null 2>&1 || rigRefuse "the context include would not load"
type AgentsTranscriptOutcomeOf > /dev/null 2>&1 || . "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" > /dev/null 2>&1 || rigRefuse "the transcript include would not load"
eval "$( LC_ALL=C awk '/^AgentsHarnessTaskBody\(\)/ { on = 1 ; } on { print ; } on && /^}/ { exit ; }' "$rigRunLib" )"
type AgentsHarnessTaskBody > /dev/null 2>&1 || rigRefuse "the task body was not found in $rigRunLib"
## The stand-in tool: it ran 3000 ms, and keeps that span as every tool does.
AgentsHarnessRunToolNow(){ AgentsHarnessToolRunMsKeep 3000 ; harnessResult="done" ; }
harnessTaskStripTimeout=""
rigOwner="$rigTmp/runs/scratch" ; mkdir -p "$rigOwner" || exit 1
rigMeta(){ ## call id -- prints `<dur_ms> <mach_ms>` of that call's record
	harnessScratch="$rigOwner" ; harnessToolRunMs=""
	AgentsHarnessContextToolMeta Bash "$1" done "" | LC_ALL=C sed -E 's/.*"dur_ms":([0-9]+),"mach_ms":([0-9]+).*/\1 \2/'
}

echo "-- 1. the task's span reaches its own call's record --"
agentsTranscriptT0="$(( $( date +%s ) - 5 ))000"
( harnessScratch="$rigOwner" ; harnessCallId=call-1 ; AgentsHarnessTaskBody Bash '{}' ) > /dev/null 2>&1
read -r rigDur rigMach <<< "$( rigMeta call-1 )"
rigAssert "mach_ms is the call's whole time less the 3000 ms it ran" "$(( ${rigDur:-0} - ${rigMach:-0} ))" 3000

echo "-- 2. a span under another call's id marks no later call --"
( harnessScratch="$rigOwner" ; harnessCallId=call-2 ; AgentsHarnessTaskBody Bash '{}' ) > /dev/null 2>&1
read -r rigDur rigMach <<< "$( rigMeta call-3 )"
rigAssert "a later call counts its whole time" "${rigDur:-x}" "${rigMach:-y}"
rigAssert "and the stray span is taken away" "$( ls "$rigOwner" | LC_ALL=C grep -c 'tool.run.ms' )" 0

echo "-- 3. the task's own folder goes with it --"
rigAssert "no task folder is left beside the caller's" "$( ls "$rigTmp/runs" | LC_ALL=C grep -c '^AgentsUniversalHarness\.' )" 0
echo
[ "$rigFailCount" -eq 0 ] || { echo "⛔ HARNESS TASK SPAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1 ; }
echo "HARNESS_TASK_SPAN: OK ($rigPassCount assertions, offline)"
