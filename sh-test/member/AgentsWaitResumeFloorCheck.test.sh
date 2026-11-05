#!/usr/bin/env bash
## Behavioural check on a resumed Wait's floor for the sources that are not Slack ones (S5.4): a tag, a direct
## message and a mention that land while the run is busy between two Wait calls are returned by the next call.
##   1. A tag posted between two Waits of one session is returned by the second. The first call reads the team
##      channel from its own start, so the tag does not exist for it, and the second must not start there too.
##   2. The same tag is returned once: a third call returns it again for nothing.
##   3. A direct message posted between two Waits is returned by the second.
##   4. Control, the same shape with nothing posted: the second call is quiet, so neither source is an echo.
## The state the fixes are held by: `wait/state` carries a `floor tagged:<member>` and a `floor dms:<member>` line,
## the words the Slack sources already keep.
## Offline: a Slack-shaped fake curl first on PATH, every tree the rig's own, no request leaves the machine.
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
rigTmp="$( rigTempDir AgentsWaitResumeFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScenario" \
	"$rigWs/.local/agents/sessions" "$rigWs/.local/agents/spawned/rig" "$rigTmp/skills/$rigMember"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
## One fake Slack: a channel's messages from history.<channel>.json, the direct conversations from dms.json, each
## read from history.<channel>.json too, a search answered empty, a reaction counted.
set -u
rigStdin="$( cat )"
rigMethod="no-method" rigChannel="" rigTs=""
for rigArg in "$@" ; do
	case "$rigArg" in
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		channel=*) rigChannel="${rigArg#channel=}" ;;
		ts@*) rigTs="$( cat "${rigArg#ts@}" 2> /dev/null )" ;;
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s %s\n' "$rigMethod" "$rigChannel" >> "$RIG_SCENARIO/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1","user":"rig-self"}\n' ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"D0RIGOWNER1"}}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"user":"URIGOWNER"}}\n' "$rigChannel" ;;
	conversations.list)
		if [ -f "$RIG_SCENARIO/dms.json" ] ; then
			printf '{"ok":true,"channels":%s,"response_metadata":{"next_cursor":""}}\n' "$( cat "$RIG_SCENARIO/dms.json" )"
		else
			printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n'
		fi
	;;
	conversations.history)
		cat "$RIG_SCENARIO/history.$rigChannel.json" 2> /dev/null || printf '{"ok":true,"messages":[],"has_more":false}\n'
	;;
	conversations.replies)
		cat "$RIG_SCENARIO/replies.$rigChannel.$rigTs.json" 2> /dev/null || printf '{"ok":true,"messages":[],"has_more":false}\n'
	;;
	search.messages)
		printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n'
	;;
	reactions.add|reactions.remove) printf '{"ok":true}\n' ;;
	users.info) printf '{"ok":true,"user":{"id":"URIGOWNER","name":"rig-owner","real_name":"Rig Owner"}}\n' ;;
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
printf '[{"id":"D0RIGOWNER1","is_im":true,"user":"URIGOWNER"}]\n' > "$rigScenario/dms.json"
rigSession="rig-resume-floor"
mkdir -p "$rigWs/.local/agents/sessions/$rigSession/wait"
## THE SESSION HAS ITS OWN THREAD, as the duty on MDV had: the team channel is then no default source of the wait, so
## nothing but the tags can read it. That is the shape in which the tag was lost.
rigThreadTs="$( date +%s ).000001"
printf 'CRIGTHRD01:%s\n' "$rigThreadTs" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
rigThreadRef="CRIGTHRD01:$rigThreadTs"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenario/history.CRIGTHRD01.json"
## THE RUN IS A WORK DUTY (the floor that carries tagged: and dms:). The record is read at its exact path.
printf -- '---\nrun-process: 1 x\nroutine: %s.work-duty.routine.md\n---\n' "$rigMember" > "$rigWs/.local/agents/spawned/rig/$rigSession.spawn.md"

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
## A message of the channel, its ts, its account, its text.
rigTeamMsg(){ printf '{"ts":"%s","user":"%s","text":"%s"}' "$1" "$2" "$3" ; }
rigTeam(){ ## ts user text... -- replaces the channel's messages with these
	local teamOut="" teamOne
	while [ $# -gt 0 ] ; do
		teamOne="$( rigTeamMsg "$1" "$2" "$3" )" || return 1
		teamOut="$teamOut${teamOut:+,}$teamOne"
		shift 3
	done
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$teamOut" > "$rigScenario/history.CRIG00001.json"
}
rigDm(){ ## ts user text... -- replaces the owner DM's messages
	local dmOut="" dmOne
	while [ $# -gt 0 ] ; do
		dmOne="$( rigTeamMsg "$1" "$2" "$3" )" || return 1
		dmOut="$dmOut${dmOut:+,}$dmOne"
		shift 3
	done
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$dmOut" > "$rigScenario/history.D0RIGOWNER1.json"
}
rigCall(){ ## name, mode, bound -- one Wait of the session
	local callRc=0
	: > "$rigScenario/calls"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT \
		MDAT_SESSION_THREAD="$rigThreadRef" \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 MDAT_SPAWN_SANDBOX_ROOT="$rigWs/.local/agents/spawned/rig" \
		HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigTool" --wait-for-input --team-member "$rigMember" "--wait-$2" --wait-session-id "$rigSession" --wait-timeout "$3" --wait-poll-interval 1 ) \
		> "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigTmp/$1.rc"
}
rigFirst(){ head -1 "$rigTmp/$1.out" ; }
rigHas(){ LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || : ; }
rigFloors(){ LC_ALL=C grep -c "^floor $2 " "$rigWs/.local/agents/sessions/$rigSession/wait/state" 2> /dev/null || : ; }

rigData="$rigTmp/data"
mkdir -p "$rigData/inboxes/$rigMember/incoming" "$rigData/board"
rigNow="$( date +%s )"
echo "-- 1. a tag posted between two Waits of one session is returned by the second --"
## Two messages of the channel stand before the run: the first call reads the channel from its own start, so it
## returns neither, and the tag is posted after it.
rigTeam "$(( rigNow - 300 )).000101" U0RIGOTHER "RIG-OLD-ONE" \
	"$(( rigNow - 200 )).000101" U0RIGOTHER "RIG-OLD-TWO"
rigDm "$(( rigNow - 400 )).000101" URIGOWNER "RIG-OLD-DM"
rigCall first default 30
rigAssert "the first call reads both sources and is quiet, with nothing for it yet" \
	"$( rigFirst first ):$( rigHas first RIG-OLD-ONE )" "WAIT-RESULT: TIMEOUT:0"
rigAssert "and it names the duty's tags and DMs among its sources" \
	"$( LC_ALL=C grep -c -E '^# sources: .*tagged:rig-member' "$rigTmp/first.out" || : )" "1"
rigAssert "and the team channel is no source of its own, so only the tags can read it" \
	"$( LC_ALL=C grep -c -E '^# sources: .*slack:magic-team' "$rigTmp/first.out" || : )" "0"
## The tag lands while the run works: the owner tags the member in the team channel, its ts taken as it is posted.
rigTagTs="$( date +%s ).000301"
rigTeam "$(( rigNow - 300 )).000101" U0RIGOTHER "RIG-OLD-ONE" \
	"$(( rigNow - 200 )).000101" U0RIGOTHER "RIG-OLD-TWO" \
	"$rigTagTs" URIGOWNER "<@URIGSELF1> RIG-TAG-BETWEEN"
## THE RUN IS BUSY FOR A WHILE BETWEEN THE TWO CALLS, as the duty on MDV was for hours: the tags are read on a 15 s
## TTL, so a second call straight after the first reads neither source at all and would prove nothing.
sleep 16
rigCall second default 40
rigAssert "a tag posted while the run worked is returned by its next Wait" \
	"$( rigFirst second ):$( rigHas second RIG-TAG-BETWEEN )" "WAIT-RESULT: RECEIVED:1"
rigAssert "the state keeps a floor for the tags, as it keeps one for a Slack source" \
	"$( rigFloors . "tagged:$rigMember" )" "1"
echo "-- 2. the same tag is returned once --"
rigCall third default 30
rigAssert "a third Wait of the session does not return that tag again" \
	"$( rigHas third RIG-TAG-BETWEEN )" "0"

echo "-- 3. a direct message posted between two Waits is returned by the second --"
sleep 16
rigCall fourth default 30
rigAssert "control: the fourth call is quiet too" "$( rigFirst fourth )" "WAIT-RESULT: TIMEOUT"
rigDmTs="$( date +%s ).000401"
rigDm "$(( rigNow - 400 )).000101" URIGOWNER "RIG-OLD-DM" \
	"$rigDmTs" URIGOWNER "RIG-DM-BETWEEN"
sleep 16
rigCall fifth default 40
rigAssert "a direct message posted while the run worked is returned by its next Wait" \
	"$( rigFirst fifth ):$([ "$( rigHas fifth RIG-DM-BETWEEN )" -ge 1 ] && printf shown || printf absent )" "WAIT-RESULT: RECEIVED:shown"
rigAssert "and nothing from before the run is returned with it" \
	"$( rigHas fifth RIG-OLD-DM )" "0"
rigAssert "the state keeps a floor for the DMs too" \
	"$( rigFloors . "dms:$rigMember" )" "1"

echo "-- 4. control: with nothing posted between two Waits, the second is quiet --"
sleep 16
rigCall sixth default 30
sleep 16
rigCall seventh default 40
rigAssert "a Wait with nothing new posted between it and the one before returns nothing" \
	"$( rigFirst seventh )" "WAIT-RESULT: TIMEOUT"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the last call that failed, for the reader:\n'
	head -c 2000 "$rigTmp/second.out" 2> /dev/null
	head -c 800 "$rigTmp/second.err" 2> /dev/null
	echo "⛔ WAIT RESUME FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_RESUME_FLOOR: OK (%d assertions, offline)\n' "$rigPassCount"
