#!/usr/bin/env bash
## Behavioural check on --member-pending-reply-read and --member-pending-reply-settle:
## the read lists the member's own open records only unless --all or --any-owner widens
## it, and shows one by id with its first line; settle closes the member's own open
## question with the reason, refuses another member's record and a readback, leaves a
## closed record as it is, and of two settles racing on one record exactly one closes
## it. A session settles only as itself; the coordinator settles another member's question
## with --magic-pending-reply-settle. Offline: a temp workspace under the workspace's
## .local/temp, no Slack.
## A list also brings the pending-replies registry up to date, by the one rebuild function
## every other rebuild of it calls, and a read of one record by its id leaves that file as it
## lies. And each open record says whether the run that asked it is alive (`asker-live:`),
## measured as the read is made and stored nowhere, by the one rule a run is recognised by,
## against a process list of this rig's own -- a ps first on PATH lists the rig's runs only, so
## no process of the host is ever seen. An ask is matched to the run whose own id it carries,
## never to the coworking session that run joined.
## One record by its id prints, after the lines a list prints for it, the whole of what the
## stores hold of that ask (`PENDING-REPLY-STORED:`): its other header fields, the question as
## it was posted, the options, the slots its post was filled with, the entries of a permission
## set, the refused call of a permission, the diff of a held change. A text of several lines
## keeps its lines, each under the field's name. The list prints none of it.
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
cp "${MDLT_ORIGIN}/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
export PATH RIG_SCENARIO RIG_CURL_LOG
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
## THE RIG'S OWN PROCESS LIST. Whether the run that asked is alive is read from the host's
## process list (ps -A). A rig that read the real one would take a command line of this host
## for a run of its own. So the ps first on PATH answers the whole-host listing from the rig's
## own list, beside it, one `<pid> <command line>` line a process, and hands every other call
## to the real ps. When one process started (-o lstart= -p <pid>) is answered from the rig's
## own table for a pid it holds, `<pid> <start as ps prints it>` a line, and by the real ps for
## any other.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
: > "$rigTmp/ps.started"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
	*" lstart= "*)
		rigPsPid=""
		for rigPsWord in "$@" ; do
			case "$rigPsWord" in ''|*[!0123456789]*) ;; *) rigPsPid="$rigPsWord" ;; esac
		done
		rigPsLine="$( grep "^$rigPsPid " "${0%/*}/../ps.started" 2> /dev/null )"
		[ -z "$rigPsLine" ] || { printf '%s\n' "${rigPsLine#* }" ; exit 0 ; }
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"
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
	## RIG_AGENT, when set, is the spawned session's own member (MDAT_SPAWN_AGENT); unset, the console.
	( cd "$rigTmp/ws" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
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

echo "-- settle: a session settles as itself; the coordinator, on another's behalf, with --magic-pending-reply-settle --"
rigRecord 11111111-0000-0000-0000-000000000008 magic-tester reply-pending "" "May the rig keep report eight?"
RIG_AGENT=magic-coordinator rigOp settle8a --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000008 --reason "as another"
rigAssert "a session settling as another member is refused" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 ):$( rigHolds "$rigTmp/settle8a.err" 'this session acts as magic-coordinator' )" "non-zero:yes"
rigAssert "and it stays open"                         "$( rigStatus 11111111-0000-0000-0000-000000000008 )" reply-pending
RIG_AGENT=magic-tester rigOp settle8b --magic-pending-reply-settle magic-coordinator 11111111-0000-0000-0000-000000000008 --reason "not the coordinator"
rigAssert "the magic form from another member's session is refused" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 ):$( rigHolds "$rigTmp/settle8b.err" "is magic-coordinator's only" )" "non-zero:yes"
rigOp settle8c --magic-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000008 --reason "named a member"
rigAssert "the magic form naming another member is refused" "$( rigHolds "$rigTmp/settle8c.err" 'only magic-coordinator settles another member' ):$( rigStatus 11111111-0000-0000-0000-000000000008 )" "yes:reply-pending"
RIG_AGENT=magic-coordinator rigOp settle8d --magic-pending-reply-settle magic-coordinator 11111111-0000-0000-0000-000000000008 --reason "settled for the tester"
rigAssert "the coordinator settles it on the asker's behalf" "$( head -1 "$rigTmp/settle8d" ):$( rigStatus 11111111-0000-0000-0000-000000000008 )" "SETTLED 11111111-0000-0000-0000-000000000008:reply-received"
rigAssert "signed as the coordinator"                 "$( rigField 11111111-0000-0000-0000-000000000008 answered-by )" "magic-coordinator (settled)"
RIG_AGENT=magic-coordinator rigOp settle4m --magic-pending-reply-settle magic-coordinator 11111111-0000-0000-0000-000000000004 --reason "a readback"
rigAssert "a readback is refused on the magic form too" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 ):$( rigStatus 11111111-0000-0000-0000-000000000004 )" "non-zero:reply-pending"

echo "-- withdraw: the asker discards its own open question, of any kind --"
rigRecord 11111111-0000-0000-0000-000000000010 magic-tester reply-pending permission "Rig permission ten"
rigRecord 11111111-0000-0000-0000-000000000011 magic-coordinator reply-pending decision "Rig decision eleven"
rigPostsBefore="$( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 )"
RIG_AGENT=magic-tester rigOp wd10 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000010 --reason "the task was cancelled" --withdraw
rigAssert "it says withdrawn"                         "$( head -1 "$rigTmp/wd10" )" "WITHDRAWN 11111111-0000-0000-0000-000000000010"
rigAssert "closed as withdrawn, a permission too"     "$( rigStatus 11111111-0000-0000-0000-000000000010 )" withdrawn
rigAssert "with the reason and who withdrew it"       "$( rigField 11111111-0000-0000-0000-000000000010 withdraw-reason ):$( rigField 11111111-0000-0000-0000-000000000010 withdrawn-by )" "the task was cancelled:magic-tester"
rigAssert "and no verdict, so nothing is granted"     "$( rigField 11111111-0000-0000-0000-000000000010 verdict ):$( rigField 11111111-0000-0000-0000-000000000010 grant )" ":"
rigAssert "a note is posted in its thread"            "$(( $( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 ) - rigPostsBefore ))" 1
rigAssert "and the note says it needs no answer"      "$( cat "$rigTmp/scenario/post.$( cat "$rigTmp/scenario/posts" )" 2>/dev/null | LC_ALL=C grep -c -F 'no longer needs an answer' )" 1
rigOp list10 --member-pending-reply-read magic-tester
rigAssert "it is no longer listed as waiting"         "$( rigHolds "$rigTmp/list10" '000000000010' )" no
RIG_AGENT=magic-tester rigOp wd11 --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000011 --reason "not mine" --withdraw
rigAssert "another member's question is refused"      "$( rigHolds "$rigTmp/wd11.err" 'cannot withdraw it' ):$( rigStatus 11111111-0000-0000-0000-000000000011 )" "yes:reply-pending"
RIG_AGENT=magic-coordinator rigOp wd8m --magic-pending-reply-settle magic-coordinator 11111111-0000-0000-0000-000000000005 --reason "for the tester" --withdraw
rigAssert "the coordinator withdraws none but its own" "$( rigHolds "$rigTmp/wd8m.err" 'cannot withdraw it' )" yes
RIG_AGENT=magic-coordinator rigOp wd11c --magic-pending-reply-settle magic-coordinator 11111111-0000-0000-0000-000000000011 --reason "asked the wrong person" --withdraw
rigAssert "control: it withdraws its own decision"    "$( head -1 "$rigTmp/wd11c" ):$( rigStatus 11111111-0000-0000-0000-000000000011 )" "WITHDRAWN 11111111-0000-0000-0000-000000000011:withdrawn"
RIG_AGENT=magic-tester rigOp wd10again --member-pending-reply-settle magic-tester 11111111-0000-0000-0000-000000000010 --reason "again" --withdraw
rigAssert "a closed record is left as it is"          "$( head -1 "$rigTmp/wd10again" ):$( rigField 11111111-0000-0000-0000-000000000010 withdraw-reason )" "ALREADY-CLOSED 11111111-0000-0000-0000-000000000010 withdrawn:the task was cancelled"

echo "-- a permission set: its own verdicts, the human-owner's to give --"
rigRecord 11111111-0000-0000-0000-000000000009 magic-coordinator reply-pending permission-set "Rig permission set nine"
LC_ALL=C awk 'NR == 2 { print "address-to: human-owner" ; print "session-id: rig-set-session" ; } { print ; }' "$rigStore/11111111-0000-0000-0000-000000000009.md" > "$rigTmp/r9" && mv "$rigTmp/r9" "$rigStore/11111111-0000-0000-0000-000000000009.md"
printf 'scope: task\nitem: task-rig-none\nsession-id: rig-set-session\nparticipants: magic-tester\nentry: WebSearch\n' > "$rigStore/11111111-0000-0000-0000-000000000009.set"
rigOp read9 --member-pending-reply-read magic-tester 11111111-0000-0000-0000-000000000009
rigAssert "it reads as a permission-set"              "$( rigHolds "$rigTmp/read9" 'kind: permission-set' )" yes
RIG_AGENT=magic-tester rigOp ans9a --member-escalation-answer magic-tester 11111111-0000-0000-0000-000000000009 allow-set
rigAssert "a member it is not addressed to cannot answer it" "$( rigHolds "$rigTmp/ans9a.err" 'cannot answer it' ):$( rigStatus 11111111-0000-0000-0000-000000000009 )" "yes:reply-pending"
rigOp ans9b --member-escalation-answer human-owner 11111111-0000-0000-0000-000000000009 allow-once
rigAssert "a permission verdict is not a set's"       "$( rigHolds "$rigTmp/ans9b.err" 'is not a verdict of this permission-set' )" yes
rigOp ans9c --member-escalation-answer human-owner 11111111-0000-0000-0000-000000000009 edit "drop WebSearch"
rigAssert "edit is the human-owner's, with its change" "$( rigStatus 11111111-0000-0000-0000-000000000009 ):$( rigField 11111111-0000-0000-0000-000000000009 verdict ):$( rigField 11111111-0000-0000-0000-000000000009 verdict-text )" "reply-received:edit:drop WebSearch"
rigAssert "and grants nothing"                        "$( rigHolds "$rigTmp/ans9c" 'GRANT:' )" no

echo "-- a list brings the pending-replies registry up to date; a read of one record leaves it as it lies --"
## A workspace of its own, so its stores hold exactly what a case names: its asks, its spawn
## records, its session stores and its board.
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigWs2="$rigTmp/ws2"
rigAgents2="$rigWs2/.local/agents"
rigStore2="$rigAgents2/pending"
rigReg2="$rigAgents2/pending-replies.registry"
rigRegInclude="${MDLT_ORIGIN}/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include"
rigReadInclude="${MDLT_ORIGIN}/myx/myx.distro-agents/sh-lib/AgentsTools.MemberPendingReply.include"
mkdir -p "$rigStore2" "$rigAgents2/spawned" "$rigAgents2/sessions" "$rigTmp/data2/board/running" "$rigWs2/.local"
cp -R "$rigTmp/ws/.local/.agents" "$rigWs2/.local/.agents" || rigRefuse "the second workspace got no settings"
rigAsk2(){ ## id, status, host ("" for none), session-id ("" for none), question line
	{
		printf -- '---\nstatus: %s\nowner: magic-tester\n' "$2"
		[ -z "$3" ] || printf 'host: %s\n' "$3"
		printf 'communication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\n'
		[ -z "$4" ] || printf 'session-id: %s\n' "$4"
		printf 'kind: decision\nasked-at: 2026-10-12 12:00 +0300\n---\n\n# Question asked\n\n%s\n' "$5"
	} > "$rigStore2/$1.md"
}
rigOp2(){ ## output name, op, arguments... -- rigOp, in that workspace
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigWs2" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigWs2" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data2" \
		bash "$rigTool" "$@" ) > "$rigTmp/$opOut" 2> "$rigTmp/$opOut.err" || rigRc=$?
}
## The rows of that workspace's registry as the one rows function gives them now.
rigRows2(){
	( MMDAPP="$rigWs2" ; MDAT_DATA_ROOT="$rigTmp/data2" ; . "$rigRegInclude" ; AgentsToolsRegistryPendingRepliesRows ) 2> /dev/null
}
rigRegRow2(){ ## key -- its row of the registry file
	LC_ALL=C awk -v wantKey="$1" '$1 == wantKey { print ; }' "$rigReg2" 2> /dev/null
}
rigA1=22222222-0000-0000-0000-000000000001 ; rigA2=22222222-0000-0000-0000-000000000002 ; rigA3=22222222-0000-0000-0000-000000000003
rigAsk2 "$rigA1" reply-pending "$rigHost" "rig-asker-one-$$" "May the rig keep list one?"
rigAsk2 "$rigA2" reply-pending "$rigHost" "rig-asker-two-$$" "May the rig keep list two?"
rigAsk2 "$rigA3" reply-received "$rigHost" "rig-asker-one-$$" "May the rig keep list three?"
printf -- '---\nblocked-on: human\nsession-id: s-rig-board\nowner: magic-tester\n---\n' > "$rigTmp/data2/board/running/task-rig-blocked.md"
## The file as an earlier rebuild left it: it still calls the third ask open, holds a row of a
## record the store no longer has, and knows nothing of the board item.
rigStale2(){
	{
		printf '%s.md ask rig-asker-one-%s magic-tester reply-pending reply_from_human-owner slack:human-owner\n' "$rigA1" "$$"
		printf '%s.md ask rig-asker-one-%s magic-tester reply-pending reply_from_human-owner slack:human-owner\n' "$rigA3" "$$"
		printf '22222222-0000-0000-0000-00000000gone.md ask rig-asker-gone magic-tester reply-pending - -\n'
	} > "$rigReg2"
}
rigStale2
rigOp2 list2 --member-pending-reply-read magic-tester
rigHolds "$rigTmp/list2" 'PENDING-REPLIES:' | grep -q yes || rigRefuse "the read op never answered in the second workspace: $( grep -m1 ERROR "$rigTmp/list2.err" )"
rigAssert "after a list, an ask the store has closed reads closed in the file" "$( rigRegRow2 "$rigA3.md" | LC_ALL=C awk '{ print $5 ; }' )" reply-received
rigAssert "an ask the file did not know has its row"  "$( rigRegRow2 "$rigA2.md" | LC_ALL=C awk '{ print $2 ":" $5 ; }' )" "ask:reply-pending"
rigAssert "a row of a record the store no longer has is gone" "$( LC_ALL=C grep -c 'rig-asker-gone' "$rigReg2" )" 0
rigAssert "the board item that waits is a row, the data root being the operation's own" "$( rigRegRow2 task-rig-blocked.md | LC_ALL=C awk '{ print $2 ":" $3 ; }' )" "board-item:s-rig-board"
rigRows2 > "$rigTmp/rows2.want"
rigAssert "the file is, byte for byte, what the one rebuild writes: every row of the store, and nothing else" "$( cmp -s "$rigReg2" "$rigTmp/rows2.want" && echo same || echo differs ):$( LC_ALL=C awk 'END { print NR + 0 ; }' "$rigReg2" )" "same:4"
rigAssert "the read rebuilds through the one rebuild function and writes no registry itself" \
	"$( LC_ALL=C grep -q 'AgentsToolsRegistryPendingRepliesRebuild' "$rigReadInclude" && echo calls-it || echo never ):$( LC_ALL=C grep -c -e 'AgentsToolsRegistryWrite' -e 'pending-replies\.registry' "$rigReadInclude" )" "calls-it:0"
rigAssert "no temp file of the rebuild is left"       "$( ls "$rigAgents2" | LC_ALL=C grep -c '^pending-replies\.registry\.' )" 0
## The list prints what it printed before: the two open ones, each field in its place, and the count.
{
	printf 'PENDING-REPLY: %s\nstatus: reply-pending\nowner: magic-tester\nkind: decision\nsession-id: rig-asker-one-%s\nasked-at: 2026-10-12 12:00 +0300\nquestion: May the rig keep list one?\n\n' "$rigA1" "$$"
	printf 'PENDING-REPLY: %s\nstatus: reply-pending\nowner: magic-tester\nkind: decision\nsession-id: rig-asker-two-%s\nasked-at: 2026-10-12 12:00 +0300\nquestion: May the rig keep list two?\n\n' "$rigA2" "$$"
	printf 'PENDING-REPLIES: 2\n'
} > "$rigTmp/list2.want"
LC_ALL=C grep -v '^asker-live: ' "$rigTmp/list2" > "$rigTmp/list2.before"
rigAssert "the list prints every line it printed before, in its place: the two open ones and their count" "$( cmp -s "$rigTmp/list2.before" "$rigTmp/list2.want" && echo same || diff "$rigTmp/list2.before" "$rigTmp/list2.want" | head -6 )" same
rigAssert "and one line more for each open one, before its question" "$( LC_ALL=C grep -c '^asker-live: ' "$rigTmp/list2" ):$( LC_ALL=C grep -A1 '^asker-live: ' "$rigTmp/list2" | LC_ALL=C grep -c '^question: ' )" "2:2"
## One record by its id: the file is not written again.
rigStale2
rigRegBefore="$( ls -i "$rigReg2" | LC_ALL=C awk '{ print $1 ; }' ):$( cksum < "$rigReg2" )"
rigOp2 one2 --member-pending-reply-read magic-tester "$rigA1"
rigAssert "a read of one record by its id shows it"   "$( rigHolds "$rigTmp/one2" "PENDING-REPLY: $rigA1" ):$rigRc" "yes:0"
rigAssert "and leaves the registry as it lay, the same file and the same bytes" "$( ls -i "$rigReg2" | LC_ALL=C awk '{ print $1 ; }' ):$( cksum < "$rigReg2" )" "$rigRegBefore"
rigOp2 any2 --member-pending-reply-read magic-coordinator --any-owner
rigAssert "the --any-owner list rebuilds it too"      "$( cmp -s "$rigReg2" "$rigTmp/rows2.want" && echo same || echo differs )" same
## A workspace with no ask store: the list says none, and the registry is written with no row.
rigWs3="$rigTmp/ws3"
mkdir -p "$rigWs3/.local" "$rigTmp/data3"
cp -R "$rigTmp/ws/.local/.agents" "$rigWs3/.local/.agents" || rigRefuse "the third workspace got no settings"
( cd "$rigWs3" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigWs3" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data3" bash "$rigTool" --member-pending-reply-read magic-tester ) > "$rigTmp/list3" 2> "$rigTmp/list3.err"
rigAssert "with no ask store the list says none"      "$( cat "$rigTmp/list3" )" "PENDING-REPLIES: 0"
rigAssert "the registry is written with no row, and no store is made" "$( [ -f "$rigWs3/.local/agents/pending-replies.registry" ] && LC_ALL=C awk 'END { print NR + 0 ; }' "$rigWs3/.local/agents/pending-replies.registry" || echo no-file ):$( [ -e "$rigWs3/.local/agents/pending" ] && echo made || echo none )" "0:none"

echo "-- each open record says whether the run that asked it is alive, by the one rule a run is recognised by --"
rm -f "$rigStore2"/*.md
rigLone="rig-lone-live-$$" ; rigEnded="rig-lone-ended-$$" ; rigCow="rig-cow-$$" ; rigJoinLive="rig-join-live-$$" ; rigJoinDead="rig-join-dead-$$"
rigResumed="rig-resumed-$$" ; rigNoWord="rig-noword-live-$$" ; rigNoWordGone="rig-noword-gone-$$" ; rigNoWordReused="rig-noword-reused-$$"
rigClosedPid="rig-closed-pid-$$" ; rigQuoted="rig-quoted-$$" ; rigRoot="rig-root-$$" ; rigRootEnded="rig-root-ended-$$" ; rigNowhere="rig-nowhere-$$"
## THE RUNS OF THIS STORE, as the command lines of the rig's process list. A run is its own
## --session-id word, or its own --resume word; nothing else on a line is one.
{
	## a lone run; its brief quotes another run by the very words a launcher uses
	printf '910001 claude --verbose --output-format stream-json --session-id %s --agent rig-member the brief, and mind --session-id %s too\n' "$rigLone" "$rigQuoted"
	## a member that joined the coworking session: its own id, and the session folder of the founding spawn in its paths
	printf '910002 claude --verbose --add-dir /rig/.local/agents/spawned/%s/input --session-id %s --agent rig-member Readable /rig/.local/agents/spawned/%s/input\n' "$rigCow" "$rigJoinLive" "$rigCow"
	## the spawn proxy of the joiner that is gone: an operation of the tooling, no run
	printf '910003 bash /rig/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --session-id %s\n' "$rigJoinDead"
	## a run resumed under its own id
	printf '910004 claude --verbose --resume %s --agent rig-member go on\n' "$rigResumed"
	## a CLI that is given no session word, alive; and another process under a pid a run once had
	printf '9100001 grok --rules /rig/rules the brief of a run with no session word on its line\n'
	printf '9100003 sleep 600\n'
} > "$rigTmp/ps.list"
printf '9100001 Mon Oct 12 07:00:00 2026\n9100003 Mon Oct 12 09:30:00 2026\n' > "$rigTmp/ps.started"
rigRun2(){ ## sandbox, session-id, spawn-id, status, the process its launch started ("" for none) -- a record named for its spawn, as the launcher names it
	mkdir -p "$rigAgents2/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nstatus: %s\nowner: magic-tester\n' "$2" "$3" "$rigHost" "$4"
		[ -z "$5" ] || printf 'run-process: %s\n' "$5"
		printf -- '---\n'
	} > "$rigAgents2/spawned/$1/$3.md"
}
rigRun2 "$rigLone" "$rigLone" "$rigLone" spawn-started ""
rigRun2 "$rigEnded" "$rigEnded" "$rigEnded" spawn-succeeded ""
## A coworking session shares one sandbox, named by its id, which is its founder's spawn id.
rigRun2 "$rigCow" "$rigCow" "$rigCow" spawn-succeeded ""
rigRun2 "$rigCow" "$rigCow" "$rigJoinLive" spawn-started ""
rigRun2 "$rigCow" "$rigCow" "$rigJoinDead" spawn-started ""
rigRun2 "$rigResumed" "$rigResumed" "$rigResumed" spawn-started ""
rigRun2 "$rigNoWord" "$rigNoWord" "$rigNoWord" spawn-started "9100001 Mon_Oct_12_07:00:00_2026"
rigRun2 "$rigNoWordGone" "$rigNoWordGone" "$rigNoWordGone" spawn-started "9100002 Mon_Oct_12_07:00:00_2026"
rigRun2 "$rigNoWordReused" "$rigNoWordReused" "$rigNoWordReused" spawn-started "9100003 Mon_Oct_12_07:00:00_2026"
rigRun2 "$rigClosedPid" "$rigClosedPid" "$rigClosedPid" spawn-succeeded "9100001 Mon_Oct_12_07:00:00_2026"
rigRun2 "$rigQuoted" "$rigQuoted" "$rigQuoted" spawn-started ""
## Two root sessions, which no spawn record names: each a store of its own, one with the end marker its client's hook writes.
mkdir -p "$rigAgents2/sessions/$rigRoot" "$rigAgents2/sessions/$rigRootEnded"
: > "$rigAgents2/sessions/$rigRootEnded/ended"
rigB(){ ## number -- the id of that ask
	printf '33333333-0000-0000-0000-0000000000%02d' "$1"
}
rigAsk2 "$( rigB 1 )" reply-pending "$rigHost" "$rigLone" "Rig decision of a lone run that lives"
rigAsk2 "$( rigB 2 )" reply-pending "$rigHost" "$rigEnded" "Rig decision of a lone run that ended"
rigAsk2 "$( rigB 3 )" reply-pending "$rigHost" "$rigCow" "Rig decision of the founder of a session, gone"
rigAsk2 "$( rigB 4 )" reply-pending "$rigHost" "$rigJoinLive" "Rig decision of a member that joined, alive"
rigAsk2 "$( rigB 5 )" reply-pending "$rigHost" "$rigJoinDead" "Rig decision of a member that joined, gone"
rigAsk2 "$( rigB 6 )" reply-pending "$rigHost" "$rigResumed" "Rig decision of a resumed run"
rigAsk2 "$( rigB 7 )" reply-pending "$rigHost" "$rigNoWord" "Rig decision of a run with no session word, alive"
rigAsk2 "$( rigB 8 )" reply-pending "$rigHost" "$rigNoWordGone" "Rig decision of a run with no session word, gone"
rigAsk2 "$( rigB 9 )" reply-pending "$rigHost" "$rigNoWordReused" "Rig decision of a run whose pid another process took"
rigAsk2 "$( rigB 10 )" reply-pending "$rigHost" "$rigClosedPid" "Rig decision of a closed run that names a living process"
rigAsk2 "$( rigB 11 )" reply-pending "$rigHost" "$rigQuoted" "Rig decision of a run only quoted in a brief"
rigAsk2 "$( rigB 12 )" reply-pending "$rigHost" "$rigRoot" "Rig decision of a root session"
rigAsk2 "$( rigB 13 )" reply-pending "$rigHost" "$rigRootEnded" "Rig decision of a root session that ended"
rigAsk2 "$( rigB 14 )" reply-pending "$rigHost" "$rigNowhere" "Rig decision of an id nothing here names"
rigAsk2 "$( rigB 15 )" reply-pending "rig-elsewhere" "$rigLone" "Rig decision asked on another host"
rigAsk2 "$( rigB 16 )" reply-pending "" "$rigLone" "Rig decision with no host recorded"
rigAsk2 "$( rigB 17 )" reply-pending "$rigHost" "" "Rig decision with no asking session"
rigAsk2 "$( rigB 18 )" reply-received "$rigHost" "$rigLone" "Rig decision already answered"
rigAskerOf(){ ## output name, ask number -- the asker-live value of that ask's block, `absent` where it has none
	LC_ALL=C awk -v wantHead="PENDING-REPLY: $( rigB "$2" )" '
		$0 == wantHead { inBlock = 1 ; next ; }
		inBlock && index( $0, "PENDING-REPLY: " ) == 1 { exit ; }
		inBlock && index( $0, "asker-live: " ) == 1 { print substr( $0, 13 ) ; found = 1 ; exit ; }
		END { if ( ! found ) { print "absent" ; } }
	' "$rigTmp/$1"
}
rigOp2 askers --member-pending-reply-read magic-tester
rigAssert "every open record is listed, each with its asker line" "$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/askers" ):$( LC_ALL=C grep -c '^asker-live: ' "$rigTmp/askers" )" "17:17"
rigAssert "a run that lives is running, by its own --session-id word" "$( rigAskerOf askers 1 )" running
rigAssert "a run whose record is closed and that no process runs as has no process: no live asker" "$( rigAskerOf askers 2 )" no-process
rigAssert "the founder of a session, gone, has no process, though two command lines hold its session folder" "$( rigAskerOf askers 3 ):$( LC_ALL=C grep -c -F -- "spawned/$rigCow/input" "$rigTmp/ps.list" )" "no-process:1"
rigAssert "a member that joined a session is matched by its own id: alive, it is running, though the session's id is another's" "$( rigAskerOf askers 4 )" running
rigAssert "and gone, it has no process, though a member of its session lives and its spawn proxy names it" "$( rigAskerOf askers 5 ):$( LC_ALL=C grep -c -F -- "--session-id $rigJoinDead" "$rigTmp/ps.list" )" "no-process:1"
rigAssert "a resumed run is running, by its own --resume word" "$( rigAskerOf askers 6 )" running
rigAssert "a run of a CLI given no session word is running, by the process its record names" "$( rigAskerOf askers 7 )" running
rigAssert "one whose recorded process is gone has no process" "$( rigAskerOf askers 8 )" no-process
rigAssert "a pid taken again by another process, started at another time, is not taken for the run" "$( rigAskerOf askers 9 ):$( LC_ALL=C grep -c '^9100003 ' "$rigTmp/ps.list" )" "no-process:1"
rigAssert "a closed record has no process, whatever process it names" "$( rigAskerOf askers 10 )" no-process
rigAssert "an id quoted in another run's brief, even after the words --session-id, is no run" "$( rigAskerOf askers 11 )" no-process
rigAssert "a root session, which no spawn record names, is not measured by a rule for runs" "$( rigAskerOf askers 12 )" no-spawn-record
rigAssert "one whose store carries its end marker has ended: no live asker" "$( rigAskerOf askers 13 )" session-ended
rigAssert "an id nothing here names is not called dead" "$( rigAskerOf askers 14 )" no-spawn-record
rigAssert "an ask of another host is not measured here, though a process of this host runs as its id" "$( rigAskerOf askers 15 )" other-host
rigAssert "nor one that records no host"              "$( rigAskerOf askers 16 )" host-unrecorded
rigAssert "one that names no asking session says so" "$( rigAskerOf askers 17 )" no-session-id
rigOp2 askersall --member-pending-reply-read magic-tester --all
rigAssert "a closed record carries no asker line"     "$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/askersall" ):$( rigAskerOf askersall 18 ):$( LC_ALL=C grep -c '^asker-live: ' "$rigTmp/askersall" )" "18:absent:17"
rigAssert "liveness is measured, never stored: no row of the registry holds it" "$( LC_ALL=C grep -c -E '(^| )(running|no-process|session-ended|no-spawn-record)( |$)' "$rigReg2" ):$( LC_ALL=C awk '$2 == "ask" { askRows++ ; } END { print askRows + 0 ; }' "$rigReg2" )" "0:18"
rigRegBefore="$( ls -i "$rigReg2" | LC_ALL=C awk '{ print $1 ; }' ):$( cksum < "$rigReg2" )"
rigOp2 asker1 --member-pending-reply-read magic-tester "$( rigB 1 )"
rigOp2 asker5 --member-pending-reply-read magic-tester "$( rigB 5 )"
rigOp2 asker18 --member-pending-reply-read magic-tester "$( rigB 18 )"
rigAssert "one record by its id says the same of its asker" "$( rigAskerOf asker1 1 ):$( rigAskerOf asker5 5 ):$( rigAskerOf asker18 18 )" "running:no-process:absent"
rigAssert "and still rebuilds nothing"                "$( ls -i "$rigReg2" | LC_ALL=C awk '{ print $1 ; }' ):$( cksum < "$rigReg2" )" "$rigRegBefore"
## The process ends: the next read says so, with no record changed.
LC_ALL=C grep -v '^910001 ' "$rigTmp/ps.list" > "$rigTmp/ps.list.next" && mv "$rigTmp/ps.list.next" "$rigTmp/ps.list"
rigStoreBefore="$( cat "$rigStore2"/*.md | cksum )"
rigOp2 askers2 --member-pending-reply-read magic-tester
rigAssert "once its process is gone the next read says so" "$( rigAskerOf askers2 1 ):$( rigAskerOf askers2 4 )" "no-process:running"
rigAssert "and the read closed, withdrew and marked nothing: every record is as it was" "$( cat "$rigStore2"/*.md | cksum )" "$rigStoreBefore"
## The registry cannot be written: the list still stands, read from the records, and says that it measured no asker.
chmod a-w "$rigAgents2"
rigOp2 askers3 --member-pending-reply-read magic-tester
chmod u+w "$rigAgents2"
rigAssert "where the registry cannot be rebuilt the list still stands, and no asker is called alive or dead" \
	"$rigRc:$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/askers3" ):$( rigAskerOf askers3 1 ):$( rigAskerOf askers3 2 ):$( rigAskerOf askers3 15 )" "0:17:not-measured:not-measured:other-host"
rigAssert "and it says so, once" "$( LC_ALL=C grep -c 'WARNING: the pending-replies registry could not be rebuilt' "$rigTmp/askers3.err" )" 1
: > "$rigTmp/ps.list" ; : > "$rigTmp/ps.started"

echo "-- one record by its id: the whole of what the stores hold, after the lines a list prints --"
rm -f "$rigStore2"/*
rigTab="$( printf '\t' )"
rigW(){ ## number -- the id of that ask
	printf '55555555-0000-0000-0000-0000000000%02d' "$1"
}
rigWholeOf(){ ## output name, field name -- the lines of that field in the stored part, its name taken off
	LC_ALL=C awk -v wantField="$2: " 'storedPart && index( $0, wantField ) == 1 { print substr( $0, length( wantField ) + 1 ) ; } index( $0, "PENDING-REPLY-STORED: " ) == 1 { storedPart = 1 ; }' "$rigTmp/$1"
}
rigListBlockOf(){ ## output name, ask number -- that ask's block of a list, its blank line included
	LC_ALL=C awk -v wantHead="PENDING-REPLY: $( rigW "$2" )" '$0 == wantHead { inBlock = 1 ; } inBlock { print ; } inBlock && $0 == "" { exit ; }' "$rigTmp/$1"
}
## A decision with options, asked with the slots kept: a question of two lines, a context that holds a backslash.
{
	printf -- '---\nstatus: reply-pending\nowner: magic-tester\nhost: rig-elsewhere\ncommunication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\n'
	printf 'session-id: rig-whole-sess\nkind: decision\naddress-to: human-owner\nchannel: DRIG00001\nquestion-ts: 1700000001.000200\nthread-ts: 1700000001.000200\n'
	printf 'addressees: URIGOWNER\nasking-accounts:  URIGSELF1 \nquestion-tag: Q7\nquestion-key: 12345-67\nask-identity: bot\nitem: task-rig-whole\ntask-ref: the rig task\n'
	printf 'reason: The rig cannot go on until one layout is chosen.\nasked-at: 2026-10-12 12:00 +0300\n---\n\n# Question asked\n\n'
	printf '# 🧭 Decision Q7\n\nWhich of the two layouts does the rig keep?\nThe second line of the question.\n\n**📋 Options**\n- Keep - the layout stays as it is.\n- Hold - nothing moves until the review.\n\n'
	printf '**⚙ Context**\nA path such as C:\\rig\\layout is named as it is.\n\n**✅ How to answer**\n- reply with the first word of the option you choose\n'
	printf '\n## Clarifications\n\n1700000001.000300 URIGOWNER: which review do you mean?\n'
} > "$rigStore2/$( rigW 1 ).md"
printf 'Keep - the layout stays as it is.\nHold - nothing moves until the review.\n' > "$rigStore2/$( rigW 1 ).options"
printf 'asked-as\tEscalateDecision\ntag\tQ7\nquestion\tWhich of the two layouts does the rig keep?\\nThe second line of the question.\ncontext\tA path such as C:\\\\rig\\\\layout is named as it is.\n' > "$rigStore2/$( rigW 1 ).fields"
## A permission set with entries: its own record beside it, and the mark that its participants were told.
{
	printf -- '---\nstatus: reply-pending\nowner: magic-coordinator\nhost: rig-elsewhere\nsession-id: rig-set-sess\nkind: permission-set\naddress-to: human-owner\n'
	printf 'channel: DRIG00001\nquestion-ts: 1700000001.000400\nthread-ts: 1700000001.000400\nitem: task-rig-whole\nasked-at: 2026-10-12 12:05 +0300\n---\n\n# Question asked\n\n'
	printf '# 🔐 Permission set\n\nMay the participants have these, for this task only?\n'
} > "$rigStore2/$( rigW 2 ).md"
{
	printf 'scope: task\nitem: task-rig-whole\nsession-id: rig-set-sess\nparticipants: magic-tester keeper-rig\n'
	printf 'entry: Edit:/rig/ws/source/one/**\nentry: WebSearch\n'
	printf 'place: /rig/ws/source/one/**\trig-ws:source/one/**\npurpose: /rig/ws/source/one/**\tWrite the rig report into its own folder.\n'
	printf 'reason: The rig task writes one report.\nheld: Read:/rig/ws/source/one/**\tmagic-tester\n'
} > "$rigStore2/$( rigW 2 ).set"
: > "$rigStore2/$( rigW 2 ).told"
## A plain question of several lines, asked before the slots were kept: the record alone holds it.
{
	printf -- '---\nstatus: reply-pending\nowner: magic-tester\nsession-id: rig-plain-sess\nasked-at: 2026-10-12 12:10 +0300\n---\n\n# Question asked\n\n'
	printf 'May the rig keep its report?\n\nIt holds three parts:\n- the list\n- the totals\n\n  An indented last line: it ends here.\n'
} > "$rigStore2/$( rigW 3 ).md"
## A permission: the refused call is the record its refusal-id names, in the store of the session that asked.
{
	printf -- '---\nstatus: reply-pending\nowner: magic-tester\nhost: rig-elsewhere\nsession-id: rig-perm-sess\nkind: permission\nrefusal-id: refusal-rig-0001\n'
	printf 'reason: The report is written there.\nasked-at: 2026-10-12 12:15 +0300\n---\n\n# Question asked\n\n# 🔐 Permission\n\nAllow Edit on the report?\n'
} > "$rigStore2/$( rigW 4 ).md"
mkdir -p "$rigAgents2/sessions/rig-perm-sess"
printf -- '---\nstatus: refused\nowner: magic-tester\nhost: rig-elsewhere\nworkspace: rig-ws\nsession-id: rig-perm-sess\ntool: Edit\ntarget: /rig/ws/source/one/report.md\nrefused-at: 2026-10-12 12:14 +0300\n---\n\n# Refused\n\nERROR: path not in the allowed access-root set: /rig/ws/source/one/report.md\nAsk for it with RequestPermission.\n' \
	> "$rigAgents2/sessions/rig-perm-sess/refusal-rig-0001.md"
printf '/rig/ws/source/one/report.md\trig-ws:source/one/report.md\n' > "$rigAgents2/sessions/rig-perm-sess/refusal-rig-0001.places"
## A change held for approval: its prompt is the ask, and the whole change is kept in the store of the session that made it.
{
	printf -- '---\nstatus: reply-pending\nowner: magic-tester\nhost: rig-elsewhere\nsession-id: rig-change-sess\nkind: change\nasked-at: 2026-10-12 12:20 +0300\n---\n\n# Question asked\n\n'
	printf '# ✏️ Change\n\nApprove this change to the report?\n'
} > "$rigStore2/$( rigW 5 ).md"
printf 'member\tmagic-tester\nfile\trig-ws:source/one/report.md\ndiff\t-old\\n+new\ncut\t2 more lines\n' > "$rigStore2/$( rigW 5 ).fields"
mkdir -p "$rigAgents2/sessions/rig-change-sess/changes/change-rig-other" "$rigAgents2/sessions/rig-change-sess/changes/change-rig-0001"
printf 'owner: magic-tester\nsession-id: rig-change-sess\ntool: Edit\nfile: /rig/ws/source/one/other.md\nask: 55555555-0000-0000-0000-000000000099\n' > "$rigAgents2/sessions/rig-change-sess/changes/change-rig-other/change"
printf 'owner: magic-tester\nsession-id: rig-change-sess\ntool: Edit\nfile: /rig/ws/source/one/report.md\nmatched: 1\nask: %s\nheld-at: 2026-10-12 12:20 +0300\n' "$( rigW 5 )" > "$rigAgents2/sessions/rig-change-sess/changes/change-rig-0001/change"
printf -- '--- a/report.md\n+++ b/report.md\n@@ -1,3 +1,3 @@\n-old\n+new\n \n same\n' > "$rigAgents2/sessions/rig-change-sess/changes/change-rig-0001/change.diff"

rigOp2 wlist --member-pending-reply-read magic-coordinator --any-owner
rigAssert "the list does not change: five records, and nothing of the stored part" "$( LC_ALL=C sed -n 's/^PENDING-REPLIES: //p' "$rigTmp/wlist" ):$( LC_ALL=C grep -c -e '^PENDING-REPLY-STORED' -e '^posted: ' -e '^option: ' "$rigTmp/wlist" )" "5:0"
rigStoreBefore="$( cat "$rigStore2"/* | cksum ):$( ls "$rigStore2" | LC_ALL=C awk 'END { print NR + 0 ; }' )"
for rigWNo in 1 2 3 4 5 ; do rigOp2 "whole$rigWNo" --member-pending-reply-read magic-coordinator "$( rigW "$rigWNo" )" ; done
## The lines of today stay as they are: the block a list prints for that record, byte for byte, comes first.
rigWholeHead=""
for rigWNo in 1 2 3 4 5 ; do
	rigListBlockOf wlist "$rigWNo" > "$rigTmp/wblock.want"
	head -n "$( LC_ALL=C awk 'END { print NR + 0 ; }' "$rigTmp/wblock.want" )" "$rigTmp/whole$rigWNo" > "$rigTmp/wblock.got"
	cmp -s "$rigTmp/wblock.got" "$rigTmp/wblock.want" && [ -s "$rigTmp/wblock.want" ] && rigWholeHead="$rigWholeHead$rigWNo"
done
rigAssert "one record by its id starts with the lines a list prints for it, byte for byte, the blank line too" "$rigWholeHead" 12345
rigAssert "then the stored part, under its own head, right after that blank line" "$( LC_ALL=C grep -n -x -F "PENDING-REPLY-STORED: $( rigW 1 )" "$rigTmp/whole1" | cut -d: -f1 ):$( LC_ALL=C grep -c '^PENDING-REPLY-STORED: ' "$rigTmp/whole1" )" "$(( $( rigListBlockOf wlist 1 | LC_ALL=C awk 'END { print NR + 0 ; }' ) + 1 )):1"
rigAssert "every line of the stored part is a name, a colon, a space and its text, to the closing blank line" "$( LC_ALL=C awk 'storedPart && $0 != "" && $0 !~ /^[a-z][a-z0-9_.-]*: / { badLines++ ; } index( $0, "PENDING-REPLY-STORED: " ) == 1 { storedPart = 1 ; } END { print badLines + 0 ; }' "$rigTmp/whole1" ):$( tail -n 1 "$rigTmp/whole1" | LC_ALL=C grep -c '^$' )" "0:1"
## A decision with options.
rigAssert "a decision: its options, each with its words" "$( rigWholeOf whole1 option )" "Keep - the layout stays as it is.
Hold - nothing moves until the review."
rigAssert "the question it was asked with, whole, its lines kept under the one name" "$( rigWholeOf whole1 field-question )" "Which of the two layouts does the rig keep?
The second line of the question."
rigAssert "a backslash of a slot is read back as it was written" "$( rigWholeOf whole1 field-context )" 'A path such as C:\rig\layout is named as it is.'
rigAssert "the tool it was asked with and its tag" "$( rigWholeOf whole1 field-asked-as ):$( rigWholeOf whole1 field-tag )" "EscalateDecision:Q7"
rigAssert "the question as it was posted, every line, the empty ones too" "$( rigWholeOf whole1 posted | cksum )" "$( printf '# 🧭 Decision Q7\n\nWhich of the two layouts does the rig keep?\nThe second line of the question.\n\n**📋 Options**\n- Keep - the layout stays as it is.\n- Hold - nothing moves until the review.\n\n**⚙ Context**\nA path such as C:\\rig\\layout is named as it is.\n\n**✅ How to answer**\n- reply with the first word of the option you choose\n' | cksum )"
rigAssert "what was said in its thread since, as the record keeps it" "$( rigWholeOf whole1 clarification )" "1700000001.000300 URIGOWNER: which review do you mean?"
rigAssert "the header fields a list leaves out, each under its own name: the reason, the task, where it was posted" \
	"$( rigWholeOf whole1 reason )|$( rigWholeOf whole1 task-ref )|$( rigWholeOf whole1 host )|$( rigWholeOf whole1 communication-channel-id )|$( rigWholeOf whole1 addressees )|$( rigWholeOf whole1 ask-identity )" \
	"The rig cannot go on until one layout is chosen.|the rig task|rig-elsewhere|slack:human-owner|URIGOWNER|bot"
rigAssert "and none of the fields printed above it a second time" "$( LC_ALL=C grep -c -e '^status: ' "$rigTmp/whole1" ):$( LC_ALL=C grep -c -e '^channel: ' "$rigTmp/whole1" ):$( LC_ALL=C grep -c -e '^item: ' "$rigTmp/whole1" )" "1:1:1"
rigAssert "what lies beside the record is named" "$( rigWholeOf whole1 kept-beside )" "fields options"
## A permission set with entries.
rigAssert "a permission set: its entries" "$( rigWholeOf whole2 set-entry )" "Edit:/rig/ws/source/one/**
WebSearch"
rigAssert "its scope, its item and its participants" "$( rigWholeOf whole2 set-scope ):$( rigWholeOf whole2 set-item ):$( rigWholeOf whole2 set-participants )" "task:task-rig-whole:magic-tester keeper-rig"
rigAssert "what each place is for, what is held already, and the reason" "$( rigWholeOf whole2 set-purpose )|$( rigWholeOf whole2 set-held )|$( rigWholeOf whole2 set-reason )" \
	"/rig/ws/source/one/**${rigTab}Write the rig report into its own folder.|Read:/rig/ws/source/one/**${rigTab}magic-tester|The rig task writes one report."
rigAssert "and the mark beside it" "$( rigWholeOf whole2 kept-beside )" "set told"
## A plain question of several lines.
printf 'May the rig keep its report?\n\nIt holds three parts:\n- the list\n- the totals\n\n  An indented last line: it ends here.\n' > "$rigTmp/whole3.want"
rigWholeOf whole3 posted > "$rigTmp/whole3.got"
rigAssert "a plain question of several lines: the first line stays where a list has it" "$( LC_ALL=C sed -n 's/^question: //p' "$rigTmp/whole3" )" "May the rig keep its report?"
rigAssert "and the whole of it follows, line for line, an empty line being the name alone" "$( cmp -s "$rigTmp/whole3.got" "$rigTmp/whole3.want" && echo same || diff "$rigTmp/whole3.got" "$rigTmp/whole3.want" | head -5 ):$( LC_ALL=C grep -c -x -F 'posted: ' "$rigTmp/whole3" )" "same:2"
rigAssert "its text ends where the next line has another name, or none" "$( LC_ALL=C awk 'index( $0, "posted: " ) == 1 { inText = 1 ; next ; } inText { print ( $0 == "" ? "blank" : $0 ) ; exit ; }' "$rigTmp/whole3" )" "blank"
rigAssert "a record with nothing beside it names nothing" "$( rigWholeOf whole3 kept-beside ):$( LC_ALL=C grep -c -e '^option: ' -e '^field-' -e '^set-' "$rigTmp/whole3" )" ":0"
## A permission: the refused call.
rigAssert "a permission: the call that was refused, from the record its refusal-id names" "$( rigWholeOf whole4 refused-tool ):$( rigWholeOf whole4 refused-target ):$( rigWholeOf whole4 refused-at )" "Edit:/rig/ws/source/one/report.md:2026-10-12 12:14 +0300"
rigAssert "what the tool said, its lines kept, and the place as it is shown" "$( rigWholeOf whole4 refused-text )|$( rigWholeOf whole4 refused-place )" \
	"ERROR: path not in the allowed access-root set: /rig/ws/source/one/report.md
Ask for it with RequestPermission.|/rig/ws/source/one/report.md${rigTab}rig-ws:source/one/report.md"
## A held change: the whole diff.
rigAssert "a held change: the change its prompt is of, found by the ask it names, and no other" "$( rigWholeOf whole5 change-file ):$( rigWholeOf whole5 change-tool ):$( rigWholeOf whole5 change-store | LC_ALL=C sed 's/.*\/sessions\///' )" "/rig/ws/source/one/report.md:Edit:rig-change-sess/changes/change-rig-0001"
rigAssert "the whole change as a diff, line for line, and the diff its prompt showed" "$( rigWholeOf whole5 change-diff | cksum ):$( rigWholeOf whole5 field-diff | LC_ALL=C tr '\n' '|' ):$( rigWholeOf whole5 field-cut )" \
	"$( printf -- '--- a/report.md\n+++ b/report.md\n@@ -1,3 +1,3 @@\n-old\n+new\n \n same\n' | cksum ):-old|+new|:2 more lines"
rigAssert "a read of one record still writes nothing: every record and file beside it is as it was" "$( cat "$rigStore2"/* | cksum ):$( ls "$rigStore2" | LC_ALL=C awk 'END { print NR + 0 ; }' )" "$rigStoreBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER PENDING REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_PENDING_REPLY: OK (%d assertions, offline)\n' "$rigPassCount"
