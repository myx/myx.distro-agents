#!/usr/bin/env bash
## AskUserQuestion and the threads its questions live in (AgentsTools.AskThread.include):
## every question to a person is a new top-level message of its own, with no opener, and a
## second question to the same person never joins the first one's thread; an identical
## open question is not posted again. Where several questions do share a thread -- one the
## asker named with to=<channel>:<ts> -- a reaction on Q2 answers Q2 only, a reply "Q1: yes"
## answers Q1 only, a plain reply answers the latest question above it (Q2) only, and a
## plain reply after Q2 was answered is returned UNCLASSIFIED to Q1 with its record left
## open; once Q1 is answered, a late reply tagged Q1 still does not answer Q2, since a
## thread that has held two questions stays shared. Only a question in a named thread is
## numbered: a top-level one carries no number. Two asks at once get distinct numbers,
## numbers count per person across threads, and a different party has its own. Only the
## tool numbers a question: a number the asker put in front of the text is removed, and
## no post says "tag". Offline: the Slack-shaped ask fixture is first on PATH; each
## scenario has its own workspace under the workspace's .local/temp.
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
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskThreadCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
## A thread the asker named, which Q1 and Q2 share: its root is someone else's, then Q1,
## Q2, then the scenario's later messages.
rigNamed="CRIG00001:1700000001.000100"
rigReplies(){ ## Q2's own extra fields, later messages
	printf '{"ok":true,"messages":[{"ts":"1700000001.000100","user":"URIGOTHER","text":"the named thread"},{"ts":"1700000001.000101","user":"URIGSELF1","text":"Q1","thread_ts":"1700000001.000100"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"Q2","thread_ts":"1700000001.000100"%s}%s],"has_more":false}\n' "$1" "$2" > "$rigScenarioDir/replies.json"
}
## The thread a question to a person opens: the question is its root, then the later messages.
rigOwnReplies(){ ## later messages
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"Q1"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigKilled=""
rigAsk(){ ## output name, guard seconds, argument object
	local askPid askLeft="$2"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		TMPDIR="$rigTmp/tmp" MDAT_SPAWN_SESSION_ID="${RIG_SESSION:-rig-session-a}" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
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
## Two questions to the same person, both posted without waiting, to where the
## fragment says: the person (human-owner) or a thread the asker names.
rigTwoOpen(){ ## scenario name, "to" fragment of the argument object
	rigStart "$1"
	rigReplies "" ""
	rigAsk ask1 20 "{$2,\"question\":\"$rigQ1\",\"wait\":false}"
	rigQ1Id="$( rigPendingOf "$rigScenarioDir/ask1" )"
	rigAsk ask2 20 "{$2,\"question\":\"$rigQ2\",\"wait\":false}"
	rigQ2Id="$( rigPendingOf "$rigScenarioDir/ask2" )"
	[ -n "$rigQ1Id" ] && [ -n "$rigQ2Id" ] || rigRefuse "the two questions were not both recorded: $( head -2 "$rigScenarioDir/ask1" ) / $( head -2 "$rigScenarioDir/ask2" )"
}
rigToPerson='"to":"human-owner"'
rigToNamed="\"to\":\"$rigNamed\",\"address_to\":\"human-owner\""

echo "-- each question to the same person is a new top-level message of its own --"
rigTwoOpen separate "$rigToPerson"
rigAssert "two posts, one per question, and no opener"    "$( rigPosts )" 2
rigAssert "the first is a question heading"               "$( rigHolds "$rigScenarioDir/post.1" 'Question' )" yes
rigAssert "with no number, being top-level"               "$( rigHolds "$rigScenarioDir/post.1" 'Question Q' )" no
rigAssert "nor the second"                                "$( rigHolds "$rigScenarioDir/post.2" 'Question Q' )" no
rigAssert "the first is top-level, inside no thread"      "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts"' )" no
rigAssert "the second too, never in the first one's thread" "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts"' )" no
rigAssert "and is not a broadcast reply"                  "$( rigHolds "$rigScenarioDir/post.2" 'reply_broadcast' )" no
rigAssert "its record names its own message as its thread" "$( LC_ALL=C grep -c -x -E 'question-ts: 1700000001\.000102|thread-ts: 1700000001\.000102' "$rigScenarioDir/ws/.local/agents/pending/$rigQ2Id.md" )" 2
rigAssert "and carries no number"                         "$( LC_ALL=C grep -c '^question-tag: ' "$rigScenarioDir/ws/.local/agents/pending/$rigQ2Id.md" )" 0

echo "-- an identical open question is not posted again --"
rigAsk ask3 20 "{\"to\":\"human-owner\",\"question\":\"  $rigQ1 \",\"wait\":false}"
rigAssert "it says already open"                          "$( head -1 "$rigScenarioDir/ask3" )" "ASK-RESULT: ALREADY-OPEN"
rigAssert "naming the open record"                        "$( rigHolds "$rigScenarioDir/ask3" "pending reply $rigQ1Id" )" yes
rigAssert "and nothing more is posted"                    "$( rigPosts )" 2

echo "-- asked again once its thread holds the answer: nothing is posted, the record closes --"
rigStart reask
rigOwnReplies ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigReaskId="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigOwnReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, keep it","thread_ts":"1700000001.000101"}'
rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "it says received"                              "$( head -1 "$rigScenarioDir/ask2" )" "ASK-RESULT: RECEIVED"
rigAssert "with the answer from the thread"               "$( rigHolds "$rigScenarioDir/ask2" 'yes, keep it' )" yes
rigAssert "nothing more is posted"                        "$( rigPosts )" 1
rigAssert "and the record is closed"                      "$( rigStatus "$rigReaskId" )" reply-received

## Closes a record as an answered one, setting the fields given ("key: value" lines).
rigCloseRecord(){ ## pending id, extra header lines
	local closeFile="$rigScenarioDir/ws/.local/agents/pending/$1.md"
	RIG_EXTRA="$2" LC_ALL=C awk '
		BEGIN { extra = ENVIRON["RIG_EXTRA"] ; }
		!done && $0 == "status: reply-pending" { print "status: reply-received" ; next ; }
		!done && /^(owner|ask-identity): / && index(extra, substr($0, 1, index($0, ":"))) { next ; }
		!done && $0 == "---" && seen++ { printf "%s", extra ; done = 1 ; }
		{ print }
	' "$closeFile" > "$closeFile.tmp" && mv -f "$closeFile.tmp" "$closeFile"
}

echo "-- the same question asked again once closed, from another session, goes into its own thread --"
rigStart sameclosed
rigOwnReplies ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigSameId="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigCloseRecord "$rigSameId" ""
RIG_SESSION=rig-session-b rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "it is posted"                                  "$( head -1 "$rigScenarioDir/ask2" )" "ASK-RESULT: POSTED"
rigAssert "as one more post, no new top-level one"        "$( rigPosts )" 2
rigAssert "inside the first asking's thread"              "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "with no number, as the question had none"      "$( rigHolds "$rigScenarioDir/post.2" 'Question Q' )" no
rigSameId2="$( rigPendingOf "$rigScenarioDir/ask2" )"
rigAssert "its record names that thread"                  "$( LC_ALL=C grep -c -x -F 'thread-ts: 1700000001.000101' "$rigScenarioDir/ws/.local/agents/pending/$rigSameId2.md" )" 1
rigAssert "and carries no number"                         "$( LC_ALL=C grep -c '^question-tag: ' "$rigScenarioDir/ws/.local/agents/pending/$rigSameId2.md" )" 0

echo "-- the same: asked first as the team bot by another member, it still goes into that thread --"
rigStart samebot
rigOwnReplies ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false,\"as_bot\":true}"
rigSameId="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigCloseRecord "$rigSameId" "owner: magic-developer
ask-identity: bot
"
RIG_SESSION=rig-session-b rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "inside the first asking's thread"              "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "and recorded as asked by the bot, like the first" "$( LC_ALL=C grep -c -x -F 'ask-identity: bot' "$rigScenarioDir/ws/.local/agents/pending/$( rigPendingOf "$rigScenarioDir/ask2" ).md" )" 1

echo "-- control: asked first in another member's own DM, the asker cannot post there --"
rigStart sameother
rigOwnReplies ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigSameId="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigCloseRecord "$rigSameId" "owner: magic-developer
ask-identity: member
"
RIG_SESSION=rig-session-b rigAsk ask2 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "it is posted"                                  "$( head -1 "$rigScenarioDir/ask2" )" "ASK-RESULT: POSTED"
rigAssert "so it is a message of its own"                 "$( [ -f "$rigScenarioDir/post.2" ] && rigHolds "$rigScenarioDir/post.2" '"thread_ts"' )" no

echo "-- a follow-up to a question, to=<channel>:<ts> naming its message, goes into its thread with no number --"
rigStart followup
rigOwnReplies ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigFollowRoot="$( rigPendingOf "$rigScenarioDir/ask1" )"
rigAsk ask2 20 "{\"to\":\"CRIG00001:1700000001.000101\",\"address_to\":\"human-owner\",\"question\":\"To be clear, the first report file only?\",\"wait\":false}"
rigFollowUp="$( rigPendingOf "$rigScenarioDir/ask2" )"
rigAssert "two posts"                                     "$( rigPosts )" 2
rigAssert "the follow-up is in the question's thread"     "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "with no new number"                            "$( rigHolds "$rigScenarioDir/post.2" 'Question Q' )" no
rigAssert "and none in its record"                        "$( LC_ALL=C grep -c '^question-tag: ' "$rigScenarioDir/ws/.local/agents/pending/$rigFollowUp.md" )" 0
rigOwnReplies ',{"ts":"1700000001.000102","user":"URIGSELF1","text":"follow-up","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, only that one","thread_ts":"1700000001.000101"}'
rigAsk wait2 20 "{\"pending_id\":\"$rigFollowUp\"}"
rigAssert "the answer in the thread answers the follow-up" "$( head -1 "$rigScenarioDir/wait2" )" "ASK-RESULT: RECEIVED"
rigAsk wait1 20 "{\"pending_id\":\"$rigFollowRoot\"}"
rigAssert "and the question it follows up"                "$( head -1 "$rigScenarioDir/wait1" )" "ASK-RESULT: RECEIVED"

echo "-- two questions to the same person in a thread the asker named: both inside it --"
rigTwoOpen named "$rigToNamed"
rigAssert "two posts and no opener"                       "$( rigPosts )" 2
rigAssert "Q1 is in the named thread"                     "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts":"1700000001.000100"' )" yes
rigAssert "Q2 is in the named thread"                     "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000100"' )" yes
rigAssert "Q1 is numbered in its heading"                 "$( rigHolds "$rigScenarioDir/post.1" 'Question Q1' )" yes
rigAssert "Q2 is numbered in its heading"                 "$( rigHolds "$rigScenarioDir/post.2" 'Question Q2' )" yes
rigAssert "Q2's record carries its number"                "$( LC_ALL=C grep -c '^question-tag: Q2$' "$rigScenarioDir/ws/.local/agents/pending/$rigQ2Id.md" )" 1

echo "-- two open in the named thread: a reaction on Q2 answers Q2 only --"
rigTwoOpen reaction "$rigToNamed"
rigReplies ',"reactions":[{"name":"white_check_mark","count":1,"users":["URIGOWNER"]}]' ""
rigAsk wait1 6 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is still waited on"                         "$rigKilled" yes
rigAsk wait2 20 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is answered"                                "$( head -1 "$rigScenarioDir/wait2" )" "ASK-RESULT: RECEIVED"
rigAssert "Q2's record closes"                            "$( rigStatus "$rigQ2Id" )" reply-received
rigAssert "Q1's stays open"                               "$( rigStatus "$rigQ1Id" )" reply-pending

echo "-- two open in the named thread: a reply tagged Q1 answers Q1 only --"
rigTwoOpen tagged "$rigToNamed"
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000100"}'
rigAsk wait2 6 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is still waited on"                         "$rigKilled" yes
rigAsk wait1 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is answered"                                "$( head -1 "$rigScenarioDir/wait1" )" "ASK-RESULT: RECEIVED"
rigAssert "Q1's record closes"                            "$( rigStatus "$rigQ1Id" )" reply-received
rigAssert "Q2's stays open"                               "$( rigStatus "$rigQ2Id" )" reply-pending
rigAssert ":eyes: on the reply the wait took"             "$( LC_ALL=C grep -c -x -F '1700000001.000200 eyes' "$rigScenarioDir/reactions" 2>/dev/null )" 1
rigAssert ":white_check_mark: on Q1"                      "$( LC_ALL=C grep -c -x -F '1700000001.000101 white_check_mark' "$rigScenarioDir/reactions" 2>/dev/null )" 1
rigAssert "none on the named thread root, not ours"       "$( LC_ALL=C grep -c -x -F '1700000001.000100 white_check_mark' "$rigScenarioDir/reactions" 2>/dev/null )" 0

echo "-- two open in the named thread: a plain reply answers the latest question above it, Q2 only --"
rigTwoOpen untagged "$rigToNamed"
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000100"}'
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
rigReplies "" ",{\"ts\":\"1700000001.000200\",\"user\":\"URIGOWNER\",\"text\":\"yes\",\"thread_ts\":\"1700000001.000100\"},{\"ts\":\"$rigStrayTs\",\"user\":\"URIGOWNER\",\"text\":\"yes\",\"thread_ts\":\"1700000001.000100\"}"
rigStrayPosts="$( rigPosts )"
rigAsk wait1c 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "the wait returns rather than keeps waiting"    "$rigKilled" no
rigAssert "nothing is posted for it"                      "$(( $( rigPosts ) - rigStrayPosts ))" 0
rigAssert "Q1 gets UNCLASSIFIED"                          "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigScenarioDir/wait1c" )" "VERDICT: UNCLASSIFIED"
rigAssert "naming the record to re-wait on"               "$( LC_ALL=C grep -c -x -F "AskUserQuestion pending_id=$rigQ1Id" "$rigScenarioDir/wait1c" )" 1
rigAssert "with a reason naming the plain text Q1"        "$( rigHolds "$rigScenarioDir/wait1c" 'starts with the plain text Q1' )" yes
rigAssert "and never saying tag"                          "$( LC_ALL=C grep -c -i -E '(^|[^a-z])(un)?tag(ged)?([^a-z]|$)' "$rigScenarioDir/wait1c" )" 0
rigAssert "and its record stays open"                     "$( rigStatus "$rigQ1Id" )" reply-pending

