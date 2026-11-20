#!/usr/bin/env bash
## Check on the `trivial` class of AgentsSolidBreachScan.sh (trivial functions and variables, inlined per
## `magic-developer/reference/code-craft.md`), and on the detector that carries it, AgentsSolidTrivials.py beside
## this check. It runs on a constructed package holding one fixture of each kind, so the result is about the
## detector and never about the live tree's own code.
## The boundary this check holds: a name another file calls plainly is no API, so that function is a row and inlined at
## its callers. A name another file holds as data -- an argument word, an entry of a table it runs by name -- is an API
## and stays. A name only a load guard asks about stays nothing. A name a sibling package names is a contract and stays.
## Held:
##   1. control: the detector reads a package of code files, and reads the packages beside it
##   2. every known-positive comes back as a `trivial` row, of the kind it is
##   3. no known-negative comes back as a row, and each is named with the reason it stays
##   4. red: a positive planted into a file that had none is caught, and the same file clean is not
##   5. red then green on the boundary: a plain call from another file is a row, and the same name held as data is not
##   6. the scan's own class list carries `trivial` at P4, and every other class keeps the priority it had
## Offline: it writes nothing but its own rig, and runs no network call.
set -u

argRoot=""
case "${1:-}" in --*) ;; "") ;; *) argRoot="$1" ;; esac
scanHere="$( cd "${BASH_SOURCE%/*}" && pwd )"
if [ -n "$argRoot" ] && [ -d "$argRoot/sh-lib" ] ; then
	rigPkg="$argRoot"
else
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set, and no package root was given}"
	rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
fi
rigScan="$scanHere/AgentsSolidBreachScan.sh"
rigDetector="$scanHere/AgentsSolidTrivials.py"
## The fixtures and the rig's own folder are found beside this check, so the result is about the tree the check came
## with: a package root given on the command line says which code the scan reads, never where the check's own files are.
rigFixtures="$scanHere/../check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScan" ] || rigRefuse "the scan is not beside this check: $rigScan"
[ -f "$rigDetector" ] || rigRefuse "the detector is not beside this check: $rigDetector"
for rigNeed in solid-trivials.positives.include solid-trivials.negatives.include solid-trivials.api-user.include ; do
	[ -f "$rigFixtures/$rigNeed" ] || rigRefuse "the fixture is not beside this check: $rigFixtures/$rigNeed"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSolidTrivialsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

## The constructed package: the three fixtures as one package's code files, plus the empty folders the scan expects,
## and the two folders beside it -- one a sibling package that names a fixture, one a folder that is no package. Each
## constructed package sits in a parent folder of its own, so no other rig's files are read as its siblings.
rigBuilt="$rigTmp/built/pkg"
mkdir -p "$rigBuilt/sh-lib/fixture" "$rigBuilt/sh-scripts" "$rigBuilt/sh-test" || exit 1
mkdir -p "$rigTmp/built/myx.distro-sibling/sh-lib" "$rigTmp/built/unrelated-folder" || exit 1
rigBuild(){
	cp "$rigFixtures/solid-trivials.positives.include" "$rigBuilt/sh-lib/fixture/solid-trivials.positives.include" || exit 1
	cp "$rigFixtures/solid-trivials.negatives.include" "$rigBuilt/sh-lib/fixture/solid-trivials.negatives.include" || exit 1
	cp "$rigFixtures/solid-trivials.api-user.include" "$rigBuilt/sh-lib/fixture/solid-trivials.api-user.include" || exit 1
	printf '## A sibling package, naming one function of the package beside it.\nSiblingCaller(){ ## text\n\tSolidNegativeSibling "$1"\n}\n## SolidPositiveSiblingProse appears here in prose only.\n## and in a heredoc body:\ncat <<X\nSolidPositiveSiblingProse\nX\n' \
		> "$rigTmp/built/myx.distro-sibling/sh-lib/sibling.include" || exit 1
	printf '## A folder holding no sh-lib and no sh-scripts: no package, naming one function of the package beside it.\nSolidPositiveSiblingless\n' \
		> "$rigTmp/built/unrelated-folder/notes.include" || exit 1
}
rigBuild

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRows(){ ## package root -- the trivial rows the detector prints for it
	python3 -I -B "$rigDetector" "$1" 2> /dev/null
}
rigKept(){ ## package root, name -- the reason the detector leaves that name out
	python3 -I -B "$rigDetector" "$1" --explain 2>&1 > /dev/null |
		LC_ALL=C awk -F'\t' -v want="$2" '$1 == "kept" && index($3, " " want) == index($3, " ") { print $4 ; }'
}
rigRowOf(){ ## package root, name -- `function` or `variable` where the detector rowed that name, empty where it did not
	python3 -I -B "$rigDetector" "$1" 2> /dev/null |
		LC_ALL=C awk -F'\t' -v want="$2" '{ d = $3 ; sub(/^[a-z]+ /, "", d) ; sub(/:.*/, "", d) ; if (d == want) { print $3 ; exit ; } ; }' |
		LC_ALL=C sed -e 's/^\([a-z]*\) .*/\1/'
}

