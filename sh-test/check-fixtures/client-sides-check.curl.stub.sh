#!/usr/bin/env bash
## The fake `curl` for AgentsClientSidesCheck. It opens no socket, and being first on PATH is that check's whole
## offline guarantee. Every call appends one line to $RIG_SCENARIO/calls: for Slack `<method> <token>`, for any other
## host `http <host> <user>` (the user half of a Basic credential, never the secret half), and one line to
## $RIG_SCENARIO/envs with the workspace the call ran in. Posted bodies are appended to $RIG_SCENARIO/bodies, and each
## reaction to $RIG_SCENARIO/reactions as `<token> <channel> <timestamp> <name>`.
## A Slack token answers as the account URIG plus its last dash-separated word, a bot token as URIGBOT01. A post is
## answered with the conversation it was sent to (a person's id as that person's DM, D for its U) and a ts counted per
## scenario. A thread or a conversation is read from $RIG_SCENARIO/thread.<token>.json where the check planted one for
## that token, and is empty otherwise: what one Slack holds is never what the other answers. conversations.info is
## not found, so no addressee is inferred from a conversation. Every other method is not found.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigUrl="" rigBodyFile="" rigChannel="" rigStamp="" rigName="" rigAskTs="" rigAskLimit=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigUrl="$rigArg" ;;
		https://*) rigUrl="$rigArg" ;;
		ts=*) rigAskTs="${rigArg#ts=}" ;;
		limit=*) rigAskLimit="${rigArg#limit=}" ;;
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		timestamp@*) rigStamp="$( cat "${rigArg#timestamp@}" 2> /dev/null )" ;;
		name@*) rigName="$( cat "${rigArg#name@}" 2> /dev/null )" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || rigBodyFile="${rigArg#@}"
	rigPrevArg="$rigArg"
done
[ -z "$rigBodyFile" ] || { cat "$rigBodyFile" ; echo ; } >> "$RIG_SCENARIO/bodies"
printf '%s MMDAPP=%s\n' "${rigMethod:-http}" "${MMDAPP-unset}" >> "$RIG_SCENARIO/envs"
if [ -z "$rigMethod" ] ; then
	rigHost="${rigUrl#https://}" ; rigHost="${rigHost%%/*}"
	rigCred="$( printf '%s' "${rigHeader#Authorization: Basic }" | { base64 -d 2> /dev/null || base64 -D 2> /dev/null ; } )"
	printf 'http %s %s\n' "$rigHost" "${rigCred%%:*}" >> "$RIG_SCENARIO/calls"
	printf '{"values":[]}\n200'
	exit 0
fi
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage)
		rigPosted="$( LC_ALL=C sed -n 's/^{"channel":"\([^"]*\)".*/\1/p' "$rigBodyFile" 2> /dev/null | head -1 )"
		case "$rigPosted" in U*) rigPosted="D${rigPosted#U}" ;; esac
		rigThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBodyFile" 2> /dev/null | head -1 )"
		rigCount=$(( $( cat "$RIG_SCENARIO/posts" 2> /dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigCount" > "$RIG_SCENARIO/posts"
		printf '{"ok":true,"channel":"%s","ts":"1700000001.00010%s","message":{"ts":"1700000001.00010%s","user":"%s"%s}}\n' \
			"${rigPosted:-CRIGNONE1}" "$rigCount" "$rigCount" "$rigUser" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.history|conversations.replies)
		if [ -f "$RIG_SCENARIO/thread.$rigToken.json" ] ; then
			cat "$RIG_SCENARIO/thread.$rigToken.json"
		elif [ "$rigMethod" = "conversations.replies" ] && [ "$rigAskLimit" = "1" ] && [ -n "$rigAskTs" ] ; then
			## the parent-presence look of a reply sent under the bot (limit=1): the conversation holds the parent
			printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"parent"}],"has_more":false}\n' "$rigAskTs"
		else
			printf '{"ok":true,"messages":[],"has_more":false}\n'
		fi
	;;
	reactions.add|reactions.remove)
		printf '%s %s %s %s\n' "$rigToken" "$rigChannel" "$rigStamp" "$rigName" >> "$RIG_SCENARIO/reactions"
		printf '{"ok":true}\n'
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
exit 0
