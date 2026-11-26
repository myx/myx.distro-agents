#!/usr/bin/env bash
## Check on the `duplicate` class of AgentsSolidBreachScan.sh: the same awk program written in more than one file is one
## row, whether the program stands on one physical line or is split over several. It runs on a constructed package
## holding one fixture of each kind, so the result is about the detector and never about the live tree's own code.
## Held, in the order they are read:
##   1. control: the scan reads the constructed package and prints rows for it
##   2. a program split over three lines, in two files, is one row at the second file's opening line
##   3. a program on one line, in two files, is still one row -- the shape the class already reported
##   4. red: the arm as it stood before this feature reports the one-line row and no row for the split program
##   5. the red copy carries the arm this feature replaced, and none of its own text
##   6. a program under 80 characters in two files is no row
##   7. two programs differing by one line are no row, and that difference is the pair they are not
##   8. three files carrying one program raise a row per copy after the first, and removing one still raises one
## Usage: AgentsSolidDupPairCheck.test.sh [<package root>]   (default: the package at $MDLT_ORIGIN). Offline: it writes only its own rig.
set -u
argRoot=""
case "${1:-}" in --*) ;; "") ;; *) argRoot="$1" ;; esac
if [ -n "$argRoot" ] && [ -d "$argRoot/sh-test/solid" ] ; then
	scanPackage="$argRoot"
else
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set, and no package root was given}"
	scanPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
fi
scanTool="$scanPackage/sh-test/solid/AgentsSolidBreachScan.sh"
scanRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$scanTool" ] || scanRefuse "the scan is not where the package root says: $scanTool"
[ -d "$scanPackage/sh-lib" ] || scanRefuse "no package at $scanPackage"
. "$scanPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
scanRig="$( rigTempDir AgentsSolidDupPairCheck )" || exit 1
scanRig="$( cd "$scanRig" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$scanRig" 2>/dev/null ; rm -rf -- "$scanRig"' EXIT

## The constructed package: one function a file, so the contracts detector has something to read. The awk programs are
## the whole subject -- a split one, a one-line one, a short one, and one a line away from the split one.
scanBuilt="$scanRig/built/pkg"
mkdir -p "$scanBuilt/sh-lib/alpha" "$scanBuilt/sh-lib/beta" "$scanBuilt/sh-lib/gamma" "$scanBuilt/sh-scripts" "$scanBuilt/sh-test" || exit 1
scanSplitProg='	LC_ALL=C awk '\''
		$0 == "---" { fences++ ; if ( fences == 2 ) { exit ; } next ; }
		fences == 1 && index($0, "owner: ") == 1 { print substr($0, 8) ; exit ; }
	'\'' "$1"'
scanLineProg='	LC_ALL=C awk '\''{ word = $1 ; if ( length(word) > 0 ) { seen[word]++ ; } } END { for ( k in seen ) print k, seen[k] ; }'\'' "$1"'
scanShortProg='	LC_ALL=C awk '\''{ print $1 }'\'' "$1"'
scanOtherProg='	LC_ALL=C awk '\''
		$0 == "---" { fences++ ; if ( fences == 2 ) { nextfile ; } next ; }
		fences == 1 && index($0, "owner: ") == 1 { print substr($0, 8) ; exit ; }
	'\'' "$1"'
scanFile(){ ## path, function name, program
	printf '## A fixture function: the program below it is the whole subject of its assertion.\n%s(){ ## record file\n%b\n}\n' "$2" "$3" > "$1" || exit 1
}
scanFile "$scanBuilt/sh-lib/alpha/split.include" ScanAlphaSplit "$scanSplitProg"
scanFile "$scanBuilt/sh-lib/beta/split-copy.include" ScanBetaSplit "$scanSplitProg"
scanFile "$scanBuilt/sh-lib/alpha/line.include" ScanAlphaLine "$scanLineProg"
scanFile "$scanBuilt/sh-lib/beta/line-copy.include" ScanBetaLine "$scanLineProg"
scanFile "$scanBuilt/sh-lib/alpha/short.include" ScanAlphaShort "$scanShortProg"
scanFile "$scanBuilt/sh-lib/beta/short-copy.include" ScanBetaShort "$scanShortProg"
scanFile "$scanBuilt/sh-lib/gamma/other.include" ScanGammaOther "$scanOtherProg"

