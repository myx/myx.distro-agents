#!/usr/bin/env bash
## Behavioural check on the authority to resolve or dismiss a run's pending question, and on escalation up the chain
## (F6.10 of the refactorings epic). The authority is held by the run's reports-to (F6.8), by the owners role at the top
## of every chain (F6.11), and by anyone the owners role grants it to by a recorded permission; never by a built-in
## equality. A person at a console acts as `user-<account>`, and a console account is never the owners role, even where
## it is mapped to an owner: the mapping only sends a confirmation to that owner's authenticated channel, a second
## factor. Without the authority nothing is disabled: by default the operation fails, naming the authority it needs and
## its two options. `--escalate-wait [--timeout <s>]` escalates and waits, with no timeout by default: exit 0 approved
## and acted, 1 denied, 124 at the timeout. `--escalate-enqueue` escalates and returns at once, `PENDING <id>` on its first line,
## exit 0, and acts when the answer arrives, through the pending-collect sweep. An escalation is any decision that cannot
## be made within the quorum available -- a permission, a choice among answers, a text, a confirmation -- and goes to the
## reports-to, then up its chain. A coordinator never escalates to the same coordinator run: it goes to its parent
## session, else to the person who started it, else to the owners role. The pending state of questions and escalations
## lives in `.local/<that subsystem>/`, not under `.local/agents/`.
## The mapping of a console account to an owner is one rig setting (rigOwnerKey, below), the only place its name is
## spelled, until the owner names the real one.
## Held, through --manager-pending-reply-answer and -dismiss (the console), --magic-escalation-answer and the served
## EscalateDecision (a member's run):
##   1. the console caller who is the run's reports-to answers at once
##   2. a console caller who is not: the bare call fails, naming the authority needed and both options; the original is
##      untouched and no request is made
##   3. --escalate-enqueue: PENDING, exit 0, a request to the reports-to, the original untouched, its state outside .local/agents
##   4. a run with no reports-to and no parent: the enqueued request goes to the owners role
##   5. a mapped console account: not at once; a confirmation goes to the owner's channel, and only that acts
##   6. a grant: refused before it, the console caller resolves the questions of that session at once after the owners
##      role grants it by a recorded permission
##   7. a dismissal without the authority fails as the answer does; enqueued, the question is not withdrawn
##   8. the sweep: once the holder's allow stands in the request's thread, the original is answered as was asked
##   9. --escalate-wait: no timeout by default; approved by the holder, exit 0 and acted; denied, exit 1 and untouched;
##      at --timeout, exit 124 and untouched
##  10. a choice among answers goes up the chain as a choice: to the reports-to with its options, and from that run,
##      escalated again, to that run's own reports-to
##  11. the coordinator escalates to its parent session, else to the person who started it, else to the owners role,
##      and never to magic-coordinator; where it is the reports-to it answers at once
## Red before F6.10: anyone answers or dismisses any question at once (2-11 fail but the controls).
## Offline: a Slack-shaped fake curl first on PATH, a ps that lists the rig's own runs only beside it; everything runs
## in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
## THE ONE PLACE the setting that maps a console account to an owner is named.
rigOwnerKey="HUMAN_OWNER_CONSOLE_ACCOUNT"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] && [ -f "$rigHarness" ] || rigRefuse "the tool or the harness is not at the origin this workspace resolves: $MDLT_ORIGIN"
## The one way a check signals a process it started: sourced before the rig puts anything on PATH.
. "$rigTest/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAuthorityResolveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigKept=""
trap 'rigProcGroupSignal KILL $rigKept ; chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*)\n\t\tcase "$*" in\n\t\t\t*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;\n\t\t\t*) sed '"'"'s/^[^ ]* //'"'"' "$RIG_PS_LIST" 2> /dev/null ;;\n\t\tesac\n\t\texit 0\n\t;;\nesac\nexec "$RIG_PS_REAL" "$@"\n' > "$rigTmp/bin/ps"
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"
for rigName in magic-coordinator magic-tester magic-developer keeper-myx ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---------------------------------------------------------------- the workspace, its sessions and runs
rigAcct="$( id -un 2>/dev/null )" || rigAcct=""
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
[ -n "$rigAcct" ] || rigAcct="unknown"
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigData/board/running" "$rigData/board/review"
: > "$rigWs/.local/agents/permissions.registry"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
## The console account an owner is mapped to: another account, or this one.
rigMapOwnerTo(){ ## account
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_WORKSPACE_DOMAIN=rig.slack.example\n%s=%s\n' "$rigOwnerKey" "$1" > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigMapOwnerTo rig-owner-account
## A run: its spawn record in its session, live in the rig's process list.
rigRun(){ ## spawn id, session, member, start-context, reports-to (empty: none), parent-session-id (empty: none, and no line, as the spawner writes it)
	mkdir -p "$rigWs/.local/agents/spawned/$2" "$rigWs/.local/agents/sessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\n%sstart-context: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$2" "$1" "${6:+parent-session-id: $6$'\n'}" "$4" "${5:+reports-to: $5$'\n'}" "$rigHost" "$3" > "$rigWs/.local/agents/spawned/$2/$1.md"
	printf 'CRIG00001:1700000000.0009%02d\n' "$(( ${#2} % 100 ))" > "$rigWs/.local/agents/sessions/$2/session.thread"
	printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" "$1" >> "$RIG_PS_LIST"
}
rigRun rig-coord rig-cow magic-coordinator spawned human-owner ""
rigRun rig-tester rig-cow magic-tester joined magic-coordinator rig-cow
rigRun rig-dev rig-cow magic-developer joined "user-$rigAcct" rig-cow
rigRun rig-keeper rig-cow keeper-myx joined "user-rig-other" rig-cow
rigRun rig-orphan rig-alone magic-tester spawned "" ""
rigRun rig-owned rig-cow keeper-myx joined human-owner rig-cow
rigRun rig-chain rig-cow magic-developer joined rig-cow:magic-tester rig-cow
rigRun rig-granted-a rig-grant keeper-myx spawned magic-coordinator ""
rigRun rig-granted-b rig-grant magic-tester joined magic-coordinator rig-grant
## Three coordinators lacking the authority: one with a parent session, one started by a person, one with neither.
rigRun rig-parent-founder rig-parent keeper-myx spawned human-owner ""
rigRun rig-coord-p rig-child-p magic-coordinator spawned "" rig-parent
rigRun rig-coord-u rig-child-u magic-coordinator spawned "user-rig-starter" ""
rigRun rig-coord-n rig-child-n magic-coordinator spawned "" ""
rigRun rig-asks-p rig-child-p keeper-myx joined human-owner rig-child-p
rigRun rig-asks-u rig-child-u keeper-myx joined human-owner rig-child-u
rigRun rig-asks-n rig-child-n keeper-myx joined human-owner rig-child-n

## An operation as the console calls it: from no session and as no member, unless one is named.
RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOpRc=0
rigOp(){ ## operation and its arguments -- out in $rigTmp/op.out, err in $rigTmp/op.err, rc in rigOpRc
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err" < /dev/null || rigOpRc=$?
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
## The record of a question or a request by its id, wherever its subsystem keeps it under .local.
rigRecordOf(){ ## pending id
	[ -n "$1" ] || return 0
	find "$rigWs/.local" -type f -name "$1.md" 2> /dev/null | head -1
}
rigKeptWhere(){ ## pending id -- outside-agents where its record is under .local but not .local/agents, under-agents, or none
	local keptFile
	keptFile="$( rigRecordOf "$1" )"
	case "$keptFile" in
		'') printf none ;;
		"$rigWs/.local/agents/"*) printf under-agents ;;
		*) printf outside-agents ;;
	esac
}
rigStatus(){ ## pending id -- `<status>:<verdict>` of that record
	local statusFile
	statusFile="$( rigRecordOf "$1" )"
	printf '%s:%s' "$( rigField "${statusFile:-/nonexistent}" status )" "$( rigField "${statusFile:-/nonexistent}" verdict )"
}
## A question a run asks, with its own thread: rigPend.
rigAskNo=0
rigAsk(){ ## asking run, its member, kind, further arguments of the open...
	local askRun="$1" askMember="$2" askKind="$3" askThread
	shift 3
	rigAskNo=$(( rigAskNo + 1 ))
	askThread="1700000000.0001$( printf '%02d' "$rigAskNo" )"
	rigPend="$( printf '# Ask\n\nMay I?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" bash "$rigTools" \
		--intern-op-pending-reply-open "$askMember" --to CRIG00001 --session-id "$askRun" --kind "$askKind" --address-to human-owner \
		--channel CRIG00001 --question-ts "$askThread" --thread-ts "$askThread" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' --ask-identity bot "$@" 2>/dev/null ) )"
	[ -n "$rigPend" ] && [ -n "$( rigRecordOf "$rigPend" )" ] || rigRefuse "no pending question could be opened"
}
rigOptions="$( printf -- '- keep: keep the file\n- drop: drop it\n- move: move it' )"
rigPendingId(){ LC_ALL=C sed -n '1s/^PENDING \([^ ]*\).*/\1/p' "$rigTmp/op.out" ; }
## The request a PENDING line names: `<kind> <address-to>`, or none.
rigRequest(){ ## pending id
	local requestFile
	requestFile="$( rigRecordOf "$1" )"
	[ -n "$requestFile" ] || { printf none ; return 0 ; }
	printf '%s %s' "$( rigField "$requestFile" kind )" "$( rigField "$requestFile" address-to )"
}
## The refusal of a bare call: failed, naming the authority it needs and both options -- `refused:<authority named>`.
rigRefusal(){ ## authority it must name
	local refusalText
	refusalText="$( cat "$rigTmp/op.out" "$rigTmp/op.err" 2> /dev/null )"
	if [ "$rigOpRc" -eq 0 ] ; then printf 'acted:exit-0' ; return 0 ; fi
	printf 'refused:%s:%s:%s' "$( printf '%s' "$refusalText" | LC_ALL=C grep -c -F -- "$1" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "names-it" : "names-not" }' )" \
		"$( printf '%s' "$refusalText" | LC_ALL=C grep -c -F -- '--escalate-wait' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "wait" : "no-wait" }' )" \
		"$( printf '%s' "$refusalText" | LC_ALL=C grep -c -F -- '--escalate-enqueue' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "enqueue" : "no-enqueue" }' )"
}
rigRefusedAs(){ ## authority -- the string rigRefusal gives for a right refusal
	printf 'refused:names-it:wait:enqueue'
}
## Every request addressed to someone, other than the questions this rig opened itself.
rigRequestsTo(){ ## addressee
	find "$rigWs/.local" -type f -name '*.md' 2> /dev/null | while IFS= read -r requestsFile ; do
		[ "$( rigField "$requestsFile" address-to )" = "$1" ] || continue
		[ "$( rigField "$requestsFile" session-id )" != "" ] || continue
		printf '%s\n' "$requestsFile"
	done | LC_ALL=C grep -c . || :
}
rigSeen=""
rigSeenMark(){ rigSeen=" $( find "$rigWs/.local" -type f -name '*.md' 2> /dev/null | LC_ALL=C tr '\n' ' ' )" ; }
rigNewRequest(){ ## -- the id of a request record made since rigSeenMark, whose address-to is set
	local newFile
	for newFile in $( find "$rigWs/.local" -type f -name '*.md' 2> /dev/null ) ; do
		case "$rigSeen" in *" $newFile "*) continue ;; esac
		[ -n "$( rigField "$newFile" address-to )" ] || continue
		basename "$newFile" .md ; return 0
	done
}
rigHasNew(){ [ -n "$( rigNewRequest )" ] ; }
## An operation started with --escalate-wait, in the background, as a group of its own: its pid in rigBgPid.
rigBg(){ ## result prefix, operation and its arguments...
	local bgOut="$1" ; shift
	set -m
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" bash "$rigTools" "$@" ; printf '%s' "$?" > "$bgOut.rc" ) > "$bgOut.out" 2> "$bgOut.err" < /dev/null &
	rigBgPid=$! ; rigBgRc="$bgOut.rc"
	set +m
	rigProcNote "$rigBgPid" ; rigKept="$rigKept $rigBgPid"
}
rigBgEnd(){ ## pid, guard seconds -- its exit status once it ends, `still-running` where the guard ran out first
	local endLeft="$2" endRc=0
	while [ -n "$( rigProcStill "$1" )" ] && [ "$endLeft" -gt 0 ] ; do sleep 1 ; endLeft=$(( endLeft - 1 )) ; done
	if [ -n "$( rigProcStill "$1" )" ] ; then
		rigProcGroupSignal TERM "$1" ; sleep 1 ; rigProcGroupSignal KILL "$1"
		wait "$1" 2> /dev/null || :
		printf still-running ; return 0
	fi
	wait "$1" 2> /dev/null || endRc=$?
	## Called in a $( ) subshell, whose wait cannot read the status of its parent's job: the call kept its own.
	[ ! -s "${rigBgRc:-/nonexistent}" ] || endRc="$( cat "$rigBgRc" )"
	printf '%s' "$endRc"
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}
rigWaiting(){ ## pid -- whether it still runs, its request made: waiting, or not-waiting
	[ -n "$( rigNewRequest )" ] && [ -n "$( rigProcStill "$1" )" ] && printf waiting || printf not-waiting
}
## The holder of a request answers it: the reports-to magic-coordinator, from its own run.
rigHolderAnswers(){ ## request id, verdict
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "${1:-none}" "$2"
}
## The posts made to the owner's own channel, and their texts.
rigOwnerPosts(){ ## fixed text -- how many posts to the human-owner's channel hold it
	local ownerPost ownerCount=0
	for ownerPost in "$rigTmp"/post.* ; do
		[ -f "$ownerPost" ] || continue
		LC_ALL=C grep -q -F '"channel":"URIGOWNER"' "$ownerPost" 2> /dev/null || LC_ALL=C grep -q -F '"channel": "URIGOWNER"' "$ownerPost" 2> /dev/null || continue
		LC_ALL=C grep -q -F -- "$1" "$ownerPost" && ownerCount=$(( ownerCount + 1 ))
	done
	printf '%s' "$ownerCount"
}

