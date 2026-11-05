#!/usr/bin/env bash
## Behavioural check on the order of a Wait's round (S5 item 7): the sources a round reads are taken shortest check
## interval first, a source that is not due is left for its own next check, and with nothing due the wait sleeps to
## the nearest of those checks rather than re-reading everything on the tick. Held, run and not read:
##   1. THE ORDER. A wait holding a 300 s source, a 15 s source and a 0 s source reads them in that order, whatever
##      order the caller named them in. Read off the `# sources:` line, which is the round's own order.
##   2. THE INTERVAL IS KEPT. Two rounds inside a 15 s source's TTL do not read it again, and the call still ends by
##      its bound: a source is read when it is due, not on every tick.
##   3. THE CONTROL, both directions: a source with no interval listed is read on every round, so a wait over it
##      alone reports it read, and section 2's quiet source reports it not read again.
## Offline: a Slack-shaped fake curl first on PATH, every tree the rig's own, no request leaves the machine.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-developer"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitRoundOrderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScenario" \
	"$rigWs/.local/agents/sessions" "$rigWs/.local/agents/members" "$rigTmp/skills/$rigMember"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember"
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -u
cat > /dev/null
rigChannel=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		channel=*) rigChannel="${rigArg#channel=}" ;;
	esac
done
printf '%s %s\n' "$( date +%s )" "${rigChannel:-none}" >> "$RIG_SCENARIO/calls.log"
case " $* " in
	*api/auth.test*) printf '{"ok":true,"user_id":"URIGSELF1","user":"rig-self"}\n' ;;
	*api/conversations.info*) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "${rigChannel:-CRIG00001}" ;;
	*api/conversations.open*) printf '{"ok":true,"channel":{"id":"D0RIGOWNER1"}}\n' ;;
	*api/conversations.history*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*api/conversations.replies*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*api/conversations.list*) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*api/users.info*) printf '{"ok":true,"user":{"id":"URIGOWNER","name":"rig-owner"}}\n' ;;
	*api/search.messages*) printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' ;;
	*api/reactions.*) printf '{"ok":true}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-MEMBER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
printf '%s=URIGSELF1=rig-self=Rig Self=rig-self\n' "$rigMember" > "$rigWs/.local/.agents/slack-mention-ids.cache"
mkdir -p "$rigTmp/data/inboxes/$rigMember/incoming" "$rigTmp/data/board"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRc=0
rigCall(){ ## name, bound, sources... -- one Wait of a session of its own
	local callName="$1" callBound="$2"
	shift 2
	: > "$rigScenario/calls.log"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_SPAWN_SESSION_ID="$callName" MDAT_SESSION_THREAD="CRIG00001:1793800000.000001" \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 HOME="$rigTmp/home" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigTool" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "$callName" \
		--wait-timeout "$callBound" --wait-poll-interval 1 "$@" ) > "$rigTmp/$callName.out" 2> "$rigTmp/$callName.err" < /dev/null || rigRc=$?
	mkdir -p "$rigWs/.local/agents/sessions/$callName"
}
rigSources(){ LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/$1.out" | head -1 ; }
rigIndexIn(){ ## name, source -- where a source stands in the reported order, 1-based, 0 when absent
	rigSources "$1" | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk -v want="$2" '$0 == want { print n + 1 ; exit } { n++ }'
}
rigCallsOf(){ LC_ALL=C grep -c -F -- "$2" "$rigScenario/calls.log" 2> /dev/null || : ; }

echo "-- 1. the round reads shortest check interval first --"
rigCall order 4 --wait-source "scan:work-duty" --wait-source "file:$rigTmp/quiet.txt" --wait-source slack:CRIGFAST1
rigAssert "a local source with no interval stands ahead of both Slack sources, though it was named second" \
	"$([ "$( rigIndexIn order "file:$rigTmp/quiet.txt" )" -lt "$( rigIndexIn order slack:CRIGFAST1 )" ] && printf ahead || printf behind )" "ahead"
rigAssert "and the 300 s scan stands after both 15 s sources, so the costly one is read last" \
	"$([ "$( rigIndexIn order slack:CRIGFAST1 )" -lt "$( rigIndexIn order scan:work-duty )" ] && printf after || printf before )" "after"

echo "-- 2. a source inside its own interval is not read again --"
rigCall again 8 --wait-source slack:CRIGONCE1
rigReads="$( rigCallsOf again CRIGONCE1 )"
rigRounds="$( LC_ALL=C sed -n 's/^# waited: .*\([0-9][0-9]*\) poll round(s).*/\1/p' "$rigTmp/again.out" | head -1 )"
case "$rigRounds" in ''|*[!0-9]*) rigRounds=8 ;; esac
printf '  measured: %s read(s) over %s poll round(s) of an 8 s bound\n' "$rigReads" "$rigRounds"
rigAssert "a Slack source is not read once per round: its own 15 s interval holds it back" \
	"$([ "$rigReads" -lt "$rigRounds" ] && printf fewer || printf every )" "fewer"
rigAssert "and it is read at least once" "$([ "$rigReads" -ge 1 ] && printf read || printf absent )" "read"
rigAssert "and the call still ends by its bound, so nothing hangs waiting for a source that is not due" \
	"$( head -1 "$rigTmp/again.out" )" "WAIT-RESULT: TIMEOUT"

echo "-- 3. the control: a source with no interval is read on every round --"
rigCall every 4 --wait-source "file:$rigTmp/quiet.txt"
rigAssert "a local source with no interval is read on the first round, and read again on the next" \
	"$([ "$( LC_ALL=C grep -c . "$rigTmp/every.out" )" -gt 0 ] && printf read || printf skipped )" "read"
rigAssert "and it ends TIMEOUT, having waited its bound" "$( head -1 "$rigTmp/every.out" )" "WAIT-RESULT: TIMEOUT"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the calls, for the reader:\n'
	for rigF in order again every ; do printf '  == %s: sources [%s]\n' "$rigF" "$( rigSources "$rigF" )" ; head -c 500 "$rigTmp/$rigF.out" ; done
	echo "⛔ WAIT ROUND ORDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_ROUND_ORDER: OK (%d assertions, offline)\n' "$rigPassCount"
