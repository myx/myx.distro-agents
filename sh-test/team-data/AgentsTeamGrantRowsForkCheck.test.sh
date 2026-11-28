#!/usr/bin/env bash
## Behavioural check of the machine-wide grant rows read by one process. A spawned member's every tool call reads them twice,
## for its Edit and its Read roots, from each workspace the shared pointers name. Held:
##   1. the rows are this workspace's file first, then each pointed workspace's in pointer order, short rows left out, and a
##      workspace with no file adds nothing; a file whose last row has no newline still gives that row whole
##   2. one awk reads them all
## Red before the change: an awk was started for each workspace.
## Offline: a HOME and workspaces of this check alone, under its own temp folder; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamGrantRowsForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
for rigWs in self one two none ; do mkdir -p "$rigTmp/$rigWs/.local/agents" || exit 1 ; done
mkdir -p "$rigTmp/home/.agents/magic-team" || exit 1
printf '%s\n' "$rigTmp/one" "$rigTmp/none" "$rigTmp/two" "$rigTmp/one" > "$rigTmp/home/.agents/magic-team/permissions.registry"
printf 'm1:self:allow:Edit(/a/**)\nshort:row\n' > "$rigTmp/self/.local/agents/permissions.registry"
printf 'm2:one:allow:Read(/b/**)\n' > "$rigTmp/one/.local/agents/permissions.registry"
printf 'm3:two:allow:Edit(/c:d/**)' > "$rigTmp/two/.local/agents/permissions.registry"
rigRows(){ ## trace file or empty
	env HOME="$rigTmp/home" bash -c '. "$1/sh-lib/team-data/AgentsTools.TeamRegistry.include" || exit 9
		[ -z "$3" ] || { PS4="+ " ; set -x ; }
		AgentsToolsTeamGrantRows "$2" permissions.registry' rig "$rigPkg" "$rigTmp/self" "${1:-}" 2> "${1:-/dev/null}"
}

echo "-- 1. the rows, in order --"
rigAssert "every long row, in workspace order, the last one whole" "$( rigRows | tr '\n' '|' )" \
	"m1:self:allow:Edit(/a/**)|m2:one:allow:Read(/b/**)|m3:two:allow:Edit(/c:d/**)|"

echo "-- 2. one process --"
rigRows "$rigTmp/trace" > /dev/null
rigAssert "awks started" "$( LC_ALL=C grep -c '^++* awk ' "$rigTmp/trace" )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TEAM GRANT ROWS FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_GRANT_ROWS_FORK: OK (%d assertions, offline)\n' "$rigPass"
