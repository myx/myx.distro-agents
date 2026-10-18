#!/usr/bin/env bash
## Behavioural check on the console's way to a pending question (--manager-pending-reply-read,
## -answer, -dismiss): what can be done with one question, as rows; an answer by a word of the
## kind, by the number of an option and by words; the reject of a kind; a dismissal with and
## without a reason, its asker running or gone; the line each leaves in the question's
## thread, and what the record keeps; and every refusal -- no such question, one not pending,
## an answer the kind does not have, a second answer, a verdict that is the human-owner's own,
## a member's session. The answer and the dismissal are the tooling's one answer operation
## and one withdraw: what is checked here is that the console reaches them, with no session,
## for any asker, the coordinator among them; and that the one who asked is given, by its
## Wait, the words of an answer and who gave them, and of a dismissal who dismissed it and
## why. Offline: a Slack-shaped fake curl is first on
## PATH, a ps that lists the rig's own runs only is beside it, and everything runs in a
## workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

## The one way a check signals a process it started: sourced before the rig puts anything on PATH.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"

rigTmp="$( mktemp -d -t AgentsManagerPendingReplyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST, as AgentsEscalationOneReplyCheck keeps it.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The rig workspace: a coworking session rig-cow with the coordinator and the tester. The
## coordinator holds nothing, so an allow given in its name goes up the chain.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-cow" "$rigWs/.local/agents/sessions/rig-cow" "$rigData/board/running" "$rigWs/ELSE"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_WORKSPACE_DOMAIN=rig.slack.example\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigWs/.local/agents/permissions.registry"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSpawnRecord(){ ## spawn id, owner, parent session id
	printf -- '---\nsession-id: rig-cow\nspawn-id: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "${3:+parent-session-id: $3$'\n'}" "$rigHost" "$2" > "$rigWs/.local/agents/spawned/rig-cow/$1.md"
}
rigSpawnRecord rig-coord magic-coordinator ""
rigSpawnRecord rig-tester magic-tester rig-coord
printf 'CRIG00001:1700000000.000900\n' > "$rigWs/.local/agents/sessions/rig-cow/session.thread"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"
rigAcct="$( id -un 2>/dev/null )" || rigAcct=""
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
[ -n "$rigAcct" ] || rigAcct="unknown"

