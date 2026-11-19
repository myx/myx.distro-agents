#!/usr/bin/env bash
## Behavioural check on a source's first read inside a short Wait (AgentsTools.MemberWaitRun.include, "THE SOURCE'S OWN BOUND").
## The bound decides when a wait returns, never which sources it reads (owner ruling 2026-10-31): a source not yet read in the
## call gets its whole read bound (MDAT_SLACK_READ_BOUND_SECONDS), and only a source read once is cut to the deadline. Held:
##   1. a 1 s bound over one Slack thread whose replies call takes 3 s and holds news: RECEIVED with the news, nothing never-read
##   2. the guard: a Slack thread that never answers, then one with news, a 1 s bound and a read bound of 4 s: the wait names the
##      silent thread never read, reads the one after it, and costs at most one read bound and a margin over the same wait with a
##      quiet thread in its place, its control, measured in the same rig just before
##   3. the same guard on whole conversations, whose history call never answers: every source read is bounded, a thread or not,
##      and a conversation is read once a round, so it too costs one read bound
## Offline: a Slack-shaped fake curl first on PATH, and every tree is the rig's own. No request leaves the machine.
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
rigTmp="$( rigTempDir AgentsWaitFirstReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
## The release ends every fake call still held, so no sleeping stub outlives the rig.
trap ': > "$rigScenario/release" 2> /dev/null ; sleep 2 ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScenario" \
	"$rigWs/.local/agents/sessions" "$rigWs/.local/agents/members" "$rigTmp/skills/$rigMember" "$rigTmp/data/board"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
## The fake Slack: the replies of a thread whose channel name holds SLOW take 3 s, a thread or a conversation whose name holds HANG
## answers only at the release, and one whose name holds NEWS has a message newer than the floor. A thread is ours, rig-self's post, which
## the human-owner answers: the poster's own account never answers its post (AgentsSlackThreadAnswers.awk). Everything else answers empty at once.
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
	*api/conversations.replies*|*api/conversations.history*)
		case "$rigChannel" in *HANG*) printf '%s\n' "$rigChannel" >> "$RIG_SCENARIO/hang.calls" ;; esac
		case "$rigChannel:$*" in
			*SLOW*api/conversations.replies*) sleep 3 ;;
			*HANG*) rigHeld=0 ; while [ ! -f "$RIG_SCENARIO/release" ] && [ "$rigHeld" -lt 60 ] ; do sleep 1 ; rigHeld=$(( rigHeld + 1 )) ; done ;;
		esac
		case "$rigChannel:$*" in
			*NEWS*api/conversations.history*) printf '{"ok":true,"messages":[{"ts":"1700000001.000201","user":"URIGOWNER","text":"RIG-NEWS"}],"has_more":false}\n' ;;
			*api/conversations.history*) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
			*NEWS*) printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the thread"},{"ts":"1700000001.000201","user":"URIGOWNER","text":"RIG-NEWS","thread_ts":"1700000001.000101"}],"has_more":false}\n' ;;
			*) printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the thread"}],"has_more":false}\n' ;;
		esac
	;;
	*api/auth.test*) printf '{"ok":true,"user_id":"URIGSELF1","user":"rig-self"}\n' ;;
	*api/conversations.info*) printf '{"ok":true,"channel":{"id":"%s","is_im":false,"is_mpim":false}}\n' "${rigChannel:-CRIG00001}" ;;
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
printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember"
printf '%s=URIGSELF1=rig-self=Rig Self=rig-self\n' "$rigMember" > "$rigWs/.local/.agents/slack-mention-ids.cache"

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
## One Wait with a 1 s bound, and how many seconds it really took. A wait still running at 40 s is ended, so an unbounded read reads as over.
rigTimedWait(){ ## name, read bound seconds, sources...
	local timedName="$1" timedReadBound="$2" timedStart
	shift 2
	timedStart="$( date +%s )"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD -u MDAT_WAIT_CACHE_ONLY \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 MDAT_SLACK_READ_BOUND_SECONDS="$timedReadBound" HOME="$rigTmp/home" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 40 -- bash "$rigTool" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "rig-first-read-$timedName" \
		--wait-timeout 1 --wait-poll-interval 1 --wait-since-utime 1700000001.000101 "$@" ) > "$rigTmp/$timedName.out" 2> "$rigTmp/$timedName.err" < /dev/null || :
	rigTook=$(( $( date +%s ) - timedStart ))
}
rigFirst(){ head -1 "$rigTmp/$1.out" ; }
rigHas(){ LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || : ; }
rigNeverRead(){ ## result name -- the WAIT-NEVER-READ line, or none
	local neverLine
	neverLine="$( LC_ALL=C sed -n 's/^WAIT-NEVER-READ: //p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${neverLine:-none}"
}
## Where a source stands in the round's own order, from the result's sources line.
rigSourcePlace(){ ## result name, source
	LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/$1.out" | head -1 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -n -x -F -- "$2" | cut -d: -f1
}

