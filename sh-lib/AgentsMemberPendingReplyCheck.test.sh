#!/usr/bin/env bash
## Behavioural check on --member-pending-reply-read and --member-pending-reply-settle:
## the read lists the member's own open records only unless --all or --any-owner widens
## it, and shows one by id with its first line; settle closes the member's own open
## question with the reason, refuses another member's record and a readback, leaves a
## closed record as it is, and of two settles racing on one record exactly one closes
## it. Offline: a temp workspace under the workspace's .local/temp, no Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsMemberPendingReplyCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws/.local/agents/pending"
mkdir -p "$rigStore" "$rigTmp/home" "$rigTmp/skills/magic-tester" "$rigTmp/data" "$rigTmp/bin" "$rigTmp/scenario"
## A settle marks the question in Slack; the Slack-shaped fake curl takes that, offline.
cp "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-lib/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
export PATH RIG_SCENARIO RIG_CURL_LOG
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
mkdir -p "$rigTmp/ws/.local/.agents"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/magic-tester.agent.env"

rigRecord(){ ## id, owner, status, kind (empty for a plain question), question line
	{
		printf -- '---\nstatus: %s\nowner: %s\n' "$3" "$2"
		printf 'communication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\n'
		[ -z "$4" ] || printf 'kind: %s\n' "$4"
		printf 'channel: CRIG00001\nquestion-ts: 1700000001.000102\nthread-ts: 1700000001.000101\nquestion-tag: Q1\n'
		printf 'asked-at: 2026-09-29 12:00 +0300\n---\n\n# Question asked\n\n# ❓ Question Q1\n\n%s\n' "$5"
	} > "$rigStore/$1.md"
}
rigRecord 11111111-0000-0000-0000-000000000001 magic-tester reply-pending "" "May the rig keep report one?"
rigRecord 11111111-0000-0000-0000-000000000002 magic-tester reply-received "" "May the rig keep report two?"
rigRecord 11111111-0000-0000-0000-000000000003 magic-coordinator reply-pending "" "May the rig keep report three?"
rigRecord 11111111-0000-0000-0000-000000000004 magic-tester reply-pending readback "Rig readback four"
rigRecord 11111111-0000-0000-0000-000000000005 magic-tester reply-pending "" "May the rig keep report five?"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigOp(){ ## output name, op, arguments...
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
rigStatus(){ ## id
	LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit }' "$rigStore/$1.md"
}
rigField(){ ## id, field
	LC_ALL=C awk -v key="$2" 'index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit }' "$rigStore/$1.md"
}

echo "-- read: the member's own open records --"
rigOp list --member-pending-reply-read magic-tester
rigHolds "$rigTmp/list" 'PENDING-REPLIES:' | grep -q yes || rigRefuse "the read op never answered: $( grep -m1 ERROR "$rigTmp/list.err" )"
rigAssert "three are listed"                          "$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/list" )" 3
rigAssert "its own open question is there"            "$( rigHolds "$rigTmp/list" 'PENDING-REPLY: 11111111-0000-0000-0000-000000000001' )" yes
rigAssert "with its first line"                       "$( rigHolds "$rigTmp/list" 'question: May the rig keep report one?' )" yes
rigAssert "and its thread"                            "$( rigHolds "$rigTmp/list" 'thread-ts: 1700000001.000101' )" yes
rigAssert "a closed one is not"                       "$( rigHolds "$rigTmp/list" '000000000002' )" no
rigAssert "nor another member's"                      "$( rigHolds "$rigTmp/list" '000000000003' )" no
rigOp listall --member-pending-reply-read magic-tester --all
rigAssert "--all adds the closed one"                 "$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/listall" )" 4
rigOp listany --member-pending-reply-read magic-tester --any-owner
rigAssert "--any-owner adds the other member's"       "$( rigHolds "$rigTmp/listany" '000000000003' )" yes
rigOp one --member-pending-reply-read magic-tester 11111111-0000-0000-0000-000000000003
rigAssert "one by id shows it"                        "$( rigHolds "$rigTmp/one" 'owner: magic-coordinator' )" yes
rigOp missing --member-pending-reply-read magic-tester 11111111-0000-0000-0000-000000000009
rigAssert "a missing id fails"                        "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero

echo "-- settle: the member's own open question --"
rigOp settle1 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000001 --reason "answered in the thread at 12:47"
rigAssert "it says settled"                           "$( head -1 "$rigTmp/settle1" )" "SETTLED 11111111-0000-0000-0000-000000000001"
rigAssert "the record is closed"                      "$( rigStatus 11111111-0000-0000-0000-000000000001 )" reply-received
rigAssert "with the reason"                           "$( rigField 11111111-0000-0000-0000-000000000001 verdict )" "settled: answered in the thread at 12:47"
rigAssert "settled by its asker"                      "$( rigField 11111111-0000-0000-0000-000000000001 answered-by )" "magic-tester (settled)"
rigAssert "with its close time in seconds"            "$( rigField 11111111-0000-0000-0000-000000000001 resolved-epoch | LC_ALL=C grep -c -E '^[0-9]+$' )" 1
rigAssert "the question is marked settled"            "$( LC_ALL=C grep -c -x -F '1700000001.000102 ballot_box_with_check' "$rigTmp/scenario/reactions" 2>/dev/null )" 1
rigAssert "not answered"                              "$( LC_ALL=C grep -c -x -F '1700000001.000102 white_check_mark' "$rigTmp/scenario/reactions" 2>/dev/null )" 0
rigAssert "and the opener is left, others being open" "$( LC_ALL=C grep -c -x -F '1700000001.000101 white_check_mark' "$rigTmp/scenario/reactions" 2>/dev/null )" 0

