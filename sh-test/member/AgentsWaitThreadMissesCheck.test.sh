#!/usr/bin/env bash
## Behavioural check on three things a Wait on an asked question (ask:<pending-id>) must see in a direct conversation with the owner, run against a scenario workspace:
##   1. a question posted under the bot, in a conversation the member's user identity cannot reach, is read under the bot as well (the read takes the identity fallback of a send): the owner's
##      reply there arrives, and the source is not left in WAIT-NEVER-READ
##   2. the replies that come in a question's thread AFTER a readback closed it arrive: the record keeps the readback's ts as its follow-floor, and what the person writes after it is delivered
##   3. a message the owner types at the top of the direct conversation, where the question is one top-level post of it, answers the question as well: Wait reads the conversation, not the thread alone
## A fake curl first on PATH answers by token and method. No request leaves the rig.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTools" ] || rigRefuse "DistroAgentsTools.fn.sh not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to act under"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitThreadMissesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScenario="$rigTmp/scenario"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigWs/.local/temp" "$rigScenario"
cat > "$rigTmp/bin/curl" <<- 'EOF'
	#!/usr/bin/env bash
	set -u
	rigAuth="$( cat )"
	rigMethod="" rigChannel="" rigPrev=""
	for rigArg in "$@" ; do
		case "$rigArg" in
			https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
			channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		esac
	done
	rigWho=user ; case "$rigAuth" in *rig-bot-*) rigWho=bot ;; esac
	printf '%s %s %s\n' "$rigMethod" "$rigWho" "$rigChannel" >> "$RIG_SCENARIO/calls"
	## A conversation of the bot's own: the user identity does not reach it.
	reachable=1 ; [ -f "$RIG_SCENARIO/bot-only" ] && [ "$rigWho" = user ] && reachable=0
	case "$rigMethod" in
		auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
		conversations.info)
			[ "$reachable" = 1 ] || { printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ; }
			if [ -f "$RIG_SCENARIO/is-im" ] ; then printf '{"ok":true,"channel":{"id":"DRIG00001","is_im":true,"is_mpim":false}}\n'
			else printf '{"ok":true,"channel":{"id":"DRIG00001","is_im":false,"is_mpim":false}}\n' ; fi
		;;
		conversations.replies)
			[ "$reachable" = 1 ] || { printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ; }
			cat "$RIG_SCENARIO/replies.json" 2> /dev/null || printf '{"ok":false,"error":"rig_no_replies"}\n'
		;;
		conversations.history)
			[ "$reachable" = 1 ] || { printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ; }
			cat "$RIG_SCENARIO/history.json" 2> /dev/null || printf '{"ok":true,"messages":[],"has_more":false}\n'
		;;
		*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
	esac
EOF
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigSession=0
rigWait(){ ## pending id -- one Wait on the question, in a session of its own; the result in out
	rigSession=$(( rigSession + 1 ))
	: > "$rigScenario/calls"
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" \
		bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "rig-miss-$1" --wait-source "ask:$1" --wait-timeout 6 --wait-poll-interval 1 ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigHas(){ ## text -- how many lines of the last result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/out" || :
}
rigFirst(){ LC_ALL=C sed -n 1p "$rigTmp/out" ; }
rigRecord(){ ## id, status, thread-ts, follow-floor (may be empty), identity (user|bot)
	{
		printf 'status: %s\nsession-id: rig-miss-%s\nowner: %s\nchannel: DRIG00001\nquestion-ts: 1700000001.000101\nthread-ts: %s\naddressees: URIGOWNER\nasking-accounts: URIGSELF1\nkind: question\nask-identity: %s\n' "$2" "$1" "$rigMember" "$3" "$5"
		[ -z "$4" ] || printf 'follow-floor: %s\n' "$4"
		printf '# Thread\n'
	} > "$rigWs/.local/agents/pending/$1.md"
}
rigQuestion='{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}'

echo "-- 1. a question the bot posted, in a conversation the user cannot reach --"
: > "$rigScenario/bot-only"
printf '{"ok":true,"messages":[%s,{"ts":"1700000003.000101","thread_ts":"1700000001.000101","user":"URIGOWNER","text":"RIG-REPLY-ONE"}],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
rigRecord rig-ask-one reply-pending 1700000001.000101 "" user
rigWait rig-ask-one
rigAssert "a record that says the user identity asked, the conversation the bot's own: the owner's reply arrives" "$( rigFirst ) $( rigHas RIG-REPLY-ONE )" "WAIT-RESULT: RECEIVED 1"
rigAssert "and the question is not left unread (the owner DM of the rig cannot be opened, which the defaults may say)" "$( LC_ALL=C grep '^WAIT-NEVER-READ' "$rigTmp/out" | LC_ALL=C grep -c 'ask:rig-ask-one' || : )" "0"
rm -f "$rigScenario/bot-only"

