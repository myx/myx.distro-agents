#!/usr/bin/env bash
## Logs each Slack method with the token it was called under, and answers as that
## token's account. It opens no socket, and being first on PATH is the whole of this
## check's offline guarantee.
set -u
rigHeader="$( cat )"
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
done
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage) printf '{"ok":true,"channel":"DRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"%s"}}\n' "$rigUser" ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac