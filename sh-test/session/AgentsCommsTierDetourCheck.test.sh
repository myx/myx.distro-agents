#!/usr/bin/env bash
## Behavioural check on `public` being a refusal and not a channel, and on the detour as one operation
## (stages 5 and 6 of the security context tier set), run rather than read, against a rig workspace built
## here, with a Slack-shaped fake curl that opens no socket.
## Held, one case per statement:
##   0. control: the rig's own send path works and both members resolve, on the untouched tree too
##   S5.1 a session recording `public` is refused when it sends to a team store, and nothing is posted
##   S5.2 control: the same unaddressed send from a session recording `shared` is posted, so the refusal
##        is the tier's and not the send path's
##   S5.3 the refusal names the contacts route, so the member knows where a public reply does go
##   S6.1 the detour posts the private part first, to the owner's own conversation, as the bot
##   S6.2 then the pointer, into the open thread it was moved out of, naming no subject
##   S6.3 a pointer that lands reports no `POINTER-FAILED=` line
##   S6.4 a private post whose pointer fails reports `POINTER-FAILED=` with the conversation it missed,
##        and never reposts the private part
## Red before stages 5 and 6: S5.1 is not refused at all, because the tier names nowhere, and every S6
## case fails because `AgentsToolsCommsTierPublish` is not there.
## Offline: a fake curl first on PATH; nothing leaves the rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTierInclude="$rigPackage/sh-lib/comms/AgentsTools.CommsTier.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this run resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsTierDetourCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigHome="$rigTmp/home"
rigScenario="$rigTmp/scenario"
## Both members the detour needs are made here: the send path refuses an address that names no member of
## the workspace, and the detour addresses the coordinator from the member.
mkdir -p "$rigWs/.local/.agents" "$rigSessions" "$rigHome" "$rigTmp/bin" "$rigScenario" \
	"$rigWs/.local/agents/members/magic-tester" "$rigWs/.local/agents/members/magic-coordinator" \
	|| rigRefuse "cannot make the rig"
printf -- '---\nname: magic-tester\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-tester/SKILL.md"
printf -- '---\nname: magic-coordinator\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-magic-tester\n' > "$rigWs/.local/.agents/magic-tester.agent.env"
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
export MMDAPP="$rigWs"
export HOME="$rigHome"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export RIG_SCENARIO="$rigScenario"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a case could reach a socket"

## Each case gets a body of its own: the send path refuses an identical repeat as a loop, so one body used
## twice would read as that refusal and never post.
rigBodyOf(){ ## case label -- that case's own body
	printf 'RIGPRIVATEBODY-%s' "$1"
}
rigSecret="$( rigBodyOf control )"
## A session on the `full` kind, with its own thread on record, recording the tier given.
rigSession(){ ## name, tier
	mkdir -p "$rigSessions/$1"
	printf 'full\n' > "$rigSessions/$1/root-session.kind"
	printf 'CRIG00001:1700000000.000001\n' > "$rigSessions/$1/session.thread"
	printf '%s\n' "$2" > "$rigSessions/$1/security.tier"
}

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## The posts the last call made, one `chat.postMessage` a line.
rigPosts(){ LC_ALL=C grep -c -F 'chat.postMessage' "$rigScenario/calls" 2> /dev/null || : ; }
rigSendOut="" ; rigSendRc=0
rigSend(){ ## session, arguments...
	local rigSendSession="$1" ; shift
	: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
	rigSendOut="$( printf '%s' "$rigSecret" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$rigSendSession" MDAT_SPAWN_SESSION_ID="$rigSendSession" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash "$rigTool" --slack-send-message --team-member magic-tester "$@" 2>&1 ) )" ; rigSendRc=$?
}
rigPublishOut="" ; rigPublishRc=0
rigPublish(){ ## session, tier, open target, addressees...
	local rigPubSession="$1" ; shift
	rigPublishOut="$( printf '%s' "$rigSecret" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$rigPubSession" MDAT_SPAWN_SESSION_ID="$rigPubSession" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash -c '. "$1" 2> /dev/null || exit 127 ; shift ; AgentsToolsCommsTierPublish "$@"' \
		rig "$rigTierInclude" magic-tester "$@" 2>&1 ) )" ; rigPublishRc=$?
}

