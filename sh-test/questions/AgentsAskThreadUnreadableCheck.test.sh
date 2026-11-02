#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on an ask whose thread cannot be read (S26 item 8): the collect reports it
## as a tooling fault, and its asker can still close the record.
## (AgentsTools.PendingReplyCollect.include, --intern-op-pending-reply-collect;
##  AgentsTools.MemberPendingReply.include, --settle-pending-reply --withdraw)
##   1. THE CONTROL: a record whose thread reads back unchanged is reported OPEN, not UNREADABLE.
##   2. A thread Slack refuses to hand back is reported UNREADABLE, naming the conversation and
##      the reader's own error: a tooling fault, never an answer and never a quiet.
##   3. The summary line counts it as unreadable, so a caller reading only the count sees it.
##   4. The asker can still close it: the withdraw succeeds and the record leaves pending/.
## Offline: a Slack-shaped fake curl first on PATH, no model CLI, this check's own rig scenes.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
[ -f "$rigFixtures/pending-reply-remind-check.curl.stub.sh" ] || rigRefuse "the pending-reply curl fixture is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAskThreadUnreadableCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
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
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/rig-asker"
printf 'rig-asker\n' > "$rigTmp/skills/rig-asker/rig-asker.basic.md"
cp "$rigFixtures/pending-reply-remind-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
rigWs="" rigScn="" rigSession="rig-sess-ask" rigChannel="CRIGASK01" rigRoot="1760000000.000900" rigId=""
rigScene(){ ## scenario name, pending id
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigId="pending-rig-$2"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data" "$rigWs/.local/agents/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGASK01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-ASKER\n' > "$rigWs/.local/.agents/rig-asker.agent.env"
	printf 'rig-asker=URIGASK01=a=A=A=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
	: > "$rigScn/calls"
	printf -- '---\nowner: rig-asker\nsession-id: %s\nkind: question\nstatus: reply-pending\nchannel: %s\nquestion-ts: %s\nthread-ts: %s\naddressees: URIGASK01\nfirst: Does the rig answer?\n---\n\nDoes the rig answer?\n' \
		"$rigSession" "$rigChannel" "$rigRoot" "$rigRoot" > "$rigWs/.local/agents/pending/$rigId.md"
}
rigCollect(){ ## -- the collect's output
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCENARIO=$rigScn" "RIG_CURL_LOG=$rigScn/calls" "MDAT_SPAWN_AGENT=rig-asker" "MDAT_SESSION_ID=$rigSession" \
		bash "$rigTools" --intern-op-pending-reply-collect --session-id "$rigSession" ) 2>&1
}
rigWithdraw(){ ## -- the settle's output and status
	local settleRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCENARIO=$rigScn" "MDAT_SPAWN_AGENT=rig-asker" "MDAT_SESSION_ID=$rigSession" \
		bash "$rigTools" --settle-pending-reply rig-asker "$rigId" --reason "the rig closes it" --withdraw ) 2>&1 || settleRc=$?
	printf 'SETTLE-EXIT=%s\n' "$settleRc"
}

echo "-- 1. the control: a thread that reads is OPEN, not UNREADABLE --"
rigScene ok control
rigAssert "the record is reported OPEN" "$( rigCollect | LC_ALL=C grep -c -x -F "OPEN $rigId - | Does the rig answer?" )" "1"
rigAssert "and nothing says it could not be read" "$( rigCollect | LC_ALL=C grep -c 'UNREADABLE' || : )" "0"

echo "-- 2. a thread Slack will not hand back is a tooling fault, named --"
rigScene refused unreadable
printf '{"ok":false,"error":"channel_not_found"}\n' > "$rigScn/replies.$rigRoot.json"
rigUnreadable="$( rigCollect )"
rigAssert "the record is reported UNREADABLE" "$( printf '%s\n' "$rigUnreadable" | LC_ALL=C grep -c "^UNREADABLE $rigId " )" "1"
rigAssert "and it names the conversation that could not be read" "$( printf '%s\n' "$rigUnreadable" | LC_ALL=C grep -c -F "$rigChannel:$rigRoot" )" "1"
rigAssert "and it says nothing is known about it" "$( printf '%s\n' "$rigUnreadable" | LC_ALL=C grep -c 'so nothing is known about it' )" "1"

echo "-- 3. the summary counts it, so a caller reading the count sees it --"
rigAssert "the summary says one unreadable" "$( printf '%s\n' "$rigUnreadable" | LC_ALL=C grep -c -E '^COLLECT: .*unreadable=1$' )" "1"

echo "-- 4. the asker can still close it --"
rigSettle="$( rigWithdraw )"
rigAssert "the withdraw succeeds" "$( printf '%s\n' "$rigSettle" | LC_ALL=C sed -n 's/^SETTLE-EXIT=//p' )" "0"
rigAssert "and the record leaves pending/" "$( [ -f "$rigWs/.local/agents/pending/$rigId.md" ] && printf still-there || printf gone )" "gone"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'ASK_THREAD_UNREADABLE: OK\n'
