#!/usr/bin/env bash
## Behavioural check on what is kept of a reply to a question, in two respects.
## A MEMBER'S OWN WORDS: the recorded answer and its clarifications are never the send header
## a member's reply starts with (mark, sender, alias, arrow, addressees), which the team's own
## send writes ahead of every message. AgentsPendingReplyOwnWords.awk takes that header off
## the answers on their way to the two readers that keep what a reply says:
## AgentsPendingReplyAnswerText.awk, the recorded answer, and
## AgentsPendingReplyClarifications.awk, what is kept with it.
## A COMMENT WHOLE: a line belongs to the reply above it whatever it starts with -- `# `,
## `reaction on the question: `, `UNMATCHED-REPLY ` -- and only the head of a next reply, set
## aside or not, ends a reply. So the answer is a reply's first line that is no quote even when
## a line like those stands before it, and every line after it is kept. The wait's own lines
## are told from a person's by where they stand, never by how they start.
## Two parts. The filter and the two readers alone, over rendered replies. Then the places
## that keep an answer, each through its own path: the close of a question that takes any
## text (AskQuestion), the same answer taken by Wait, a later message arriving on Wait, the
## collect of a question nobody waited on, the escalation read of a question with an answer
## form, and a question closed elsewhere while it was waited on.
## Red recipe: take the AgentsPendingReplyOwnWords.awk stage out of one of the callers, and
## its scenario records the header line as the answer, or keeps the answer as a clarification;
## give AgentsPendingReplyClarifications.awk back its rule that ends a reply at a `# ` line,
## and every "a comment whole" assertion fails.
## Offline: a Slack-shaped fake curl is first on PATH, model CLIs on PATH only log, and every
## scenario runs in its own workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigToolFile="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigToolFile" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigToolFile"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPendingReplyOwnWordsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## A model call anywhere would reach one of these first, and it only logs.
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

## A member's send header, as the send writes it.
rigHeader=':mouse: *_magic-coordinator_* @dispatchr → <@URIGSELF1>.'
rigReply='1700000001.000200 | URIGOWNER |'
rigLater='1700000001.000300 | URIGOWNER |'
rigOwnWords(){ ## stdin: rendered answers -> the same with each reply's send header taken off
	LC_ALL=C awk -f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/questions/AgentsPendingReplyOwnWords.awk"
}

echo "-- the filter alone: a member's send header is taken off, every other line is left as it is --"
rigWords(){ ## rendered lines... -> what the filter prints, its lines joined by `#`
	printf '%s\n' "$@" | rigOwnWords 2>&1 | LC_ALL=C tr '\n' '#'
}
rigAssert "the header on the answer's line: the answer is left"   "$( rigWords "$rigReply $rigHeader yes, keep it" )" "$rigReply yes, keep it#"
rigAssert "the header on a line of its own: the head is left empty, the lines under it as they are" "$( rigWords "$rigReply $rigHeader" 'yes, keep it' 'but rename it first' )" "$rigReply #yes, keep it#but rename it first#"
rigAssert "the formatter's own annotation ahead of the header stays" "$( rigWords "$rigReply [sender: magic-coordinator] $rigHeader yes, keep it" )" "$rigReply [sender: magic-coordinator] yes, keep it#"
rigAssert "a person's reply is left as it is, an arrow in its own words too" "$( rigWords "$rigReply yes, keep it" 'see a → b. fine' "$rigLater see a → b. fine" )" "$rigReply yes, keep it#see a → b. fine#$rigLater see a → b. fine#"
rigAssert "a header quoted under a reply is that reply's own line" "$( rigWords "$rigReply as the coordinator wrote:" "$rigHeader go on" )" "$rigReply as the coordinator wrote:#$rigHeader go on#"
rigAssert "a line that is no reply is left as it is" \
	"$( rigWords 'reaction on the question: [reactions: +1 x1 (URIGOWNER)]' "UNMATCHED-REPLY $rigReply $rigHeader late" '# pending reply 1 is closed: reply-received' )" \
	"reaction on the question: [reactions: +1 x1 (URIGOWNER)]#UNMATCHED-REPLY $rigReply $rigHeader late## pending reply 1 is closed: reply-received#"

