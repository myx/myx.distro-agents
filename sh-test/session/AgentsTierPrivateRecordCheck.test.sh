#!/usr/bin/env bash
## Behavioural check on private content staying out of the session's own records (stage 7 of the
## security context tier set): the detour's private body never enters the session chat file nor the
## session transcript, and only the pointer line does.
## Held, one case per statement:
##   1. control: the probe sees a body in the session chat file, so a body there is visible to it
##   2. control: the probe sees a planted line in the session transcript, and is clear once it is
##      cleared, so the absences below are real absences and not a blind reader
##   3. the detour ran and reported its two sends
##   4. the private body is in neither the chat file nor the chat index
##   5. the private body is not in the session transcript
##   6. the pointer line is in the session chat file, so the record says the detour happened
##   7. the private body reached the owner's own conversation, so it was delivered and not dropped
## Red before stages 6 and 7: `AgentsToolsCommsTierPublish` is not there, so case 3 fails and 4 to 7
## with it. Cases 1 and 2 hold as the probe's own proof.
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
rigTmp="$( rigTempDir AgentsTierPrivateRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigSession="rig-t7"
rigHome="$rigTmp/home"
rigScenario="$rigTmp/scenario"
rigData="$rigTmp/data"
## Both members the send path needs are made here: it refuses an address that names no member.
mkdir -p "$rigWs/.local/.agents" "$rigSessions/$rigSession" "$rigHome" "$rigTmp/bin" "$rigScenario" \
	"$rigData/audit/2026-11" "$rigWs/.local/agents/members/magic-tester" "$rigWs/.local/agents/members/magic-coordinator" \
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
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
: > "$rigScenario/bodies" ; : > "$rigScenario/calls"

## The session is on the `full` kind, records `system`, and has its own transcript on record.
printf 'full\n' > "$rigSessions/$rigSession/root-session.kind"
printf 'CRIG00001:1700000000.000001\n' > "$rigSessions/$rigSession/session.thread"
printf 'system\n' > "$rigSessions/$rigSession/security.tier"
## The `system` tier names the session's tooling thread, and refuses a send where the session has none (AgentsToolsCommsTierTarget).
printf 'CRIGTRACK:1700000000.000002\n' > "$rigSessions/$rigSession/event-track.thread"
rigTranscript="$rigData/audit/2026-11/session-rig-t7.log"
printf 'START session=rig-t7 member=magic-tester\n' > "$rigTranscript"
printf '%s\n' "$rigTranscript" > "$rigSessions/$rigSession/transcript"
printf '%s\n' "$rigData" > "$rigSessions/$rigSession/data-root"

## Each case gets a body of its own: the send path refuses an identical repeat as a loop.
rigSecret='RIGPRIVATEBODY-stage-seven'
rigOther='RIGORDINARYBODY-control'

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigAllChatText(){ cat "$rigSessions/$rigSession"/session.chat* 2> /dev/null || : ; }
rigTranscriptText(){ cat "$rigTranscript" 2> /dev/null || : ; }
rigCount(){ ## text, fixed marker -- matching lines, 0 where none
	printf '%s\n' "$1" | LC_ALL=C grep -c -F -- "$2" 2> /dev/null || :
}
rigOut="" ; rigOutRc=0
## An unaddressed send: the empty target is the send's own "the session's own channel", and the body
## goes on stdin, as the team's own send path takes it.
rigSend(){ ## body
	local rigBody="$1"
	rigOut="$( printf '%s' "$rigBody" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash "$rigTool" --slack-send-message --team-member magic-tester "" --from-stdin 2>&1 ) )" ; rigOutRc=$?
}
rigPublishOut="" ; rigPublishRc=0
rigPublish(){ ## member, tier, open target, addressees...
	rigPublishOut="$( printf '%s' "$rigSecret" | ( cd "$rigWs" && env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash -c '. "$1" 2> /dev/null || exit 127 ; shift ; AgentsToolsCommsTierPublish "$@"' \
		rig "$rigTierInclude" "$@" 2>&1 ) )" ; rigPublishRc=$?
}

echo "-- 1. control: the probe sees a body in the session chat file --"
rigSend "$rigOther"
rigAssert "the control send is recorded in the session chat file, so a body there is visible to this probe" \
	"$( [ "$( rigCount "$( rigAllChatText )" "$rigOther" )" -ge 1 ] && printf visible || printf blind )" visible

echo "-- 2. control: the probe sees a line in the session transcript --"
printf '%s\n' "$rigSecret" >> "$rigTranscript"
rigAssert "a planted line in the transcript is found by this probe" "$( rigCount "$( rigTranscriptText )" "$rigSecret" )" 1
printf 'START session=rig-t7 member=magic-tester\n' > "$rigTranscript"
rigAssert "and once cleared it is gone, so the probe reads the file as it stands" "$( rigCount "$( rigTranscriptText )" "$rigSecret" )" 0

echo "-- 3. to 7. the detour: private body nowhere in the records, the pointer in the chat file --"
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
rigPublish magic-tester private 'CRIG00001:1700000000.000001' magic-coordinator
rigAssert "the detour ran, and reported its two sends" \
	"$( printf '%s\n' "$rigPublishOut" | LC_ALL=C grep -c '^SENT_MESSAGE_TS=' )" 2
rigAssert "the private body is in neither the chat index nor the chat file" \
	"$( rigCount "$( rigAllChatText )" "$rigSecret" )" 0
rigAssert "and not in the session transcript either" "$( rigCount "$( rigTranscriptText )" "$rigSecret" )" 0
rigAssert "the pointer line is in the session chat file, so the record says the detour happened" \
	"$( rigCount "$( rigAllChatText )" 'direct conversation' )" 1
rigAssert "and the private body reached the owner's own conversation, so it was delivered and not dropped" \
	"$( LC_ALL=C grep -c -F "$rigSecret" "$rigScenario/bodies" )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TIER PRIVATE RECORD CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  what the detour records, never the assertion" >&2
	exit 1
fi
printf 'TIER_PRIVATE_RECORD: OK (%d assertions, offline)\n' "$rigPass"
