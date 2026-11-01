#!/usr/bin/env bash
## Behavioural check on the one rule of the test system: a rig holds real copies, and no link into real source. Run
## rather than read, offline: no deploy, no ssh, no host. Held:
##   1. no file of sh-test makes a link whose target is the origin, the installed packages, or a path the same file
##      takes from either, directly or through a variable or a loop variable (check-fixtures/rig-source-links.py)
##   2. the reader of rule 1 finds a direct origin link, a link through a loop over the origin, and a link through a
##      variable holding the origin, and finds nothing in a rig's own links
##   3. rigCopyTree makes a real copy: the files and their modes, no link anywhere, and a link in the source comes out
##      as the file it named
##   4. rigCopyTree refuses a source that is not there, and says which
##   5. rigCopyTree still copies where cp has no clone (GNU cp, which refuses -c)
##   6. a distro-workspace rig holds its packages as copies: no link of .local/myx/<package>
## Red before: every rig that mirrored the origin held it by `ln -s`, and a write of the run reached the real package.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test"
rigScanner="$rigHere/check-fixtures/rig-source-links.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScanner" ] || rigRefuse "the reader of a rig's links is not at the origin this workspace resolves: $rigScanner"
. "$rigHere/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigHere/check-fixtures/rig-distro-workspace.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRigSourceLinkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## The words this check plants, from parts, so that this file is read like every other and holds no sample of its own.
rigLink="l""n -s"
rigOriginVar='$'"MDLT_ORIGIN"

echo "-- 1. no file of sh-test links the origin into a rig --"
rigFound="$( python3 -I -B "$rigScanner" "$rigHere"/*/*.test.sh "$rigHere"/*/*.include.sh "$rigHere"/check-fixtures/*.include.sh "$rigHere"/AgentsRunTests.sh 2>&1 )" || rigRefuse "the reader of a rig's links could not be run: $rigFound"
rigAssert "no file of sh-test holds a link into real source" "$( printf '%s' "$rigFound" )" ""

echo "-- 2. the reader of rule 1 is not blind: each shape it must find, and the rig's own links it must not --"
mkdir -p "$rigTmp/sample"
printf '%s %s/myx" "$rigDest"\n' "$rigLink" "$rigOriginVar" > "$rigTmp/sample/direct.sh"
printf 'for rigEntry in "%s/myx"/* ; do %s "$rigEntry" "$rigDest/x" ; done\n' "$rigOriginVar" "$rigLink" > "$rigTmp/sample/loop.sh"
printf 'rigPackage="%s/myx/myx.distro-agents"\n%s "$rigPackage" "$rigDest"\n' "$rigOriginVar" "$rigLink" > "$rigTmp/sample/throughvar.sh"
printf 'rigWs="$MMDAPP/.local/temp/rig"\n%s "$rigWs/.local/myx/rig/x" "$rigDest"\n%s "$rigDest/a" "$rigDest/b"\n' "$rigLink" "$rigLink" > "$rigTmp/sample/ownership.sh"
rigAssert "the reader finds the direct origin link, the loop over the origin and the variable holding it" \
	"$( python3 -I -B "$rigScanner" "$rigTmp/sample/direct.sh" "$rigTmp/sample/loop.sh" "$rigTmp/sample/throughvar.sh" | LC_ALL=C cut -d: -f1 | LC_ALL=C sort -u | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( python3 -I -B "$rigScanner" "$rigTmp/sample/direct.sh" "$rigTmp/sample/loop.sh" "$rigTmp/sample/throughvar.sh" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "3 3"
rigAssert "and it finds nothing in the rig's own links, nor in a comment" \
	"$( python3 -I -B "$rigScanner" "$rigTmp/sample/ownership.sh" ; printf '## %s %s/myx x\n' "$rigLink" "$rigOriginVar" > "$rigTmp/sample/comment.sh" ; python3 -I -B "$rigScanner" "$rigTmp/sample/comment.sh" )" ""

echo "-- 3. rigCopyTree copies: the files, their modes, and no link --"
mkdir -p "$rigTmp/from/lib"
printf 'rig\n' > "$rigTmp/from/lib/one.sh" ; chmod +x "$rigTmp/from/lib/one.sh"
printf 'rig\n' > "$rigTmp/from/two.txt"
rigCopyTree "$rigTmp/from" "$rigTmp/to" || rigAssert "the copy is made" "copy failed" "made"
rigAssert "the copy holds the tree, the file's mode and no link" \
	"$( cd "$rigTmp/to" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ) $( ls -l "$rigTmp/to/lib/one.sh" | LC_ALL=C cut -c1-10 ) $( find "$rigTmp/to" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" \
	"./lib ./lib/one.sh ./two.txt -rwxr-xr-x 0"
rigAssert "a link in the source comes out as the file it named, so a copy holds no link at all" \
	"$( $rigLink "$rigTmp/to/two.txt" "$rigTmp/from/three.link" && rigCopyTree "$rigTmp/from" "$rigTmp/to2" ; find "$rigTmp/to2" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( cat "$rigTmp/to2/three.link" 2> /dev/null )" "0 rig"
rigAssert "a source that is not there is refused, and named" \
	"$( rigCopyTree "$rigTmp/absent" "$rigTmp/to3" 2> "$rigTmp/to3.err" && printf made || printf refused ) $( LC_ALL=C grep -c 'no such source' "$rigTmp/to3.err" || : ) $( [ -e "$rigTmp/to3" ] && printf made || printf nothing )" "refused 1 nothing"

echo "-- 4. the copy survives a cp with no clone, as GNU cp is --"
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\nfor rigWord in "$@" ; do [ "$rigWord" != "-Rcp" ] || exit 1 ; [ "$rigWord" != "-RLcp" ] || exit 1 ; done\nexec /bin/cp "$@"\n' > "$rigTmp/bin/cp"
chmod +x "$rigTmp/bin/cp"
rigAssert "with a cp that refuses the clone option the copy is still made, and is real" \
	"$( PATH="$rigTmp/bin:$PATH" rigCopyTree "$rigTmp/from" "$rigTmp/to4" && printf made || printf failed ) $( cat "$rigTmp/to4/two.txt" 2> /dev/null ) $( find "$rigTmp/to4" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "made rig 0"

echo "-- 5. a distro-workspace rig holds its packages as copies --"
rigWs="$rigTmp/distro"
rigDistroWorkspace "$rigWs/ws" rig-repository || rigRefuse "the rig's workspace could not be made"
rigAssert "every package of the rig's tooling is a real folder, none a link" \
	"$( find "$rigWs/ws/.local/myx" -mindepth 1 -maxdepth 1 -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( find "$rigWs/ws/.local/myx" -mindepth 1 -maxdepth 1 -type d ! -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' | LC_ALL=C sed 's/^[1-9][0-9]*$/some/' )" "0 some"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RIG SOURCE LINK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RIG_SOURCE_LINK: OK (%d assertions, offline)\n' "$rigPasses"
