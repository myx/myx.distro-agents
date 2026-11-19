#!/usr/bin/env bash
## Behavioural check on the lane count of the test line, `AgentsRunLaneCount` of sh-test/AgentsRunTests.sh, run rather than read: the
## runner itself executes as it loads, so the one function under test is cut out of it, given rigs of this check's own and the pace
## measures its cases write into them. The count follows the schedule's pace line alone. Held:
##   1. control, both directions: a lane count set by hand is that count, so the function is read at all; and an over-the-gate
##      measure gives one lane where a measure under the gate gives the lane maximum
##   2. the gate: a median under it gives the lane maximum, a median at it or over it gives one lane, and its own setting is read
##   3. the lane maximum: suite-lanes/max, else MDAT_SUITE_LANES, else 3, and a count set by hand is held to it
##   4. too little to judge is allowed, as a duty start is: fewer than 3 calls, a measure as old as its TTL, a measure that
##      reads as no number, and no measure on any rig
##   5. the freshest measure of the rigs decides, and a stale one is skipped
##   6. the line says the count first, then why, naming the rig it read
##   7. the same measure gives the same verdict as the duty gate (AgentsToolsSchedulePaceText), and the function takes no probe
##      of its own: no floor file, no timing loop, no walk of `spawned/`
## Offline: a rig HOME of this check's own, holding the machine's lane folder, and no process started at all.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRunner="$rigPkg/sh-test/AgentsRunTests.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin: $rigRunner"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsPaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## THE FUNCTION UNDER TEST, cut out of the runner whole: from its own first line to the line holding its closing brace at
## column one. A cut that finds no such function refuses, so a stage that reached nothing never reports a result.
rigCut(){ ## function name, the file to write
	LC_ALL=C awk -v want="$1" '
		$0 == want "(){" || $0 ~ ( "^" want "\\(\\)\\{" ) { inside = 1 }
		inside { print }
		inside && $0 == "}" { done = 1 ; exit }
		END { exit ( done ? 0 : 1 ) ; }
	' "$rigRunner" > "$2" || rigRefuse "the runner holds no whole function named $1"
	[ -s "$2" ] || rigRefuse "the function $1 was cut to an empty file"
}
rigLaneCountText="$rigTmp/lane-count.sh"
rigCut AgentsRunLaneCount "$rigLaneCountText"
bash -n "$rigLaneCountText" || rigRefuse "the cut of AgentsRunLaneCount does not parse"

rigLanes="$rigTmp/home/.agents/magic-team/suite-lanes"
mkdir -p "$rigLanes" || rigRefuse "the rig's lane folder could not be made: $rigLanes"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## THE RIGS OF THE MACHINE are the two folders ws-a and ws-b of this check: the name of the rigs is replaced by a function that prints
## them as the real one does, `<root><TAB><owner>` a line, so the reading of their measures is the function's and the rig list is
## not this check's. One NAME=value pair a case wants in the environment goes after the case's own arguments.
rigRoot="$rigTmp/rigs"
rigMeasure_(){ ## rig name, the measure's age in seconds, its median, its calls: the measure as the schedule keeps it
	mkdir -p "$rigRoot/$1/.local/agents/schedule"
	printf '%s 300 %s %s\n' "$(( $( date +%s ) - $2 ))" "$3" "$4" > "$rigRoot/$1/.local/agents/schedule/pace.measure"
}
rigReset_(){ ## the lane maximum, or nothing for no lane maximum file
	rm -rf "$rigRoot" "$rigLanes/count" "$rigLanes/max"
	mkdir -p "$rigRoot/ws-a" "$rigRoot/ws-b"
	[ -z "${1:-}" ] || printf '%s\n' "$1" > "$rigLanes/max"
}
rigLaneLine(){ ## NAME=value pairs for the environment, if any: the whole line the function prints
	env "$@" bash -c '. "$1" ; runLaneDir="$2" ; rigRootDir="$3" ; AgentsToolsSuperviseRigs(){ printf "%s\t-\n" "$rigRootDir/ws-a" "$rigRootDir/ws-b" ; } ; MMDAPP="$rigRootDir" ; AgentsRunLaneCount' rig "$rigLaneCountText" "$rigLanes" "$rigRoot" 2>&1
}
rigLaneWord(){ ## the same, the lane count alone
	local wordLine
	wordLine="$( rigLaneLine "$@" )"
	printf '%s' "${wordLine%% *}"
}

## The age in a line is read a moment after the measure was written, so a case compares it as N.
rigAgeless(){ LC_ALL=C sed 's/, [0-9]*s old/, Ns old/' ; }

echo "-- 1. control, both directions --"
rigReset_ 3 ; rigMeasure_ ws-a 10 9000 50
rigAssert "a measure over the gate gives one lane" "$( rigLaneWord )" "1"
printf '2\n' > "$rigLanes/count"
rigAssert "and a count set by hand is that count, whatever the pace" "$( rigLaneWord )" "2"
rigReset_ 3 ; rigMeasure_ ws-a 10 2000 50
rigAssert "a measure under the gate gives the lane maximum" "$( rigLaneWord )" "3"
printf '1\n' > "$rigLanes/count"
rigAssert "and a count set by hand is that count there too" "$( rigLaneWord )" "1"

