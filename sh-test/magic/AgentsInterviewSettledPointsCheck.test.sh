#!/usr/bin/env bash
## Behavioural check on S24.16 of the refactorings epic: each interview question is checked against the
## settled points first, so a question they answer is never put to the party. Read over the package's
## own routine, and run once.
## Held:
##   1. control: the routine's reassess step is found, and it is numbered after the step that gathers
##   2. that step carries the check of each question against the settled points
##   3. and it says a question they answer is dropped, never asked
##   4. control: the same reading on a copy with those two lines removed finds none of them
## Offline: the routine file and two copies of it under this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigRoutine="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.interview.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRoutine" ] || rigRefuse "the interview routine is not at the origin this workspace resolves: $rigRoutine"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsInterviewSettledPointsCheck.XXXXXX" )" || exit 1
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
## The number of the step that carries a named step, in the `# Steps` region, or `none`.
rigStepNumber(){ ## routine file, step name
	LC_ALL=C awk -v wantName="$2" '
		/^# Steps$/ { inSteps = 1 ; next }
		inSteps && /^# / { exit }
		inSteps && /^[0-9]+\. \*\*/ {
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( index( $0, "**" wantName "**" ) > 0 ) { print stepNumber ; found = 1 ; exit }
		}
		END { if ( ! found ) { print "none" ; } }
	' "$1"
}
## The tab-separated tabs of the numbered step region: the step's own tabs and its numbered sub-tabs.
rigStepLines(){ ## routine file, step number
	LC_ALL=C awk -v wantStep="$2" '
		/^# Steps$/ { inSteps = 1 ; next }
		inSteps && /^# / { exit }
		inSteps && /^[0-9]+\. / {
			if ( taking ) { exit }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 }
			next
		}
		taking { print }
	' "$1"
}

echo "-- 1. control: the reassess step is named, and it comes after the gathering step --"
rigGather="$( rigStepNumber "$rigRoutine" resume-review )"
rigReassess="$( rigStepNumber "$rigRoutine" reassess-before-next-message )"
rigAssert "the routine names its resume-review step" "$rigGather" 5
rigAssert "and its reassess-before-next-message step" "$rigReassess" 6

echo "-- 2. that step carries the check of each question against the settled points --"
rigAssert "the step checks each question against the settled points" \
	"$( rigStepLines "$rigRoutine" 6 | LC_ALL=C grep -c 'check each question against the settled points' )" 1

echo "-- 3. and it says a question they answer is dropped, never asked --"
rigAssert "the same line says such a question is dropped, never asked" \
	"$( rigStepLines "$rigRoutine" 6 | LC_ALL=C grep -c 'is dropped, never asked' )" 1

echo "-- 4. control: copies with those lines removed find none of them --"
LC_ALL=C grep -v 'check each question against the settled points' "$rigRoutine" > "$rigTmp/no-check.md"
LC_ALL=C grep -v 'is dropped, never asked' "$rigRoutine" > "$rigTmp/no-drop.md"
rigAssert "control: the copy without the check line carries it nowhere" \
	"$( rigStepLines "$rigTmp/no-check.md" 6 | LC_ALL=C grep -c 'check each question against the settled points' )" 0
rigAssert "control: the copy without the drop line carries it nowhere" \
	"$( rigStepLines "$rigTmp/no-drop.md" 6 | LC_ALL=C grep -c 'is dropped, never asked' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
