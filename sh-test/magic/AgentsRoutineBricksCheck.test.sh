#!/usr/bin/env bash
## Behavioural check on the team's process-flow bricks (S19 of the refactorings epic), run rather than read: every routine
## the team's armed file names is a real file, and the validator takes it with no row.
##   1. THE LIST IS READ: the armed file names its routines, so a pass over none of them is no pass.
##   2. EVERY ONE OF THEM IS A FILE in the team's own skillset folder.
##   3. THE VALIDATOR TAKES EVERY ONE: front matter, the required headers and the step groups, no row.
##   4. THE BRICKS THE ITEM NAMES EXIST: process-inbox, interview, discuss, brainstorm, research, proposal and investigate,
##      which the item records as missing.
## Offline: the package at this origin, and the validator's own read-only call for each routine.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTeam="$rigPackage/skillset/magic-team/magic-team"
rigArmed="$rigTeam/magic-team.armed.md"
rigTool="$rigPackage/sh-scripts/DistroAgentsTesting.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigArmed" ] || rigRefuse "not found at the origin this workspace resolves: $rigArmed"
[ -f "$rigTool" ] || rigRefuse "not found at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineBricksCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## The routine files the armed file names, one a line, each once.
rigNamed="$( LC_ALL=C grep -o 'magic-team\.[a-z-]*\.routine\.md' "$rigArmed" | LC_ALL=C sort -u )"
rigCount="$( printf '%s\n' "$rigNamed" | LC_ALL=C grep -c . )"

echo "-- 1. the list is read --"
rigAssert "the armed file names its routines"                        "$( [ "$rigCount" -ge 5 ] && printf enough || printf few )" enough

echo "-- 2. every one of them is a file --"
rigMissing=""
while IFS= read -r rigOne ; do
	[ -z "$rigOne" ] || [ -f "$rigTeam/$rigOne" ] || rigMissing="$rigMissing $rigOne"
done <<< "$rigNamed"
rigAssert "every routine the armed file names exists"                "${rigMissing:-none}" none

echo "-- 3. the validator takes every one --"
rigUnsound=""
while IFS= read -r rigOne ; do
	[ -z "$rigOne" ] || [ -f "$rigTeam/$rigOne" ] || continue
	rigRow="$( MDLT_ORIGIN="$rigOrigin" MMDAPP="$MMDAPP" bash "$rigTool" --skillset-validate-routine "$rigTeam/$rigOne" 2>&1 )"
	rigRc=$?
	[ "$rigRc" = 0 ] && [ -z "$rigRow" ] || rigUnsound="$rigUnsound $rigOne"
done <<< "$rigNamed"
rigAssert "no routine is refused by the validator"                   "${rigUnsound:-none}" none

echo "-- 4. the bricks the item names exist --"
rigBricks="process-inbox interview discuss brainstorm research proposal investigate"
rigAbsent=""
for rigBrick in $rigBricks ; do
	[ -f "$rigTeam/magic-team.$rigBrick.routine.md" ] || rigAbsent="$rigAbsent $rigBrick"
done
rigAssert "the named bricks are all there, investigate included"     "${rigAbsent:-none}" none

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions, %s routines)\n' "$rigPassCount" "$rigCount"
exit 0