echo "-- two asks at once to the same person in the named thread get distinct numbers --"
rigStart concurrent
rigReplies "" ""
rigAsk ask1 20 "{$rigToNamed,\"question\":\"$rigQ1\",\"wait\":false}"
( rigAsk askA 30 "{$rigToNamed,\"question\":\"May the rig keep report A?\",\"wait\":false}" ) &
( rigAsk askB 30 "{$rigToNamed,\"question\":\"May the rig keep report B?\",\"wait\":false}" ) &
wait
rigAssert "all three were posted"                         "$( rigPosts )" 3
rigAssert "all of them inside the named thread"           "$( LC_ALL=C grep -l -F '"thread_ts":"1700000001.000100"' "$rigScenarioDir"/post.* | wc -l | tr -d ' ' )" 3
rigAssert "under three different numbers"                 "$( LC_ALL=C sed -n 's/^question-tag: //p' "$rigScenarioDir"/ws/.local/agents/pending/*.md | LC_ALL=C sort -u | tr '\n' ' ' )" "Q1 Q2 Q3 "

echo "-- Q1 answered, Q2 open in the named thread: a late reply tagged Q1 does not answer Q2 --"
rigTwoOpen late "$rigToNamed"
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000100"}'
rigAsk wait1 20 "{\"pending_id\":\"$rigQ1Id\"}"
rigAssert "Q1 is answered and closed"                     "$( rigStatus "$rigQ1Id" )" reply-received
rigReplies "" ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1: yes","thread_ts":"1700000001.000100"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"Q1 actually no","thread_ts":"1700000001.000100"}'
rigAsk wait2 6 "{\"pending_id\":\"$rigQ2Id\"}"
rigAssert "Q2 is still waited on"                         "$rigKilled" yes
rigAssert "and stays open"                                "$( rigStatus "$rigQ2Id" )" reply-pending

