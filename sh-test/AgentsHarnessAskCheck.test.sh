#!/usr/bin/env bash
## Behavioural check on the AskUserQuestion harness tool, run through --intern-tool,
## the path the myx.distro MCP stub uses. Covers the mechanisms the typed escalation
## kinds will reuse: the question as one top-level message, no opener, the pending-reply record,
## who counts as the answerer, the TIMEOUT re-wait, and the refusals that post nothing.
## Offline: a Slack-shaped fake curl is first on PATH, and every scenario runs in its
## own workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

## A rig that could not reach its subject must never reach its PASS lines.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

rigTmp="$( mktemp -d -t AgentsHarnessAskCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/harness-ask-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

rigPassCount=0
rigFailCount=0
rigScenarioCount=0
rigScenarioPass=0
rigScenarioFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

## yes/no, with a third value for a file never written.
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}

rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}

## The number of pending-reply records, and the status each holds.
rigRecords(){
	local recordCount=0 recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		recordCount=$(( recordCount + 1 ))
	done
	printf '%s' "$recordCount"
}
rigRecordStatus(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$recordFile"
		return 0
	done
	printf 'no-record'
}

## A body field of one posted message, by the post's sequence number.
rigPostThread(){ ## post number
	[ -f "$rigScenarioDir/post.$1" ] || { printf 'no-such-post' ; return 0 ; }
	LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigScenarioDir/post.$1" | head -1
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## One thread as conversations.replies returns it: the question, its root, then
## whatever the scenario adds after the question.
rigReplies(){ ## question extra fields (may be empty), later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"question"%s}%s],"has_more":false}\n' \
		"$1" "$2" > "$rigScenarioDir/replies.json"
}

## The tool, with a guard: a question nobody answers is re-waited without end by
## design, so a scenario proving that has to stop it. The guard is the scenario's,
## and a killed run is reported as such rather than as a result.
rigKilled=""
## With from-read the guard counts from the first thread read, not from the start, so a slow
## startup under load does not eat it; the start itself is allowed up to 120 s.
rigAsk(){ ## guard seconds, argument object, optional from-read
	local askPid askLeft askStartLeft=120
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	askPid=$!
	set +m
	askLeft="$1"
	while kill -0 "$askPid" 2>/dev/null && [ "$askLeft" -gt 0 ] ; do
		sleep 1
		if [ "${3:-}" = "from-read" ] && [ "$askStartLeft" -gt 0 ] && [ "$( rigCalls conversations.replies )" = 0 ] ; then
			askStartLeft=$(( askStartLeft - 1 ))
			continue
		fi
		askLeft=$(( askLeft - 1 ))
	done
	if kill -0 "$askPid" 2>/dev/null ; then
		rigKilled="yes"
		## The whole block, not the wait alone: bash 3.2 prints its job notice during the sleep.
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	wait "$askPid" 2>/dev/null || :
}

rigQuestion='Should the rig proceed with the second scenario now?'

## ---------------------------------------------------------------------------
## 1. Posted with no wait: the question itself, one top-level message in the
##    conversation with no opener, and the record opened only after the send.
## ---------------------------------------------------------------------------
rigStart posted
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait\":\"false\"}"
[ "$( rigCalls chat.postMessage )" != 0 ] || rigRefuse "no send reached the fake curl at all, so nothing below would be measured"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result opens with POSTED"                  "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: POSTED"
rigAssert "one post: the question, no opener"             "$( rigCalls chat.postMessage )" 1
rigAssert "the question is top-level, inside no thread"   "$( rigPostThread 1 )" ""
rigAssert "the question text reached the question post"   "$( rigHolds "$rigScenarioDir/post.1" "$rigQuestion" )" yes
rigAssert "the record names the question as its own thread" "$( LC_ALL=C cat "$rigScenarioDir/ws/.local/agents/pending/"*.md 2>/dev/null | LC_ALL=C grep -c -x -E 'question-ts: 1700000001\.000101|thread-ts: 1700000001\.000101' )" 2
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "it is still waiting for a reply"               "$( rigRecordStatus )" reply-pending
rigAssert "the result names the record"                   "$( rigHolds "$rigScenarioDir/out" 'recorded as pending reply' )" yes
rigAssert "no wait was performed"                         "$( rigCalls conversations.replies )" 0
rigPostedId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
rigAssert "it names its wait item, the pending record"   "$( [ -n "$rigPostedId" ] && [ -f "$rigScenarioDir/ws/.local/agents/pending/$rigPostedId.md" ] && printf yes || printf no )" yes
rigAssert "the last line names the Wait for the answer"   "$( LC_ALL=C awk 'END { gsub( /ask:[0-9A-Za-z._-]+/, "ask:<id>" ) ; print ; }' "$rigScenarioDir/out" )" "NEXT: to wait for the answer, call Wait sources=ask:<id> -- it posts nothing"
rigAssert "and it is the only NEXT: line, none from the send" "$( LC_ALL=C grep -c '^NEXT: ' "$rigScenarioDir/out" )" 1
rigVerdict "wait=false -- the question as one top-level message, POSTED with a pending record"

## ---------------------------------------------------------------------------
## 2. The addressee's reply is the answer; the same reply from anybody else is not.
## ---------------------------------------------------------------------------
rigStart addressee-reply
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"RIG-ANSWER-MARKER","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result opens with RECEIVED"                "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the answer text is carried"                    "$( rigHolds "$rigScenarioDir/out" 'RIG-ANSWER-MARKER' )" yes
rigAssert "the wait watched the question's own thread"    "$( rigHolds "$rigScenarioDir/out" 'slack:CRIG00001:1700000001.000101' )" yes
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record is closed as received"              "$( rigRecordStatus )" reply-received
rigVerdict "the addressee's reply answers the question and closes the record"

rigStart other-reply
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOTHER","text":"RIG-ANSWER-MARKER","thread_ts":"1700000001.000101"}'
rigAsk 6 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}" from-read
rigAssert "it was still waiting when the guard stopped it" "$rigKilled" yes
rigAssert "the thread was read, so it was the wait"       "$( [ "$( rigCalls conversations.replies )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "no RECEIVED result was produced"               "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" no
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigVerdict "the same reply from a non-addressee is not an answer"