echo "-- settle: refusals --"
rigOp settle3 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000003 --reason "not mine"
rigAssert "another member's record is refused"        "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "naming who asked it"                       "$( rigHolds "$rigTmp/settle3.err" 'asked by magic-coordinator' )" yes
rigAssert "and it stays open"                         "$( rigStatus 11111111-0000-0000-0000-000000000003 )" reply-pending
rigOp settle4 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000004 --reason "a readback"
rigAssert "a readback is refused"                     "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and stays open"                            "$( rigStatus 11111111-0000-0000-0000-000000000004 )" reply-pending
rigOp settle0 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000005
rigAssert "no reason is refused"                      "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero

echo "-- settle: a closed record is left as it is --"
rigOp settle2 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000001 --reason "again"
rigAssert "it says already closed"                    "$( head -1 "$rigTmp/settle2" )" "ALREADY-CLOSED 11111111-0000-0000-0000-000000000001 reply-received"
rigAssert "and the first reason stands"               "$( rigField 11111111-0000-0000-0000-000000000001 verdict )" "settled: answered in the thread at 12:47"

echo "-- two settles racing on one record: exactly one closes it --"
( rigOp raceA --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000005 --reason "race A" ) &
( rigOp raceB --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000005 --reason "race B" ) &
wait
rigAssert "one says settled"                          "$( cat "$rigTmp/raceA" "$rigTmp/raceB" | LC_ALL=C grep -c '^SETTLED ' )" 1
rigAssert "the other says already closed"             "$( cat "$rigTmp/raceA" "$rigTmp/raceB" | LC_ALL=C grep -c '^ALREADY-CLOSED ' )" 1
rigAssert "and the verdict is the winner's"           "$( rigField 11111111-0000-0000-0000-000000000005 verdict | LC_ALL=C grep -c -E '^settled: race (A|B)$' )" 1

echo "-- amend: the coordinator corrects a closed record's verdict --"
rigRecord 11111111-0000-0000-0000-000000000006 magic-tester reply-unknown "" "May the rig keep report six?"
printf 'verdict: closed in error\n' > "$rigTmp/v6" && LC_ALL=C awk -v add="$( cat "$rigTmp/v6" )" 'NR == 2 { print add ; } { print ; }' "$rigStore/11111111-0000-0000-0000-000000000006.md" > "$rigTmp/r6" && mv "$rigTmp/r6" "$rigStore/11111111-0000-0000-0000-000000000006.md"
rigRecord 11111111-0000-0000-0000-000000000007 magic-tester reply-received permission "Rig permission seven"
rigOp amend6 --magic-pending-reply-amend magic-coordinator 11111111-0000-0000-0000-000000000006 --verdict "No - keep it elsewhere" --reason "the answer in its thread at 12:32"
rigAssert "it says amended"                           "$( head -1 "$rigTmp/amend6" )" "AMENDED 11111111-0000-0000-0000-000000000006"
rigAssert "the verdict is corrected"                  "$( rigField 11111111-0000-0000-0000-000000000006 verdict )" "No - keep it elsewhere"
rigAssert "the record reads received"                 "$( rigStatus 11111111-0000-0000-0000-000000000006 )" reply-received
rigAssert "with who amended it"                       "$( rigField 11111111-0000-0000-0000-000000000006 amended-by )" magic-coordinator
rigAssert "and why"                                   "$( rigField 11111111-0000-0000-0000-000000000006 amend-reason )" "the answer in its thread at 12:32"
rigAssert "and what it corrected"                     "$( rigField 11111111-0000-0000-0000-000000000006 amended-from )" "closed in error"
rigOp read6 --member-pending-reply-read magic-tester 11111111-0000-0000-0000-000000000006
rigAssert "the read shows who amended it"             "$( rigHolds "$rigTmp/read6" 'amended-by: magic-coordinator' )" yes
rigAssert "and what it corrected"                     "$( rigHolds "$rigTmp/read6" 'amended-from: closed in error' )" yes
rigOp amend7 --magic-pending-reply-amend magic-coordinator 11111111-0000-0000-0000-000000000007 --verdict "deny" --reason "x"
rigAssert "a permission record is not amended"        "$( rigHolds "$rigTmp/amend7.err" 'corrected through the grant store' )" yes
rigAssert "and is left as it was"                     "$( rigField 11111111-0000-0000-0000-000000000007 verdict )" ""
rigAssert "and no Slack mark is posted for it"        "$( LC_ALL=C grep -c -x -F '1700000001.000102 white_check_mark' "$rigTmp/scenario/reactions" 2>/dev/null )" 0
rigOp amendOpen --magic-pending-reply-amend magic-coordinator 11111111-0000-0000-0000-000000000003 --verdict "x" --reason "y"
rigAssert "an open record is refused"                 "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and stays open"                            "$( rigStatus 11111111-0000-0000-0000-000000000003 )" reply-pending
rigOp amendOther --magic-pending-reply-amend magic-tester 11111111-0000-0000-0000-000000000006 --verdict "x" --reason "y"
rigAssert "another member may not amend"              "$( rigHolds "$rigTmp/amendOther.err" 'only magic-coordinator amends' )" yes
rigAssert "and the verdict stands"                    "$( rigField 11111111-0000-0000-0000-000000000006 verdict )" "No - keep it elsewhere"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER PENDING REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_PENDING_REPLY: OK (%d assertions, offline)\n' "$rigPassCount"