echo "-- 1. a 1 s bound, and a source whose first read takes 3 s: it is read --"
rigTimedWait slow 30 --wait-source slack:CRIGSLOWNEWS01:1700000001.000101:conversation
rigAssert "the first read completes past the deadline, so the wait returns its news" "$( rigFirst slow ):$( rigHas slow RIG-NEWS )" "WAIT-RESULT: RECEIVED:1"
rigAssert "and nothing is named never read" "$( rigNeverRead slow )" "none"
printf '  measured: bound 1 s, a 3 s first read, took %ss\n' "$rigTook"

echo "-- 2. the guard: a source that never answers costs one read bound, and the source after it is read --"
rigTimedWait quiet 4 --wait-source slack:CRIGAAAQUIET01:1700000001.000101:conversation --wait-source slack:CRIGZZZNEWS01:1700000001.000101:conversation
rigQuietTook="$rigTook"
rigTimedWait hang 4 --wait-source slack:CRIGAAAHANG01:1700000001.000101:conversation --wait-source slack:CRIGZZZNEWS01:1700000001.000101:conversation
rigAssert "the silent source is read before the one with news, in the round's own order" \
	"$( [ "$( rigSourcePlace hang slack:CRIGAAAHANG01:1700000001.000101:conversation )" -lt "$( rigSourcePlace hang slack:CRIGZZZNEWS01:1700000001.000101:conversation )" ] 2> /dev/null && printf ordered || printf other )" "ordered"
rigAssert "the source after the silent one is read: the wait returns its news" "$( rigFirst hang ):$( rigHas hang RIG-NEWS )" "WAIT-RESULT: RECEIVED:1"
rigAssert "the silent source is named never read" "$( rigNeverRead hang )" "[slack:CRIGAAAHANG01:1700000001.000101:conversation]"
rigAssert "and it is read once in its round" "$( LC_ALL=C grep -c -x CRIGAAAHANG01 "$rigScenario/hang.calls" || : )" "1"
## One read bound of 4 s, 1 s to end the read, and 6 s for the load between two runs: far under the 60 s an unbounded read is held.
rigAssert "the silent source costs at most one read bound and a margin over its quiet control" "$( [ $(( rigTook - rigQuietTook )) -le 11 ] && printf within || printf over )" "within"
printf '  measured: bound 1 s, read bound 4 s, a silent source then one with news, took %ss, its quiet control %ss\n' "$rigTook" "$rigQuietTook"

echo "-- 3. the guard on whole conversations: one that never answers costs one read bound, and the one after it is read --"
rigTimedWait chanquiet 4 --wait-source slack:CRIGAAAQUIET02 --wait-source slack:CRIGZZZNEWS02
rigQuietTook="$rigTook"
rigTimedWait chan 4 --wait-source slack:CRIGAAAHANG02 --wait-source slack:CRIGZZZNEWS02
rigAssert "the conversation after the silent one is read: the wait returns its news" "$( rigFirst chan ):$( rigHas chan RIG-NEWS )" "WAIT-RESULT: RECEIVED:1"
rigAssert "the silent conversation is named never read" "$( rigNeverRead chan )" "[slack:CRIGAAAHANG02]"
rigAssert "and it is read once in its round, never a second time after its first read failed" "$( LC_ALL=C grep -c -x CRIGAAAHANG02 "$rigScenario/hang.calls" || : )" "1"
rigAssert "the silent conversation costs at most one read bound and a margin over its quiet control" "$( [ $(( rigTook - rigQuietTook )) -le 11 ] && printf within || printf over )" "within"
printf '  measured: bound 1 s, read bound 4 s, a silent conversation then one with news, took %ss, its quiet control %ss\n' "$rigTook" "$rigQuietTook"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '  --- the failed calls, for the reader:\n'
	for rigF in slow hang chan ; do printf '  == %s\n' "$rigF" ; head -c 900 "$rigTmp/$rigF.out" ; done
	echo "⛔ WAIT FIRST READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_FIRST_READ: OK (%d assertions, offline)\n' "$rigPassCount"
