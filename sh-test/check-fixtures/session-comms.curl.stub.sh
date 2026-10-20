#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsSessionCommsCheck.test.sh. Opens no socket. Answers from the scenario directory
## ($RIG_SCENARIO) and logs every call as "<epoch> <method> <channel> <ts> <oldest> <token>" in api.log:
##   conversations.replies   the thread from replies.<channel>.<ts>.json (the whole file, whatever `oldest` says: what the
##                           reader asks is in the log). A line of replies-script answers the call before it is read: `rate:<n>`
##                           is HTTP 429 with a Retry-After of n seconds, `error:<name>` a Slack refusal.
##   chat.postMessage        what its payload is kept as post.<n>; a line of post-script, taken one a call, says what happens:
##                           `ok` (the default once the script is empty), `error:<name>` (Slack refuses), `rate:<n>` (429 with
##                           a Retry-After of n seconds), `curl:<code>` (curl itself fails with that exit status, nothing said).
##   conversations.info, auth.test   answered, for the send operation's own steps.
## The token that came on stdin is the last word of each log line, so a check can tell which identity called.
set -u
rigHeader="$( cat )"
rigMethod="no-method" rigChannel="" rigTs="" rigOldest="" rigBody="" rigHeaders="" rigPrev=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2>/dev/null )" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		oldest@*) rigOldest="$( cat "${rigArg#oldest@}" 2>/dev/null )" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
	[ "$rigPrev" != "--data-binary" ] || rigBody="${rigArg#@}"
	[ "$rigPrev" != "-D" ] || rigHeaders="$rigArg"
	rigPrev="$rigArg"
done
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
rigToken="${rigHeader#Authorization: Bearer }"
if [ "$rigMethod" = "chat.postMessage" ] && [ -n "$rigBody" ] ; then
	rigChannel="$( sed -n 's/.*"channel":"\([A-Z0-9]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
	rigTs="$( sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigBody" 2>/dev/null | head -1 )"
fi
printf '%s %s %s %s %s %s\n' "$( date +%s )" "$rigMethod" "${rigChannel:--}" "${rigTs:--}" "${rigOldest:--}" "$rigToken" >> "$RIG_SCENARIO/api.log"
## The next line of a script, taken: its first word and what follows.
rigStep(){ ## script file -- prints the line, removes it from the file
	local stepFile="$1" stepLine
	[ -s "$stepFile" ] || return 1
	stepLine="$( head -1 "$stepFile" )"
	tail -n +2 "$stepFile" > "$stepFile.next" ; mv -f "$stepFile.next" "$stepFile"
	printf '%s\n' "$stepLine"
}
rigAnswer(){ ## the scripted step, or nothing for the normal answer. Ends the call where it answers.
	local answerStep="$1"
	case "$answerStep" in
		rate:*)
			[ -z "$rigHeaders" ] || printf 'HTTP/1.1 429 Too Many Requests\r\nRetry-After: %s\r\n\r\n' "${answerStep#rate:}" > "$rigHeaders"
			printf '{"ok":false,"error":"ratelimited"}\n' ; exit 0
		;;
		error:*) printf '{"ok":false,"error":"%s"}\n' "${answerStep#error:}" ; exit 0 ;;
		curl:*) printf 'curl: (%s) rig: the request failed\n' "${answerStep#curl:}" >&2 ; exit "${answerStep#curl:}" ;;
	esac
}
[ -z "$rigHeaders" ] || printf 'HTTP/1.1 200 OK\r\n\r\n' > "$rigHeaders"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"%s"}\n' "$rigUser" ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "${rigChannel:-CRIG00001}" ;;
	conversations.replies)
		rigStepLine="$( rigStep "$RIG_SCENARIO/replies-script" )" && rigAnswer "$rigStepLine"
		if [ -f "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json"
		else
			printf '{"ok":false,"error":"thread_not_found"}\n'
		fi
	;;
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigStepLine="$( rigStep "$RIG_SCENARIO/post-script" )" && [ "$rigStepLine" != "ok" ] && rigAnswer "$rigStepLine"
		printf '{"ok":true,"channel":"CRIGSES01","ts":"1760000000.00010%s","message":{"ts":"1760000000.00010%s","user":"%s"%s}}\n' \
			"$rigPost" "$rigPost" "$rigUser" "${rigTs:+,\"thread_ts\":\"$rigTs\"}"
	;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
