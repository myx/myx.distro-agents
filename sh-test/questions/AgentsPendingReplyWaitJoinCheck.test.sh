#!/usr/bin/env bash
## Behavioural check that a question joins its session's stored wait at once (--intern-op-pending-reply-open,
## sh-lib/questions/AgentsTools.InternOpPendingReply.include): an asking call that the client cut off still has its
## answer collected by the session's next Wait, because the ask is already in the stored wait. Run through the real
## operation, in a rig workspace of its own, then read back through a separate path: the stored wait file itself.
## Held:
##   1. a question opened with --session-id <session> puts `ask:<its id>` in the `sources:` line of sessions/<session>/wait/state, once
##   2. a second question of the session adds its own id and keeps the first: both are there, once each
##   3. a question opened with another session's id joins that session's wait only
##   4. a question opened with no --session-id joins no session's stored wait and makes none
## Able to fail: the code before the fix opened the record and left the wait alone, so rows 1-3 read 0 lines. The
## rows compare the count of exact lines, and each has a control that the question was opened at all.
## Offline: no Slack and no endpoint; the rig is a workspace under this workspace's scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool file is not at the origin: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPendingReplyWaitJoinCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/agents/sessions/rig-sess-a" "$rigWs/.local/agents/sessions/rig-sess-b" "$rigSkills/rig-member" "$rigData/board/running" "$rigTmp/home"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOpen(){ ## session id or empty -- opens a question, prints its id
	printf '# Ask\n\nMay I?\n' | ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$PATH" MDAT_WORKSPACE_MODE=team-rig MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-pending-reply-open rig-member --to CRIG00001 ${1:+--session-id "$1"} --kind question \
		--channel CRIG00001 --question-ts 1700000000.000100 --thread-ts 1700000000.000100 --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2> "$rigTmp/open.err" )
}
rigLines(){ ## session, source -- how many times the source stands in the `sources:` line of the session's stored wait
	LC_ALL=C awk -v want="$2" '$1 == "sources:" { for ( fieldNo = 2 ; fieldNo <= NF ; fieldNo++ ) if ( $fieldNo == want ) hits++ } END { print hits + 0 }' "$rigWs/.local/agents/sessions/$1/wait/state" 2> /dev/null || printf 0
}

echo "-- 1. a question opened for a session joins its stored wait at once --"
rigIdA1="$( rigOpen rig-sess-a )"
rigAssert "control: the operation printed an id, and wrote its record" "$( [ -n "$rigIdA1" ] && [ -f "$rigWs/.local/agents/pending/$rigIdA1.md" ] && echo yes || echo no )" yes
rigAssert "the session's stored wait holds ask:<id>, once" "$( rigLines rig-sess-a "ask:$rigIdA1" )" 1

echo "-- 2. a second question adds its own and keeps the first --"
rigIdA2="$( rigOpen rig-sess-a )"
rigAssert "control: a second, other id" "$( [ -n "$rigIdA2" ] && [ "$rigIdA2" != "$rigIdA1" ] && echo yes || echo no )" yes
rigAssert "both asks stand in the wait, once each" "$( rigLines rig-sess-a "ask:$rigIdA1" ):$( rigLines rig-sess-a "ask:$rigIdA2" )" "1:1"

echo "-- 3. another session's question joins that session's wait only --"
rigIdB1="$( rigOpen rig-sess-b )"
rigAssert "control: the question was opened" "$( [ -n "$rigIdB1" ] && echo yes || echo no )" yes
rigAssert "session b holds its own ask, and session a holds none of b's" "$( rigLines rig-sess-b "ask:$rigIdB1" ):$( rigLines rig-sess-a "ask:$rigIdB1" )" "1:0"

echo "-- 4. no session, no stored wait --"
rigBefore="$( find "$rigWs/.local/agents/sessions" -name state | LC_ALL=C sort | tr '\n' ' ' )"
rigIdNone="$( rigOpen "" )"
rigAssert "control: the question was opened" "$( [ -n "$rigIdNone" ] && [ -f "$rigWs/.local/agents/pending/$rigIdNone.md" ] && echo yes || echo no )" yes
rigAssert "no session's stored wait holds it, and no stored wait was made" "$( LC_ALL=C grep -r -l -F -- "ask:$rigIdNone" "$rigWs/.local/agents/sessions" 2> /dev/null | wc -l | tr -d ' ' ):$( find "$rigWs/.local/agents/sessions" -name state | LC_ALL=C sort | tr '\n' ' ' )" "0:$rigBefore"

if [ "$rigFailCount" = 0 ] ; then
	printf 'PENDING_REPLY_WAIT_JOIN: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount" ; exit 0
fi
printf '⛔ PENDING REPLY WAIT JOIN CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" ; exit 1
