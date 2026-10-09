#!/usr/bin/env bash
## Behavioural check on which token --member-comms-slack-send-message posts under, run
## rather than read, against a scenario workspace built here. Holds: --identity-bot
## posts with the bot token, the human-owner target included; without it a member
## holding its own SLACK_USER_TOKEN posts with that token, and a token-less member's
## human-owner send relays under magic-coordinator's. A fake `curl` first on PATH
## logs each method with its token; every token is a literal. Offline by construction.
## Also who may send: a spawned session acts only as itself through a --member-* op (send,
## react, email, wait, digest) and reads no config scope, the tooling's --intern-op-* form
## names any member, and the --magic-* form is the coordinator's.
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

## Who may send. A spawned session (MDAT_SPAWN_AGENT) acts only as its own member through a
## --member-* op; the tooling's --intern-op-* form and the coordinator's --magic-* form do not.
rigOpAs(){ ## acting member (empty: none), op and arguments... -- stdout and stderr, then rc=<n>
	: > "$rigTmp/calls"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		${1:+MDAT_SPAWN_AGENT="$1"} bash "$rigTool" "${@:2}" 2>&1 ; echo "rc=$?" )
}
rigSendAs(){ ## acting member, send op, member, target -- the token it posted under, or refused
	local sendOut
	sendOut="$( rigOpAs "$1" "$2" "$3" "$4" RIG-BODY-MARKER )"
	case "$sendOut" in
		*'this session acts as'*) printf 'refused, %s posted' "$( rigPostCount )" ; return 0 ;;
	esac
	LC_ALL=C awk '$1 == "chat.postMessage" { print $2 ; exit }' "$rigTmp/calls"
}
rigAssert "a session sending as another member through --member-comms-* is refused" \
	"$( rigSendAs keeper-myx --member-comms-slack-send-message magic-coordinator magic-team )" "refused, 0 posted"
rigAssert "control: the same session sending as itself posts under its own token" \
	"$( rigSendAs keeper-myx --member-comms-slack-send-message keeper-myx magic-team )" rig-user-token-KEEPER
rigAssert "the tooling's --intern-op-comms-* form sends as the member it names" \
	"$( rigSendAs keeper-myx --intern-op-comms-slack-send-message magic-coordinator magic-team )" rig-user-token-COORD
rigAssert "--magic-comms-* from another member's session is refused" \
	"$( rigSendAs keeper-myx --magic-comms-slack-send-message keeper-myx magic-team )" "refused, 0 posted"
rigAssert "--magic-comms-* from the coordinator's session acts as the member named" \
	"$( rigSendAs magic-coordinator --magic-comms-slack-send-message keeper-myx magic-team )" rig-user-token-KEEPER
rigAssert "control: the console sends as any member" \
	"$( rigSendAs "" --member-comms-slack-send-message magic-coordinator magic-team )" rig-user-token-COORD
rigAssert "a scope declaration passes the stub from any session" \
	"$( rigOpAs keeper-myx --member-comms-slack-react --print-required-scopes | LC_ALL=C grep -c -x 'reactions:write' )" 1
rigAssert "a react as another member is refused" \
	"$( rigOpAs keeper-myx --member-comms-slack-react magic-coordinator CRIG00001:1700000000.000100 eyes | LC_ALL=C grep -c -e 'this session acts as keeper-myx, so it cannot act as magic-coordinator' -e '^rc=1$' )" 2
rigAssert "an email send as another member is refused before any connection" \
	"$( rigOpAs keeper-myx --member-comms-email-send magic-coordinator rig@example.org -- rig -- body | LC_ALL=C grep -c -e 'this session acts as keeper-myx' -e '^rc=1$' )" 2
rigAssert "a wait as another member is refused with its result line" \
	"$( rigOpAs keeper-myx --member-wait-for-input magic-coordinator --wait-list-sources | LC_ALL=C grep -c -x -e 'WAIT-RESULT: ERROR' -e 'rc=1' )" 2
rigAssert "control: a wait as itself is not refused" \
	"$( rigOpAs keeper-myx --member-wait-for-input keeper-myx --wait-list-sources | LC_ALL=C grep -c 'this session acts as' )" 0
rigAssert "a digest as another member is refused, nothing posted" \
	"$( rigOpAs keeper-myx --member-contact-digest-send magic-coordinator --resolved rig digest | LC_ALL=C grep -c -e 'this session acts as keeper-myx' -e '^rc=1$' ):$( rigPostCount )" "2:0"
rigAssert "an escalation read as another member is refused" \
	"$( rigOpAs keeper-myx --member-escalation-read magic-coordinator rig-no-such-ask | LC_ALL=C grep -c -e 'this session acts as keeper-myx, so it cannot act as magic-coordinator' -e '^rc=1$' )" 2
rigAssert "the tooling's --intern-op-escalation-read reads as the member it names" \
	"$( rigOpAs keeper-myx --intern-op-escalation-read magic-coordinator rig-no-such-ask | LC_ALL=C grep -c -e 'this session acts as' -e 'no escalation record rig-no-such-ask' )" 1
rigScopeOut="$( rigOpAs keeper-myx --member-config-option keeper-myx --select SLACK_USER_TOKEN )"
rigAssert "--member-config-option is no member op: refused, printing no credential, even of the session's own scope" \
	"$( printf '%s\n' "$rigScopeOut" | LC_ALL=C grep -c 'rig-user-token-KEEPER' ):$( printf '%s\n' "$rigScopeOut" | LC_ALL=C grep -c -x 'rc=1' )" "0:1"
rigAssert "control: --agents-config-option, the tooling's, reads any scope" \
	"$( rigOpAs keeper-myx --agents-config-option magic-coordinator --select SLACK_USER_TOKEN | LC_ALL=C grep -c -x -e rig-user-token-COORD -e rc=0 )" 2

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK SEND IDENTITY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_IDENTITY: OK (%d assertions, offline)\n' "$rigPasses"