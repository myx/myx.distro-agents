#!/bin/sh
## Stand-in for curl, for AgentsEmbeddedPythonInstallCheck: no request leaves the rig. It logs its arguments in
## RIG_CURL_LOG, and answers a request for https://github.com/astral-sh/uv/releases/download/<version>/<file> with the
## file of that name from $RIG_FIXTURES/<version>/, else with a 404 (rc 22, as curl -f). With RIG_CURL_FAIL set it
## refuses every request (rc 7), as a host with no internet would.
printf '%s\n' "$*" >> "${RIG_CURL_LOG:?RIG_CURL_LOG is not set}"
dest="" ; url=""
while [ $# -gt 0 ] ; do
	case "$1" in
		-o) dest="$2" ; shift 2 ;;
		-*) shift ;;
		*) url="$1" ; shift ;;
	esac
done
[ -z "${RIG_CURL_FAIL:-}" ] || { echo "stub curl: no network in this rig" >&2 ; exit 7 ; }
version="${url#https://github.com/astral-sh/uv/releases/download/}" ; version="${version%%/*}"
name="${url##*/}"
source="${RIG_FIXTURES:?RIG_FIXTURES is not set}/$version/$name"
[ -n "$dest" ] && [ -f "$source" ] || { echo "stub curl: 404 $url" >&2 ; exit 22 ; }
cp "$source" "$dest"
