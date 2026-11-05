#!/usr/bin/env bash
## Behavioural check on S12.6's pace signal, `AgentsRunLaneCount` of sh-test/AgentsRunTests.sh, run rather than read: the
## runner itself executes as it loads, so the one function under test is cut out of it and given the pace its own cases
## name. Held:
##   1. control, both directions: a lane count set by hand is that count, so the function is read at all
##   2. the arithmetic: the floor against the pace, as the whole number of lanes, clamped to 1 and to the machine's count
##   3. a pace floor is only ever lowered: a slower pace never raises it, and a floor a day old is read again
##   4. an unmeasurable pace -- no reading, a reading that is no number, a reading of zero -- is a busy machine, so one
##      lane and never the machine's maximum
## Red before S12.6's fix: a probe that could not be timed printed the machine's own count, so cases 4 fail at 3 lanes.
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

## THE LANE COUNT THE FUNCTION GIVES, with the pace the case names: the probe is replaced by one that prints that word as
## it stands, so the arithmetic is the function's and the measurement is not this check's. An empty word is a probe that
## could not be timed, which is the case a broken instrument gives.
rigLanes_(){ ## machine count, the probe's word, [the floor file's word], [a count set by hand]
	rm -f "$rigLanes/pace-floor" "$rigLanes/count"
	printf '%s\n' "$1" > "$rigLanes/max"
	[ -z "${3:-}" ] || printf '%s\n' "$3" > "$rigLanes/pace-floor"
	[ -z "${4:-}" ] || printf '%s\n' "$4" > "$rigLanes/count"
	## The probe's word goes in a variable of the caller: inside the stub, `$2` is the stub's own argument, never the
	## script's, and a stub reading it would answer every case with the empty word.
	bash -c '. "$1" ; rigPace="$2" ; runLaneDir="$3" ; AgentsRunPaceMs(){ printf "%s" "$rigPace" ; } ; AgentsRunLaneCount' rig "$rigLaneCountText" "$2" "$rigLanes" 2>&1
}
rigFloor(){ LC_ALL=C sed -n 1p "$rigLanes/pace-floor" 2> /dev/null || : ; }

echo "-- 1. control, both directions: a count set by hand is the answer, and a machine's own count is read --"
rigAssert "a count set by hand is that count, whatever the pace" "$( rigLanes_ 3 999999 "" 2 )" "2"
rigAssert "and with no count set, the function reads the machine's own and the pace" "$( rigLanes_ 3 100 100 )" "3"

echo "-- 2. the arithmetic: the floor against the pace, clamped at both ends --"
rigAssert "a pace at the floor gives the machine's whole count" "$( rigLanes_ 3 250 250 )" "3"
rigAssert "a pace half again the floor gives two of three lanes" "$( rigLanes_ 3 375 250 )" "2"
rigAssert "three times as slow gives one lane, never none" "$( rigLanes_ 3 750 250 )" "1"
rigAssert "a machine count of one is never passed" "$( rigLanes_ 1 100 1000 )" "1"
rigAssert "a floor of zero is no floor: the count is one lane, never a division by zero" "$( rigLanes_ 3 250 0 )" "1"

echo "-- 3. the floor is the fastest pace this machine has shown --"
rigAssert "a slower pace never raises it" "$( rigLanes_ 3 400 100 )" "1"
rigAssert "and the floor it kept is the faster one" "$( rigFloor )" "100"
rm -f "$rigLanes/pace-floor"
rigAssert "a first reading writes the floor" "$( rigLanes_ 3 250 )" "3"
rigAssert "and that is the pace it read" "$( rigFloor )" "250"
printf '900\n' > "$rigLanes/pace-floor"
touch -t "$( date -r "$(( $( date +%s ) - 172800 ))" '+%Y%m%d%H%M.%S' 2> /dev/null || date -d "@$(( $( date +%s ) - 172800 ))" '+%Y%m%d%H%M.%S' )" "$rigLanes/pace-floor"
rigAssert "a floor a day old is read again, so a busy hour is not kept for ever" "$( rigLanes_ 3 300 )" "3"
rigAssert "and the fresh pace replaces it" "$( rigFloor )" "300"

echo "-- 4. an unmeasurable pace is a busy machine: one lane, never the maximum --"
rigAssert "a probe that cannot be timed at all gives one lane" "$( rigLanes_ 3 "" 250 )" "1"
rigAssert "a reading that is no whole number gives one lane" "$( rigLanes_ 3 "0.250" 250 )" "1"
rigAssert "a reading that is no number at all gives one lane" "$( rigLanes_ 3 "unknown" 250 )" "1"
rigAssert "a reading of zero gives one lane, never a division by zero" "$( rigLanes_ 3 "0" 250 )" "1"
rigAssert "and no floor was written from a reading that cannot be measured" "$( rigFloor )" "250"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ RUN TESTS PACE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_PACE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