echo "-- 1. the console caller who is the run's reports-to answers at once --"
rigAsk rig-dev magic-developer decision --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rigAssert "answered at once: exit 0, no PENDING, the question closed with the answer" "$rigOpRc:$( rigPendingId ):$( rigStatus "$rigPend" )" "0::reply-received:keep"

echo "-- 2. a console caller who is not: the bare call fails, naming the authority and both options --"
rigAsk rig-tester magic-tester decision --options "$rigOptions"
rigSeenMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rigAssert "refused, naming magic-coordinator, --escalate-wait and --escalate-enqueue" "$( rigRefusal magic-coordinator )" "$( rigRefusedAs )"
rigAssert "the original is untouched, and no request is made" "$( rigStatus "$rigPend" ):$( rigNewRequest )" "reply-pending::"

echo "-- 3. --escalate-enqueue: PENDING, a request to the reports-to, the original untouched --"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep --escalate-enqueue
rigEscalated="$( rigPendingId )"
rigAssert "the first line is PENDING <id>, exit 0"            "$rigOpRc:$( [ -n "$rigEscalated" ] && printf pending || LC_ALL=C sed -n 1p "$rigTmp/op.out" )" "0:pending"
rigAssert "the request is addressed to the reports-to"        "$( rigRequest "$rigEscalated" | LC_ALL=C sed 's/^[^ ]* //' )" magic-coordinator
rigAssert "the original is untouched"                         "$( rigStatus "$rigPend" )" "reply-pending:"
rigAssert "its pending state is under .local/, not under .local/agents/" "$( rigKeptWhere "$rigEscalated" )" outside-agents
rigTesterPend="$rigPend"

