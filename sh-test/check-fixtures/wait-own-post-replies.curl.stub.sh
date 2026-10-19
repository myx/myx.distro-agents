#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsWaitOwnPostRepliesCheck.test.sh. Opens no socket. Answers from the
## scenario directory: a thread from replies.<channel>.<ts>.json, a conversation from history.<channel>.json
## (empty where the scenario has none), and logs every call as "<method> <channel> <ts>" in api.log.
set -u
cat > /dev/null
rigMethod="no-method"
rigChannel=""
rigTs=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2>/dev/null )" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
printf '%s %s %s\n' "$rigMethod" "$rigChannel" "$rigTs" >> "$RIG_SCENARIO/api.log"
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"URIGSELF1"}\n'
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "$rigChannel"
	;;
	conversations.replies)
		if [ -f "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json"
		else
			printf '{"ok":false,"error":"thread_not_found"}\n'
		fi
	;;
	conversations.history)
		if [ -f "$RIG_SCENARIO/history.$rigChannel.json" ] ; then
			cat "$RIG_SCENARIO/history.$rigChannel.json"
		else
			printf '{"ok":true,"messages":[],"has_more":false}\n'
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
