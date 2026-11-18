#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsHarnessAskTaskCheck.test.sh: logs each method it is called with, and answers a post with a fixed
## ts after two seconds, so a call that returned as a task can be told from one that waited in place. Opens no socket.
set -u
cat > /dev/null
rigMethod="no-method"
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "${RIG_CURL_LOG:?}"
case "$rigMethod" in
	chat.postMessage) sleep 2 ; printf '{"ok":true,"channel":"CRIG00001","ts":"1700000009.000101","message":{"ts":"1700000009.000101","user":"URIGSELF1"}}\n' ;;
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
