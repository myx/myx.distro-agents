#!/usr/bin/env bash
## Behavioural check on the dispatch as the mixer gives it back (F2.1, F7.2; the owner's S6.43: the Markdown mixer is "checked that it works,
## tested where needed, and used wherever dispatches are mixed"): `--get-dispatch-text` prints the run's dispatch, and where the sandbox holds a
## second part it is the merge of `dispatch.md`, the board item's copy and the input scan, each a section of its own. What a member re-reads there
## is the whole of what it was given, so this check holds the four things the merge claims, on the dispatch's own path:
##   0. control: the lost-line detector reports a line it does not hold, and passes one it does
##   1. merged order: Dispatch, then Board item, then Input scan, each exactly one section, in that order
##   2. heading levels: every heading of a part sits at least one level below its section, and no level is skipped
##   3. no lost line: every non-blank, non-heading line of a part is in the merged text
##   4. no silent loss: where the merge's depth cap stops a part's section, the merged text names that section and its file in one line
##   5. a part whose first line is `---` and whose second is not: that rule is no front matter, so the prose and headings under it are kept
## The detector of 3 is held able to fail first: a line planted in no part is reported.
## Red before the fix of 5: a part whose first line is `---` and whose second line is not `---` is swallowed, silently, up to its next rule.
## Offline: a rig sandbox of this rig's own, every call through `env -i`.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSession" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigOrigin"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDispatchMixCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigBox="$rigTmp/sandbox"
mkdir -p "$rigWs/.local/.agents" "$rigHome" "$rigBox/input" "$rigBox/output"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One dispatch, as the session's own tool gives it back: in $rigTmp/<name>.out, its stderr beside it.
rigDispatch(){ ## sandbox, out name
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SPAWN_SANDBOX_ROOT="$1" MDAT_SPAWN_AGENT=magic-tester \
		bash "$rigSession" --get-dispatch-text ) > "$rigTmp/$2.out" 2> "$rigTmp/$2.err" < /dev/null
}
## Every non-blank, non-heading line of a file that the merged text does not hold, one a line: the detector of the third claim, and one that
## answers for a line planted nowhere as readily as for a real one.
rigLostLines(){ ## source file, merged text
	LC_ALL=C awk 'NR == 1 && $0 == "---" { fm = 1 ; next } fm { if ( $0 == "---" ) { fm = 0 } ; next } /^#+ / { next } $0 == "" { next } { print }' "$1" \
		| while IFS= read -r rigLine ; do LC_ALL=C grep -qxF -- "$rigLine" "$2" || printf '%s\n' "$rigLine" ; done
}
## The captions of a merged text's headings, one a line, in order.
rigCaptions(){ ## merged text
	LC_ALL=C awk '/^#+ / { sub( /^#+ /, "" ) ; print }' "$1"
}
## The headings whose level sits more than one below the heading above them: a merge that reworks levels never makes such a jump.
rigLevelJumps(){ ## merged text
	LC_ALL=C awk '/^#+ / { l = 0 ; s = $0 ; while ( substr( s, l + 1, 1 ) == "#" ) l++ ; if ( prev > 0 && l > prev + 1 ) printf "%s at %d after %d\n", $0, l, prev ; prev = l }' "$1"
}

echo "-- 0. control: the lost-line detector can fail --"
printf 'RIG-PRESENT line\n' > "$rigTmp/plant.txt"
printf 'RIG-PRESENT line\nRIG-PLANTED-NOWHERE line\n' > "$rigTmp/plant2.txt"
rigAssert "a line the merged text holds is not reported"        "$( rigLostLines "$rigTmp/plant.txt" "$rigTmp/plant.txt" )" ""
rigAssert "a line it does not hold is reported, by its text"    "$( rigLostLines "$rigTmp/plant2.txt" "$rigTmp/plant.txt" )" "RIG-PLANTED-NOWHERE line"

echo "-- 1. merged order: dispatch, board item, input scan --"
printf '# Brief\n\nRIG-DISPATCH the task as given.\n\n## Brief sub\n\nRIG-DISPATCH-SUB body\n' > "$rigBox/input/dispatch.md"
printf -- '---\nowner: magic-tester\ndate: 2026-11-04 12:00 +0200\n---\n# Item\n\nRIG-ITEM the board item.\n' > "$rigBox/input/dispatch-20261104T1000Z-rig.md"
printf '# Scan\n\nRIG-SCAN the input scan.\n\n## Scan sub\n\nRIG-SCAN-SUB body\n' > "$rigBox/input/input-scan.md"
printf 'RIG-POINTERS not the dispatch\n' > "$rigBox/input/pointers.md"
rigDispatch "$rigBox" three
rigAssert "the three parts, in that order, and the pointers left out" \
	"$( LC_ALL=C grep -o -E 'RIG-(DISPATCH-SUB|DISPATCH|ITEM|SCAN-SUB|SCAN|POINTERS)' "$rigTmp/three.out" | LC_ALL=C tr '\n' ',' )" \
	"RIG-DISPATCH,RIG-DISPATCH-SUB,RIG-ITEM,RIG-SCAN,RIG-SCAN-SUB,"
