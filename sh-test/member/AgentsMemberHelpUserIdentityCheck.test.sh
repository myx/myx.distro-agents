#!/usr/bin/env bash
## Behavioural check on `--member-help` with no team member resolved (S21.20): a root console
## session's own fallback identity, user-<account>, is not a member with help of its own. Held:
##   1. With no --team-member and no implied member, the call is refused, clearly: it names whose
##      help was tried and says to name a real member, never the earlier confusing "not a
##      recognized team-member naming pattern".
##   2. --team-member, given explicitly, still works: the real member's help is printed.
## Offline: no Slack, no network, a scratch skillset of the rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMemberHelpUserIdentityCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local" "$rigTmp/skills/magic-team"
printf '# magic-team\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"

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
rigCall(){ ## team-member (empty for none), args...
	( env -u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID \
		${1:+MDAT_TEAM_MEMBER="$1"} HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		"$rigTool" "${@:2}" ) 2>&1
}

echo "-- 1. no team member resolved: refused, clearly, not the old confusing message --"
rigOut="$( rigCall '' --member-help )"
rigAssert "the old confusing message is gone" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F 'not a recognized team-member naming pattern' )" 0
rigAssert "says whose help was tried and names no help of its own" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F 'has no help of its own' )" 1
rigAssert "names the way out" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F '--member-help <team-member>' )" 1

echo "-- 2. --team-member, given explicitly, still works --"
rigAssert "the real member's help is printed, not refused" "$( rigCall '' --member-help --team-member magic-team | LC_ALL=C grep -c -F 'has no help of its own' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER HELP USER IDENTITY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a root console with no team member resolved gets a confusing refusal from --member-help" >&2
	echo "  fix:  repair sh-lib/member/AgentsTools.MemberHelp.include -- never the assertion" >&2
	exit 1
fi
printf 'MEMBER_HELP_USER_IDENTITY: OK (%d assertions, offline)\n' "$rigPassCount"
