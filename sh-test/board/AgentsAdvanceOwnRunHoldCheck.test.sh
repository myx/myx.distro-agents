#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on S16 stage 2 item 4: the advance routine's hand-or-run step compares the
## holder the digest names with THIS PASS'S OWN RUN, so a sweeper does not read its own hold as a
## third party's. Read over the package's own routine. Held:
##   1. control: the hand-or-run step is found, in the routine's `# Steps`, after pick-the-iteration
##   2. it reads the digest's `held` line and names the holder's spawn id
##   3. it compares that with this pass's own run, and says which of the two runs the round
##   4. the other run's branch names the `no-action` outcome, and its own run's branch runs the round
##   5. controls: copies with each of those parts removed find none of them, so no assertion above
##      is always green
## Offline: the routine file and three copies of it under this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigRoutine="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.advance.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRoutine" ] || rigRefuse "the advance routine is not at the origin this workspace resolves: $rigRoutine"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAdvanceOwnRunHoldCheck )" || exit 1
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
		/^# Steps$/ { inSteps = 1 ; next ; }
		inSteps && /^# / { exit ; }
		inSteps && /^[0-9]+\. \*\*/ {
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( index( $0, "**" wantName "**" ) > 0 ) { print stepNumber ; found = 1 ; exit ; }
		}
		END { if ( ! found ) { print "none" ; } ; }
	' "$1"
}
## The lines of one numbered step region: the step's own line and its tabled sub-lines.
rigStepLines(){ ## routine file, step number
	LC_ALL=C awk -v wantStep="$2" '
		/^# Steps$/ { inSteps = 1 ; next ; }
		inSteps && /^# / { exit ; }
		inSteps && /^[0-9]+\. / {
			if ( taking ) { exit ; }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 ; print ; }
			next
		}
		taking { print ; }
	' "$1"
}
## How many of a region's lines name a word.
rigCountIn(){ ## region lines, word
	printf '%s\n' "$1" | LC_ALL=C grep -c -F -- "$2"
}

echo "-- 1. control: the hand-or-run step is found, after pick-the-iteration --"
rigHandOrRun="$( rigStepNumber "$rigRoutine" hand-or-run )"
rigPickIteration="$( rigStepNumber "$rigRoutine" pick-the-iteration )"
rigAssert "the routine names its pick-the-iteration step" "$rigPickIteration" 1
rigAssert "and its hand-or-run step, after it" "$rigHandOrRun" 2
rigStepText="$( rigStepLines "$rigRoutine" "$rigHandOrRun" )"
rigAssert "control: the hand-or-run step carries lines of its own" \
	"$( printf '%s\n' "$rigStepText" | LC_ALL=C grep -c -F -- '**hand-or-run**' )" 1

echo "-- 2. it reads the digest's held line and names the holder's spawn id --"
rigAssert "the step reads the digest's held line" \
	"$( rigCountIn "$rigStepText" 'the digest marks the item `held`' )" 1
rigAssert "and names the holder by its spawn id" \
	"$( rigCountIn "$rigStepText" "that holder's spawn id" )" 1

echo "-- 3. and compares it with this pass's own run --"
rigAssert "the step names this pass's own run as the other side of the comparison" \
	"$( rigCountIn "$rigStepText" "compare that holder's spawn id with this pass's own run" )" 1
rigAssert "and keeps the two answers apart: another run holds it, or this pass's own run does" \
	"$( rigCountIn "$rigStepText" "This pass's own run holds it" )" 1

echo "-- 4. each branch names what it does --"
rigAssert "another run's branch runs nothing and names the no-action outcome" \
	"$( rigCountIn "$rigStepText" 'Another run holds it: run nothing, and name the holder. Outcome `no-action`.' )" 1
rigAssert "and this pass's own run's branch runs the round" \
	"$( rigCountIn "$rigStepText" 'run the round, per the round' )" 1

echo "-- 5. controls: copies without each part find none of it --"
LC_ALL=C grep -v -F -- "compare that holder's spawn id with this pass's own run" "$rigRoutine" > "$rigTmp/no-compare.md"
LC_ALL=C grep -v -F -- 'the digest marks the item `held`' "$rigRoutine" > "$rigTmp/no-held.md"
LC_ALL=C grep -v -F -- "This pass's own run holds it" "$rigRoutine" > "$rigTmp/no-own.md"
rigAssert "control: the copy without the comparison compares nothing" \
	"$( rigCountIn "$( rigStepLines "$rigTmp/no-compare.md" "$rigHandOrRun" )" "compare that holder's spawn id with this pass's own run" )" 0
rigAssert "control: the copy without the held line reads no digest hold" \
	"$( rigCountIn "$( rigStepLines "$rigTmp/no-held.md" "$rigHandOrRun" )" 'the digest marks the item `held`' )" 0
rigAssert "control: the copy without the own-run branch names no own run" \
	"$( rigCountIn "$( rigStepLines "$rigTmp/no-own.md" "$rigHandOrRun" )" "This pass's own run holds it" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'ADVANCE_OWN_RUN_HOLD: OK (%s assertions, offline)\n' "$rigPassCount"