echo "-- ahead of the two readers: the answer is the answer, a clarification is never the header --"
rigAnswerOf(){ ## rendered lines... -> the answer text
	printf '%s\n' "$@" | rigOwnWords | LC_ALL=C awk -f "$rigHere/questions/AgentsPendingReplyAnswerText.awk" 2>&1
}
rigClarifyOf(){ ## the answer's ts, rendered lines... -> the clarifications, each "<ts>|<user>|<text>", joined by `#`
	local clarifyTs="$1"
	shift
	printf '%s\n' "$@" | rigOwnWords | LC_ALL=C awk -v answerTs="$clarifyTs" -f "$rigHere/questions/AgentsPendingReplyClarifications.awk" 2>&1 | LC_ALL=C tr '\t\n' '|#'
}
rigAssert "the answer of a member's reply, its header on a line of its own" "$( rigAnswerOf "$rigReply $rigHeader" 'yes, keep it' 'but rename it first' )" "yes, keep it"
rigAssert "the answer of a member's reply, its header on the answer's line" "$( rigAnswerOf "$rigReply $rigHeader yes, keep it" 'but rename it first' )" "yes, keep it"
rigAssert "the answer under a header and a quote of the question" "$( rigAnswerOf "$rigReply $rigHeader" '&gt; May the rig keep it?' 'yes, keep it' )" "yes, keep it"
rigAssert "control: a person's answer is read as before"   "$( rigAnswerOf "$rigReply yes, keep it" 'but rename it first' )" "yes, keep it"
rigAssert "the clarifications of a member's reply: what follows its answer, and its later reply, in its own words" \
	"$( rigClarifyOf 1700000001.000200 "$rigReply $rigHeader" 'yes, keep it' 'but rename it first' "$rigLater $rigHeader to report-final" )" \
	"1700000001.000200|URIGOWNER|but rename it first#1700000001.000300|URIGOWNER|to report-final#"
rigAssert "a later reply with its header on a line of its own: its lines, and no header" \
	"$( rigClarifyOf 1700000001.000200 "$rigReply $rigHeader yes, keep it" "$rigLater $rigHeader" 'to report-final' 'in the docs folder' )" \
	"1700000001.000300|URIGOWNER|to report-final / in the docs folder#"
rigAssert "control: a person's clarifications are read as before" \
	"$( rigClarifyOf 1700000001.000200 "$rigReply yes, keep it" 'but rename it first' "$rigLater to report-final" )" \
	"1700000001.000200|URIGOWNER|but rename it first#1700000001.000300|URIGOWNER|to report-final#"

echo "-- the two readers: a line belongs to the reply above it, whatever it starts with --"
rigAssert "a comment is kept whole: lines that start like a heading, a reaction line and a set-aside mark are the person's own" \
	"$( rigClarifyOf 1700000001.000200 "$rigReply yes, keep it" '# why' 'reaction on the question: I saw it' 'UNMATCHED-REPLY is a word I use' 'it is the final one' "$rigLater rename it" '# to' 'report-final' )" \
	"1700000001.000200|URIGOWNER|# why / reaction on the question: I saw it / UNMATCHED-REPLY is a word I use / it is the final one#1700000001.000300|URIGOWNER|rename it / # to / report-final#"
rigAssert "only a next reply ends one: a reply set aside is not kept, none of its lines, and the reply after it is kept whole" \
	"$( rigClarifyOf 1700000001.000200 "$rigReply yes, keep it" 'and why' 'UNMATCHED-REPLY 1700000001.000250 | URIGOWNER | late words' 'UNMATCHED-REPLY # under them' "$rigLater after it" '# with a heading' )" \
	"1700000001.000200|URIGOWNER|and why#1700000001.000300|URIGOWNER|after it / # with a heading#"
