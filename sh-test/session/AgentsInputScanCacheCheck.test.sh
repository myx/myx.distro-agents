#!/usr/bin/env bash
## AgentsInputScanCacheCheck -- sketch 7.1, option A: the spawner calls one scan twice for one start, the real
## run and its own bare-named seed read right after. A second start of the same session, soon after the first,
## runs the same scan a third time. None of this is cached: a member who re-reads a scan's own CLI operation
## through head, grep or sed, inside the same five minutes, pays for the whole scan again too (the sketch's own
## PROBLEM note). AgentsToolsInputScanDefRun must serve a repeat of the one words, for the one session, from
## what the first call wrote, not run the scan again. A different session, or a different scan, is not served
## from another's cache. Offline by construction: DistroAgentsTools is stubbed, no host and no board reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigDef="$rigHere/session/AgentsTools.InputScanDef.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigDef" ] || rigRefuse "the input-scan definitions are not in the package: $rigDef"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInputScanCacheCheck )" || exit 1
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
## Runs the scenario in a clean process: a stubbed DistroAgentsTools counts its own calls to a file, and the
## real include is sourced over it, never the other way round.
rigRun(){
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" COUNT_FILE="$rigTmp/count" bash -c '
		set -u
		: > "$COUNT_FILE"
		DistroAgentsTools(){ printf x >> "$COUNT_FILE" ; printf "report for: %s\n" "$*" ; }
		AgentsToolsRoutineKeyLines(){ :; }
		. "'"$rigDef"'"
		AgentsToolsInputScanDefRun "work-duty" "magic-developer" "sess-1" "" "'"$rigTmp"'/out.1" > /dev/null 2>&1
		AgentsToolsInputScanDefRun "work-duty" "magic-developer" "sess-1" "" "'"$rigTmp"'/out.2" > /dev/null 2>&1
		AgentsToolsInputScanDefRun "work-duty" "magic-developer" "sess-2" "" "'"$rigTmp"'/out.3" > /dev/null 2>&1
		AgentsToolsInputScanDefRun "grooming"  "magic-developer" "sess-1" "" "'"$rigTmp"'/out.4" > /dev/null 2>&1
	'
	wc -c < "$rigTmp/count" | LC_ALL=C tr -d ' '
}

echo "-- the same scan, for the same session, soon after, is served once and run once --"
rigAssert "4 starts (a repeat, a different session, a different scan) run the scan 3 times, not 4" "$( rigRun )" "3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN CACHE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_CACHE: OK (%d assertions, offline)\n' "$rigPassCount"
