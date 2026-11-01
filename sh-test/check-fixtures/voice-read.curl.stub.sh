#!/usr/bin/env bash
## Slack-shaped fake curl for AgentsVoiceTranscriptCheck.test.sh. Opens no socket. Answers a conversation from
## history.<channel>.json, a thread from replies.<channel>.<ts>.json, a file's metadata from file.<file-id>.json, and a download of any other https URL from
## clip.bin, reported to curl's own -w line as 200 with its size. Every call is logged by its method and argument in calls: `conversations.history <channel>`,
## `files.info <file-id>`, `download <url>`.
set -u
rigStdin="$( cat )"
rigUrl=""
rigMethod="no-method"
rigChannel=""
rigFileId=""
rigTs=""
rigDest=""
rigNext=""
for rigArg in "$@" ; do
	if [ "$rigNext" = "output" ] ; then rigDest="$rigArg" ; rigNext="" ; continue ; fi
	case "$rigArg" in
		-o|--output) rigNext="output" ; continue ;;
		https://slack.com/api/*)
			rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}"
		;;
		https://*|http://*) rigUrl="$rigArg" ;;
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		file@*) rigFileId="$( cat "${rigArg#file@}" 2> /dev/null )" ;;
		channel=*) rigChannel="${rigArg#channel=}" ;;
		file=*) rigFileId="${rigArg#file=}" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2> /dev/null )" ;;
		ts=*) rigTs="${rigArg#ts=}" ;;
	esac
done
[ -n "${RIG_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
case "$rigMethod" in
	no-method)
		case "$rigUrl" in
			'') printf '⛔ rig: a curl call named neither an api method nor a download url\n' >&2 ; exit 7 ;;
			*)
				printf 'download %s\n' "$rigUrl" >> "$RIG_SCENARIO/calls"
				if [ -n "$rigDest" ] ; then cat "$RIG_SCENARIO/clip.bin" > "$rigDest" ; else cat "$RIG_SCENARIO/clip.bin" ; fi
				## curl's own -w report: http status, bytes, content type, on the last line.
				printf '200 %s application/octet-stream\n' "$( LC_ALL=C wc -c < "$RIG_SCENARIO/clip.bin" | LC_ALL=C tr -d ' ' )"
				exit 0
			;;
		esac
	;;
esac
printf '%s %s\n' "$rigMethod" "${rigChannel:-${rigFileId:-}}" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"UVOICESELF","user":"rig-voice"}\n'
	;;
	users.info)
		printf '{"ok":true,"user":{"id":"UVOICEPERSON","name":"rig-voice-person","real_name":"Rig Voice Person"}}\n'
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
	files.info)
		if [ -f "$RIG_SCENARIO/file.$rigFileId.json" ] ; then
			cat "$RIG_SCENARIO/file.$rigFileId.json"
		else
			printf '{"ok":false,"error":"file_not_found"}\n'
		fi
	;;
	*)
		printf '{"ok":false,"error":"rig_unhandled"}\n'
	;;
esac
