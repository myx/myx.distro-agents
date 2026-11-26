#!/usr/bin/env bash
## Behavioural check on the arming of the acting-member guard, `AgentsToolsActingMemberCheck`
## (board sub-item: every arm that calls the guard loads the function it calls). The population is
## derived here, by classifying every mention of the name in the package's `sh-lib` and `sh-scripts`
## into the four kinds it can be: the definition, an arming line, a header comment, or a call site.
## Held:
##   0. the classifier's own self-tests: an armed call is one call and one arming; a comment mention
##      is no call site; an arming line is no call site; two calls under one arming line read as two
##      sites and one arming, so the file is reported short
##   1. the population, derived: every mention of the name is one of the four kinds, so nothing is
##      silently unclassified, and the derivation actually read the tree. The count itself is printed
##      and never pinned: it was 27 call sites at e519852d and 28 an hour later, through no fault of
##      any fix, so a hardcoded figure would go red against a tree where every site is armed
##   2. every calling file arms the guard at least once per call site it makes
##   3. the definition is one, and it sits in its own file
## Red before the fix: the two comms arms that call the guard with no arming line, which fail as
## `AgentsToolsActingMemberCheck: command not found`. Green after: no calling file is short.
## Offline: reads the package at this origin, and runs nothing of it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/sh-lib" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigPackage"
rigTmp="$( mkdir -p "${MMDAPP%/}/.local/temp" && mktemp -d "${MMDAPP%/}/.local/temp/AgentsActingMemberGuardArmingCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## THE CLASSIFIER. One file on stdin -> three numbers on one line: call sites, arming lines, mentions.
##   a mention is any line naming the name;
##   the definition is the line that opens the function (`AgentsToolsActingMemberCheck(){`);
##   an arming line is `type <name> > /dev/null ... || . <path>`;
##   a comment mention is a line whose first non-blank character is `#`;
##   a call site is a mention that is none of those three.
rigClassify(){
	LC_ALL=C awk -v name='AgentsToolsActingMemberCheck' '
		{
			if ( index( $0, name ) == 0 ) { next ; }
			mentions++ ;
			if ( $0 ~ ("^[ \t]*" name "\\(\\)\\{") ) { defs++ ; next ; }
			if ( $0 ~ ("^[ \t]*type " name " > /dev/null") ) { arms++ ; next ; }
			if ( $0 ~ /^[ \t]*#/ ) { comments++ ; next ; }
			calls++ ;
		}
		END { printf "%d %d %d %d %d\n", calls + 0, arms + 0, defs + 0, comments + 0, mentions + 0 ; }
	'
}

## SELF-TESTS. The classifier must be able to come out both ways on a shape it is given, or a clean
## reading of the tree means nothing. Each row is one shape, written to a file and classified.
rigShape(){ ## name, the file's lines on stdin -> "<calls> <arms> <defs> <comments>"
	cat > "$rigTmp/shape-$1.include"
	rigClassify < "$rigTmp/shape-$1.include"
}
printf '%s\n' \
	'type AgentsToolsActingMemberCheck > /dev/null 2>&1 || . "/x/sh-lib/member/AgentsTools.ActingMember.include"' \
	'AgentsToolsActingMemberCheck "$who" op || return 1' | rigShape armed > "$rigTmp/self-armed"
printf '%s\n' \
	'## a session names only itself (AgentsToolsActingMemberCheck); tooling calls the' \
	'doSomething' | rigShape comment > "$rigTmp/self-comment"
printf '%s\n' \
	'type AgentsToolsActingMemberCheck > /dev/null 2>&1 || . "/x/sh-lib/member/AgentsTools.ActingMember.include"' \
	'doSomething' | rigShape arming > "$rigTmp/self-arming"
printf '%s\n' \
	'type AgentsToolsActingMemberCheck > /dev/null 2>&1 || . "/x/sh-lib/member/AgentsTools.ActingMember.include"' \
	'AgentsToolsActingMemberCheck "$a" one || return 1' \
	'AgentsToolsActingMemberCheck "$b" two || return 1' | rigShape twoone > "$rigTmp/self-twoone"
printf '%s\n' \
	'AgentsToolsActingMemberCheck(){ ## named member, operation' \
	'	return 0' \
	'}' | rigShape definition > "$rigTmp/self-definition"
printf '%s\n' 'nothing here' | rigShape empty > "$rigTmp/self-empty"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- 0. the classifier's self-tests: it comes out both ways on the shapes it is given --"
rigAssert "an armed call: one call site, one arming"          "$( cat "$rigTmp/self-armed" )"     "1 1 0 0 2"
rigAssert "control: a comment mention is no call site"        "$( cat "$rigTmp/self-comment" )"   "0 0 0 1 1"
rigAssert "control: an arming line is no call site"           "$( cat "$rigTmp/self-arming" )"    "0 1 0 0 1"
rigAssert "two calls under one arming line: two sites, one arming" "$( cat "$rigTmp/self-twoone" )" "2 1 0 0 3"
rigAssert "control: the definition is no call site"           "$( cat "$rigTmp/self-definition" )" "0 0 1 0 1"
rigAssert "control: a file naming nothing reads as nothing"    "$( cat "$rigTmp/self-empty" )"     "0 0 0 0 0"
## The tree's own classifier must report the same shapes short, so a file it calls short is short for
## this reason and not another: the two-calls-one-arming shape is what the tree rows below fail on.
rigShort(){ ## a classified "<calls> <arms> ..." line -> the file's shortfall, or none
	set -- $1
	[ "$1" -le "$2" ] && printf none || printf short
}
rigAssert "the self-test shapes are judged by the same rule the tree is" "$( rigShort "$( cat "$rigTmp/self-armed" )" ):$( rigShort "$( cat "$rigTmp/self-twoone" )" )" "none:short"

echo "-- 1. the population, derived from every mention of the name --"
cd "$rigPackage" || rigRefuse "the package left the origin between two lines of this check"
LC_ALL=C grep -rl -F 'AgentsToolsActingMemberCheck' sh-lib sh-scripts 2>/dev/null | LC_ALL=C sort > "$rigTmp/names.txt" || :
[ -s "$rigTmp/names.txt" ] || rigRefuse "no file of the package names the guard, so this check has nothing to read and reports nothing"
: > "$rigTmp/per-file.txt"
while IFS= read -r rigFile ; do
	rigNumbers="$( rigClassify < "$rigFile" )" || rigRefuse "the classifier failed on $rigFile"
	printf '%s %s\n' "$rigNumbers" "$rigFile" >> "$rigTmp/per-file.txt"
done < "$rigTmp/names.txt"
rigTotal(){ ## the column named, summed over the files -- 1 calls, 2 arms, 3 defs, 4 comments, 5 mentions
	LC_ALL=C awk -v col="$1" '{ total += $col ; } END { print total + 0 ; }' "$rigTmp/per-file.txt"
}
## THE COUNT IS DERIVED AND NEVER PINNED. It was 27 call sites in 25 calling files at HEAD e519852d
## (2026-11-25 15:54 +0200), and it read 28 an hour later when another change added a call and brought
## its arming line with it. A row asserting either number goes red against a tree where every site is
## armed, which is the fault the board item's own warning names. What is asserted instead:
##   - the derivation READ the tree, so a broken derivation cannot pass by emptiness,
##   - every mention is one of the four kinds, so nothing is silently unclassified,
##   - and no calling file is short of an arming line, which is the assertion that must never move.
rigAssert "control: the derivation read the tree, not an empty list" "$( [ "$( rigTotal 1 )" -ge 25 ] && printf read || printf empty )" read
echo "        | derived: $( rigTotal 1 ) call site(s) in $( LC_ALL=C awk '$1 > 0 { n++ ; } END { print n + 0 ; }' "$rigTmp/per-file.txt" ) calling file(s), $( rigTotal 2 ) arming line(s), $( rigTotal 3 ) definition(s), at $( date '+%Y-%m-%d %H:%M:%S %z' ) on $( uname -s )"
## The arming lines are not counted to a fixed number here: they are the thing the fix adds, so their
## count moves with it. What must not move is the population above, and every calling file's own arming.
rigAssert "the definition is one"                      "$( rigTotal 3 )" 1
## Every mention is one of the four kinds, so the four add up to the whole: a fifth kind would show
## here rather than be lost from every row below.
rigMentions="$( rigTotal 5 )"
rigKindSum=$(( $( rigTotal 1 ) + $( rigTotal 2 ) + $( rigTotal 3 ) + $( rigTotal 4 ) ))
rigAssert "every mention is one of the four kinds"     "$rigKindSum" "$rigMentions"

echo "-- 2. each calling file arms the guard once for every call site it makes --"
LC_ALL=C awk '$1 > 0 && $1 > $2 { printf "%s (%d call site(s), %d arming line(s))\n", $6, $1, $2 ; }' "$rigTmp/per-file.txt" > "$rigTmp/short.txt"
cat "$rigTmp/short.txt" | LC_ALL=C sed 's/^/        | /'
rigAssert "no calling file is short of an arming line"  "$( wc -l < "$rigTmp/short.txt" | tr -d ' ' )" 0
## An arming line that names a path no file has arms nothing, and reads as an arming line to every row
## above. Each one's own path is resolved against the origin here, so a mistyped include is caught.
rigArmedPathsFile="$rigTmp/armed-paths.txt"
( cd "$rigPackage" && LC_ALL=C grep -rh '^[[:space:]]*type AgentsToolsActingMemberCheck > /dev/null 2>&1 || \.' sh-lib sh-scripts 2>/dev/null ) \
	| LC_ALL=C sed -n 's|.*\. "\$MDLT_ORIGIN/\([^"]*\)".*|\1|p' | LC_ALL=C sort -u > "$rigArmedPathsFile"
rigArmedPaths="$( wc -l < "$rigArmedPathsFile" | tr -d ' ' )"
rigArmedMissing=0
while IFS= read -r rigArmPath ; do
	[ -n "$rigArmPath" ] || continue
	[ -f "$rigOrigin/$rigArmPath" ] || { rigArmedMissing=$(( rigArmedMissing + 1 )) ; printf '        | missing: %s\n' "$rigArmPath" ; }
done < "$rigArmedPathsFile"
## The control reads the count of paths actually read: a pattern matching nothing would otherwise report
## "no missing path" while having looked at none.
rigAssert "every arming line names a file the origin holds"  "$rigArmedPaths:$rigArmedMissing" "$rigArmedPaths:0"
rigAssert "control: and the paths were actually read"        "$( [ "$rigArmedPaths" -ge 1 ] && printf read || printf none )" read

echo "-- 3. the definition: one, in its own file, sourcing nothing --"
rigDefiner="$( LC_ALL=C awk '$3 > 0 { print $6 ; }' "$rigTmp/per-file.txt" )"
## The item's own two targets, named, so a green says the fault's own arms are armed and not merely that
## every file happens to hold an arming line somewhere.
for rigTarget in sh-lib/trello/AgentsTools.MemberCommsTrello.include sh-lib/wait/AgentsTools.MemberWait.include ; do
	rigAssert "the target ${rigTarget##*/} is armed now"   "$( LC_ALL=C awk -v f="$rigTarget" '$6 == f { print ( $1 <= $2 ? "armed" : "short" ) ; }' "$rigTmp/per-file.txt" )" armed
done
rigAssert "the file that defines the guard"            "$rigDefiner" "sh-lib/member/AgentsTools.ActingMember.include"
rigAssert "it calls the guard itself nowhere"          "$( LC_ALL=C awk '$3 > 0 { print $1 ; }' "$rigTmp/per-file.txt" )" 0

echo
printf 'ACTING_MEMBER_GUARD_ARMING: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ ACTING MEMBER GUARD ARMING CHECK FAILED" >&2 ; exit 1 ; }