echo "-- 2. a reply after a readback --"
printf '{"ok":true,"messages":[%s,{"ts":"1700000002.000101","thread_ts":"1700000001.000101","user":"URIGSELF1","text":"I take it you mean option A"},{"ts":"1700000003.000101","thread_ts":"1700000001.000101","user":"URIGOWNER","text":"RIG-REPLY-AFTER-READBACK"}],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
rigRecord rig-ask-two reply-received 1700000001.000101 1700000002.000101 bot
rigWait rig-ask-two
rigAssert "the person writes after the readback: that reply is delivered" "$( rigFirst ) $( rigHas RIG-REPLY-AFTER-READBACK )" "WAIT-RESULT: RECEIVED 1"
printf '{"ok":true,"messages":[%s,{"ts":"1700000002.000101","thread_ts":"1700000001.000101","user":"URIGSELF1","text":"I take it you mean option A"},{"ts":"1700000001.500000","thread_ts":"1700000001.000101","user":"URIGOWNER","text":"RIG-REPLY-BEFORE-READBACK"}],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
rigRecord rig-ask-two-b reply-received 1700000001.000101 1700000002.000101 bot
rigWait rig-ask-two-b
rigAssert "control: what stands before the readback is not delivered again" "$( rigHas RIG-REPLY-BEFORE-READBACK )" "0"

echo "-- 3. a message typed at the top of a direct conversation --"
: > "$rigScenario/is-im"
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
printf '{"ok":true,"messages":[{"ts":"1700000004.000101","user":"URIGOWNER","text":"RIG-TOP-LEVEL-ANSWER"},%s],"has_more":false}\n' "$rigQuestion" > "$rigScenario/history.json"
rigRecord rig-ask-three reply-pending 1700000001.000101 "" bot
rigWait rig-ask-three
rigAssert "the owner types in the conversation, not in the thread: the question's Wait delivers it" "$( rigFirst ) $( rigHas RIG-TOP-LEVEL-ANSWER )" "WAIT-RESULT: RECEIVED 1"
printf '{"ok":true,"messages":[%s,{"ts":"1700000002.000101","thread_ts":"1700000001.000101","user":"URIGSELF1","text":"I take it you mean option A"}],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
rigRecord rig-ask-three-b reply-received 1700000001.000101 1700000002.000101 bot
rigWait rig-ask-three-b
rigAssert "and after a readback too: what the owner types at the top of the conversation after it" "$( rigFirst ) $( rigHas RIG-TOP-LEVEL-ANSWER )" "WAIT-RESULT: RECEIVED 1"
rm -f "$rigScenario/is-im"
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$rigQuestion" > "$rigScenario/replies.json"
rigRecord rig-ask-three-c reply-pending 1700000001.000101 "" bot
rigWait rig-ask-three-c
rigAssert "control: in a conversation that is no direct one a top-level message is no answer to the question" "$( rigHas RIG-TOP-LEVEL-ANSWER )" "0"

echo "-- 4. a top-level message of the owner is the reply of the latest post above it, and is returned once --"
## Three top-level posts of the run in the conversation, M1 typed between the first and the second, M2 between the second and the third.
: > "$rigScenario/is-im"
rigSessionDir="$rigWs/.local/agents/sessions/rig-miss-posts"
mkdir -p "$rigSessionDir"
printf '%s\n' \
	"DRIG00001:1700000030.000101 1700000030.000101 URIGOWNER - - 0 - 0" \
	"DRIG00001:1700000020.000101 1700000020.000101 URIGOWNER - - 0 - 0" \
	"DRIG00001:1700000010.000101 1700000010.000101 URIGOWNER - - 0 - 0" > "$rigSessionDir/last-own-post"
printf '{"ok":true,"messages":[{"ts":"1700000010.000101","user":"URIGSELF1","text":"post one"}],"has_more":false}\n' > "$rigScenario/replies.json"
printf '{"ok":true,"messages":[{"ts":"1700000035.000101","user":"URIGOWNER","text":"RIG-M3"},{"ts":"1700000025.000101","user":"URIGOWNER","text":"RIG-M2"},{"ts":"1700000015.000101","user":"URIGOWNER","text":"RIG-M1"},{"ts":"1700000030.000101","user":"URIGSELF1","text":"post three"},{"ts":"1700000020.000101","user":"URIGSELF1","text":"post two"},{"ts":"1700000010.000101","user":"URIGSELF1","text":"post one"}],"has_more":false}\n' > "$rigScenario/history.json"
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
	RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" \
	bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "rig-miss-posts" --wait-timeout 6 --wait-poll-interval 1 ) > "$rigTmp/out" 2> "$rigTmp/err"
