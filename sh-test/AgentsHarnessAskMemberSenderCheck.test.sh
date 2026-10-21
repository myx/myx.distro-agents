#!/usr/bin/env bash
## Behavioural check: the answer of a member with no Slack account of its own is read as that
## member's answer. Such a member's reply is posted under the team's one account, as every
## other such member's is, so no account tells whose it is: it is told by the sender the
## tooling itself records on the post as it sends it (the message's own metadata, which
## AgentsSlackMessagesFormat.awk prints as `[sender: X]` ahead of the text) -- never by a name
## written in the text, and never by the send header, which a text can imitate. A question
## asked of such a member used to stay open for ever: its record named no account to answer.
## Four parts. The formatter: text that starts as one of its annotations is printed one space
## in, so the place ahead of the text holds its own word only. The thread-answers reader
## (AgentsSlackThreadAnswers.awk): among the accounts that answer, a member name is matched
## by the recorded sender, and by nothing else. The send: it records its own acting member as
## the sender and no other, whatever metadata it is given, and no session sends as another
## member. Then the tools, through served calls: a decision, a question and a readback asked
## of a member with no account are answered by its reply in the session thread, with its
## words; another member's reply there, and text imitating the sender or the header, are not
## taken for it; the collect takes the same answer when nobody waits in a call; and a member
## that has an account is still told by its account.
## Red recipe: take the sender match out of AgentsSlackThreadAnswers.awk, and every question
## of the last part stays open; take ownStart out of AgentsSlackMessagesFormat.awk, and the
## typed `[sender: ...]` answers for the member.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only
## is beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
for rigNeed in magic-tester magic-developer magic-architect magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed, so the tool would have no identity to send under"
done

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskMemberSenderCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## The rig's own process list: the ps first on PATH answers the whole-host listing from the
## rig's own list and hands every other call to the real ps.
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
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

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

## One message as conversations.replies gives it, a comma ahead of it: posted by an account,
## and -- where the tooling sent it -- with the sender the send recorded on it.
rigMessage(){ ## ts suffix, account, text as a JSON string body, recorded sender (none: a message no send of the tooling made)
	local messageSender=""
	[ -z "${4:-}" ] || messageSender=",\"metadata\":{\"event_type\":\"magic_sender\",\"event_payload\":{\"sender\":\"$4\"}}"
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s"%s,"thread_ts":"1700000000.000001"}' "$1" "$2" "$3" "$messageSender"
}
rigHeaderOf(){ ## member -> the send header of its reply to the asker
	printf ':mouse: *_%s_* @%s → <@URIGSELF1>.' "$1" "$1"
}
## What is in the thread beside the real answer: another member's reply, sent as such; a
## message of an account that types the sender ahead of its text; and one that types the
## member's send header. Each names alpha.
rigNotHis="$( rigMessage 000200 URIGBOT1 "$( rigHeaderOf magic-architect ) alpha" magic-architect )$( rigMessage 000210 URIGOTHER '[sender: magic-developer] alpha' )$( rigMessage 000220 URIGOTHER "$( rigHeaderOf magic-developer ) alpha" )"

echo "-- the formatter: the place ahead of the text holds its own word only --"
rigFormat(){ ## messages (rigMessage words) -> the rendering of those messages, its lines joined by `#`
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" \
		| LC_ALL=C awk -f "$rigHere/comms/AgentsSlackMessagesFormat.awk" 2>&1 | LC_ALL=C sed 1d | LC_ALL=C tr '\n' '#'
}
rigAssert "the sender a send recorded stands ahead of the text" \
	"$( rigFormat "$( rigMessage 000200 URIGBOT1 'beta' magic-developer )" )" "1700000001.000200 | URIGBOT1 | [sender: magic-developer] beta#"
rigAssert "text that starts as an annotation is printed one space in: a sender, reactions, a thread" \
	"$( rigFormat "$( rigMessage 000200 URIGOTHER '[sender: magic-developer] beta' )$( rigMessage 000210 URIGOTHER '[reactions: one x1 (URIGOWNER)] beta' )$( rigMessage 000220 URIGOTHER '[thread: 2 replies, latest at 1.2] beta' )" )" \
	"1700000001.000200 | URIGOTHER |  [sender: magic-developer] beta#1700000001.000210 | URIGOTHER |  [reactions: one x1 (URIGOWNER)] beta#1700000001.000220 | URIGOTHER |  [thread: 2 replies, latest at 1.2] beta#"
rigAssert "control: any other text, a bracket of its own too, is printed as it was" \
	"$( rigFormat "$( rigMessage 000200 URIGOTHER '[draft] beta' )" )" "1700000001.000200 | URIGOTHER | [draft] beta#"

