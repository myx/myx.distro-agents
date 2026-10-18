#!/usr/bin/env bash
## Fake curl for AgentsSlackResolveIdsGateCheck.test.sh. Logs each Slack method
## and its cursor, then answers deterministically from $RIG_SCENARIO. Opens no
## socket, and being first on PATH is the whole of this check's offline
## guarantee. A users.list page is read from
## $RIG_SCENARIO/users-list-pages/<cursor>, or /page1 when there is none.
set -u
rigHeader="$( cat )"
rigToken="${rigHeader#Authorization: Bearer }"
rigMethod="" rigCursor="" rigChannelParam=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		cursor=*) rigCursor="${rigArg#cursor=}" ;;
		channel=*) rigChannelParam="${rigArg#channel=}" ;;
	esac
done
printf '%s cursor=%s token=%s\n' "$rigMethod" "${rigCursor:--}" "$rigToken" >> "$RIG_SCENARIO/calls"

case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"URIGSELF01"}\n'
	;;
	users.info)
		printf '{"ok":false,"error":"user_not_found"}\n'
	;;
	conversations.info)
		if [ -f "$RIG_SCENARIO/conversations-info-ok/$rigChannelParam" ] ; then
			printf '{"ok":true,"channel":{"id":"%s","name":"rig-channel"}}\n' "$rigChannelParam"
		else
			printf '{"ok":false,"error":"channel_not_found"}\n'
		fi
	;;
	users.list)
		rigPageFile="$RIG_SCENARIO/users-list-pages/${rigCursor:-page1}"
		if [ -f "$rigPageFile" ] ; then
			cat "$rigPageFile"
		else
			printf '{"ok":true,"members":[]}\n'
		fi
	;;
	conversations.open)
		printf '{"ok":true,"channel":{"id":"DRIGOPENED1"}}\n'
	;;
	*)
		printf '{"ok":false,"error":"unexpected_method"}\n'
	;;
esac
