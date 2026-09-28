#!/usr/bin/env bash
## Records the request body and replays one canned stop stream. It opens no socket, and
## being first on PATH is the whole of this check's offline guarantee.
set -u
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req" ; shift 2 ;;
		*)  shift ;;
	esac
done
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-ANSWER"},"finish_reason":"stop"}],"usage":{"total_tokens":1}}\n'
printf 'data: [DONE]\n'
