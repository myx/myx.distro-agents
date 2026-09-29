#!/usr/bin/env bash
## AskUserQuestion in a thread several questions share (AgentsTools.AskThread.include):
## a second question to the same person lands in the first one's thread, tagged Q2, with
## no second opener; an identical open question is not posted again; with two questions
## open, a reaction on Q2 answers Q2 only, a reply "Q1: yes" answers Q1 only, a plain
## reply answers the latest question above it (Q2) only, and a plain reply after Q2 was
## answered is returned UNCLASSIFIED to Q1 with its record left open; two asks at
## once get distinct tags; once Q1 is answered, a late reply tagged Q1 still does not
## answer Q2, since a thread that has held two questions stays shared. The controls:
## a different party, and the same person in a different conversation, each get a
## thread of their own. Only the thread numbers a question: a number the asker put in
## front of the text is removed, and no post says "tag". Offline: the Slack-shaped ask fixture is
## first on PATH; each scenario has its own workspace under the workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskThreadCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigHere/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigPosts(){
	cat "$rigScenarioDir/posts" 2>/dev/null || echo 0
}
rigStatus(){ ## pending id
	LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$1.md" 2>/dev/null
}
rigPendingOf(){ ## output file -> the pending id it names
	LC_ALL=C sed -n 's/.*recorded as pending reply \([0-9a-f-]*\).*/\1/p' "$1" | head -1
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The shared thread: opener, Q1, Q2, then the scenario's later messages.
rigReplies(){ ## Q2's own extra fields, later messages
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"opener"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"Q1","thread_ts":"1700000001.000101"},{"ts":"1700000001.000103","user":"URIGSELF1","text":"Q2","thread_ts":"1700000001.000101"%s}%s],"has_more":false}\n' "$1" "$2" > "$rigScenarioDir/replies.json"
}
rigKilled=""
rigAsk(){ ## output name, guard seconds, argument object
	local askPid askLeft="$2"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		TMPDIR="$rigTmp/tmp" MDAT_SPAWN_SESSION_ID=rig-session-a RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigScenarioDir/$1" 2> "$rigScenarioDir/$1.err" &
	askPid=$!
	set +m
	while kill -0 "$askPid" 2>/dev/null && [ "$askLeft" -gt 0 ] ; do sleep 1 ; askLeft=$(( askLeft - 1 )) ; done
	if kill -0 "$askPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	{ wait "$askPid" ; } 2>/dev/null || :
}
rigQ1='May the rig keep its first report file?'
rigQ2='May the rig also keep its second report file?'
## Two questions to the same person, both posted without waiting: Q1 opens the thread.
rigTwoOpen(){ ## scenario name
	rigStart "$1"
	rigReplies "" ""
	rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
	rigQ1Id="$( rigPendingOf "$rigScenarioDir/ask1" )"
	rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ2\",\"wait\":false}"
	rigQ2Id="$( rigPendingOf "$rigScenarioDir/ask2" )"
	[ -n "$rigQ1Id" ] && [ -n "$rigQ2Id" ] || rigRefuse "the two questions were not both recorded: $( head -2 "$rigScenarioDir/ask1" ) / $( head -2 "$rigScenarioDir/ask2" )"
}

echo "-- a second question to the same person joins the first one's thread --"
rigTwoOpen shared
rigAssert "three posts: one opener, then Q1 and Q2"       "$( rigPosts )" 3
rigAssert "Q1 is tagged in its heading"                   "$( rigHolds "$rigScenarioDir/post.2" 'Question Q1' )" yes
rigAssert "Q2 is tagged in its heading"                   "$( rigHolds "$rigScenarioDir/post.3" 'Question Q2' )" yes
rigAssert "Q2 is posted into Q1's thread"                 "$( rigHolds "$rigScenarioDir/post.3" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "Q2's record carries its tag"                   "$( LC_ALL=C grep -c '^question-tag: Q2$' "$rigScenarioDir/ws/.local/agents/pending/$rigQ2Id.md" )" 1

echo "-- an identical open question is not posted again --"
rigAsk ask3 20 "{\"to\":\"human-owner\",\"question\":\"  $rigQ1 \",\"wait\":false}"
rigAssert "it says already open"                          "$( head -1 "$rigScenarioDir/ask3" )" "ASK-RESULT: ALREADY-OPEN"
rigAssert "naming the open record"                        "$( rigHolds "$rigScenarioDir/ask3" "pending reply $rigQ1Id" )" yes
rigAssert "and nothing more is posted"                    "$( rigPosts )" 3