rigAssert "the lines ahead of the first reply are the question's own, and no comment" \
	"$( rigClarifyOf 1700000001.000101 'reaction on the question: [reactions: +1 x1 (URIGOWNER)]' "$rigReply yes, keep it" '# why' )" \
	"1700000001.000200|URIGOWNER|yes, keep it / # why#"
rigAssert "the answer is the first line that is no quote, a heading too" "$( rigAnswerOf "$rigReply &gt; May the rig keep it?" '# Yes' 'keep it' )" "# Yes"
rigAssert "and what follows that line is what is kept with it" "$( rigClarifyOf 1700000001.000200 "$rigReply &gt; May the rig keep it?" '# Yes' 'keep it' )" "1700000001.000200|URIGOWNER|keep it#"
rigAssert "a heading under the answer leaves the answer as it is" "$( rigAnswerOf "$rigReply yes, keep it" '# why' 'it is the final one' )" "yes, keep it"
rigAssert "the first reply ends at a reply set aside: one that is all quote gives its first line, never the other's" \
	"$( rigAnswerOf "$rigReply &gt; May the rig keep it?" 'UNMATCHED-REPLY 1700000001.000250 | URIGOWNER | late words' 'UNMATCHED-REPLY yes' )" "&gt; May the rig keep it?"
rigAssert "a reply set aside ahead of the first reply is passed over" \
	"$( rigAnswerOf 'UNMATCHED-REPLY 1700000001.000150 | URIGOWNER | late words' 'UNMATCHED-REPLY no' "$rigReply yes, keep it" )" "yes, keep it"

rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -q -F -- "$2" "$1" && printf 'yes' || printf 'no'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
## The scenario's one record: its file, its id, one header field of it, and how many of its
## lines hold a text.
rigRecordFile(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && { printf '%s' "$recordFile" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/no-record"
}
rigRecordId(){
	local recordId
	recordId="$( rigRecordFile )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigRecordField(){ ## field
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile )" 2>/dev/null || printf 'no-record'
}
rigRecordLines(){ ## fixed text -> how many lines of the record hold it
	LC_ALL=C grep -c -F -- "$1" "$( rigRecordFile )" 2>/dev/null || :
}

rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The question's own thread as conversations.replies returns it: the question, its root,
## then the later messages. A reply comes from the account the question is addressed to: a
## member's is that account's text opening with the member's send header.
rigThread(){ ## later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigMessage(){ ## ts suffix, text
	printf ',{"ts":"1700000001.%s","user":"URIGOWNER","text":"%s","thread_ts":"1700000001.000101"}' "$1" "$2"
}

## One served call of a tool. A question nobody answers is re-waited without end by design,
## so the guard is the scenario's: a killed run is reported as such, never as a result.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-words-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
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

## One operation of the tool itself, under the scenario's workspace, with no model key.
rigTool(){ ## operation and its arguments...
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		bash "$rigToolFile" "$@" )
}

rigAsk='"to":"magic-team","address_to":"URIGOWNER"'
## A member's answer with its header on a line of its own and one more line under the answer,
## then its later reply with the header on that reply's own line.
rigMemberAnswer="$( rigMessage 000200 "$rigHeader\\nyes, keep it\\nbut rename it first" )$( rigMessage 000300 "$rigHeader to report-final" )"

echo "-- AskQuestion closing a question that takes any text: the answer and what is kept with it --"
rigStart close-text
rigThread "$rigMemberAnswer"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\"}"
rigAssert "the question is answered"                   "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status )" "no:ASK-RESULT: RECEIVED:reply-received"
rigAssert "the recorded answer is the member's answer, not its send header" "$( rigRecordField verdict )" "yes, keep it"
rigAssert "the rest of that reply is kept, and the later reply, each in the member's own words" \
	"$( rigRecordLines '- 1700000001.000200 URIGOWNER: but rename it first' ):$( rigRecordLines '- 1700000001.000300 URIGOWNER: to report-final' )" "1:1"
