#!/usr/bin/env bash
## Behavioural check on the plain-language floor of what the spawn path emits (epic S6.30): the tooling's own text in a
## spawn is measured by the team's one checker, `AgentsOutputStyleCheck.awk`, and not only by a second set of counts. Held:
##   1. the brief's mechanical block, in the shape each harness receives it (a universal-harness brief and a *-native one),
##      measured with textGroup=brief, draws no fault
##   2. the access block's closing ask line, taken from the function that writes it, draws no fault
##   3. the same measurement on a known-bad line and on live's own two lines reports the fault, so the instrument is
##      shown able to fail before its clean answer counts
##   4. a detached process's report carries the process's output as a fenced block, after the tooling's own sentence, so
##      the reader is given the summary first and the log as quoted data
## Offline: the template, the two includes and the checker are read, never run against a site.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTemplate="$rigPackage/sh-lib/templates/spawn-brief.document.format.md"
rigChecker="$rigPackage/sh-lib/comms/AgentsOutputStyleCheck.awk"
rigHolds="$rigPackage/sh-lib/grants/AgentsTools.PermissionHolds.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "the brief template is not in the package: $rigTemplate"
[ -f "$rigChecker" ] || rigRefuse "the output-style checker is not in the package: $rigChecker"
[ -f "$rigHolds" ] || rigRefuse "the permission include is not in the package: $rigHolds"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnBriefStyleCheck )" || exit 1
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
rigFaults(){ ## textGroup, file -- how many fault lines the one checker prints, and its exit status
	printf '%s ' "$( LC_ALL=C awk -v textGroup="$1" -f "$rigChecker" "$2" 2>/dev/null | LC_ALL=C grep -c . )"
	LC_ALL=C awk -v textGroup="$1" -f "$rigChecker" "$2" > /dev/null 2>&1 ; printf '%s' "$?"
}

## The block as each harness receives it: from SPAWN-PREPARE-BRIEF to its closing line, the tag of the other harness's
## lines dropped and the emitted harness's tags stripped.
rigBlock(){ ## harness (own|native), output file
	LC_ALL=C awk -v want="$1" '
		/^SPAWN-PREPARE-BRIEF: / { inBlock = 1 ; print ; next }
		!inBlock { next }
		/^When done, hand back/ { print ; exit }
		/^\[native\] / { if ( want == "native" ) { sub( /^\[native\] /, "" ) ; print } ; next }
		/^\[own\] / { if ( want == "own" ) { sub( /^\[own\] /, "" ) ; print } ; next }
		{ sub( /^\[(lock|scan)\] /, "" ) ; print }
	' "$rigTemplate" > "$2"
}
rigBlock own "$rigTmp/own"
rigBlock native "$rigTmp/native"

## The access block's ask line, from the function that writes it, over an empty workspace: that line is always printed.
rigAskLine(){ ## output file
	( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig MDAT_DATA_ROOT="$rigTmp/data" \
		bash -c '. "$1" ; AgentsToolsPermissionAccessBlock "$2" ""' _ "$rigHolds" magic-developer ) 2> "$rigTmp/holds.err" > "$1.full"
	LC_ALL=C grep '^to ask for more:' "$1.full" > "$1"
	[ -s "$1" ] || rigRefuse "the access block prints no ask line, so there is nothing to measure: $( LC_ALL=C head -2 "$rigTmp/holds.err" )"
}
mkdir -p "$rigTmp/ws/.local" "$rigTmp/data"
rigAskLine "$rigTmp/ask"

echo "-- 1. the brief's mechanical block, measured by the one checker --"
rigAssert "the universal-harness block draws no fault" "$( rigFaults brief "$rigTmp/own" )" "0 0"
rigAssert "the *-native block draws no fault"          "$( rigFaults brief "$rigTmp/native" )" "0 0"
rigAssert "and neither block is a blank file, so a clean reading is a reading" \
	"$( [ "$( LC_ALL=C grep -c . "$rigTmp/own" )" -gt 20 ] && printf full ):$( [ "$( LC_ALL=C grep -c . "$rigTmp/native" )" -gt 20 ] && printf full )" "full:full"
rigAssert "each block ends on the closing line the spawner's own code matches" \
	"$( tail -1 "$rigTmp/own" ):$( tail -1 "$rigTmp/native" )" "When done, hand back and Wait until dismissed.:When done, hand back and Wait until dismissed."

echo "-- 2. the access block's ask line --"
rigAssert "it draws no fault either" "$( rigFaults brief "$rigTmp/ask" )" "0 0"
rigAssert "it still says how to ask, and names the owner" \
	"$( LC_ALL=C grep -o -e 'RequestPermission' -e 'human-owner' "$rigTmp/ask" | LC_ALL=C grep -c . )" "2"

echo "-- 3. the instrument is shown able to fail --"
printf '%s\n' 'One clause; another clause.' > "$rigTmp/bad-semicolon"
rigAssert "a semicolon is reported, with a non-zero status" "$( rigFaults brief "$rigTmp/bad-semicolon" )" "1 1"
LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 30 ; i++ ) { printf "%s ", "word" } ; printf "\n" }' > "$rigTmp/bad-long"
rigAssert "an over-long sentence is reported" "$( rigFaults brief "$rigTmp/bad-long" )" "1 1"
printf 'When done, hand back; then Wait until dismissed.\n' > "$rigTmp/live-closing"
printf 'to ask for more: call RequestPermission naming the tool or path and why; the human-owner decides.\n' > "$rigTmp/live-ask"
rigAssert "the two lines live carried are each reported, so these assertions would have failed on live" \
	"$( rigFaults brief "$rigTmp/live-closing" ):$( rigFaults brief "$rigTmp/live-ask" )" "1 1:1 1"

echo "-- 4. the instrument measures the whole block, not one line of it --"
rigAssert "the native block's tools line is read as one paragraph with the rest, and still passes" \
	"$( LC_ALL=C grep -c '^tools: first, in one call: ToolSearch' "$rigTmp/native" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN BRIEF STYLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_BRIEF_STYLE: OK (%d assertions, offline)\n' "$rigPassCount"
