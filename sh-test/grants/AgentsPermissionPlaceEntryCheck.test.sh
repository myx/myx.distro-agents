#!/usr/bin/env bash
## Behavioural check on the place form of a permission entry (defect of 2026-10-31, human-owner):
## a member asks for access to a place, never for a path. The ask teaches
## `Tool:<place>:<relative>/**`, the tool accepts it, and a path in no place is still written as
## its absolute path.
##   1. the RequestPermission declaration teaches the place form, and no longer the absolute one.
##   2. every refusal repeats that declaration's practice, so it teaches it too.
##   3. an entry `Edit:<place>:<relative>/**` resolves to the folder and shows the place.
##   4. the old `@<place>:<relative>/**` form still resolves the same way.
##   5. control: an absolute entry is still accepted, and names no place.
## Offline: a shell of this box, no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigAgents="$rigOrigin/myx/myx.distro-agents"
rigTools="$rigAgents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTools"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPermissionPlaceEntryCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigHome="$rigTmp/home"
rigWs="$rigTmp/ws"
rigShared="$rigTmp/shared"
mkdir -p "$rigHome/.agents/magic-team" "$rigWs/.local/agents" "$rigShared/proj" || exit 1
printf '%s\tdirectory\tread-write\t%s\towner\n' place-a "$rigShared" > "$rigWs/.local/agents/directories.registry"
printf '%s\t%s\n' ws "$rigWs" > "$rigHome/.agents/magic-team/directories.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigTeaches(){ ## what the declaration must carry, and what it must not
	local teachesHave teachesHaveNot
	teachesHave="$( LC_ALL=C grep -c -F -- "$1" "$rigAgents/sh-lib/harness/AgentsOpenAiChatWire.sh" 2> /dev/null )" || teachesHave=0
	teachesHaveNot="$( LC_ALL=C grep -c -F -- "$2" "$rigAgents/sh-lib/harness/AgentsOpenAiChatWire.sh" 2> /dev/null )" || teachesHaveNot=0
	printf '%s:%s' "$teachesHave" "$teachesHaveNot"
}
rigPractice(){ ## the practice every refusal repeats, one line
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.BareName.include" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.InternOpPermission.include" ; AgentsToolsPermissionAskPractice' rig 2> /dev/null \
		| LC_ALL=C grep -c -F -- '<place>:<relative>/**' || :
}
rigEntry(){ ## entry -- "<target>|<place>|<rc>"
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDSC_CMD=rig \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.BareName.include" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.InternOpPermission.include" ; permEntryTarget="" ; permEntryPlace="" ; AgentsToolsPermissionEntryPlace "$1" rig-session > /dev/null 2>&1 || { printf "%s|%s|1" "${permEntryTarget:-}" "${permEntryPlace:-}" ; exit 0 ; } ; printf "%s|%s|0" "$permEntryTarget" "$permEntryPlace"' rig "$1" 2> /dev/null
}

echo "-- 1. the declaration teaches the place form --"
rigAssert "the place form is taught, the bare absolute example is gone" \
	"$( rigTeaches '<place>:<relative>/**' 'Tool,Tool:<folder>/**' )" "1:0"

echo "-- 2. every refusal repeats that practice --"
rigAssert "the practice a refusal prints carries the place form" "$( rigPractice )" 1

echo "-- 3. a place entry resolves to its folder --"
rigAssert "Edit:place-a:proj/** is the folder, shown by its place" \
	"$( rigEntry 'Edit:place-a:proj/**' )" "$rigShared/proj/**|place-a:proj/**|0"

echo "-- 4. the @ form still resolves the same way --"
rigAssert "Edit:@place-a:proj/** keeps working" \
	"$( rigEntry 'Edit:@place-a:proj/**' )" "$rigShared/proj/**|place-a:proj/**|0"

echo "-- 5. control: an absolute entry is still accepted --"
rigAssert "an absolute entry is taken as it is, naming no place" \
	"$( rigEntry 'Read:/usr/rig-nowhere/x/**' )" "/usr/rig-nowhere/x/**||0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION PLACE ENTRY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  AgentsOpenAiChatWire.sh and sh-lib/grants/AgentsTools.InternOpPermission.include -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_PLACE_ENTRY: OK (%d assertions, offline)\n' "$rigPassCount"