## ---------------------------------------------------------------------------
## 3. A reaction on the question: from the addressee it answers. From anybody
##    else it must not -- the control that makes the first half mean "addressee".
## ---------------------------------------------------------------------------
rigStart addressee-reaction
rigReplies ',"reactions":[{"name":"white_check_mark","count":1,"users":["URIGOWNER"]}]' ""
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result opens with RECEIVED"                "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the reaction is carried"                       "$( rigHolds "$rigScenarioDir/out" 'reaction on the question' )" yes
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record is closed as received"              "$( rigRecordStatus )" reply-received
rigVerdict "the addressee's reaction answers the question"

rigStart other-reaction
rigReplies ',"reactions":[{"name":"x","count":1,"users":["URIGOTHER"]}]' ""
rigAsk 6 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}" from-read
rigAssert "it was still waiting when the guard stopped it" "$rigKilled" yes
rigAssert "the thread was read, so it was the wait"       "$( [ "$( rigCalls conversations.replies )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "no RECEIVED result was produced"               "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" no
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigVerdict "a non-addressee's reaction is not an answer"

## ---------------------------------------------------------------------------
## 4. Nobody answers: the wait times out and is re-entered, and the record stays
##    open the whole time.
## ---------------------------------------------------------------------------
rigStart no-answer
rigReplies "" ""
rigAsk 6 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"timeout\":\"1\"}" from-read
rigAssert "it was still waiting when the guard stopped it" "$rigKilled" yes
rigAssert "the thread was read more than once"            "$( [ "$( rigCalls conversations.replies )" -gt 1 ] && printf yes || printf no )" yes
rigAssert "no result line of any kind was produced"       "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT:' )" no
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigVerdict "an unanswered question is re-waited and its record stays open"

## ---------------------------------------------------------------------------
## 5. A send that fails: the question does not exist, and no record is written.
##    Slack's own permanent refusal drives the same branch the output-style floor does.
## ---------------------------------------------------------------------------
rigStart send-refused
: > "$rigScenarioDir/post-refuse"
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result opens with ERROR"                   "$( rigFirstLine "$rigScenarioDir/out" )" "ERROR: AskUserQuestion: the question could NOT be posted, so nobody was asked and no answer is pending anywhere. THE QUESTION DOES NOT EXIST: this is not a question that went unanswered, and it will not be answered later. The send measures the plain-language floor (${MDAT_SKILLSET_ROOT:-}/magic-team/magic-team.shared.md) and never refuses on it, so this is not a style refusal -- clear what the send reported and ask it again. What the send reported follows:"
rigAssert "it is not dressed as POSTED"                   "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT' )" no
rigAssert "no record was written"                         "$( rigRecords )" 0
rigAssert "no wait was performed"                         "$( rigCalls conversations.replies )" 0
rigVerdict "a refused send -- THE QUESTION DOES NOT EXIST, and nothing is recorded"

