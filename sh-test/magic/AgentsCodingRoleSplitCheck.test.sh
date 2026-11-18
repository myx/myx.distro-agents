#!/usr/bin/env bash
## Behavioural check on S10.10 of the refactorings epic: the coding roles are split. A keeper or any other member
## describes the code and the change it wants, and magic-developer makes that change, turns its test green, reviews
## it with the member that asked, joins the architect or the librarian where needed, and hands back the patch to
## apply. Read over the team's own armed file, and run once.
## Held:
##   1. control: the armed file is read, and the consult rule that stands in it today is found
##   2. each of the five statements of the split stands in that file, once
##   3. control: the same reading finds a statement once where it is written, and nowhere where it is not
## Offline: the armed file at this origin, and two rig copies.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigArmed="$rigPackage/skillset/magic-team/magic-team/magic-team.armed.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigArmed" ] || rigRefuse "the team armed file is not at the origin this workspace resolves: $rigArmed"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCodingRoleSplitCheck )" || exit 1
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
## The five statements of the split, in the words the change lands, one a line.
rigStatements='describes the code and the change it wants
makes that change and turns its test green
reviews the change with the member that asked
also takes `magic-architect` and `magic-librarian` where the change is
hands back the patch to apply'
## How many times one statement stands in one file.
rigCount(){ ## file, statement
	LC_ALL=C grep -c -F -- "$2" "$1" || :
}
## How many of the five statements stand in one file.
rigFoundIn(){ ## file
	rigTotal=0
	while IFS= read -r rigOne ; do
		[ -z "$rigOne" ] || rigTotal=$(( rigTotal + $( rigCount "$1" "$rigOne" ) ))
	done <<< "$rigStatements"
	printf '%s' "$rigTotal"
}

echo "-- 1. control: the armed file is read, and the consult rule it holds today is found --"
rigAssert "the armed file carries the consult rule"                    "$( rigCount "$rigArmed" 'invokes `magic-developer` first' )" 1
rigAssert "so a read of it finds a line that is known to be there"     "$( rigCount "$rigArmed" 'A reviewer of changed code reads' )" 1

echo "-- 2. each of the five statements of the split stands in that file --"
while IFS= read -r rigOne ; do
	[ -z "$rigOne" ] || rigAssert "the armed file carries: $rigOne" "$( rigCount "$rigArmed" "$rigOne" )" 1
done <<< "$rigStatements"

echo "-- 3. control: found where written, nowhere where not --"
printf '%s\n' "$rigStatements" > "$rigTmp/written.md"
: > "$rigTmp/absent.md"
rigAssert "control: all five read out of a copy that carries them"     "$( rigFoundIn "$rigTmp/written.md" )" 5
rigAssert "control: none read out of a copy that carries none of them" "$( rigFoundIn "$rigTmp/absent.md" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
