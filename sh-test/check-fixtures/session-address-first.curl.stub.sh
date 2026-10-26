#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsSessionAddressFirstCheck.test.sh. Opens no socket and answers in the
## shape the real call reads: the `channel` of a post is the channel the call was given, a post's `ts` is a
## fixed base and the number of the post in this scenario, and `message.thread_ts` is present only where the
## post was made INTO a thread -- a top-level post carries none, exactly as Slack answers, so the session
## chat record of a top-level message names the message's own ts and not a `-` placeholder.
## Logs each call as `<method> <channel> <thread_ts> <post number>` in $RIG_SCENARIO/calls (a field the call
## carries no value of reads `-`), keeps each posted payload in $RIG_SCENARIO/post.<n>, and writes the
## response-headers file the shared Slack call asks for, so no rate-limit handling reads a missing file.
## A scenario can answer a post with a Slack error, one error name per line in post-errors; a line `ok` is a
## post that goes through.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigBody="" rigHeaderFile="" rigChannel="" rigThread="" rigPostThread=""
while [ $# -gt 0 ] ; do
	rigArg="$1"
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || case "$rigArg" in @*) rigBody="${rigArg#@}" ;; esac
	[ "$rigPrevArg" != "-D" ] || rigHeaderFile="$rigArg"
	rigPrevArg="$rigArg"
	shift
done
if [ -n "$rigHeaderFile" ] ; then
	printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' > "$rigHeaderFile" 2> /dev/null || :
fi
rigPost=""
case "$rigMethod" in
	chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigPost"
		rigChannel="$( LC_ALL=C sed -n 's/.*"channel":"\([^"]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		rigPostThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([^"]*\)".*/\1/p' "$rigBody" 2> /dev/null | head -1 )"
		case "$rigChannel" in ''|-*) rigChannel="-" ;; esac
		rigThread="$rigPostThread"
		case "$rigThread" in ''|-*) rigThread="-" ;; esac
		printf '%s %s %s %s\n' "$rigMethod" "$rigChannel" "$rigThread" "$rigPost" >> "$RIG_SCENARIO/calls"
		if [ -s "$RIG_SCENARIO/post-errors" ] ; then
			rigError="$( head -1 "$RIG_SCENARIO/post-errors" )"
			tail -n +2 "$RIG_SCENARIO/post-errors" > "$RIG_SCENARIO/post-errors.next" && mv "$RIG_SCENARIO/post-errors.next" "$RIG_SCENARIO/post-errors"
			if [ "$rigError" != "ok" ] ; then
				printf '{"ok":false,"error":"%s"}\n' "$rigError"
				exit 0
			fi
		fi
		printf '{"ok":true,"channel":"%s","ts":"1760000001.%06d","message":{"ts":"1760000001.%06d","user":"URIGBOT01"%s}}\n' \
			"$rigChannel" "$rigPost" "$rigPost" "${rigPostThread:+,\"thread_ts\":\"$rigPostThread\"}"
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "${rigChannel:-CRIG00001}"
	;;
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	reactions.add) printf '{"ok":true}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
case "$rigMethod" in
	chat.postMessage) ;;
	*) printf '%s %s - -\n' "${rigMethod:-unknown}" "-" >> "$RIG_SCENARIO/calls" ;;
esac
