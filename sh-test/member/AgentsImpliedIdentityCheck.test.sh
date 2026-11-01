#!/usr/bin/env bash
## Behavioural check on the implied common options of a session that no spawn minted (S21 item 21), run rather than read:
## the tooling reads MDAT_TEAM_MEMBER, MDAT_SESSION_ID and MDAT_SPAWNED_ID, and a session that sets none of them acts as
## the console's own user-<account>, never as a team member.
##   1. THE MEMBER IS IMPLIED from MDAT_TEAM_MEMBER: a root session that names itself is that member.
##   2. OPT-IN ONLY: with no MDAT_TEAM_MEMBER it acts as user-<account>, never as a member it did not name.
##   3. THE SESSION IS IMPLIED from MDAT_SESSION_ID, and the spawn from MDAT_SPAWNED_ID, in that order of naming.
## Offline: a scratch skillset of the rig's own, env -i for every call, no Slack and no model.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves: $rigTool -- refusing to report a result" >&2 ; exit 1 ; }
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsImpliedIdentityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-member"
printf '# magic-team\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
printf '# rig-member\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"

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
## What the tool's own context says, one `<key>: <value>` a line, from a call that names nothing: member, then session, then spawn.
rigShow(){ ## environment words...
	env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" "$@" \
		bash "$rigTool" --intern-context-show 2>&1 | LC_ALL=C grep -E '^(team-member|session-id|spawn-id): ' || :
}
rigField(){ ## text, name
	printf '%s\n' "$1" | LC_ALL=C sed -n "s/^$2: //p" | head -1
}
rigAccount="$( id -un )"

echo "-- 1. the member is implied from MDAT_TEAM_MEMBER --"
rigOut="$( rigShow MDAT_TEAM_MEMBER=rig-member )"
rigAssert "a root session that names itself acts as that member"        "$( rigField "$rigOut" team-member )" rig-member

echo "-- 2. opt-in only: with none named it is the console's own account --"
rigOut="$( rigShow )"
rigAssert "it acts as user-<account>, never as a member"                "$( rigField "$rigOut" team-member )" "user-$rigAccount"

echo "-- 3. the session and the spawn are implied too --"
rigOut="$( rigShow MDAT_TEAM_MEMBER=rig-member MDAT_SESSION_ID=rig-session MDAT_SPAWNED_ID=rig-spawn )"
rigAssert "the session comes from MDAT_SESSION_ID"                     "$( rigField "$rigOut" session-id )" rig-session
rigAssert "the spawn comes from MDAT_SPAWNED_ID"                       "$( rigField "$rigOut" spawn-id )" rig-spawn
rigOut="$( rigShow MDAT_TEAM_MEMBER=rig-member MDAT_SPAWN_SESSION_ID=rig-spawn-both MDAT_SPAWNED_ID=rig-spawn )"
rigAssert "the spawn session id stands ahead of MDAT_SPAWNED_ID"       "$( rigField "$rigOut" spawn-id )" rig-spawn-both

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
exit 0
