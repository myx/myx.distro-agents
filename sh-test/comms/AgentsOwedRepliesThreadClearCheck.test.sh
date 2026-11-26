#!/usr/bin/env bash
## Behavioural check on a reply clearing the owed line of the message it answers, when that message
## sits INSIDE a thread: sh-lib/slack/AgentsTools.InternOpCommsSlackSend.include hands the clear the ts
## the reply was posted under, never the thread root Slack flattens it to.
## Holds:
##   1. A REPLY UNDER A MESSAGE INSIDE A THREAD removes that message's own line. Slack answers such a
##      post with the thread's ROOT in message.thread_ts, so one that cleared on that answer removes
##      nothing while the member owes it for ever.
##   2. THE CONTROL IN THE OTHER DIRECTION: a reply given a different message of the same thread leaves
##      the first one's line standing, so the first assertion cannot pass by clearing the whole thread.
##   3. A line for a message nobody answered stays.
## Offline: a Slack-shaped fake curl first on PATH, and one whose answers carry the flattening.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$rigPackage/sh-test"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsOwedRepliesThreadClearCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/members/magic-coordinator" \
	"$rigHome/.agents/magic-team" "$rigScenario" "$rigWs/.local/agents/schedule/owed"
cp "$rigTest/check-fixtures/owed-reply-thread.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/owed-reply-thread.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001' 'SLACK_BOT_TOKEN=rig-bot-token-TEAM' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' > "$rigWs/.local/agents/team-members-names.registry"
printf '%s\t%s\n' magic-coordinator "$rigWs/.local/agents/members/magic-coordinator" > "$rigHome/.agents/magic-team/members.registry"

## ONE THREAD, two messages under it: the root, and a message posted under the root.
rigRoot="1794216200.000001"
rigInner="1794216240.000100"
rigOther="1794216300.000200"
rigOwed="$rigWs/.local/agents/schedule/owed/magic-coordinator"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## Two persons' messages owed, each at its own ts, both inside the one thread.
rigSeed(){
	printf '%s\n' \
		"$( printf '1794216500\tslack:CRIG00001:%s\tUPERSON1\twhere does the variable go?' "$rigInner" )" \
		"$( printf '1794216500\tslack:CRIG00001:%s\tUPERSON2\tshould this ship?' "$rigOther" )" \
		> "$rigOwed"
}
rigSend(){ ## target -- posts one reply there, and prints the tool's own stderr
	: > "$rigScenario/calls"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		RIG_THREAD_ROOT="$rigRoot" MDAT_OWED_REPLY_SECONDS=0 \
		bash "$rigTool" --slack-send-message --team-member magic-coordinator "$1" --told RIG-BODY ) \
		> "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	printf '%s\n' "$( LC_ALL=C sed -n 's/^SENT_MESSAGE_THREAD_TS=//p' "$rigTmp/err" | head -1 )"
}
rigLines(){ wc -l < "$rigOwed" | tr -d ' ' ; }

echo "-- the message owed, answered where it was asked --"
rigSeed
rigAssert "the store holds the two messages owed" "$( rigLines )" "2"
rigAssert "the reply under the inner message reports the thread root Slack flattened it to" \
	"$( rigSend "magic-team:$rigInner" )" "$rigRoot"
rigAssert "the inner message's own line is gone" \
	"$( LC_ALL=C grep -c "slack:CRIG00001:$rigInner" "$rigOwed" || : )" "0"
rigAssert "the control: the other message of the same thread still owes a reply" \
	"$( LC_ALL=C grep -c "slack:CRIG00001:$rigOther" "$rigOwed" || : )" "1"

echo "-- the control in the other direction --"
rigSeed
rigSend "magic-team:$rigOther" > /dev/null
rigAssert "a reply to the other message leaves the first one's line standing" \
	"$( LC_ALL=C grep -c "slack:CRIG00001:$rigInner" "$rigOwed" || : )" "1"

echo "-- a line for a message nobody answered stays --"
rigSeed
rigSend "magic-team:$rigOther" > /dev/null
rigAssert "the unanswered line is untouched" "$( rigLines )" "1"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