echo "-- asked again once its thread holds the answer: nothing is posted, the record closes --"
rigStart reask
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigReaskId="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, keep it","thread_ts":"1700000001.000101"}'
rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "it says received"                              "$( head -1 "$rigScenarioDir/ask2" )" "ASK-RESULT: RECEIVED"
rigAssert "with the answer from the thread"               "$( rigHolds "$rigScenarioDir/ask2" 'yes, keep it' )" yes
rigAssert "nothing more is posted"                        "$( rigPosts )" 2
rigAssert "and the record is closed"                      "$( rigStatus "$rigReaskId" )" reply-received

echo "-- two open: a reaction on Q2 answers Q2 only --"
rigTwoOpen reaction
rigReplies ',"reactions":[{"name":"white_check_mark","count":1,"users":["URIGOWNER"]}]' ""
rigAsk wait1 6 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is still waited on"                         "$rigKilled" yes
rigAsk wait2 20 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is answered"                                "$( head -1 "$rigScenarioDir/wait2" )" "ASK-RESULT: RECEIVED"
rigAssert "Q2's record closes"                            "$( rigStatus "$rigQ2Id" )" reply-received
rigAssert "Q1's stays open"                               "$( rigStatus "$rigQ1Id" )" reply-pending

echo "-- two open: a reply tagged Q1 answers Q1 only --"
rigTwoOpen tagged
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000101"}'
rigAsk wait2 6 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is still waited on"                         "$rigKilled" yes
rigAsk wait1 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is answered"                                "$( head -1 "$rigScenarioDir/wait1" )" "ASK-RESULT: RECEIVED"
rigAssert "Q1's record closes"                            "$( rigStatus "$rigQ1Id" )" reply-received
rigAssert "Q2's stays open"                               "$( rigStatus "$rigQ2Id" )" reply-pending
rigAssert ":eyes: on the reply the wait took"             "$( LC_ALL=C grep -c -x -F '1700000001.000200 eyes' "$rigScenarioDir/reactions" 2>/dev/null )" 1
rigAssert ":white_check_mark: on Q1"                      "$( LC_ALL=C grep -c -x -F '1700000001.000102 white_check_mark' "$rigScenarioDir/reactions" 2>/dev/null )" 1
rigAssert "none on the opener while Q2 is open"           "$( LC_ALL=C grep -c -x -F '1700000001.000101 white_check_mark' "$rigScenarioDir/reactions" 2>/dev/null )" 0

echo "-- two open: a plain reply answers the latest question above it, Q2 only --"
rigTwoOpen untagged
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000101"}'
rigAsk wait1 6 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is still waited on"                         "$rigKilled" yes
rigAssert "and its record stays open"                     "$( rigStatus "$rigQ1Id" )" reply-pending
rigAsk wait2 20 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is answered"                                "$( head -1 "$rigScenarioDir/wait2" )" "ASK-RESULT: RECEIVED"
rigAssert "with no verdict line"                          "$( LC_ALL=C grep -c '^VERDICT: ' "$rigScenarioDir/wait2" )" 0
rigAssert "and its record closes"                         "$( rigStatus "$rigQ2Id" )" reply-received

echo "-- Q2 answered: that same reply still does not answer Q1 --"
rigAsk wait1b 6 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is still waited on"                         "$rigKilled" yes

echo "-- Q2 answered: a later plain reply answers nothing, and says so --"
rigStrayTs="$(( $( date +%s ) + 120 )).000300"
rigReplies "" ",{\"ts\":\"1700000001.000200\",\"user\":\"URIGOWNER\",\"text\":\"yes\",\"thread_ts\":\"1700000001.000101\"},{\"ts\":\"$rigStrayTs\",\"user\":\"URIGOWNER\",\"text\":\"yes\",\"thread_ts\":\"1700000001.000101\"}"
rigAsk wait1c 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 gets UNCLASSIFIED"                          "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigScenarioDir/wait1c" )" "VERDICT: UNCLASSIFIED"
rigAssert "with a reason naming the plain text Q1"        "$( rigHolds "$rigScenarioDir/wait1c" 'starts with the plain text Q1' )" yes
rigAssert "and never saying tag"                          "$( LC_ALL=C grep -c -i -E '(^|[^a-z])(un)?tag(ged)?([^a-z]|$)' "$rigScenarioDir/wait1c" )" 0
rigAssert "and its record stays open"                     "$( rigStatus "$rigQ1Id" )" reply-pending

