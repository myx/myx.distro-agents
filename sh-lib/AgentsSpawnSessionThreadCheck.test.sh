#!/usr/bin/env bash
## Behavioural check on the session thread --intern-op-agent-spawn-proxy opens, run
## rather than read, against a scenario workspace built here. Holds: a spawn posts its
## opening to magic-team once and hands `session_thread_ts: <channel>:<ts>` to the
## session in its brief; a failed post still launches the spawn, says so on stderr,
## and hands over none. A fake console records the brief; the fake curl is the Slack
## send identity check's own. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSpawnSessionThreadCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: it records the brief and the launch, and runs no
## model. It names --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy
## greps for before it launches anything.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## One spawn; prints the proxy's own output, stdout and stderr together.
rigSpawn(){
	: > "$rigTmp/calls"
	: > "$rigTmp/bodies"
	: > "$rigTmp/brief"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --wait --context rig-session-thread <<< "RIG-BRIEF-MARKER" 2>&1 ) || :
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

## The post succeeds.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigOut="$( rigSpawn )"
## The subject has to be reachable before anything is asserted about it.
grep -q 'RIG-BRIEF-MARKER' "$rigTmp/brief" || rigRefuse "the fake console never received the brief, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep 'ERROR' | head -1 )"

rigAssert "the spawn launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the opening is posted once, under the bot token" \
	"$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 }' "$rigTmp/calls" )" rig-bot-token-TEAM
rigAssert "the opening is addressed to the spawned member, never @here" \
	"$( grep -c '→ @here' "$rigTmp/bodies" ) $( grep -c '"text":"[^"]*→ [^"]*_keeper-myx_' "$rigTmp/bodies" )" "0 1"
rigAssert "the brief hands over session_thread_ts as <channel>:<ts>" \
	"$( grep '^session_thread_ts: ' "$rigTmp/brief" )" "session_thread_ts: DRIG00001:1.000001"

## The post fails: magic-team names no channel.
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigOut="$( rigSpawn )"
rigAssert "a failed post still launches the spawn" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "a failed post posts nothing" "$( grep -c '^chat.postMessage ' "$rigTmp/calls" )" 0
rigAssert "a failed post is reported" "$( printf '%s\n' "$rigOut" | grep -c 'session thread not opened' )" 1
rigAssert "a failed post hands over no thread" \
	"$( grep -c '^session_thread_ts: none' "$rigTmp/brief" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SESSION THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SESSION_THREAD: OK (%d assertions, offline)\n' "$rigPasses"