echo "-- 0. control: the rig itself works on the untouched tree --"
rigAssert "the detour's sender and its addressee both resolve as members of the rig" \
	"$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamRegistry.include" ;
		printf "%s %s" "$( AgentsToolsTeamMemberDirectory magic-tester > /dev/null 2>&1 && printf present || printf absent )" \
		"$( AgentsToolsTeamMemberDirectory magic-coordinator > /dev/null 2>&1 && printf present || printf absent )"' 2> /dev/null )" \
	"present present"
rigSession rig-control shared
rigSend rig-control "" --from-stdin
rigAssert "a plain send from a shared session is posted, so the rig's send path works" \
	"[$( [ "$( rigPosts )" -ge 1 ] && printf posted || printf none )]" "[posted]"
if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS TIER DETOUR CHECK BROKEN: the control fails on the untouched tree, so no case beside it means anything" >&2
	exit 1
fi

echo "-- S5.1 a public session's send to a team store is refused, and nothing is posted --"
rigSecret="$( rigBodyOf s51 )"
rigSession rig-open public
rigSend rig-open "" --from-stdin
rigAssert "the send is refused, rc 1" "$rigSendRc" 1
rigAssert "and no message was posted anywhere" "$( rigPosts )" 0
rigAssert "the private body reached no chat file either" \
	"$( LC_ALL=C grep -r -l -F "$rigSecret" "$rigSessions" 2> /dev/null | LC_ALL=C grep -c . )" 0

echo "-- S5.2 control: the same send from a shared session is posted --"
rigSecret="$( rigBodyOf s52 )"
rigSession rig-team shared
rigSend rig-team "" --from-stdin
rigAssert "the control send is posted, so the refusal above is the tier's" \
	"[$( [ "$( rigPosts )" -ge 1 ] && printf posted || printf none )]" "[posted]"

echo "-- S5.3 the refusal names the contacts route --"
rigSecret="$( rigBodyOf s53 )"
rigSend rig-open "" --from-stdin
rigAssert "the refusal sends the member to the contacts route, not to another channel" \
	"$( printf '%s\n' "$rigSendOut" | LC_ALL=C grep -c -i 'contact' )" "1"

echo "-- S6.1 to S6.3 the detour: the private part first, then a pointer that names no subject --"
rigSecret="$( rigBodyOf s61 )"
rigSession rig-detour system
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
rigPublish rig-detour private 'CRIG00001:1700000000.000001' magic-coordinator
rigAssert "the detour reports two sends, one for the private part and one for the pointer" \
	"$( printf '%s\n' "$rigPublishOut" | LC_ALL=C grep -c '^SENT_MESSAGE_TS=' )" 2
rigAssert "the private part goes as the bot, not as the member's own account" \
	"$( LC_ALL=C grep -c -F 'chat.postMessage rig-bot-token-TEAM' "$rigScenario/calls" )" 1
rigAssert "the private body was posted once, so the private part went first" \
	"$( LC_ALL=C grep -c -F "$rigSecret" "$rigScenario/bodies" )" 1
rigAssert "the pointer names the party and the conversation, and carries no word of the private body" \
	"$( LC_ALL=C grep -c -i 'direct conversation' "$rigScenario/bodies" )" 1
rigAssert "and the pointer carries no marker of the private body" \
	"$( LC_ALL=C grep -i 'direct conversation' "$rigScenario/bodies" | LC_ALL=C grep -c -F "$rigSecret" )" 0
rigAssert "a pointer that lands reports no POINTER-FAILED line" \
	"$( printf '%s\n' "$rigPublishOut" | LC_ALL=C grep -c 'POINTER-FAILED=' )" 0

echo "-- S6.4 a failed pointer is reported, and the private part is never reposted --"
rigSecret="$( rigBodyOf s64 )"
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
printf '1\n' > "$rigScenario/post-exits"
rigPublish rig-detour private 'CRIG00001:1700000000.000002' magic-coordinator
rm -f "$rigScenario/post-exits"
rigAssert "the failure is reported as POINTER-FAILED=, with the conversation it could not reach" \
	"$( printf '%s\n' "$rigPublishOut" | LC_ALL=C grep -c 'POINTER-FAILED=CRIG00001:1700000000.000002' )" 1
