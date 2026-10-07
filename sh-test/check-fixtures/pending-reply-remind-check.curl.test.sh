#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsPendingReplyRemindCheck.test.sh. Logs each method and
## the token each call carried, keeps each posted body, and answers from the scenario
## directory. Opens no socket.
set -u
rigAuth="$( LC_ALL=C sed -n 's/^Authorization: Bearer //p' | head -1 )"
rigMethod="no-method"
rigBody=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
		@-) ;;
		@*) rigBody="${rigArg#@}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"URIGSELF1"}\n'
	;;
	chat.postMessage)
		if [ -f "$RIG_SCENARIO/post-refuse" ] ; then
			printf '{"ok":false,"error":"is_archived"}\n'
			exit 0
		fi
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		printf '%s\n' "$rigAuth" > "$RIG_SCENARIO/post.$rigPost.auth"
		rigChannel="$( sed -n 's/.*"channel":"\([A-Z0-9]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		printf '{"ok":true,"channel":"%s","ts":"1700000009.%06d","message":{"ts":"1700000009.%06d","user":"URIGSELF1"%s}}\n' \
			"${rigChannel:-CRIG00001}" "$rigPost" "$rigPost" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.open)
		printf '{"ok":true,"channel":{"id":"DRIGOWNER"}}\n'
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	chat.getPermalink)
		printf '{"ok":true,"permalink":"https:\\/\\/rigperma.slack.com\\/archives\\/CRIG00001\\/p1"}\n'
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