echo "-- 4. a run with no reports-to and no parent: the enqueued request goes to the owners role --"
rigAsk rig-orphan magic-tester decision --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer drop --escalate-enqueue
rigAssert "PENDING, the request addressed to human-owner"     "$rigOpRc:$( rigRequest "$( rigPendingId )" | LC_ALL=C sed 's/^[^ ]* //' )" "0:human-owner"
rigAssert "the original is untouched"                         "$( rigStatus "$rigPend" )" "reply-pending:"

echo "-- 5. a console account mapped to an owner: a confirmation to the owner's channel, and only that acts --"
rigMapOwnerTo "$rigAcct"
rigAsk rig-owned keeper-myx decision --options "$rigOptions"
rm -f "$rigTmp"/post.* "$rigTmp/posts"
rigSeenMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer drop
rigAssert "not at once: the original is untouched"            "$( rigStatus "$rigPend" )" "reply-pending:"
rigConfirm="$( rigNewRequest )"
rigAssert "a confirmation is posted to the owner's own channel" "$( [ -n "$rigConfirm" ] && printf made || printf none ):$( rigOwnerPosts "$rigAcct" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "posted" : "not-posted" }' )" "made:posted"
rigAssert "the confirmation goes as a readback"               "$( rigRequest "$rigConfirm" | LC_ALL=C cut -d' ' -f1 )" readback
rigConfirmTs="$( rigField "$( rigRecordOf "$rigConfirm" )" question-ts 2> /dev/null )"
if [ -n "$rigConfirmTs" ] ; then
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"Confirm?"},{"ts":"1700000600.000001","user":"URIGOWNER","text":"yes","thread_ts":"%s"}],"has_more":false}\n' "$rigConfirmTs" "$rigConfirmTs" > "$rigTmp/replies.$rigConfirmTs.json"
fi
rigOp --intern-op-pending-reply-collect --ended --context rig-authority
rigAssert "the owner confirms in Slack: then the original is answered" "$( rigStatus "$rigPend" )" "reply-received:drop"
rigMapOwnerTo rig-owner-account

