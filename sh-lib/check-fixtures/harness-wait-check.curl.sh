#!/usr/bin/env bash
set -u
## The DESTINATION, one line per call, never the argv: a request body carries the
## word `slack` in the Wait tool's own description, so a log of argv would report a
## Slack request on every model round and the offline assertion would be noise.
rigUrl="no-url"
for rigArg in "$@" ; do
	case "$rigArg" in
		http://*|https://*) rigUrl="$rigArg" ;;
	esac
done
printf '%s\n' "$rigUrl" >> "$RIG_CURL_LOG"
[ -n "${RIG_SCENARIO:-}" ] || exit 1
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
