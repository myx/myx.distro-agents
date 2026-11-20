#!/usr/bin/env bash
## Behavioural check on AgentsHarnessAwkAxiom.test.awk, the missing-`;` checker: a line
## ending in a shell `${...}` expansion is not flagged, and a `}` sharing its line with code and
## no `;` right before it is flagged wherever it stands on that line. With -v awkShell=1 only the lines inside a
## single-quoted region opened on a line naming awk are checked, so an awk program
## held in a `sh` file is examined and the shell around it is not. Offline: a temp
## file of sample lines.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigChecker="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/harness/AgentsHarnessAwkAxiom.test.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigChecker" ] || rigRefuse "the checker is not at the origin this workspace resolves: $rigChecker"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessAwkAxiomCheck )" || exit 1
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
## The same, with the input read as a shell file: the checker's own -v awkShell.
rigFlagsShell(){ ## line text
	printf '%s\n' "$1" > "$rigTmp/sample"
	if AWK_AXIOM_SHELL=1 LC_ALL=C awk -f "$rigChecker" "$rigTmp/sample" > /dev/null ; then printf clean ; else printf flagged ; fi
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
echo "-- every brace on a line is checked, not only the last --"
rigAssert 'a mid-line } with no ; before it is flagged'      "$( rigFlags '	{ if (a) { b = 1 } ; next ; }' )" flagged
rigAssert 'a } closing after a } is flagged'                "$( rigFlags '	{ if (a) { b = 1 ; } }' )" flagged
rigAssert 'the same with ; before each } is clean'          "$( rigFlags '	{ if (a) { b = 1 ; } ; }' )" clean
rigAssert 'a } in a string, a regex or a comment is no code' \
	"$( rigFlags '	$0 ~ /a{2}|[}]/ { s = "a}\"}" ; n = n / 2 ; } # ends } here' )" clean
echo "-- an awk program quoted inside a shell file is examined, and the shell is not --"
## The shape the tree actually has: a shell variable opened on a line that names awk, the program's own lines under it.
printf '%s\n' "rigSpinAwk='" "\t\t{ if (a) { print \"hit\" } }" "'" > "$rigTmp/sample"
if AWK_AXIOM_SHELL=1 LC_ALL=C awk -f "$rigChecker" "$rigTmp/sample" > /dev/null ; then rigShellVerdict=clean ; else rigShellVerdict=flagged ; fi
rigAssert 'an awk program held in a sh file is flagged where it should be' "$rigShellVerdict" flagged
rigAssert 'its clean sibling is not'                        "$( rigFlagsShell 'awk '\''\''{ print x ; }'\'''\'' f' )" clean
rigAssert 'and a shell line holding no awk is passed over'  "$( rigFlagsShell '	if [ -f x ] { echo y }' )" clean
rigAssert 'a region opened on a line naming no awk is shell' \
	"$( rigFlagsShell '	printf '\''%s'\'' { x }' )" clean
rigAssert 'a $'\''...'\'' string naming awk opens no region' \
	"$( rigFlagsShell '	$'\''Fill.awk: the slot {{name}} has no value\nrc=4'\''' )" clean
echo "-- a program opened and closed on one shell line is checked, and only its own command counts --"
rigAssert 'a one-line awk program with no ; before its } is flagged' \
	"$( rigFlagsShell '	n="$( LC_ALL=C awk '\''END { print NR }'\'' f )"' )" flagged
rigAssert 'the same with ; before its } is clean' \
	"$( rigFlagsShell '	n="$( LC_ALL=C awk '\''END { print NR ; }'\'' f )"' )" clean
rigAssert 'a quoted payload after a closed $( ... | awk ... ) is no awk program' \
	"$( rigFlagsShell '	printf '\''%s'\'' '\''{"d":"'\''"$( printf x | LC_ALL=C awk -f e.awk )"'\''"}}'\''' )" clean
rigAssert 'a sed after an awk in one pipeline is no awk program' \
	"$( rigFlagsShell '	LC_ALL=C awk '\''{ print ; }'\'' f | sed '\''s/a}/b/'\''' )" clean

echo "-- the package holds to it: every awk source, found rather than listed --"
rigAwkFiles=()
while IFS= read -r rigAwkFile ; do rigAwkFiles+=( "$rigAwkFile" ) ; done < <( find -L "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test" -name '*.awk' -type f )
[ "${#rigAwkFiles[@]}" -gt 0 ] || rigRefuse "no awk source found under the package, so the sweep would read nothing"
rigAssert "no awk source of the package has a } without ; before it on a shared line" \
	"[$( LC_ALL=C awk -f "$rigChecker" "${rigAwkFiles[@]}" | LC_ALL=C sed "s|^$MDLT_ORIGIN/myx/myx.distro-agents/||" | LC_ALL=C tr '\n' ' ' )]" "[]"
rigShellFiles=()
while IFS= read -r rigShellFile ; do rigShellFiles+=( "$rigShellFile" ) ; done < <( find -L "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts" \( -name '*.sh' -o -name '*.include' \) -type f )
[ "${#rigShellFiles[@]}" -gt 0 ] || rigRefuse "no shell file found under the package, so the sweep would read nothing"
rigAssert "no awk program a shell file of the package holds has a } without ; before it on a shared line" \
	"[$( AWK_AXIOM_SHELL=1 LC_ALL=C awk -f "$rigChecker" "${rigShellFiles[@]}" | LC_ALL=C sed "s|^$MDLT_ORIGIN/myx/myx.distro-agents/||" | LC_ALL=C cut -d: -f1,2 | LC_ALL=C tr '\n' ' ' )]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AWK AXIOM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AWK_AXIOM: OK (%d assertions, offline)\n' "$rigPassCount"