echo "-- 6. a grant by the owners role, a recorded permission: refused before it, at once after it --"
rigAsk rig-granted-a keeper-myx decision --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rigAssert "before the grant: refused"                         "$( rigRefusal magic-coordinator )" "$( rigRefusedAs )"
rigGrantRefusal="$( cat "$rigTmp/op.out" "$rigTmp/op.err" | LC_ALL=C grep -o -E 'refusal-[0-9a-f-]+' | head -1 )"
rigOp --intern-op-permission-grant-open human-owner --session-id rig-grant --refusal-id "${rigGrantRefusal:-none}" --kind session
rigAssert "the owners role grants it, recorded"               "$rigOpRc:$( LC_ALL=C grep -c '^GRANT: session ' "$rigTmp/op.out" )" "0:1"
rigAsk rig-granted-b magic-tester decision --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer drop
rigAssert "after the grant: another question of that session is answered at once" "$rigOpRc:$( rigPendingId ):$( rigStatus "$rigPend" )" "0::reply-received:drop"

echo "-- 7. a dismissal without the authority: refused bare; enqueued, the question is not withdrawn --"
rigAsk rig-tester magic-tester question
rigOp --manager-pending-reply-dismiss --id "$rigPend" --reason "stale"
rigAssert "refused, naming magic-coordinator and both options" "$( rigRefusal magic-coordinator )" "$( rigRefusedAs )"
rigOp --manager-pending-reply-dismiss --id "$rigPend" --reason "stale" --escalate-enqueue
rigAssert "enqueued: PENDING, a request to the reports-to"    "$rigOpRc:$( rigRequest "$( rigPendingId )" | LC_ALL=C sed 's/^[^ ]* //' )" "0:magic-coordinator"
rigAssert "a dismissal goes as a permission"                  "$( rigRequest "$( rigPendingId )" | LC_ALL=C cut -d' ' -f1 )" permission
rigAssert "the question is not withdrawn"                     "$( rigStatus "$rigPend" )" "reply-pending:"

