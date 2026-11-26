#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsOwedRepliesThreadClearCheck.test.sh. Opens no socket. Answers as Slack
## does on the point the check turns on: a post made with `thread_ts` set to a message INSIDE a thread
## comes back with `message.thread_ts` naming that thread's ROOT, never the message posted under. Slack
## flattens a reply to its thread root, and that flattening is the whole subject of the check.
## The root ts is read from $RIG_THREAD_ROOT, so the check says which thread it stands for.
## Logs each post as `<method> <channel> <posted thread_ts> <post number>` in $RIG_SCENARIO/calls and keeps
## the payload in $RIG_SCENARIO/post.<n>. Writes the response-headers file the shared Slack call asks for.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigBody="" rigHeaderFile="" rigPostThread="" rigTs=""
while [ $# -gt 0 ] ; do
	rigArg="$1"
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || case "$rigArg" in @*) rigBody="${rigArg#@}" ;; esac
	[ "$rigPrevArg" != "--data-urlencode" ] || case "$rigArg" in ts@*) rigTs="$( cat "${rigArg#ts@}" 2> /dev/null )" ;; esac
	[ "$rigPrevArg" != "-D" ] || rigHeaderFile="$rigArg"
	rigPrevArg="$rigArg"
	shift
done
if [ -n "$rigHeaderFile" ] ; then
	printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' > "$rigHeaderFile" 2> /dev/null || :
fi
case "$rigMethod" in
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2> /dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigChannel="$( LC_ALL=C sed -n 's/.*"channel":"\([^"]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		rigPostThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([^"]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		case "$rigChannel" in ''|-*) rigChannel="-" ;; esac
		case "$rigPostThread" in ''|-*) rigPostThread="-" ;; esac
		printf '%s %s %s %s\n' "$rigMethod" "$rigChannel" "$rigPostThread" "$rigPost" >> "$RIG_SCENARIO/calls"
		## THE FLATTENING: a post under a message inside a thread reports the thread's root, never the message.
		if [ "$rigPostThread" != "-" ] ; then
			printf '{"ok":true,"channel":"%s","ts":"1760000002.%06d","message":{"ts":"1760000002.%06d","user":"URIGBOT01","thread_ts":"%s"}}\n' \
				"$rigChannel" "$rigPost" "$rigPost" "${RIG_THREAD_ROOT:?}"
		else
			printf '{"ok":true,"channel":"%s","ts":"1760000002.%06d","message":{"ts":"1760000002.%06d","user":"URIGBOT01"}}\n' \
				"$rigChannel" "$rigPost" "$rigPost"
		fi
	;;
	conversations.replies)
		## The send checks the message it answers exists: echo the ts it asked for, as a bot message,
		## so no person is inferred as the reply's addressee.
		printf '%s %s - -\n' "$rigMethod" "${rigChannel:--}" >> "$RIG_SCENARIO/calls"
		printf '{"ok":true,"messages":[{"ts":"%s","bot_id":"BRIG1","subtype":"bot_message"}]}\n' "${rigTs:-1760000000.000000}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
case "$rigMethod" in
	chat.postMessage|conversations.replies) ;;
	*) printf '%s - - -\n' "${rigMethod:-unknown}" >> "$RIG_SCENARIO/calls" ;;
esac
exit 0
