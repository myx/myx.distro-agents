#!/usr/bin/env bash
## Behavioural check on S6.4 of `20261102-refactorings.epic.md`: "An answer the owner gives in a
## question's thread reaches its pending record and its asker's Wait. Today the root's asks in the
## bot DM stayed `reply-pending`, and Wait listed their sources as never read."
##
## Held in two parts, each run through the real operations:
##   A. READING A RECORD BY ITS ID RECORDS THE OWNER'S REPLY. A record is waiting, the owner has
##      answered in its thread, and nothing has read it. The read of that one record by its id is
##      made; afterwards the record holds the owner's own words. Before it, it holds none of them --
##      the control, so a pass is not a check that cannot fail.
##   B. A SHORT BOUND READS ITS `ask:` SOURCES. One Wait, six `ask:` sources, a five-second bound,
##      and an upstream that takes seven seconds for each thread: the bound is the wait's own, not
##      one probe's cost repeated per source.
##        B1. it returns inside 20 seconds -- six probes at seven seconds each is 42 and more, which
##            is what the bound is there to stop;
##        B2. at most ONE of its six sources is named WAIT-NEVER-READ;
##        B3. of the answers already in hand, every source that is not named never-read carries its
##            answer into what the wait returned.
##
## WHY BOTH ARE RED ON THE TREE BEFORE THE FIX:
##   A. `--read-pending-reply` polls each own open ask, but its last step is `AgentsHarnessAskResolve`,
##      which needs `harnessAgent` and `harnessScratch` -- set only inside a running harness. Outside
##      one it returns at its first test and prints nothing, so the reply is never recorded and the
##      record stays `reply-pending` (measured on this tree: status unchanged, no reply kept).
##   B. `AgentsTools.MemberWaitRun.include` sets `roundNow` once at the head of a round and gives every
##      source `waitDeadline - roundNow`, so each source gets the whole five seconds however much the
##      earlier ones used; each slow probe is detached at the bound and named WAIT-NEVER-READ, and six
##      of them take six bounds. Measured from the code and by the developer in session 66b4ae11.
##
## Offline: a Slack-shaped fake curl first on PATH, which opens no socket and answers from this rig's
## own scenario files; the workspace, the store and every record are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/pending-reply-remind-check.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPendingReplyReadAndShortWaitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigScn="$rigTmp/scn"
rigStore="$rigWs/.local/agents/pending"
mkdir -p "$rigTmp/bin" "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigStore" "$rigScn" "$rigTmp/home" \
	"$rigTmp/skills/rig-member" "$rigTmp/data"
printf 'rig identity\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
## The fake curl: every Slack call is logged; a thread is answered from the scenario's own file; and
## `rigSlow` makes it take seven seconds, which is what a real thread read costs this check.
cp "$rigFixtures/pending-reply-remind-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
printf '%s\n' '#!/bin/sh' \
	'## The rig'"'"'s slow Slack: seven seconds, then the fake curl'"'"'s own answer.' \
	'sleep 7' \
	'exec "'"$rigTmp"'/bin/curl.real" "$@"' > "$rigTmp/bin/curl.slow"
chmod +x "$rigTmp/bin/curl.slow"
mv "$rigTmp/bin/curl" "$rigTmp/bin/curl.real"
printf '%s\n' '#!/bin/sh' \
	'## The rig'"'"'s Slack: seven seconds a call while the slow mark stands, the fake curl otherwise.' \
	'if [ -f "'"$rigScn"'/slow" ] ; then exec "'"$rigTmp"'/bin/curl.slow" "$@" ; fi' \
	'exec "'"$rigTmp"'/bin/curl.real" "$@"' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the rig's curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
export RIG_CURL_LOG="$rigScn/curl.log"
: > "$RIG_CURL_LOG"

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
rigOp(){ ## output name, then the operation and its arguments -- one call of the tooling from the rig workspace
	local opName="$1" ; shift
	( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_DATA_ROOT \
		HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		PATH="$rigTmp/bin:$PATH" RIG_SCENARIO="$rigScn" RIG_CURL_LOG="$RIG_CURL_LOG" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opName" 2> "$rigTmp/$opName.err"
}
## The record has the shape of the root's own open asks: a question with an answer form (`select: one`)
## and the accounts that asked it. A plain ask with no form is closed by the poll without the harness, so a
## record of that shape could never show the defect this part is about. The reply stays free text.
rigRecord(){ ## id, thread ts, question ts, the question line
	{
		printf -- '---\nstatus: reply-pending\nowner: rig-member\nkind: question\nselect: one\n'
		printf 'communication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\n'
		printf 'channel: CRIG00001\nquestion-ts: %s\nthread-ts: %s\naddressees: URIGOWNER\nasking-accounts: URIGBOT01\nask-identity: bot\n' "$3" "$2"
		printf 'asked-at: 2026-11-02 20:00 +0200\n---\n\n# Question asked\n\n# ❓ Question\n\n%s\n' "$4"
	} > "$rigStore/$1.md"
	printf '# Options\n\nship: go on\nhold: wait\n' > "$rigStore/$1.options"
}
## A record closed by the read moves to pending/closed/ (retention, T9), so both readers look in
## either store: a check that read the live folder alone would report the close as a missing record.
rigRecordFile(){ ## id -- the record's file, live or closed
	if [ -f "$rigStore/$1.md" ] ; then printf '%s' "$rigStore/$1.md" ; else printf '%s' "$rigStore/closed/$1.md" ; fi
}
rigStatus(){ ## id -- the record's status word
	LC_ALL=C sed -n 's/^status: //p' "$( rigRecordFile "$1" )" 2> /dev/null | head -n 1
}
rigHolds(){ ## id, fixed string -- yes when the record holds that string
	LC_ALL=C grep -q -F -- "$2" "$( rigRecordFile "$1" )" 2> /dev/null && printf yes || printf no
}
rigAnswer(){ ## thread ts, question ts, the reply ts, the words -- the thread's file: the root post, the question, and the owner's reply
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"the rig thread root"},{"ts":"%s","user":"URIGSELF1","text":"the rig question"},{"ts":"%s","user":"URIGOWNER","text":"%s"}]}\n' \
		"$1" "$2" "$3" "$4" > "$rigScn/replies.$1.json"
}