## ---------------------------------------------------------------------------
## 6. A question into one message's thread with nobody named: refused before any
##    request, because anybody could answer it.
## ---------------------------------------------------------------------------
rigStart no-addressee
rigAsk 30 "{\"to\":\"CRIG00001:1700000001.000101\",\"question\":\"$rigQuestion\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the refusal names address_to"                  "$( rigHolds "$rigScenarioDir/out" 'address_to is required' )" yes
rigAssert "nothing was sent"                              "$( rigHolds "$rigScenarioDir/out" 'Nothing was sent' )" yes
rigAssert "no request left this box"                      "$( LC_ALL=C awk 'END { print NR + 0 ; }' "$RIG_CURL_LOG" )" 0
rigAssert "no record was written"                         "$( rigRecords )" 0
rigVerdict "to=<channel>:<ts> with no address_to -- refused before any request"

## ---------------------------------------------------------------------------
## 7. Below the team's own plain-language floor: the Slack send measures it and
##    never refuses (AgentsTools.MemberCommsSlack.include), so the question is
##    POSTED and recorded, and the fired predicate is named in what the send reported.
## ---------------------------------------------------------------------------
rigStart floor-measured
rigAsk 30 '{"to":"magic-team","question":"Should the rig proceed now; or wait for the second scenario?","address_to":"URIGOWNER","wait":"false"}'
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result opens with POSTED"                  "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: POSTED"
rigAssert "the send's floor warning is carried"           "$( rigHolds "$rigScenarioDir/out" 'IT WAS WRITTEN ANYWAY' )" yes
rigAssert "the warning names the predicate"               "$( rigHolds "$rigScenarioDir/out" 'a semicolon, which this floor does not allow' )" yes
rigAssert "it is not dressed as a refusal"                "$( rigHolds "$rigScenarioDir/out" 'THE QUESTION DOES NOT EXIST' )" no
rigAssert "one post: the question, no opener"             "$( rigCalls chat.postMessage )" 1
rigAssert "one pending record"                            "$( rigRecords )" 1
rigVerdict "below the plain-language floor -- measured, never refused: POSTED, and the predicate named"

