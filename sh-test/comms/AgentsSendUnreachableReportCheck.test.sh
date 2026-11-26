#!/usr/bin/env bash
## Behavioural check on sketch 5.4: the fault a run nobody can reach is, is reported by the send itself, not only by
## the report function. `AgentsToolsCommsSlackUnreachableReport` is called on every send, and the send's own output
## carries its line `SENT_MESSAGE_UNREACHABLE_MEMBERS=<member>...` when an addressee has no live run, and no such line
## when the addressee's run is alive. Held through the real send, with a Slack-shaped fake curl that opens no socket:
##   1. a send to a member with no live run posts the message, and names that member as unreachable
##   2. control: a send to a member whose run is alive posts the message, and names nobody
## Offline: every tree is the rig's own, and the fake curl answers every post and opens no socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSendUnreachableReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-member" "$rigTmp/scenario"
printf 'rig identity\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
printf 'rig identity\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
printf '%s\n' "$m" >> "$RIG_SCENARIO/calls.log"
case "$m" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.replies|conversations.history) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.000001","message":{"ts":"1700000001.000001","user":"URIGBOT01"}}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"

rigPass=0 rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }

## The tooling's own send, to the team channel, addressed to rig-member. Its whole output is the evidence.
rigSend(){ ## result file, the addressee word
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp/scenario" \
		bash "$rigFn" --intern-op-comms-slack-send-message magic-team magic-team --identity-bot --address-to "$1" \
		--from-stdin <<< "the rig post" ) > "$2" 2>&1
	printf '%s' "$?" > "$2.rc"
}
rigPosts(){ LC_ALL=C grep -c '^chat.postMessage$' "$rigTmp/scenario/calls.log" 2> /dev/null || : ; }
rigUnreach(){ LC_ALL=C grep -c '^SENT_MESSAGE_UNREACHABLE_MEMBERS=' "$1" 2> /dev/null || : ; }

echo "-- 1. a send to a member with no live run is reported --"
rigSend rig-member "$rigTmp/a"
rigAssert "the message is posted" "$( cat "$rigTmp/a.rc" ) $( rigPosts )" "0 1"
rigAssert "the addressee is named unreachable" "$( rigUnreach "$rigTmp/a" )" "1"
rigAssert "the fault line names the member" "$( LC_ALL=C grep -c '^SENT_MESSAGE_UNREACHABLE_MEMBERS=rig-member$' "$rigTmp/a" )" "1"

echo "-- 2. control: a send to a member whose run is alive names nobody --"
mkdir -p "$rigWs/.local/agents/spawned/rig-run"
printf -- '---\nsession-id: rig-run\nspawn-id: rig-run\nhost: %s\nstatus: spawn-started\nowner: rig-member\nrun-process: %s %s\n---\n\n# rig\n' "$( hostname -s 2> /dev/null || printf unknown )" "$$" "$( ps -o lstart= -p $$ 2>/dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; }' )" > "$rigWs/.local/agents/spawned/rig-run/rig-run.spawn.md"
rigSend rig-member "$rigTmp/b"
rigAssert "the message is still posted" "$( cat "$rigTmp/b.rc" ) $( rigPosts )" "0 2"
rigAssert "and no member is named unreachable" "$( rigUnreach "$rigTmp/b" )" "0"

if [ "$rigFail" -ne 0 ] ; then
	printf '⛔ SEND UNREACHABLE REPORT CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" >&2 ; exit 1
fi
printf 'SEND_UNREACHABLE_REPORT: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