## An operation as the console calls it: from no session and as no member, unless one is named.
RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOpRc=0
rigOp(){
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err" || rigOpRc=$?
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
rigRow(){ ## first field, optional second field -> that row of the last output, tabs as |
	LC_ALL=C awk -F'\t' -v one="$1" -v two="${2:-}" '$1 == one && ( two == "" || $3 == two || $2 == two ) { gsub( /\t/, "|" ) ; print ; exit ; }' "$rigTmp/op.out"
}
## Each question has a thread of its own, named by its number: 1700000000.0001<n>.
rigAskNo=0
rigThread=""
rigPend=""
rigFile=""
rigAsk(){ ## owner, its session, kind, addressee, further arguments of the open... -> rigPend, rigFile, rigThread
	local askOwner="$1" askSession="$2" askKind="$3" askTo="$4"
	shift 4
	rigAskNo=$(( rigAskNo + 1 ))
	rigThread="1700000000.0001$( printf '%02d' "$rigAskNo" )"
	rigPend="$( printf '# Ask\n\nMay I?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open "$askOwner" --to CRIG00001 --session-id "$askSession" --kind "$askKind" --address-to "$askTo" \
		--channel CRIG00001 --question-ts "$rigThread" --thread-ts "$rigThread" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' --ask-identity bot "$@" 2>/dev/null ) )"
	[ -n "$rigPend" ] || rigRefuse "no pending question could be opened"
	rigFile="$rigWs/.local/agents/pending/$rigPend.md"
}
## The posts made since a mark that hold every text given, counted (the fake curl numbers each post).
rigPostMark=0
rigMark(){
	rigPostMark="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )"
}
rigNew(){ ## fixed text...
	local newNo newText newAll newCount=0 newLast
	newLast="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )"
	newNo="$rigPostMark"
	while [ "$newNo" -lt "$newLast" ] ; do
		newNo=$(( newNo + 1 ))
		[ -f "$rigTmp/post.$newNo" ] || continue
		newAll=1
		for newText in "$@" ; do LC_ALL=C grep -q -F -- "$newText" "$rigTmp/post.$newNo" || { newAll="" ; break ; } ; done
		[ -z "$newAll" ] || newCount=$(( newCount + 1 ))
	done
	printf '%s' "$newCount"
}
rigInThread(){ ## thread ts -> the JSON field that puts a post in that thread
	printf '"thread_ts":"%s"' "$1"
}
rigOptions="$( printf -- '- keep: keep the file\n- drop: drop it' )"

echo "-- a decision: what can be done, as rows --"
rigAsk magic-tester rig-tester decision human-owner --options "$rigOptions"
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "the read of a pending question succeeds" "$rigOpRc" "0"
rigAssert "the question row: status, kind, form, asker, addressee, whose word, words, no reject, dismiss, the link" "$( rigRow question )" \
	"question|$rigPend|reply-pending|decision|-|magic-tester|human-owner|magic-coordinator|words|-|yes|https://rig.slack.example/archives/CRIG00001/p${rigThread/./}"
rigAssert "the first option: its number, word, what becomes of it, its label" "$( rigRow answer keep )" "answer|1|keep|settles|keep the file"
rigAssert "the second option" "$( rigRow answer drop )" "answer|2|drop|settles|drop it"

echo "-- the refusals of an answer leave the question as it was --"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer 9
rigAssert "a number the question has not is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'is not an answer of this decision' )" "1:yes"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer maybe
rigAssert "a word the question has not is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'is not an answer of this decision' )" "1:yes"
rigOp --manager-pending-reply-answer --id "$rigPend" --reject
rigAssert "a reject of a kind with no negative answer is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'takes no reject' )" "1:yes"
rigOp --manager-pending-reply-answer --id no-such-question --answer keep
rigAssert "an answer to no such question is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'no pending question no-such-question' )" "1:yes"
rigOp --manager-pending-reply-read --id no-such-question
rigAssert "a read of no such question is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'no pending question no-such-question' )" "1:yes"
rigOp --manager-pending-reply-dismiss --id no-such-question
rigAssert "a dismissal of no such question is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'no pending question no-such-question' )" "1:yes"
RIG_OP_AGENT=magic-tester RIG_OP_SESSION=rig-tester rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rigAssert "a member's session is refused" "$rigOpRc:$( rigHas "$rigTmp/op.err" "the console's own" )" "1:yes"
rigOp --magic-escalation-answer magic-coordinator "$rigPend" keep
rigAssert "the coordinator's own stub still asks for a session" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'carries no session id' )" "1:yes"
rigAssert "after every refusal the question is still pending, and nothing was posted" "$( rigField "$rigFile" status ):$( rigNew 'console' )" "reply-pending:0"

echo "-- a decision answered by the number of an option --"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer 2
rigAssert "the row says answered, with the option's word, whose word and the account" "$rigOpRc:$( rigRow answered )" "0:answered|$rigPend|drop|magic-coordinator|console:$rigAcct|-"
rigAssert "the record closed as an answer read from its thread closes it" "$( rigField "$rigFile" status ):$( rigField "$rigFile" verdict ):$( rigField "$rigFile" answered-by )" "reply-received:drop:magic-coordinator"
rigAssert "the record names the console and the account" "$( rigField "$rigFile" answered-session )" "console:$rigAcct"
rigAssert "one line in the question's thread says it was answered from the console, by whom, with what" \
	"$( rigNew "Answered from the console by $rigAcct" 'drop' "$( rigInThread "$rigThread" )" )" "1"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer 1
rigAssert "a second answer is refused, and says how it was answered" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'is answered already, with "drop" by magic-coordinator' ):$( rigField "$rigFile" verdict ):$( rigNew 'console' )" "1:yes:drop:0"
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "an answered question takes no answer, reject or dismissal any more" "$( rigRow question | cut -d'|' -f3,9-11 ):$( rigRow answer )" "reply-received|-|-|no:"

