#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsApplyReportCheck.test.sh. Opens no socket: being first on PATH is that check's
## whole offline guarantee. It keeps each posted body as post.<n>, counts them in posts, and logs each method in
## argv.log. The body arrives on stdin, as the tool sends it.
set -u
rigUrl="" rigFile=""
for rigArg in "$@" ; do
	printf '%s\n' "$rigArg" >> "$RIG_SCENARIO/argv.log"
	case "$rigArg" in
		https://slack.com/api/*) rigUrl="$rigArg" ;;
		@*) rigFile="${rigArg#@}" ;;
	esac
done
case "$rigUrl" in
	https://slack.com/api/chat.postMessage)
		rigPost=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SCENARIO/posts"
		case "$rigFile" in
			''|-) cat > "$RIG_SCENARIO/post.$rigPost" ;;
			*) cat "$rigFile" > "$RIG_SCENARIO/post.$rigPost" 2>/dev/null ;;
		esac
		printf '{"ok":true,"channel":"CRIGAPPLY01","ts":"1700000000.00010%s","message":{"ts":"1700000000.00010%s","user":"URIGBOT01"}}\n' "$rigPost" "$rigPost"
	;;
	https://slack.com/api/auth.test) cat > /dev/null ; printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	*) cat > /dev/null ; printf '{"ok":false,"error":"unknown_method"}\n' ;;
esac
exit 0
