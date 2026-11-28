#!/usr/bin/env bash
## Behavioural check that the git guard fails closed. A git write over a source tree is refused, and the list of source trees
## comes from SandboxLinks. Where that list cannot be made, a path in a source tree must still answer as one: an empty list
## would let a write reach uncommitted work. Held:
##   1. control: with the whole package, a path in a source tree is one, and a path outside every tree is not
##   2. with the producer of the list absent, a path in a source tree still answers as one
## Red before the change: with the producer absent, the guard answered that no path was in a source tree.
## Offline: loads the package only, and nothing runs git.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGitSourceRootsClosedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
rigAsk(){ ## origin, path -- prints 0 where the guard answers a source tree, 1 where it does not
	( MDLT_ORIGIN="$1" ; . "$1/myx/myx.distro-agents/sh-lib/common/AgentsTools.GitWrite.include" ; AgentsToolsGitTreeIsSource "$2" ) > /dev/null 2>&1
	echo "$?"
}
[ -d "$MMDAPP/source" ] || rigRefuse "the workspace has no source tree at $MMDAPP/source, so no path can be in one"
mkdir -p "$rigTmp/origin/myx/myx.distro-agents/sh-lib/common" \
	&& cp "$rigPkg/sh-lib/common/AgentsTools.GitWrite.include" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/common/" \
	|| rigRefuse "could not make the origin that lacks the producer"

echo "-- 1. control: the whole package tells the two paths apart --"
rigAssert "a path in the source tree, and a path outside every tree" \
	"$( rigAsk "$MDLT_ORIGIN" "$MMDAPP/source/rig-no-such-entry" ) $( rigAsk "$MDLT_ORIGIN" "$rigTmp/outside" )" "0 1"

echo "-- 2. with the producer absent, the source tree still answers as one --"
rigAssert "a path in the source tree, its roots list not made" "$( rigAsk "$rigTmp/origin" "$MMDAPP/source/rig-no-such-entry" )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ GIT SOURCE ROOTS CLOSED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'GIT_SOURCE_ROOTS_CLOSED: OK (%d assertions, offline)\n' "$rigPass"
