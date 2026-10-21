#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsSessionChatFileCheck.test.sh. Opens no socket. Logs each call as
## "<method> <token>" in $RIG_SCENARIO/calls; keeps each posted payload in $RIG_SCENARIO/post.<n>; and, at each
## chat.postMessage, what the session chat file ($RIG_CHAT) held at that moment, as "<n> <line count>" in
## $RIG_SCENARIO/at-post, so a check can tell a message recorded before its post from one recorded after.
## A scenario can have posts answered with a Slack error, one error name per line in post-errors; a line `ok`
## is a post that goes through.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigBody="" rigChannel=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2>/dev/null )" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || rigBody="${rigArg#@}"
	rigPrevArg="$rigArg"
done
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		rigHeld=""
		[ ! -f "${RIG_CHAT:-/nonexistent}" ] || rigHeld="$( LC_ALL=C wc -l < "$RIG_CHAT" | LC_ALL=C tr -d ' ' )"
		printf '%s %s\n' "$rigPost" "$rigHeld" >> "$RIG_SCENARIO/at-post"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		if [ -s "$RIG_SCENARIO/post-errors" ] ; then
			rigError="$( head -1 "$RIG_SCENARIO/post-errors" )"
			tail -n +2 "$RIG_SCENARIO/post-errors" > "$RIG_SCENARIO/post-errors.next" && mv "$RIG_SCENARIO/post-errors.next" "$RIG_SCENARIO/post-errors"
			if [ "$rigError" != "ok" ] ; then
				printf '{"ok":false,"error":"%s"}\n' "$rigError"
				exit 0
			fi
		fi
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		printf '{"ok":true,"channel":"CRIG00001","ts":"1760000000.00010%s","message":{"ts":"1760000000.00010%s","user":"%s"%s}}\n' \
			"$rigPost" "$rigPost" "$rigUser" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	## A scenario with a file `history-empty` has conversations that are empty and rosters with none, instead of an error: a read that succeeds and finds
## nothing; with a file `history-body` a conversation reads as that file says (a Slack conversations.history answer).
	## A scenario can also have direct conversations: `dms.<token>.json`, the `channels` array of conversations.list for the account whose token ends so (none
	## for the others), and `history.<channel>.json`, the answer of conversations.history for that conversation; users.info answers one person.
	users.info) printf '{"ok":true,"user":{"id":"URIGFRIEND","name":"rig-friend","real_name":"Rig Friend","profile":{"display_name":"rigf"}}}\n' ;;
	conversations.history|conversations.list)
		if [ "$rigMethod" = "conversations.list" ] && [ -f "$RIG_SCENARIO/dms.$rigToken.json" ] ; then
			printf '{"ok":true,"channels":%s,"response_metadata":{"next_cursor":""}}\n' "$( cat "$RIG_SCENARIO/dms.$rigToken.json" )"
		elif [ "$rigMethod" = "conversations.history" ] && [ -n "$rigChannel" ] && [ -f "$RIG_SCENARIO/history.$rigChannel.json" ] ; then
			cat "$RIG_SCENARIO/history.$rigChannel.json"
		elif [ -f "$RIG_SCENARIO/history-body" ] && [ "$rigMethod" = "conversations.history" ] ; then
			cat "$RIG_SCENARIO/history-body"
		elif [ -f "$RIG_SCENARIO/history-empty" ] ; then
			printf '{"ok":true,"messages":[],"channels":[],"has_more":false}\n'
		else
			printf '{"ok":false,"error":"channel_not_found"}\n'
		fi
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