rigAssert "each part a section of its own, one each"  "$( LC_ALL=C grep -c -x -e '# Dispatch' -e '# Board item' -e '# Input scan' "$rigTmp/three.out" )" 3

echo "-- 2. heading levels: a part's own headings sit below its section, and no level is skipped --"
rigAssert "no heading sits more than one level below the one above it" "$( rigLevelJumps "$rigTmp/three.out" )" ""
rigAssert "the dispatch's own ## heading is one level under its section" \
	"$( LC_ALL=C grep -c -x -e '## Brief' -e '### Brief sub' "$rigTmp/three.out" )" 2

echo "-- 3. no lost line: the merged text holds every line of each part --"
rigAssert "the dispatch loses nothing"    "$( rigLostLines "$rigBox/input/dispatch.md" "$rigTmp/three.out" )" ""
rigAssert "the board item loses nothing"  "$( rigLostLines "$rigBox/input/dispatch-20261104T1000Z-rig.md" "$rigTmp/three.out" )" ""
rigAssert "the input scan loses nothing"  "$( rigLostLines "$rigBox/input/input-scan.md" "$rigTmp/three.out" )" ""

echo "-- 4. no silent loss: a part deeper than the cap is named by a reference line --"
rigBox2="$rigTmp/sandbox-cap"
mkdir -p "$rigBox2/input" "$rigBox2/output"
{
	printf '# Brief\n\nRIG-CAP-TOP body\n\n## Two\n\nRIG-CAP-TWO body\n\n### Three\n\nRIG-CAP-THREE body\n\n#### Four\n\nRIG-CAP-FOUR body\n\n##### Five\n\nRIG-CAP-FIVE body\n\n###### Six\n\nRIG-CAP-SIX body\n'
} > "$rigBox2/input/dispatch.md"
printf '# Scan\n\nRIG-CAP-SCAN body\n' > "$rigBox2/input/input-scan.md"
rigDispatch "$rigBox2" cap
rigAssert "the deepest body is not inlined"                       "$( LC_ALL=C grep -c -F 'RIG-CAP-SIX' "$rigTmp/cap.out" || : )" 0
rigAssert "and one line names the section and the file it was in" \
	"$( LC_ALL=C grep -c -F 'See "Six" in ' "$rigTmp/cap.out" || : ):$( LC_ALL=C grep -c -F 'dispatch.md, a section deeper than this merge shows.' "$rigTmp/cap.out" || : )" "1:1"

echo "-- 5. a part that opens with a rule is not read as front matter, and its prose is kept --"
rigBox3="$rigTmp/sandbox-rule"
mkdir -p "$rigBox3/input" "$rigBox3/output"
printf -- '---\n\nRIG-RULE-BODY the opening paragraph\n\n# Brief\n\nRIG-RULE-HEAD body\n\n---\n\n## After the rule\n\nRIG-RULE-AFTER body\n' > "$rigBox3/input/dispatch.md"
printf '# Scan\n\nRIG-RULE-SCAN body\n' > "$rigBox3/input/input-scan.md"
rigDispatch "$rigBox3" rule
## Only a block that opens and closes as front matter is left out. Here the first `---` is a thematic break, so the prose under it is
## content: the merge drops it silently today, and a merged dispatch then re-reads as a task with no opening paragraph and no heading.
rigAssert "the part's prose above its first heading is in the merged text" "$( LC_ALL=C grep -c -F 'RIG-RULE-BODY' "$rigTmp/rule.out" || : )" 1
rigAssert "and so is everything under its first heading"                   "$( LC_ALL=C grep -c -F 'RIG-RULE-HEAD' "$rigTmp/rule.out" || : )" 1
rigAssert "while the part that stands at a real front matter block is still read from its first heading" \
	"$( LC_ALL=C grep -c -F 'RIG-RULE-AFTER' "$rigTmp/rule.out" || : ):$( LC_ALL=C grep -c -F 'RIG-RULE-SCAN' "$rigTmp/rule.out" || : )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISPATCH MIX CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DISPATCH_MIX: OK (%d assertions, offline)\n' "$rigPassCount"
