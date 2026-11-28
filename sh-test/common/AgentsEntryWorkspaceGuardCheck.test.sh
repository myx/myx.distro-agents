#!/usr/bin/env bash
## Behavioural check of the workspace the agents tooling runs under. Every entry script of the package writes its stores under
## $MMDAPP/.local, so a MMDAPP that names the tooling tree -- a relative path resolved inside it, the tree itself, or a folder of
## its packages -- had the tooling make a .local tree in the source tree. Held, for every entry script of sh-scripts that takes
## its workspace from MMDAPP:
##   1. a relative MMDAPP is refused, and nothing is made under the folder the process stands in
##   2. MMDAPP the tooling tree, or a folder of its packages, is refused
##   3. any other folder passes the guard, a rig with no .local yet included
## Red before the change: a given MMDAPP was never checked.
## Offline: folders of this check alone, under its own temp folder; each script is asked only for an operation it does not have.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEntryWorkspaceGuardCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/stand" "$rigTmp/rig" || exit 1
rigScripts="$( LC_ALL=C grep -lF 'export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"' "$rigPkg"/sh-scripts/*.fn.sh )"
rigRun(){ ## script, MMDAPP, folder to stand in -- prints whether the guard refused
	( cd "$3" && env -u MDAT_DATA_ROOT -u MDAT_DATA_ROOT_OF MMDAPP="$2" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$1" --rig-no-such-operation < /dev/null 2>&1 ) | LC_ALL=C grep -cE 'MMDAPP (is not an absolute workspace path|is inside the tooling tree)' | awk '{ print ( $1 > 0 ) ? "refused" : "passed" }'
}
rigRelative="" rigTree="" rigPackage="" rigGood=""
for rigScript in $rigScripts ; do
	[ "$( rigRun "$rigScript" . "$rigTmp/stand" )" = refused ] || rigRelative="$rigRelative ${rigScript##*/}"
	[ "$( rigRun "$rigScript" "$MDLT_ORIGIN" "$rigTmp" )" = refused ] || rigTree="$rigTree ${rigScript##*/}"
	[ "$( rigRun "$rigScript" "$rigPkg/sh-test" "$rigTmp" )" = refused ] || rigPackage="$rigPackage ${rigScript##*/}"
	[ "$( rigRun "$rigScript" "$rigTmp/rig" "$rigTmp" )" = passed ] || rigGood="$rigGood ${rigScript##*/}"
done

echo "-- 1. a relative MMDAPP --"
rigAssert "scripts that run under a relative MMDAPP" "${rigRelative:-none}" none
rigAssert "files made where the process stood" "$( find "$rigTmp/stand" -mindepth 1 | wc -l | tr -d ' ' )" 0

echo "-- 2. the tooling tree --"
rigAssert "scripts that run with MMDAPP the tooling tree" "${rigTree:-none}" none
rigAssert "scripts that run with MMDAPP a folder of its packages" "${rigPackage:-none}" none

echo "-- 3. any other folder --"
rigAssert "scripts the guard stops under a rig folder" "${rigGood:-none}" none

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ENTRY WORKSPACE GUARD CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ENTRY_WORKSPACE_GUARD: OK (%d assertions over %d scripts, offline)\n' "$rigPass" "$( printf '%s\n' $rigScripts | wc -l | tr -d ' ' )"
