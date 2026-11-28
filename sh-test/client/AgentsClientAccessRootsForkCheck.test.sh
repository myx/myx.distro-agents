#!/usr/bin/env bash
## Behavioural check of the member roots resolved with no process per member. Every tool call of a spawned member computes its
## access roots, and the readable member set is the first of them: one real path per member of the skillset root. Held:
##   1. the readable set resolves every member, a linked one to where it leads, and skips trash, in sorted order
##   2. no member costs a process of its own: the traced set holds no pwd -P command
## Red before the change: each member was resolved in a $( cd && pwd -P ) of its own.
## Offline: a skillset root of this check alone, under the check's own temp folder; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClientAccessRootsForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/skills" "$rigTmp/real/linked-member" "$rigTmp/skills/member-a" "$rigTmp/skills/member-b" "$rigTmp/skills/trash" || exit 1
( cd "$rigTmp/skills" && ln -s ../real/linked-member member-c ) || exit 1
rigReal="$( cd "$rigTmp" && pwd -P )"
rigSet(){ ## trace file or empty
	env MDAT_SKILLSET_ROOT="$rigTmp/skills" bash -c '. "$1/sh-lib/client/AgentsTools.ClientAccessRoots.include" || exit 9
		[ -z "$2" ] || { PS4="+ " ; set -x ; }
		AgentsToolsClientAccessRootsMembers readable' rig "$rigPkg" "${1:-}" 2> "${1:-/dev/null}"
}

echo "-- 1. the readable set --"
rigAssert "every member, the linked one where it leads, trash skipped" "$( rigSet | tr '\n' ' ' )" \
	"$rigReal/real/linked-member $rigReal/skills/member-a $rigReal/skills/member-b "

echo "-- 2. no process per member --"
rigSet "$rigTmp/trace" > /dev/null
rigAssert "pwd -P commands in the traced set" "$( LC_ALL=C grep -c '^++* pwd -P' "$rigTmp/trace" )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLIENT ACCESS ROOTS FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_ACCESS_ROOTS_FORK: OK (%d assertions, offline)\n' "$rigPass"
