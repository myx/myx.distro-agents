#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsHarnessEscalationEdgeCheck.test.sh. Like the ask
## fixture, but each post claims its number atomically, so concurrent posts never share
## one, and a scenario holding post-delay-first has its first post answered a second late.
set -u
cat > /dev/null
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
		rigPost=1
		while ! mkdir "$RIG_SCENARIO/post.claim.$rigPost" 2>/dev/null ; do rigPost=$(( rigPost + 1 )) ; done
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		[ "$rigPost" != 1 ] || [ ! -f "$RIG_SCENARIO/post-delay-first" ] || sleep 1
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.00010%s","message":{"ts":"1700000001.00010%s","user":"URIGSELF1"%s}}\n' \
			"$rigPost" "$rigPost" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	conversations.replies)
		if [ -f "$RIG_SCENARIO/replies.json" ] ; then
			cat "$RIG_SCENARIO/replies.json"
		else
			printf '{"ok":false,"error":"rig_no_replies"}\n'
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