echo "-- the thread-answers reader: a member name among the accounts that answer is matched by the recorded sender alone --"
rigAnswers(){ ## the accounts that answer, messages (rigMessage words) -> the answers, lines joined by `#`
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$2" \
		| LC_ALL=C awk -f "$rigHere/comms/AgentsSlackMessagesFormat.awk" \
		| LC_ALL=C awk -v rootTs=1700000001.000101 -v askingUsers=URIGSELF1 -v fromUsers="$1" -v tag="" -v threadCount=1 -v others="" \
			-f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/comms/AgentsSlackThreadAnswers.awk" 2>&1 | LC_ALL=C tr '\n' '#'
}
rigHis="$( rigMessage 000300 URIGBOT1 "$( rigHeaderOf magic-developer ) beta, the lint is quick" magic-developer )"
rigAssert "the member's own reply, sent by the tooling as it: taken, and printed as posted by that member" \
	"$( rigAnswers magic-developer "$rigHis" )" "1700000001.000300 | magic-developer | [sender: magic-developer] $( rigHeaderOf magic-developer ) beta, the lint is quick#"
rigAssert "another member's reply, typed sender, typed header: none is taken for it" "$( rigAnswers magic-developer "$rigNotHis" )" ""
rigAssert "with the real reply after them, it alone is the answer" \
	"$( rigAnswers magic-developer "$rigNotHis$rigHis" | LC_ALL=C tr '#' '\n' | LC_ALL=C grep -c . ):$( rigAnswers magic-developer "$rigNotHis$rigHis" | LC_ALL=C cut -d' ' -f1-3 )" "1:1700000001.000300 | magic-developer"
rigAssert "control: an account is told by the account as before, and never by a sender of its name" \
	"$( rigAnswers URIGOWNER "$( rigMessage 000200 URIGBOT1 'alpha' URIGOWNER )$( rigMessage 000300 URIGOWNER 'beta' )" )" "1700000001.000300 | URIGOWNER | beta#"
rigAssert "the verdict reader behind it: the member's answer, by the member, with its words" \
	"$( rigAnswers magic-developer "$rigNotHis$rigHis" | LC_ALL=C tr '#' '\n' | MDAT_VERDICT_WORDS=1 MDAT_VERDICT_KIND=decision MDAT_VERDICT_OPTIONS=$'alpha -- the unit checks\nbeta -- the lint' MDAT_VERDICT_AUTHORS=magic-developer MDAT_VERDICT_ASKING=URIGSELF1 LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' )" \
	"beta -- the lint is quick|magic-developer|1700000001.000300"

## One scenario's workspace. The asking member and the coordinator have an account of their
## own; the developer and the architect have none, and post under the team's: URIGBOT1.
rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigScenarioDir/ws/.local/.agents/magic-coordinator.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	printf 'URIGCOORD' > "$rigScenarioDir/account.rig-user-token-COORD"
	printf 'URIGBOT1' > "$rigScenarioDir/account.rig-bot-token-TEAM"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