## ---------------------------------------------------------------------------
## 7a. The senders' NEXT: line. SendMessage names the Wait for a reply in the
##     message's thread, built from what the send reported; SubagentHandback, from a
##     spawned session nobody blocks on, says to keep waiting. Each with a control.
## ---------------------------------------------------------------------------
rigServe(){ ## tool, argument object, then env assignments for the call
	local serveTool="$1" serveArgs="$2"
	shift 2
	( cd "$rigScenarioDir/ws" && printf '%s' "$serveArgs" | env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_CALLER_WAITS \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" "$@" \
		bash "$rigHarness" --intern-tool "$serveTool" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || :
}
rigLastLine(){ ## file
	LC_ALL=C awk 'END { print ; }' "$1"
}
rigStart send-next
rigServe SendMessage '{"to":"magic-team","message":"Rig status note."}'
rigAssert "it was sent"                                   "$( rigHolds "$rigScenarioDir/out" 'SENT_MESSAGE_TS=1700000001.000101' )" yes
rigAssert "a top-level post: wait in its own thread"      "$( rigLastLine "$rigScenarioDir/out" )" "NEXT: to wait for a reply in its thread, call Wait sources=slack:CRIG00001:1700000001.000101:conversation since_utime=1700000001.000101"
rigServe SendMessage '{"to":"CRIG00001:1700000001.000101","message":"Rig thread note."}'
rigAssert "a thread reply: the thread root, our own ts as floor" "$( rigLastLine "$rigScenarioDir/out" )" "NEXT: to wait for a reply in its thread, call Wait sources=slack:CRIG00001:1700000001.000101:conversation since_utime=1700000001.000102"
: > "$rigScenarioDir/post-refuse"
rigServe SendMessage '{"to":"magic-team","message":"Rig refused note."}'
rigAssert "control: a refused send names no next step"    "$( rigHolds "$rigScenarioDir/out" 'NEXT:' )" no
rm -f "$rigScenarioDir/post-refuse"
rigServe PushNotification '{"to":"magic-team","severity":"info","headline":"Rig push."}'
rigAssert "control: an announcement names no next step"   "$( rigHolds "$rigScenarioDir/out" 'NEXT:' )" no
rigVerdict "SendMessage ends with the NEXT: Wait for a reply in its thread -- none on a refusal or an announcement"

rigStart handback-next
rigServe SubagentHandback '{"to":"magic-team","outcome":"Rig work done."}' MDAT_SPAWN_SESSION_ID=rig-spawn-session
rigAssert "it was sent"                                   "$( rigHolds "$rigScenarioDir/out" 'SENT_MESSAGE_TS=' )" yes
rigAssert "a spawned session is told to keep waiting"     "$( rigLastLine "$rigScenarioDir/out" )" "NEXT: you are not done -- call Wait with no sources (your session thread) and obey what arrives, until it returns DISMISSED"
rigServe SubagentHandback '{"to":"magic-team","outcome":"Rig work done."}' MDAT_SPAWN_SESSION_ID=rig-spawn-session MDAT_SPAWN_CALLER_WAITS=true
rigAssert "control: a caller-waits spawn is not"          "$( rigHolds "$rigScenarioDir/out" 'NEXT:' )" no
rigServe SubagentHandback '{"to":"magic-team","outcome":"Rig work done."}'
rigAssert "control: a session that is no spawn is not"    "$( rigHolds "$rigScenarioDir/out" 'NEXT:' )" no
rigAssert "control: and the send itself still went"       "$( rigHolds "$rigScenarioDir/out" 'SENT_MESSAGE_TS=' )" yes
rigVerdict "SubagentHandback from a spawned session ends with the NEXT: keep-waiting line -- not for a caller-waits spawn or a non-spawn"

## ---------------------------------------------------------------------------
## 8. The wait itself cannot be performed: the question stands, nothing is known,
##    and the record stays open. An unknown source kind is the way in.
## ---------------------------------------------------------------------------
rigStart wait-error
rigReplies "" ""
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait_source\":\"bogus:x\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the result says it WAS posted"                 "$( rigHolds "$rigScenarioDir/out" 'the question WAS posted' )" yes
rigAssert "and that nothing is known"                     "$( rigHolds "$rigScenarioDir/out" 'NOTHING is known' )" yes
rigAssert "it is not dressed as a result"                 "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT' )" no
rigAssert "the question was posted"                       "$( rigCalls chat.postMessage )" 1
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigVerdict "a wait that cannot be performed -- posted, NOTHING known, record open"

## ---------------------------------------------------------------------------
## 9. The thread cannot be read at all: that is an ERROR the asker is told about,
##    not a silent re-wait. Scenario 4, a readable thread with no answer, is its
##    control. The record stays open either way.
## ---------------------------------------------------------------------------
rigStart thread-unreadable
rigAsk 12 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"timeout\":\"1\"}"
rigAssert "the thread was tried"                          "$( [ "$( rigCalls conversations.replies )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "it returned rather than re-waiting"            "$rigKilled" no
rigAssert "the result says it WAS posted"                 "$( rigHolds "$rigScenarioDir/out" 'the question WAS posted' )" yes
rigAssert "and that nothing is known"                     "$( rigHolds "$rigScenarioDir/out" 'NOTHING is known' )" yes
rigAssert "the result names the pending record"           "$( rigHolds "$rigScenarioDir/out" 'pending reply' )" yes
rigAssert "one pending record"                            "$( rigRecords )" 1
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigVerdict "an unreadable thread -- ERROR naming the pending record, never a silent re-wait"

## The VERDICT line of the result, or none.
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordVerdict(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk -F': ' '$1 == "verdict" { print $2 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict" ; } }' "$recordFile"
		return 0
	done
	printf 'no-record'
}
rigReadbackArgs='"kind":"readback","understood":"deploy tag v1 with $HOME and `x` kept","source":"the dispatch brief","will_do":"run the tag step"'

## ---------------------------------------------------------------------------
## 10. A typed kind missing a field it needs is refused before anything is sent.
## ---------------------------------------------------------------------------
rigStart readback-missing
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"readback\",\"understood\":\"x\"}"
rigAssert "it is refused as missing fields"               "$( rigHolds "$rigScenarioDir/out" 'kind readback needs understood, source and will_do' )" yes
rigAssert "nothing was posted"                            "$( rigCalls chat.postMessage )" 0
rigAssert "no record was written"                         "$( rigRecords )" 0
rigStart decision-missing
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\"}"
rigAssert "a decision with no options is refused"         "$( rigHolds "$rigScenarioDir/out" 'kind decision needs options' )" yes
rigStart decision-duplicate
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"keep -- the old tag\\nKeep -- nothing\"}"
rigAssert "two options with the same first word are refused" "$( rigHolds "$rigScenarioDir/out" 'each option to start with a different word' )" yes
rigAssert "nothing was posted"                            "$( rigCalls chat.postMessage )" 0
rigStart permission-no-record
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"refusal-0\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "a permission for an unrecorded refusal is refused" "$( rigHolds "$rigScenarioDir/out" 'no refusal refusal-0 is recorded' )" yes
rigAssert "nothing was posted"                            "$( rigCalls chat.postMessage )" 0
rigStart unknown-kind
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"poll\"}"
rigAssert "an unknown kind is refused"                    "$( rigHolds "$rigScenarioDir/out" 'kind must be question, readback, decision or permission' )" yes
rigVerdict "typed kinds refuse a missing field, a missing record or an unknown kind before sending"

## ---------------------------------------------------------------------------
## 11. A readback: its fields reach the post, the addressee's yes is the verdict,
##     and the record closes carrying it.
## ---------------------------------------------------------------------------
rigStart readback-yes
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"<@URIGSELF1> Yes.","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",$rigReadbackArgs}"
rigAssert "the result opens with RECEIVED"                "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the verdict is yes"                            "$( rigVerdictLine )" "VERDICT: yes"
rigAssert "the post carries the readback heading"         "$( rigHolds "$rigScenarioDir/post.1" 'Readback' )" yes
rigAssert "the understood text reached the post intact"   "$( rigHolds "$rigScenarioDir/post.1" 'deploy tag v1 with $HOME and `x` kept' )" yes
rigAssert "the will-do text reached the post"             "$( rigHolds "$rigScenarioDir/post.1" 'run the tag step' )" yes
rigAssert "the record closed as received"                 "$( rigRecordStatus )" reply-received
rigAssert "and carries the verdict"                       "$( rigRecordVerdict )" yes
rigVerdict "readback -- fields posted, the addressee's yes is the verdict, the record carries it"

