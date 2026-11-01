#!/usr/bin/env bash
## Behavioural check on ThisSession's read of the participants a session has not brought in yet (S4.7 of the
## refactorings epic): the executor's default list to invite from, held and run rather than read: the operation is
## served by the harness, declared on the tool floor (sh-lib/harness/AgentsOpenAiChatWire.sh) and answered by
## DistroAgentsSession.fn.sh --get-uninvited-participants.
##   1. IT NAMES THE ONES WITH NO RUN: one a line, in the record's order -- the participant that already runs is not
##      named, and an agent-less parent's record is no run of anybody.
##   2. EVERY ONE ALREADY RUNNING, or a record naming no participants: nothing on stdout, one line saying so on
##      stderr, and rc 0 -- never an error.
##   3. A CALL FROM NO SESSION IS REFUSED with ERROR, and no list is printed in its place.
##   4. IT ONLY READS: no Slack call is made, and nothing is posted.
## Offline: a Slack-shaped fake curl is first on PATH, the workspace and its session are folders of the rig's own,
## and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigWire" "$rigFixtures/session-chat.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsThisSessionUninvitedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/rig-member" "$rigTmp/skills/rig-part"
for rigMember in rig-member rig-part rig-late ; do mkdir -p "$rigTmp/skills/$rigMember" ; printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
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
## A workspace of the rig's own: a session with its thread, its spawn records, the team's channel settings.
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
}
## One spawn record of this session: folder, owner, and the extra headers of its frontmatter.
rigRecord(){ ## folder, spawn id, owner, header lines
	local recDir="$rigWs/.local/agents/spawned/$1"
	mkdir -p "$recDir"
	{
		printf '%s\n' '---' "session-id: $rigSession" "spawn-id: $2" "owner: $3"
		printf '%s\n' "$4"
		printf '%s\n' '---' ''
	} > "$recDir/$2.spawn.md"
}

rigOut="" rigErr="" rigRc=""
## One call of the ThisSession tool, from a session by the member named (role nosession: no session at all), as the
## harness serves it.
rigCall(){ ## name, arguments json, role
	local callName="$1" callArgs="$2" callRole="$3" callRc=0
	local -a callEnv=( "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_AGENT=rig-member" )
	case "$callRole" in
		nosession) callEnv=( "MDAT_SPAWN_AGENT=rig-member" ) ;;
	esac
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && printf '%s' "$callArgs" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" \
		"RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" ${callEnv[@]+"${callEnv[@]}"} \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool ThisSession ) > "$rigOut" 2> "$rigErr" || callRc=$?
	rigRc="$callRc"
}
rigLines(){ LC_ALL=C awk 'END { print NR + 0 }' "$rigOut" ; }
## The rig's origin stands outside the rig's workspace, so SystemContext announces itself on its own line
## (myx.distro-system sh-lib/SystemContext.include). That line is the rig's, and production has none: the origin
## stands under the workspace there. Everything else on stdout is the operation's own.
rigList(){ LC_ALL=C grep -v -e '^SystemContext: init: ' "$rigOut" ; }
rigOutHolds(){ ## fixed text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || :
}
rigErrHolds(){ ## fixed text -- how many lines of the harness's own stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigErr" 2> /dev/null || :
}

echo "-- 1. it names the ones with no run, one a line, in the record's order --"
rigScene two-late
rigRecord founder "$rigSession" rig-lead "participants: rig-member rig-part rig-late"
rigRecord run-a run-member rig-member ""
## An agent-less parent's record names its owner too, and that owner has no run of its own in this session.
rigRecord run-b run-parent rig-part "agent-less: true"
rigCall list-1 '{"operation":"get-uninvited-participants"}' session
rigAssert "the read is served, and makes no Slack call"             "$rigRc:$( rigOutHolds 'unknown operation' )" "0:0"
rigAssert "the ones with no run, one a line, in the record's order" "$( rigList )" "rig-part
rig-late"
rigAssert "the participant that already runs is not named"          "$( rigOutHolds 'rig-member' )" 0

echo "-- 2. every one already running is no error, and names nobody --"
rigScene all-running
rigRecord founder "$rigSession" rig-lead "participants: rig-member rig-part"
rigRecord run-a run-member rig-member ""
rigRecord run-c run-part rig-part ""
rigCall list-2 '{"operation":"get-uninvited-participants"}' session
rigAssert "rc 0, a line a participant, and no participant named"   "$rigRc:$( rigList ):$( rigOutHolds 'rig-' )" "0::0"

echo "-- 3. a record naming no participants at all is the same and no error --"
rigScene no-participants
rigRecord founder "$rigSession" rig-lead "description: a session of no participants"
rigCall list-3 '{"operation":"get-uninvited-participants"}' session
rigAssert "rc 0, and no participant named"                         "$rigRc:$( rigOutHolds 'rig-' )" "0:0"
rigAssert "one notice line saying the record names no participants" "$( rigList )" "DistroAgentsSession: NOTICE: --get-uninvited-participants: the record of this session names no participants; any member may be invited"

echo "-- 4. a call from no session is refused --"
rigScene no-session
rigRecord founder "$rigSession" rig-lead "participants: rig-member"
rigCall list-4 '{"operation":"get-uninvited-participants"}' nosession
rigAssert "refused, with ERROR, and no list in its place"           "$( rigOutHolds 'ERROR:' ):$( rigOutHolds 'rig-member' )" "1:0"

echo "-- 5. it only reads --"
rigAssert "no Slack call was made, and nothing was posted"          "$( LC_ALL=C awk 'END { print NR + 0 }' "$rigScn/calls" ):$( [ -f "$rigScn/posts" ] && printf posted || printf none )" "0:none"

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
exit 0