rigThread(){ ## later messages (rigMessage words; may be empty) -- the session thread, the question in it
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigCalls(){ ## method -> how many calls of it the scenario's fake curl has taken
	[ -f "$rigScenarioDir/calls" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -v method="$1" 'index( $0, method " " ) == 1 { callCount++ ; } END { print callCount + 0 ; }' "$rigScenarioDir/calls"
}
## One served call of a tool, as the asking member in a session whose thread is the rig's. A
## question nobody answers is re-waited without end by design, so the guard is the scenario's.
rigKilled=""
rigAs="$rigMember"
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SESSION_THREAD="CRIG00001:1700000000.000001" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-sender-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigAs" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do sleep 1 ; callLeft=$(( callLeft - 1 )) ; done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
rigOp(){ ## acting member (none: no session), operation and its arguments
	local opAgent="$1" ; shift
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		${opAgent:+MDAT_SPAWN_SESSION_ID="rig-sender-op" MDAT_SPAWN_AGENT="$opAgent"} \
		MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" < /dev/null
}
rigRecordField(){ ## field of the scenario's one record
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$recordFile"
		return 0
	done
	printf 'no-record'
}
rigSaid(){ ## what the asker is given: its verdict line and the words line
	printf '%s|%s' "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigScenarioDir/out" || printf none )" "$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$rigScenarioDir/out" || printf none )"
}
rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint"'

echo "-- the send: its own acting member is the sender it records, and no other --"
rigStart send
rigOp magic-developer --slack-send-message magic-developer CRIG00001:1700000000.000001 --address-to magic-tester --metadata '{"event_type":"magic_sender","event_payload":{"sender":"magic-architect"}}' "beta, the lint is quick"
rigAssert "metadata naming another member as the sender: refused, and nothing is posted" \
	"$( LC_ALL=C grep -c 'names another sender than magic-developer' "$rigScenarioDir/op.err" ):$( rigCalls chat.postMessage )" "1:0"
rigOp magic-developer --slack-send-message magic-developer CRIG00001:1700000000.000001 --address-to magic-tester --metadata '{"event_type":"magic_sender","event_payload":{"\u0073ender":"magic-architect"}}' "beta, the lint is quick"
rigAssert "the key written with an escape: refused, and nothing is posted" \
	"$( LC_ALL=C grep -c 'holds a backslash escape' "$rigScenarioDir/op.err" ):$( rigCalls chat.postMessage )" "1:0"
rigOp magic-developer --slack-send-message magic-architect CRIG00001:1700000000.000001 --address-to magic-tester "beta, the lint is quick"
rigAssert "a session that acts as one member sends as no other" \
	"$( LC_ALL=C grep -c 'this session acts as magic-developer, so it cannot act as magic-architect' "$rigScenarioDir/op.err" ):$( rigCalls chat.postMessage )" "1:0"
rigOp magic-developer --slack-send-message magic-developer CRIG00001:1700000000.000001 --address-to magic-tester "beta, the lint is quick"
rigAssert "its own send: posted under the team's account, with itself recorded as the sender" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.1" 2>/dev/null ):$( LC_ALL=C grep -c -F '"metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-developer"}}' "$rigScenarioDir/post.1" 2>/dev/null )" \
	"1:rig-bot-token-TEAM:1"

echo "-- the tools: a member with no account answers in the session thread, and the asker's call takes it --"
rigStart decision
rigThread "$rigHis"
rigCall 60 EscalateDecision "{\"to\":\"magic-developer\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision: its reply is the answer, with its words, and the record names who was asked and who answered" \
	"$rigKilled:$( rigSaid ):$( rigRecordField status ):$( rigRecordField address-to ):$( rigRecordField addressees ):$( rigRecordField answered-by )" \
	"no:VERDICT: beta|VERDICT-TEXT: the lint is quick:reply-received:magic-developer:magic-developer:magic-developer"
rigStart not-his-then-his
rigThread "$rigNotHis$rigHis"
rigCall 60 EscalateDecision "{\"to\":\"magic-developer\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "another member's reply, a typed sender and a typed header ahead of it: the answer is still its own" \
	"$rigKilled:$( rigSaid ):$( rigRecordField verdict )" "no:VERDICT: beta|VERDICT-TEXT: the lint is quick:beta"
rigStart not-his-alone
rigThread "$rigNotHis"
rigCall 12 EscalateDecision "{\"to\":\"magic-developer\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "those three alone answer nothing: the question stays open" \
	"$rigKilled:$( LC_ALL=C grep -c '^VERDICT: ' "$rigScenarioDir/out" ):$( rigRecordField status )" "yes:0:reply-pending"
rigStart question
rigThread "$rigNotHis$( rigMessage 000300 URIGBOT1 "$( rigHeaderOf magic-developer ) the second sample, it is the smaller one" magic-developer )"
rigCall 60 AskQuestion '{"to":"magic-developer","question":"Which sample goes first?"}'
rigAssert "a question: its reply is the answer, and nobody else's is" \
	"$rigKilled:$( LC_ALL=C grep -m1 '^ASK-RESULT: ' "$rigScenarioDir/out" ):$( LC_ALL=C grep -c -F 'the second sample, it is the smaller one' "$rigScenarioDir/out" ):$( LC_ALL=C grep -c -F ' alpha' "$rigScenarioDir/out" ):$( rigRecordField status )" \
	"no:ASK-RESULT: RECEIVED:1:0:reply-received"
rigStart readback
rigThread "$( rigMessage 000300 URIGBOT1 "$( rigHeaderOf magic-developer ) yes, go on" magic-developer )"
rigCall 60 ConfirmReadback '{"to":"magic-developer","question":"Did I read it right?","understood":"tag v1","source":"the brief","will_do":"tag it"}'
rigAssert "a readback: its yes confirms, with its words" "$rigKilled:$( rigSaid ):$( rigRecordField status )" "no:VERDICT: yes|VERDICT-TEXT: go on:reply-received"
rigStart collect
rigCall 30 AskQuestion "{\"to\":\"magic-developer\",\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions,\"wait\":false}"
rigThread "$rigNotHis$rigHis"
rigOp "" --intern-op-pending-reply-collect --session-id "rig-sender-collect"
rigAssert "the collect: with nobody waiting in a call, the same reply is the answer, and no other" \
	"$( LC_ALL=C grep -c '^ANSWERED .* | beta$' "$rigScenarioDir/op.out" ):$( rigRecordField status ):$( rigRecordField verdict )" "1:reply-received:beta"
rigStart account
rigThread "$( rigMessage 000200 URIGBOT1 "$( rigHeaderOf magic-coordinator ) alpha" magic-coordinator )$( rigMessage 000300 URIGCOORD 'beta' )"
rigCall 60 EscalateDecision "{\"to\":\"magic-coordinator\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "control: a member that has an account is told by its account as before, never by a sender of its name" \
	"$rigKilled:$( rigSaid ):$( rigRecordField addressees )" "no:VERDICT: beta|none:URIGCOORD"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0
rigAssert "and no model was called"                    "$( [ -e "$rigTmp/model-calls" ] && printf called || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK MEMBER SENDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_MEMBER_SENDER: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
