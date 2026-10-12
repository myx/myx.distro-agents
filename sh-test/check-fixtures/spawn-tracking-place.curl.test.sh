#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsSpawnTrackingPlaceCheck.test.sh. It answers a post as Slack
## does: in the conversation the post names, with a ts of its own, so a thread it opens is
## told apart from every other. Keeps each posted body ($RIG_SCENARIO/post.<n>) and one line
## for it in $RIG_SCENARIO/posts.log: `<n> <conversation> <thread ts, or top> <what>`, where
## <what> is the tracking kind of a tracking post, `session-root` for the root of a session
## thread, and `message` for a member's message. Opens no socket.
set -u
rigHeader="$( cat )"
rigToken="${rigHeader#Authorization: Bearer }"
rigMethod="no-method" rigBody="" rigPrevArg=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || rigBody="${rigArg#@}"
	rigPrevArg="$rigArg"
done
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigChannel="$( LC_ALL=C sed -n 's/^{"channel":"\([^"]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigWhat="$( LC_ALL=C sed -n 's/.*"tracking":"\([a-z-]*\)".*/\1/p' "$rigBody" | head -1 )"
		rigTs="$( printf '1700000001.%06d' "$(( rigPost * 100 ))" )"
		printf '%s %s %s %s\n' "$rigPost" "$rigChannel" "${rigThread:-top}" "${rigWhat:-message}" >> "$RIG_SCENARIO/posts.log"
		printf '{"ok":true,"channel":"%s","ts":"%s","message":{"ts":"%s","user":"URIGBOT01"%s}}\n' \
			"$rigChannel" "$rigTs" "$rigTs" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIGTEAM1","is_im":false,"is_mpim":false}}\n' ;;
	reactions.add|conversations.join) printf '{"ok":true}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
