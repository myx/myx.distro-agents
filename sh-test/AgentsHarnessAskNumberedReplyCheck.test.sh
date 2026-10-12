#!/usr/bin/env bash
## Behavioural check on a numbered reply: which question a reply starting with a question's
## number, `Q<n>`, answers -- in a thread several questions share, and in a thread that has
## held one numbered question alone. A member's reply starts with the send header the team's
## own send writes ahead of every message (mark, sender, alias, arrow, addressees), so its
## number is the first word after that header: on the head line, or on the line under it
## where the header fills the head line. And a reply with no number that came after the
## latest question above it was answered is set aside whole, every line of it.
## Two parts. The reader alone (AgentsSlackThreadAnswers.awk, with AgentsDismissalMatch.awk
## loaded ahead of it, exactly as the Wait and the escalation read run it), over one rendered
## thread: a person's and a member's reply, numbered for this question, numbered for another
## and with no number. Then AskQuestion through --intern-tool, the path the myx.distro MCP
## uses: two questions in one thread, a member's numbered reply answering the one it names
## and leaving the other open; one question alone in its thread, answered by a reply that
## starts with its own number; and a reply of two lines set aside, whose second line is no
## answer to anything.
## Red recipe: drop the memberSendHeaderLength call from AgentsSlackThreadAnswers.awk, and
## every "a member's reply, numbered" assertion fails while every person's one still passes.
## Offline: a Slack-shaped fake curl is first on PATH, and every scenario runs in its own
## workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskNumberedReplyCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
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

## A member's send header, as the send writes it: with a mark, and with none and two addressees.
rigHeader=':mouse: *_magic-coordinator_* @dispatchr → <@URIGSELF1>.'
rigHeaderTwo='*_keeper-myx_* @keeper → *_magic-tester_* @tester; *_magic-developer_* <@URIGDEV>.'

echo "-- the reader alone: a thread two questions share, Q1 and Q2, and one reply under them --"
## What the reader prints for one of the two questions, its lines joined by `#`. The thread is
## rendered as the formatter prints it: the thread's own first message, Q1, Q2, then the lines
## given. The other question is `open`, or closed at the epoch second given; `alone` reads Q1
## as the one question its thread has held, and `unnumbered` the same for a question that
## carries no number.
rigRead(){ ## question (1|2), the other question (open|<epoch second>|alone|unnumbered), rendered lines...
	local readTag="Q$1" readRoot="1700000001.000101" readOther="1700000001.000201/$2" readCount=2
	[ "$1" = "1" ] || { readRoot="1700000001.000201" ; readOther="1700000001.000101/$2" ; }
	[ "$2" != "alone" ] || { readOther="" ; readCount=1 ; }
	[ "$2" != "unnumbered" ] || { readTag="" ; readOther="" ; readCount=1 ; }
	shift 2
	{
		printf '%s\n' '1700000001.000001 | URIGOTHER | the thread' '1700000001.000101 | URIGSELF1 | question one'
		[ "$readCount" = 1 ] || printf '%s\n' '1700000001.000201 | URIGSELF1 | question two'
		printf '%s\n' "$@"
	} | LC_ALL=C awk -v rootTs="$readRoot" -v askingUsers=URIGSELF1 -v fromUsers=URIGOWNER -v tag="$readTag" -v threadCount="$readCount" -v others="$readOther" \
		-f "$rigHere/AgentsDismissalMatch.awk" -f "$rigHere/AgentsSlackThreadAnswers.awk" 2>&1 | LC_ALL=C tr '\n' '#'
}
rigReply='1700000009.000400 | URIGOWNER |'
rigLater='1700000009.000500 | URIGOWNER |'