echo "-- 2. the gate --"
rigReset_ 3 ; rigMeasure_ ws-a 10 3999 50
rigAssert "a median just under the gate gives the lane maximum" "$( rigLaneWord )" "3"
rigMeasure_ ws-a 10 4000 50
rigAssert "a median at the gate gives one lane, as a duty start is held at it" "$( rigLaneWord )" "1"
rigAssert "a gate set in MDAT_TOOL_PACE_MS is read: 2000 ms against a gate of 1000 gives one lane" "$( rigMeasure_ ws-a 10 2000 50 ; rigLaneWord MDAT_TOOL_PACE_MS=1000 )" "1"
rigAssert "and 4500 ms against a gate of 5000 gives the lane maximum" "$( rigMeasure_ ws-a 10 4500 50 ; rigLaneWord MDAT_TOOL_PACE_MS=5000 )" "3"
rigAssert "a gate that is no number is the gate of 4000 ms" "$( rigMeasure_ ws-a 10 4500 50 ; rigLaneWord MDAT_TOOL_PACE_MS=abc )" "1"

echo "-- 3. the lane maximum --"
rigReset_ 5 ; rigMeasure_ ws-a 10 2000 50
rigAssert "suite-lanes/max is the lane maximum" "$( rigLaneWord )" "5"
rigReset_ "" ; rigMeasure_ ws-a 10 2000 50
rigAssert "with no max file, MDAT_SUITE_LANES is" "$( rigLaneWord MDAT_SUITE_LANES=4 )" "4"
rigAssert "with neither, it is 3" "$( rigLaneWord MDAT_SUITE_LANES= )" "3"
rigReset_ abc ; rigMeasure_ ws-a 10 2000 50
rigAssert "a max file that is no number falls to MDAT_SUITE_LANES, and that to 3" "$( rigLaneWord MDAT_SUITE_LANES=xyz )" "3"
rigReset_ 0 ; rigMeasure_ ws-a 10 2000 50
rigAssert "a lane maximum of zero is one lane, never none" "$( rigLaneWord )" "1"
rigReset_ 3 ; printf '9\n' > "$rigLanes/count"
rigAssert "a count set by hand is held to the lane maximum" "$( rigLaneWord )" "3"
printf '0\n' > "$rigLanes/count"
rigAssert "and is at least one lane" "$( rigLaneWord )" "1"

echo "-- 4. too little to judge is allowed --"
rigReset_ 3 ; rigMeasure_ ws-a 10 9000 2
rigAssert "a measure of 2 calls over the gate gives the lane maximum" "$( rigLaneWord )" "3"
rigMeasure_ ws-a 10 9000 3
rigAssert "and a measure of 3 calls over the gate gives one lane" "$( rigLaneWord )" "1"
rigMeasure_ ws-a 10 - 0
rigAssert "a measure of no calls, whose median is a dash, gives the lane maximum" "$( rigLaneWord )" "3"
rigMeasure_ ws-a 10 abc 50
rigAssert "a median that is no number gives the lane maximum" "$( rigLaneWord )" "3"
rigMeasure_ ws-a 55 9000 50
rigAssert "a measure a few seconds short of its TTL still counts: one lane" "$( rigLaneWord )" "1"
rigMeasure_ ws-a 61 9000 50
rigAssert "a measure older than its TTL is too old to judge: the lane maximum" "$( rigLaneWord )" "3"
rigAssert "a TTL set in MDAT_TOOL_PACE_CACHE_SECONDS is read: 90 s old against a TTL of 120 gives one lane" "$( rigMeasure_ ws-a 90 9000 50 ; rigLaneWord MDAT_TOOL_PACE_CACHE_SECONDS=120 )" "1"
rigMeasure_ ws-a -30 9000 50
rigAssert "a measure dated ahead of the clock is not read: the lane maximum" "$( rigLaneWord )" "3"
rigReset_ 3
rigAssert "no measure on any rig gives the lane maximum" "$( rigLaneWord )" "3"
mkdir -p "$rigRoot/ws-a/.local/agents/schedule" && printf 'garbage\n' > "$rigRoot/ws-a/.local/agents/schedule/pace.measure" || rigRefuse "the rig's measure could not be written"
rigAssert "a measure file that is no measure gives the lane maximum" "$( rigLaneWord )" "3"