echo "-- 1. control: the detector reads a package of code files --"
rigAssert "control: the constructed package holds the three fixture files" \
	"$( find "$rigBuilt/sh-lib" -type f -name '*.include' | wc -l | tr -d ' ' )" 3
rigAssert "control: the detector prints a row for a known-positive, so an empty answer is not an empty run" \
	"$( rigRowOf "$rigBuilt" SolidTrivialVersionLine )" function
rigAssert "control: the package beside the constructed one is read, so its contract can be found at all" \
	"$( rigKept "$rigBuilt" SolidNegativeSibling )" "the sibling package names it, in ../myx.distro-sibling/sh-lib/sibling.include"

echo "-- 2. every known-positive comes back as a row of its kind --"
rigAssert "a function of one simple command, with one call site here" "$( rigRowOf "$rigBuilt" SolidTrivialCopyPath )" function
rigAssert "a function of one printf of its arguments" "$( rigRowOf "$rigBuilt" SolidTrivialVersionLine )" function
rigAssert "a variable from a literal, read once nearby" "$( rigRowOf "$rigBuilt" SolidPositiveBase )" variable
rigAssert "a variable from another variable, read once nearby" "$( rigRowOf "$rigBuilt" SolidPositiveSeen )" variable
rigAssert "a function another file calls plainly is a row: that call is inlined at its caller" \
	"$( rigRowOf "$rigBuilt" SolidPositivePlainCall )" function
rigAssert "a function another file only load-guards is a row: the guard never runs it" \
	"$( rigRowOf "$rigBuilt" SolidPositiveGuardOnly )" function
rigAssert "a function a folder that is no package names is a row" \
	"$( rigRowOf "$rigBuilt" SolidPositiveSiblingless )" function
rigAssert "a function the sibling names in prose and in a heredoc only is a row: no code, no contract" \
	"$( rigRowOf "$rigBuilt" SolidPositiveSiblingProse )" function

echo "-- 3. no known-negative comes back, and each is named with its reason --"
rigAssert "a name another file holds as data is no row" "$( rigRowOf "$rigBuilt" SolidNegativeByString )" ""
rigAssert "a name another file holds as data is kept for that" \
	"$( rigKept "$rigBuilt" SolidNegativeByString )" "a name another file runs by string, from sh-lib/fixture/solid-trivials.api-user.include"
rigAssert "a name a sibling package names is no row" "$( rigRowOf "$rigBuilt" SolidNegativeSibling )" ""
rigAssert "a trap handler is no row" "$( rigRowOf "$rigBuilt" SolidNegativeTrap )" ""
rigAssert "a trap handler is kept for the trap" "$( rigKept "$rigBuilt" SolidNegativeTrap )" "handed over as a bare word"
rigAssert "a case arm's command is no row" "$( rigRowOf "$rigBuilt" SolidNegativeArm )" ""
rigAssert "a case arm's command is kept for the arm" "$( rigKept "$rigBuilt" SolidNegativeArm )" "handed over as a bare word"
rigAssert "a name a variable holds is no row" "$( rigRowOf "$rigBuilt" SolidNegativeHeld )" ""
rigAssert "a name a variable holds is kept for that" "$( rigKept "$rigBuilt" SolidNegativeHeld )" "handed over as a bare word"
rigAssert "a name a callback parameter receives is no row" "$( rigRowOf "$rigBuilt" SolidNegativeHanded )" ""
rigAssert "a comment that states why is no row" "$( rigKept "$rigBuilt" SolidNegativeKnown )" "its comment states why"
rigAssert "a pipeline is no single simple command" "$( rigRowOf "$rigBuilt" SolidNegativePipe )" ""
rigAssert "two statements are no single simple command" "$( rigRowOf "$rigBuilt" SolidNegativeTwo )" ""
rigAssert "a variable read twice is the algorithm's" "$( rigRowOf "$rigBuilt" SolidNegativeTwice )" ""
rigAssert "a variable read far from its assignment is the algorithm's" "$( rigRowOf "$rigBuilt" SolidNegativeFarAway )" ""
rigAssert "a counter the loop changes is the algorithm's" "$( rigRowOf "$rigBuilt" SolidNegativeCounter )" ""
rigAssert "a value the shell writes in is no value of that line" "$( rigRowOf "$rigBuilt" SolidNegativeRead )" ""
rigAssert "an exported name is no row" "$( rigRowOf "$rigBuilt" SolidNegativeExported )" ""

