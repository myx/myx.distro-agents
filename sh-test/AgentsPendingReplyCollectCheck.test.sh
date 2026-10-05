#!/usr/bin/env bash
## Behavioural check on --intern-op-pending-reply-collect, the collector of answers to
## questions nobody waits on: a session's answered question is closed with its answer,
## :eyes: on the reply, :white_check_mark: on the question and, once nothing in the thread
## is open, on its opener; a question still open is marked for the main loop and the
## opener is left alone; the main loop's --ended pass closes a later answer and leaves a
## note in the asker's inbox; an unreadable thread stays open and is never closed; a
## readback is never collected; a collect racing a settle closes the record once; a
## refused reaction leaves the close intact; a handback carries what was collected; and
## no model is called anywhere. Offline: the Slack-shaped fake curl is first on PATH,
## model CLIs on PATH only log, and each scenario has its own workspace under the
## workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to read under"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsPendingReplyCollectCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## A model call anywhere would reach one of these first, and it only logs.
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
PATH="$rigTmp/bin:/usr/bin:/bin"
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
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
rigRecord(){ ## id, question ts, tag, session, kind (empty for a plain question)
	{
		printf -- '---\nstatus: reply-pending\nowner: %s\nhost: rig\n' "$rigMember"
		printf 'communication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\nsession-id: %s\n' "$4"
		[ -z "$5" ] || printf 'kind: %s\n' "$5"
		printf 'address-to: human-owner\nchannel: CRIG00001\nquestion-ts: %s\nthread-ts: 1700000001.000101\n' "$2"
		printf 'addressees: URIGOWNER\nasking-accounts: URIGSELF1\nquestion-tag: %s\nasked-at: 2026-09-29 12:00 +0300\n---\n\n' "$3"
		printf '# Question asked\n\n# ❓ Question %s\n\nMay the rig keep report %s?\n' "$3" "$3"
	} > "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
## The shared thread: opener, Q1, Q2, then the scenario's later messages.
rigReplies(){ ## later messages
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"opener"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"Q1","thread_ts":"1700000001.000101"},{"ts":"1700000001.000103","user":"URIGSELF1","text":"Q2","thread_ts":"1700000001.000101"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigEnv(){ ## command... -- run under the scenario's workspace, with no model key
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" "$@" )
}
rigCollect(){ ## output name, collect arguments...
	local collectOut="$1" ; shift
	rigEnv bash "$rigTool" --intern-op-pending-reply-collect "$@" > "$rigScenarioDir/$collectOut" 2> "$rigScenarioDir/$collectOut.err"
}
rigStatus(){ ## id
	LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigField(){ ## id, field
	LC_ALL=C awk -v key="$2" 'index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigReacted(){ ## "<ts> <name>" -- how many times that reaction was asked for
	LC_ALL=C grep -c -x -F -- "$1" "$rigScenarioDir/reactions" 2>/dev/null || :
}
rigQ1=22222222-0000-0000-0000-000000000001
rigQ2=22222222-0000-0000-0000-000000000002

echo "-- a question nobody waited on is answered: its session's collect closes it --"
rigStart answered
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-a ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, keep it","thread_ts":"1700000001.000101"}'
rigCollect out --session-id rig-sess-a
rigHolds "$rigScenarioDir/out" 'COLLECT: ' | grep -q yes || rigRefuse "the collect never answered: $( grep -m1 ERROR "$rigScenarioDir/out.err" )"
rigAssert "it says answered, with the answer"             "$( rigHolds "$rigScenarioDir/out" "ANSWERED $rigQ1 Q1 | May the rig keep report Q1? | yes, keep it" )" yes
rigAssert "the record is closed as received"              "$( rigStatus "$rigQ1" )" reply-received
rigAssert "with the answer as its verdict"                "$( rigField "$rigQ1" verdict )" "yes, keep it"
rigAssert "answered by the addressee"                     "$( rigField "$rigQ1" answered-by )" URIGOWNER
rigAssert ":eyes: on the reply taken"                     "$( rigReacted '1700000001.000200 eyes' )" 1
rigAssert ":white_check_mark: on the question"            "$( rigReacted '1700000001.000102 white_check_mark' )" 1
rigAssert "and on the opener, nothing else being open"    "$( rigReacted '1700000001.000101 white_check_mark' )" 1

echo "-- a session ends with one answered and one open --"
rigStart ended
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-b ""
rigRecord "$rigQ2" 1700000001.000103 Q2 rig-sess-b ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1 yes","thread_ts":"1700000001.000101"}'
rigCollect out --session-id rig-sess-b --mark-ended
rigAssert "Q1 is answered"                                "$( rigStatus "$rigQ1" )" reply-received
rigAssert "Q2 is still open"                              "$( rigStatus "$rigQ2" )" reply-pending
rigAssert "and reported open"                             "$( rigHolds "$rigScenarioDir/out" "OPEN $rigQ2 Q2" )" yes
rigAssert "Q2 is marked for the main loop"                "$( rigField "$rigQ2" collect )" ended
rigAssert "the opener is left alone while Q2 is open"     "$( rigReacted '1700000001.000101 white_check_mark' )" 0
rigAssert "the count line says so"                        "$( tail -1 "$rigScenarioDir/out" )" "COLLECT: answered=1 unmatched=0 open=1 unreadable=0"

echo "-- the main loop's pass: a later answer closes Q2 and reaches the asker's inbox --"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Q1 yes","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"go ahead","thread_ts":"1700000001.000101"}'
rigCollect ended --ended
rigAssert "Q2 is answered"                                "$( rigStatus "$rigQ2" )" reply-received
rigAssert "with the later reply"                          "$( rigField "$rigQ2" verdict )" "go ahead"
rigAssert "a note is in the asker's inbox"                "$( ls "$rigScenarioDir/data/inboxes/$rigMember/" 2>/dev/null | LC_ALL=C grep -c -E '^note-[0-9]{8}T[0-9]{6}Z-answer-22222222\.md$' )" 1
rigAssert "carrying the answer"                           "$( cat "$rigScenarioDir/data/inboxes/$rigMember/"note-*-answer-*.md 2>/dev/null | LC_ALL=C grep -c -F 'go ahead' )" 1
rigAssert "and now the opener is marked"                  "$( rigReacted '1700000001.000101 white_check_mark' )" 1

echo "-- an unreadable thread stays open --"
rigStart unreadable
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-c ""
rigCollect out --session-id rig-sess-c
rigAssert "it says unreadable"                            "$( rigHolds "$rigScenarioDir/out" "UNREADABLE $rigQ1" )" yes
rigAssert "and the record stays open"                     "$( rigStatus "$rigQ1" )" reply-pending

echo "-- a readback is never collected --"
rigStart readback
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-d readback
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000101"}'
rigCollect out --session-id rig-sess-d
rigAssert "nothing is reported for it"                    "$( rigHolds "$rigScenarioDir/out" "$rigQ1" )" no
rigAssert "it stays open"                                 "$( rigStatus "$rigQ1" )" reply-pending
rigAssert "and no reaction goes out"                      "$( cat "$rigScenarioDir/reactions" 2>/dev/null | wc -l | tr -d ' ' )" 0

echo "-- a collect racing a settle closes the record once --"
rigStart race
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-e ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000101"}'
( rigCollect raceCollect --session-id rig-sess-e ) &
( rigEnv env MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" bash "$rigTool" --member-pending-reply-settle "$rigMember" "$rigQ1" --reason "settled in the race" > "$rigScenarioDir/raceSettle" 2>&1 ) &
wait
rigAssert "one closer closed it"                          "$( cat "$rigScenarioDir/raceCollect" "$rigScenarioDir/raceSettle" | LC_ALL=C grep -c -E "^(ANSWERED $rigQ1|SETTLED $rigQ1)" )" 1
rigAssert "the other found it closed"                     "$( cat "$rigScenarioDir/raceCollect" "$rigScenarioDir/raceSettle" | LC_ALL=C grep -c "^ALREADY-CLOSED $rigQ1" )" 1

echo "-- a refused reaction leaves the close intact --"
rigStart refused
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-f ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes","thread_ts":"1700000001.000101"}'
touch "$rigScenarioDir/react-refuse"
rigCollect out --session-id rig-sess-f
rigAssert "the record is closed"                          "$( rigStatus "$rigQ1" )" reply-received
rigAssert "and says answered"                             "$( rigHolds "$rigScenarioDir/out" "ANSWERED $rigQ1" )" yes

echo "-- a handback carries what the tooling collected --"
rigStart handback
rigRecord "$rigQ1" 1700000001.000102 Q1 rig-sess-h ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, keep it","thread_ts":"1700000001.000101"}'
printf '%s' '{"to":"magic-team","outcome":"rig done"}' | rigEnv env MDAT_SPAWN_SESSION_ID=rig-sess-h MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
	bash "$rigHarness" --intern-tool SubagentHandback > "$rigScenarioDir/handback" 2> "$rigScenarioDir/handback.err"
rigAssert "the handback is posted"                        "$( ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' ' )" 1
rigAssert "with the collected field"                      "$( rigHolds "$rigScenarioDir/post.1" 'Answers collected, and questions still open:' )" yes
rigAssert "carrying the answer"                           "$( rigHolds "$rigScenarioDir/post.1" 'yes, keep it' )" yes
rigAssert "and the record is closed"                      "$( rigStatus "$rigQ1" )" reply-received
rigAssert "control: the body names its channel as this check reads it" "$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIG00001"' )" yes

## The addressee of a handback, and of the tools that share its send path. The child's record
## sits in a folder named for neither id, so only a lookup by record name can find it.
rigSpawnRecords(){ ## parent id for the child record, the parent's thread (empty for none)
	local spawnDir="$rigScenarioDir/ws/.local/agents/spawned"
	mkdir -p "$spawnDir/child-folder" "$spawnDir/parent-folder" "$spawnDir/prefix-folder"
	printf -- '---\nspawn-id: rig-child-id\nparent-session-id: %s\n---\n' "$1" > "$spawnDir/child-folder/rig-child-id.md"
	printf '%s\n' 'CCHILD01:1700000002.000202' > "$spawnDir/child-folder/session.thread"
	printf -- '---\nspawn-id: rig-parent-id\nparent-session-id: none\n%s---\n' "${2:+session-thread: $2
}" > "$spawnDir/parent-folder/rig-parent-id.md"
	printf '%s\n' 'CWRONG01:1.1' > "$spawnDir/parent-folder/session.thread"
	printf -- '---\nspawn-id: rig-parent-id-extra\nparent-session-id: none\nsession-thread: CWRONG01:1.1\n---\n' > "$spawnDir/prefix-folder/rig-parent-id-extra.md"
}
rigCall(){ ## tool name, arguments JSON
	printf '%s' "$2" | rigEnv env -u MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
		bash "$rigHarness" --intern-tool "$1" > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err"
}
rigPosts(){
	ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' '
}
rigFirstIs(){ ## prefix of the result's first line
	LC_ALL=C awk -v want="$1" 'NR == 1 { print ( index($0, want) == 1 ? "yes" : "no" ) ; exit ; }' "$rigScenarioDir/tool.out"
}
rigPostedTo(){ ## channel, thread ts (empty for none)
	[ "$( rigHolds "$rigScenarioDir/post.1" "\"channel\":\"$1\"" )" = yes ] && { [ -z "$2" ] || [ "$( rigHolds "$rigScenarioDir/post.1" "\"thread_ts\":\"$2\"" )" = yes ] ; } && printf yes || printf no
}
rigInbox(){ ## member -> how many inquiry items it holds
	ls "$rigScenarioDir/data/inboxes/$1/" 2>/dev/null | LC_ALL=C grep -c -E '^inquiry-[0-9]{8}T[0-9]{4}Z-' || :
}

echo "-- a handback with no addressee goes to the parent session's thread --"
rigStart hbDefault
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"outcome":"rig done"}'
rigAssert "one post"                                      "$( rigPosts )" 1
rigAssert "in the parent's channel and thread"            "$( rigPostedTo CPARENT1 1700000001.000101 )" yes
rigAssert "as a handback"                                 "$( rigHolds "$rigScenarioDir/post.1" 'Handback' )" yes
rigAssert "and the result's first line names the route"   "$( rigFirstIs 'Sent to CPARENT1:1700000001.000101 (the thread of parent session rig-parent-id) as magic-tester.' )" yes
rigAssert "the child's own thread was not used"           "$( rigHolds "$rigScenarioDir/post.1" 'CCHILD01' )" no
rigAssert "nor the thread of a longer parent id"          "$( rigHolds "$rigScenarioDir/post.1" 'CWRONG01' )" no

echo "-- session-parent, named or empty, is the same route --"
rigStart hbNamed
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"session-parent","outcome":"x"}'
rigAssert "named: posted to the parent"                   "$( rigPostedTo CPARENT1 1700000001.000101 )" yes
rigStart hbEmpty
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"","outcome":"x"}'
rigAssert "empty: posted to the parent"                   "$( rigPostedTo CPARENT1 1700000001.000101 )" yes

