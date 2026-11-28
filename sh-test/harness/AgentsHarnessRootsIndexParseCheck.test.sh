#!/usr/bin/env bash
## Behavioural check of the roots index's ready lines read in linear time. A served call reads the index on every start, and its
## ready lines hold every root on one line each: a slice off the body per line rescans that line, quadratic in bash 3.2. Held:
##   1. an index of 3000 roots is read within 20 seconds
##   2. it gives every root, the write set, and no open row
## Red before the change: the slices took minutes on such an index, and the watchdog ends the read.
## Offline: a rig workspace and its own index; the fingerprint is pinned to the index's print line, as only the format is tested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessRootsIndexParseCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws" ; mkdir -p "$rigWs/.local/agents" || exit 1
LC_ALL=C awk -v ws="$rigWs" 'BEGIN {
	sep = sprintf("%c", 31) ; printf "myx.distro harness.roots.index 4\nprint\trig-print\n"
	for ( i = 1 ; i <= 3000 ; i++ ) { roots = roots ( i > 1 ? sep : "" ) sprintf("%s/root-%05d", ws, i) ; reals = reals ( i > 1 ? sep : "" ) sprintf("%s/real-%05d", ws, i) }
	printf "readyroots\tread\t%s\nreadyreals\tread\t%s\n", roots, reals
	printf "readyroots\twref\t%s/wref\nreadyreals\twref\t%s/wref\n", ws, ws
	printf "readyroots\tgrant\t%s/grant\nreadyreals\tgrant\t%s/grant\n", ws, ws
	printf "readytests\tall\t\nend\n" }' > "$rigWs/.local/agents/harness.roots.index"

echo "-- 1. 3000 roots are read within 20 seconds --"
( env -u MDAT_SKILLSET_ROOT MDLT_ORIGIN="" bash -c '. "$1/sh-lib/harness/AgentsHarnessRootsIndex.include" || exit 3
	AgentsHarnessRootsFingerprint(){ agentsRootsPrint="rig-print" ; }
	harnessAccessRoots=() harnessWriteAccessRoots=()
	AgentsHarnessRootsIndexUse "$2" "" 0 || exit 4
	printf "%s %s %s %s %s\n" "${#harnessAccessRoots[@]}" "${harnessAccessRoots[2999]}" "${harnessAccessRootsReal[2999]}" "${harnessWriteAccessRoots[*]}" "${#harnessAccessRootsOpen[@]}"' rig "$rigPkg" "$rigWs" > "$rigTmp/answer" 2> "$rigTmp/err" ) &
rigPid=$!
rigTurns=0 ; while kill -0 "$rigPid" 2> /dev/null && [ "$rigTurns" -lt 200 ] ; do sleep 0.1 ; rigTurns=$(( rigTurns + 1 )) ; done
if kill -0 "$rigPid" 2> /dev/null ; then pkill -P "$rigPid" 2> /dev/null ; kill "$rigPid" 2> /dev/null ; wait "$rigPid" 2> /dev/null ; rigRc=timeout ; else wait "$rigPid" ; rigRc=$? ; fi
rigAssert "the read ends by itself, answering" "$rigRc" 0

echo "-- 2. it gives every root --"
rigAssert "roots, the last root and its resolution, the write set, the open rows" "$( cat "$rigTmp/answer" 2> /dev/null )" \
	"3000 $rigWs/root-03000 $rigWs/real-03000 $rigWs/wref $rigWs/grant 0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ROOTS INDEX PARSE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ROOTS_INDEX_PARSE: OK (%d assertions, offline)\n' "$rigPass"
