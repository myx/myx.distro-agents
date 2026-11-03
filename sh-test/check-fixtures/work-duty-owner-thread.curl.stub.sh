#!/usr/bin/env bash
## The fake `curl` for AgentsWorkDutyOwnerThreadCheck. It opens no socket, and being first on PATH is the whole of
## that check's offline guarantee. Each call is logged as `<method> <token>` in $RIG_SCENARIO/calls. A posted body is
## kept in $RIG_SCENARIO/bodies and its target channel, read off the JSON or the form, is logged beside it as
## `<n> <channel>` in $RIG_SCENARIO/post-channels, so a check tells a post to the owner's conversation from one to
## the team channel. A direct message opens as DRIGOWNER01.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigBody="" rigChannel=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		channel=*) rigChannel="${rigArg#channel=}" ;;
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
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"DRIGOWNER01"}}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false,"is_channel":true,"is_group":false,"name":"rig"}}\n' "${rigChannel:-CRIG00001}" ;;
	users.info) printf '{"ok":true,"user":{"id":"URIGOWNER01","name":"rig-owner","real_name":"Rig Owner","profile":{"display_name":"rigowner"}}}\n' ;;
	conversations.history|conversations.list) printf '{"ok":true,"messages":[],"channels":[],"has_more":false,"response_metadata":{"next_cursor":""}}\n' ;;
	reactions.add) printf '{"ok":true}\n' ;;
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2> /dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/body.$rigPost"
		[ -n "$rigChannel" ] || rigChannel="$( sed -n 's/.*"channel":"\([A-Z0-9]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		printf '%s %s\n' "$rigPost" "${rigChannel:-none}" >> "$RIG_SCENARIO/post-channels"
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		printf '{"ok":true,"channel":"%s","ts":"1760000000.00010%s","message":{"ts":"1760000000.00010%s","user":"%s"%s}}\n' \
			"${rigChannel:-CRIG00001}" "$rigPost" "$rigPost" "$rigUser" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
exit 0