echo "-- 8. the sweep: once the holder's allow stands in the request's thread, the original is answered --"
## The request was asked as the ask tools ask a member: a reply in the session's thread. The answer
## sits in that thread, after it.
rigEscalatedTs="$( rigField "$( rigRecordOf "$rigEscalated" )" question-ts 2> /dev/null )"
rigEscalatedThread="$( rigField "$( rigRecordOf "$rigEscalated" )" thread-ts 2> /dev/null )"
if [ -n "$rigEscalatedTs" ] && [ -n "$rigEscalatedThread" ] ; then
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"session opened"},{"ts":"%s","user":"URIGBOT01","text":"May the console answer?","thread_ts":"%s"},{"ts":"1700000500.000001","user":"URIGOWNER","text":"allow-once","thread_ts":"%s"}],"has_more":false}\n' \
		"$rigEscalatedThread" "$rigEscalatedTs" "$rigEscalatedThread" "$rigEscalatedThread" > "$rigTmp/replies.$rigEscalatedThread.json"
fi
rigAssert "before the allow, the original is still untouched" "$( rigStatus "$rigTesterPend" )" "reply-pending:"
rigOp --intern-op-pending-reply-collect --ended --context rig-authority
rigAssert "after the sweep, it is answered as the console asked" "$( rigStatus "$rigTesterPend" )" "reply-received:keep"