echo "-- no recorded parent: an error, nothing sent, no other thread --"
rigStart hbNoParent
rigSpawnRecords none CPARENT1:1700000001.000101
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "no post"                                       "$( rigPosts )" 0
rigAssert "it is an error"                                "$( rigFirstIs 'ERROR: this session has no recorded parent session' )" yes

echo "-- a parent with no thread: an error, nothing sent, never the child's own thread --"
rigStart hbNoThread
rigSpawnRecords rig-parent-id ""
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "no post"                                       "$( rigPosts )" 0
rigAssert "it names the parent"                           "$( rigFirstIs 'ERROR: the parent session rig-parent-id has no recorded thread' )" yes

echo "-- no record at all: an error, nothing sent --"
rigStart hbNoRecord
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "no post"                                       "$( rigPosts )" 0
rigAssert "it is an error"                                "$( rigFirstIs 'ERROR: this session has no recorded parent session' )" yes

echo "-- an explicit thread wins over the default --"
rigStart hbExplicit
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"CEXPL001:1700000009.000009","outcome":"x"}'
rigAssert "posted to that thread"                         "$( rigPostedTo CEXPL001 1700000009.000009 )" yes
rigAssert "and not to the parent's"                       "$( rigHolds "$rigScenarioDir/post.1" 'CPARENT1' )" no

