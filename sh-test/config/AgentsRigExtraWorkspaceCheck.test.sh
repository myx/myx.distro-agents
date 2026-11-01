#!/usr/bin/env bash
## Behavioural check on the two decisions the rig's install warning hangs on (S14.2 of the refactorings epic), run rather
## than read: AgentsToolsInstallRigWorkspacePlace and AgentsToolsInstallRigOwnSkillset, both in
## sh-lib/config/AgentsTools.Install.include.
##   1. OFF A RIG NOTHING IS THE RIG'S OWN: a registered workspace place and a skillset-shaped target are both refused,
##      so the warning stands exactly as it always did.
##   2. ON A RIG, A REGISTERED WORKSPACE PLACE IS THE RIG'S OWN: the extra workspace is accepted, and the warning is not reached.
##   3. ON A RIG, A PATH OUTSIDE EVERY REGISTERED PLACE IS STILL NOT: the warning stands.
##   4. A PLACE THAT IS NO WORKSPACE (a console, a documents folder) is not one.
##   5. A SKILLSET-SHAPED TARGET ON A RIG IS THE RIG'S OWN, and any other shape is not.
## What this does NOT pin: the install's own scan, which reaches these decisions. That pass is covered by
## AgentsTeamRegistryCheck.
## Offline: a workspace of the rig's own, and a registry file under it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/config/AgentsTools.Install.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "not found at the origin this workspace resolves: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRigExtraWorkspaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

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

rigWs="$rigTmp/ws-here" rigExtra="$rigTmp/ws-extra" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/agents" "$rigExtra/source/ns/skillset/keeper-rig" "$rigHome"
printf -- '---\nname: keeper-rig\n---\n' > "$rigExtra/source/ns/skillset/keeper-rig/SKILL.md"
## The rig's places: one extra workspace, and one place that is no workspace at all.
printf '%s\t%s\t%s\t%s\t%s\n' \
	extra "$( [ -d "$rigExtra" ] && printf workspace )" read-write "$rigExtra" yes \
	console console read-write "$rigTmp/console" no > "$rigWs/.local/agents/directories.registry"

## One decision, asked in the rig workspace with the mode given: `place <path>` or `own <path> <member>`.
rigAsk(){ ## mode, what to ask, its arguments...
	local askMode="$1" ; shift
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		${askMode:+MDAT_WORKSPACE_MODE=$askMode} bash -c '
			## The include parses its own operation word on sourcing, which is no call here: its answer is dropped
			## and only the functions it defines are used.
			askInclude="$1" ; askKind="$2" ; askA="${3:-}" ; askB="${4:-}"
			. "$askInclude" > /dev/null 2>&1
			case "$askKind" in
				place) AgentsToolsInstallRigWorkspacePlace "$askA" ;;
				own) AgentsToolsInstallRigOwnSkillset "$askA" "$askB" ;;
			esac
			exit $?
		' rig "$rigInclude" "$@" 2> /dev/null
}
rigVerdict(){ ## rc -- the word a reader wants
	[ "$1" = "0" ] && printf "accepted" || printf "refused"
}

echo "-- 1. off a rig nothing is the rig's own --"
rigAsk "" place "$rigExtra/source/magic-developer" ; rigAssert "off a rig: a registered workspace place is not accepted" "$( rigVerdict $? )" refused
rigAsk "" own "$rigExtra/source/ns/skillset/keeper-rig" keeper-rig ; rigAssert "off a rig: a skillset-shaped target is not accepted" "$( rigVerdict $? )" refused

echo "-- 2. on a rig a registered extra workspace is the rig's own --"
rigAsk team-rig place "$rigExtra/source/magic-developer" ; rigAssert "a path inside the extra workspace is accepted" "$( rigVerdict $? )" accepted
rigAsk team-rig place "$rigExtra" ; rigAssert "the extra workspace itself is accepted" "$( rigVerdict $? )" accepted

echo "-- 3. on a rig a path outside every place is still foreign --"
rigAsk team-rig place "$rigTmp/elsewhere/skillset/magic-developer" ; rigAssert "a path outside every registered place is refused" "$( rigVerdict $? )" refused

echo "-- 4. a place that is no workspace is not one --"
rigAsk team-rig place "$rigTmp/console/work" ; rigAssert "a console place is not a workspace place" "$( rigVerdict $? )" refused

echo "-- 5. a skillset-shaped target on a rig is the rig's own, and any other shape is not --"
rigAsk team-rig own "$rigExtra/source/ns/skillset/keeper-rig" keeper-rig ; rigAssert "skillset/<member> of the rig is accepted" "$( rigVerdict $? )" accepted
rigAsk team-rig own "$rigTmp/other-copy/keeper-rig" keeper-rig ; rigAssert "another shape of the same member is refused" "$( rigVerdict $? )" refused
rigAsk team-rig own "$rigExtra/source/ns/skillset/someone-else" keeper-rig ; rigAssert "a skillset folder of another member is refused" "$( rigVerdict $? )" refused

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
exit 0