echo "-- a decision the coordinator asked, answered by a word, with words --"
rigAsk magic-coordinator rig-coord decision human-owner --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer Keep --text "for now"
rigAssert "the operator is not the asker: the coordinator's own question is answered" "$rigOpRc:$( rigRow answered )" "0:answered|$rigPend|keep|magic-coordinator|console:$rigAcct|for now"
rigAssert "its words are kept with the verdict" "$( rigField "$rigFile" verdict ):$( rigField "$rigFile" verdict-text )" "keep:for now"

echo "-- a readback rejected --"
rigAsk magic-tester rig-tester readback human-owner
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "a readback names its reject" "$( rigRow question | cut -d'|' -f10 ):$( rigRow answer no )" "no:answer|-|no|settles|-"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --reject
rigAssert "the reject gives the kind's own negative answer" "$rigOpRc:$( rigRow rejected ):$( rigField "$rigFile" verdict )" "0:rejected|$rigPend|no|magic-coordinator|console:$rigAcct|-:no"
rigAssert "its line says rejected from the console" "$( rigNew "Rejected from the console by $rigAcct" "$( rigInThread "$rigThread" )" )" "1"

echo "-- a permission: an allow the coordinator does not hold goes up the chain, a deny settles --"
rigOp --intern-op-permission-refusal-log magic-tester --session-id rig-tester --tool Write --target "$rigWs/ELSE/a.txt" --reason rig
rigRefusalId="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/op.out" | head -1 )"
[ -n "$rigRefusalId" ] || rigRefuse "no refusal could be recorded"
rigAsk magic-tester rig-tester permission human-owner --refusal-id "$rigRefusalId"
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "the read says beforehand what becomes of each answer" "$( rigRow answer allow-once ) $( rigRow answer deny ) $( rigRow question | cut -d'|' -f10 )" "answer|-|allow-once|up-the-chain|- answer|-|deny|settles|- deny"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer allow-once
rigAssert "the allow is not applied: the row says it went up, and to whom" "$rigOpRc:$( rigRow up-the-chain | cut -d'|' -f1-5 )" "0:up-the-chain|$rigPend|human-owner|magic-coordinator|console:$rigAcct"
rigAssert "the request stays open, and nothing is granted" "$( rigField "$rigFile" status ):$( rigHas "$rigWs/.local/agents/sessions/rig-tester/grants" "$rigRefusalId" )" "reply-pending:no-such-file"
rigOp --manager-pending-reply-answer --id "$rigPend" --reject
rigAssert "the reject of a permission is its deny, which settles" "$rigOpRc:$( rigRow rejected | cut -d'|' -f1-3 ):$( rigField "$rigFile" status )" "0:rejected|$rigPend|deny:reply-received"

echo "-- a plain question takes words --"
rigAsk magic-tester rig-tester question human-owner
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "words alone are its answer: no answer rows, no reject" "$( rigRow question | cut -d'|' -f4,9,10 ):$( rigRow answer )" "question|answer|-:"
rigOp --manager-pending-reply-answer --id "$rigPend" --reject
rigAssert "a plain question takes no reject" "$rigOpRc:$( rigHas "$rigTmp/op.err" 'takes no reject' ):$( rigField "$rigFile" status )" "1:yes:reply-pending"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer "Use the Staging host, not prod"
rigAssert "the words are the verdict, as typed" "$rigOpRc:$( rigField "$rigFile" status ):$( rigField "$rigFile" verdict )" "0:reply-received:Use the Staging host, not prod"
rigAssert "its line carries the words" "$( rigNew "Answered from the console by $rigAcct" 'Use the Staging host, not prod' )" "1"

echo "-- a question with an answer form --"
rigAsk magic-tester rig-tester question human-owner --select yes-no
rigOp --manager-pending-reply-answer --id "$rigPend" --answer yes
rigAssert "yes-no by its word" "$rigOpRc:$( rigField "$rigFile" verdict )" "0:yes"
rigAsk magic-tester rig-tester question human-owner --select one --options "$rigOptions"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer 1
rigAssert "one of its options by number" "$rigOpRc:$( rigField "$rigFile" verdict )" "0:keep"

