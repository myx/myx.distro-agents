#!/usr/bin/env bash
## Behavioural check on PushNotification as the myx.distro MCP server serves it: the tool a
## native client is rerouted to when it reaches for its own PushNotification. One served call
## to event-track with a unique marker in its headline must reach chat.postMessage on the
## event-track channel carrying that marker, so a send that reports success but posts nothing
## fails. The control is a second call with an invalid severity: refused, and nothing sent.
##
## Offline, and self-contained in its scratch: MMDAPP, HOME and the skillset are fixtures,
## and the Slack-shaped fake curl first on PATH answers every call, so nothing is posted.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "not found at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsHarnessPushNotificationCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/skills/magic-coordinator"
printf 'rig-coordinator\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"

cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would post for real"
: > "$rigTmp/calls"
: > "$rigTmp/bodies"

printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigTmp/ws/.local/.agents/magic-coordinator.agent.env"
printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"

rigMark="rig-push-$( date +%s )-$$"

## One server life. The recursion marker is cleared because this rig IS the directly
## registered server, and the spawn variable so the call acts as the root session.
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"PushNotification","arguments":{"to":"event-track","severity":"info","headline":"Test push from the PushNotification check, marker %s"}}}\n' "$rigMark"
	printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"PushNotification","arguments":{"to":"event-track","severity":"bogus","headline":"%s-control"}}}\n' "$rigMark"
} | (
	unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_DATA_ROOT
	cd "$rigTmp/ws" && RIG_SCENARIO="$rigTmp" HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigTool" --intern-mcp-server --run > "$rigTmp/serve.wire" 2> "$rigTmp/serve.err"
) || :
LC_ALL=C grep -q '"id":1,' "$rigTmp/serve.wire" 2>/dev/null || {
	sed 's/^/    /' "$rigTmp/serve.err" >&2
	rigRefuse "the server did not answer initialize, so nothing was served"
}
LC_ALL=C grep -q '^chat.postMessage ' "$rigTmp/calls" || {
	sed 's/^/    /' "$rigTmp/serve.err" >&2
	LC_ALL=C grep '"id":2,' "$rigTmp/serve.wire" | sed 's/^/    /' >&2
	rigRefuse "no send reached the fake curl at all, so there is nothing to read back"
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

echo "-- a served PushNotification to the event-track channel --"
rigAssert "the served call reports a sent message" \
	"$( LC_ALL=C grep '"id":2,' "$rigTmp/serve.wire" | LC_ALL=C grep -F -q -- 'SENT_MESSAGE_TS' && printf 'sent' || printf 'not-sent' )" "sent"
rigAssert "the posted body carries the marker, on the event-track channel" \
	"$( LC_ALL=C grep -F -- "$rigMark" "$rigTmp/bodies" | LC_ALL=C grep -F -q -- 'CRIGTRACK' && printf 'marker' || printf 'no-marker' )" "marker"

echo "-- control: an invalid severity --"
rigControl="$( LC_ALL=C grep '"id":3,' "$rigTmp/serve.wire" )"
rigAssert "it is refused for its severity" \
	"$( LC_ALL=C grep -F -q -- 'severity must be info, warn or alert' <<< "$rigControl" && printf 'refused' || printf 'not-refused' )" "refused"
rigAssert "nothing is sent" \
	"$( LC_ALL=C grep -F -q -- "$rigMark-control" "$rigTmp/bodies" && printf 'sent' || printf 'not-sent' )" "not-sent"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ PUSH NOTIFICATION CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a native client rerouted to the served PushNotification does not reach" >&2
	echo "        the event-track channel, or an invalid severity is not refused" >&2
	echo "  fix:  repair the served PushNotification -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_PUSH_NOTIFICATION: OK (%d assertions, offline)\n' "$rigPasses"