## The red arm: the same scan with this feature's arm put back as it stood, one grep over a quoted one-line program.
scanArmStart='## duplicate: an awk program of 80+ characters'
scanArmStop='## the internal contracts: unreached calls'
for scanMark in "$scanArmStart" "$scanArmStop" ; do
	scanMarkCount="$( LC_ALL=C grep -cF "$scanMark" "$scanTool" )" || :
	[ "$scanMarkCount" = 1 ] || scanRefuse "the line naming the arm ($scanMark) appears $scanMarkCount times in $scanTool, so the red copy would prove nothing"
done
scanRedDir="$scanRig/red"
mkdir -p "$scanRedDir" || exit 1
cp "$scanPackage/sh-test/solid/AgentsSolidContracts.py" "$scanPackage/sh-test/solid/AgentsSolidTrivials.py" "$scanRedDir/" || exit 1
cat > "$scanRedDir/old-arm.txt" <<'REDARM'
	## duplicate: an awk program of 80+ characters, one row per extra file carrying it
	LC_ALL=C grep -rnoE "awk [^|]{0,40}'[^']{80,}'" sh-lib --include='*.include' --include='*.sh' |
		LC_ALL=C awk -F: '{ f = $1 ; l = $2 ; $1 = "" ; $2 = "" ; t = $0 ; sub(/^[^'"'"']*/, "", t) ; if (!(t in first)) first[t] = f ":" l ; else if (index(first[t], f ":") != 1) printf "duplicate\t%s:%s\tsame awk program as %s\n", f, l, first[t] ; }'
REDARM
scanRedTool="$scanRedDir/AgentsSolidBreachScan.sh"
LC_ALL=C awk -v start="$scanArmStart" -v stop="$scanArmStop" -v armFile="$scanRedDir/old-arm.txt" '
	!skipping && index($0, start) > 0 { skipping = 1 ; next }
	skipping { if (index($0, stop) > 0) { while ((getline armLine < armFile) > 0) print armLine ; close(armFile) ; skipping = 0 ; print } ; next }
	{ print }' "$scanTool" > "$scanRedTool" || scanRefuse "the red copy could not be written"
LC_ALL=C grep -qF -- "$scanArmStop" "$scanRedTool" || scanRefuse "the red copy lost the line that ends the arm"
chmod +x "$scanRedTool" || scanRefuse "the red copy could not be made executable"

scanPassCount=0
scanFailCount=0
scanAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; scanPassCount=$(( scanPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; scanFailCount=$(( scanFailCount + 1 ))
	fi
}
scanRun(){ ## scan, package -- its rows
	bash "$1" "$2" 2> "$scanRig/scan.err"
}
scanDupOf(){ ## rows, file -- the duplicate row naming that file, `<file>:<line>` and what it repeats
	LC_ALL=C awk -F'\t' -v want="$2" '$2 == "duplicate" && $3 == want { printf "%s %s", $3, $4 ; }' <<< "$1"
}

echo "-- 1. control: the scan reads the constructed package --"
scanRows="$( scanRun "$scanTool" "$scanBuilt" )" || scanRefuse "the scan failed on the constructed package: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "control: the scan printed rows for the constructed package at all" \
	"$( [ -n "$scanRows" ] && printf rows || printf none )" rows

echo "-- 2. a program split over three lines, in two files, is one row --"
scanAssert "the split program's second copy is a row, naming the first" \
	"$( scanDupOf "$scanRows" sh-lib/beta/split-copy.include:3 )" \
	"sh-lib/beta/split-copy.include:3 same awk program as sh-lib/alpha/split.include:3"

echo "-- 3. a program on one line is still a row --"
scanAssert "the one-line pair is one row, naming both files" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" { site = $3 " " $4 ; if (index(site, "line-copy.include:3") > 0 && index(site, "line.include:3") > 0) { n++ ; } } END { print n + 0 ; }' <<< "$scanRows" )" 1

echo "-- 4. red: the arm as it stood reports the one-line row and no row for the split program --"
scanRedRows="$( scanRun "$scanRedTool" "$scanBuilt" )" || scanRefuse "the red copy of the scan failed on the constructed package: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "red: the one-line pair is one row, naming both files" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" { line = $3 " " $4 ; if (index(line, "line-copy.include:3") > 0 && index(line, "line.include:3") > 0) { n++ ; } } END { print n + 0 ; }' <<< "$scanRedRows" )" 1
scanAssert "red: the split program is no row at all" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" && index($3 $4, "split") > 0 { print $3 ; }' <<< "$scanRedRows" )" ""

echo "-- 5. the red copy carries the arm this feature replaced --"
scanAssert "the red copy holds the old one-line pattern once, and none of the new arm's own marking" \
	"$( LC_ALL=C grep -cF "awk [^|]{0,40}'[^']{80,}'" "$scanRedTool" )/$( LC_ALL=C grep -cF 'minProgram' "$scanRedTool" )" "1/0"

