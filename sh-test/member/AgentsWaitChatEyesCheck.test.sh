#!/usr/bin/env bash
## Behavioural check on the eyes reaction over a session chat message (S5 item 4, S6 item 48): the block a chat read
## hands over is keyed by its own number, and the message it carried is named as `<channel>:<ts>`, so the same
## synchronous eyes call a Slack source gets can be made. Held, run and not read:
##   1. THE CHAT READ NAMES ITS BLOCKS AND THEIR MESSAGES. A chat floor read over one message a person wrote reports
##      that block's number and that message's `<channel>:<ts>`, and not the member's own message.
##   2. THE PROBE CARRIES THEM. The chat source's own sidecar file holds the `eye` line for what it handed over, which
##      is where the wait's seen reaction reads its ids.
##   3. THE INSTRUMENT, both directions: a block whose sender is the member gives no eye line, and a block a bot wrote
##      is named all the same, since the reaction names the message and not its author.
## Offline: a chat file made by the tooling's own append, a fake Slack that makes no request, and the tree the rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is not at the origin"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitChatEyesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSession="rig-eyes-1"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession"
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -u
cat > /dev/null
case " $* " in
	*api/auth.test*) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	*api/conversations.replies*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*api/conversations.history*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*api/conversations.info*) printf '{"ok":true,"channel":{"id":"CRIGEYES01","is_im":false}}\n' ;;
	*api/conversations.list*) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGEYES01\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token\n' > "$rigWs/.local/.agents/magic-developer.agent.env"
printf 'magic-developer=URIGSELF1=rig-self=Rig Self=rig-self\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigThread="CRIGEYES01:1793800000.000001"
printf '%s\n' "$rigThread" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
printf 'read:magic-developer\t0\n' > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"

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
rigChat(){ ## from, ts, the body -- one block, written by the tooling's own append
	printf '%s\n' "$3" | ( cd "$rigWs" && env MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_SESSION_ID="$rigSession" \
		bash -c 'set -- __definitions__ ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ; AgentsToolsSessionChatAppend "$MDAT_SPAWN_SESSION_ID" "$1" magic-developer "$2" '"$rigThread"' console' "$rigSession" "$3" "$2" ) > /dev/null 2>&1
}
## The tooling's own writer takes its words as arguments in a fixed order, so it is called through a small shim.
rigAppend(){ ## from, ts, the body
	printf '%s\n' "$3" > "$rigTmp/body"
	( cd "$rigWs" && env MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_SESSION_ID="$rigSession" bash "$rigTmp/append.sh" "$1" "$2" ) > /dev/null 2>&1
}
cat > "$rigTmp/append.sh" <<'EOF'
#!/usr/bin/env bash
set -u
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
AgentsToolsSessionChatAppend "$MDAT_SPAWN_SESSION_ID" "$1" magic-developer "$2" "$RIG_THREAD" console < "$RIG_BODY_FILE"
EOF
chmod +x "$rigTmp/append.sh"
export RIG_THREAD="$rigThread" RIG_BODY_FILE="$rigTmp/body"
cat > "$rigTmp/floor.sh" <<'EOF'
#!/usr/bin/env bash
set -u
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
AgentsToolsSessionChatFloor "$1" magic-developer > /dev/null 2>&1
printf 'blocks=[%s] eyes=[%s]\n' "${agentsSessionChatBlocks:-}" "${agentsSessionChatEyes:-}"
EOF
chmod +x "$rigTmp/floor.sh"
rigFloor(){ ## -- the chat read's own report of its blocks and their messages
	( cd "$rigWs" && env MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SESSION_THREAD="$rigThread" \
		bash "$rigTmp/floor.sh" "$rigSession" ) 2> /dev/null | tail -1
}
rigReset(){ printf 'read:magic-developer\t0\n' > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers" ; : > "$rigWs/.local/agents/sessions/$rigSession/session.chat" ; : > "$rigWs/.local/agents/sessions/$rigSession/session.chat.index" ; }

echo "-- 1. a message a person wrote is named by its channel and ts --"
rigReset
rigAppend human-owner "1793819900.000901" "RIG-EYES-GOOD"
rigAssert "the chat read reports the block it handed over, and the message as <channel>:<ts>" \
	"$( rigFloor )" "blocks=[1 ] eyes=[CRIGEYES01:1793819900.000901 ]"

echo "-- 2. the member's own message is not named, and a bot's is --"
rigReset
rigAppend magic-developer "1793819901.000901" "RIG-EYES-OWN"
rigAssert "a message the member wrote itself is never delivered to it, so the read names no block and no eyes target" \
	"$( rigFloor )" "blocks=[] eyes=[]"
rigReset
rigAppend some-bot "1793819902.000901" "RIG-EYES-BOT"
rigAssert "a bot's message is named all the same: the reaction names the message, not its author" \
	"$( rigFloor )" "blocks=[1 ] eyes=[CRIGEYES01:1793819902.000901 ]"

echo "-- 3. the chat probe carries the eye line its wait reads --"
rigReset
rigAppend human-owner "1793819903.000901" "RIG-EYES-PROBE"
cat > "$rigTmp/probe.sh" <<'EOF'
#!/usr/bin/env bash
set -u
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.BareName.include" > /dev/null 2>&1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitCore.include" > /dev/null 2>&1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitChat.include" > /dev/null 2>&1
probeOut="$1" probeSession="$2"
set --
agentsWaitCovered=""
AgentsWaitProbeChat magic-developer "$probeSession" "" "$probeOut" "" false ""
EOF
( cd "$rigWs" && env -u MDAT_SESSION_THREAD MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SESSION_THREAD="$rigThread" \
	bash "$rigTmp/probe.sh" "$rigTmp/now.$rigSession" "$rigSession" ) > "$rigTmp/probe.log" 2>&1 ; echo "probe rc=$?" >> "$rigTmp/probe.log"
rigAssert "the chat source's own sidecar holds the eye line for what it handed over" \
	"$( LC_ALL=C sed -n 's/^eye //p' "$rigTmp/now.$rigSession.newest" 2> /dev/null )" "CRIGEYES01:1793819903.000901"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the reads, for the reader:\n'
	printf '  sidecar: %s\n' "$( cat "$rigTmp/now.$rigSession.newest" 2> /dev/null | LC_ALL=C tr '\n' '|' )"
	printf '  probe log: %s\n' "$( cat "$rigTmp/probe.log" 2> /dev/null | LC_ALL=C tr '\n' '|' )"
	echo "⛔ WAIT CHAT EYES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CHAT_EYES: OK (%d assertions, offline)\n' "$rigPassCount"