## ---- A. reading one record by its id records the owner's reply ----
echo "-- A. the owner's reply in a thread reaches the record when the record is read by its id --"
rigOwning="11111111-0000-0000-0000-0000000000a1"
rigAnswer 1700000100.000101 1700000100.000102 1700000100.000200 'RIG-OWNER-SAYS-SHIP-IT'
rigRecord "$rigOwning" 1700000100.000101 1700000100.000102 'Which way for the rig?'
rigAssert "before the read the record holds nothing of the owner's words" "$( rigHolds "$rigOwning" 'RIG-OWNER-SAYS-SHIP-IT' )" no
rigAssert "and it is still waiting"                            "$( rigStatus "$rigOwning" )" reply-pending
rigOp readA --read-pending-reply --team-member rig-member "$rigOwning"
rigAssert "the read answers for the record it was given"        "$( grep -c -F "PENDING-REPLY: $rigOwning" "$rigTmp/readA" || : )" 1
rigAssert "and afterwards the record holds the owner's own words" "$( rigHolds "$rigOwning" 'RIG-OWNER-SAYS-SHIP-IT' )" yes
## A record that closes stays, and a closed record is asked for in its own store, so the read of it is
## still answered rather than reported as missing.
rigAssert "the record is still there after the read, in one store or the other" "$( [ -f "$( rigRecordFile "$rigOwning" )" ] && printf yes || printf no )" yes

## ---- B. one short bound, six ask sources, a slow upstream ----
echo "-- B. a five-second bound over six ask: sources, with a thread that takes seven seconds a call --"
rigIds=""
for rigN in 1 2 3 4 5 6 ; do
	rigId="22222222-0000-0000-0000-00000000000$rigN"
	rigAnswer "170000020$rigN.000101" "170000020$rigN.000102" "170000020$rigN.000200" "RIG-ANSWER-$rigN"
	rigRecord "$rigId" "170000020$rigN.000101" "170000020$rigN.000102" "Question number $rigN?"
	rigIds="$rigIds $rigId"
done
rigSources=""
for rigId in $rigIds ; do rigSources="$rigSources --wait-source ask:$rigId" ; done
## Warm the comms cache: each thread read once while the upstream is quick, as a session that has been
## running for a while would have it. The cache is filled through the tooling's own cache reader, never
## through a read of the record: a read is what this check measures, and under the fix it closes the record.
rigN=0
for rigId in $rigIds ; do
	rigN=$(( rigN + 1 ))
	( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_DATA_ROOT \
		HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		PATH="$rigTmp/bin:$PATH" RIG_SCENARIO="$rigScn" RIG_CURL_LOG="$RIG_CURL_LOG" bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
			AgentsToolsCommsCacheSlackThread rig-member "CRIG00001:$1" "$2" true "$( date +%s )"
		' _ "170000020$rigN.000101" "$rigTmp/warm.$rigN.out" ) > /dev/null 2>&1 || :
done
: > "$rigScn/slow"
rigStarted="$( date +%s )"
rigWaitRc=0
( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_DATA_ROOT -u MDAT_SESSION_THREAD \
	HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
	PATH="$rigTmp/bin:$PATH" RIG_SCENARIO="$rigScn" RIG_CURL_LOG="$RIG_CURL_LOG" MDAT_WAIT_REMIND=off \
	bash "$rigTool" --wait-for-input --team-member rig-member $rigSources --wait-timeout 5 ) > "$rigTmp/wait.out" 2> "$rigTmp/wait.err" || rigWaitRc=$?
rigElapsed=$(( $( date +%s ) - rigStarted ))
rm -f "$rigScn/slow"
rigFirst="$( LC_ALL=C sed -n '1p' "$rigTmp/wait.out" )"
rigAnswered=""
for rigN in 1 2 3 4 5 6 ; do
	LC_ALL=C grep -q -F "RIG-ANSWER-$rigN" "$rigTmp/wait.out" && rigAnswered="$rigAnswered $rigN"
done
rigFixtureHolds="$( LC_ALL=C grep -c -F 'RIG-ANSWER-1' "$rigScn/replies.1700000201.000101.json" || : )"
rigResultLine="$( printf '%s' "$rigFirst" | LC_ALL=C grep -c '^WAIT-RESULT: ' || : )"
rigAssert "the wait answered with a WAIT-RESULT line"            "$rigResultLine" 1
rigAssert "B1. the whole call returned inside 20 seconds, on its own 5-second bound" \
	"$( [ "$rigElapsed" -le 20 ] && printf yes || printf no )" yes
rigAssert "B2. an answer already in the thread reaches the return of that short wait" \
	"$( [ -n "$rigAnswered" ] && printf yes || printf no )" yes
rigAssert "and the control: the fixture really holds the answer the wait was to find" \
	"$rigFixtureHolds" 1
## What the run says of itself, kept in the check's own output: a fail here reads with its reason.
printf '  note  waited %ss, answers returned:%s\n' "$rigElapsed" "${rigAnswered:- none}"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY READ AND SHORT WAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_READ_AND_SHORT_WAIT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
