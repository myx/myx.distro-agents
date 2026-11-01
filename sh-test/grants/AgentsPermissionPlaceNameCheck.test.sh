#!/usr/bin/env bash
## Behavioural check on how a permission post NAMES a target (defect of 2026-10-31, human-owner):
## by the place the asking member's own grant came from, never by a guess between the workspaces
## that name the same folder. `eclipse-ae3` and `eclipse-acm` both name /Volumes/workspace/myx,
## so a target below it was shown as its absolute path, or under the asker's own name.
##   1. a member whose home workspace names the folder: its own place, from any workspace.
##   2. the same name from the other workspace: still the member's own place, not that one's.
##   3. control: a target in no place keeps its absolute form.
## Offline: a shell of this box, no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="keeper-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTools"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPermissionPlaceNameCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

## Three workspaces and one folder two of them name, at the same depth, as eclipse-ae3 and
## eclipse-acm do. The member's home is the first; every call below is made from the third.
rigHome="$rigTmp/home"
rigWsA="$rigTmp/ws-a"
rigWsB="$rigTmp/ws-b"
rigWsC="$rigTmp/ws-c"
rigShared="$rigTmp/shared"
mkdir -p "$rigHome/.agents/magic-team" "$rigWsA/.local/agents" "$rigWsB/.local/agents" "$rigWsC/.local/agents" "$rigShared/proj" || exit 1
printf '%s\t%s\n' ws-a "$rigWsA" > "$rigHome/.agents/magic-team/directories.registry"
printf '%s\t%s\n' ws-b "$rigWsB" >> "$rigHome/.agents/magic-team/directories.registry"
printf '%s\tdirectory\tread-write\t%s\towner\n' place-a "$rigShared" > "$rigWsA/.local/agents/directories.registry"
printf '%s\tdirectory\tread-write\t%s\towner\n' place-b "$rigShared" > "$rigWsB/.local/agents/directories.registry"
printf '%s\t%s\tsource-symlink\tx\t%s\n' "$rigMember" "$rigWsA" "$rigWsA" > "$rigHome/.agents/magic-team/members.registry"
printf '%s\t%s\n' "$rigMember" "$rigWsA" > "$rigHome/.agents/magic-team/member-homes.registry"
printf '%s:ws-a:directory:Edit(/%s/proj/**)\n' "$rigMember" "$rigShared" > "$rigWsA/.local/agents/permissions.registry"
: > "$rigWsB/.local/agents/permissions.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigShown(){ ## workspace the call is made from, target
	( cd "$1" && env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$1" MDLT_ORIGIN="$rigOrigin" \
		bash "$rigTools" --intern-op-permission-place "$rigMember" "$2" 2> /dev/null )
}

rigAssert "the member's own place, asked from a workspace that names the folder too" \
	"$( rigShown "$rigWsC" "$rigShared/proj/**" )" "place-a:proj/**"
rigAssert "the same, asked from the other workspace that names it" \
	"$( rigShown "$rigWsB" "$rigShared/proj/**" )" "place-a:proj/**"
rigAssert "control: a target in no place keeps its absolute form" \
	"$( rigShown "$rigWsC" "/usr/rig-nowhere/x/**" )" "/usr/rig-nowhere/x/**"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION PLACE NAME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  sh-lib/grants/AgentsTools.InternOpPermission.include -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_PLACE_NAME: OK (%d assertions, offline)\n' "$rigPassCount"