echo "-- 4. red: the same probe catches a planted trivial and clears it again --"
rigPlanted="$rigTmp/planted/pkg"
mkdir -p "$rigPlanted/sh-lib/fixture" "$rigPlanted/sh-scripts" "$rigPlanted/sh-test" || exit 1
printf '## A file of one planted function.\nSolidPlantedTrivial(){ ## text\n\tprintf %s "$1"\n}\n' \
	> "$rigPlanted/sh-lib/fixture/planted.include" || exit 1
rigAssert "a planted trivial is caught" "$( rigRowOf "$rigPlanted" SolidPlantedTrivial )" function
printf '## A file of one planted function, now inlined.\nSolidPlantedInline(){ ## text\n\tprintf %s "$1"\n\tprintf %s "$1"\n}\n' \
	> "$rigPlanted/sh-lib/fixture/planted.include" || exit 1
rigAssert "the same file, its body now two statements, is clean" "$( rigRowOf "$rigPlanted" SolidPlantedInline )" ""

echo "-- 5. red then green on the boundary: a plain call from another file is a row, the same name held as data is not --"
rigBoundary="$rigTmp/boundary/pkg"
mkdir -p "$rigBoundary/sh-lib/fixture" "$rigBoundary/sh-scripts" "$rigBoundary/sh-test" || exit 1
printf '## The name, in the file that defines it.\nSolidBoundaryName(){ ## text\n\tprintf %%s\\n "$1"\n}\n' \
	> "$rigBoundary/sh-lib/fixture/defines.include" || exit 1
printf '## The same name, called plainly by another file.\nSolidBoundaryPlainCaller(){ ## text\n\tSolidBoundaryName "$1"\n}\n' \
	> "$rigBoundary/sh-lib/fixture/calls.include" || exit 1
rigAssert "red: a plain call from another file leaves the name a row" "$( rigRowOf "$rigBoundary" SolidBoundaryName )" function
rigAssert "the same name is not kept, so no reason hides it" "$( rigKept "$rigBoundary" SolidBoundaryName )" ""
printf '## The same name, held as data by another file and run by that name.\nSolidBoundaryTable(){ ## text\n\tSolidBoundaryPlainCaller SolidBoundaryName "$1"\n}\n' \
	> "$rigBoundary/sh-lib/fixture/calls.include" || exit 1
rigAssert "green: the same name, held as data by another file, is no row" "$( rigRowOf "$rigBoundary" SolidBoundaryName )" ""
rigAssert "the same name is kept for that" "$( rigKept "$rigBoundary" SolidBoundaryName )" "a name another file runs by string, from sh-lib/fixture/calls.include"

echo "-- 6. the scan's classes: trivial at P4, every other class where it was --"
rigClassOf(){ ## class -- the priority the scan gives it, from its own table
	LC_ALL=C grep -o 'p\["[a-z-]*"\] = "P[0-9]"' "$rigScan" |
		LC_ALL=C sed -e 's/^p\["//' -e 's/"\] = "/ /' -e 's/"$//' |
		LC_ALL=C awk -v want="$1" '$1 == want { print $2 ; exit ; }'
}
rigAssert "trivial is a class of the scan" "$( rigClassOf trivial )" "P4"
rigAssert "trivial sits beside duplicate" "$( rigClassOf duplicate )" "P4"
rigAssert "fabricated keeps P5" "$( rigClassOf fabricated )" "P5"
rigAssert "foreign-package keeps P1" "$( rigClassOf foreign-package )" "P1"
rigAssert "foreign-store keeps P2" "$( rigClassOf foreign-store )" "P2"
rigAssert "dead keeps P6" "$( rigClassOf dead )" "P6"
rigAssert "the scan runs the detector on its own root, and a trivial reaches its rows" \
	"$( MDLT_ORIGIN="$rigPkg/.." bash "$rigScan" "$rigBuilt" 2> /dev/null |
		LC_ALL=C awk -F'\t' -v want="SolidTrivialVersionLine" '$2 == "trivial" && index($4, want) { print "row" ; exit ; }' )" row

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SOLID TRIVIALS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  sh-test/solid/AgentsSolidTrivials.py -- never the assertion" >&2
	exit 1
fi
printf 'SOLID_TRIVIALS: OK (%d assertions, offline)\n' "$rigPassCount"
