#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsWorkDutyInputScanCheck.test.sh. Opens no socket. Answers from the scenario directory: a thread
## from replies.<channel>.<ts>.json, a conversation from history.<channel>.json (empty where the scenario has none), the direct
## conversations of the account from dms.json (a conversations.list `channels` array; none where the scenario has none), and logs
## every call as "<method> <channel> <ts>" in api.log.
## A search is answered by the token it is made with: search.<token>.json, else a refusal of the scope; it is logged as
## "search.messages <token> <query>" in search.log.
set -u
rigStdin="$( cat )"
rigMethod="no-method"
rigChannel=""
rigTs=""
rigQuery=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2>/dev/null )" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		query@*) rigQuery="$( cat "${rigArg#query@}" 2>/dev/null )" ;;
		query=*) rigQuery="${rigArg#query=}" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
printf '%s %s %s\n' "$rigMethod" "$rigChannel" "$rigTs" >> "$RIG_SCENARIO/api.log"
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"URIGSELF1","user":"rig-self"}\n'
	;;
	users.info)
		printf '{"ok":true,"user":{"id":"URIGFRIEND","name":"rig-friend","real_name":"Rig Friend","profile":{"display_name":"rigf"}}}\n'
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "$rigChannel"
	;;
	conversations.list)
		if [ -f "$RIG_SCENARIO/dms.json" ] ; then
			printf '{"ok":true,"channels":%s,"response_metadata":{"next_cursor":""}}\n' "$( cat "$RIG_SCENARIO/dms.json" )"
		else
			printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n'
		fi
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
	search.messages)
		rigToken="$( printf '%s\n' "$rigStdin" | sed -n 's/^Authorization: Bearer //p' | head -1 )"
		printf 'search.messages %s %s\n' "${rigToken:--}" "$rigQuery" >> "$RIG_SCENARIO/search.log"
		if [ -n "$rigToken" ] && [ -f "$RIG_SCENARIO/search.$rigToken.json" ] ; then
			cat "$RIG_SCENARIO/search.$rigToken.json"
		else
			printf '{"ok":false,"error":"missing_scope","needed":"search:read"}\n'
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