## A person's reply: what the reader did before a member's header was read, held unchanged.
rigAssert "a person's reply, numbered for this question: taken, its number dropped" "$( rigRead 1 open "$rigReply Q1 beta" )" "$rigReply beta#"
rigAssert "a person's reply, numbered for the other question: not taken" "$( rigRead 2 open "$rigReply Q1 beta" )" ""
rigAssert "a person's reply, numbered in small letters with a colon" "$( rigRead 1 open "$rigReply q1: beta, the lint" )" "$rigReply beta, the lint#"
rigAssert "a person's reply of several lines, numbered: every line of it" "$( rigRead 2 open "$rigReply Q2 gamma" 'because it is last' )" "$rigReply gamma#because it is last#"
rigAssert "and no line of it for the other question" "$( rigRead 1 open "$rigReply Q2 gamma" 'because it is last' )" ""
rigAssert "a person's reply with no number answers the latest question above it" "$( rigRead 2 open "$rigReply beta" )" "$rigReply beta#"
rigAssert "and not the one before" "$( rigRead 1 open "$rigReply beta" )" ""
rigAssert "a person's reply with no number, after the latest question closed: set aside" "$( rigRead 1 1700000005 "$rigReply beta" )" "UNMATCHED-REPLY $rigReply beta#"
rigAssert "a person's reply of several lines, set aside: every line of it is marked" "$( rigRead 1 1700000005 "$rigReply thanks" 'beta' '' 'and more' )" "UNMATCHED-REPLY $rigReply thanks#UNMATCHED-REPLY beta#UNMATCHED-REPLY #UNMATCHED-REPLY and more#"
rigAssert "and the reply after it is read on its own" "$( rigRead 1 1700000005 "$rigReply thanks" 'beta' "$rigLater Q1 gamma" 'as said' )" "UNMATCHED-REPLY $rigReply thanks#UNMATCHED-REPLY beta#$rigLater gamma#as said#"
rigAssert "an arrow in a person's own words is no header: the reply has no number" "$( rigRead 1 open "$rigReply see a → b. Q1 beta" ):$( rigRead 2 open "$rigReply see a → b. Q1 beta" )" ":$rigReply see a → b. Q1 beta#"

## A member's reply: the number is the first word after the send header.
rigAssert "a member's reply, numbered for this question: taken, header kept, number dropped" "$( rigRead 1 open "$rigReply $rigHeader Q1 beta" )" "$rigReply $rigHeader beta#"
rigAssert "a member's reply, numbered for the other question: not taken" "$( rigRead 2 open "$rigReply $rigHeader Q1 beta" )" ""
rigAssert "a member's reply, numbered, behind the formatter's own annotation" "$( rigRead 2 open "$rigReply [sender: magic-coordinator] $rigHeader Q2: gamma" )" "$rigReply [sender: magic-coordinator] $rigHeader gamma#"
rigAssert "a header with no mark and two addressees is a header too" "$( rigRead 1 open "$rigReply $rigHeaderTwo Q1 beta" ):$( rigRead 2 open "$rigReply $rigHeaderTwo Q1 beta" )" "$rigReply $rigHeaderTwo beta#:"
rigAssert "the header on a line of its own, the number on the next: taken" "$( rigRead 1 open "$rigReply $rigHeader" 'Q1 beta' )" "$rigReply $rigHeader#beta#"
rigAssert "and no line of it for the other question" "$( rigRead 2 open "$rigReply $rigHeader" 'Q1 beta' 'and a note' )" ""
rigAssert "with every line under it" "$( rigRead 1 open "$rigReply $rigHeader" 'Q1 beta' 'and a note' )" "$rigReply $rigHeader#beta#and a note#"
rigAssert "an empty line between the header and the number changes nothing" "$( rigRead 1 open "$rigReply $rigHeader" '' 'Q1 beta' ):$( rigRead 2 open "$rigReply $rigHeader" '' 'Q1 beta' )" "$rigReply $rigHeader##beta#:"
rigAssert "a member's reply with no number answers the latest question above it, as before" "$( rigRead 2 open "$rigReply $rigHeader beta" ):$( rigRead 1 open "$rigReply $rigHeader beta" )" "$rigReply $rigHeader beta#:"
rigAssert "the same with its header on a line of its own" "$( rigRead 2 open "$rigReply $rigHeader" 'beta' ):$( rigRead 1 open "$rigReply $rigHeader" 'beta' )" "$rigReply $rigHeader#beta#:"
rigAssert "a member's reply with no number, after the latest question closed: set aside" "$( rigRead 1 1700000005 "$rigReply $rigHeader beta" )" "UNMATCHED-REPLY $rigReply $rigHeader beta#"
rigAssert "the same with its header on a line of its own: both lines marked" "$( rigRead 1 1700000005 "$rigReply $rigHeader" 'beta' )" "UNMATCHED-REPLY $rigReply $rigHeader#UNMATCHED-REPLY beta#"
rigAssert "a header with nothing under it is a reply with no number" "$( rigRead 2 open "$rigReply $rigHeader" ):$( rigRead 1 open "$rigReply $rigHeader" )" "$rigReply $rigHeader#:"
rigAssert "a reply after a member's is read on its own: the one numbered for this question" "$( rigRead 1 open "$rigReply $rigHeader" 'Q2 gamma' "$rigLater Q1 beta" )" "$rigLater beta#"
rigAssert "and the member's, for the question it names" "$( rigRead 2 open "$rigReply $rigHeader" 'Q2 gamma' "$rigLater Q1 beta" )" "$rigReply $rigHeader#gamma#"
rigAssert "a reply after a header with nothing under it is read on its own too" "$( rigRead 1 open "$rigReply $rigHeader" "$rigLater $rigHeader Q1 beta" )" "$rigLater $rigHeader beta#"

