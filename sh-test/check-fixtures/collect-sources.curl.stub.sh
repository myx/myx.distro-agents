#!/usr/bin/env bash
## Offline stand-in for curl, for the collection checks: opens no socket. Logs each call as `<method> <url>` to $FIX_DIR/curl.log
## (the credential on its standard input is read and dropped, never logged) and answers the one Trello read the collector makes,
## the unread notifications of the member, from $FIX_DIR/trello.json, and the identity lookup a scan prints (members/me).
## $FIX_DIR/trello-fails, when present, makes the first fail.
## A call for anything else is logged as `OTHER <url>` and fails, so the check can count that none was made. Test fixture only.
set +e
method="GET" url=""
for arg in "$@" ; do
	case "$arg" in
		-X) ;;
		POST|PUT|DELETE|PATCH) method="$arg" ;;
		http*) url="$arg" ;;
	esac
done
cat > /dev/null
case "$url" in
	https://api.trello.com/1/members/me/notifications\?read_filter=unread)
		printf '%s %s\n' "$method" "$url" >> "$FIX_DIR/curl.log"
		if [ -e "$FIX_DIR/trello-fails" ] ; then
			echo "curl: (22) The requested URL returned error: 401" >&2
			exit 22
		fi
		cat "$FIX_DIR/trello.json"
		exit 0
	;;
esac
case "$url" in
	https://api.trello.com/1/members/me\?fields=id,username)
		## Who the credential is, for the identity line of a scan; not a read of the source.
		printf '%s %s\n' "$method" "$url" >> "$FIX_DIR/curl.log"
		printf '%s' '{"id":"rigtrelloid","username":"rigtrello"}'
		exit 0
	;;
esac
printf 'OTHER %s %s\n' "$method" "$url" >> "$FIX_DIR/curl.log"
echo "curl: (6) the check's curl answers only the unread notifications" >&2
exit 6
