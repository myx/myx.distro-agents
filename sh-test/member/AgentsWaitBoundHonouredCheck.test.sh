#!/usr/bin/env bash
## Behavioural check on a Wait's bound (S5 item 4): no probe holds a wait far past its timeout, and a hit ends the
## round instead of paying a slow source after it. Held, run and not read:
##   1. A SLOW SOURCE DOES NOT OVERRUN THE BOUND. One Slack source whose every call takes 5 s, with a 2 s bound,
##      returns within the bound plus a small margin. Before the fix the probe ran in line unbounded and the whole
##      conversation was paid for: measured 34 s of a 1 s bound.
##   2. A HIT ENDS THE ROUND. A source that has news, read first, with a sleeping source after it: the wait returns
##      with the news at about the first source's own cost, not the sum of both.
##   3. THE CONTROL. The same wait over a source that never has news still waits out its whole bound, so the fix
##      shortens no wait that has nothing to return.
## Offline: a Slack-shaped fake curl first on PATH whose one conversation sleeps on demand, and every tree is the
## rig's own. No request leaves the machine.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitBoundHonouredCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'for rigHold in "$rigTmp"/*/hold ; do [ ! -f "$rigHold" ] || : > "${rigHold%%hold}release" ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScenario" \
	"$rigWs/.local/agents/sessions" "$rigTmp/skills/$rigMember"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
## The fake Slack: a conversation whose name holds SLOW sleeps 5 s on every call; one whose name holds NEWS has a
## message; everything else answers empty at once. Every call is logged with the second it began.
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
case " $* " in
	*api/*) printf '%s %s\n' "$( date +%s )" "${rigChannel:-none}" >> "$RIG_SCENARIO/calls.log" ;;
esac
case "$rigChannel" in *SLOW*) sleep 5 ;; esac
case " $* " in
	*api/auth.test*) printf '{"ok":true,"user_id":"URIGSELF1","user":"rig-self"}\n' ;;
	*api/conversations.info*) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "${rigChannel:-CRIG00001}" ;;
	*api/conversations.open*) printf '{"ok":true,"channel":{"id":"DRIGOWNER1"}}\n' ;;
	*api/conversations.history*)
		case "${rigChannel:-}" in
			*NEWS*) printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-NEWS"}],"has_more":false}\n' "$( date +%s )" ;;
			*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
		esac
	;;
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
mkdir -p "$rigWs/.local/agents/members"
printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember"
printf '%s=URIGSELF1=rig-self=Rig Self=rig-self\n' "$rigMember" > "$rigWs/.local/.agents/slack-mention-ids.cache"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenario/history.CRIG00001.json"

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
rigTimedWait(){ ## name, bound, sources... -- one Wait, and how many seconds it really took
	local timedName="$1" timedBound="$2" timedStart
	shift 2
	: > "$rigScenario/calls.log"
	timedStart="$( date +%s )"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 HOME="$rigTmp/home" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigTool" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "rig-bound-$timedName" \
		--wait-timeout "$timedBound" --wait-poll-interval 1 "$@" ) > "$rigTmp/$timedName.out" 2> "$rigTmp/$timedName.err" < /dev/null || rigRc=$?
	rigTook=$(( $( date +%s ) - timedStart ))
}
rigFirst(){ head -1 "$rigTmp/$1.out" ; }
rigHas(){ LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || : ; }
mkdir -p "$rigTmp/data/inboxes/$rigMember/incoming" "$rigTmp/data/board"

echo "-- 1. a slow source does not overrun the bound --"
rigTimedWait slo1 2 --wait-source slack:CBTSLOW01
rigOneSourceTook=$rigTook
rigTimedWait slo2 2 --wait-source slack:CBTSLOW03 --wait-source slack:CBTSLOW04
rigAssert "a second slow source does not double the wait: one source's cost, not the round's sum" \
	"$([ $(( rigTook - rigOneSourceTook )) -le 8 ] && printf flat || printf doubled )" "flat"
rigAssert "and a 2 s bound over two sources of 5 s each ends within one probe's own cost and a margin" \
	"$([ "$rigTook" -le 20 ] && printf within || printf over )" "within"
printf '  measured: bound 2 s, one slow source %ss, two slow sources %ss, %s\n' "$rigOneSourceTook" "$rigTook" "$( rigFirst slo2 )"

echo "-- 2. a hit ends the round --"
rigTimedWait hit 60 --wait-source slack:CRIGAAANEWS01 --wait-source slack:CRIGZZZSLOW02
rigAssert "a source with news, read first, ends the round: the round's own source line puts it before the sleeping source" \
	"$([ "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/hit.out" | head -1 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -n -x -F slack:CRIGAAANEWS01 | cut -d: -f1)" -lt "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/hit.out" | head -1 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -n -x -F slack:CRIGZZZSLOW02 | cut -d: -f1)" ] && printf ordered || printf reversed )" "ordered"
rigAssert "and the wait returns the news" "$( rigFirst hit ):$( rigHas hit RIG-NEWS )" "WAIT-RESULT: RECEIVED:1"
printf '  measured: bound 60 s, took %ss, the sleeping source after the hit called %s time(s)\n' "$rigTook" "$( LC_ALL=C grep -c 'CRIGZZZSLOW02' "$rigScenario/calls.log" || : )"

echo "-- 3. the control: a wait with nothing to return still waits out its bound --"
rigTimedWait quiet 8 --wait-source slack:CBTQUIET01
rigAssert "a Wait with nothing to return still waits out its whole 8 s bound, so no wait with nothing is shortened" \
	"$([ "$rigTook" -ge 8 ] && printf waited || printf short )" "waited"
rigAssert "and it ends TIMEOUT" "$( rigFirst quiet )" "WAIT-RESULT: TIMEOUT"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the failed calls, for the reader:\n'
	for rigF in slo1 slo2 hit quiet ; do printf '  == %s\n' "$rigF" ; head -c 900 "$rigTmp/$rigF.out" ; done
	echo "⛔ WAIT BOUND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_BOUND_HONOURED: OK (%d assertions, offline)\n' "$rigPassCount"
