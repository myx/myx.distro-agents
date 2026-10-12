#!/usr/bin/env bash
## The fake `curl` for AgentsClientSystemsCheck and AgentsClientSettingsFallbackCheck. It opens no socket, and being
## first on PATH is half of each check's offline guarantee: the fake `python3` beside it is the other half. Every call appends one line to
## $RIG_SCENARIO/calls that names the system, where the call went and whose settings it carried -- the login, the
## user or the key, never the secret half:
##   imap <host> <login> <request>       smtp <host> <login> <recipient>...
##   trello <path> <key>                 http <host> <user>     (a Basic credential: Jira, Confluence)
##   slack <method> <token>              other <url>
## (a rig Slack token is no secret: it only says whose it is) and one line to $RIG_SCENARIO/envs with the workspace the
## call ran in. The answers are the least each operation
## takes as one: an unseen count and two UIDs, an empty notification list, an account named after the key, an empty
## page of rows with status 200, a Slack account named after the token and an empty conversation. Every other Slack
## method is not found.
set -u
rigIn="$( cat )"
rigUrl="" rigRequest="" rigPrevArg="" rigRcpt=""
for rigArg in "$@" ; do
	case "$rigPrevArg" in
		--url) rigUrl="$rigArg" ;;
		--request) rigRequest="$rigArg" ;;
		--mail-rcpt) rigRcpt="$rigRcpt $rigArg" ;;
	esac
	case "$rigArg" in
		https://*) rigUrl="$rigArg" ;;
	esac
	rigPrevArg="$rigArg"
done
printf '%s MMDAPP=%s\n' "${rigUrl%%:*}" "${MMDAPP-unset}" >> "$RIG_SCENARIO/envs"
rigLogin="$( printf '%s\n' "$rigIn" | LC_ALL=C sed -n 's/^machine [^ ]* login \([^ ]*\) password .*/\1/p' | head -1 )"
case "$rigUrl" in
	imaps://*)
		rigHost="${rigUrl#imaps://}" ; rigHost="${rigHost%%/*}"
		printf 'imap %s %s %s\n' "$rigHost" "$rigLogin" "$rigRequest" >> "$RIG_SCENARIO/calls"
		case "$rigRequest" in
			STATUS*) printf '* STATUS INBOX (UNSEEN 2)\r\n' ;;
			'UID SEARCH'*) printf '* SEARCH 41 42\r\n' ;;
		esac
	;;
	smtp://*)
		rigHost="${rigUrl#smtp://}" ; rigHost="${rigHost%%:*}"
		printf 'smtp %s %s%s\n' "$rigHost" "$rigLogin" "$rigRcpt" >> "$RIG_SCENARIO/calls"
	;;
	https://api.trello.com/*)
		rigKey="$( printf '%s\n' "$rigIn" | LC_ALL=C sed -n 's/.*oauth_consumer_key=[\\]*"\([^"\\]*\).*/\1/p' | head -1 )"
		rigPath="${rigUrl#https://api.trello.com/1/}" ; rigPath="${rigPath%%\?*}"
		printf 'trello %s %s\n' "$rigPath" "$rigKey" >> "$RIG_SCENARIO/calls"
		case "$rigPath" in
			members/me) printf '{"id":"rigid%s","username":"rig-%s"}\n' "${rigKey##*-}" "${rigKey##*-}" ;;
			members/me/notifications) printf '[]\n' ;;
			*) printf '{"id":"%s"}\n' "${rigPath##*/}" ;;
		esac
	;;
	https://slack.com/api/*)
		rigMethod="${rigUrl#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}"
		rigToken="${rigIn#Authorization: Bearer }"
		printf 'slack %s %s\n' "$rigMethod" "$rigToken" >> "$RIG_SCENARIO/calls"
		case "$rigMethod" in
			auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIG%s"}\n' "${rigToken##*-}" ;;
			conversations.history|conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
			*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
		esac
	;;
	https://*)
		rigHost="${rigUrl#https://}" ; rigHost="${rigHost%%/*}"
		rigCred="$( printf '%s' "${rigIn#Authorization: Basic }" | { base64 -d 2> /dev/null || base64 -D 2> /dev/null ; } )"
		printf 'http %s %s\n' "$rigHost" "${rigCred%%:*}" >> "$RIG_SCENARIO/calls"
		printf '{"values":[],"results":[]}\n200'
	;;
	*) printf 'other %s\n' "$rigUrl" >> "$RIG_SCENARIO/calls" ;;
esac
exit 0
