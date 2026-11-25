#!/usr/bin/env bash
## Slack-shaped fake curl for the request-thread checks. It answers a post as Slack does, with a ts of its own, and keeps each body in
## $RIG_SCENARIO/post.<n> and one line in $RIG_SCENARIO/posts.log: `<n> <conversation> <thread ts, or top> <what>`.
## A scenario sets files of $RIG_SCENARIO, each read when the call is made:
##   post-errors   one Slack error name for each chat.postMessage, taken from the top, where `ok` lets one through
##   topless       an answer to a reply names no thread_ts, as a post that landed at the top of the conversation does
##   reply-root    the thread_ts an answer to a reply names, in place of the thread the post asked for
##   omit-thread   an answer names no thread_ts although the post is in its thread, as a workspace that leaves the field out does
##   delete-error  the error chat.delete answers
##   update-error  the error chat.update answers
## conversations.replies answers with the post named by `oldest` only where that post landed in a thread (landed.<n> of $RIG_SCENARIO).
## chat.delete is logged as `<conversation> <ts>` in $RIG_SCENARIO/deletes, and drops the post from posts.log, as Slack removes it.
## Every call is one line in $RIG_SCENARIO/calls: `<method> <token>`. It opens no socket.
set -u
rigHeader="$( cat )"
rigToken="${rigHeader#Authorization: Bearer }"
rigMethod="no-method" rigBody="" rigPrevArg="" rigFormChannel="" rigFormTs="" rigFormOldest=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
	case "$rigPrevArg" in
		--data-binary) rigBody="${rigArg#@}" ;;
		--data-urlencode)
			case "$rigArg" in
				channel@*) rigFormChannel="$( cat "${rigArg#*@}" )" ;;
				ts@*) rigFormTs="$( cat "${rigArg#*@}" )" ;;
				oldest@*) rigFormOldest="$( cat "${rigArg#*@}" )" ;;
			esac
		;;
	esac
	rigPrevArg="$rigArg"
done
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage)
		if [ -s "$RIG_SCENARIO/post-errors" ] ; then
			rigError="$( head -1 "$RIG_SCENARIO/post-errors" )"
			tail -n +2 "$RIG_SCENARIO/post-errors" > "$RIG_SCENARIO/post-errors.next" && mv "$RIG_SCENARIO/post-errors.next" "$RIG_SCENARIO/post-errors"
			if [ "$rigError" != "ok" ] ; then printf '{"ok":false,"error":"%s"}\n' "$rigError" ; exit 0 ; fi
		fi
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2> /dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigChannel="$( LC_ALL=C sed -n 's/^{"channel":"\([^"]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigWhat="$( LC_ALL=C sed -n 's/.*"tracking":"\([a-z-]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigTs="$( printf '1700000001.%06d' "$(( rigPost * 100 ))" )"
		printf '%s %s %s %s\n' "$rigPost" "$rigChannel" "${rigThread:-top}" "${rigWhat:-message}" >> "$RIG_SCENARIO/posts.log"
		[ ! -f "$RIG_SCENARIO/topless" ] || rigThread=""
		[ -z "$rigThread" ] || [ ! -s "$RIG_SCENARIO/reply-root" ] || rigThread="$( head -1 "$RIG_SCENARIO/reply-root" )"
		printf '%s' "${rigThread:-top}" > "$RIG_SCENARIO/landed.$rigPost"
		[ ! -f "$RIG_SCENARIO/omit-thread" ] || rigThread=""
		printf '{"ok":true,"channel":"%s","ts":"%s","message":{"ts":"%s","user":"URIGBOT01"%s}}\n' "$rigChannel" "$rigTs" "$rigTs" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.replies)
		rigReplyOldest="${rigFormOldest:-0.000000}"
		rigReplyPost=$(( 10#${rigReplyOldest#*.} / 100 ))
		if [ "$( cat "$RIG_SCENARIO/landed.$rigReplyPost" 2> /dev/null || echo top )" != top ] ; then
			printf '{"ok":true,"messages":[{"ts":"%s"},{"ts":"%s"}]}\n' "$rigFormTs" "$rigFormOldest"
		else
			printf '{"ok":true,"messages":[{"ts":"%s"}]}\n' "$rigFormTs"
		fi
	;;
	chat.update)
		if [ -s "$RIG_SCENARIO/update-error" ] ; then printf '{"ok":false,"error":"%s"}\n' "$( head -1 "$RIG_SCENARIO/update-error" )" ; else printf '{"ok":true}\n' ; fi
	;;
	chat.delete)
		printf '%s %s\n' "$rigFormChannel" "$rigFormTs" >> "$RIG_SCENARIO/deletes"
		if [ -s "$RIG_SCENARIO/delete-error" ] ; then printf '{"ok":false,"error":"%s"}\n' "$( head -1 "$RIG_SCENARIO/delete-error" )" ; exit 0 ; fi
		rigDrop=$(( 10#${rigFormTs#*.} / 100 ))
		LC_ALL=C awk -v drop="$rigDrop" -v channel="$rigFormChannel" '$1 == drop && $2 == channel { next ; } { print ; }' "$RIG_SCENARIO/posts.log" > "$RIG_SCENARIO/posts.log.next" \
			&& mv "$RIG_SCENARIO/posts.log.next" "$RIG_SCENARIO/posts.log"
		printf '{"ok":true}\n'
	;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIGTEAM1","is_im":false,"is_mpim":false}}\n' ;;
	reactions.add|conversations.join) printf '{"ok":true}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
