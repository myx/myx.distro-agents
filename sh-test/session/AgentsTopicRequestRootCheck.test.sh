#!/usr/bin/env bash
## Behavioural check on the root edit of --set-session-topic (AgentsToolsThisSessionTopicSet, AgentsTools.ThisSession.include). The root of a
## session started for a person's message is that message, and the bot cannot edit it. Held, run and not read:
##   1. A ROOT THE BOT DID NOT POST (Slack answers cant_update_message or message_not_found) is said so on the OK line, and the title is set.
##   2. ANY OTHER ERROR of the edit is a loud warning that names the thread, and the title is set all the same.
##   3. A ROOT THE BOT POSTED is edited once, and nothing is said of it.
## Each case asserts its own outcome, so a failing case never hides the others. Offline: a fake curl answers chat.update from a file of the scenario.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPackage/sh-lib/session/AgentsTools.ThisSession.include" ] && [ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the this-session include is not at the origin this run resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTopicRequestRootCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigRecord="$rigWs/.local/agents/spawned/rigtopic/rigtopic.spawn.md"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/rigtopic" "$rigWs/.local/agents/spawned/rigtopic" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/scenario" \
	"$rigWs/.local/agents/members/magic-tester" || rigRefuse "cannot make the rig"
printf -- '---\nname: magic-tester\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-tester/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'CRIGREQ01:1700000000.000100\n' > "$rigWs/.local/agents/sessions/rigtopic/session.thread"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
## The fake curl of this check: logs each Slack method, and answers chat.update with the error a scenario file names, else ok.
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
[ -t 0 ] || cat > /dev/null
printf '%s\n' "$m" >> "$RIG_SCENARIO/calls"
case "$m" in
	chat.update)
		if [ -s "$RIG_SCENARIO/update-error" ] ; then printf '{"ok":false,"error":"%s"}\n' "$( head -1 "$RIG_SCENARIO/update-error" )"
		else printf '{"ok":true,"channel":"CRIGREQ01","ts":"1700000000.000100","text":"rig"}\n' ; fi
	;;
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a case could reach a socket"
rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigOut=""
rigTopic(){ ## the error chat.update answers (empty for none)
	printf -- '---\nsession-id: rigtopic\nspawn-id: rigtopic\nowner: magic-tester\nreports-to: human-owner\nstatus: spawn-started\n---\n\n# rig\n' > "$rigRecord"
	rm -f "$rigTmp/scenario/update-error" ; : > "$rigTmp/scenario/calls"
	[ -z "$1" ] || printf '%s\n' "$1" > "$rigTmp/scenario/update-error"
	rigOut="$( env -i MMDAPP="$rigWs" HOME="$rigTmp/home" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigTmp/scenario" MDSC_CMD=rig MDAT_SPAWN_SESSION_ID=rigtopic \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include" ;
			AgentsToolsThisSessionTopicSet --session-id rigtopic "the rig topic" ; printf "rc=%s\n" "$?"' 2>&1 )"
}
rigUpdates(){ LC_ALL=C grep -c '^chat.update$' "$rigTmp/scenario/calls" 2> /dev/null || : ; }
rigSaid(){ printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "$1" || : ; }
rigTitle(){ LC_ALL=C grep -c '^session-comment: the rig topic$' "$rigRecord" 2> /dev/null || : ; }
echo "-- 1. a root the bot did not post --"
rigTopic cant_update_message
rigAssert "the title is set, the call ends OK, and the OK line says the root is not the bot's post" \
	"$( rigTitle ):$( rigSaid 'OK: --set-session-topic: session rigtopic is about: the rig topic' ):$( rigSaid 'rc=0' ):$( rigSaid "the thread root is not the bot's post" )" "1:1:1:1"
rigAssert "the edit was tried exactly once" "$( rigUpdates )" "1"
rigTopic message_not_found
rigAssert "message_not_found is said the same way, and the title is set" "$( rigTitle ):$( rigSaid "the thread root is not the bot's post" )" "1:1"
echo "-- 2. any other error is loud --"
rigTopic rig_other_error
rigAssert "a warning names the thread, the OK line stays plain, and the title is set" \
	"$( rigTitle ):$( rigSaid 'was not edited, and the title is set' ):$( rigSaid 'the thread root of rigtopic was not edited' ):$( rigSaid "the thread root is not the bot's post" )" "1:1:1:0"
echo "-- 3. a root the bot posted --"
rigTopic ""
rigAssert "the root is edited once, and nothing is said of it" "$( rigUpdates ):$( rigSaid 'thread root' ):$( rigTitle )" "1:0:1"
if [ "$rigFail" -ne 0 ] ; then echo "⛔ TOPIC REQUEST ROOT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1 ; fi
printf 'TOPIC_REQUEST_ROOT: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