echo "-- 9. --escalate-wait: no timeout by default; approved, denied, or the timeout --"
rigAsk rig-tester magic-tester decision --options "$rigOptions"
rigSeenMark
rigBg "$rigTmp/w1" --manager-pending-reply-answer --id "$rigPend" --answer drop --escalate-wait
rigWaitFor 20 rigHasNew
sleep 5
rigAssert "it waits, its request made, and no default timeout ends it" "$( rigWaiting "$rigBgPid" )" waiting
rigAssert "nothing is acted while it waits"                   "$( rigStatus "$rigPend" )" "reply-pending:"
rigHolderAnswers "$( rigNewRequest )" allow-once
rigAssert "approved by the holder: exit 0"                    "$( rigBgEnd "$rigBgPid" 30 )" 0
rigAssert "and acted"                                         "$( rigStatus "$rigPend" )" "reply-received:drop"
rigAsk rig-tester magic-tester decision --options "$rigOptions"
rigSeenMark
rigBg "$rigTmp/w2" --manager-pending-reply-answer --id "$rigPend" --answer drop --escalate-wait --timeout 60
rigWaitFor 20 rigHasNew
rigAssert "it waits, its request made"                        "$( rigWaiting "$rigBgPid" )" waiting
rigHolderAnswers "$( rigNewRequest )" deny
rigAssert "denied: exit 1"                                    "$( rigBgEnd "$rigBgPid" 30 )" 1
rigAssert "and the original untouched"                        "$( rigStatus "$rigPend" )" "reply-pending:"
rigSeenMark
rigBg "$rigTmp/w3" --manager-pending-reply-answer --id "$rigPend" --answer keep --escalate-wait --timeout 4
sleep 2
rigAssert "it waits, its request made"                        "$( rigWaiting "$rigBgPid" )" waiting
rigAssert "no answer: exit 124 at the timeout"                "$( rigBgEnd "$rigBgPid" 30 )" 124
rigAssert "and the original untouched"                        "$( rigStatus "$rigPend" )" "reply-pending:"

echo "-- 10. a choice among answers goes up the chain as a choice --"
rigAsk rig-chain magic-developer decision --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer move --escalate-enqueue
rigChoice="$( rigPendingId )"
rigAssert "a request to the reports-to, the tester's run in its session" "$( rigRequest "$rigChoice" | LC_ALL=C sed 's/^[^ ]* //' )" "rig-cow:magic-tester"
rigAssert "a choice, not a permission: its kind is decision, and its options are the question's" \
	"$( rigRequest "$rigChoice" | LC_ALL=C cut -d' ' -f1 ):$( LC_ALL=C grep -c -E '(keep|drop|move)' "$( rigRecordOf "$rigChoice" )" 2> /dev/null | LC_ALL=C awk '{ print ( $1 >= 3 ) ? "options" : "no-options" }' )" "decision:options"
## No `to`: an escalation that names no other target goes to the run's reports-to (F6.8). It always waits: bounded here.
printf '{"question":"Which of keep, drop or move is right for the developer file?","options":"keep: keep the file\\ndrop: drop it\\nmove: move it","timeout":2}' > "$rigTmp/escalate.args"
rigSeenMark
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
	MDAT_SESSION_ID=rig-cow MDAT_SPAWN_SESSION_ID=rig-tester MDAT_SPAWN_AGENT=magic-tester bash "$rigHarness" --intern-tool EscalateDecision < "$rigTmp/escalate.args" ) > "$rigTmp/escalate.out" 2> "$rigTmp/escalate.err"