echo "-- control: a different party in the named thread is numbered on its own --"
rigStart party
rigReplies "" ""
rigAsk ask1 20 "{$rigToNamed,\"question\":\"$rigQ1\",\"wait\":false}"
rigAsk ask2 20 "{\"to\":\"$rigNamed\",\"address_to\":\"URIGOTHER\",\"question\":\"$rigQ2\",\"wait\":false}"
rigAssert "two questions and no opener"                   "$( rigPosts )" 2
rigAssert "the first is the person's Q1"                  "$( rigHolds "$rigScenarioDir/post.1" 'Question Q1' )" yes
rigAssert "and the second is that party's own Q1"         "$( rigHolds "$rigScenarioDir/post.2" 'Question Q1' )" yes

echo "-- control: numbers count per person, across threads, and top-level questions take none --"
rigStart conversation
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"$rigQ1\",\"wait\":false}"
rigAsk ask2 20 "{$rigToNamed,\"question\":\"$rigQ2\",\"wait\":false}"
rigAsk ask3 20 "{\"to\":\"CRIG00002:1700000002.000200\",\"address_to\":\"human-owner\",\"question\":\"May the rig keep report C?\",\"wait\":false}"
rigAssert "three questions and no opener"                 "$( rigPosts )" 3
rigAssert "the top-level one carries no number"           "$( rigHolds "$rigScenarioDir/post.1" 'Question Q' )" no
rigAssert "so the first in a thread is Q1"                "$( rigHolds "$rigScenarioDir/post.2" 'Question Q1' )" yes
rigAssert "and the next, in another thread, is Q2"        "$( rigHolds "$rigScenarioDir/post.3" 'Question Q2' )" yes
rigAssert "never a second Q1 for the same person"         "$( rigHolds "$rigScenarioDir/post.3" 'Question Q1' )" no

