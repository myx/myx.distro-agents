#!/usr/bin/env bash
## The fake `curl` for AgentsMemberWorkspaceCheck. It opens no socket, and being first on PATH is that check's whole
## offline guarantee. Every call appends one line to $RIG_SCENARIO/calls: for Slack `<method> <token>`, for any other
## host `http <host> <user>` (the user half of a Basic credential, never the secret half), and one line to
## $RIG_SCENARIO/envs with what the call's own environment held: MMDAPP, MDLT_ORIGIN, a stale distro index variable
## the check planted, a stale MDSC_ID variable, MDAT_DATA_ROOT. Posted bodies are appended to $RIG_SCENARIO/bodies.
## A Slack token answers as the account URIG plus its last dash-separated word, a bot token as URIGBOT01.
set -u
rigHeader="$( cat )"
rigMethod="" rigPrevArg="" rigUrl=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigUrl="$rigArg" ;;
		https://*) rigUrl="$rigArg" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || { cat "${rigArg#@}" ; echo ; } >> "$RIG_SCENARIO/bodies"
	rigPrevArg="$rigArg"
done
printf '%s MMDAPP=%s ORIGIN=%s CACHED=%s STALEID=%s DATAROOT=%s\n' "${rigMethod:-http}" "${MMDAPP-unset}" "${MDLT_ORIGIN-unset}" "${MDSC_CACHED-unset}" "${MDSC_ID_RIGSTALE-unset}" "${MDAT_DATA_ROOT-unset}" >> "$RIG_SCENARIO/envs"
if [ -z "$rigMethod" ] ; then
	rigHost="${rigUrl#https://}" ; rigHost="${rigHost%%/*}"
	rigCred="$( printf '%s' "${rigHeader#Authorization: Basic }" | { base64 -d 2> /dev/null || base64 -D 2> /dev/null ; } )"
	printf 'http %s %s\n' "$rigHost" "${rigCred%%:*}" >> "$RIG_SCENARIO/calls"
	printf '{"values":[]}\n200'
	exit 0
fi
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
case "$rigToken" in
	rig-bot-*) rigUser="URIGBOT01" ;;
	*) rigUser="URIG${rigToken##*-}" ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"%s"}\n' "$rigUser" ;;
	chat.postMessage) printf '{"ok":true,"channel":"DRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"%s"}}\n' "$rigUser" ;;
	conversations.history|conversations.replies) printf '{"ok":true,"messages":[]}\n' ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
exit 0