echo "-- 6. a program under 80 characters in two files is no row --"
scanAssert "one filter finds the pair over the floor and nothing for the pair under it" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" { if (index($3 $4, "line-copy.include:3") > 0) { print "found" ; } }' <<< "$scanRows" )/$( LC_ALL=C awk -F'\t' '$2 == "duplicate" { if (index($3 $4, "short") > 0) { print "found" ; } }' <<< "$scanRows" )" "found/"

echo "-- 7. two programs differing by one line are no row --"
scanAssert "the near-miss program raises nothing" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" && index($3, "gamma") > 0 { print $3 ; }' <<< "$scanRows" )" ""
scanAssert "the near-miss program is one line from the split program, so the pair it is not is real" \
	"$( diff <( sed -n '3,6p' "$scanBuilt/sh-lib/alpha/split.include" ) <( sed -n '3,6p' "$scanBuilt/sh-lib/gamma/other.include" ) | LC_ALL=C grep -c '^[<>]' )" "2"

echo "-- 8. three files carrying one program raise a row per copy after the first --"
scanFile "$scanBuilt/sh-lib/gamma/split-third.include" ScanGammaSplit "$scanSplitProg"
scanTrioRows="$( scanRun "$scanTool" "$scanBuilt" )" || scanRefuse "the scan failed with the third copy planted: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "three copies raise two rows, one for each copy after the first" \
	"$( LC_ALL=C awk -F'\t' '$2 == "duplicate" && index($3, "split") > 0 { print $3 ; }' <<< "$scanTrioRows" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" \
	"sh-lib/beta/split-copy.include:3 sh-lib/gamma/split-third.include:3 "
rm -f "$scanBuilt/sh-lib/gamma/split-third.include" || exit 1
scanPairRows="$( scanRun "$scanTool" "$scanBuilt" )" || scanRefuse "the scan failed after the third copy was removed: $( LC_ALL=C tail -n 3 "$scanRig/scan.err" )"
scanAssert "with one of the three removed, the remaining pair still raises its one row" \
	"$( scanDupOf "$scanPairRows" sh-lib/beta/split-copy.include:3 )" \
	"sh-lib/beta/split-copy.include:3 same awk program as sh-lib/alpha/split.include:3"

if [ "$scanFailCount" -ne 0 ] ; then
	echo "⛔ SOLID DUP PAIR CHECK FAILED: $scanFailCount of $(( scanPassCount + scanFailCount )) assertion(s)" >&2
	echo "  fix:  sh-test/solid/AgentsSolidBreachScan.sh, the duplicate arm -- never the assertion" >&2
	exit 1
fi
printf 'SOLID_DUP_PAIR: OK (%d assertions, offline)\n' "$scanPassCount"
