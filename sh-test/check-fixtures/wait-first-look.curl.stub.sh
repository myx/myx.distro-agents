#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsWaitRepliesFirstLookCheck.test.sh. Opens no socket. Answers from the
## scenario directory: a thread from replies.<channel>.<ts>.json, a conversation from history.<channel>.json
## (empty where the scenario has none), and reactions.add from react-errors (one `<ts> <error>` a line, `ok`
## for a reaction that goes through). Every call is logged as "<method> <channel> <ts> <name>" in api.log,
## and every reaction attempt again, alone, in reactions:
## "<identity token> <channel> <ts> <name> <result>", so a check can count the attempts and who made them.
set -u
rigToken="$( cat )"
rigToken="${rigToken#Authorization: Bearer }"
rigMethod="no-method"
rigChannel=""
rigTs=""
rigName=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2>/dev/null )" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2>/dev/null )" ;;
		timestamp@*) rigTs="$( cat "${rigArg#timestamp@}" 2>/dev/null )" ;;
		name@*) rigName="$( cat "${rigArg#name@}" 2>/dev/null )" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
printf '%s %s %s %s\n' "$rigMethod" "$rigChannel" "$rigTs" "$rigName" >> "$RIG_SCENARIO/api.log"
case "$rigMethod" in
	auth.test)
		case "$rigToken" in
			rig-bot-*) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
			*) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGSELF1"}\n' ;;
		esac
	;;
	conversations.info)
		printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "$rigChannel"
	;;
	conversations.replies)
		if [ -f "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json" ] ; then
			cat "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json"
		else
			printf '{"ok":false,"error":"thread_not_found"}\n'
		fi
	;;
	conversations.history)
		if [ -f "$RIG_SCENARIO/history.$rigChannel.json" ] ; then
			cat "$RIG_SCENARIO/history.$rigChannel.json"
		else
			printf '{"ok":true,"messages":[],"has_more":false}\n'
		fi
	;;
	reactions.add)
		## react-errors holds `<ts> <error> [<identity>]` a line: the identity is `user` or `bot`, and a line
		## without one answers every identity. `ok` is a reaction that goes through.
		rigError="ok"
		case "$rigToken" in
			rig-bot-*) rigIdentity="bot" ;;
			*) rigIdentity="user" ;;
		esac
		if [ -f "$RIG_SCENARIO/react-errors" ] ; then
			rigWanted="$( LC_ALL=C awk -v want="$rigTs" -v who="$rigIdentity" '$1 == want && ( NF < 3 || $3 == who ) { print $2 ; exit ; }' "$RIG_SCENARIO/react-errors" 2>/dev/null )"
			[ -z "$rigWanted" ] || rigError="$rigWanted"
		fi
		printf '%s %s %s %s %s\n' "$rigToken" "$rigChannel" "$rigTs" "$rigName" "$rigError" >> "$RIG_SCENARIO/reactions"
		if [ "$rigError" = "ok" ] ; then
			printf '{"ok":true}\n'
		else
			printf '{"ok":false,"error":"%s"}\n' "$rigError"
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
