#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsChangeApprovalCheck.test.sh. Logs each method with the
## token it was called under, keeps each posted body, each reaction placed or taken off, each
## edit and each deleted message, and answers as that token's account. A thread read answers
## from the scenario directory: replies.<ts>.json for the thread of that ts, else that thread
## with its first message alone. A scenario that holds a file `post.fail` has every post
## refused. Opens no socket.
set -u
rigHeader="$( cat )"
rigToken="${rigHeader#Authorization: Bearer }"
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
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"%s"}\n' "$rigUser"
	;;
	chat.postMessage)
		if [ -f "$RIG_SCENARIO/post.fail" ] ; then
			printf '{"ok":false,"error":"rig_post_refused"}\n'
			exit 0
		fi
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		printf '%s\n' "$rigToken" > "$RIG_SCENARIO/post.$rigPost.token"
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		## The n-th post is 1700000001.<n>01 in six digits, so a scenario can place a reply between two posts.
		rigPostTs="$( printf '1700000001.%06d' "$(( rigPost * 100 + 1 ))" )"
		printf '{"ok":true,"channel":"CRIG00001","ts":"%s","message":{"ts":"%s","user":"%s"%s}}\n' \
			"$rigPostTs" "$rigPostTs" "$rigUser" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	conversations.replies)
		if [ -n "$rigTs" ] && [ -f "$RIG_SCENARIO/replies.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigTs.json"
		else
			printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"first"}],"has_more":false}\n' "${rigTs:-1700000000.000001}"
		fi
	;;
	reactions.add)
		printf '%s %s\n' "$rigReactTs" "$rigReactName" >> "$RIG_SCENARIO/reactions"
		printf '{"ok":true}\n'
	;;
	reactions.remove)
		printf '%s %s\n' "$rigReactTs" "$rigReactName" >> "$RIG_SCENARIO/reactions.removed"
		printf '{"ok":true}\n'
	;;
	chat.update)
		## An edit comes as the send's own JSON body, naming the message it edits.
		[ -n "$rigTs" ] || rigTs="$( sed -n 's/.*","ts":"\([0-9.]*\)","blocks":.*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		[ -n "$rigTs" ] || rigTs="$( sed -n 's/.*","ts":"\([0-9.]*\)"}$/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		printf '%s\n' "$rigTs" >> "$RIG_SCENARIO/edited"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/edit.$rigTs"
		printf '{"ok":true,"channel":"CRIG00001","ts":"%s","message":{"ts":"%s","user":"URIGBOT01"}}\n' "$rigTs" "$rigTs"
	;;
	chat.delete)
		printf '%s\n' "$rigTs" >> "$RIG_SCENARIO/deleted"
		printf '{"ok":true,"channel":"CRIG00001","ts":"%s"}\n' "$rigTs"
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
