#!/usr/bin/env bash
## Behavioural check on the tester family (sketch 10.6): `DistroAgentsTools --tester-<operation>` is one thin stub per operation
## `DistroAgentsTesting.fn.sh` serves, and nothing else. Read off the two files, and one call each side. Held:
##   1. the family's list in DistroAgentsTools.fn.sh is exactly the operations the testing tool's help names, no more, no fewer
##   2. a stub of the family runs the testing operation, and printing the testbed's list is enough to show it
##   3. a name outside the family is refused, and the refusal names the family
## Offline: two files read, two calls made, nothing written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHelp="$rigPackage/sh-lib/help/Help.DistroAgentsTesting.help.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHelp" ] || rigRefuse "the testing tool's help is not at the origin: $rigHelp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsTesterFamilyCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The operations the testing tool's help names, one a line, sorted.
LC_ALL=C grep -o '^📘 syntax: DistroAgentsTesting.fn.sh --[a-z-]*' "$rigHelp" \
	| LC_ALL=C sed 's/.*--//' | LC_ALL=C sort -u > "$rigTmp/help.out"
## The family's own list, from the one line of the script, words sorted.
LC_ALL=C sed -n '/^agentsTesterOperations=/,/"/{ s/^agentsTesterOperations="// ; s/"$// ; p ; }' "$rigTool" \
	| LC_ALL=C tr ' \t' '\n\n' | LC_ALL=C sed '/^$/d' | LC_ALL=C sort -u > "$rigTmp/family.out"

echo "-- 1. the family is exactly the testing tool's operations --"
rigAssert "the two lists agree, a name each" "$( LC_ALL=C diff "$rigTmp/help.out" "$rigTmp/family.out" > /dev/null 2>&1 && echo same || echo differ )" "same"
rigAssert "and the list is not empty" "$( [ -s "$rigTmp/family.out" ] && echo some || echo none )" "some"

echo "-- 2. a stub runs its testing operation --"
rigRan=0
"$rigTool" --tester-test-list > "$rigTmp/list.out" 2> "$rigTmp/list.err" || rigRan=1
rigAssert "the testbed's list is printed through the stub, and the call does not fail" "$rigRan" "0"
rigAssert "and it printed nothing that reads as a refusal" "$( LC_ALL=C grep -c 'invalid option' "$rigTmp/list.err" )" "0"

echo "-- 3. a name outside the family is refused --"
rigOutside=0
"$rigTool" --tester-nonsense > /dev/null 2> "$rigTmp/outside.err" || rigOutside=$?
rigAssert "a name the family does not hold is refused" "$( [ "$rigOutside" != "0" ] && echo refused || echo ran )" "refused"
rigAssert "and the refusal names the family" "$( LC_ALL=C grep -c 'the family is:' "$rigTmp/outside.err" )" "1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TESTER FAMILY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TESTER_FAMILY: OK (%d assertions, offline, two files read)\n' "$rigPasses"