rigAssert "the private part is posted once and never again" \
	"$( LC_ALL=C grep -c -F "$rigSecret" "$rigScenario/bodies" )" 1
rigAssert "so no post of it reached the open thread" \
	"$( LC_ALL=C grep -c -F 'chat.postMessage' "$rigScenario/calls" )" 1

echo "-- S6.6 the door: a member reaches the detour as an operation, with a help pair --"
## The detour's function is proved above; this case proves the operation a member can actually call. Its
## help line is read from the tool itself, and one run of it is proved to post the private part and the
## pointer, so the door is a way in and not only a declaration.
rigSessionTool="$( cd "$rigPackage/sh-scripts" && pwd )/DistroAgentsSession.fn.sh"
rigDoorHelp="$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigSessionTool" --help-syntax --post-tier-message 2>&1 )"
rigAssert "the session tool prints a syntax line for --post-tier-message, and no refusal of it" \
	"$( printf '%s\n' "$rigDoorHelp" | LC_ALL=C grep -c 'syntax: DistroAgentsSession.fn.sh --post-tier-message' )$( printf '%s\n' "$rigDoorHelp" | LC_ALL=C grep -c 'invalid option' )" "10"
rigAssert "and the line names the member and the address it takes, as its siblings do" \
	"$( printf '%s\n' "$rigDoorHelp" | LC_ALL=C grep -c -- '--team-member' )" 1
rigSecret="$( rigBodyOf s66 )"
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
rigDoorOut="$( printf '%s' "$rigSecret" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
	MDAT_SESSION_ID=rig-detour MDAT_SESSION_WORKSPACE="$rigWs" MDAT_SPAWN_AGENT=magic-tester \
	bash "$rigSessionTool" --post-tier-message --team-member magic-tester --address-to magic-coordinator --from-stdin 2>&1 ) )"
rigAssert "one run of the door posts twice: the private part, then the pointer" \
	"$( printf '%s\n' "$rigDoorOut" | LC_ALL=C grep -c 'chat.postMessage' )" 2
rigAssert "the private part reached the owner's conversation, under the bot's own identity" \
	"$( LC_ALL=C grep -c -F 'chat.postMessage rig-bot-token-TEAM' "$rigScenario/calls" )" 1

echo "-- S6.7 the door passes its addressee to both posts --"
rigDoor(){ ## session -- the door run once on the body in rigSecret, its output and status in rigDoorOut and rigDoorRc
	: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
	rigDoorOut="$( printf '%s' "$rigSecret" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$1" MDAT_SESSION_WORKSPACE="$rigWs" MDAT_SPAWN_AGENT=magic-tester \
		bash "$rigSessionTool" --post-tier-message --team-member magic-tester --address-to magic-coordinator --from-stdin 2>&1 ) )" ; rigDoorRc=$?
}
rigSecret="$( rigBodyOf s67 )"
rigDoor rig-detour
rigAssert "the addressee is named in the private part and in the pointer, one body line each" \
	"$( LC_ALL=C grep -c -F 'magic-coordinator' "$rigScenario/bodies" )" 2

echo "-- S6.8 a public session's door and detour post nothing --"
rigSecret="$( rigBodyOf s68 )"
rigSession rig-pub public
rigDoor rig-pub
rigAssert "the door refuses, naming the contacts route, with a status" \
	"$( printf '%s\n' "$rigDoorOut" | LC_ALL=C grep -c 'contacts route' ):$rigDoorRc" "1:1"
rigAssert "and the door posted nothing" "$( rigPosts )" 0
rigSecret="$( rigBodyOf s69 )"
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
rigPublish rig-pub public 'CRIG00001:1700000000.000003' magic-coordinator
rigAssert "the detour function refuses the public tier at status 2" "$rigPublishRc" 2
rigAssert "and the detour posted nothing" "$( rigPosts )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS TIER DETOUR CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the public refusal, the detour's order, and the door -- never the assertion" >&2
	exit 1
fi
printf 'COMMS_TIER_DETOUR: OK (%d assertions, offline)\n' "$rigPass"
