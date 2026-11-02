#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on what a ThisSession post REPORTS (S26 item 5): a post either lands, with
## its channel and its ts in the result, or fails. A post is never reported as posted while
## lost. (AgentsHarnessMessages.include, AgentsHarnessToolThisSession)
##   1. THE CONTROL: a landed post reports `POSTED`, with the session thread and the ts.
##   2. A post Slack refuses (a message over its size limit, `msg_too_long`) is an ERROR,
##      and never a `POSTED` claim.
##   3. A second refusal shape, `not_in_channel`, is an ERROR too: the check is not reading
##      one Slack error name into a general rule.
## Offline: a Slack-shaped fake curl first on PATH, no model CLI, this check's own rig scenes.
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
rigTmp="$( rigTempDir AgentsThisSessionPostReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The rig is this check's own folder, and something in it may still be finishing a write when the
## trap runs: a folder that is not empty yet is tried again before it is left.
rigCleanup(){
	local cleanTry=0
	while [ "$cleanTry" -lt 5 ] ; do
		rm -rf -- "$rigTmp" 2> /dev/null
		[ -d "$rigTmp" ] || return 0
		cleanTry=$(( cleanTry + 1 ))
		sleep 1
	done
	rm -rf -- "$rigTmp" 2> /dev/null || :
}
trap rigCleanup EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/rig-member"
printf 'rig-member\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigWs="" rigSession="" rigChat="" rigScn="" rigThread="CRIG00001:1760000000.000050"
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data"
	rigChat="$rigWs/.local/agents/sessions/$rigSession"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
	printf 'rig-member=URIGMEM01=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
	: > "$rigScn/calls"
	printf '%s\n' "$rigThread" > "$rigChat/session.thread"
}
rigOut="" rigErr="" rigRc=""
rigCall(){ ## name, arguments json -- one call of the ThisSession tool, as the harness serves it
	local callName="$1" callArgs="$2" callRc=0
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && printf '%s' "$callArgs" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_DATA_ROOT=$rigScn/data" \
		"RIG_SCENARIO=$rigScn" "RIG_CHAT=$rigChat/session.chat" "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_AGENT=rig-member" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool ThisSession ) > "$rigOut" 2> "$rigErr" || callRc=$?
	rigRc="$callRc"
}
rigFirst(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" ; }
rigOutHolds(){ ## fixed text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || :
}

echo "-- 1. the control: a landed post reports its channel and its ts --"
rigScene landed
rigCall post-1 '{"operation":"post","message":"RIG-LANDED hello"}'
rigAssert "it reports POSTED, with the thread and the ts" "$( rigFirst )" "POSTED to your own session thread $rigThread at CRIG00001:1760000000.000101 as rig-member, and recorded in the session chat file first, then posted."

echo "-- 2. a post Slack refuses for its size is an error, never posted --"
rigScene too-long
printf 'msg_too_long\n' > "$rigScn/post-errors"
rigCall post-2 '{"operation":"post","message":"RIG-TOO-LONG hello"}'
rigAssert "it is a failure, with ERROR" "$( rigOutHolds 'ERROR:' )" "1"
rigAssert "and it never claims the post landed" "$( rigOutHolds 'POSTED' )" "0"

echo "-- 3. another Slack refusal is an error too --"
rigScene not-in-channel
printf 'not_in_channel\n' > "$rigScn/post-errors"
rigCall post-3 '{"operation":"post","message":"RIG-NOT-IN-CHANNEL hello"}'
rigAssert "it is a failure, with ERROR" "$( rigOutHolds 'ERROR:' )" "1"
rigAssert "and it never claims the post landed" "$( rigOutHolds 'POSTED' )" "0"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'THIS_SESSION_POST_REPORT: OK\n'
