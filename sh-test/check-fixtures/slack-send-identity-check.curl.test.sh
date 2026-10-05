#!/usr/bin/env bash
## Logs each Slack method with the token it was called under, and answers as that
## token's account. It opens no socket, and being first on PATH is the whole of this
## check's offline guarantee. A --data-binary body is appended to $RIG_SCENARIO/bodies.
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
## A scenario can have successive posts fail at the transport, one curl exit code per line.
if [ "$rigMethod" = "chat.postMessage" ] && [ -s "$RIG_SCENARIO/post-exits" ] ; then
	rigExit="$( head -1 "$RIG_SCENARIO/post-exits" )"
	tail -n +2 "$RIG_SCENARIO/post-exits" > "$RIG_SCENARIO/post-exits.next" && mv "$RIG_SCENARIO/post-exits.next" "$RIG_SCENARIO/post-exits"
	if [ "$rigExit" != "0" ] ; then
		echo "curl: ($rigExit) rig transport failure"
		exit "$rigExit"
	fi
fi
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage) printf '{"ok":true,"channel":"DRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"%s"}}\n' "$rigUser" ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac