#!/usr/bin/env bash
## Behavioural check on AgentsToolsCommsSlackConversationsRoster's handle lookup:
## it must never fetch the whole workspace's users.list, paged or not, and must
## instead resolve each conversation's counterparty by one users.info call per
## distinct id the scan actually saw. A fake curl first on PATH logs each method
## and its own query params; offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackRosterNarrowedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/usr/bin/env bash
set -u
rigHeader="$( cat )"
rigMethod="" rigUser="" rigCursor=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		## --intern-op-slack-call's own form values arrive as curl's own
		## name@<path-to-a-file-holding-the-value> form, not name=value inline.
		user@*) rigUser="$( cat "${rigArg#user@}" 2>/dev/null )" ;;
		cursor@*) rigCursor="$( cat "${rigArg#cursor@}" 2>/dev/null )" ;;
		user=*) rigUser="${rigArg#user=}" ;;
		cursor=*) rigCursor="${rigArg#cursor=}" ;;
	esac
done
printf '%s user=%s cursor=%s\n' "$rigMethod" "${rigUser:--}" "${rigCursor:--}" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test)
		printf '{"ok":true,"user_id":"UBOTSELF1","user":"magicteam"}\n'
	;;
	conversations.list)
		printf '{"ok":true,"channels":[{"id":"D1","is_im":true,"is_mpim":false,"user":"UCOUNTERPARTY1","is_user_deleted":false},{"id":"D2","is_im":true,"is_mpim":false,"user":"UCOUNTERPARTY2","is_user_deleted":false}],"response_metadata":{"next_cursor":""}}\n'
	;;
	users.info)
		case "$rigUser" in
			UCOUNTERPARTY1) printf '{"ok":true,"user":{"id":"UCOUNTERPARTY1","name":"alice"}}\n' ;;
			UCOUNTERPARTY2) printf '{"ok":true,"user":{"id":"UCOUNTERPARTY2","name":"bob"}}\n' ;;
			*) printf '{"ok":false,"error":"user_not_found"}\n' ;;
		esac
	;;
	users.list)
		printf '{"ok":true,"members":[]}\n'
	;;
	*)
		printf '{"ok":false,"error":"unexpected_method"}\n'
	;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
RIG_SCENARIO="$rigTmp"
export RIG_SCENARIO
: > "$rigTmp/calls"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

rigOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --magic-comms-slack-conversations-roster magic-team --identity bot 2>&1 )" || rigRc=$?
LC_ALL=C grep -q '^auth.test ' "$rigTmp/calls" || rigRefuse "auth.test never reached the fake curl at all, so nothing below would be measured"

rigAssert "the whole user directory is never fetched" "$( LC_ALL=C grep -c '^users.list ' "$rigTmp/calls" )" 0
rigAssert "exactly one users.info call per distinct counterparty" "$( LC_ALL=C grep -c '^users.info ' "$rigTmp/calls" )" 2
rigAssert "the first counterparty is named" "$( printf '%s' "$rigOut" | grep -c 'counterparty=UCOUNTERPARTY1|handle=alice' )" 1
rigAssert "the second counterparty is named" "$( printf '%s' "$rigOut" | grep -c 'counterparty=UCOUNTERPARTY2|handle=bob' )" 1
rigAssert "the roster is reported complete" "$( printf '%s' "$rigOut" | grep -c '^ROSTER_STATUS=complete$' )" 1

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