rigStart readback-wait-false
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait\":\"false\",$rigReadbackArgs}"
rigAssert "an escalation asked with wait=false still waits" "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "and says wait=false was ignored"               "$( rigHolds "$rigScenarioDir/out" 'wait=false was ignored' )" yes
rigAssert "control: waited without it, no such line"      "$( rigHolds "$rigTmp/readback-yes/out" 'wait=false was ignored' )" no
rigVerdict "an escalation always waits -- wait=false is overridden and said so"

rigStart readback-correct
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"correct: use tag v2 instead","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",$rigReadbackArgs}" from-read
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the verdict is correct"                        "$( rigVerdictLine )" "VERDICT: correct"
rigAssert "and carries the correction"                    "$( rigHolds "$rigScenarioDir/out" 'VERDICT-TEXT: use tag v2 instead' )" yes
rigVerdict "readback -- correct carries its text"

## ---------------------------------------------------------------------------
## 12. A bare reaction on a typed kind is not its answer: it returns UNCLASSIFIED to
##     the agent and the record stays open. The reaction the kind declares is the control.
## ---------------------------------------------------------------------------
rigStart readback-bare-reaction
rigReplies ',"reactions":[{"name":"thumbsup","count":1,"users":["URIGOWNER"]}]' ""
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",$rigReadbackArgs}" from-read
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the bare reaction is UNCLASSIFIED"             "$( rigVerdictLine )" "VERDICT: UNCLASSIFIED"
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigAssert "the last line is the re-wait call"             "$( LC_ALL=C awk 'END { sub( /[0-9a-f-]+$/, "<id>" ) ; print ; }' "$rigScenarioDir/out" )" "AskUserQuestion pending_id=<id>"
rigStart readback-declared-reaction
rigReplies ',"reactions":[{"name":"white_check_mark","count":1,"users":["URIGOWNER"]}]' ""
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",$rigReadbackArgs}" from-read
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "control: the declared reaction is yes"         "$( rigVerdictLine )" "VERDICT: yes"
rigAssert "control: the record closes"                    "$( rigRecordStatus )" reply-received
rigStart question-reaction
rigReplies ',"reactions":[{"name":"thumbsup","count":1,"users":["URIGOWNER"]}]' ""
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}" from-read
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "a plain question keeps today's shape, with no verdict" "$( rigVerdictLine )" "no-verdict-line"
rigAssert "and any addressee reaction still answers it"   "$( rigRecordStatus )" reply-received
rigVerdict "a bare reaction on a typed kind is not its answer, and a declared one classifies"