echo "-- a team member name: its Slack DM where it has an account, its inbox where it has none --"
rigStart hbMemberDm
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"magic-tester","outcome":"x"}'
rigAssert "a member with an account: one post"            "$( rigPosts )" 1
rigAssert "to its own account, as the DM"                 "$( rigPostedTo URIGSELF1 "" )" yes
rigAssert "and nothing in its inbox"                      "$( rigInbox magic-tester )" 0
rigStart hbMemberInbox
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"magic-librarian","outcome":"rig done"}'
rigAssert "a member with none: no post"                   "$( rigPosts )" 0
rigAssert "one inquiry in its inbox"                      "$( rigInbox magic-librarian )" 1
rigAssert "of type inquiry"                               "$( cat "$rigScenarioDir/data/inboxes/magic-librarian/"inquiry-*.md 2>/dev/null | LC_ALL=C grep -c -x 'type: inquiry' )" 1
rigAssert "carrying the handback"                         "$( cat "$rigScenarioDir/data/inboxes/magic-librarian/"inquiry-*.md 2>/dev/null | LC_ALL=C grep -c -F 'rig done' )" 1
rigAssert "and the first line names the inbox route"      "$( rigFirstIs 'Sent to the inbox of magic-librarian as inquiry-' )" yes
rigStart hbMemberUnknown
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"no-such-member","outcome":"x"}'
rigAssert "a name that is no member: no post"             "$( rigPosts )" 0
rigAssert "it is an error"                                "$( rigFirstIs 'ERROR:' )" yes
rigAssert "and no inbox was made for it"                  "$( ls "$rigScenarioDir/data/inboxes" 2>/dev/null | LC_ALL=C grep -c -x 'no-such-member' || : )" 0