rigUnder(){ ## message marker -- the posts whose heading the marker stands under, comma-separated
	LC_ALL=C awk -v mark="$1" '/^# replies to your post / { post = $NF ; sub(/^.*:/, "", post) } index( $0, mark ) { printf "%s%s", sep, post ; sep = "," }' "$rigTmp/out"
}
rigAssert "M1 stands once, under the first post, the latest one above it" "$( rigUnder RIG-M1 )" "1700000010.000101"
rigAssert "M2 stands once, under the second post" "$( rigUnder RIG-M2 )" "1700000020.000101"
rigAssert "M3 stands once, under the third post" "$( rigUnder RIG-M3 )" "1700000030.000101"
rm -f "$rigScenario/is-im"

echo "-- 5. two default Waits in one session: the second resumes after what the first returned --"
now="$( date +%s )"
printf '{"ok":true,"messages":[{"ts":"%s.000101","user":"URIGOWNER","text":"RIG-FIRST-ARRIVAL"}],"has_more":false}\n' "$(( now + 2 ))" > "$rigScenario/history.json"
rigDefault(){ ## session -- one Wait with no sources and a short bound
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" \
		bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "$1" --wait-timeout 8 --wait-poll-interval 1 "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigDefault rig-miss-resume
rigAssert "the first Wait delivers the arrival" "$( rigHas RIG-FIRST-ARRIVAL )" "1"
rigDefault rig-miss-resume
rigAssert "the second Wait, in the same session, does not deliver it again: it resumes after the newest message the first returned" "$( rigHas RIG-FIRST-ARRIVAL )" "0"

echo "-- 6. a named set is the wait's own (sketch 3.2), the stored set never shrinks, a floor lives for a source of the set --"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenario/history.json"
: > "$rigWs/named-a.txt" ; : > "$rigWs/named-b.txt"
rigSourcesOf(){ LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/out" | head -1 ; }
rigDefault rig-miss-named --wait-source "file:$rigWs/named-a.txt"
rigAssert "a default call naming a source watches it in place of the defaults: the file, and no team channel or owner DM" "$( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e slack:magic-team -e slack:human-owner ):$( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e "file:$rigWs/named-a.txt" )" "0:1"
rigDefault rig-miss-named --wait-source "file:$rigWs/named-b.txt"
rigAssert "and the next call, naming another, keeps the first in the stored set: both files" "$( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e "file:$rigWs/named-a.txt" -e "file:$rigWs/named-b.txt" )" "2"
rigDefault rig-miss-named
rigAssert "a call naming nothing keeps them all" "$( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e slack:magic-team -e slack:human-owner -e "file:$rigWs/named-a.txt" -e "file:$rigWs/named-b.txt" )" "4"
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD RIG_SCENARIO="$rigScenario" MDAT_WAIT_REMIND=off MMDAPP="$rigWs" bash "$rigTools" --wait-for-input --team-member "$rigMember" --unwait "file:$rigWs/named-a.txt" --wait-session-id rig-miss-named ) > "$rigTmp/out" 2> "$rigTmp/err"
rigDefault rig-miss-named
rigAssert "only --unwait takes a source out of the stored set" "$( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e "file:$rigWs/named-a.txt" ) $( rigSourcesOf | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e "file:$rigWs/named-b.txt" )" "0 1"
rigAssert "the header says which session thread is on record for the session, or that none is" "$( LC_ALL=C grep -c '^# session thread: ' "$rigTmp/out" )" "1"
rigStateDir="$rigWs/.local/agents/sessions/rig-miss-floors/wait"
mkdir -p "$rigStateDir"
printf 'sources: replies:rig-miss-floors slack:magic-team\naddressee: \ninclude-own: false\nfloor slack:magic-team 1700000100.000001\nfloor slack:CGONE0001 1700000200.000001\nfloor slack:human-owner 1700000300.000001\n' > "$rigStateDir/state"
rigStart="$( date +%s )"
rigDefault rig-miss-floors
rigAssert "the floor of a source of the stored set is used; a source that comes back after a gap starts at the wait's start, not at a stale floor stored for it" "$( LC_ALL=C sed -n 's/^# filters: .*floors=\(.*\) addressee=.*$/\1/p' "$rigTmp/out" | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk -F= -v start="$rigStart" '$1 == "slack:magic-team" { printf "kept=%s ", $2 } $1 == "slack:human-owner" { printf "back=%s", ( $2 + 0 >= start - 2 ) ? "start" : "stale" }' )" "kept=1700000100.000001 back=start"
rigAssert "a floor stored for a source that is not in the set is dropped when the state is written" "$( LC_ALL=C grep -c 'slack:CGONE0001' "$rigStateDir/state" || : )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WAIT THREAD MISSES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_THREAD_MISSES: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
