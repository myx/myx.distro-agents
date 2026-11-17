#!/usr/bin/env bash
## Behavioural check on S6.31's tooling half: a routine states the deliverables its steps produce as
## `deliverables:` lines, and the item a review judges must reach the judge as the items the routine wrote,
## never as more or fewer. The review joins the items by `;` on one header line and reads them back by that
## same character, so an item that holds a semicolon would reach the judge as two items, and no reader could
## tell a routine declaring one such item from a routine declaring two. Held:
##   1. a routine declaring a deliverable with no separator validates, at save and at spawn
##   2. a routine declaring an item that holds `;` is refused at save, and the refusal names the item
##   3. the same routine is refused at spawn, so nothing starts
##   4. the round trip the carry takes keeps one item, one item: the join and the split of two plain items
##      return those two
##   5. control for 4: the same join and split of one item holding `;` returns three, which is what makes 2
##      a defect rather than a style
##   6. control: a routine declaring none validates, so the key is not required
## Red before the separator was refused: 2 and 3 fail. Red before the key was asked at save: 2 fails.
## Offline: every tree is this rig's own, and no routine is started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigLib/routine/AgentsTools.RoutineRequirements.include" "$rigLib/team-data/AgentsTools.DocValidateRuleSets.include" "$rigFixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineDeliverableCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export MDLT_ORIGIN MMDAPP="$rigTmp/ws"
mkdir -p "$MMDAPP/.local/temp" || exit 1
. "$rigLib/routine/AgentsTools.RoutineRequirements.include" || rigRefuse "the requirements include would not load"
. "$rigLib/team-data/AgentsTools.DocValidateRuleSets.include" || rigRefuse "the rule sets include would not load"
rigHead='---
type: routine
executors: magic-developer
maintainers: magic-coordinator
requires-session-kind: standalone
review-by: inherit
'
## One routine written as the daemon shape: the declaration, given as printf words.
rigWrite(){
	printf '%s' "$rigHead" > "$1"
	printf '%s' "$2" >> "$1"
	printf -- '---\n# rig routine\n' >> "$1"
}
rigAsked=0
rigFail=0
rigAssert(){ ## what, got, want
	rigAsked=$(( rigAsked + 1 ))
	if [ "$2" = "$3" ] ; then
		printf 'ok   %s\n' "$1"
	else
		printf 'FAIL %s\n     got:  %s\n     want: %s\n' "$1" "$2" "$3"
		rigFail=$(( rigFail + 1 ))
	fi
}
rigVerdict(){ ## routine file, site
	AgentsToolsRoutineRequirement deliverables "$2" "$1" | LC_ALL=C awk -F'\t' '{ print $1 }'
}
rigWrite "$rigTmp/plain.routine.md" 'deliverables: the decisions, in a named document
'
rigWrite "$rigTmp/separated.routine.md" 'deliverables: the options weighed; each with its cost
'
rigWrite "$rigTmp/none.routine.md" ''
rigAssert "1. a plain declaration validates at save" "$( rigVerdict "$rigTmp/plain.routine.md" save )" validate
rigAssert "1. a plain declaration validates at spawn" "$( rigVerdict "$rigTmp/plain.routine.md" spawn )" validate
rigAssert "2. an item holding a separator is refused at save" "$( rigVerdict "$rigTmp/separated.routine.md" save )" reject
rigAssert "2. the refusal names the item" \
	"$( AgentsToolsRoutineRequirement deliverables save "$rigTmp/separated.routine.md" | LC_ALL=C grep -c -F 'the options weighed; each with its cost' )" 1
rigAssert "3. the same declaration is refused at spawn" "$( rigVerdict "$rigTmp/separated.routine.md" spawn )" reject
## The carry's own round trip, taken from the two sites that do it: the join (AgentsReviewToReview) and the split
## (AgentsReviewPromptPost). A checker that only passed on its own fixture would report green on a broken carry.
rigJoined="$( printf '%s\n' 'the decisions, in decisions-2026-11-17.md' 'the options weighed' | LC_ALL=C awk 'BEGIN { ORS = "" } { printf "%s%s", ( NR > 1 ? "; " : "" ), $0 }' )"
rigAssert "4. two plain items join onto one line" "$rigJoined" 'the decisions, in decisions-2026-11-17.md; the options weighed'
rigAssert "4. and read back as the same two" "$( printf '%s\n' "$rigJoined" | LC_ALL=C tr ';' '\n' | LC_ALL=C grep -c . )" 2
rigJoinedBad="$( printf '%s\n' 'the decisions, in decisions-2026-11-17.md' 'the options weighed; each with its cost' | LC_ALL=C awk 'BEGIN { ORS = "" } { printf "%s%s", ( NR > 1 ? "; " : "" ), $0 }' )"
rigAssert "5. control: one item holding a separator reads back as three" "$( printf '%s\n' "$rigJoinedBad" | LC_ALL=C tr ';' '\n' | LC_ALL=C grep -c . )" 3
rigAssert "6. control: a routine declaring none validates" "$( rigVerdict "$rigTmp/none.routine.md" save )" validate
## The validator asks the same evaluator at save, so the row of one is the row of the other.
rigAssert "the validator reports the separated routine" \
	"$( AgentsToolsDocValidateRoutine "$rigTmp/separated.routine.md" "$rigTmp/separated.routine.md" | LC_ALL=C grep -c 'deliverables:' )" 1
print_summary(){
	printf '%s of %s assertions failed, %s asked\n' "$rigFail" "$rigAsked" "$rigAsked"
	[ "$rigFail" -eq 0 ] || exit 1
}
print_summary