echo "-- two asks at once to the same person get distinct tags --"
rigStart concurrent
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
( rigAsk askA 30 "{\"to\":\"human-owner\",\"question\":\"May the rig keep report A?\",\"wait\":false}" ) &
( rigAsk askB 30 "{\"to\":\"human-owner\",\"question\":\"May the rig keep report B?\",\"wait\":false}" ) &
wait
rigAssert "both were posted"                              "$( rigPosts )" 4
rigAssert "under two different tags"                      "$( LC_ALL=C sed -n 's/^question-tag: //p' "$rigScenarioDir"/ws/.local/agents/pending/*.md | LC_ALL=C sort -u | tr '\n' ' ' )" "Q1 Q2 Q3 "

echo "-- Q1 answered, Q2 open: a late reply tagged Q1 does not answer Q2 --"
rigTwoOpen late
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000101"}'
rigAsk wait1 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is answered and closed"                     "$( rigStatus "$rigQ1Id" )" reply-received
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"Q1 actually no","thread_ts":"1700000001.000101"}'
rigAsk wait2 6 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is still waited on"                         "$rigKilled" yes
rigAssert "and stays open"                                "$( rigStatus "$rigQ2Id" )" reply-pending

echo "-- control: a different party opens a thread of its own --"
rigStart party
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAsk ask2 20 "{\"to\":\"magic-team\",\"question\":\"$rigQ2\",\"wait\":false}"
rigAssert "two openers and two questions"                 "$( rigPosts )" 4
rigAssert "the second question is in its own thread"      "$( rigHolds "$rigScenarioDir/post.4" '"thread_ts":"1700000001.000103"' )" yes
rigAssert "and is its thread's Q1"                        "$( rigHolds "$rigScenarioDir/post.4" 'Question Q1' )" yes

echo "-- control: the same person in a different conversation gets a thread of its own --"
rigStart conversation
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAsk ask2 20 "{\"to\":\"magic-team\",\"address_to\":\"human-owner\",\"question\":\"$rigQ2\",\"wait\":false}"
rigAssert "two openers and two questions"                 "$( rigPosts )" 4
rigAssert "the second question is in its own thread"      "$( rigHolds "$rigScenarioDir/post.4" '"thread_ts":"1700000001.000103"' )" yes
rigAssert "and is its thread's Q1"                        "$( rigHolds "$rigScenarioDir/post.4" 'Question Q1' )" yes

echo "-- only the thread numbers a question, and no post says tag --"
rigStart numbering
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"Q7: May the rig keep its first report file?\",\"wait\":false}"
rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"q1) May the rig also keep its second report file?\",\"wait\":false}"
rigAssert "the opener carries no number of the asker's"   "$( rigHolds "$rigScenarioDir/post.1" 'Q7' )" no
rigAssert "Q1's heading is Question Q1"                   "$( rigHolds "$rigScenarioDir/post.2" 'Question Q1' )" yes
rigAssert "and its text carries no second number"         "$( rigHolds "$rigScenarioDir/post.2" 'Q7' )" no
rigAssert "Q2's heading is Question Q2"                   "$( rigHolds "$rigScenarioDir/post.3" 'Question Q2' )" yes
rigAssert "and its text carries no second number"         "$( rigHolds "$rigScenarioDir/post.3" 'q1)' )" no
rigAssert "Q1 has no line about earlier questions"        "$( rigHolds "$rigScenarioDir/post.2" 'earlier question' )" no
rigAssert "and no rule that holds only sometimes"         "$( rigHolds "$rigScenarioDir/post.2" 'more than one question is open' )" no
rigAssert "Q2 says how to answer an earlier one"          "$( rigHolds "$rigScenarioDir/post.3" 'start your reply with its number, for example `Q1 yes`' )" yes
rigAssert "no post says tag"                              "$( cat "$rigScenarioDir"/post.* | LC_ALL=C grep -c -w -i 'tag' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS ASK THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_THREAD: OK (%d assertions, offline)\n' "$rigPassCount"
