#!/usr/bin/env bash
## The fake `curl` for AgentsSlackClientPersonaCheck. It opens no socket, and being first on PATH is that check's whole
## offline guarantee. It logs each Slack method with the token it was called under (calls), appends every posted body
## (bodies), and answers as that token's account: a bot token is URIGBOT01, any other token is URIG plus its last word.
## $RIG_SCENARIO/post-answers holds one answer per line for successive chat.postMessage calls: `ok`, or a Slack error
## code such as channel_not_found; an empty file means ok every time. Other methods answer ok:false.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || { cat "${rigArg#@}" ; echo ; } >> "$RIG_SCENARIO/bodies"
	rigPrevArg="$rigArg"
done
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage)
		rigAnswer=ok
		if [ -s "$RIG_SCENARIO/post-answers" ] ; then
			rigAnswer="$( head -1 "$RIG_SCENARIO/post-answers" )"
			tail -n +2 "$RIG_SCENARIO/post-answers" > "$RIG_SCENARIO/post-answers.next" && mv "$RIG_SCENARIO/post-answers.next" "$RIG_SCENARIO/post-answers"
		fi
		if [ "$rigAnswer" = ok ] || [ -z "$rigAnswer" ] ; then
			printf '{"ok":true,"channel":"DRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"%s"}}\n' "$rigUser"
		else
			printf '{"ok":false,"error":"%s"}\n' "$rigAnswer"
		fi
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
exit 0
