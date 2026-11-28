#!/usr/bin/env bash
## Behavioural check of the roots index on a served call (AgentsHarnessRootsIndexUse): a call path takes the index's answer and
## resolves nothing of it. A root that is no directory resolves to itself (AgentsHarnessResolveDir answers it as given), so its
## row hands that answer back, and the harness start resolves none of the index's roots. Held:
##   1. a row whose root is absent hands back the root itself, never an empty resolution the start must resolve again
##   2. control: that is the answer AgentsHarnessResolveDir gives for the same root
##   3. a row whose root is a directory keeps its stored resolution, and the write set is filled from its own rows
## Red before the change: the absent root's resolution is empty, so every call resolves it, one cache scan per root.
## Offline: a rig workspace of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessRootsIndexAbsentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/dir-root" || exit 1
rigAbsent="$rigTmp/absent-root"
rigRows="$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT= bash -c '
	. "$1/sh-lib/harness/AgentsHarnessAccess.include" || exit 1
	. "$1/sh-lib/harness/AgentsHarnessRootsIndex.include" || exit 1
	AgentsHarnessRootsFingerprint "$2" || exit 1
	AgentsHarnessRootsEnc "$agentsRootsPrint"
	printf "%s\nprint\t%s\nread\t%s\t\nread\t%s\t%s\nwref\t%s\t%s\nend\n" "$agentsRootsIndexHeader" "$agentsRootsEnc" "$3" "$4" "$4" "$4" "$4" > "$2/.local/agents/harness.roots.index" || exit 1
	MDLT_ORIGIN=""
	harnessAccessRoots=() ; harnessWriteAccessRoots=()
	AgentsHarnessRootsIndexUse "$2" "" 0 || { echo "INDEX-NOT-USED" ; exit 0 ; }
	rowAt=0
	while [ "$rowAt" -lt "${#harnessAccessRoots[@]}" ] ; do printf "read %s=%s\n" "${harnessAccessRoots[$rowAt]}" "${harnessAccessRootsReal[$rowAt]}" ; rowAt=$(( rowAt + 1 )) ; done
	rowAt=0
	while [ "$rowAt" -lt "${#harnessWriteAccessRoots[@]}" ] ; do printf "write %s=%s\n" "${harnessWriteAccessRoots[$rowAt]}" "${harnessWriteAccessRootsReal[$rowAt]}" ; rowAt=$(( rowAt + 1 )) ; done
	AgentsHarnessResolveDir "$3" rowResolved ; printf "resolve %s\n" "$rowResolved"
' rig "$rigPkg" "$rigWs" "$rigAbsent" "$rigTmp/dir-root" 2>&1 )"
case "$rigRows" in *INDEX-NOT-USED*) echo "⛔ ERROR: the rig's index was not used, so nothing about its rows is known -- refusing to report a result" >&2 ; exit 1 ;; esac

echo "-- 1. an absent root hands back itself --"
rigAssert "the absent root's row resolves to the root as given" "$( printf '%s\n' "$rigRows" | LC_ALL=C sed -n "s#^read $rigAbsent=##p" )" "$rigAbsent"
echo "-- 2. control: the same answer AgentsHarnessResolveDir gives --"
rigAssert "AgentsHarnessResolveDir answers the absent root as given" "$( printf '%s\n' "$rigRows" | LC_ALL=C sed -n 's#^resolve ##p' )" "$rigAbsent"
echo "-- 3. a directory row keeps its stored resolution --"
rigAssert "the directory row keeps its stored resolution" "$( printf '%s\n' "$rigRows" | LC_ALL=C sed -n "s#^read $rigTmp/dir-root=##p" )" "$rigTmp/dir-root"
rigAssert "and the write set holds its own row" "$( printf '%s\n' "$rigRows" | LC_ALL=C grep -c "^write $rigTmp/dir-root=$rigTmp/dir-root\$" )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS ROOTS INDEX ABSENT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ROOTS_INDEX_ABSENT: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
