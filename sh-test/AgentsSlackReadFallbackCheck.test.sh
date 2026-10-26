#!/usr/bin/env bash
## Behavioural check on the identity of a Slack READ: a read takes the fallback a send takes. A send of a member holding its own user token to a conversation that
## identity cannot reach is posted under the bot (AgentsTools.MemberCommsSlack.include, --slack-send-message); what it posted is read back by
## --slack-read (and so by Wait and by the readback of an escalation, which read through it) under the user token first and, when Slack says
## channel_not_found or not_in_channel, once more under the bot. Held:
##   1. the send falls back to the bot, and the read of the thread it posted is then answered: the replies of the owner come back, the calls are the user's and then the bot's
##   2. the same for a whole conversation (a top-level message of a direct conversation)
##   3. a conversation the user identity can reach is read once, under the user token, and the bot is not asked
##   4. --identity-bot asked is final: one call, the bot's; a conversation neither identity reaches ends 1 with Slack's error, after the two calls
##   (fails without the fix: section 1 reads a thread the user token cannot reach, which ended 1 on channel_not_found before the fallback)
## A fake curl first on PATH answers by token and method; no request leaves the rig.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackReadFallbackCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin"
## Answers by the token and the method. The conversation DRIG00001 is the bot's own: the user token gets channel_not_found for it. DUSER0001 is the user's too.
## DNONE0001 is reached by neither.
cat > "$rigTmp/bin/curl" <<- 'EOF'
	#!/usr/bin/env bash
	set -u
	rigHeader="$( cat )"
	rigMethod="" rigChannel="" rigPrev=""
	for rigArg in "$@" ; do
		case "$rigArg" in
			https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
			channel@*) rigChannel="$( cat "${rigArg#channel@}" )" ;;
			channel=*) rigChannel="${rigArg#channel=}" ;;
		esac
		if [ "$rigPrev" = "--data-binary" ] ; then rigChannel="$( sed -n 's/^.*"channel":"\([^"]*\)".*$/\1/p' "${rigArg#@}" | head -1 )" ; fi
		rigPrev="$rigArg"
	done
	printf '%s\n' "$*" >> "$RIG_SCENARIO/args"
	rigToken="${rigHeader#Authorization: Bearer }"
	rigWho=user ; case "$rigToken" in rig-bot-*) rigWho=bot ;; esac
	printf '%s %s %s\n' "$rigMethod" "$rigWho" "$rigChannel" >> "$RIG_SCENARIO/calls"
	case "$rigMethod" in
		auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIG%s"}\n' "$rigWho" ;;
		conversations.info)
			case "$rigChannel:$rigWho" in
				DRIG00001:bot|DUSER0001:*) printf '{"ok":true,"channel":{"id":"%s"}}\n' "$rigChannel" ;;
				*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
			esac
		;;
		chat.postMessage)
			if [ "$rigWho" = user ] && { [ "$rigChannel" = "DRIG00001" ] || [ "$rigChannel" = "DOTHER0001" ] ; } ; then printf '{"ok":false,"error":"channel_not_found"}\n'
			else printf '{"ok":true,"channel":"%s","ts":"1700000000.000100","message":{"ts":"1700000000.000100","user":"URIG%s"}}\n' "$rigChannel" "$rigWho" ; fi
		;;
		conversations.replies|conversations.history)
			case "$rigChannel:$rigWho" in
				DRIG00001:bot|DUSER0001:user|DUSER0001:bot)
					printf '{"ok":true,"has_more":false,"messages":[{"type":"message","user":"URIGOWNER","text":"the question","ts":"1700000000.000100"},{"type":"message","user":"URIGOWNER","text":"RIG-OWNER-REPLY","ts":"1700000001.000200","thread_ts":"1700000000.000100"}]}\n'
				;;
				*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
			esac
		;;
		*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
	esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRc=0
