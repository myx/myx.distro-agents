#!/usr/bin/env bash
## The fake `curl` for AgentsSessionContextReadsCheck.test.sh. Opens no socket. Logs
## "<token-kind> <method> <channel> <ts> <cursor>" per call to $FIX_DIR/calls.log and
## answers from a fixed estate: $FIX_DMS direct conversations whose last digit picks
## a shape (empty, fresh thread, stale thread of our own, thread with no stated
## latest reply, two pages, ...), $FIX_CHANNELS member and $FIX_NONMEMBER
## non-member channels on a channel-wide roster, and one mention hit.
## $FIX_K6_AGE ages the "6" threads; $FIX_FAIL turns three reads into failures.
set -u
fixStdin="$( cat )"
fixToken="user" ; case "$fixStdin" in *xoxb-*) fixToken="bot" ;; esac
fixUrl=""
declare -a fixForm=()
for fixArg in "$@" ; do
	case "$fixArg" in
		https://*|imaps://*|smtp://*) fixUrl="$fixArg" ;;
		*=*|*@*)
			case "$fixArg" in
				*@/*) fixForm+=( "${fixArg%%@*}=$( cat "${fixArg#*@}" 2>/dev/null )" ) ;;
				*=*) fixForm+=( "$fixArg" ) ;;
			esac
		;;
	esac
done
fv(){ local p ; for p in "${fixForm[@]+"${fixForm[@]}"}" ; do case "$p" in "$1="*) printf '%s' "${p#*=}" ; return ;; esac ; done ; }
fixMethod="${fixUrl#https://slack.com/api/}"
fixMethod="${fixMethod%%\?*}"
fixChannel="$( fv channel )" fixTs="$( fv ts )" fixCursor="$( fv cursor )"
printf '%s %s %s %s %s\n' "$fixToken" "$fixMethod" "$fixChannel" "$fixTs" "$fixCursor" >> "$FIX_DIR/calls.log"
sleep "${FIX_LATENCY:-0}"
N="$FIX_TS"
if [ -n "${FIX_FAIL:-}" ] ; then
	case "$fixMethod:$fixChannel" in
		conversations.history:DFIX0000011) printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ;;
		conversations.history:DFIX0000014) printf '{"ok":true,"messages":[{"type":"message","ts":"1.0","text":"x"\n' ; exit 0 ;;
		conversations.replies:DFIX0000012) printf '{"ok":false,"error":"thread_not_found"}\n' ; exit 0 ;;
	esac
fi
## Per-channel deterministic number 0..9 from the channel's last digit.
cnum(){ local c="$1" ; c="${c: -1}" ; case "$c" in [0-9]) printf '%s' "$c" ;; *) printf 0 ;; esac ; }
msg(){ ## ts user text [reply_count latest_reply [reply_users]]
	local extra=""
	[ -z "${4:-}" ] || extra=",\"thread_ts\":\"$1\",\"reply_count\":$4"
	[ -z "${5:-}" ] || extra="$extra,\"latest_reply\":\"$5\""
	[ -z "${6:-}" ] || extra="$extra,\"reply_users\":[\"$6\"]"
	printf '{"type":"message","user":"%s","ts":"%s","text":"%s"%s}' "$2" "$1" "$3" "$extra"
}
case "$fixMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"UFIXSELF","user":"fix%s"}\n' "$fixToken" ;;
	users.list) printf '{"ok":true,"members":[{"id":"UFIXSELF","name":"fixself"},{"id":"UFIX0000001","name":"alice"},{"id":"UFIX0000002","name":"bob"},{"id":"UFIXPEER01","name":"peer"}],"response_metadata":{"next_cursor":""}}\n' ;;
	conversations.list)
		printf '{"ok":true,"channels":['
		i=1 ; sep=""
		while [ "$i" -le "${FIX_DMS:-5}" ] ; do
			printf '%s{"id":"DFIX%07d","is_im":true,"user":"UFIX%07d"}' "$sep" "$i" "$i" ; sep=","
			i=$(( i + 1 ))
		done
		case "$(fv types)" in *public_channel*)
			i=1
			while [ "$i" -le "${FIX_CHANNELS:-0}" ] ; do
				printf '%s{"id":"CFIXMEM%04d","is_im":false,"is_mpim":false,"is_member":true}' "$sep" "$i" ; sep=","
				i=$(( i + 1 ))
			done
			i=1
			while [ "$i" -le "${FIX_NONMEMBER:-0}" ] ; do
				printf '%s{"id":"CFIXNON%04d","is_im":false,"is_mpim":false,"is_member":false}' "$sep" "$i" ; sep=","
				i=$(( i + 1 ))
			done
		;; esac
		printf '],"response_metadata":{"next_cursor":""}}\n'
	;;
	users.info) printf '{"ok":true,"user":{"id":"UFIX0000001","name":"alice"}}\n' ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"DFIXOWNER01"}}\n' ;;
	conversations.info)
		case "$fixChannel" in
			D*) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"is_channel":false,"is_group":false,"user":"UFIXOWNER01"}}\n' "$fixChannel" ;;
			*) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false,"is_channel":true,"is_group":false,"name":"fix"}}\n' "$fixChannel" ;;
		esac
	;;
	conversations.history)
		k="$( cnum "$fixChannel" )"
		## Old enough to be before any cut-off the rig gives.
		O=$(( N - 90000 ))
		printf '{"ok":true,"messages":['
		if [ "$fixCursor" = "page2" ] ; then
			msg "$(( O - 50 )).000100" UFIXPEER01 "older page msg $fixChannel"
			printf '],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
			exit 0
		fi
		case "$k" in
			0) ;;  ## empty
			1) msg "$(( N - 100 - k )).000100" UFIX0000001 "hello in $fixChannel <@UFIXSELF>" ;;
			2) msg "$(( N - 200 )).000200" UFIX0000002 "fresh thread parent $fixChannel" 2 "$(( N - 30 )).000300" UFIX0000002 ;;
			3) msg "$(( O )).000300" UFIXSELF "stale vane thread $fixChannel" 3 "$(( O + 10 )).000400" UFIX0000001 ; printf ',' ; msg "$(( N - 300 )).000300" UFIX0000001 "recent top $fixChannel" ;;
			4) msg "$(( O )).000400" UFIX0000002 "vane tagged no latest <@UFIXSELF> $fixChannel" 1 ;;
			5) msg "$(( N - 500 )).000500" UFIXPEER01 "page one $fixChannel" ; printf '],"has_more":true,"response_metadata":{"next_cursor":"page2"}}\n' ; exit 0 ;;
			6) msg "$(( O )).000600" UFIX0000001 "old thread with fresh reply $fixChannel" 4 "$(( N - ${FIX_K6_AGE:-60} )).000600" ;;
			7) msg "$(( O + 5 )).000700" UFIX0000001 "stale non-vane thread $fixChannel" 2 "$(( O + 20 )).000700" ;;
			8) msg "$(( N - 800 )).000800" UFIX0000002 "eight $fixChannel" ;;
			9) msg "$(( N - 900 )).000900" UFIXSELF "self $fixChannel" ;;
		esac
		printf '],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
	;;
	conversations.replies)
		k="$( cnum "$fixChannel" )"
		O=$(( N - 90000 ))
		pts="${fixTs%%.*}"
		printf '{"ok":true,"messages":['
		msg "$fixTs" UFIX0000001 "root of $fixChannel:$fixTs" 1
		case "$k" in
			2) printf ',' ; msg "$(( N - 100 )).000201" UFIX0000001 "reply A $fixChannel" ; printf ',' ; msg "$(( N - 30 )).000300" UFIXSELF "reply B $fixChannel" ;;
			3|7) printf ',' ; msg "$(( pts + 10 )).000401" UFIX0000001 "stale reply $fixChannel" ;;
			4) printf ',' ; msg "$(( N - 40 )).000402" UFIX0000001 "reply to tag $fixChannel" ;;
			6) printf ',' ; msg "$(( O + 1 )).000601" UFIX0000002 "old reply $fixChannel" ; printf ',' ; msg "$(( N - ${FIX_K6_AGE:-60} )).000600" UFIX0000002 "new reply $fixChannel" ;;
			*) printf ',' ; msg "$(( N - 70 )).000999" UFIX0000002 "mention-thread reply $fixChannel" ;;
		esac
		printf '],"has_more":false}\n'
	;;
	search.messages)
		printf '{"ok":true,"messages":{"matches":[{"channel":{"id":"CFIXMENT001"},"ts":"%s.000111"}],"paging":{"pages":1,"page":1}}}\n' "$(( N - 1000 ))"
	;;
	*) printf '{"ok":false,"error":"fixture_unknown_method"}\n' ;;
esac
exit 0
