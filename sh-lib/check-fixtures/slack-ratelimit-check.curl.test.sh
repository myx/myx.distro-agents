#!/usr/bin/env bash
## The fake `curl` for AgentsSlackRateLimitCheck. It opens no socket. It answers Slack
## as rate-limited or not by $RIG_SCENARIO/mode -- `none` never, `once` on the first
## call only, `always` on every call -- writing the status line and a Retry-After of 1
## second where `-D` names a file, as a real curl writes response headers there. It
## honours the two other shapes the shared call uses: `-o` (a raw GET: the body goes
## to that file, stdout is the `-w` status line) and a `-w` status line after the body
## (an upload). Each call is appended to $RIG_SCENARIO/calls.
set -u
cat > /dev/null
rigHeaderFile="" rigOutFile="" rigWriteOut="" rigPrevArg=""
for rigArg in "$@" ; do
	case "$rigPrevArg" in
		-D) rigHeaderFile="$rigArg" ;;
		-o) rigOutFile="$rigArg" ;;
		-w) rigWriteOut="$rigArg" ;;
	esac
	rigPrevArg="$rigArg"
done
printf 'call\n' >> "$RIG_SCENARIO/calls"
rigCallCount="$( LC_ALL=C awk 'END { print NR ; }' "$RIG_SCENARIO/calls" )"
rigMode="$( cat "$RIG_SCENARIO/mode" )"
rigLimited="no"
case "$rigMode" in
	always) rigLimited="yes" ;;
	once) [ "$rigCallCount" -ne 1 ] || rigLimited="yes" ;;
esac
if [ "$rigLimited" = "yes" ] ; then
	rigCode=429
	[ -z "$rigHeaderFile" ] || printf 'HTTP/2 429\r\nretry-after: 1\r\ncontent-type: application/json\r\n\r\n' > "$rigHeaderFile"
	rigBody='{"ok":false,"error":"ratelimited"}'
else
	rigCode=200
	[ -z "$rigHeaderFile" ] || printf 'HTTP/2 200\r\ncontent-type: application/json\r\n\r\n' > "$rigHeaderFile"
	rigBody='{"ok":true,"messages":[],"has_more":false,"response_metadata":{"next_cursor":""}}'
	[ -z "$rigOutFile" ] || rigBody='RIG-FETCHED-FILE-CONTENT'
fi
if [ -n "$rigOutFile" ] ; then
	printf '%s\n' "$rigBody" > "$rigOutFile"
	printf '%s %s application/octet-stream' "$rigCode" "${#rigBody}"
elif [ -n "$rigWriteOut" ] ; then
	printf '%s\n%s 10' "$rigBody" "$rigCode"
else
	printf '%s\n' "$rigBody"
fi
exit 0
