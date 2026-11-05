#!/usr/bin/env bash
## Behavioural check on S5.4: a message addressed to a member with no live run is reported as such where it is sent,
## and the message is posted all the same.
## The report is one line, `SENT_MESSAGE_UNREACHABLE_MEMBERS=<member>...`, and it names the addressees only, never
## the sender. Held here, with a Slack-shaped fake curl that answers every post and opens no socket:
##   1. an addressee with no spawn record at all is named.
##   2. control: an addressee whose run is alive is not named.
##   3. control: the sending member is never named, however it was addressed.
## Red before S5.4: the line never appeared, and an addressee nobody could reach was silent.
## Offline: every tree is the rig's own, and the fake curl opens no socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigSend="$rigPkg/sh-lib/comms/AgentsTools.InternOpCommsSlackSend.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigSend" ] || rigRefuse "the send include is not at the origin: $rigSend"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSendUnreachableCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigTmp/bin" "$rigTmp/home"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
cat > /dev/null
printf '{"ok":true,"ts":"1793659000.000001","channel":"CRIG00001"}'
exit 0
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }

## The report, as the send path calls it: its standard output is the line.
rigReport(){ ## addressees, sender
	env -i MMDAPP="$rigWs" HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsCommsSlackUnreachableReport "$2" "$3"' rig "$rigSend" "$1" "$2" 2>&1
}

echo "-- 1. an addressee with no spawn record is named (S5.4) --"
rigAssert "the unreachable member is named"  "$( rigReport magic-tester magic-coordinator )" "SENT_MESSAGE_UNREACHABLE_MEMBERS=magic-tester"

echo "-- 2. control: an addressee whose run is alive is not named --"
mkdir -p "$rigWs/.local/agents/spawned/rig-run"
printf -- '---\nsession-id: rig-run\nspawn-id: rig-run\nhost: %s\nstatus: spawn-started\nowner: magic-tester\nrun-process: %s %s\n---\n\n# rig\n' "$( hostname -s 2> /dev/null || printf unknown )" "$$" "$( ps -o lstart= -p $$ 2>/dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; }' )" > "$rigWs/.local/agents/spawned/rig-run/rig-run.spawn.md"
rigAssert "a live carry says nothing"        "$( rigReport magic-tester magic-coordinator )" ""

echo "-- 3. control: the sender is never named --"
rigAssert "its own name is left out"         "$( rigReport 'magic-coordinator magic-tester' magic-coordinator )" ""

if [ "$rigFail" -ne 0 ] ; then
	printf '⛔ SEND UNREACHABLE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" >&2 ; exit 1
fi
printf 'SEND_UNREACHABLE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