## A thread that has held one numbered question: a reply starting with that question's own
## number answers it, for a person and for a member; every other reply is printed whole.
rigAssert "one question alone: a person's reply starting with its number is taken, the number dropped" "$( rigRead 1 alone "$rigReply Q1 beta" ):$( rigRead 1 alone "$rigReply q1: beta" 'and a note' )" "$rigReply beta#:$rigReply beta#and a note#"
rigAssert "one question alone: the same for a member's reply, its header kept" "$( rigRead 1 alone "$rigReply $rigHeader Q1 beta" )" "$rigReply $rigHeader beta#"
rigAssert "one question alone: and with the header on a line of its own" "$( rigRead 1 alone "$rigReply $rigHeader" 'Q1 beta' 'and a note' )" "$rigReply $rigHeader#beta#and a note#"
rigAssert "one question alone: a number that is not that question's is left as it is" \
	"$( rigRead 1 alone "$rigReply Q2 beta" ):$( rigRead 1 alone "$rigReply $rigHeader Q2 beta" ):$( rigRead 1 alone "$rigReply $rigHeader" 'Q2 beta' )" \
	"$rigReply Q2 beta#:$rigReply $rigHeader Q2 beta#:$rigReply $rigHeader#Q2 beta#"
rigAssert "one question alone: a reply with no number is printed whole" \
	"$( rigRead 1 alone "$rigReply beta" 'more' ):$( rigRead 1 alone "$rigReply $rigHeader beta" ):$( rigRead 1 alone "$rigReply $rigHeader" '' 'beta' )" \
	"$rigReply beta#more#:$rigReply $rigHeader beta#:$rigReply $rigHeader##beta#"
rigAssert "control: a question that carries no number takes nothing by number" \
	"$( rigRead 1 unnumbered "$rigReply Q1 beta" ):$( rigRead 1 unnumbered "$rigReply $rigHeader" 'Q1 beta' )" \
	"$rigReply Q1 beta#:$rigReply $rigHeader#Q1 beta#"

echo "-- through AskQuestion: two questions in one thread, each answered by the reply numbered for it --"
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigWaitId(){ ## -> the pending id the last call left to wait on
	LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | head -1
}
rigFieldOf(){ ## pending id, field
	LC_ALL=C awk -v key="$2" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' \
		"$rigScenarioDir/ws/.local/agents/pending/$1.md" 2>/dev/null || printf 'no-record'
}

rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## One served call of AskQuestion. A question nobody answers is re-waited without end by
## design, so the guard is the scenario's: a killed run is reported as such, never as a
## result. With from-read the guard counts from the first thread read this call makes.
rigKilled=""
rigCall(){ ## guard seconds, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-numbered-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskQuestion --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		if [ "${3:-}" = "from-read" ] && [ "$callStartLeft" -gt 0 ] && [ "$( rigCalls conversations.replies )" = "$callReads" ] ; then
			callStartLeft=$(( callStartLeft - 1 ))
			continue
		fi
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}