echo "-- human-owner is unchanged --"
rigStart hbOwner
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall SubagentHandback '{"to":"human-owner","outcome":"x"}'
rigAssert "posted to the owner's conversation"            "$( rigPostedTo URIGOWNER "" )" yes

echo "-- each tool keeps its own rules that are not about the addressee --"
rigStart sharedRefused
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall ReportFindings '{"subject":"s","findings":"f"}'
rigAssert "ReportFindings with no to"                     "$( rigFirstIs 'ERROR: ReportFindings: to is required' )" yes
rigCall PushNotification '{"severity":"info","headline":"h"}'
rigAssert "PushNotification with no to"                   "$( rigFirstIs 'ERROR: PushNotification: to is required' )" yes
rigCall Artifact '{"url":"https://x/y"}'
rigAssert "Artifact with no to"                           "$( rigFirstIs 'ERROR: Artifact: to is required' )" yes
rigCall Artifact '{"to":"magic-librarian","url":"not-a-url"}'
rigAssert "Artifact still checks its url first"           "$( rigFirstIs 'ERROR: Artifact: url must be' )" yes
rigCall ReportFindings '{"to":"session-parent","subject":"s"}'
rigAssert "ReportFindings still needs its findings"       "$( rigFirstIs 'ERROR: ReportFindings: both subject and findings are required' )" yes
rigCall SubagentHandback '{"findings":"f"}'
rigAssert "a handback with no outcome and no to"          "$( rigFirstIs 'ERROR: SubagentHandback: outcome is required' )" yes
rigAssert "none of these posted or reached an inbox"      "$( rigPosts )$( rigInbox magic-librarian )" 00