echo "-- a verdict that is the human-owner's own is not given from the console --"
rigAsk magic-tester rig-tester review human-owner
rigOp --manager-pending-reply-read --id "$rigPend"
rigAssert "the read says it is not taken" "$( rigRow answer accept )" "answer|-|accept|not-taken|-"
rigMark
rigOp --manager-pending-reply-answer --id "$rigPend" --answer accept
rigAssert "the answer is refused, with why, and the review prompt stays open" "$rigOpRc:$( rigHas "$rigTmp/op.err" "is the human-owner's own" ):$( rigField "$rigFile" status ):$( rigNew 'console' )" "1:yes:reply-pending:0"

echo "-- a dismissal, its asker running, with a reason --"
printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" rig-tester > "$RIG_PS_LIST"
rigAsk magic-tester rig-tester decision human-owner --options "$rigOptions"
rigMark
rigOp --manager-pending-reply-dismiss --id "$rigPend" --reason "stale since Monday"
rigAssert "the row says dismissed, by whom, with the reason" "$rigOpRc:$( rigRow dismissed )" "0:dismissed|$rigPend|console:$rigAcct|stale since Monday"
rigAssert "the record is withdrawn by the console's account, with the reason and no verdict" \
	"$( rigField "$rigFile" status ):$( rigField "$rigFile" withdrawn-by ):$( rigField "$rigFile" withdraw-reason ):$( rigField "$rigFile" verdict )" "withdrawn:console:$rigAcct:stale since Monday:"
rigAssert "one line in its thread says it was dismissed from the console, by whom and why" "$( rigNew "Dismissed from the console by $rigAcct" 'stale since Monday' "$( rigInThread "$rigThread" )" )" "1"
rigOp --manager-pending-reply-dismiss --id "$rigPend"
rigAssert "a second dismissal is refused, and says who dismissed it" "$rigOpRc:$( rigHas "$rigTmp/op.err" "is not pending, it is withdrawn by console:$rigAcct" )" "1:yes"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rigAssert "a dismissed question takes no answer" "$rigOpRc:$( rigField "$rigFile" status )" "1:withdrawn"

echo "-- a dismissal, its asker gone, with no reason --"
: > "$RIG_PS_LIST"
rigAsk magic-tester rig-tester question human-owner
rigMark
rigOp --manager-pending-reply-dismiss --id "$rigPend"
rigAssert "dismissed with no reason" "$rigOpRc:$( rigRow dismissed ):$( rigField "$rigFile" status ):$( rigField "$rigFile" withdrawn-by )" "0:dismissed|$rigPend|console:$rigAcct|-:withdrawn:console:$rigAcct"
rigAssert "its line names the account" "$( rigNew "Dismissed from the console by $rigAcct" )" "1"

echo "-- a line that cannot be posted does not undo the answer --"
rigAsk magic-tester rig-tester decision human-owner --options "$rigOptions"
: > "$rigTmp/post-refuse"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer keep
rm -f "$rigTmp/post-refuse"
rigAssert "the answer stands, and stderr says the line was not posted" "$rigOpRc:$( rigField "$rigFile" status ):$( rigField "$rigFile" verdict ):$( rigHas "$rigTmp/op.err" 'the line that says so was not posted' )" "0:reply-received:keep:yes"