rigAssert "the answer is not kept again as a clarification" "$( rigRecordLines 'URIGOWNER: yes, keep it' )" 0
rigAssert "and the record holds no send header"        "$( rigRecordLines '*_magic-coordinator_*' )" 0

echo "-- a later message of the member arriving on Wait: kept in its own words --"
rigThread "$rigMemberAnswer$( rigMessage 000500 "$rigHeader\\ncorrection: keep a copy too" )"
rigCall 60 Wait '{"mode":"continue"}'
rigAssert "it arrives as a clarification on the answer" "$rigKilled:$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: CLARIFIED' )" "no:yes"
rigAssert "and is kept without its header"             "$( rigRecordLines '- 1700000001.000500 URIGOWNER: correction: keep a copy too' ):$( rigRecordLines '*_magic-coordinator_*' )" "1:0"
rigAssert "the recorded answer is left as it was"      "$( rigRecordField verdict )" "yes, keep it"

echo "-- the collect of a question nobody waited on: the same answer, the same clarifications --"
rigStart collect-text
rigThread ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\",\"wait\":false}"
rigAssert "control: posted, not waited on"             "$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status )" "ASK-RESULT: POSTED:reply-pending"
rigThread "$rigMemberAnswer"
rigTool --intern-op-pending-reply-collect --session-id "rig-words-$rigScenarioName" > "$rigScenarioDir/collect" 2> "$rigScenarioDir/collect.err"
rigAssert "the collect says answered, with the member's answer" "$( LC_ALL=C grep -c "^ANSWERED $( rigRecordId ) .* | yes, keep it\$" "$rigScenarioDir/collect" ):$( rigRecordField status )" "1:reply-received"
rigAssert "the recorded answer is the member's answer, not its send header" "$( rigRecordField verdict )" "yes, keep it"
rigAssert "the rest of that reply is kept, and the later reply, each in the member's own words" \
	"$( rigRecordLines '- 1700000001.000200 URIGOWNER: but rename it first' ):$( rigRecordLines '- 1700000001.000300 URIGOWNER: to report-final' )" "1:1"
rigAssert "the answer is not kept again as a clarification, and the record holds no send header" "$( rigRecordLines 'URIGOWNER: yes, keep it' ):$( rigRecordLines '*_magic-coordinator_*' )" "0:0"

echo "-- the escalation read of a question with an answer form: its clarifications --"
rigStart read-form
rigThread "$( rigMessage 000200 "$rigHeader\\nbeta\\nbecause it is quick" )$( rigMessage 000300 "$rigHeader and tell ops first" )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",\"options\":\"alpha -- the unit checks\\nbeta -- the lint\\ngamma -- the smoke run\"}"
rigAssert "the member's answer under its header is the verdict" "$rigKilled:$( rigVerdictLine ):$( rigRecordField verdict )" "no:VERDICT: beta:beta"
rigAssert "what follows the answer is kept, and the later reply, each in the member's own words" \
	"$( rigRecordLines '- 1700000001.000200 URIGOWNER: because it is quick' ):$( rigRecordLines '- 1700000001.000300 URIGOWNER: and tell ops first' )" "1:1"
rigAssert "the answer is not kept as a clarification, and the record holds no send header" "$( rigRecordLines 'URIGOWNER: beta' ):$( rigRecordLines '*_magic-coordinator_*' )" "0:0"

