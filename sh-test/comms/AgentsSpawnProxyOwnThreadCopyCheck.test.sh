#!/usr/bin/env bash
## Behavioural and structural check on the delivered-copy guard for the spawn proxy (S12.15,
## AgentsToolsSessionChatDeliverCopy): a send into the thread of the session it serves is that session's own,
## never copied back as `delivered`. The proxy makes such sends from its own shell, so the proxy carries the
## session's id and thread in its environment (AgentsTools.InternOpAgentSpawnProxy.include), and a send into the
## session's own thread is seen as that session's own. Held:
##   1. a session notice with no session word leaves a `delivered` copy (red before);
##   2. the proxy's own session word stops that copy;
##   3. the proxy exports its session id (the one place, for every send it makes);
##   4. the one-send inline thread prefix on the joined line is gone, being covered by that export.
## Offline: a Slack-shaped fake curl is first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigProxy="$rigHere/spawn/AgentsTools.InternOpAgentSpawnProxy.include"

rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigProxy" ] || rigRefuse "the spawn proxy include is not at the origin this workspace resolves: $rigProxy"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnProxyOwnThreadCopyCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSession="recv-session"
rigThread="CRECV0001:1700000000.000200"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf '# armed\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
cp "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf '%s\n' "$rigThread" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"

rigPassCount=0
rigFailCount=0
rigAssert(){ if [ "$2" = "$3" ] ; then rigPassCount=$(( rigPassCount + 1 )) ; else rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fi ; }
rigDeliveredCount(){ LC_ALL=C awk -F'\t' '$4 == "delivered" { n++ } END { print n + 0 }' "$rigWs/.local/agents/sessions/$rigSession/session.chat.index" 2>/dev/null ; }
rigNotice(){ ## extra NAME=value words (empty for before)
	: > "$rigTmp/bodies"
	( cd "$rigWs" && env -i PATH="$rigTmp/bin:/usr/bin:/bin" HOME="$rigTmp" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MYXROOT="${MYXROOT:-/usr/local/share/myx.common}" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=proxy-run-id MDAT_SPAWN_AGENT=keeper-rig \
		${1:+MDAT_SESSION_ID="$rigSession" MDAT_SESSION_THREAD="$rigThread"} \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include" ; AgentsToolsSpawnProxySessionNotice "$1" keeper-rig "" handback-missing' rig "$rigThread" ) > /dev/null 2>&1
}

echo "-- the own thread is never a delivered copy --"
rm -f "$rigWs/.local/agents/sessions/$rigSession/session.chat" "$rigWs/.local/agents/sessions/$rigSession/session.chat.index"
rigNotice ""
rigAssert "a session notice with no session word leaves a delivered copy" "$( rigDeliveredCount )" "1"
rm -f "$rigWs/.local/agents/sessions/$rigSession/session.chat" "$rigWs/.local/agents/sessions/$rigSession/session.chat.index"
rigNotice "yes"
rigAssert "the proxy's own session word stops that copy" "$( rigDeliveredCount )" "0"

echo "-- the one place --"
rigAssert "the proxy exports its session id, so every send it makes is the session's own" \
	"$( LC_ALL=C grep -c -F 'export MDAT_SESSION_ID="$sessionId"' "$rigProxy" 2> /dev/null )" "1"
rigAssert "the one-send inline thread prefix is gone, covered by that export" \
	"$( LC_ALL=C grep -c -F 'MDAT_SESSION_THREAD="$sessionThread" DistroAgentsTools --intern-op-comms-slack-send-message' "$rigProxy" 2> /dev/null )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PROXY OWN THREAD COPY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PROXY_OWN_THREAD_COPY: OK (%d assertions, offline)\n' "$rigPassCount"
