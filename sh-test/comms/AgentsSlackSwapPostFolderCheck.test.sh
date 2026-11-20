#!/usr/bin/env bash
## Behavioural check on the FOLDER a post is stored in: what the send stored and the link to its Slack ts must sit in the ONE folder.
## The fault held here is not the identity swap. The store resolves its folder with `threadTs` and the link resolves it again with the
## ts Slack answered, so the two differ for every post that is not already a reply. Measured 2026-11-20 06:52 +0200 on a post the user
## identity reaches, so no swap happens: the store line lands in `slack-CRIG00001` and the link line in
## `slack-CRIG00001-1700000000.000100`. A swapped post carries the same split, which is what the report described.
##   1. the send completes, and the swap case falls back to the bot as it is supposed to
##   2. the post's own stored line is in the folder the send resolved
##   3. that one folder holds both the line and its link
##   4. the link line sits there, its first field the ts Slack gave
##   5. no folder named by the second resolve holds a line of this post
## A fake curl first on PATH answers by token and method; no request leaves the rig.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackSwapPostFolderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin"
## THE CAUSE IS A SECOND RESOLVE WITH A DIFFERENT THREAD. The store asks `AgentsToolsCommsCacheSlackDir` with `threadTs`, which is empty
## for a post that is not already a reply. The link asks it again with `sentThreadTs`, which is the ts Slack answered. So the two folders
## differ, whatever identity sent the post. The fix keeps the store's own folder for the link.
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
	rigToken="${rigHeader#Authorization: Bearer }"
	rigWho=user ; case "$rigToken" in rig-bot-*) rigWho=bot ;; esac
	printf '%s %s %s\n' "$rigMethod" "$rigWho" "$rigChannel" >> "$RIG_SCENARIO/calls"
	case "$rigMethod" in
		auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGUSER1"}\n' ;;
		conversations.info)
			case "$rigChannel" in
				CRIG00001) printf '{"ok":true,"channel":{"id":"CRIG00001"}}\n' ;;
				*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
			esac
		;;
		conversations.replies)
			case "$rigWho:$rigChannel" in
				bot:DRIG00001) printf '{"ok":true,"has_more":false,"messages":[{"type":"message","user":"URIGOWNER","text":"the question","ts":"1700000000.000100","thread_ts":"1700000000.000100"}]}\n' ;;
				*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
			esac
		;;
		chat.postMessage)
			if [ "$rigWho" = user ] ; then printf '{"ok":false,"error":"channel_not_found"}\n'
			else printf '{"ok":true,"channel":"%s","ts":"1700000000.000100","message":{"ts":"1700000000.000100","user":"URIGBOT1"}}\n' "$rigChannel" ; fi
		;;
		*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
	esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The user account is pinned, so the folders are `slack-URIGUSER1-DRIG00001-<thread ts>` (the line) and `slack-bot-DRIG00001-<thread ts>` (the link, wrongly).
## A reply's folder carries the thread ts, which `AgentsToolsCommsCacheSlackDir` adds as its fourth argument.
mkdir -p "$rigWs/.local/cache/comms/slack"
printf '%s %s\n' "$( date +%s )" 'URIGUSER1' > "$rigWs/.local/cache/comms/slack/.user-id-magic-coordinator.txt"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRc=0
rigRun(){ ## the tool arguments -- one dispatcher call from the rig workspace; rc in rigRc, calls in calls
	: > "$rigTmp/calls" ; rigRc=0
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_THREAD RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigCalls(){ ## method -- the identities that method was called under, in order, comma-separated
	LC_ALL=C awk -v want="$1" '$1 == want { printf "%s%s", sep, $2 ; sep = "," ; }' "$rigTmp/calls"
}
rigUserDir="$rigWs/.local/cache/comms/slack/slack-CRIG00001"
rigWrongDir="$rigWs/.local/cache/comms/slack/slack-CRIG00001-1700000000.000100"
rigLines(){ ## folder -- how many message lines it holds across its month folders
	[ -d "$1" ] || { printf '0\n' ; return 0 ; }
	cat "$1"/[0-9][0-9][0-9][0-9][0-9][0-9]/messages.txt 2> /dev/null | LC_ALL=C grep -c . || :
}

echo "-- 1. a post into a channel the user identity cannot reach --"
rigRun --slack-send-message --team-member magic-coordinator CRIG00001 "RIG-SWAP-REPLY"
rigAssert "control: the send swaps to the bot, as the swap exists to do" "$rigRc $( rigCalls chat.postMessage )" "0 user,bot"
rigAssert "control: the folder the send resolved holds the post's own line already" "$( [ -z "$( LC_ALL=C grep -rl 'RIG-SWAP-REPLY' "$rigUserDir" 2> /dev/null | head -1 )" ] && echo absent || echo present )" "present"
rigAssert "that one folder holds both the line and its link, two lines together" "$( rigLines "$rigUserDir" )" "2"
rigAssert "the link line, whose first field is the ts Slack gave, sits in that same folder" "$( cat "$rigUserDir"/[0-9][0-9][0-9][0-9][0-9][0-9]/messages.txt 2> /dev/null | LC_ALL=C grep -c '^1700000000\.000100 |' || : )" "1"
rigAssert "and no folder named by the second resolve holds a line of this post" "$( LC_ALL=C grep -rc 'RIG-SWAP-REPLY' "$rigWrongDir" 2> /dev/null | LC_ALL=C awk -F: '{ n += $2 ; } END { print n + 0 ; }' )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK SWAP POST FOLDER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SWAP_POST_FOLDER: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
