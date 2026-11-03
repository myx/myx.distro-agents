#!/usr/bin/env bash
## Behavioural check on S24.15 of the refactorings epic: `investigation-round` is the first step of the
## interview routine, so no question is put to the party before every source the task names has been read.
## Read over the package's own routine, and run once.
## Held:
##   1. control: the routine's Steps region is read, and its first numbered step is found
##   2. the first step is `investigation-round`
##   3. and it runs before the first question, as its own words say
##   4. control: the same reading on a copy whose first two steps are swapped finds another step first
## Offline: the routine file and two copies of it under this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigRoutine="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.interview.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRoutine" ] || rigRefuse "the interview routine is not at the origin this workspace resolves: $rigRoutine"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsInterviewInvestigationFirstCheck.XXXXXX" )" || exit 1
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
## The text of `# Steps` from one numbered step up to the next, the step's own numbering removed.
rigStepText(){ ## routine file, step number
	LC_ALL=C awk -v wantStep="$2" '
		/^# Steps$/ { inSteps = 1 ; next }
		inSteps && /^# / { exit }
		inSteps && /^[0-9]+\. / {
			if ( taking ) { exit }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 ; print }
			next
		}
		taking { print }
	' "$1"
}

echo "-- 1. control: the Steps region is read, and its first numbered step is found --"
rigFirstStep="$( rigStepText "$rigRoutine" 1 | LC_ALL=C sed -n 's/^[0-9]*\. \*\*\([a-z-]*\)\*\*.*/\1/p' | head -1 )"
rigAssert "the first numbered step of the routine is named" "$( [ -n "$rigFirstStep" ] && printf found || printf none )" found

echo "-- 2. the first step is investigation-round --"
rigAssert "step 1 is investigation-round" "$rigFirstStep" investigation-round

echo "-- 3. and it runs before the first question --"
rigAssert "step 1 says it runs before the first question" \
	"$( rigStepText "$rigRoutine" 1 | LC_ALL=C grep -c 'before the first question' )" 1

echo "-- 4. control: the same reading on a copy whose first two steps are swapped --"
cp -p "$rigRoutine" "$rigTmp/swapped.md" || rigRefuse "the routine could not be copied for its own control"
LC_ALL=C sed -e 's/^1\. \*\*investigation-round\*\*/2. **investigation-round**/' \
	-e 's/^2\. \*\*process-own-inbox\*\*/1. **process-own-inbox**/' \
	"$rigRoutine" > "$rigTmp/swapped.md"
rigSwappedFirst="$( rigStepText "$rigTmp/swapped.md" 1 | LC_ALL=C sed -n 's/^[0-9]*\. \*\*\([a-z-]*\)\*\*.*/\1/p' | head -1 )"
rigAssert "control: the swapped copy reads another step first" "$( [ "$rigSwappedFirst" = investigation-round ] && printf investigation-round || printf "${rigSwappedFirst:-none}" )" process-own-inbox

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