echo "-- 5. the freshest measure of the rigs decides --"
rigReset_ 3 ; rigMeasure_ ws-a 40 9000 50 ; rigMeasure_ ws-b 5 2000 50
rigAssert "an older rig over the gate and a fresher one under it gives the lane maximum" "$( rigLaneWord )" "3"
rigReset_ 3 ; rigMeasure_ ws-a 5 9000 50 ; rigMeasure_ ws-b 40 2000 50
rigAssert "the reverse gives one lane" "$( rigLaneWord )" "1"
rigReset_ 3 ; rigMeasure_ ws-a 40 9000 50 ; rigMeasure_ ws-b 5 9000 1
rigAssert "a fresher rig of too few calls decides over an older one over the gate: the lane maximum" "$( rigLaneWord )" "3"
rigReset_ 3 ; rigMeasure_ ws-a 100 2000 50 ; rigMeasure_ ws-b 30 9000 50
rigAssert "a stale rig is skipped, and the fresh one over the gate gives one lane" "$( rigLaneWord )" "1"
rigReset_ 3 ; rigMeasure_ ws-a 100 9000 50 ; rigMeasure_ ws-b 30 2000 50
rigAssert "and the reverse gives the lane maximum" "$( rigLaneWord )" "3"

echo "-- 6. the line says the count, then why --"
rigReset_ 3 ; rigMeasure_ ws-a 40 9000 50 ; rigMeasure_ ws-b 5 2000 61
rigAssert "under the gate: the count, the rig read, its age, its median and calls, the gate" "$( rigLaneLine | rigAgeless )" "3 pace of ws-b, Ns old: median 2000 ms machinery a call over 61 calls, under the 4000 ms gate"
rigMeasure_ ws-b 5 4000 61
rigAssert "at or over the gate" "$( rigLaneLine | rigAgeless )" "1 pace of ws-b, Ns old: median 4000 ms machinery a call over 61 calls, at or over the 4000 ms gate"
rigMeasure_ ws-b 5 4000 2
rigAssert "too few calls" "$( rigLaneLine | rigAgeless )" "3 pace of ws-b, Ns old: 2 calls in its window, too few to judge"
rigReset_ 3
rigAssert "no measure" "$( rigLaneLine )" "3 no pace measure of a rig is under 60s old, too little to judge"
printf '2\n' > "$rigLanes/count"
rigAssert "a count set by hand says so" "$( rigLaneLine )" "2 set by hand in $rigLanes/count"

echo "-- 7. the duty gate's verdict, and no probe of its own --"
## The schedule's own reading of the same measure, run: a rig folder holding the measure is read by AgentsToolsSchedulePaceText without
## a walk, as the measure is within its TTL and its window, so the two verdicts are the one pace line read twice.
rigDutyVerdict(){ ## the median, the calls: allowed or held, by the duty gate
	local dutyLine
	rigReset_ 3 ; rigMeasure_ ws-a 10 "$1" "$2"
	dutyLine="$( bash -c '. "$1/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ; MMDAPP="$2" ; AgentsToolsSchedulePaceText' rig "$MDLT_ORIGIN" "$rigRoot/ws-a" 2>&1 )"
	case "$dutyLine" in *'a duty start is allowed'*) printf 'allowed' ;; *'a duty start is held'*) printf 'held' ;; *) printf 'unread: %s' "$dutyLine" ;; esac
}
rigAssert "a median under the gate: the duty gate allows" "$( rigDutyVerdict 2000 50 )" "allowed"
rigAssert "and the line runs the lane maximum" "$( rigLaneWord )" "3"
rigAssert "a median over the gate: the duty gate holds" "$( rigDutyVerdict 9000 50 )" "held"
rigAssert "and the line runs one lane" "$( rigLaneWord )" "1"
rigAssert "a median at the gate: the duty gate holds" "$( rigDutyVerdict 4000 50 )" "held"
rigAssert "and the line runs one lane" "$( rigLaneWord )" "1"
rigAssert "2 calls over the gate: the duty gate allows" "$( rigDutyVerdict 9000 2 )" "allowed"
rigAssert "and the line runs the lane maximum" "$( rigLaneWord )" "3"
rigAssert "the function names the rigs as --flags does, AgentsToolsSuperviseRigs" "$( LC_ALL=C grep -c -F 'AgentsToolsSuperviseRigs "$MMDAPP"' "$rigLaneCountText" )" "1"
rigAssert "and the include it loads defines that function" "$( LC_ALL=C grep -c -F 'sh-lib/supervise/AgentsTools.SuperviseRigs.include' "$rigLaneCountText" ; LC_ALL=C grep -c '^AgentsToolsSuperviseRigs()' "$rigPkg/sh-lib/supervise/AgentsTools.SuperviseRigs.include" )" "$( printf '1\n1' )"
rigAssert "the function keeps no floor, times no loop and walks no run folder" "$( LC_ALL=C grep -c -e 'pace-floor' -e 'TIMEFORMAT' -e 'spawned/' -e 'AgentsRunPaceMs' "$rigLaneCountText" || : )" "0"
rigAssert "and the runner holds no probe of its own" "$( LC_ALL=C grep -c -e 'AgentsRunPaceMs' -e 'pace-floor' "$rigRunner" || : )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ RUN TESTS PACE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_PACE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