rigRow(){ ## scenario name, tool, arguments JSON
	rigStart "$1"
	rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
	rigCall "$2" "$3"
}
echo "-- the same addressee values work in all six tools --"
rigRow allParentSend SendMessage '{"to":"session-parent","message":"m"}'
rigAssert "SendMessage to session-parent"                 "$( rigPosts )$( rigPostedTo CPARENT1 1700000001.000101 )" 1yes
rigRow allParentReport ReportFindings '{"to":"session-parent","subject":"s","findings":"f"}'
rigAssert "ReportFindings to session-parent"              "$( rigPosts )$( rigPostedTo CPARENT1 1700000001.000101 )" 1yes
rigRow allParentPush PushNotification '{"to":"session-parent","severity":"info","headline":"h"}'
rigAssert "PushNotification to session-parent"            "$( rigPosts )$( rigPostedTo CPARENT1 1700000001.000101 )" 1yes
rigRow allParentArtifact Artifact '{"to":"session-parent","url":"https://x/y"}'
rigAssert "Artifact to session-parent"                    "$( rigPosts )$( rigPostedTo CPARENT1 1700000001.000101 )" 1yes
rigRow allParentAsk AskUserQuestion '{"to":"session-parent","address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "AskUserQuestion to session-parent"             "$( rigPosts )$( rigPostedTo CPARENT1 1700000001.000101 )" 1yes
rigRow allParentAskBare AskUserQuestion '{"to":"session-parent","question":"May the rig go on?","wait":false}'
rigAssert "AskUserQuestion there needs address_to, as for any thread" "$( rigPosts )$( rigFirstIs 'ERROR: AskUserQuestion:' )" 0yes
for rigPair in 'SendMessage={"to":"magic-tester","message":"m"}' 'ReportFindings={"to":"magic-tester","subject":"s","findings":"f"}' 'PushNotification={"to":"magic-tester","severity":"info","headline":"h"}' 'Artifact={"to":"magic-tester","url":"https://x/y"}' ; do
	rigRow "allDm${rigPair%%=*}" "${rigPair%%=*}" "${rigPair#*=}"
	rigAssert "${rigPair%%=*} to a member with an account: its DM"  "$( rigPosts )$( rigPostedTo URIGSELF1 "" )$( rigInbox magic-tester )" 1yes0
done
for rigPair in 'SendMessage={"to":"magic-librarian","message":"m"}' 'ReportFindings={"to":"magic-librarian","subject":"s","findings":"f"}' 'PushNotification={"to":"magic-librarian","severity":"info","headline":"h"}' 'Artifact={"to":"magic-librarian","url":"https://x/y"}' ; do
	rigRow "allInbox${rigPair%%=*}" "${rigPair%%=*}" "${rigPair#*=}"
	rigAssert "${rigPair%%=*} to a member with none: its inbox"     "$( rigPosts )$( rigInbox magic-librarian )$( rigFirstIs 'Sent to the inbox of magic-librarian' )" 01yes
done
rigRow allAskDm AskUserQuestion '{"to":"magic-tester","question":"May the rig go on?","wait":false}'
rigAssert "AskUserQuestion to a member with an account: its DM" "$( rigPostedTo URIGSELF1 "" )" yes
rigRow allAskInbox AskUserQuestion '{"to":"magic-librarian","question":"May the rig go on?","wait":false}'
rigAssert "AskUserQuestion to a member with none is refused, as an inbox cannot answer" "$( rigPosts )$( rigInbox magic-librarian )$( rigHolds "$rigScenarioDir/tool.out" 'cannot carry a question' )" 00yes

echo "-- PushNotification to a team member: DM, else inbox --"
rigStart pushOwner
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall PushNotification '{"to":"human-owner","severity":"info","headline":"h"}'
rigAssert "to human-owner: one post, in its conversation" "$( rigPosts )$( rigPostedTo URIGOWNER "" )" 1yes
rigStart pushMember
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall PushNotification '{"to":"magic-tester","severity":"warn","headline":"h"}'
rigAssert "to a member with an account: its DM"           "$( rigPosts )$( rigPostedTo URIGSELF1 "" )" 1yes
rigStart pushInbox
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall PushNotification '{"to":"magic-librarian","severity":"alert","headline":"h"}'
rigAssert "to a member with none: its inbox, no post"     "$( rigPosts )$( rigInbox magic-librarian )" 01
rigStart pushBogus
rigSpawnRecords rig-parent-id CPARENT1:1700000001.000101
rigCall PushNotification '{"to":"human-owner","severity":"bogus","headline":"h"}'
rigAssert "control: a bad severity is refused, no post"   "$( rigPosts )$( rigFirstIs 'ERROR: PushNotification: severity must be' )" 0yes

echo "-- no model was called anywhere --"
rigAssert "no claude or codex call"                       "$( cat "$rigTmp/model-calls" 2>/dev/null | wc -l | tr -d ' ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY COLLECT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_COLLECT: OK (%d assertions, offline, no model)\n' "$rigPassCount"