## ---------------------------------------------------------------------------
## 13. A decision: the first word of the reply names the option; any other word is
##     UNCLASSIFIED, returned to the agent with the record open.
## ---------------------------------------------------------------------------
rigStart decision-beta
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Beta, please","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"alpha -- keep the old tag\\nbeta -- cut a new tag\"}"
rigAssert "the verdict is the option's own word"          "$( rigVerdictLine )" "VERDICT: beta"
rigAssert "the post carries the decision heading"         "$( rigHolds "$rigScenarioDir/post.1" 'Decision' )" yes
rigStart decision-other
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"gamma","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"alpha -- keep the old tag\\nbeta -- cut a new tag\"}" from-read
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "any other word is UNCLASSIFIED"                "$( rigVerdictLine )" "VERDICT: UNCLASSIFIED"
rigAssert "the reply text is returned"                    "$( rigHolds "$rigScenarioDir/out" 'gamma' )" yes
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigAssert "nothing is posted for it"                      "$( rigCalls chat.postMessage )" 1
rigVerdict "decision -- the option's word is the verdict, anything else returns UNCLASSIFIED"

## ---------------------------------------------------------------------------
## 14. A reply naming no option returns UNCLASSIFIED; the agent re-waits on the same
##     pending id, posting nothing, and the later reply's option is the verdict.
## ---------------------------------------------------------------------------
rigStart decision-unclassified-then-option
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"YES, SURE","thread_ts":"1700000001.000101"}'
rigAsk 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow -- let it run\\ndeny -- stop it\"}"
rigAssert "it ran to completion"                          "$rigKilled" no
rigAssert "the unrecognised reply is UNCLASSIFIED"        "$( rigVerdictLine )" "VERDICT: UNCLASSIFIED"
rigAssert "the record stays open"                         "$( rigRecordStatus )" reply-pending
rigRewaitId="$( LC_ALL=C sed -n 's/^AskUserQuestion pending_id=//p' "$rigScenarioDir/out" | tail -1 )"
rigAssert "the last line names the record to re-wait on"  "$( [ -n "$rigRewaitId" ] && [ -f "$rigScenarioDir/ws/.local/agents/pending/$rigRewaitId.md" ] && printf yes || printf no )" yes
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"YES, SURE","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"allow","thread_ts":"1700000001.000101"}'
rigPostsBefore="$( rigCalls chat.postMessage )"
rigAsk 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "the re-wait ran to completion"                 "$rigKilled" no
rigAssert "the re-wait posted nothing"                    "$(( $( rigCalls chat.postMessage ) - rigPostsBefore ))" 0
rigAssert "the later reply's option is the verdict"       "$( rigVerdictLine )" "VERDICT: allow"
rigAssert "the record closed as received"                 "$( rigRecordStatus )" reply-received
rigAssert "and carries the verdict"                       "$( rigRecordVerdict )" allow
rigAsk 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "a closed record is refused"                    "$( rigHolds "$rigScenarioDir/out" 'is closed' )" yes
rigAsk 30 '{"pending_id":"no-such-record"}'
rigAssert "an unknown id is refused"                      "$( rigHolds "$rigScenarioDir/out" 'names no pending reply' )" yes
rigVerdict "decision -- a reply naming no option returns UNCLASSIFIED, and a re-wait on its id finds the later answer"

## ---------------------------------------------------------------------------
## Offline, asserted: every request any scenario made went to the fake, and the
## fake only ever answered Slack methods.
## ---------------------------------------------------------------------------
rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method"   "$rigUnknown" 0
rigVerdict "offline -- every request was answered by the fake"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