## The shared thread as conversations.replies returns it: its own first message, the
## questions posted so far (ts suffixes), then the replies, each "<ts suffix>|<text>", or
## "<a whole ts>|<text>" for a reply that must be later than the clock. A
## reply comes from the account the questions are addressed to: a member's is that account's
## text opening with the member's send header, as a member's own send posts it.
rigSharedThread(){ ## the questions' ts suffixes (one word), replies...
	local sharedOut="" sharedTs sharedReply
	for sharedTs in $1 ; do
		sharedOut="$sharedOut,{\"ts\":\"1700000001.$sharedTs\",\"user\":\"URIGSELF1\",\"text\":\"a question\",\"thread_ts\":\"1700000001.000001\"}"
	done
	shift
	for sharedReply in "$@" ; do
		sharedTs="${sharedReply%%|*}"
		case "$sharedTs" in *.*) ;; *) sharedTs="1700000001.$sharedTs" ;; esac
		sharedOut="$sharedOut,{\"ts\":\"$sharedTs\",\"user\":\"URIGOWNER\",\"text\":\"${sharedReply#*|}\",\"thread_ts\":\"1700000001.000001\"}"
	done
	printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"}%s],"has_more":false}\n' "$sharedOut" > "$rigScenarioDir/replies.json"
}
## Two questions asked into one thread, neither waited on: Q1, then Q2. With a select they
## take one of three options; with none they take any text.
rigOptions='"select":"one","options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run",'
rigSharedFirst="" rigSharedSecond=""
rigSharedStart(){ ## scenario name, the answer form's fields (may be empty)
	rigStart "$1"
	rigSharedThread '000101'
	rigCall 30 "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check first?\",$2\"wait\":false}"
	rigSharedFirst="$( rigWaitId )"
	rigSharedThread '000101 000201'
	rigCall 30 "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check last?\",$2\"wait\":false}"
	rigSharedSecond="$( rigWaitId )"
	[ -n "$rigSharedFirst" ] && [ -n "$rigSharedSecond" ] && [ "$rigSharedFirst" != "$rigSharedSecond" ] || rigRefuse "the rig did not leave two questions in one thread"
	[ "$( rigFieldOf "$rigSharedFirst" question-tag ):$( rigFieldOf "$rigSharedSecond" question-tag )" = "Q1:Q2" ] || rigRefuse "the rig did not number the two questions Q1 and Q2"
}

## The human-owner's own replies, each numbered: the reading a member's reply is held to.
rigSharedStart owner-numbered "$rigOptions"
rigSharedThread '000101 000201' '000400|Q2 gamma' '000500|Q1 beta'
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "a person's reply numbered for the first question answers it" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "no:VERDICT: beta:beta"
rigAssert "and the second is still open"               "$( rigFieldOf "$rigSharedSecond" status )" "reply-pending"
rigCall 60 "{\"pending_id\":\"$rigSharedSecond\"}"
rigAssert "which takes the reply numbered for it"      "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedSecond" verdict )" "no:VERDICT: gamma:gamma"

## The case of the ruling: a member replies with the number of the first and an answer. The
## first question takes the answer, and the second stays open.
rigSharedStart member-numbered "$rigOptions"
rigSharedThread '000101 000201' "000400|$rigHeader Q1 beta"
rigCall 6 "{\"pending_id\":\"$rigSharedSecond\"}" from-read
rigAssert "a member's reply numbered for the first question does not answer the second: it is still waiting" "$rigKilled:$( rigFieldOf "$rigSharedSecond" status )" "yes:reply-pending"
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "the first question takes it as its answer"  "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "no:VERDICT: beta:beta"
rigAssert "its record closes, the second stays open"   "$( rigFieldOf "$rigSharedFirst" status ):$( rigFieldOf "$rigSharedSecond" status )" "reply-received:reply-pending"
rigCall 6 "{\"pending_id\":\"$rigSharedSecond\"}" from-read
rigAssert "and that reply never answers the second, the first now closed" "$rigKilled:$( rigFieldOf "$rigSharedSecond" status )" "yes:reply-pending"

## The same with the header on a line of its own, as a send with no blocks posts it, and
## numbered for the second question.
rigSharedStart member-numbered-next-line "$rigOptions"
rigSharedThread '000101 000201' "000400|$rigHeader\\nQ2 gamma"
rigCall 6 "{\"pending_id\":\"$rigSharedFirst\"}" from-read
rigAssert "the header on a line of its own, the number under it: the first question is still waiting" "$rigKilled:$( rigFieldOf "$rigSharedFirst" status )" "yes:reply-pending"
rigCall 60 "{\"pending_id\":\"$rigSharedSecond\"}"
rigAssert "the second question takes it as its answer" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedSecond" verdict ):$( rigFieldOf "$rigSharedFirst" status )" "no:VERDICT: gamma:gamma:reply-pending"