echo "-- what the one who asked is given by its Wait --"
## The asking session's own tool calls, served by the harness as a spawned run's are: it asks a
## plain question and does not wait; the console answers it, or dismisses it; its Wait on that
## question then returns what was done, with the words and who, and never as a bare closing.
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/magic-tester.agent.env"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}],"has_more":false}\n' > "$rigTmp/replies.json"
mkdir -p "$rigWs/IN"
rigToolCall(){ ## guard seconds, tool, argument object -- one served tool call of the asking session
	local callPid callLeft="$1"
	set -m
	( cd "$rigWs" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID=rig-tester RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDAT_SPAWN_AGENT=magic-tester MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigWs" --access-write-root "$rigWs/IN" ) > "$rigTmp/tool.out" 2> "$rigTmp/tool.err" &
	callPid=$!
	set +m
	## Noted as it is started: a call that outlives its guard is ended as the group it leads, and
	## only while that group is still this check's own (rigProcGroupSignal).
	rigProcNote "$callPid"
	while [ -n "$( rigProcStill "$callPid" )" ] && [ "$callLeft" -gt 0 ] ; do sleep 1 ; callLeft=$(( callLeft - 1 )) ; done
	if [ -n "$( rigProcStill "$callPid" )" ] ; then
		rigProcGroupSignal TERM "$callPid" ; sleep 1 ; rigProcGroupSignal KILL "$callPid"
		printf 'RIG-KILLED: the call did not end within its guard\n' >> "$rigTmp/tool.out"
	fi
	wait "$callPid" 2>/dev/null || :
}
rigToolAsk(){ ## the question -> rigPend, rigFile
	rigToolCall 40 AskQuestion "{\"to\":\"magic-team\",\"address_to\":\"URIGOWNER\",\"question\":\"$1\",\"wait\":false}"
	rigPend="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigTmp/tool.out" | head -1 )"
	[ -n "$rigPend" ] || rigRefuse "the asking session's question was not asked: $( head -3 "$rigTmp/tool.out" "$rigTmp/tool.err" 2>/dev/null | tr '\n' ' ' )"
	rigFile="$rigWs/.local/agents/pending/$rigPend.md"
	## Its thread, as Slack would give it: the question's own message, and no reply.
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"the question"}],"has_more":false}\n' "$( rigField "$rigFile" question-ts )" > "$rigTmp/replies.json"
}
rigToolAsk "Which host does the rig report go to?"
rigOp --manager-pending-reply-answer --id "$rigPend" --answer "Use the Staging host, not prod"
rigAssert "control: the plain question the session asked is answered from the console" "$rigOpRc:$( rigField "$rigFile" status )" "0:reply-received"
rigToolCall 40 Wait "{\"sources\":\"ask:$rigPend\",\"timeout\":5}"
rigAssert "its Wait returns the answer as received, with the words that were given and who gave them" \
	"$( rigHas "$rigTmp/tool.out" 'ASK-RESULT: RECEIVED' ):$( LC_ALL=C grep -c -x -F 'VERDICT: Use the Staging host, not prod' "$rigTmp/tool.out" ):$( LC_ALL=C grep -c -x -F 'ANSWERED-BY: magic-coordinator' "$rigTmp/tool.out" )" "yes:1:1"
rigToolAsk "May the rig keep its second report?"
rigOp --manager-pending-reply-dismiss --id "$rigPend" --reason "asked twice"
rigAssert "control: the question the session asked is dismissed from the console" "$rigOpRc:$( rigField "$rigFile" status )" "0:withdrawn"
rigToolCall 40 Wait "{\"sources\":\"ask:$rigPend\",\"timeout\":5}"
rigAssert "its Wait says it was dismissed from the console, by which account and why, and gives no answer" \
	"$( rigHas "$rigTmp/tool.out" "dismissed from the console by $rigAcct. Reason: asked twice." ):$( LC_ALL=C grep -c '^VERDICT: ' "$rigTmp/tool.out" )" "yes:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER PENDING REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a pending question cannot be read, answered, rejected or dismissed from the console as its help entries say" >&2
	echo "  fix:  repair sh-lib/AgentsTools.ManagerPendingReply.include, the console's part of the answer arm (AgentsTools.MemberEscalation.include) and of the withdraw (AgentsTools.MemberPendingReply.include), and what the asker's Wait says of a record closed that way (AgentsHarnessAskResolve, AgentsHarnessWaitAskResolve) -- never the assertion" >&2
	exit 1
fi
printf 'MANAGER_PENDING_REPLY: OK (%d assertions, offline)\n' "$rigPassCount"
