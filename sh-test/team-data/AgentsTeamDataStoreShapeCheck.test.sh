#!/usr/bin/env bash
## AgentsTeamDataStoreShapeCheck -- the repair's shape test: the operation it guards resets the repository it is handed, so a root
## that is no team-data store must be refused before anything is reset (2026-11-26 11:08: the tooling's own source checkout was
## reset to a commit and every uncommitted change in it was lost). A store holds board/ and inboxes/ at its root; a source
## checkout holds neither. Offline: three temp folders of this check alone, removed at its end.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigRepair="$rigOrigin/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCheckoutRepair.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigRepair" ] || rigRefuse "the repair include is not at the origin this workspace resolves: $rigRepair"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsTeamDataStoreShapeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The include ends with its own dispatcher on `$1`, so a source needs a bound one and answers that branch; the function it defines
## is what this check reads.
## The include reads a name `set -u` refuses at its top level, so it is sourced with the option off and the check's own options
## are put back at once.
set +u
set -- shape-check
. "$rigRepair" > /dev/null 2>&1 || :
set --
set -u
type AgentsToolsTeamDataStoreShapeOk > /dev/null 2>&1 || rigRefuse "the repair include defines no shape test: $rigRepair"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/store/board" "$rigTmp/store/inboxes" "$rigTmp/source/sh-lib" "$rigTmp/plain"
rigAssert "a store's root passes: board/ and inboxes/ stand at it" "$( AgentsToolsTeamDataStoreShapeOk "$rigTmp/store" && echo ok || echo no )" ok
rigAssert "a source checkout's root does not pass" "$( AgentsToolsTeamDataStoreShapeOk "$rigTmp/source" && echo ok || echo no )" no
rigAssert "a root with board/ and no inboxes/ does not pass" "$( mkdir -p "$rigTmp/half/board" ; AgentsToolsTeamDataStoreShapeOk "$rigTmp/half" && echo ok || echo no )" no
rigAssert "a plain folder does not pass" "$( AgentsToolsTeamDataStoreShapeOk "$rigTmp/plain" && echo ok || echo no )" no
rigAssert "no root at all does not pass" "$( AgentsToolsTeamDataStoreShapeOk "" && echo ok || echo no )" no
if [ "$rigFail" -ne 0 ] ; then printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPass" "$rigFail" ; exit 1 ; fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPass"
exit 0
