#!/usr/bin/env bash
## Behavioural check on AgentsHarnessAwkAxiom.test.awk, the missing-`;` checker: a line
## ending in a shell `${...}` expansion is not flagged, and an awk block ending in a
## statement with no `;` still is. Offline: a temp file of sample lines.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigChecker="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsHarnessAwkAxiom.test.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigChecker" ] || rigRefuse "the checker is not at the origin this workspace resolves: $rigChecker"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsHarnessAwkAxiomCheck.XXXXXX" )" || exit 1
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
## Whether the checker flags this one line: flagged or clean.
rigFlags(){ ## line text
	printf '%s\n' "$1" > "$rigTmp/sample"
	if LC_ALL=C awk -f "$rigChecker" "$rigTmp/sample" > /dev/null ; then printf clean ; else printf flagged ; fi
}

echo "-- shell expansions are not awk blocks --"
rigAssert 'x=${#arr[@]} is not flagged'                    "$( rigFlags '	x=${#arr[@]}' )" clean
rigAssert 'y=${name} is not flagged'                        "$( rigFlags '	y=${name}' )" clean
rigAssert 'a nested ${a:-${b}} is not flagged'              "$( rigFlags '	z=${a:-${b}}' )" clean
echo "-- control: awk blocks are still checked --"
rigAssert '{ print x } is still flagged'                    "$( rigFlags '	{ print x }' )" flagged
rigAssert 'NR==1 { if (a) { b=1 } ; next } is still flagged' "$( rigFlags '	NR==1 { if (a) { b=1 ; } ; next }' )" flagged
rigAssert 'a block closing after ${x} is still flagged'     "$( rigFlags '	{ v = "${x}" ; print v }' )" flagged
rigAssert '{ print x ; } is clean'                          "$( rigFlags '	{ print x ; }' )" clean

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AWK AXIOM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AWK_AXIOM: OK (%d assertions, offline)\n' "$rigPassCount"
