#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsHarnessAskFormsCheck.test.sh. Logs each method, keeps each
## posted body, each reaction placed or taken off, each edit and each delete, and answers
## from the scenario directory. Keeps each call with the token it was made under. Opens no socket.
set -u
## The token arrives on stdin, as the call's Authorization header.
rigHeader="$( cat )"
rigToken="${rigHeader#Authorization: Bearer }"
rigMethod="no-method"
rigBody=""
rigTs=""
rigReactTs=""
rigReactName=""
rigText=""
for rigArg in "$@" ; do
	case "$rigArg" in
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		timestamp@*) rigReactTs="$( cat "${rigArg#timestamp@}" 2>/dev/null )" ;;
		name@*) rigReactName="$( cat "${rigArg#name@}" 2>/dev/null )" ;;
		text@*) rigText="${rigArg#text@}" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
		@-) ;;
		@*) rigBody="${rigArg#@}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
## Each call as "<method> <token>", a reaction with its post and its name after them.
printf '%s %s%s\n' "$rigMethod" "$rigToken" "${rigReactName:+ $rigReactTs $rigReactName}" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test)
		## A scenario can give one token an account of its own: its user id, in account.<token>.
		printf '{"ok":true,"user_id":"%s"}\n' "$( cat "$RIG_SCENARIO/account.$rigToken" 2>/dev/null || printf 'URIGSELF1' )"
	;;
	chat.postMessage)
		## A scenario can have every post holding one text refused, permanently.
		if [ -s "$RIG_SCENARIO/post-refuse-matching" ] && [ -n "$rigBody" ] && LC_ALL=C grep -q -F -f "$RIG_SCENARIO/post-refuse-matching" "$rigBody" 2>/dev/null ; then
			printf '{"ok":false,"error":"is_archived"}\n'
			exit 0
		fi
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		## The token that post went out under, beside it.
		printf '%s' "$rigToken" > "$RIG_SCENARIO/posted-as.$rigPost"
		rigThread="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		## The n-th post is 1700000001.000n01, so a scenario can place a reply between two posts.
		printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.000%s01","message":{"ts":"1700000001.000%s01","user":"URIGSELF1"%s}}\n' \
			"$rigPost" "$rigPost" "${rigThread:+,\"thread_ts\":\"$rigThread\"}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n'
	;;
	conversations.replies)
		## A thread of its own answers from replies.<ts>.json; every other thread shares replies.json.
		if [ -n "$rigTs" ] && [ -f "$RIG_SCENARIO/replies.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigTs.json"
		elif [ -f "$RIG_SCENARIO/replies.json" ] ; then
			cat "$RIG_SCENARIO/replies.json"
		else
			printf '{"ok":false,"error":"rig_no_replies"}\n'
		fi
	;;
	reactions.add)
		printf '%s %s\n' "$rigReactTs" "$rigReactName" >> "$RIG_SCENARIO/reactions"
		if [ -f "$RIG_SCENARIO/react-refuse" ] ; then
			printf '{"ok":false,"error":"missing_scope"}\n'
		else
			printf '{"ok":true}\n'
		fi
	;;
	reactions.remove)
		printf '%s %s\n' "$rigReactTs" "$rigReactName" >> "$RIG_SCENARIO/reactions.removed"
		printf '{"ok":true}\n'
	;;
	chat.update)
		## An edit comes as the send's own JSON body, naming the message it edits; an edit by
		## form fields (the plain edit op) is kept the same way, as its text.
		[ -n "$rigTs" ] || rigTs="$( sed -n 's/.*","ts":"\([0-9.]*\)","blocks":.*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		[ -n "$rigTs" ] || rigTs="$( sed -n 's/.*","ts":"\([0-9.]*\)"}$/\1/p' "$rigBody" 2>/dev/null | head -1 )"
		## A scenario can have every edit refused, as Slack refuses one it will not make.
		if [ -f "$RIG_SCENARIO/edit-refuse" ] ; then
			printf '%s\n' "$rigTs" >> "$RIG_SCENARIO/edit-refused"
			printf '{"ok":false,"error":"cant_update_message"}\n'
			exit 0
		fi
		printf '%s\n' "$rigTs" >> "$RIG_SCENARIO/edited"
		if [ -n "$rigBody" ] ; then
			cp "$rigBody" "$RIG_SCENARIO/edit.$rigTs"
		elif [ -n "$rigText" ] ; then
			cp "$rigText" "$RIG_SCENARIO/edit.$rigTs"
		fi
		printf '{"ok":true,"channel":"CRIG00001","ts":"%s","message":{"ts":"%s","user":"URIGSELF1"}}\n' "$rigTs" "$rigTs"
	;;
	chat.delete)
		printf '%s\n' "$rigTs" >> "$RIG_SCENARIO/deleted"
		printf '{"ok":true,"channel":"CRIG00001","ts":"%s"}\n' "$rigTs"
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
