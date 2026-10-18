#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsHarnessAskCheck.test.sh. Logs each method, keeps
## each posted body, and answers from the scenario directory. Opens no socket.
set -u
cat > /dev/null
rigMethod="no-method"
rigBody=""
rigTs=""
rigReactTs=""
rigReactName=""
for rigArg in "$@" ; do
	case "$rigArg" in
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		timestamp@*) rigReactTs="$( cat "${rigArg#timestamp@}" 2>/dev/null )" ;;
		name@*) rigReactName="$( cat "${rigArg#name@}" 2>/dev/null )" ;;
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
			## A permanent refusal, so the send gives up at once rather than backing off.
			printf '{"ok":false,"error":"is_archived"}\n'
			exit 0
		fi
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		## A scenario can ask for the message object to nest another user ahead of its own, or to name none.
		rigUserField='"user":"URIGSELF1"'
		[ ! -f "$RIG_SCENARIO/post-nested" ] || rigUserField='"blocks":[{"type":"rich_text","user":"URIGFAKE"}],"bot_profile":{"id":"BRIG1"},"user":"URIGSELF1"'
		[ ! -f "$RIG_SCENARIO/post-nouser" ] || rigUserField='"bot_id":"BRIG1"'
		printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.00010%s","message":{"ts":"1700000001.00010%s",%s%s}}\n' \
			"$rigPost" "$rigPost" "$rigUserField" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	conversations.replies)
		## A thread of its own answers from replies.<ts>.json; every other thread shares replies.json.
		if [ -n "$rigTs" ] && [ -f "$RIG_SCENARIO/replies.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigTs.json"
		elif [ -f "$RIG_SCENARIO/replies.json" ] ; then
			cat "$RIG_SCENARIO/replies.json"
		else
			printf '{"ok":false,"error":"rig_no_replies"}\n'
		fi
	;;
	reactions.add)
		## Each reaction asked for, as "<ts> <name>"; a scenario can have every one refused.
		printf '%s %s\n' "$rigReactTs" "$rigReactName" >> "$RIG_SCENARIO/reactions"
		if [ -f "$RIG_SCENARIO/react-refuse" ] ; then
			printf '{"ok":false,"error":"missing_scope"}\n'
		else
			printf '{"ok":true}\n'
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
