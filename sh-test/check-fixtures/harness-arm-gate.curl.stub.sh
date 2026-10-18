#!/usr/bin/env bash
## Fake curl for AgentsHarnessArmGateCheck.test.sh. A model request replays the round's
## canned stream and keeps its body; a Slack request is answered Slack-shaped and its
## body kept, without spending a round. Every destination is logged; no socket opens.
set -u
rigUrl="no-url"
rigBody=""
for rigArg in "$@" ; do
	case "$rigArg" in
		http://*|https://*) rigUrl="$rigArg" ;;
		@-) ;;
		@*) rigBody="${rigArg#@}" ;;
	esac
done
printf '%s\n' "$rigUrl" >> "$RIG_CURL_LOG"
cat > /dev/null
[ -n "${RIG_SCENARIO:-}" ] || exit 1
case "$rigUrl" in
	https://slack.com/api/*)
		[ -z "$rigBody" ] || { cat "$rigBody" >> "$RIG_SCENARIO/slack.bodies" ; echo >> "$RIG_SCENARIO/slack.bodies" ; }
		printf '{"ok":true,"channel":"CRIGTRACK","ts":"1700000001.000100","message":{"ts":"1700000001.000100","user":"URIGBOT"}}\n'
		exit 0
	;;
esac
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/req.$rigRound"
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
