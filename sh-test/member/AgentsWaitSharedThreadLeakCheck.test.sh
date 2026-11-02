#!/usr/bin/env bash
## Behavioural check on the shared-thread leak of S6.3 (`20261102-refactorings.epic.md`): a member's post
## that is a reply inside a shared thread must not receive every later message of that thread.
##
## The cause: the replies source reads the thread of every own post in mode `thread`, which returns every
## message after the floor, whoever wrote it (`AgentsWaitOwnPostReplies.awk`, its mode `thread`, called at
## `AgentsTools.MemberWaitReplies.include`). Every handback into the team thread is a reply in that one
## thread, so a member's Wait showed it as a reply to its own post, and the member took another session's
## handback for its own.
##
## Held, run through the real Wait against a Slack-shaped fake curl, four messages in one thread, in order:
##   1. the thread's root post;
##   2. the member's own post, a reply in that thread;
##   3. a handback of another member, addressed to the coordinator;
##   4. a message addressed to the member.
## The member's replies floor must return 4 and not 3.
## The control: a post at the TOP of its own thread still returns every reply in it, whoever wrote it.
##
## WHY IT IS RED ON THE TREE BEFORE THE FIX: mode `thread` returns every later message of the thread, so
## message 3 is returned beside message 4, and a member reading its own floor is shown another member's
## handback as if it were a reply to itself.
##
## Offline: a Slack-shaped fake curl first on PATH, opening no socket; every workspace is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigMember="rig-member"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigPackage/sh-lib/member/AgentsWaitOwnPostReplies.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitSharedThreadLeakCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigNow="$( date +%s )"
rigAt(){ ## seconds back from now, microseconds
	printf '%s.%06d' "$(( rigNow - $1 ))" "$2"
}
rigMsg(){ ## ts user text [thread ts] [fields]
	printf '{"ts":"%s","user":"%s","text":"%s"%s%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}" "${5:+,$5}"
}
rigJoin(){ ## messages... -- comma-joined
	local joinOut="" joinOne
	for joinOne in "$@" ; do joinOut="$joinOut${joinOut:+,}$joinOne" ; done
	printf '%s' "$joinOut"
}
rigScene(){ ## name -- one workspace, one session of its own, a fake Slack
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/sessions/$rigSession" "$rigDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
}
rigOwnMeta='"metadata":{"event_type":"rig","event_payload":{"sender":"rig-member"}}'
rigRecord(){ ## record lines, newest first
	printf '%s\n' "$@" > "$rigDir/ws/.local/agents/sessions/$rigSession/last-own-post"
}
rigThread(){ ## channel, thread root ts, then its messages (root first)
	local threadChannel="$1" threadTs="$2"
	shift 2
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/replies.$threadChannel.$threadTs.json"
}
rigHistory(){ ## channel, then its top-level messages
	local historyChannel="$1"
	shift
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/history.$historyChannel.json"
}
rigWait(){ ## output name -- one plain Wait of this rig, killed if it will not return
	local waitName="$1" waitPid waitWatch
	rigOut="$rigDir/$waitName.out"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID \
		-u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigTmp/bin:$PATH" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		bash "$rigTool" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-timeout 4 \
		> "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	( waitLeft=60 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2> /dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2> /dev/null ; sleep 2 ; kill -KILL "$waitPid" 2> /dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2> /dev/null
	kill -TERM "$waitWatch" 2> /dev/null
	wait "$waitWatch" 2> /dev/null || :
}
rigHolds(){ ## text -- yes when the last output holds it
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C grep -q -F -- "$1" "$rigOut" && printf yes || printf no
}
rigFirstLine(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" 2> /dev/null || : ; }

## ---- 1. a post that is a reply in a shared thread ----
echo "-- 1. a member's post inside a shared thread returns the message to it, and not another member's handback --"
rigScene shared
rigRoot="$( rigAt 400 100 )"
rigOwn="$( rigAt 300 100 )"
rigHandback="$( rigAt 200 100 )"
rigToMe="$( rigAt 100 100 )"
rigRecord "CRIG00001:$rigRoot $rigOwn URIGADDR1 - - 0 - 0"
rigThread CRIG00001 "$rigRoot" \
	"$( rigMsg "$rigRoot" URIGOWNER2 'RIG-ROOT of the team thread' '' )" \
	"$( rigMsg "$rigOwn" URIGSELF1 'RIG-OWN post in the shared thread' "$rigRoot" "$rigOwnMeta" )" \
	"$( rigMsg "$rigHandback" URIGOTHER 'RIG-HANDBACK of another run, to the coordinator' "$rigRoot" )" \
	"$( rigMsg "$rigToMe" URIGADDR1 'RIG-MESSAGE-TO-ME' "$rigRoot" )"
rigWait shared
rigAssert "the wait returned RECEIVED"                          "$( rigFirstLine )" "WAIT-RESULT: RECEIVED"
rigAssert "the message addressed to the member is returned"     "$( rigHolds 'RIG-MESSAGE-TO-ME' )" yes
rigAssert "another member's handback in that thread is NOT"     "$( rigHolds 'RIG-HANDBACK' )" no
rigAssert "and the run's own post is not returned to itself"    "$( rigHolds 'RIG-OWN post in the shared thread' )" no

## ---- 2. the control: a post at the top of its own thread ----
echo "-- 2. control: a post at the top of its own thread still returns every reply in it --"
rigScene own-thread
rigOwn="$( rigAt 300 100 )"
rigByA="$( rigAt 200 100 )"
rigByB="$( rigAt 100 100 )"
rigRecord "CRIGDM001:$rigOwn $rigOwn URIGADDR1 - - 0 - 0"
rigThread CRIGDM001 "$rigOwn" \
	"$( rigMsg "$rigOwn" URIGSELF1 'RIG-QUESTION of the run' '' "$rigOwnMeta" )" \
	"$( rigMsg "$rigByA" URIGOTHER 'RIG-REPLY-BY-A' "$rigOwn" )" \
	"$( rigMsg "$rigByB" URIGOTHER2 'RIG-REPLY-BY-B' "$rigOwn" )"
rigHistory CRIGDM001 "$( rigMsg "$rigOwn" URIGSELF1 'RIG-QUESTION of the run' '' "$rigOwnMeta" )"
rigWait own-thread
rigAssert "the wait returned RECEIVED"                          "$( rigFirstLine )" "WAIT-RESULT: RECEIVED"
rigAssert "a reply by one person in the run's own thread"       "$( rigHolds 'RIG-REPLY-BY-A' )" yes
rigAssert "and a reply by another"                              "$( rigHolds 'RIG-REPLY-BY-B' )" yes
rigAssert "and the run's own post is still not returned"        "$( rigHolds 'RIG-QUESTION of the run' )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SHARED THREAD LEAK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SHARED_THREAD_LEAK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
