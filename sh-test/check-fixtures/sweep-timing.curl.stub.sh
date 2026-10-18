#!/usr/bin/env bash
## The fake `curl` for AgentsSweepTimingInstrument.sh. It opens no socket. Every call
## waits $FIX_LATENCY seconds, the stand-in for a network round trip, is logged by its
## Slack method to $FIX_DIR/calls.log, and gets a generic answer: a roster of $FIX_DMS
## direct conversations, empty histories, and resolvable conversation ids.
set -u
cat > /dev/null
fixUrl=""
for fixArg in "$@" ; do
	case "$fixArg" in
		https://*|imaps://*|smtp://*) fixUrl="$fixArg" ;;
	esac
done
fixMethod="${fixUrl#https://slack.com/api/}"
fixMethod="${fixMethod%%\?*}"
printf '%s %s\n' "$( date +%s )" "$fixMethod" >> "$FIX_DIR/calls.log"
sleep "${FIX_LATENCY:-0}"
case "$fixMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"UFIXSELF","user":"fix"}\n' ;;
	conversations.list)
		printf '{"ok":true,"channels":['
		fixIndex=1
		while [ "$fixIndex" -le "${FIX_DMS:-10}" ] ; do
			[ "$fixIndex" -eq 1 ] || printf ','
			printf '{"id":"DFIX%07d","is_im":true,"user":"UFIX%07d"}' "$fixIndex" "$fixIndex"
			fixIndex=$(( fixIndex + 1 ))
		done
		printf '],"response_metadata":{"next_cursor":""}}\n'
	;;
	users.list) printf '{"ok":true,"members":[{"id":"UFIXSELF","name":"fix"}],"response_metadata":{"next_cursor":""}}\n' ;;
	users.info) printf '{"ok":true,"user":{"id":"UFIX0000001","name":"fixuser"}}\n' ;;
	conversations.history|conversations.replies) printf '{"ok":true,"messages":[],"has_more":false,"response_metadata":{"next_cursor":""}}\n' ;;
	conversations.info)
		fixChannel=""
		for fixArg in "$@" ; do
			case "$fixArg" in
				channel=*) fixChannel="${fixArg#channel=}" ;;
			esac
		done
		case "$fixChannel" in
			D*) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"is_channel":false,"is_group":false,"user":"UFIX%s"}}\n' "$fixChannel" "${fixChannel#DFIX}" ;;
			*) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false,"is_channel":true,"is_group":false,"name":"fix"}}\n' "$fixChannel" ;;
		esac
	;;
	search.messages) printf '{"ok":true,"messages":{"matches":[],"paging":{"pages":1,"page":1}}}\n' ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"DFIXOWNER01"}}\n' ;;
	*) printf '{"ok":false,"error":"fixture_unknown_method"}\n' ;;
esac
exit 0