echo "-- the person's counter starts above every number already in use --"
rigStart seeded
rigReplies "" ""
mkdir -p "$rigScenarioDir/ws/.local/agents/pending"
printf -- '---\nstatus: reply-received\nowner: magic-tester\naddress-to: human-owner\nquestion-tag: Q7\n---\n\n# Question asked\n' > "$rigScenarioDir/ws/.local/agents/pending/33333333-0000-0000-0000-000000000007.md"
rigAsk ask1 20 "{$rigToNamed,\"question\":\"$rigQ1\",\"wait\":false}"
rigAssert "the next question is Q8"                       "$( rigHolds "$rigScenarioDir/post.1" 'Question Q8' )" yes
rigAssert "a question has no earlier-question line"       "$( rigHolds "$rigScenarioDir/post.1" 'earlier question' )" no

echo "-- only the tool numbers a question, and no post says tag --"
rigStart numbering
rigReplies "" ""
rigAsk ask1 20 "{\"to\":\"human-owner\",\"question\":\"Q7: May the rig keep its first report file?\",\"wait\":false}"
rigAsk ask2 20 "{$rigToNamed,\"question\":\"q1) May the rig also keep its second report file?\",\"wait\":false}"
rigAssert "the top-level heading carries no number"       "$( rigHolds "$rigScenarioDir/post.1" 'Question Q' )" no
rigAssert "and its text keeps none of the asker's"        "$( rigHolds "$rigScenarioDir/post.1" 'Q7' )" no
rigAssert "the thread question's heading is Question Q1"  "$( rigHolds "$rigScenarioDir/post.2" 'Question Q1' )" yes
rigAssert "and its text carries no second number"         "$( rigHolds "$rigScenarioDir/post.2" 'q1)' )" no
rigAssert "no line about earlier questions"               "$( rigHolds "$rigScenarioDir/post.1" 'earlier question' )" no
rigAssert "and no rule that holds only sometimes"         "$( rigHolds "$rigScenarioDir/post.1" 'more than one question is open' )" no
rigAssert "nor in the thread question"                    "$( rigHolds "$rigScenarioDir/post.2" 'earlier question' )" no
rigAssert "no post says tag"                              "$( cat "$rigScenarioDir"/post.* | LC_ALL=C grep -c -w -i 'tag' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS ASK THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_THREAD: OK (%d assertions, offline)\n' "$rigPassCount"
