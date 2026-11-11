#!/usr/bin/env bash
## Behavioural check on the schedule's report of a start that failed (S12.12, board task 20261106T0819Z; `AgentsToolsScheduleSpawnReport`
## in AgentsTools.DispatcherSchedule.include): A FAILURE ALWAYS SAYS WHY, and the why is the text the start gave on the lines after its
## error line, not the error line alone. The first live pass of 2026-11-04 made nine duty starts that every one failed at
## `refusing to join`, and the report said the first line of each, with the sentence that explained it left behind.
## Held, run rather than read:
##   1. THE FOUR LINES AFTER THE FIRST ERROR LINE TRAVEL WITH IT, in their order, as one line of the report.
##   2. THE FIRST ERROR LINE IS THE ANCHOR: a later error line's reason is not reported as this start's.
##   3. A START THAT PRINTED NO ERROR LINE is reported by its last non-blank line.
##   4. A START THAT PRINTED NOTHING is reported as having printed nothing, with its exit status.
##   5. THE REPORT CONSUMES ITS OWN FILES: the same start is said once, never at every later pass.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06, one mutation per guarded line of `AgentsToolsScheduleSpawnReport`:
##   the reason grep's `-A 4` changed to `-A 0` fails rows 1 and 2, the two rows of that one guard (:722 at 2026-11-09 03:21).
##   the fallback that takes the start's last non-blank line, deleted, fails row 3 alone (:723).
##   the fallback that answers "it printed nothing, exit <rc>", deleted, fails row 4 alone (:724).
##   the `rm -f` that consumes the report file and its output, deleted, fails both assertions of row 5 (:727).
## Offline: the include this check loads, and a rig of its own; no spawner is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The package under test is found from the origin this workspace resolves, and a mutated copy is pointed at by RIG_PACKAGE.
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Dispatcher include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleStartReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/schedule/starting" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## A start that ended is two files the report meets, written here as AgentsToolsScheduleSpawn leaves them: the output, and the status.
rigEnded(){ ## key, status, then the output's lines
	local endKey="$1" endRc="$2" endLine
	shift 2
	: > "$rigWs/.local/agents/schedule/starting/$endKey.out"
	for endLine in "$@" ; do printf '%s\n' "$endLine" >> "$rigWs/.local/agents/schedule/starting/$endKey.out" ; done
	printf '%s\n' "$endRc" > "$rigWs/.local/agents/schedule/starting/$endKey.rc"
}
## The report is run in a shell of its own, with the include loaded from the package under test and nothing else of this check's context.
rigReport(){ ## the include to load
	MMDAPP="$rigWs" bash -c '. "$1" ; AgentsToolsScheduleSpawnReport' rig-report "$1" 2>&1
}
## Each section starts from an empty store, so a start left by an earlier section cannot enter this one's expected line.
rigClear(){ rm -f "$rigWs/.local/agents/schedule/starting/"* ; }

echo "-- 1. the reason on the lines after the error line travels with it --"
rigClear
rigEnded probe-a 1 \
	'⛔ ERROR: the start refused: the join was refused' \
	'the registry holds no row for session stale-one' \
	'so the duty reads as never started' \
	'and its schedule slot is given up' \
	'until the next pass that finds it due'
rigAssert "the first error line and the four lines after it are one line of the report" \
	"$( rigReport "$rigInclude" )" \
	'schedule: the start of probe-a failed: ⛔ ERROR: the start refused: the join was refused the registry holds no row for session stale-one so the duty reads as never started and its schedule slot is given up until the next pass that finds it due '

echo "-- 2. the first error line is the anchor --"
rigClear
## The second error sits beyond the first one's own four-line window, so its presence would be a report of a failure this start did not lead with.
rigEnded probe-b 1 \
	'a preamble line that is not an error' \
	'⛔ ERROR: the first failure, which is the one reported' \
	'its reason, first' \
	'its reason, second' \
	'its reason, third' \
	'its reason, fourth' \
	'a line that follows the window' \
	'another line that follows the window' \
	'⛔ ERROR: a second failure later in the same output' \
	'its reason, which is not this start reason'
rigAssert "the report carries the first error's four lines, and stops at them" \
	"$( rigReport "$rigInclude" )" \
	'schedule: the start of probe-b failed: ⛔ ERROR: the first failure, which is the one reported its reason, first its reason, second its reason, third its reason, fourth '

echo "-- 3. no error line at all: the last line that says something --"
rigClear
rigEnded probe-c 1 'the routine ended without a marker' 'the last real line' ''
rigAssert "a start with no error line is reported by its last non-blank line" \
	"$( rigReport "$rigInclude" )" \
	'schedule: the start of probe-c failed: the last real line'

echo "-- 4. nothing printed at all --"
rigClear
rigEnded probe-d 3
rigAssert "a start that printed nothing says so, with its status" \
	"$( rigReport "$rigInclude" )" \
	'schedule: the start of probe-d failed: it printed nothing, exit 3'

echo "-- 5. the report consumes its own files --"
rigClear
rigEnded probe-e 1 '⛔ ERROR: a failure said once'
rigReport "$rigInclude" > /dev/null
rigAssert "the start's files are gone after the report" \
	"$( ls "$rigWs/.local/agents/schedule/starting" | LC_ALL=C grep -c -E '^probe-e\.' || : )" 0
rigAssert "and a second pass says nothing of it" "$( rigReport "$rigInclude" )" ''

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE START REPORT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_START_REPORT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
