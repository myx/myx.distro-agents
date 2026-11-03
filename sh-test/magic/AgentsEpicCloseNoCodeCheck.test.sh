#!/usr/bin/env bash
## Behavioural check on S24.17 of the refactorings epic: the epic-close steps 1 to 4 are optional for an
## epic that changes no code, and step 5 still runs for it. Read over the package's own routine, and run once.
## Held:
##   1. control: the routine's Steps region is read, and steps 1 to 5 are all found
##   2. each of steps 1 to 4 carries the skip
##   3. step 5 carries no skip, so it runs for such an epic
##   4. the routine's own rule names pack-delete as what such an epic runs
##   5. control: the same reading on a copy with one step's skip removed finds one step unskipped
## Offline: the routine file and two copies of it under this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigRoutine="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.epic-close.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRoutine" ] || rigRefuse "the epic-close routine is not at the origin this workspace resolves: $rigRoutine"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsEpicCloseNoCodeCheck.XXXXXX" )" || exit 1
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
## Every line of one numbered step, its continuation lines included, from the step's line up to the next step.
rigStepLines(){ ## routine file, step number
	LC_ALL=C awk -v wantStep="$2" '
		/^# Steps$/ { inSteps = 1 ; next }
		inSteps && /^# / { exit }
		inSteps && /^[0-9]+\. / {
			if ( taking ) { exit }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 ; print ; next }
			next
		}
		taking { print }
	' "$1"
}
## How many of steps 1 to 4 carry the skip, and whether step 5 does.
rigSkipCount(){ ## routine file
	rigSkips=0
	for rigStep in 1 2 3 4 ; do
		[ "$( rigStepLines "$1" "$rigStep" | LC_ALL=C grep -c 'Skipped for an epic that changes no code' )" -ge 1 ] && rigSkips=$(( rigSkips + 1 ))
	done
	printf '%s' "$rigSkips"
}

echo "-- 1. control: the Steps region is read, and steps 1 to 5 are all found --"
rigFound=0
for rigStep in 1 2 3 4 5 ; do
	[ "$( rigStepLines "$rigRoutine" "$rigStep" | LC_ALL=C grep -c . )" -ge 1 ] && rigFound=$(( rigFound + 1 ))
done
rigAssert "all five numbered steps of the routine are read" "$rigFound" 5

echo "-- 2. each of steps 1 to 4 carries the skip --"
rigAssert "the four steps before pack-delete each carry it" "$( rigSkipCount "$rigRoutine" )" 4

echo "-- 3. step 5 carries no skip --"
rigAssert "pack-delete carries no skip of its own" \
	"$( rigStepLines "$rigRoutine" 5 | LC_ALL=C grep -c 'Skipped for an epic that changes no code' )" 0

echo "-- 4. the routine's own rule names pack-delete for such an epic --"
rigRule="$( LC_ALL=C awk '/^# Routine.s local rules$/ { inRules = 1 ; next } inRules && /^# / { exit } inRules { print }' "$rigRoutine" )"
rigAssert "a rule says such an epic skips steps 1 to 4" "$( printf '%s\n' "$rigRule" | LC_ALL=C grep -c 'skips steps 1 to 4' )" 1
rigAssert "and the same rule names pack-delete as what it runs" "$( printf '%s\n' "$rigRule" | LC_ALL=C grep -c 'runs \*\*pack-delete\*\*' )" 1

echo "-- 5. control: copies that lose the skip find it, one step at a time and everywhere --"
LC_ALL=C sed 's/Skipped for an epic that changes no code\.//' "$rigRoutine" > "$rigTmp/no-skips.md"
rigAssert "control: with the skip removed everywhere, no step carries it" "$( rigSkipCount "$rigTmp/no-skips.md" )" 0
LC_ALL=C sed '/owner-commit/ s/Skipped for an epic that changes no code\.//' "$rigRoutine" > "$rigTmp/step-one-unskipped.md"
rigAssert "control: with step 1's skip gone alone, three remain" "$( rigSkipCount "$rigTmp/step-one-unskipped.md" )" 3

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
