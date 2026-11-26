#!/usr/bin/env bash
## Behavioural check on the two comms arms that call the acting-member guard, `AgentsToolsActingMemberCheck`:
## a Trello operation and a wait each answer instead of failing as `command not found`.
## The guard is called before its own include is loaded unless the calling file arms it, so an unarmed
## call site fails inside the operation and the caller reads a shell error where it needs its result.
## Held:
##   0. the probe: a stand-in .fn.sh that calls the guard with no arming line fails exactly as the fault
##      was measured, and the same call with the arming line answers. The probe can come out both ways.
##   1. --trello-whoami answers: the acting member's own Trello identity is printed, and its body ran
##      (the stub Trello endpoint was called), so a green is not a call that failed earlier and quietly.
##   2. --wait-for-input answers: it returns its WAIT-RESULT line rather than ERROR.
## Red before the fix: both operations fail with `AgentsToolsActingMemberCheck: command not found`.
## Green after: each prints its own result.
## Offline: a rig workspace and data root under .local/temp, a stub curl first on PATH, no Slack, no Trello.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTrello="$rigPackage/sh-scripts/DistroAgentsTrello.fn.sh"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigInclude="$rigPackage/sh-lib/member/AgentsTools.ActingMember.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTrello" ] || rigRefuse "the Trello operations are not at the origin this workspace resolves: $rigTrello"
[ -f "$rigSession" ] || rigRefuse "the session operations are not at the origin this workspace resolves: $rigSession"
[ -f "$rigInclude" ] || rigRefuse "the guard's own include is not at the origin this workspace resolves: $rigInclude"
rigTmp="$( mkdir -p "${MMDAPP%/}/.local/temp" && mktemp -d "${MMDAPP%/}/.local/temp/AgentsActingMemberGuardAnswerCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigMember="rig-member"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/home" "$rigTmp/data/board" "$rigTmp/bin" "$rigTmp/skills/$rigMember" "$rigTmp/data/questions"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigTmp/data/board/$rigState" ; done
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
printf 'TRELLO_KEY=rig-trello-key\nTRELLO_TOKEN=rig-trello-token\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
## The stub Trello endpoint: it answers members/me, and it notes every call, so a row can tell the
## operation's own body running from a call that stopped before it.
printf '%s\n' '#!/bin/sh' "printf '%s\\n' \"\$*\" >> '$rigTmp/curl.log'" 'printf '\''{"id":"rig-id-1","username":"rig-user-1"}\n'\''' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
: > "$rigTmp/curl.log"

## Every call runs in the rig's own workspace and identity, with nothing of this session's environment:
## an inherited session id or Slack token would point the call at a real conversation.
rigAs(){ ## output name, command...
	local asOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" \
		PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-$rigMember-run" \
		bash "$@" ) > "$rigTmp/$asOut.out" 2> "$rigTmp/$asOut.err" < /dev/null
	printf '%s' "$?" > "$rigTmp/$asOut.rc"
}
## A wait that outlives its bound would hold this check open: a limiter kills it, and the row reads the kill.
## The wall clock is bash's own, since Darwin carries neither `timeout` nor `gtimeout`.
rigBounded(){ ## output name, seconds, command...
	local boundOut="$1" boundSeconds="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" \
		PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-$rigMember-run" \
		bash -c 'exec "$@" & here=$! ; ( sleep '"$boundSeconds"' ; kill -9 $here 2> /dev/null ) > /dev/null 2>&1 & limiter=$! ; wait $here ; rc=$? ; kill $limiter 2> /dev/null ; exit $rc' rig "$@" ) \
		> "$rigTmp/$boundOut.out" 2> "$rigTmp/$boundOut.err" < /dev/null
	printf '%s' "$?" > "$rigTmp/$boundOut.rc"
}
rigRc(){ cat "$rigTmp/$1.rc" ; }
rigSaid(){ ## output name, text -- whether its stdout or stderr holds the text
	LC_ALL=C grep -q -F -- "$2" "$rigTmp/$1.out" "$rigTmp/$1.err" 2> /dev/null && printf yes || printf no
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- 0. the probe comes out both ways on the fault's own shape --"
printf '#!/usr/bin/env bash\nMDSC_CMD=rig\nAgentsToolsActingMemberCheck "%s" trello-whoami\n' "$rigMember" > "$rigTmp/RigUnarmed.fn.sh"
printf '#!/usr/bin/env bash\nMDSC_CMD=rig\ntype AgentsToolsActingMemberCheck > /dev/null 2>&1 || . "%s"\nAgentsToolsActingMemberCheck "%s" trello-whoami\n' "$rigInclude" "$rigMember" > "$rigTmp/RigArmed.fn.sh"
rigAs bare "$rigTmp/RigUnarmed.fn.sh"
rigAssert "control: an unarmed call fails as command not found"  "$( [ "$( rigRc bare )" -ne 0 ] && printf failed || printf passed ):$( rigSaid bare 'AgentsToolsActingMemberCheck: command not found' )" "failed:yes"
rigAs armed "$rigTmp/RigArmed.fn.sh"
rigAssert "control: the same call, armed, answers"               "$( rigRc armed ):$( rigSaid armed 'command not found' )" "0:no"

echo "-- 1. a Trello operation answers, instead of failing before its body --"
: > "$rigTmp/curl.log"
rigAs trello "$rigTrello" --trello-whoami "$rigMember"
rigAssert "it does not fail as command not found"               "$( rigSaid trello 'command not found' )" no
rigAssert "it answers, rc 0"                                    "$( rigRc trello )" 0
rigAssert "with the acting member's own Trello identity"        "$( LC_ALL=C sed -n 's/^TRELLO_USER_ID=//p' "$rigTmp/trello.out" | head -1 )" "rig-id-1"
## The control for the row above: the operation reached its own Trello call. Without this, a call that
## failed earlier for another reason would pass every row here by saying nothing.
rigAssert "and its own body ran: the Trello endpoint was called" "$( LC_ALL=C grep -c 'members/me' "$rigTmp/curl.log" )" 1

echo "-- 2. a wait answers, instead of failing before its own result --"
: > "$rigTmp/curl.log"
rigBounded wait 45 "$rigSession" --wait-for-input "$rigMember" --wait-timeout 1
rigAssert "it does not fail as command not found"               "$( rigSaid wait 'command not found' )" no
rigAssert "it does not report an error result"                  "$( rigSaid wait 'WAIT-RESULT: ERROR' )" no
rigAssert "it returns a wait result of its own, rc 0"           "$( rigRc wait ):$( LC_ALL=C grep -c '^WAIT-RESULT: ' "$rigTmp/wait.out" )" "0:1"

echo
printf 'ACTING_MEMBER_GUARD_ANSWER: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ ACTING MEMBER GUARD ANSWER CHECK FAILED" >&2 ; exit 1 ; }