rigAssert "the tester's run escalates it again: to its own reports-to, magic-coordinator" "$( rigRequest "$( rigNewRequest )" | LC_ALL=C sed 's/^[^ ]* //' )" magic-coordinator

echo "-- 11. the coordinator escalates up, never to itself --"
rigAsk rig-tester magic-tester decision --options "$rigOptions"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" keep
rigAssert "control: the coordinator, the tester's reports-to, answers at once" "$rigOpRc:$( rigPendingId ):$( rigStatus "$rigPend" )" "0::reply-received:keep"
rigToCoordBefore="$( rigRequestsTo magic-coordinator )"
for rigCase in "p|rig-parent" "u|user-rig-starter" "n|human-owner" ; do
	rigWhich="${rigCase%%|*}" ; rigTo="${rigCase#*|}"
	rigAsk "rig-asks-$rigWhich" keeper-myx decision --options "$rigOptions"
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION="rig-coord-$rigWhich" rigOp --magic-escalation-answer magic-coordinator "$rigPend" keep --escalate-enqueue
	rigAssert "coordinator $rigWhich: PENDING, a request to $rigTo" "$rigOpRc:$( rigRequest "$( rigPendingId )" | LC_ALL=C sed 's/^[^ ]* //' | LC_ALL=C sed 's/:.*//' )" "0:$rigTo"
	rigAssert "coordinator $rigWhich: the original untouched"  "$( rigStatus "$rigPend" )" "reply-pending:"
done
rigAssert "and no request is addressed to magic-coordinator itself" "$( rigRequestsTo magic-coordinator )" "$rigToCoordBefore"

echo "-- 13. a text to provide goes up as a question: the holder's reply is the text given --"
rigAsk rig-tester magic-tester question
rigTextPend="$rigPend"
rigOp --manager-pending-reply-answer --id "$rigTextPend" --answer "the console text" --escalate-enqueue
rigText="$( rigPendingId )"
rigAssert "PENDING, a request to the reports-to, as a question for the text, not a permission" "$rigOpRc:$( rigRequest "$rigText" )" "0:question magic-coordinator"
rigAssert "the original is untouched"                         "$( rigStatus "$rigTextPend" )" "reply-pending:"
rigTextTs="$( rigField "$( rigRecordOf "$rigText" )" question-ts 2> /dev/null )"
rigTextThread="$( rigField "$( rigRecordOf "$rigText" )" thread-ts 2> /dev/null )"
if [ -n "$rigTextTs" ] && [ -n "$rigTextThread" ] ; then
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"session opened"},{"ts":"%s","user":"URIGBOT01","text":"May the console give its text?","thread_ts":"%s"},{"ts":"1700000700.000001","user":"URIGOWNER","text":"the holder text","thread_ts":"%s"}],"has_more":false}\n' \
		"$rigTextThread" "$rigTextTs" "$rigTextThread" "$rigTextThread" > "$rigTmp/replies.$rigTextThread.json"
fi
rigOp --intern-op-pending-reply-collect --ended --context rig-authority
rigAssert "after the sweep, the request holds the holder's text, and the original is answered with it" \
	"$( rigField "$( rigRecordOf "$rigText" )" chosen ):$( rigField "$( rigRecordOf "$rigTextPend" )" status ):$( LC_ALL=C grep -c -F 'the holder text' "$( rigRecordOf "$rigTextPend" )" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "its-text" : "not-its-text" }' )" \
	"the holder text:reply-received:its-text"

echo "-- 12. the escalation tool states when to escalate, with its threshold, in its own description --"
rigAssert "EscalateDecision's description: only what needs the attention of the one reported to, and the rest decided" \
	"$( LC_ALL=C grep -o -E '"name":"EscalateDecision","description":"[^"]*"' "$rigHere/harness/AgentsOpenAiChatWire.sh" | LC_ALL=C grep -c -F -- 'Escalate only a decision that needs the attention of the one you report to: one outside your brief or your authority, or one that is costly to undo. Decide anything else yourself."' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AUTHORITY RESOLVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AUTHORITY_RESOLVE: OK (%d assertions, offline)\n' "$rigPassCount"