echo "-- a person's comment is recorded whole, through each path that keeps an answer --"
## A person's answer with a heading line under it, and a later reply with one in its middle.
rigComment="$( rigMessage 000200 'yes, keep it\n# why\nit is the final one' )$( rigMessage 000300 'rename it\n# to\nreport-final' )"
rigCommentKept(){ ## -> how many of the two replies are kept whole on the record, as "<first>:<second>"
	printf '%s:%s' "$( rigRecordLines '- 1700000001.000200 URIGOWNER: # why / it is the final one' )" "$( rigRecordLines '- 1700000001.000300 URIGOWNER: rename it / # to / report-final' )"
}
rigStart comment-close
rigThread "$rigComment"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\"}"
rigAssert "the ask's own close: the answer, and both replies whole" "$rigKilled:$( rigRecordField verdict ):$( rigCommentKept )" "no:yes, keep it:1:1"

rigStart comment-wait
rigThread ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\",\"wait\":false}"
rigThread "$rigComment"
rigCall 60 Wait '{"mode":"continue"}'
rigAssert "the answer taken by Wait: the answer, and both replies whole" "$rigKilled:$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' ):$( rigRecordField verdict ):$( rigCommentKept )" "no:yes:yes, keep it:1:1"
rigThread "$rigComment$( rigMessage 000500 'one more thing\n# note\nkeep a copy' )"
rigCall 60 Wait '{"mode":"continue"}'
rigAssert "a later message arriving on Wait is kept whole" "$rigKilled:$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: CLARIFIED' ):$( rigRecordLines '- 1700000001.000500 URIGOWNER: one more thing / # note / keep a copy' )" "no:yes:1"

rigStart comment-collect
rigThread ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\",\"wait\":false}"
rigThread "$rigComment"
rigTool --intern-op-pending-reply-collect --session-id "rig-words-$rigScenarioName" > "$rigScenarioDir/collect" 2> "$rigScenarioDir/collect.err"
rigAssert "the collect: the answer, and both replies whole" "$( rigRecordField status ):$( rigRecordField verdict ):$( rigCommentKept )" "reply-received:yes, keep it:1:1"

rigStart comment-read
rigThread "$( rigMessage 000200 'beta\n# why\nit is quick' )$( rigMessage 000300 'rename it\n# to\nreport-final' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",\"options\":\"alpha -- the unit checks\\nbeta -- the lint\\ngamma -- the smoke run\"}"
rigAssert "the escalation read: the verdict, and both replies whole" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordLines '- 1700000001.000200 URIGOWNER: # why / it is quick' ):$( rigRecordLines '- 1700000001.000300 URIGOWNER: rename it / # to / report-final' )" "no:VERDICT: beta:1:1"

## The wait's own line is no part of a comment. A question closed elsewhere while it is waited
## on, with no floor to watch its thread from: the wait says so in a line of its own under the
## replies it read, which is kept on no record.
rigStart comment-closed-elsewhere
rigThread ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"May the rig keep its report file?\",\"wait\":false}"
rigTool --intern-op-pending-reply-close "$( rigRecordId )" --if-open --status reply-received --verdict 'taken elsewhere' --answered-by URIGOWNER --no-decision --quiet --context rig > "$rigScenarioDir/close" 2> "$rigScenarioDir/close.err"
rigAssert "control: closed elsewhere, with no floor to watch its thread from" "$( rigRecordField status ):$( rigRecordField follow-floor )" "reply-received:none"
rigThread "$rigComment"
rigCall 60 Wait '{"mode":"continue"}'
rigAssert "control: the wait says the question is closed, in its own line under the replies" "$rigKilled:$( LC_ALL=C grep -c "^# pending reply $( rigRecordId ) is closed: reply-received\$" "$rigScenarioDir/out" )" "no:1"
rigAssert "the replies are kept whole, and the wait's own line is kept nowhere" "$( rigCommentKept ):$( rigRecordLines 'is closed: reply-received' )" "1:1:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0
rigAssert "and no model was called"                    "$( [ -e "$rigTmp/model-calls" ] && printf called || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY OWN WORDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_OWN_WORDS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
