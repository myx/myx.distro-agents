#!/usr/bin/env bash
## Fake curl for AgentsHarnessBusyAnswerCheck.test.sh. A call to Slack goes to the Slack-shaped stub the check names in RIG_SLACK_STUB. Any other call
## is one model request: its body is kept as req.<n>, the headers file it is asked for is made from hdr.<n> (none where that file is absent, as a leg
## whose transport writes none), and res.<n> is replayed. A round with no res.<n> fails as a dropped connection. It opens no socket.
set -u
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) exec bash "$RIG_SLACK_STUB" "$@" ;;
	esac
done
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > /dev/null
rigPrev=""
for rigArg in "$@" ; do
	case "$rigPrev" in
		--data-binary) cp "${rigArg#@}" "$RIG_SCENARIO/req.$rigRound" ;;
		-D) [ ! -f "$RIG_SCENARIO/hdr.$rigRound" ] || cp "$RIG_SCENARIO/hdr.$rigRound" "$rigArg" ;;
	esac
	rigPrev="$rigArg"
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned answer for request %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
