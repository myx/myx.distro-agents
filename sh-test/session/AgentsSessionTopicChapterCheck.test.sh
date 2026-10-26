#!/usr/bin/env bash
## Behavioural check on ThisSession's --set-session-topic and --set-session-chapter (T4 of the
## refactorings epic, DistroAgentsSession.fn.sh): two sibling operations locked to the session of
## the call. The topic is what the session is about (the title in lists and statuses, the
## `session-comment` header of its records, and the thread's root post edited to match); the
## chapter is what it does now (kept in the session's own store, sessions/<id>/chapter, and
## announced in the session thread). The executor of the session sets them; a change by another
## participant goes as an escalation to the executor and up its chain (a bare call is refused with
## the escalation options); nothing is set from a call of no member or no session, or with no text.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own,
## and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigSessionFn="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSessionFn" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSessionFn"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionTopicChapterCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/rig-member" "$rigTmp/skills/rig-part"
for rigMember in rig-member rig-part ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"

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

rigWs="" rigSession="" rigChat="" rigScn="" rigThread="CRIG00001:1760000000.000050"
## The records of a session with an executor (the founder, whose own id is the session's) and a
## participant (joined), as the spawn proxy writes them. The executor's run reports to the console
## user; the participant's to the executor.
rigRec(){ ## run id (also the folder), session id, member, start-context, reports-to
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nworkspace: rigws\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-25 09:00 +0300\nstart-context: %s\nreports-to: %s\n---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$3" "$4" "$5" "$2" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data"
	rigChat="$rigWs/.local/agents/sessions/$rigSession"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
	printf 'rig-member=URIGMEM01=m=M=M=d\nrig-part=URIGPART01=p=P=P=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
	: > "$rigScn/calls"
	printf '%s\n' "$rigThread" > "$rigChat/session.thread"
	rigRec "$rigSession" "$rigSession" rig-member spawned user-rig-console
	rigRec rig-spawn-participant "$rigSession" rig-part joined rig-member
}
rigOut="" rigErr="" rigRc=""
rigCall(){ ## name, role (executor|participant|none), operation and its arguments...
	local callName="$1" callRole="$2" callEnv=() callRc=0
	shift 2
	case "$callRole" in
		executor) callEnv+=( "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_SESSION_ID=$rigSession" "MDAT_SPAWN_AGENT=rig-member" ) ;;
		participant) callEnv+=( "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_SESSION_ID=rig-spawn-participant" "MDAT_SPAWN_AGENT=rig-part" ) ;;
		none) ;;
	esac
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" \
		"MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" "RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" \
		${callEnv[@]+"${callEnv[@]}"} \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 90 -- bash "$rigSessionFn" "$@" ) > "$rigOut" 2> "$rigErr" < /dev/null || callRc=$?
	rigRc="$callRc"
}
rigErrHolds(){ LC_ALL=C grep -c -F -- "$1" "$rigErr" 2> /dev/null || : ; }
rigOutHolds(){ LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || : ; }
rigHeader(){ ## run id, header -- one record header of the session
	LC_ALL=C sed -n "s/^$2: //p" "$rigWs/.local/agents/spawned/$1/$1.spawn.md" 2> /dev/null | head -1
}

echo "-- 1. --set-session-topic, by the executor --"
rigScene topic-exec
rigCall t-1 executor --set-session-topic the rig topic
rigAssert "the executor sets the topic: rc 0 and an OK line"       "$rigRc:$( rigOutHolds 'OK: --set-session-topic' )" "0:1"
rigAssert "the title is the session-comment header of its records" "$( rigHeader "$rigSession" session-comment ):$( rigHeader rig-spawn-participant session-comment )" "the rig topic:the rig topic"
rigAssert "the thread's root post is edited to match (a chat.update)" "$( LC_ALL=C grep -c '^chat.update ' "$rigScn/calls" 2> /dev/null )" 1
rigAssert "no member's message is posted for a topic change"       "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigScn/calls" 2> /dev/null )" 0

echo "-- 2. --set-session-chapter, by the executor --"
rigScene chapter-exec
rigCall c-1 executor --set-session-chapter writing the report
rigAssert "the executor sets the chapter: rc 0 and an OK line"     "$rigRc:$( rigOutHolds 'OK: --set-session-chapter' )" "0:1"
rigAssert "the chapter is kept in the session's own store"         "$( cat "$rigChat/chapter" 2> /dev/null )" "writing the report"
rigAssert "it is announced in the session thread (one post)"       "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigScn/calls" 2> /dev/null ):$( LC_ALL=C grep -c -F 'Session chapter: writing the report' "$rigScn/post.1" 2> /dev/null )" "1:1"

echo "-- 3. a participant's change is an escalation, not a direct set --"
rigScene participant
rigCall p-1 participant --set-session-topic their own topic
rigAssert "a bare call is refused with the escalation options"     "$rigRc:$( rigErrHolds '--escalate-wait' ):$( rigErrHolds '--escalate-enqueue' )" "3:1:1"
rigAssert "nothing was set"                                         "$( rigHeader "$rigSession" session-comment )" ""
rigCall p-2 participant --set-session-chapter doing something else
rigAssert "the chapter is refused the same way, nothing set"       "$rigRc:$( [ -f "$rigChat/chapter" ] && printf written || printf none )" "3:none"

echo "-- 4. nothing is set without a member, a session, or a text --"
rigScene refused
rigCall r-1 none --set-session-topic no member here
rigAssert "from no member's session: refused, nothing set"         "$rigRc:$( rigErrHolds 'no member' ):$( rigHeader "$rigSession" session-comment )" "1:1:"
rigCall r-2 executor --set-session-topic
rigAssert "no text: refused, nothing set"                          "$rigRc:$( rigErrHolds 'syntax is' )" "1:1"
rigCall r-3 executor --set-session-chapter
rigAssert "the chapter takes text too"                             "$rigRc:$( rigErrHolds 'syntax is' )" "1:1"

echo "-- 5. the help --"
for rigOp in --set-session-topic --set-session-chapter ; do
	rigAssert "the help describes $rigOp"                       "$( LC_ALL=C grep -c -E "^		$rigOp( |\$)" "$rigHere/help/Help.DistroAgentsTools.help.md" )" 1
done

echo "-- 6. the intern operations the escalation runs --"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigScene intern
i2rc=0
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" \
	"MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" "RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" \
	python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 90 -- bash "$rigTool" --intern-op-set-session-topic --session-id "$rigSession" via the intern op ) > "$rigScn/i-2.out" 2> "$rigScn/i-2.err" || i2rc=$?
rigAssert "the intern op sets the title the same way"           "$i2rc:$( rigHeader "$rigSession" session-comment )" "0:via the intern op"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ THIS SESSION TOPIC/CHAPTER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_TOPIC_CHAPTER: OK (%d assertions, offline)\n' "$rigPassCount"
