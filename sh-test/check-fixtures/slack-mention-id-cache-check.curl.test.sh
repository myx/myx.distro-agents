#!/usr/bin/env bash
## The fake `curl` for AgentsSlackMentionIdCacheCheck. It opens no socket, and being first on PATH is that check's whole
## offline guarantee. It appends each Slack method with the token it was called under to $RIG_SCENARIO/calls, and answers
## as that token's account: auth.test gives URIG plus the token's last word; users.info gives the JSON in
## $RIG_SCENARIO/users-info.json, or ok:false when $RIG_SCENARIO/users-info-fail exists; anything else is ok:false.
set -u
rigHeader="$( cat )"
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
done
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIG%s"}\n' "${rigToken##*-}" ;;
	users.info)
		if [ -e "$RIG_SCENARIO/users-info-fail" ] ; then
			printf '{"ok":false,"error":"user_not_found"}\n'
		else
			cat "$RIG_SCENARIO/users-info.json"
		fi
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
exit 0
