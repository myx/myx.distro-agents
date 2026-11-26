#!/usr/bin/env bash
## Behavioural check on `AgentsToolsWorkspaceByName` (sh-lib/member/AgentsTools.MemberWorkspace.include): a workspace
## name resolves to one path, and the machine's two lists naming that path are no ambiguity.
##
## Measured on the live rig at 04:31 +0200 (W2, item task-20261125T1823Z): `--spawn-settings-workspace ws-myx-devops`
## was refused with "several workspaces this machine knows have that name (/…/ws-myx-devops, /…/ws-myx-devops)". A
## tracked workspace is named by the places list (`directories.registry`) AND by the known-workspaces registry, so its
## path arrived twice, and the resolver counted the rows without collapsing the spellings. Every dispatch naming
## another workspace was refused by it. Held:
##   1. one path named by both lists: it resolves, and the resolver answers that path
##   2. two different paths of one name: still refused, and each path said once
##   3. control: a name no list holds: refused, naming where it looked
## Offline: a HOME and workspaces of this check's own under its temp tree, no socket opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigInclude="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWorkspace.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the resolver is not at the origin this workspace resolves: $rigInclude"

rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWorkspaceNameDedupCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home"
rigList="$rigHome/.agents/magic-team/known-workspaces.registry"
rigPlaces="$rigHome/.agents/magic-team/directories.registry"
mkdir -p "$rigHome/.agents/magic-team" "$rigTmp/ws-here" "$rigTmp/ws-one" "$rigTmp/decoy/ws-one" || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigBoth(){ ## the text, the first path, the second -- whether both are said, in that order
	case "$1" in *"$2, $3"*) printf both ;; *) printf not-both ;; esac
}
rigWhere(){ ## the text -- whether the refusal names where it looked
	case "$1" in *"no workspace this machine knows has that name"*) printf named ;; *) printf unnamed ;; esac
}
rigResolve(){ ## name -- rc in rigRc, the resolver's own answer in rigOut (stdout and stderr together)
	rigOut="$( HOME="$rigHome" MMDAPP="$rigTmp/ws-here" MDLT_ORIGIN="${MDLT_ORIGIN:-}" \
		bash -c '. "$1" 2> /dev/null ; AgentsToolsWorkspaceByName "$2" 2>&1' _ "$rigInclude" "$1" )"
	rigRc=$?
}

## 1. the same path named by both lists: one workspace
printf '%s\n' "$rigTmp/ws-one" > "$rigList"
printf 'ws-one\t%s\n' "$rigTmp/ws-one" > "$rigPlaces"
rigResolve ws-one
rigAssert "a path both lists name resolves"          "$rigRc" "0"
rigAssert "and the answer is that path"              "$rigOut" "$rigTmp/ws-one"

## 2. two different paths of one name: refused, each said once
printf '%s\n%s\n' "$rigTmp/ws-one" "$rigTmp/decoy/ws-one" > "$rigList"
rigResolve ws-one
rigAssert "a name two paths hold is still refused"   "$rigRc" "1"
rigAssert "and both paths are said"                  "$( rigBoth "$rigOut" "$rigTmp/ws-one" "$rigTmp/decoy/ws-one" )" "both"
rigAssert "each said once, never twice for one path" "$( printf '%s' "$rigOut" | LC_ALL=C grep -o -F -- "$rigTmp/ws-one" | LC_ALL=C grep -c . )" "1"

## 3. control: a name no list holds
rigResolve ws-nowhere
rigAssert "a name no list holds is refused"          "$rigRc" "1"
rigAssert "and the refusal says where it looked"     "$( rigWhere "$rigOut" )" "named"

echo
if [ "$rigFailCount" = "0" ] ; then
	printf 'WORKSPACE_NAME_DEDUP: OK (%s assertions, offline)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ WORKSPACE NAME DEDUP CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
