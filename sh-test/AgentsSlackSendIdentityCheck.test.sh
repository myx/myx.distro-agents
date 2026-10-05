#!/usr/bin/env bash
## Behavioural check on which token --member-comms-slack-send-message posts under, run
## rather than read, against a scenario workspace built here. Holds: --identity-bot
## posts with the bot token, the human-owner target included; without it a member
## holding its own SLACK_USER_TOKEN posts with that token, and a token-less member's
## human-owner send relays under magic-coordinator's. A fake `curl` first on PATH
## logs each method with its token; every token is a literal. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSlackSendIdentityCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"

## The token chat.postMessage was called under, or the refusal the send ended with.
rigSend(){ ## member, target, send options...
	: > "$rigTmp/calls"
	local sendOut=""
	sendOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --member-comms-slack-send-message "$1" "$2" "${@:3}" RIG-BODY-MARKER 2>&1 )" \
		|| { printf 'send-failed: %s' "$( printf '%s\n' "$sendOut" | grep 'ERROR' | head -1 )" ; return 0 ; }
	LC_ALL=C awk '$1 == "chat.postMessage" { print $2 ; exit }' "$rigTmp/calls"
}

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

## The subject has to be reachable before anything is asserted about it.
rigSend magic-team magic-team --identity-bot > /dev/null
grep -q '^chat.postMessage ' "$rigTmp/calls" || rigRefuse "no send reached the fake curl at all, so no identity below would be measured"

rigAssert "--identity-bot to human-owner posts with the bot token" \
	"$( rigSend magic-team human-owner --identity-bot )" rig-bot-token-TEAM
rigAssert "--identity-bot to human-owner, a member with its own user token" \
	"$( rigSend keeper-myx human-owner --identity-bot )" rig-bot-token-TEAM
rigAssert "--identity-bot to a channel posts with the bot token" \
	"$( rigSend keeper-myx magic-team --identity-bot )" rig-bot-token-TEAM
rigAssert "no flag, a member with its own user token posts with that token" \
	"$( rigSend keeper-myx human-owner )" rig-user-token-KEEPER
rigAssert "no flag, the same member to a channel keeps its own token" \
	"$( rigSend keeper-myx magic-team )" rig-user-token-KEEPER
rigAssert "no flag, a token-less member to human-owner relays under magic-coordinator" \
	"$( rigSend magic-team human-owner )" rig-user-token-COORD

## A transport failure before anything reached Slack is retried; one after it may have
## reached Slack is not, since a post is not idempotent and a retry could post twice.
rigPostCount(){ LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" ; }
printf '6\n0\n' > "$rigTmp/post-exits"
rigAssert "a DNS failure (curl 6) is retried and the post goes out" \
	"$( rigSend keeper-myx magic-team --identity-bot > /dev/null ; rigPostCount )" 2
printf '28\n0\n' > "$rigTmp/post-exits"
: > "$rigTmp/calls"
rigSendRc=0
rigSendOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --member-comms-slack-send-message keeper-myx magic-team --identity-bot RIG-BODY-MARKER 2>&1 )" || rigSendRc=$?
rigAssert "a timeout after the request left (curl 28) is not retried" "$( rigPostCount )" 1
rigAssert "and the send fails" "$rigSendRc" 1
rigAssert "and the send says whether it posted is unknown" \
	"$( printf '%s' "$rigSendOut" | grep -c 'WHETHER THIS WAS POSTED IS UNKNOWN' )" 1
rm -f "$rigTmp/post-exits"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK SEND IDENTITY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_IDENTITY: OK (%d assertions, offline)\n' "$rigPasses"