rigRun(){ ## environment words..., then the tool arguments after `--` -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err, calls in calls
	local runEnv=()
	while [ "$1" != "--" ] ; do runEnv+=( "$1" ) ; shift ; done
	shift
	: > "$rigTmp/calls" ; rigRc=0
	( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" ${runEnv[@]+"${runEnv[@]}"} bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigCalls(){ ## method -- the identities that method was called under, in order, comma-separated
	LC_ALL=C awk -v want="$1" '$1 == want { printf "%s%s", sep, $2 ; sep = "," }' "$rigTmp/calls"
}

echo "-- 1. a send that fell back to the bot, then a read of its thread --"
rigRun -- --slack-send-message magic-coordinator DRIG00001 "RIG-QUESTION"
rigAssert "the send: the user identity cannot reach the conversation, so it is posted under the bot" "$rigRc $( rigCalls chat.postMessage )" "0 user,bot"
rigRun -- --slack-read magic-coordinator DRIG00001:1700000000.000100 --thread
rigAssert "the read of that thread: answered, with the owner's reply in it" "$rigRc $( LC_ALL=C grep -c 'RIG-OWNER-REPLY' "$rigTmp/out" )" "0 1"
rigAssert "it asked as the user first and then as the bot, once each" "$( rigCalls conversations.replies )" "user,bot"
rigAssert "and said so, on standard error" "$( LC_ALL=C grep -c 'reading once under bot identity' "$rigTmp/err" )" "1"
rigRun -- --intern-op-comms-slack-read magic-coordinator DRIG00001:1700000000.000100 --thread
rigAssert "the tooling's own form of the read (what Wait and the readback call) is the same" "$rigRc $( LC_ALL=C grep -c 'RIG-OWNER-REPLY' "$rigTmp/out" ) $( rigCalls conversations.replies )" "0 1 user,bot"

echo "-- 1b. a reply, whose thread the bot cannot see --"
rigRun -- --slack-send-message magic-coordinator DRIG00001:1700000000.000100 "RIG-REPLY"
rigAssert "a reply into a thread the bot sees: the user cannot reach the conversation, the bot posts it" "$rigRc $( rigCalls chat.postMessage )" "0 user,bot"
rigRun -- --slack-send-message magic-coordinator DOTHER0001:1700000000.000100 "RIG-REPLY"
rigAssert "a reply into a thread whose parent is in another conversation than the bot can see: an error, and nothing posted under the bot" "$( [ "$rigRc" != 0 ] && echo failed ) $( rigCalls chat.postMessage ) $( LC_ALL=C grep -c 'NOT posted\|nothing was posted' "$rigTmp/err" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "said" : "silent" }' )" "failed user said"

echo "-- 2. a whole conversation --"
rigRun -- --slack-read magic-coordinator DRIG00001
rigAssert "a conversation the user cannot reach is read under the bot: the owner's top-level messages come back" "$rigRc $( LC_ALL=C grep -c 'RIG-OWNER-REPLY' "$rigTmp/out" ) $( rigCalls conversations.history )" "0 1 user,bot"

echo "-- 3. a conversation the user reaches --"
rigRun -- --slack-read magic-coordinator DUSER0001:1700000000.000100 --thread
rigAssert "read once under the user token; the bot is not asked" "$rigRc $( LC_ALL=C grep -c 'RIG-OWNER-REPLY' "$rigTmp/out" ) $( rigCalls conversations.replies )" "0 1 user"

echo "-- 4. --identity-bot asked, and a conversation no identity reaches --"
rigRun -- --slack-read magic-coordinator DRIG00001:1700000000.000100 --thread --identity-bot
rigAssert "--identity-bot is final: one call, the bot's" "$rigRc $( rigCalls conversations.replies )" "0 bot"
rigRun -- --slack-read magic-coordinator DNONE0001:1700000000.000100 --thread
rigAssert "neither identity reaches it: both are asked, once, and the exit is 1 with Slack's error" "$rigRc $( rigCalls conversations.replies ) $( LC_ALL=C grep -c 'channel_not_found' "$rigTmp/err" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "said" : "silent" }' )" "1 user,bot said"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK READ FALLBACK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_READ_FALLBACK: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
