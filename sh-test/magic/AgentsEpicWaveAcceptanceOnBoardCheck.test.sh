#!/usr/bin/env bash
## Behavioural check on S6.2 of the refactorings epic: THE WAVE ROUTINE ACCEPTS EACH APPLIED FEATURE ON ITS BUILDER
## TASK, so the board is the record of acceptance and the epic carries no status line. Read over the package's own
## routine, and run once. Held:
##   1. control: the routine's `# Steps` region is read, and its set-status step is found after the step before it
##   2. that step accepts the feature on its builder task with `--accept-review`
##   3. and it does so before it moves the item to the epic's `## Done`
##   4. and it says the board is the record of acceptance
##   5. the local rules bar a status line in the epic
##   6. the tooling list names `--accept-review`, beside its owner `DistroAgentsItems`
##   7. control: copies with each of those lines removed find none of them, so no assertion above is always red
## Offline: the routine file and three copies of it under this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigRoutine="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.epic-wave.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRoutine" ] || rigRefuse "the wave routine is not at the origin this workspace resolves: $rigRoutine"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsEpicWaveAcceptanceOnBoardCheck.XXXXXX" )" || exit 1
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
## The lines of a named `# ` or `## ` section, its heading left out.
rigSectionLines(){ ## routine file, heading text
	LC_ALL=C awk -v wantHeading="$2" '
		$0 == wantHeading { taking = 1 ; next ; }
		taking && /^#/ { exit ; }
		taking { print ; }
	' "$1"
}
## How many of a region's lines name a word.
rigCountIn(){ ## region lines, word
	printf '%s\n' "$1" | LC_ALL=C grep -c -F -- "$2"
}

echo "-- 1. control: the set-status step is found, after the step before it --"
rigSetStatus="$( rigStepNumber "$rigRoutine" set-status )"
rigRuleGaps="$( rigStepNumber "$rigRoutine" rule-gaps )"
rigAssert "the routine names its rule-gaps step" "$rigRuleGaps" 4
rigAssert "and its set-status step, after it" "$rigSetStatus" 6
rigSetLines="$( rigStepLines "$rigRoutine" "$rigSetStatus" )"
rigAssert "control: the set-status step carries lines of its own" \
	"$( printf '%s\n' "$rigSetLines" | LC_ALL=C grep -c -F -- '**set-status**' )" 1

echo "-- 2. that step accepts the feature on its builder task --"
rigAssert "the step accepts it with --accept-review" \
	"$( rigCountIn "$rigSetLines" '--accept-review' )" 1
rigAssert "and says the acceptance lands on the builder task" \
	"$( rigCountIn "$rigSetLines" 'builder task' )" 1
echo "-- 3. and it accepts before it moves the item to ## Done --"
rigAcceptAt="$( printf '%s\n' "$rigSetLines" | LC_ALL=C awk -v wantWord='--accept-review' '{ at = index( $0, wantWord ) ; if ( at > 0 ) { print at ; exit ; } }' )"
rigDoneAt="$( printf '%s\n' "$rigSetLines" | LC_ALL=C awk -v wantWord='--epic-update' '{ at = index( $0, wantWord ) ; if ( at > 0 ) { print at ; exit ; } }' )"
rigAcceptFirst=no
[ -n "$rigAcceptAt" ] && [ -n "$rigDoneAt" ] && [ "$rigAcceptAt" -lt "$rigDoneAt" ] && rigAcceptFirst=yes
rigAssert "the accept comes before the Done move" "$rigAcceptFirst" yes

echo "-- 4. and it says the board is the record of acceptance --"
rigAssert "the step says the board records the acceptance" \
	"$( rigCountIn "$rigSetLines" 'The board is the record of acceptance' )" 1

echo "-- 5. the local rules bar a status line in the epic --"
rigRuleLines="$( rigSectionLines "$rigRoutine" "# Routine's local rules" )"
rigAssert "the local rules are read" \
	"$( rigCountIn "$rigRuleLines" 'Never edit the epic by hand' )" 1
rigAssert "a rule bars a status line in the epic" \
	"$( rigCountIn "$rigRuleLines" 'No status line goes into the epic' )" 1

echo "-- 6. the tooling list names the operation and its owner --"
rigToolLines="$( rigSectionLines "$rigRoutine" "## Tooling operations" )"
rigAssert "the tooling list is read" \
	"$( rigCountIn "$rigToolLines" '--epic-update' )" 2
rigAssert "it names --accept-review, owned by DistroAgentsItems" \
	"$( printf '%s\n' "$rigToolLines" | LC_ALL=C grep -c -F -- '--accept-review' )" 1
rigAssert "and the line that names it names its owner" \
	"$( printf '%s\n' "$rigToolLines" | LC_ALL=C grep -F -- '--accept-review' | LC_ALL=C grep -c -F -- 'DistroAgentsItems' )" 1

echo "-- 7. control: copies with each line removed find none of them --"
LC_ALL=C grep -v -F -- '--accept-review' "$rigRoutine" > "$rigTmp/no-accept.md"
LC_ALL=C grep -v -F -- 'The board is the record of acceptance' "$rigRoutine" > "$rigTmp/no-board.md"
LC_ALL=C grep -v -F -- 'No status line goes into the epic' "$rigRoutine" > "$rigTmp/no-rule.md"
rigAssert "control: the copy without the accept line accepts nowhere" \
	"$( rigCountIn "$( rigStepLines "$rigTmp/no-accept.md" 6 )" '--accept-review' )" 0
rigAssert "control: the copy without the board line carries the sentence nowhere" \
	"$( rigCountIn "$( rigStepLines "$rigTmp/no-board.md" 6 )" 'The board is the record of acceptance' )" 0
rigAssert "control: the copy without the rule bars no status line" \
	"$( rigCountIn "$( rigSectionLines "$rigTmp/no-rule.md" "# Routine's local rules" )" 'No status line goes into the epic' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