## A member's reply with no number, as before: it answers the latest question above it.
rigSharedStart member-plain "$rigOptions"
rigSharedThread '000101 000201' "000400|$rigHeader gamma"
rigCall 6 "{\"pending_id\":\"$rigSharedFirst\"}" from-read
rigAssert "a member's reply with no number does not answer the first question" "$rigKilled:$( rigFieldOf "$rigSharedFirst" status )" "yes:reply-pending"
rigCall 60 "{\"pending_id\":\"$rigSharedSecond\"}"
rigAssert "it answers the question posted last above it" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedSecond" verdict )" "no:VERDICT: gamma:gamma"

## Two questions that take any text: no verdict is read, so the Wait alone says whose the reply is.
rigSharedStart member-numbered-text ""
rigSharedThread '000101 000201' "000400|$rigHeader Q1: keep the first report"
rigCall 6 "{\"pending_id\":\"$rigSharedSecond\"}" from-read
rigAssert "free text: the second question is still waiting" "$rigKilled:$( rigFieldOf "$rigSharedSecond" status )" "yes:reply-pending"
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "free text: the first question receives the member's reply" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigHolds "$rigScenarioDir/out" 'keep the first report' ):$( rigFieldOf "$rigSharedFirst" status ):$( rigFieldOf "$rigSharedSecond" status )" \
	"no:ASK-RESULT: RECEIVED:yes:reply-received:reply-pending"

echo "-- one question alone in its thread: a reply starting with its own number is its answer --"
## One question asked into a thread, alone there, not waited on: it is numbered, as every
## question inside a thread is.
rigAloneStart(){ ## scenario name
	rigStart "$1"
	rigSharedThread '000101'
	rigCall 30 "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check first?\",$rigOptions\"wait\":false}"
	rigSharedFirst="$( rigWaitId )"
	[ -n "$rigSharedFirst" ] && [ "$( rigFieldOf "$rigSharedFirst" question-tag )" = "Q1" ] || rigRefuse "the rig did not leave one question numbered Q1 in the thread"
}
rigAloneStart alone-owner
rigSharedThread '000101' '000400|Q1 beta'
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "a person's reply starting with the question's own number is its answer" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "no:VERDICT: beta:beta"
rigAloneStart alone-member
rigSharedThread '000101' "000400|$rigHeader Q1 beta"
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "a member's reply starting with it, after its send header, is its answer" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "no:VERDICT: beta:beta"
rigAloneStart alone-member-next-line
rigSharedThread '000101' "000400|$rigHeader\\nQ1 gamma"
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "the same with the header on a line of its own" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "no:VERDICT: gamma:gamma"
rigAloneStart alone-other-number
rigSharedThread '000101' '000400|Q7 beta'
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "a number that is not that question's is no answer, as before: the question comes back, still open" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" status )" "no:VERDICT: RETURNED:reply-pending"

echo "-- a reply set aside is set aside whole: the line under its first is no answer --"
## Q2 is answered and closed. Then, for Q1, a reply numbered for it that is all quote and
## names no answer, and after it a reply of two lines with no number, later than Q2's close:
## it answers none, and its second line, an option's word, must not be read as Q1's answer.
rigSharedStart set-aside-whole "$rigOptions"
rigSharedThread '000101 000201' '000400|Q2 gamma'
rigCall 60 "{\"pending_id\":\"$rigSharedSecond\"}"
rigAssert "control: the second question is answered and closed" "$( rigVerdictLine ):$( rigFieldOf "$rigSharedSecond" status )" "VERDICT: gamma:reply-received"
rigAsideTs="$(( $( date +%s ) + 120 )).000600"
rigSharedThread '000101 000201' '000400|Q2 gamma' '000500|Q1 &gt; alpha, was it?' "$rigAsideTs|thanks for that\\nbeta"
rigCall 60 "{\"pending_id\":\"$rigSharedFirst\"}"
rigAssert "the second line of a reply set aside is not taken as the first question's answer" "$rigKilled:$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict ):$( rigFieldOf "$rigSharedFirst" status )" "no:VERDICT: RETURNED:none:reply-pending"
rigAssert "the question comes back saying why"         "$( rigHolds "$rigScenarioDir/out" 'a reply with no question number came after the latest question above it was already answered' )" yes

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK NUMBERED REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_NUMBERED_REPLY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
